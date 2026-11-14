#!/usr/bin/env python3
"""Kernel NAT regression in a new network namespace only; never edits host rules."""
import importlib.util
import json
import os
import shutil
import socket
import subprocess
import sys
import threading
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'herdr-spreader/.config/herdr-spreader/sandbox_exposure_proxy.py'


def child(parent_netns):
    if os.readlink('/proc/self/ns/net') == parent_netns:
        raise RuntimeError('refusing NAT test in the parent network namespace')
    spec = importlib.util.spec_from_file_location('proxy_nat_test', SOURCE)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    subprocess.run(['ip', 'link', 'set', 'lo', 'up'], check=True)
    for suffix in range(2, 7):
        subprocess.run(['ip', 'addr', 'add', f'198.18.0.{suffix}/32', 'dev', 'lo'], check=True)
    sockets = []
    for address, port, label in [('198.18.0.2', 3128, b'HOST1'), ('198.18.0.3', 3128, b'GUEST1'),
                                 ('198.18.0.4', 3128, b'HOST2'), ('198.18.0.5', 3128, b'GUEST2'),
                                 ('198.18.0.3', 9000, b'INLETS1'), ('198.18.0.6', 3128, b'SHARED')]:
        server = socket.socket()
        server.bind((address, port))
        server.listen()
        sockets.append(server)
        def serve(server=server, label=label):
            while True:
                connection, _ = server.accept()
                with connection:
                    connection.sendall(label)
        threading.Thread(target=serve, daemon=True).start()
    for address, label in [('198.18.0.2', b'HOST-UDP'), ('198.18.0.3', b'GUEST-UDP')]:
        udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        udp.bind((address, 3128))
        sockets.append(udp)
        def serve_udp(server=udp, value=label):
            while True:
                _, peer = server.recvfrom(1024)
                server.sendto(value, peer)
        threading.Thread(target=serve_udp, daemon=True).start()
    subprocess.run(['nft', '-f', '-'], input='table ip later {\n chain out {\n type nat hook output priority -100;\n ip daddr 198.18.0.2 dnat to 198.18.0.3\n ip daddr 198.18.0.4 dnat to 198.18.0.5\n }\n}\n', text=True, check=True)
    def probe(address, port=3128):
        with socket.create_connection((address, port), timeout=2) as connection:
            return connection.recv(32)
    def transaction(commands):
        subprocess.run(['nft', '-j', '-f', '-'], input=json.dumps({'nftables': commands}), text=True, check=True)
    manager = module.ProxyManager(Path('/unused-test-root'), None)
    first = {'name': 'xiqfwd0', 'sandbox': 'test-one', 'address': '198.18.0.2', 'target': '198.18.0.3',
             'marker': 'herdr-sandbox-exposure:xiqfwd0:' + 'a' * 32}
    second = {'name': 'xiqfwd1', 'sandbox': 'test-two', 'address': '198.18.0.4', 'target': '198.18.0.5',
              'marker': 'herdr-sandbox-exposure:xiqfwd1:' + 'b' * 32}
    assert probe(first['address']) == b'GUEST1'
    assert probe(second['address']) == b'GUEST2'
    for record in (first, second):
        transaction([{'add': row} for row in manager.nft_objects(record)])
        actual = json.loads(subprocess.check_output(['nft', '-j', 'list', 'table', 'ip', manager.table_name(record)]))['nftables']
        assert module.canonical_nft(actual) == module.canonical_nft(manager.nft_objects(record)), json.dumps(actual)
    assert probe(first['address']) == b'HOST1'
    assert probe(second['address']) == b'HOST2'
    assert probe(first['address'], 9000) == b'INLETS1'
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp_client:
        udp_client.settimeout(2)
        udp_client.sendto(b'udp-not-a-proxy', (first['address'], 3128))
        assert udp_client.recv(64) == b'GUEST-UDP', 'proxy exception captured non-TCP traffic'
    assert probe('198.18.0.6') == b'SHARED'
    transaction([{'delete': {'table': {'family': 'ip', 'name': manager.table_name(first)}}}])
    assert probe(first['address']) == b'GUEST1'
    assert probe(second['address']) == b'HOST2'
    assert probe('198.18.0.6') == b'SHARED'
    print('PASS: isolated kernel NAT, two instances, scoped removal, other ports/shared IP unchanged')


class KernelNatTests(unittest.TestCase):
    @unittest.skipUnless(os.geteuid() == 0 and all(shutil.which(x) for x in ('unshare', 'nft', 'ip')), 'root + unshare/nft/ip required')
    def test_scoped_host_proxy_exceptions(self):
        result = subprocess.run(['unshare', '--net', sys.executable, '-B', str(Path(__file__).resolve()),
                                 '--child', os.readlink('/proc/self/ns/net')],
                                capture_output=True, text=True, timeout=20, check=False)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn('PASS:', result.stdout)


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--child':
        child(sys.argv[2])
    else:
        unittest.main()
