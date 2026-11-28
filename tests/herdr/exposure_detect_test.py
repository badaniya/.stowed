import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[2] / 'herdr-spreader/.config/herdr-spreader/sandbox_exposure_detect.py'


class DetectTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('exposure_detect', SOURCE)
        assert spec is not None and spec.loader is not None
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.link = {'ifname': 'uplink', 'flags': ['UP', 'BROADCAST'], 'link_type': 'ether'}
        self.addr = {'ifname': 'uplink', 'addr_info': [{'family': 'inet', 'local': '192.0.2.10', 'prefixlen': 24, 'scope': 'global'}]}

    def test_ethernet_is_not_proof_of_dhcp(self):
        row = self.mod.detect([self.link], [self.addr])[0]
        self.assertEqual(row['multiple_address'], 'unverified')
        self.assertIn('DHCP', row['reason'])

    def test_wsl_vpn_like_address_recommends_single(self):
        self.addr['addr_info'][0]['prefixlen'] = 32
        row = self.mod.detect([self.link], [self.addr], wsl=True)[0]
        self.assertEqual(row['recommended_mode'], 'host-address')
        self.assertEqual(row['multiple_address'], 'unverified')

    def test_tun_cannot_supply_l2_macvlan(self):
        self.link['flags'] = ['UP', 'POINTOPOINT']
        self.link['link_type'] = 'none'
        row = self.mod.detect([self.link], [self.addr])[0]
        self.assertEqual(row['multiple_address'], 'not-l2')

    def test_down_or_internal_links_are_not_external_candidates(self):
        self.link['flags'] = []
        self.assertEqual(self.mod.detect([self.link], [self.addr]), [])
        self.link['flags'] = ['UP']
        self.link['linkinfo'] = {'info_kind': 'bridge'}
        self.assertEqual(self.mod.detect([self.link], [self.addr]), [])

    def test_controller_detection_runs_only_inventory_commands(self):
        sys.path.insert(0, str(SOURCE.parent))
        spec = importlib.util.spec_from_file_location('detect_controller', SOURCE.with_name('sandbox-exposure.py'))
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        calls = []
        link, addr = self.link, self.addr

        class Runner:
            def run(self, args, data=None):
                calls.append(args)
                if args == ['ip', '-details', '-json', 'link', 'show']:
                    return json.dumps([link])
                if args == ['ip', '-json', '-4', 'addr', 'show']:
                    return json.dumps([addr])
                raise AssertionError('Unexpected mutation/probe: ' + repr(args))

        with tempfile.TemporaryDirectory() as directory:
            controller = module.Controller(Path(directory) / 'absent-state', Runner(), lambda _: False)
            self.assertEqual(len(controller.detect('uplink')), 1)
        self.assertEqual(len(calls), 2)

    def test_confirmed_probe_cleans_only_its_resources_without_forward(self):
        sys.path.insert(0, str(SOURCE.parent))
        spec = importlib.util.spec_from_file_location('probe_controller', SOURCE.with_name('sandbox-exposure.py'))
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        calls = []

        class Runner:
            def run(self, args, data=None):
                calls.append(args)
                return '{}'

        with tempfile.TemporaryDirectory() as directory, patch.object(module, 'check_dhcp_apparmor'), patch.object(module.shutil, 'which', return_value='/usr/sbin/dhclient'):
            ctl = module.Controller(Path(directory), Runner(), lambda _: True)
            ctl.links = lambda: {'uplink': {'address': '00:11:22:33:44:55'}}
            ctl.validate_target = lambda record, target: target
            ctl.owned_link = lambda record, links: {'owned': True}
            ctl.addresses = lambda name: ['192.0.2.11'] if name.startswith('agts') else ['192.0.2.10']
            def dhcp(record, release=False):
                (Path(directory) / (record['name'] + '.dhcp')).mkdir(exist_ok=True)
                calls.append(['dhcp-release' if release else 'dhcp-acquire'])
            ctl.dhcp = dhcp
            result = ctl.probe('agtsbxfwd0', 'uplink', 'agentbr0', 'default', '203.0.113.10')
            self.assertTrue(result['success'])
            self.assertFalse((Path(directory) / 'agtsbxfwd0.json').exists())
            self.assertIn(['dhcp-release'], calls)
            self.assertFalse(any('forward' in command for command in calls))

    def test_verified_existing_lease_is_evidence_not_unlimited_capacity(self):
        records = [{'parent': 'uplink', 'status': 'ready', 'listen_address': '192.0.2.11'}]
        row = self.mod.detect([self.link], [self.addr], healthy=records)[0]
        self.assertEqual(row['multiple_address'], 'existing-lease-verified')
        self.assertIn('capacity', row['reason'])


if __name__ == '__main__':
    unittest.main()
