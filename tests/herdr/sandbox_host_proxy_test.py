#!/usr/bin/env python3
"""Loopback-only CONNECT tests; no guest, shared helper or live exposure changes."""
import importlib.util
import ipaddress
import json
import socket
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'herdr/.config/herdr-spreader/sandbox_exposure_proxy.py'
SERVER = SOURCE.with_name('sandbox_exposure_proxy_server.py')


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load(SERVER, 'host_proxy_server')

    def setUp(self):
        self.upstream = socket.socket()
        self.upstream.bind(('127.0.0.1', 0))
        self.upstream.listen()
        self.addCleanup(self.upstream.close)
        self.config = {'listen_address': '127.0.0.1', 'listen_port': 3128,
                       'target': '127.0.0.1', 'target_ports': [self.upstream.getsockname()[1]],
                       'client_cidrs': ['127.0.0.0/8'], 'allow_host_probe': False}
        self.server = self.mod.make_server(self.config, address=('127.0.0.1', 0))
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)

    def request(self, authority, method='CONNECT'):
        client = socket.create_connection(self.server.server_address, timeout=2)
        client.settimeout(2)
        client.sendall(f'{method} {authority} HTTP/1.1\r\nHost: test\r\n\r\n'.encode())
        data = b''
        while b'\r\n\r\n' not in data:
            part = client.recv(4096)
            if not part:
                break
            data += part
        return client, data

    def test_allowed_connect_relays_opaque_bytes(self):
        def echo():
            c, _ = self.upstream.accept()
            with c:
                data = c.recv(64)
                c.sendall(data)
        thread = threading.Thread(target=echo, daemon=True)
        thread.start()
        client, headers = self.request(f'127.0.0.1:{self.upstream.getsockname()[1]}')
        with client:
            self.assertIn(b'200 Connection established', headers)
            client.sendall(b'opaque-tls-bytes')
            self.assertEqual(b'opaque-tls-bytes', client.recv(64))
        thread.join(2)

    def test_other_destinations_ports_dns_and_non_connect_are_denied(self):
        for authority, method in [('127.0.0.2:443', 'CONNECT'), ('127.0.0.1:22', 'CONNECT'),
                                  ('localhost:443', 'CONNECT'), ('http://127.0.0.1:443/', 'CONNECT'),
                                  ('http://127.0.0.1/', 'GET')]:
            with self.subTest(authority=authority):
                c, headers = self.request(authority, method)
                c.close()
                self.assertRegex(headers.decode(), r'HTTP/1.1 (403|405)')

    def test_unapproved_client_denied_and_explicit_self_probe_supported(self):
        self.config['client_cidrs'] = ['10.64.195.0/24']
        c, headers = self.request('127.0.0.1:443')
        c.close()
        self.assertIn(b'403', headers)
        self.assertTrue(self.mod.client_allowed('127.0.0.1', dict(self.config, allow_host_probe=True)))
        self.assertFalse(self.mod.client_allowed('10.64.194.1', self.config))


class FakeRunner:
    def __init__(self):
        self.tables = {}
        self.active = set()
        self.calls = []
        self.fail_nft = False

    def run(self, args, data=None):
        self.calls.append((args, data))
        if args[:4] == ['nft', '-j', 'list', 'tables']:
            return json.dumps({'nftables': [{'table': {'family': 'ip', 'name': name}}
                                           for name in self.tables]})
        if args[:4] == ['nft', '-j', 'list', 'table']:
            return json.dumps({'nftables': self.tables[args[-1]]})
        if args[0] == 'nft' and '-f' in args:
            if '-c' in args:
                return ''
            if self.fail_nft:
                raise RuntimeError('injected nft failure')
            assert isinstance(data, str)
            for command in json.loads(data)['nftables']:
                if 'delete' in command:
                    self.tables.pop(command['delete']['table']['name'], None)
                elif 'add' in command:
                    value = command['add']
                    if 'table' in value:
                        self.tables[value['table']['name']] = [value]
                    else:
                        item = next(iter(value.values()))
                        self.tables[item['table']].append(value)
            return ''
        if args[:2] == ['systemctl', 'show']:
            return 'active\n' if args[2] in self.active else 'inactive\n'
        if args[:2] == ['systemctl', 'restart']:
            self.active.add(args[-1])
            return ''
        if args[:2] == ['systemctl', 'disable']:
            self.active.discard(args[-1])
            return ''
        if args[:2] == ['systemctl', 'stop']:
            self.active.discard(args[-1])
            return ''
        if args[:2] in (['systemctl', 'enable'], ['systemctl', 'daemon-reload']):
            return ''
        raise AssertionError(args)


class ManagerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load(SOURCE, 'host_proxy_manager')

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.runner = FakeRunner()
        self.manager = self.mod.ProxyManager(self.root / 'state', self.runner, self.root / 'units')
        self.config = self.mod.normalize_proxy({'enabled': True, 'client_cidrs': ['10.64.195.0/24']})
        self.record = {'name': 'xiqfwd0', 'sandbox': 'emulator-11', 'address': '134.141.48.97',
                       'target': '10.77.10.14', 'marker': 'herdr-sandbox-exposure:xiqfwd0:' + 'a' * 32}

    def test_scoped_create_repeat_adopt_update_and_remove(self):
        self.manager.apply(self.record, self.config)
        unit = 'herdr-sandbox-exposure-proxy-emulator-11.service'
        self.assertIn(unit, self.runner.active)
        self.assertEqual(1, len(self.runner.tables))
        payload = self.manager.server_config(self.record, self.config)
        self.assertEqual('134.141.48.97', payload['listen_address'])
        self.assertEqual([443], payload['target_ports'])
        self.assertNotIn(str(ipaddress.IPv4Address(0)), json.dumps(payload))
        self.runner.calls.clear()
        # A new manager adopts the existing matching owned resources without restart.
        self.mod.ProxyManager(self.root / 'state', self.runner, self.root / 'units').apply(self.record, self.config)
        self.assertFalse(any(args[:2] == ['systemctl', 'restart'] or (args[0] == 'nft' and '-f' in args)
                             for args, _ in self.runner.calls))
        updated = dict(self.record, target='10.77.10.15')
        self.manager.apply(updated, self.config)
        directory = self.root / 'state/xiqfwd0.proxy'
        self.assertEqual('10.77.10.15', json.loads((directory / 'config.json').read_text())['target'])
        self.manager.remove(updated)
        self.assertEqual({}, self.runner.tables)
        self.assertNotIn(unit, self.runner.active)
        self.assertFalse(directory.exists())
        self.manager.remove(updated)

    def test_two_sandboxes_do_not_capture_or_remove_each_other(self):
        second = {'name': 'xiqfwd1', 'sandbox': 'emulator-12', 'address': '134.141.48.98',
                  'target': '10.77.10.15', 'marker': 'herdr-sandbox-exposure:xiqfwd1:' + 'b' * 32}
        self.manager.apply(self.record, self.config)
        self.manager.apply(second, self.config)
        self.assertEqual(2, len(self.runner.tables))
        before = json.dumps(self.runner.tables[self.manager.table_name(second)], sort_keys=True)
        self.manager.remove(self.record)
        self.assertEqual(before, json.dumps(self.runner.tables[self.manager.table_name(second)], sort_keys=True))
        self.assertIn('herdr-sandbox-exposure-proxy-emulator-12.service', self.runner.active)
        for args, _ in self.runner.calls:
            self.assertNotIn('docker', args)
            self.assertFalse(any('cheroot-review' in arg or '134.141.48.68' in arg for arg in args))

    def test_nat_only_matches_own_ip_and_tcp_3128_before_incus(self):
        self.manager.apply(self.record, self.config)
        objects = self.runner.tables[self.manager.table_name(self.record)]
        chains = [row['chain'] for row in objects if 'chain' in row]
        self.assertEqual({'output', 'prerouting'}, {row['hook'] for row in chains})
        self.assertTrue(all(row['prio'] == -110 for row in chains))
        rules = [row['rule'] for row in objects if 'rule' in row]
        self.assertEqual(2, len(rules))
        for row in rules:
            self.assertIn('134.141.48.97', json.dumps(row))
            self.assertIn('3128', json.dumps(row))
            self.assertNotIn('10.77.10.14', json.dumps(row))
            self.assertNotIn('134.141.48.68', json.dumps(row))

    def test_unrecognized_unit_or_nft_table_is_never_adopted(self):
        self.manager.apply(self.record, self.config)
        table = self.manager.table_name(self.record)
        self.runner.tables[table][0]['table']['comment'] = 'another owner'
        with self.assertRaises(self.mod.ProxyError):
            self.manager.remove(self.record)
        self.assertTrue(self.runner.active)
        self.assertIn(table, self.runner.tables)

    def test_nft_failure_stops_only_its_own_helper_and_is_recoverable(self):
        self.runner.fail_nft = True
        with self.assertRaises(self.mod.ProxyError):
            self.manager.apply(self.record, self.config)
        self.assertNotIn('herdr-sandbox-exposure-proxy-emulator-11.service', self.runner.active)
        self.runner.fail_nft = False
        self.manager.apply(self.record, self.config)
        self.assertEqual('ready', self.manager.status(self.record, self.config)['status'])

    def test_config_write_failure_stops_old_target_proxy(self):
        self.manager.apply(self.record, self.config)
        write = self.manager.write
        def fail_config(path, data):
            if path.name == 'config.json':
                raise PermissionError('injected config write failure')
            return write(path, data)
        with mock.patch.object(self.manager, 'write', side_effect=fail_config), self.assertRaises(self.mod.ProxyError):
            self.manager.apply(dict(self.record, target='10.77.10.15'), self.config)
        self.assertNotIn('herdr-sandbox-exposure-proxy-emulator-11.service', self.runner.active)

    def test_foreign_unit_template_is_not_overwritten_or_stopped(self):
        self.manager.apply(self.record, self.config)
        path = self.root / 'units/herdr-sandbox-exposure-proxy-emulator-11.service'
        path.write_text('foreign service')
        path.chmod(0o644)
        self.runner.calls.clear()
        with self.assertRaises(self.mod.ProxyError):
            self.manager.apply(self.record, self.config)
        self.assertEqual([], self.runner.calls)
        self.assertEqual('foreign service', path.read_text())

    def test_invalid_or_open_acl_is_rejected(self):
        for change in ({'client_cidrs': ['0.0.0.0/0']}, {'target_ports': [22]}, {'target_ports': [80]},
                       {'listen_port': 443}, {'client_cidrs': []}, {'typo': 1},
                       {'client_cidrs': ['10.64.195.1/24']}, {'enabled': 'yes'}):
            with self.subTest(change=change), self.assertRaises((ValueError, self.mod.ProxyError)):
                self.mod.normalize_proxy(dict({'enabled': True}, **change))


if __name__ == '__main__':
    unittest.main()
