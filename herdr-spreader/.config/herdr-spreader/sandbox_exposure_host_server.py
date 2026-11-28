#!/usr/bin/env python3
"""TCP-only address-specific relay. No payload logging, no NIC or firewall changes."""
import argparse
import ipaddress
import json
import os
import resource
import select
import signal
import socket
import socketserver
import subprocess
import threading
from pathlib import Path


def relay(client, target, stop):
    with socket.create_connection(target, timeout=10) as backend:
        client.settimeout(300)
        backend.settimeout(300)
        readers = [client, backend]
        while readers and not stop.is_set():
            ready, _, _ = select.select(readers, [], [], 2)
            for source in ready:
                other = backend if source is client else client
                data = source.recv(65536)
                if not data:
                    readers.remove(source)
                    other.shutdown(socket.SHUT_WR)
                else:
                    other.sendall(data)


def address_present(parent, address):
    try:
        r = subprocess.run(['/usr/sbin/ip', '-j', '-4', 'addr', 'show', 'dev', parent],
                           capture_output=True, text=True, timeout=5)
        return r.returncode == 0 and any(a.get('local') == address for link in json.loads(r.stdout)
                                         for a in link.get('addr_info', []))
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return False


def notify_ready():
    path = os.environ.get('NOTIFY_SOCKET')
    if path:
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sock:
            sock.connect('\0' + path[1:] if path.startswith('@') else path)
            sock.sendall(b'READY=1')


def main():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    args = parser.parse_args()
    try:
        config = json.loads(Path(args.config).read_text())
    except (OSError, ValueError) as exc:
        raise ValueError('Missing/invalid host-exposure config') from exc
    address = str(ipaddress.IPv4Address(config['address']))
    target = str(ipaddress.IPv4Address(config['target']))
    clients = [ipaddress.IPv4Network(c, strict=True) for c in config['clients']]
    ports = config['ports']
    if not ports or len(ports) > 256 or any(type(p) is not int or not 1 <= p <= 65535 for p in ports):
        raise ValueError('Invalid TCP ports')
    if not clients or any(c.prefixlen < 8 for c in clients):
        raise ValueError('Explicit client ranges required')
    if not address_present(config['parent'], address):
        raise ValueError('Selected address absent; refusing interface fallback')
    stop = threading.Event()
    slots = threading.BoundedSemaphore(64)

    class Handler(socketserver.BaseRequestHandler):
        def handle(self):
            if not any(ipaddress.IPv4Address(self.client_address[0]) in network for network in clients):
                return
            if not slots.acquire(blocking=False):
                return
            try:
                relay(self.request, (target, self.request.getsockname()[1]), stop)
            except (OSError, TimeoutError):
                pass  # Never log request payloads or credentials.
            finally:
                slots.release()

    class Server(socketserver.ThreadingTCPServer):
        allow_reuse_address = True
        daemon_threads = True
        block_on_close = False

    servers = []
    try:
        for port in ports:
            servers.append(Server((address, port), Handler))
        for server in servers:
            threading.Thread(target=server.serve_forever, daemon=True).start()
        signal.signal(signal.SIGTERM, lambda *_: stop.set())
        signal.signal(signal.SIGINT, lambda *_: stop.set())
        notify_ready()
        while not stop.wait(2):
            if not address_present(config['parent'], address):
                raise RuntimeError('VPN/host address disappeared; stopping owned listeners')
    finally:
        stop.set()
        for server in servers:
            server.shutdown()
            server.server_close()


if __name__ == '__main__':
    main()
