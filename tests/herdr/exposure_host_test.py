import importlib.util
import json
import os
import socket
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[2] / 'herdr-spreader/.config/herdr-spreader/sandbox_exposure_host.py'


class HostTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('exposure_host', SOURCE)
        assert spec is not None and spec.loader is not None
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)

    def test_only_explicit_tcp_ports(self):
        self.assertEqual(self.mod.tcp_ports('tcp:443,tcp:8090-8091'), [443, 8090, 8091])
        for value in ['all', 'udp:53', 'tcp:0', 'tcp:443,tcp:443', 'tcp:1-65535']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.mod.tcp_ports(value)

    def test_clients_are_explicit_and_not_open(self):
        self.assertEqual(self.mod.client_ranges(['192.0.2.0/24']), ['192.0.2.0/24'])
        for value in [[], ['0.0.0.0/0'], ['192.0.2.1/24'], ['not-a-cidr']]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.mod.client_ranges(value)

    def test_owned_record_validation(self):
        record = {'version': 1, 'mode': 'host-address', 'name': 'agtsbxfwd0',
                  'parent': 'uplink', 'network': 'agentbr0', 'project': 'default',
                  'address': '192.0.2.10', 'target': '203.0.113.10', 'ports': 'tcp:443',
                  'clients': ['192.0.2.0/24'], 'stage': 'ready',
                  'marker': 'herdr-sandbox-exposure:agtsbxfwd0:' + 'a' * 32}
        self.mod.validate_record(record)
        record['ports'] = 'all'
        with self.assertRaises(ValueError):
            self.mod.validate_record(record)

    def test_desired_config_accepts_host_mode_and_rejects_udp(self):
        sys.path.insert(0, str(SOURCE.parent))
        config_spec = importlib.util.spec_from_file_location('exposure_config', SOURCE.with_name('sandbox_exposure_config.py'))
        assert config_spec is not None and config_spec.loader is not None
        config = importlib.util.module_from_spec(config_spec)
        config_spec.loader.exec_module(config)
        spec = importlib.util.spec_from_file_location('controller', SOURCE.with_name('sandbox-exposure.py'))
        assert spec is not None and spec.loader is not None
        ctl = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ctl)
        entry = {'interface': 'agtsbxfwd0', 'parent': 'uplink', 'target': '203.0.113.10',
                 'ports': 'tcp:443', 'mode': 'host-address', 'address': '192.0.2.10',
                 'clients': ['192.0.2.0/24']}
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / 'config.json'
            p.write_text(json.dumps({'schema_version': 1, 'id': 'fixture', 'sandboxes': {'fixture': entry}}))
            self.assertEqual(config.read_config(p, ctl.parse_ports)['sandboxes']['fixture']['mode'], 'host-address')
            entry['ports'] = 'udp:53'
            p.write_text(json.dumps({'schema_version': 1, 'id': 'fixture', 'sandboxes': {'fixture': entry}}))
            with self.assertRaises(RuntimeError):
                config.read_config(p, ctl.parse_ports)

    def test_occupied_port_is_not_taken_over(self):
        manager = self.mod.HostManager(SimpleNamespace())
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            listener.listen()
            with self.assertRaises(ValueError):
                manager.unused_ports({'address': '127.0.0.1', 'ports': 'tcp:' + str(listener.getsockname()[1])})

    def test_missing_address_does_not_fall_back_to_another_interface(self):
        ctl = SimpleNamespace(addresses=lambda _: [])
        manager = self.mod.HostManager(ctl)
        with self.assertRaisesRegex(ValueError, 'no interface fallback'):
            manager.address_present({'parent': 'uplink', 'address': '192.0.2.10', 'target': '203.0.113.10'})

    def test_failed_service_start_does_not_leave_an_old_target_running(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            host = root / 'host'
            unit = root / 'owned.service'
            calls = []
            def run(args):
                calls.append(args)
                if args[:2] == ['systemctl', 'start']:
                    raise RuntimeError('fixture failure')
                return ''
            ctl = SimpleNamespace(root=root, runner=SimpleNamespace(run=run), ensure_root=lambda: None,
                                  safe_path=lambda *args, **kwargs: None, save=lambda _: self.fail('must not mark ready'))
            manager = self.mod.HostManager(ctl, root)
            record = {'name': 'agtsbxfwd0', 'marker': 'fixture', 'parent': 'uplink', 'address': '192.0.2.10',
                      'target': '203.0.113.10', 'clients': ['192.0.2.0/24'], 'ports': 'tcp:443', 'stage': 'creating'}
            with patch.object(manager, 'address_present'), patch.object(manager, 'unused_ports'), patch.object(manager, 'inventory', return_value=(host, 'owned.service', unit)), self.assertRaises(RuntimeError):
                manager.apply(record)
            self.assertIn(['systemctl', 'stop', 'owned.service'], calls)
            self.assertEqual(record['stage'], 'creating')

    def test_owned_lifecycle_is_idempotent_and_never_changes_nic(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'state'
            units = Path(directory) / 'units'
            root.mkdir()
            units.mkdir()
            calls = []
            active = set()

            class Runner:
                def run(self, args):
                    calls.append(args)
                    if args[:2] == ['systemctl', 'start']:
                        active.add(args[2])
                    elif args[:2] in [['systemctl', 'stop'], ['systemctl', 'disable']]:
                        active.clear()
                    if args[:2] == ['systemctl', 'show']:
                        return 'active' if args[2] in active else 'inactive'
                    return ''

            class Controller:
                runner = Runner()
                def __init__(self):
                    self.root = root
                def load(self, name):
                    p = root / (name + '.json')
                    return json.loads(p.read_text()) if p.exists() else None
                def addresses(self, name):
                    return ['192.0.2.10']
                def validate_target(self, record, target):
                    return target
                def links(self):
                    return {}
                def confirm(self, message):
                    return True
                def ensure_root(self):
                    pass
                def safe_path(self, path, directory=False):
                    assert not path.is_symlink()
                def save(self, record):
                    (root / (record['name'] + '.json')).write_text(json.dumps(record))

            ctl = Controller()
            manager = self.mod.HostManager(ctl, units)
            with patch.object(manager, 'unused_ports'):
                record = manager.create('agtsbxfwd0', 'uplink', 'agentbr0', 'default', '203.0.113.10', 'tcp:443', '192.0.2.10', ['192.0.2.0/24'])
                before = sum('start' in call for call in calls)
                manager.create('agtsbxfwd0', 'uplink', 'agentbr0', 'default', '203.0.113.10', 'tcp:443', '192.0.2.10', ['192.0.2.0/24'])
                self.assertEqual(before, sum('start' in call for call in calls))
                with self.assertRaises(ValueError):
                    manager.create('agtsbxfwd1', 'uplink', 'agentbr0', 'default', '203.0.113.11', 'tcp:8090', '192.0.2.10', ['192.0.2.0/24'])
                manager.update(record, target='203.0.113.11')
                manager.delete(record)
            self.assertFalse((root / 'agtsbxfwd0.json').exists())
            self.assertFalse(any('ip' in call or 'dhclient' in call or 'nft' in call for call in calls))

    def test_real_relay_preserves_half_close_and_rejects_unapproved_client(self):
        class Echo(socketserver.BaseRequestHandler):
            def handle(self):
                chunks = []
                while chunk := self.request.recv(1024):
                    chunks.append(chunk)
                self.request.sendall(b'reply:' + b''.join(chunks))

        with socketserver.ThreadingTCPServer(('127.0.0.2', 0), Echo) as backend, tempfile.TemporaryDirectory() as directory:
            threading.Thread(target=backend.serve_forever, daemon=True).start()
            port = backend.server_address[1]
            p = Path(directory) / 'config.json'
            p.write_text(json.dumps({'parent': 'lo', 'address': '127.0.0.1', 'target': '127.0.0.2',
                                     'clients': ['127.0.0.1/32'], 'ports': [port]}))
            env = dict(os.environ)
            env.pop('NOTIFY_SOCKET', None)
            process = subprocess.Popen([sys.executable, str(SOURCE.with_name('sandbox_exposure_host_server.py')), '--config', str(p)],
                                       env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                for _ in range(60):
                    try:
                        client = socket.create_connection(('127.0.0.1', port), timeout=1)
                        break
                    except OSError:
                        time.sleep(0.05)
                else:
                    self.fail('Relay did not start')
                with client:
                    client.sendall(b'hello')
                    client.shutdown(socket.SHUT_WR)
                    self.assertEqual(client.recv(1024), b'reply:hello')
                with socket.socket() as denied:
                    denied.settimeout(2)
                    denied.bind(('127.0.0.2', 0))
                    denied.connect(('127.0.0.1', port))
                    try:
                        denied.sendall(b'not-allowed')
                        received = denied.recv(1024)
                    except ConnectionResetError:
                        received = b''
                    self.assertEqual(received, b'')
            finally:
                process.terminate()
                stdout, stderr = process.communicate(timeout=5)
                backend.shutdown()
            self.assertNotIn(b'hello', stdout + stderr)

    def test_unit_does_not_need_nic_named_after_exposure(self):
        text = self.mod.unit_text('agtsbxfwd0', 'fixture-owner', Path('/var/lib/fixture'))
        self.assertIn('DynamicUser=yes', text)
        self.assertIn('NoNewPrivileges=yes', text)
        self.assertNotIn('/sys/class/net/agtsbxfwd0', text)
        self.assertNotIn('net_admin', text)


if __name__ == '__main__':
    unittest.main()
