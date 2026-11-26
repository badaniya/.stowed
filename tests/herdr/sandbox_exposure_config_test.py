#!/usr/bin/env python3
import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HELPERS = ROOT / 'herdr-spreader/.config/herdr-spreader'
sys.path.insert(0, str(HELPERS))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load('exposure_config', HELPERS / 'sandbox_exposure_config.py')
        cls.core = load('exposure_core_config_test', HELPERS / 'sandbox-exposure.py')
        cls.base = load('exposure_base_test', ROOT / 'tests/herdr/sandbox_exposure_test.py')

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.host = self.base.FakeHost()
        self.ctl = self.core.Controller(self.root / 'state', self.host, lambda message: True)
        self.ctl.proxy = mock.Mock()
        self.ctl.proxy.status.return_value = {'status': 'ready'}
        patcher = mock.patch.object(self.core, 'check_dhcp_apparmor')
        patcher.start()
        self.addCleanup(patcher.stop)
        self.config = {'schema_version': 1, 'id': 'lab-exposures', 'sandboxes': {'multi-11': {
            'interface': 'agtsbxfwd0', 'parent': 'eth0', 'network': 'agentbr0', 'project': 'default',
            'target': '10.77.10.14', 'ports': 'all',
            'proxy': {'enabled': True, 'client_cidrs': ['192.0.2.0/24']}}}}

    def apply(self, config=None, **kw):
        path = self.root / 'desired.json'
        path.write_text(json.dumps(self.config if config is None else config))
        desired = self.mod.read_config(path, self.core.parse_ports)
        return self.mod.ConfigManager(self.ctl).apply(desired, **kw)

    def test_interface_prefix_and_linux_name_length_boundaries(self):
        path = self.root / 'desired.json'
        for name in ('agtsbxfwd0', 'agtsbxfwd999999'):
            self.config['sandboxes']['multi-11']['interface'] = name
            path.write_text(json.dumps(self.config))
            desired = self.mod.read_config(path, self.core.parse_ports)
            self.assertEqual(name, desired['sandboxes']['multi-11']['interface'])
        for name in ('legacyfwd0', 'agtsbxfwd', 'agtsbxfwd01', 'agtsbxfwd1000000', 'agtsbxfwd١'):
            self.config['sandboxes']['multi-11']['interface'] = name
            path.write_text(json.dumps(self.config))
            with self.subTest(name=name), self.assertRaisesRegex(RuntimeError, 'invalid interface'):
                self.mod.read_config(path, self.core.parse_ports)
        self.assertEqual([], self.host.mutations())

    def test_create_update_remove_proxy_and_prune_by_sandbox(self):
        self.apply()
        record = self.ctl.load('agtsbxfwd0')
        self.assertEqual('multi-11', record['sandbox'])
        self.assertEqual('lab-exposures', record['config_id'])
        self.assertEqual([443], record['proxy']['target_ports'])
        self.assertEqual('agtsbxfwd0', self.ctl.resolve_name('multi-11'))
        self.ctl.proxy.apply.assert_called()
        self.config['sandboxes']['multi-11']['target'] = '10.77.10.15'
        self.apply()
        self.assertEqual('10.77.10.15', self.ctl.proxy.apply.call_args.args[0]['target'])
        del self.config['sandboxes']['multi-11']['proxy']
        self.apply()
        self.ctl.proxy.remove.assert_called()
        self.assertIsNone(self.ctl.load('agtsbxfwd0')['proxy'])
        self.config['sandboxes'].clear()
        self.apply(prune=True)
        self.assertIsNone(self.ctl.load('agtsbxfwd0'))
        self.assertIsNone(self.ctl.resolve_name('multi-11', missing_ok=True))

    def test_apply_adopts_already_managed_interface_without_network_mutation(self):
        self.ctl.create('agtsbxfwd0', 'eth0', 'agentbr0', 'default', '10.77.10.14', 'all')
        self.host.calls.clear()
        self.apply()
        self.assertEqual([], self.host.mutations())
        self.host.calls.clear()
        self.apply()
        self.assertEqual([], self.host.mutations())
        self.assertFalse(self.ctl.load('agtsbxfwd0')['proxy_pending'])

    def test_duplicate_interfaces_targets_and_unknown_keys_rejected_before_mutation(self):
        for field in ('interface', 'target', 'unknown'):
            config = copy.deepcopy(self.config)
            second = dict(config['sandboxes']['multi-11'])
            second.update(interface='agtsbxfwd1', target='10.77.10.15')
            if field == 'unknown':
                second[field] = 'bad'
            else:
                second[field] = config['sandboxes']['multi-11'][field]
            config['sandboxes']['multi-12'] = second
            with self.subTest(field=field), self.assertRaises((ValueError, RuntimeError)):
                self.apply(config)
            self.assertEqual([], self.host.mutations())

    def test_two_instances_and_pruning_never_removes_another_config(self):
        self.apply()
        self.host.lease = '192.0.2.41'
        self.ctl.create('agtsbxfwd2', 'eth0', 'agentbr0', 'default', '10.77.10.16', 'all')
        other = self.ctl.load('agtsbxfwd2')
        other.update(sandbox='other-sandbox', config_id='other-config')
        self.ctl.save(other)
        self.config['sandboxes'].clear()
        self.apply(prune=True)
        self.assertIsNone(self.ctl.load('agtsbxfwd0'))
        self.assertIsNotNone(self.ctl.load('agtsbxfwd2'))

    def test_two_config_entries_create_unique_mac_ip_and_delete_only_one(self):
        entry = self.config['sandboxes']['multi-11']
        self.config['sandboxes']['multi-12'] = dict(entry, interface='agtsbxfwd1', target='10.77.10.15')
        run = self.host.run
        def distinct_dhcp(args, data=None):
            if args[0] == 'dhclient' and '-r' not in args:
                self.host.lease = '192.0.2.40' if args[-1] == 'agtsbxfwd0' else '192.0.2.41'
            return run(args, data=data)
        self.host.run = distinct_dhcp
        self.apply()
        first, second = self.ctl.load('agtsbxfwd0'), self.ctl.load('agtsbxfwd1')
        self.assertNotEqual(first['mac'], second['mac'])
        self.assertNotEqual(first['address'], second['address'])
        self.assertEqual('agtsbxfwd1', self.ctl.resolve_name('multi-12'))
        self.ctl.delete(self.ctl.resolve_name('multi-11'))
        self.assertNotIn('agtsbxfwd0', self.host.links)
        self.assertIn('agtsbxfwd1', self.host.links)
        self.assertEqual(second, self.ctl.load('agtsbxfwd1'))
        self.assertEqual(1, len(self.host.forwards))
        self.assertEqual(second['address'], self.host.forwards[0]['listen_address'])

    def test_direct_update_cannot_steal_another_sandbox_target(self):
        self.apply()
        self.host.lease = '192.0.2.41'
        self.ctl.create('agtsbxfwd1', 'eth0', 'agentbr0', 'default', '10.77.10.15', 'all')
        self.host.calls.clear()
        with self.assertRaises(RuntimeError):
            self.ctl.update('agtsbxfwd0', target='10.77.10.15')
        self.assertEqual([], self.host.mutations())

    def test_proxy_failure_marks_pending_and_blocks_false_ready(self):
        self.ctl.proxy.apply.side_effect = RuntimeError('proxy failed')
        with self.assertRaises(RuntimeError):
            self.apply()
        self.assertTrue(self.ctl.load('agtsbxfwd0')['proxy_pending'])
        self.assertEqual('degraded', self.ctl.status('agtsbxfwd0')[0]['status'])
        self.ctl.proxy.apply.side_effect = None
        self.apply()
        self.assertFalse(self.ctl.load('agtsbxfwd0')['proxy_pending'])

    def test_duplicate_expected_lab_addresses_rejected_before_creation(self):
        first = self.config['sandboxes']['multi-11']
        first['expected_address'] = '203.0.113.97'
        self.config['sandboxes']['multi-12'] = dict(first, interface='agtsbxfwd1', target='10.77.10.15')
        with self.assertRaises(RuntimeError):
            self.apply()
        self.assertEqual([], self.host.mutations())

    def test_delete_stops_proxy_before_interface_removal(self):
        self.apply()
        self.ctl.delete(self.ctl.resolve_name('multi-11'))
        self.ctl.proxy.remove.assert_called()
        self.assertNotIn('agtsbxfwd0', self.host.links)


if __name__ == '__main__':
    unittest.main()
