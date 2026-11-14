#!/usr/bin/env python3
"""No live network commands: all controller operations use FakeHost."""
import contextlib
import copy
import importlib.util
import json
import os
import pty
import select
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from collections.abc import Callable
from pathlib import Path
from typing import Any
from unittest import mock

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'herdr-spreader/.config/herdr-spreader/sandbox-exposure.py'
sys.path.insert(0, str(SOURCE.parent))


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeHost:
    def __init__(self):
        self.links: dict[str, Any] = {'eth0': {'ifname': 'eth0'}, 'agentbr0': {'ifname': 'agentbr0'}}
        self.addresses = {}
        self.forwards = []
        self.calls = []
        self.fail: Callable[[list[str]], bool] | None = None
        self.lease = '192.0.2.40'

    def run(self, args, data=None):
        self.calls.append((list(args), data))
        if self.fail and self.fail(args):
            raise RuntimeError('injected command failure')
        if args[:4] == ['ip', '-details', '-json', 'link']:
            return json.dumps(list(self.links.values()))
        if args[:4] == ['ip', '-json', '-4', 'addr']:
            names = [args[-1]] if 'dev' in args else list(self.addresses)
            return json.dumps([{'ifname': name, 'addr_info': [{'family': 'inet', 'scope': 'global', 'local': a}
                                for a in self.addresses.get(name, [])]} for name in names])
        if args[:3] == ['ip', 'link', 'add']:
            name = args[args.index('name') + 1]
            self.links[name] = {'ifname': name, 'link': args[args.index('link', 2) + 1],
                                'ifalias': args[args.index('alias') + 1],
                                'address': args[args.index('address') + 1],
                                'linkinfo': {'info_kind': 'macvlan', 'info_data': {'mode': 'bridge'}}}
            return ''
        if args[:3] == ['ip', 'link', 'set'] or args[0] == 'sysctl':
            if 'alias' in args:
                self.links[args[args.index('dev') + 1]]['ifalias'] = args[args.index('alias') + 1]
            return ''
        if args[:3] == ['ip', 'link', 'delete']:
            self.links.pop(args[-1], None)
            self.addresses.pop(args[-1], None)
            return ''
        if args[0] == 'dhclient':
            if '-r' not in args:
                self.addresses[args[-1]] = [self.lease]
            return ''
        if args[0] == 'incus':
            rest = args[args.index('--project') + 2:]
            if rest == ['network', 'list', '--format', 'json']:
                return json.dumps([{'name': 'agentbr0', 'type': 'bridge', 'managed': True,
                                    'config': {'ipv4.address': '10.77.0.1/16'}}])
            if rest[:3] == ['network', 'forward', 'list']:
                return json.dumps(self.forwards)
            if rest[:3] == ['network', 'forward', 'create']:
                assert data is not None
                value = json.loads(data)
                value['listen_address'] = rest[4]
                self.forwards.append(value)
                return ''
            if rest[:3] == ['network', 'forward', 'edit']:
                old = next(f for f in self.forwards if f['listen_address'] == rest[4])
                assert data is not None
                old.clear()
                old.update(json.loads(data), listen_address=rest[4])
                return ''
            if rest[:3] == ['network', 'forward', 'delete']:
                self.forwards = [f for f in self.forwards if f['listen_address'] != rest[4]]
                return ''
        raise AssertionError(f'unexpected command: {args!r}')

    def mutations(self):
        return [c for c in self.calls if c[0][0] in ('dhclient', 'sysctl')
                or c[0][:2] == ['ip', 'link']
                or (c[0][0] == 'incus' and any(x in c[0] for x in ('create', 'edit', 'delete')))]


class ExposureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load(SOURCE, 'exposure')

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.host = FakeHost()
        self.prompts = []
        self.answer = True
        self.ctl = self.mod.Controller(Path(self.tmp.name) / 'state', self.host, self.confirm)
        preflight = mock.patch.object(self.mod, 'check_dhcp_apparmor')
        self.preflight = preflight.start()
        self.addCleanup(preflight.stop)

    def confirm(self, message):
        self.prompts.append(message)
        return self.answer

    def create(self, **kw):
        values = {'name': 'xiqfwd1', 'parent': 'eth0', 'network': 'agentbr0', 'project': 'default',
                  'target': '10.77.10.20', 'ports': 'all'}
        values.update(kw)
        return self.ctl.create(**values)

    def test_decimal_conversion_errors_have_context(self):
        self.assertEqual(65535, self.mod.parse_decimal('65535', 'port'))
        for value in ('not-a-number', '', '1.5'):
            with self.subTest(value=value[:20]), self.assertRaisesRegex(self.mod.ExposureError, 'invalid port') as caught:
                self.mod.parse_decimal(value, 'port')
            self.assertIsInstance(caught.exception.__cause__, ValueError)

    def test_corrupt_state_has_context_and_blocks_mutation(self):
        self.create()
        path = self.ctl.root / 'xiqfwd1.json'
        self.host.calls.clear()
        for data in (b'not-json', b'\xff'):
            path.write_bytes(data)
            with self.subTest(data=data), self.assertRaisesRegex(self.mod.ExposureError, 'ownership record.*xiqfwd1') as caught:
                self.ctl.delete('xiqfwd1')
            self.assertIsInstance(caught.exception.__cause__, ValueError)
        self.assertEqual([], self.host.mutations())

    def test_state_read_error_has_context(self):
        self.create()
        self.host.calls.clear()
        with (mock.patch.object(Path, 'read_text', side_effect=PermissionError('read denied')),
              self.assertRaisesRegex(self.mod.ExposureError, 'ownership record.*xiqfwd1') as caught):
            self.ctl.delete('xiqfwd1')
        self.assertIsInstance(caught.exception.__cause__, PermissionError)
        self.assertEqual([], self.host.mutations())

    def test_invalid_link_and_address_json_have_context(self):
        for operation, context in ((self.ctl.links, 'link inventory'),
                                   (lambda: self.ctl.addresses('xiqfwd1'), 'addresses.*xiqfwd1')):
            with (self.subTest(context=context), mock.patch.object(self.host, 'run', return_value='not-json'),
                  self.assertRaisesRegex(self.mod.ExposureError, context) as caught):
                operation()
            self.assertIsInstance(caught.exception.__cause__, json.JSONDecodeError)
        self.assertEqual([], self.host.mutations())

    def invalid_forward_inventory(self, args, data=None):
        if 'forward' in args and 'list' in args:
            return 'not-json'
        return self.original_run(args, data=data)

    def test_invalid_owned_forward_json_blocks_mutation(self):
        self.create()
        self.host.calls.clear()
        self.original_run = self.host.run
        with (mock.patch.object(self.host, 'run', side_effect=self.invalid_forward_inventory),
              self.assertRaisesRegex(self.mod.ExposureError, 'forward inventory.*default/agentbr0') as caught):
            self.ctl.update('xiqfwd1', target='10.77.10.21')
        self.assertIsInstance(caught.exception.__cause__, json.JSONDecodeError)
        self.assertEqual([], self.host.mutations())

    def test_invalid_unmanaged_forward_json_has_context(self):
        self.host.links['xiqfwd0'] = {'ifname': 'xiqfwd0'}
        self.host.addresses['xiqfwd0'] = ['192.0.2.41']
        self.original_run = self.host.run
        with (mock.patch.object(self.host, 'run', side_effect=self.invalid_forward_inventory),
              self.assertRaisesRegex(self.mod.ExposureError, 'forward inventory.*default/agentbr0') as caught):
            self.ctl.status('xiqfwd0')
        self.assertIsInstance(caught.exception.__cause__, json.JSONDecodeError)
        self.assertEqual([], self.host.mutations())

    def test_create_and_repeat_are_idempotent(self):
        self.create()
        self.assertEqual('10.77.10.20', self.host.forwards[0]['config']['target_address'])
        self.assertEqual([], self.host.forwards[0]['ports'])
        self.assertIn('herdr-sandbox-exposure:', self.host.links['xiqfwd1']['ifalias'])
        self.assertIn('herdr-sandbox-exposure:', self.host.forwards[0]['description'])
        self.host.calls.clear()
        self.create()
        self.assertEqual([], self.host.mutations())

    def test_parent_or_shared_lab_address_is_never_captured(self):
        self.host.addresses['eth0'] = [self.host.lease]
        with self.assertRaisesRegex(self.mod.ExposureError, 'address.*another interface'):
            self.create()
        self.assertEqual([], self.host.forwards)

    def test_unmanaged_interface_is_never_adopted(self):
        self.host.links['xiqfwd0'] = {'ifname': 'xiqfwd0'}
        with self.assertRaisesRegex(self.mod.ExposureError, 'unmanaged|owned'):
            self.create(name='xiqfwd0')
        self.assertEqual([], self.host.mutations())

    def test_retarget_requires_confirmation_and_preserves_ports(self):
        self.create(ports='tcp:443,udp:5000-5002')
        self.host.calls.clear()
        self.answer = False
        with self.assertRaisesRegex(self.mod.ExposureError, 'cancel'):
            self.ctl.update('xiqfwd1', target='10.77.10.21')
        self.assertEqual([], self.host.mutations())
        self.answer = True
        self.ctl.update('xiqfwd1', target='10.77.10.21')
        forward = self.host.forwards[0]
        self.assertNotIn('target_address', forward['config'])
        self.assertEqual(['tcp', 'udp'], [p['protocol'] for p in forward['ports']])
        self.assertTrue(all(p['target_address'] == '10.77.10.21' for p in forward['ports']))
        self.assertIn('10.77.10.20', self.prompts[-1])
        self.assertIn('10.77.10.21', self.prompts[-1])

    def test_restrict_removes_catch_all_and_same_update_is_noop(self):
        self.create()
        self.ctl.update('xiqfwd1', ports='tcp:80,tcp:443')
        self.assertEqual({}, self.host.forwards[0]['config'])
        self.assertEqual(2, len(self.host.forwards[0]['ports']))
        self.host.calls.clear()
        self.ctl.update('xiqfwd1', ports='tcp:80,tcp:443')
        self.assertEqual([], self.host.mutations())

    def test_delete_is_confirmed_and_ordered_then_repeat_is_noop(self):
        self.create()
        self.host.calls.clear()
        self.answer = False
        with self.assertRaisesRegex(self.mod.ExposureError, 'cancel'):
            self.ctl.delete('xiqfwd1')
        self.assertEqual([], self.host.mutations())
        self.answer = True
        self.ctl.delete('xiqfwd1')
        calls = [c[0] for c in self.host.mutations()]
        self.assertEqual('delete', calls[0][-3])
        self.assertEqual('dhclient', calls[1][0])
        self.assertIn('-r', calls[1])
        self.assertEqual(['ip', 'link', 'delete', 'dev', 'xiqfwd1'], calls[2])
        self.assertNotIn('xiqfwd1', self.host.links)
        self.host.calls.clear()
        self.ctl.delete('xiqfwd1')
        self.assertEqual([], self.host.mutations())

    def test_invalid_inputs_fail_before_mutation(self):
        for kw in ({'name': 'xiqfwd1;id'}, {'name': 'xiqfwd01'}, {'target': '127.0.0.1'},
                   {'target': '10.77.0.1'}, {'target': '10.77.255.255'},
                   {'target': '2001:db8::1'}, {'ports': 'tcp:0'}, {'ports': 'udp:65536'},
                   {'ports': 'tcp:80-1'}, {'ports': 'tcp:80,tcp:80'}, {'ports': ''},
                   {'ports': 'all,tcp:22'}, {'parent': 'eth0;id'}, {'network': 'remote:net'}):
            with self.subTest(kw=kw):
                with self.assertRaises((self.mod.ExposureError, ValueError)):
                    self.create(**kw)
                self.assertEqual([], self.host.mutations())

    def test_unowned_address_forward_is_not_modified(self):
        original = {'listen_address': self.host.lease, 'description': 'another agent',
                    'config': {'target_address': '10.77.1.1'}, 'ports': []}
        self.host.forwards.append(copy.deepcopy(original))
        with self.assertRaisesRegex(self.mod.ExposureError, 'owned|unmanaged|conflict'):
            self.create()
        self.assertEqual([original], self.host.forwards)
        self.assertFalse(any(c[0][0] == 'incus' and 'delete' in c[0] for c in self.host.calls))

    def test_forward_drift_blocks_update_and_delete(self):
        self.create()
        self.host.forwards[0]['config']['target_address'] = '10.77.2.3'
        self.host.calls.clear()
        for action in (lambda: self.ctl.update('xiqfwd1', target='10.77.10.22'),
                       lambda: self.ctl.delete('xiqfwd1')):
            with self.assertRaisesRegex(self.mod.ExposureError, 'drift|changed'):
                action()
        self.assertEqual([], self.host.mutations())

    def test_dhcp_failure_leaves_recoverable_record(self):
        self.host.fail = lambda a: a[0] == 'dhclient' and '-r' not in a
        with self.assertRaises(RuntimeError):
            self.create()
        self.assertIn('xiqfwd1', self.host.links)
        self.assertEqual([], self.host.forwards)
        self.host.fail = None
        self.create()
        self.assertEqual(1, len(self.host.forwards))

    def test_forward_create_failure_can_retry_or_delete(self):
        self.host.fail = lambda a: a[0] == 'incus' and 'create' in a
        with self.assertRaises(RuntimeError):
            self.create()
        self.host.fail = None
        self.create()
        self.assertEqual(1, len(self.host.forwards))

    def test_delete_failure_keeps_interface_and_retry_is_safe(self):
        self.create()
        self.host.fail = lambda a: a[0] == 'incus' and 'delete' in a
        with self.assertRaises(RuntimeError):
            self.ctl.delete('xiqfwd1')
        self.assertIn('xiqfwd1', self.host.links)
        self.host.fail = None
        self.ctl.delete('xiqfwd1')
        self.assertNotIn('xiqfwd1', self.host.links)

    def test_lease_change_blocks_update_but_owned_delete_still_works(self):
        self.create()
        self.host.addresses['xiqfwd1'] = ['192.0.2.99']
        self.host.calls.clear()
        with self.assertRaisesRegex(self.mod.ExposureError, 'address|lease'):
            self.ctl.update('xiqfwd1', target='10.77.10.21')
        self.assertEqual([], self.host.mutations())
        self.ctl.delete('xiqfwd1')
        self.assertEqual([], self.host.forwards)

    def test_missing_owned_interface_still_cleans_its_forward(self):
        self.create()
        del self.host.links['xiqfwd1']
        self.ctl.delete('xiqfwd1')
        self.assertEqual([], self.host.forwards)

    def test_reused_interface_blocks_delete_even_with_owned_record(self):
        self.create()
        self.host.links['xiqfwd1']['ifalias'] = 'someone else'
        self.host.calls.clear()
        with self.assertRaisesRegex(self.mod.ExposureError, 'owned|ownership'):
            self.ctl.delete('xiqfwd1')
        self.assertEqual([], self.host.mutations())

    def test_status_is_read_only_and_marks_unmanaged(self):
        self.host.links['xiqfwd0'] = {'ifname': 'xiqfwd0'}
        result = self.ctl.status()
        self.assertEqual('unmanaged', result[0]['status'])
        self.assertEqual([], self.host.mutations())
        self.assertFalse(self.ctl.root.exists())

    def test_state_permissions_and_symlinks_are_rejected(self):
        self.create()
        path = self.ctl.root / 'xiqfwd1.json'
        path.chmod(0o666)
        self.host.calls.clear()
        with self.assertRaisesRegex(self.mod.ExposureError, 'unsafe|permission'):
            self.ctl.delete('xiqfwd1')
        self.assertEqual([], self.host.mutations())

    def test_pid_reuse_blocks_dhcp_release(self):
        self.create()
        path = self.ctl.root / 'xiqfwd1.dhcp/client.pid'
        path.write_text('12345\n')
        path.chmod(0o600)
        self.host.calls.clear()
        with (mock.patch.object(self.mod, 'process_command', return_value=['unrelated-service']),
              self.assertRaisesRegex(self.mod.ExposureError, 'PID|process')):
            self.ctl.delete('xiqfwd1')
        self.assertIn('xiqfwd1', self.host.links)
        self.assertFalse(any(c[0][0] == 'dhclient' for c in self.host.calls))

    def test_pid_reuse_blocks_retry_acquisition(self):
        self.host.fail = lambda a: a[0] == 'incus' and 'create' in a
        with self.assertRaises(RuntimeError):
            self.create()
        self.host.fail = None
        self.host.addresses['xiqfwd1'] = []
        path = self.ctl.root / 'xiqfwd1.dhcp/client.pid'
        path.write_text('12345\n')
        path.chmod(0o600)
        self.host.calls.clear()
        with (mock.patch.object(self.mod, 'process_command', return_value=['unrelated-service']),
              self.assertRaisesRegex(self.mod.ExposureError, 'PID|process')):
            self.create()
        self.assertFalse(any(c[0][0] == 'dhclient' for c in self.host.calls))

    def test_release_failure_keeps_state_and_interface_for_retry(self):
        self.create()
        self.host.fail = lambda a: a[0] == 'dhclient' and '-r' in a
        with self.assertRaises(RuntimeError):
            self.ctl.delete('xiqfwd1')
        self.assertEqual([], self.host.forwards)
        self.assertIn('xiqfwd1', self.host.links)
        self.host.fail = None
        self.ctl.delete('xiqfwd1')
        self.assertNotIn('xiqfwd1', self.host.links)

    def test_update_failure_after_effect_is_recoverable(self):
        self.create()
        original = self.ctl.save
        def fail_final(record):
            if record['target'] == '10.77.10.21' and record['pending'] is None:
                raise RuntimeError('simulated crash after edit')
            original(record)
        with mock.patch.object(self.ctl, 'save', side_effect=fail_final), self.assertRaises(RuntimeError):
            self.ctl.update('xiqfwd1', target='10.77.10.21')
        self.host.calls.clear()
        with self.assertRaisesRegex(self.mod.ExposureError, 'pending|update'):
            self.create()
        self.ctl.update('xiqfwd1', target='10.77.10.21')
        self.assertEqual([], self.host.mutations())
        self.assertEqual('ready', self.ctl.status('xiqfwd1')[0]['status'])

    def test_symlink_state_and_lock_contention_fail_closed(self):
        self.create()
        path = self.ctl.root / 'xiqfwd1.json'
        backup = path.with_suffix('.backup')
        path.rename(backup)
        path.symlink_to(backup)
        with self.assertRaisesRegex(self.mod.ExposureError, 'unsafe'):
            self.ctl.delete('xiqfwd1')
        with self.ctl.lock(), self.assertRaisesRegex(self.mod.ExposureError, 'another exposure'), self.ctl.lock():
            self.fail('acquired held lock')

    def test_confirmation_without_tty_cancels(self):
        with mock.patch('builtins.open', side_effect=OSError('no tty')):
            self.assertFalse(self.mod.confirm_tty('test confirmation'))

    def test_confirmation_accepts_yes_on_a_real_controlling_tty(self):
        pid, fd = pty.fork()
        if pid == 0:
            os._exit(0 if self.mod.confirm_tty('PTY confirmation check') else 1)
        status = None
        output = b''
        try:
            deadline = time.monotonic() + 5
            while b'Type yes to confirm' not in output and time.monotonic() < deadline:
                if select.select([fd], [], [], 0.1)[0]:
                    try:
                        output += os.read(fd, 4096)
                    except OSError:
                        break
            self.assertIn(b'Type yes to confirm', output, output.decode(errors='replace'))
            os.write(fd, b'yes\n')
            while time.monotonic() < deadline:
                exited, status = os.waitpid(pid, os.WNOHANG)
                if exited:
                    break
                status = None
                time.sleep(0.01)
            self.assertIsNotNone(status, 'TTY confirmation did not finish')
            self.assertEqual(0, status)
        finally:
            os.close(fd)
            if status is None:
                with contextlib.suppress(ProcessLookupError):
                    os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)

    def test_ipv6_is_disabled_only_on_owned_interface(self):
        self.create()
        calls = [c[0] for c in self.host.calls]
        disable = ['sysctl', '-w', 'net.ipv6.conf.xiqfwd1.disable_ipv6=1']
        self.assertIn(disable, calls)
        self.assertLess(calls.index(disable), calls.index(['ip', 'link', 'set', 'dev', 'xiqfwd1', 'up']))

    def legacy_exposure(self):
        self.host.links['xiqfwd0'] = {'ifname': 'xiqfwd0', 'ifindex': 42, 'link': 'eth0',
                                    'address': 'ae:63:1f:10:24:87',
                                    'linkinfo': {'info_kind': 'macvlan', 'info_data': {'mode': 'bridge'}}}
        self.host.addresses['xiqfwd0'] = [self.host.lease]
        self.host.forwards = [{'listen_address': self.host.lease, 'description': '',
                               'config': {'target_address': '10.77.10.20'}, 'ports': []}]
        self.legacy = {'pid': 12345, 'uid': 0, 'exe': '/usr/sbin/dhclient', 'start_ticks': '123',
                       'netns': os.readlink('/proc/self/ns/net'),
                       'args': ['dhclient', '-v', '-lf', '/run/xiqfwd/lease', '-pf', '/run/xiqfwd/pid',
                                '-sf', '/bin/true', 'xiqfwd0']}
        self.clients = [copy.deepcopy(self.legacy)]
        for name, effect in (
                ('dhcp_processes', lambda name: copy.deepcopy(self.clients)),
                ('process_identity', lambda pid: next((copy.deepcopy(p) for p in self.clients if p['pid'] == pid), None)),
                ('stop_legacy_client', lambda identity: self.clients.remove(identity))):
            patcher = mock.patch.object(self.mod, name, side_effect=effect, create=True)
            patcher.start()
            self.addCleanup(patcher.stop)
        original = self.host.run
        def run(args, data=None):
            if args[0] != 'dhclient' or '-r' in args:
                return original(args, data=data)
            env = dict(item.split('=', 1) for i, item in enumerate(args) if i and args[i - 1] == '-e')
            expected = env.get('HERDR_EXPOSURE_EXPECT_ADDRESS')
            if not expected:
                return original(args, data=data)
            self.host.calls.append((list(args), data))
            if self.host.fail and self.host.fail(args):
                raise RuntimeError('injected DHCP handoff failure')
            pid = 22222
            pid_file = Path(args[args.index('-pf') + 1])
            pid_file.write_text(f'{pid}\n')
            pid_file.chmod(0o600)
            self.clients.append({'pid': pid, 'uid': 0, 'exe': '/usr/sbin/dhclient', 'start_ticks': '222',
                                 'netns': os.readlink('/proc/self/ns/net'), 'args': args})
            if self.host.lease == expected:
                ack = Path(env['HERDR_EXPOSURE_ACK_FILE'])
                ack.write_text(json.dumps({'marker': env['HERDR_EXPOSURE_MARKER'], 'address': expected}))
                ack.chmod(0o600)
            return ''
        self.host.run = run

    def adopt(self, **kw):
        values = {'name': 'xiqfwd0', 'parent': 'eth0', 'network': 'agentbr0', 'project': 'default',
                  'target': '10.77.10.20', 'ports': 'all', 'legacy_dhcp_pid': 12345}
        values.update(kw)
        return self.ctl.adopt(**values)

    def test_adopt_preserves_resources_and_hands_off_dhcp(self):
        self.legacy_exposure()
        original_link = copy.deepcopy(self.host.links['xiqfwd0'])
        record = self.adopt()
        self.assertEqual('ready', record['stage'])
        self.assertEqual(self.host.lease, record['address'])
        for key in ('ifindex', 'address', 'link', 'linkinfo'):
            self.assertEqual(original_link[key], self.host.links['xiqfwd0'][key])
        self.assertEqual('10.77.10.20', self.host.forwards[0]['config']['target_address'])
        self.assertEqual([], self.host.forwards[0]['ports'])
        self.assertEqual(record['marker'], self.host.links['xiqfwd0']['ifalias'])
        self.assertEqual(record['marker'], self.host.forwards[0]['description'])
        self.assertEqual(22222, self.clients[0]['pid'])
        calls = [c[0] for c in self.host.mutations()]
        self.assertFalse(any('delete' in c or 'add' in c or '-r' in c for c in calls))
        self.assertIn('send dhcp-requested-address 192.0.2.40;',
                      (self.ctl.root / 'xiqfwd0.dhcp/dhclient.conf').read_text())
        self.assertEqual('ready', self.ctl.status('xiqfwd0')[0]['status'])
        self.host.calls.clear()
        self.adopt()
        self.assertEqual([], self.host.mutations())
        self.assertEqual(1, len(self.prompts))

    def test_apparmor_failure_blocks_before_resource_claim_or_dhcp_stop(self):
        self.legacy_exposure()
        self.preflight.side_effect = self.mod.ExposureError('AppArmor policy missing')
        for action in (self.adopt, self.create, lambda: self.ctl.delete('xiqfwd0')):
            with self.assertRaisesRegex(self.mod.ExposureError, 'AppArmor'):
                action()
        self.assertEqual([], self.host.mutations())
        self.assertEqual([self.legacy], self.clients)
        self.assertFalse(self.ctl.root.exists())

    def test_adopt_cancellation_does_not_claim_resources(self):
        self.legacy_exposure()
        self.answer = False
        with self.assertRaisesRegex(self.mod.ExposureError, 'cancel'):
            self.adopt()
        self.assertEqual([], self.host.mutations())
        self.assertFalse(self.ctl.root.exists())

    def test_adopt_rejects_mismatched_expectations(self):
        for change in ({'parent': 'other'}, {'target': '10.77.10.21'}, {'ports': 'tcp:443'},
                       {'legacy_dhcp_pid': 999}, {'name': 'xiqfwd0;id'}):
            with self.subTest(change=change):
                self.legacy_exposure()
                with self.assertRaises((self.mod.ExposureError, ValueError)):
                    self.adopt(**change)
                self.assertEqual([], self.host.mutations())

    def test_adopt_rejects_claimed_or_ambiguous_resources(self):
        for drift in ('alias', 'description', 'address', 'duplicate', 'mode', 'client'):
            with self.subTest(drift=drift):
                self.legacy_exposure()
                if drift == 'alias':
                    self.host.links['xiqfwd0']['ifalias'] = 'another-owner'
                elif drift == 'description':
                    self.host.forwards[0]['description'] = 'another-owner'
                elif drift == 'address':
                    self.host.addresses['xiqfwd0'].append('192.0.2.41')
                elif drift == 'duplicate':
                    self.host.forwards.append(copy.deepcopy(self.host.forwards[0]))
                elif drift == 'mode':
                    self.host.links['xiqfwd0']['linkinfo']['info_data']['mode'] = 'private'
                else:
                    self.clients.append(dict(self.legacy, pid=99999))
                with self.assertRaises(self.mod.ExposureError):
                    self.adopt()
                self.assertEqual([], self.host.mutations())

    def test_adopt_rejects_resource_or_pid_changes_during_confirmation(self):
        for drift in ('forward', 'ifindex', 'pid'):
            with self.subTest(drift=drift):
                self.legacy_exposure()
                def confirm(message, drift=drift):
                    if drift == 'forward':
                        self.host.forwards[0]['config']['target_address'] = '10.77.10.99'
                    elif drift == 'ifindex':
                        self.host.links['xiqfwd0']['ifindex'] = 999
                    else:
                        self.clients[0]['start_ticks'] = 'reused'
                    return True
                self.ctl.confirm = confirm
                with self.assertRaises(self.mod.ExposureError):
                    self.adopt()
                self.assertEqual([], self.host.mutations())
                self.assertFalse(self.ctl.root.exists())

    def test_adopt_handoff_failure_is_resumable_and_blocks_other_mutations(self):
        self.legacy_exposure()
        self.host.fail = lambda a: a[0] == 'dhclient'
        with self.assertRaises(RuntimeError):
            self.adopt()
        self.assertEqual('adopting', self.ctl.load('xiqfwd0')['stage'])
        self.assertEqual([self.host.lease], self.host.addresses['xiqfwd0'])
        self.assertEqual('10.77.10.20', self.host.forwards[0]['config']['target_address'])
        self.host.calls.clear()
        for operation in (lambda: self.create(name='xiqfwd0'),
                          lambda: self.ctl.update('xiqfwd0', target='10.77.10.21'),
                          lambda: self.ctl.delete('xiqfwd0')):
            with self.assertRaises(self.mod.ExposureError):
                operation()
        self.assertEqual([], self.host.mutations())
        self.host.fail = None
        self.assertEqual('ready', self.adopt()['stage'])

    def test_adopt_never_trusts_dhcp_exit_without_matching_ack(self):
        self.legacy_exposure()
        self.host.lease = '192.0.2.99'
        with self.assertRaisesRegex(self.mod.ExposureError, 'ACK|lease'):
            self.adopt()
        self.assertEqual('adopting', self.ctl.load('xiqfwd0')['stage'])
        self.assertEqual(['192.0.2.40'], self.host.addresses['xiqfwd0'])
        self.assertEqual('192.0.2.40', self.host.forwards[0]['listen_address'])

    def test_adopt_final_record_write_failure_does_not_repeat_handoff(self):
        self.legacy_exposure()
        save = self.ctl.save
        def fail_final(record):
            if record['stage'] == 'ready':
                raise RuntimeError('crash after DHCP handoff')
            save(record)
        with mock.patch.object(self.ctl, 'save', side_effect=fail_final), self.assertRaises(RuntimeError):
            self.adopt()
        self.host.calls.clear()
        self.assertEqual('ready', self.adopt()['stage'])
        self.assertEqual([], self.host.mutations())

    def test_adopt_ready_requires_running_managed_dhcp(self):
        self.legacy_exposure()
        self.adopt()
        self.clients.clear()
        self.host.calls.clear()
        with self.assertRaisesRegex(self.mod.ExposureError, 'DHCP|client'):
            self.adopt()
        self.assertEqual([], self.host.mutations())

    def test_adopted_exposure_can_be_updated_and_deleted(self):
        self.legacy_exposure()
        self.adopt()
        self.ctl.update('xiqfwd0', ports='tcp:443')
        self.ctl.delete('xiqfwd0')
        self.assertNotIn('xiqfwd0', self.host.links)
        self.assertEqual([], self.host.forwards)
        self.assertIsNone(self.ctl.load('xiqfwd0'))

    def test_adopt_forward_tag_failure_is_resumable(self):
        self.legacy_exposure()
        self.host.fail = lambda a: a[0] == 'incus' and 'edit' in a
        with self.assertRaises(RuntimeError):
            self.adopt()
        self.assertEqual([self.legacy], self.clients)
        self.host.fail = None
        self.assertEqual('ready', self.adopt()['stage'])

    def test_cli_help_never_needs_privileges(self):
        result = subprocess.run(['python3', str(SOURCE), '--help'], capture_output=True, text=True, check=False)
        self.assertEqual(0, result.returncode, result.stderr)
        for verb in ('create', 'update', 'delete', 'list', 'status'):
            self.assertIn(verb, result.stdout)


class ProcessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load(SOURCE, 'exposure_process')

    def identity(self, **kw):
        value = {'pid': 12345, 'uid': 0, 'exe': '/usr/sbin/dhclient', 'start_ticks': '123',
                 'netns': 'net:[123]', 'args': ['dhclient', '-v', '-lf', '/run/xiqfwd/lease',
                 '-pf', '/run/xiqfwd/pid', '-sf', '/bin/true', 'xiqfwd0']}
        value.update(kw)
        return value

    def test_legacy_client_validation_is_narrow_and_namespace_scoped(self):
        with mock.patch.object(self.mod.os, 'readlink', return_value='net:[123]'):
            self.mod.validate_legacy_client(self.identity(), 'xiqfwd0')
            for change in ({'uid': 1000}, {'exe': '/untrusted/dhclient'}, {'netns': 'net:[999]'},
                           {'args': ['dhclient', '-sf', '/untrusted/hook', 'xiqfwd0']}):
                with self.subTest(change=change), self.assertRaises(self.mod.ExposureError):
                    self.mod.validate_legacy_client(self.identity(**change), 'xiqfwd0')

    def test_pid_reuse_after_pidfd_open_never_signals_a_process(self):
        identity = self.identity()
        with (mock.patch.object(self.mod.os, 'pidfd_open', return_value=99),
              mock.patch.object(self.mod.os, 'close') as close,
              mock.patch.object(self.mod.signal, 'pidfd_send_signal') as send,
              mock.patch.object(self.mod, 'process_identity', return_value=self.identity(start_ticks='reused')),
              self.assertRaisesRegex(self.mod.ExposureError, 'identity changed')):
            self.mod.stop_legacy_client(identity)
        send.assert_not_called()
        close.assert_called_once_with(99)

    def test_pidfd_stop_targets_verified_process_and_waits_for_exit(self):
        identity = self.identity()
        poll = mock.Mock()
        poll.poll.return_value = [(99, 1)]
        with (mock.patch.object(self.mod.os, 'pidfd_open', return_value=99),
              mock.patch.object(self.mod.os, 'close'),
              mock.patch.object(self.mod.signal, 'pidfd_send_signal') as send,
              mock.patch.object(self.mod.select, 'poll', return_value=poll),
              mock.patch.object(self.mod, 'process_identity', return_value=identity)):
            self.mod.stop_legacy_client(identity)
        send.assert_called_once_with(99, self.mod.signal.SIGTERM)
        poll.poll.assert_called_once_with(5000)


class DHCPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load(SOURCE.with_name('sandbox-exposure-dhcp.py'), 'dhcp_hook')

    def run_hook(self, reason='BOUND', **overrides):
        env = {'interface': 'xiqfwd1', 'HERDR_EXPOSURE_INTERFACE': 'xiqfwd1',
               'HERDR_EXPOSURE_MARKER': 'owned-marker', 'reason': reason,
               'new_ip_address': '192.0.2.40', 'new_subnet_mask': '255.255.255.0'}
        env.update(overrides)
        calls = []
        def run(args):
            calls.append(args)
            if args[:4] == ['ip', '-details', '-json', 'link']:
                return json.dumps([{'ifname': 'xiqfwd1', 'ifalias': 'owned-marker'}])
            if args[:4] == ['ip', '-json', '-4', 'addr']:
                return json.dumps([{'addr_info': [{'local': '192.0.2.39', 'prefixlen': 24},
                                                  {'local': '192.0.2.40', 'prefixlen': 24}]}])
            return ''
        self.mod.configure(env, run)
        return calls

    def test_invalid_link_inventory_is_reported_before_address_changes(self):
        env = {'interface': 'xiqfwd1', 'HERDR_EXPOSURE_INTERFACE': 'xiqfwd1', 'reason': 'BOUND'}
        for error in ('not-json', OSError('ip unavailable'), subprocess.CalledProcessError(1, ['ip'])):
            command = mock.Mock()
            if isinstance(error, Exception):
                command.side_effect = error
            else:
                command.return_value = error
            with self.subTest(error=error), self.assertRaisesRegex(RuntimeError, 'DHCP.*link inventory') as caught:
                self.mod.configure(env, command)
            self.assertIsNotNone(caught.exception.__cause__)
            command.assert_called_once_with(['ip', '-details', '-json', 'link', 'show'])

    def test_bound_sets_address_not_routes_or_dns(self):
        calls = self.run_hook()
        self.assertIn(['ip', '-4', 'address', 'replace', '192.0.2.40/24', 'dev', 'xiqfwd1', 'noprefixroute'], calls)
        self.assertFalse(any('route' in a or 'resolv' in ' '.join(a) for a in calls))

    def test_renew_changed_address_removes_only_previous_address(self):
        calls = self.run_hook(reason='RENEW', old_ip_address='192.0.2.39', old_subnet_mask='255.255.255.0')
        self.assertIn(['ip', '-4', 'address', 'delete', '192.0.2.39/24', 'dev', 'xiqfwd1'], calls)
        self.assertFalse(any('flush' in a for a in calls))

    def test_expiry_removes_only_lease_address(self):
        calls = self.run_hook(reason='EXPIRE', old_ip_address='192.0.2.40', old_subnet_mask='255.255.255.0')
        self.assertIn(['ip', '-4', 'address', 'delete', '192.0.2.40/24', 'dev', 'xiqfwd1'], calls)
        self.assertFalse(any('replace' in a for a in calls))

    def test_expiry_without_old_mask_uses_live_prefix(self):
        calls = self.run_hook(reason='EXPIRE', old_ip_address='192.0.2.40')
        self.assertIn(['ip', '-4', 'address', 'delete', '192.0.2.40/24', 'dev', 'xiqfwd1'], calls)

    def test_timeout_and_wrong_marker_are_rejected(self):
        for overrides in ({'reason': 'TIMEOUT'}, {'HERDR_EXPOSURE_MARKER': 'wrong'}):
            with self.subTest(overrides=overrides), self.assertRaises((ValueError, RuntimeError)):
                self.run_hook(**overrides)

    def test_adoption_hook_rejects_changed_offer_before_modifying_address(self):
        with self.assertRaisesRegex((ValueError, RuntimeError), 'address|lease'):
            self.run_hook(HERDR_EXPOSURE_EXPECT_ADDRESS='192.0.2.99')

    def test_adoption_hook_writes_verified_ack(self):
        with tempfile.TemporaryDirectory() as directory:
            ack = Path(directory) / 'ack.json'
            self.run_hook(HERDR_EXPOSURE_EXPECT_ADDRESS='192.0.2.40', HERDR_EXPOSURE_ACK_FILE=str(ack))
            self.assertEqual({'address': '192.0.2.40', 'marker': 'owned-marker'}, json.loads(ack.read_text()))
            calls = self.run_hook(HERDR_EXPOSURE_EXPECT_ADDRESS='192.0.2.40', HERDR_EXPOSURE_ACK_FILE=str(ack))
            self.assertFalse(any('replace' in c or 'delete' in c for c in calls), 'adoption must preserve the address and its connected route')
            ack.unlink()
            self.run_hook(reason='PREINIT', HERDR_EXPOSURE_EXPECT_ADDRESS='192.0.2.40', HERDR_EXPOSURE_ACK_FILE=str(ack))
            self.assertFalse(ack.exists())

    def test_adoption_hook_refuses_changed_subnet_mask(self):
        with self.assertRaisesRegex((ValueError, RuntimeError), 'prefix|subnet'):
            self.run_hook(HERDR_EXPOSURE_EXPECT_ADDRESS='192.0.2.40', new_subnet_mask='255.255.254.0')

    def test_wrong_interface_is_rejected(self):
        with self.assertRaises((ValueError, RuntimeError)):
            self.run_hook(interface='eth0')


if __name__ == '__main__':
    unittest.main()
