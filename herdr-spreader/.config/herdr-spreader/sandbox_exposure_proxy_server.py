#!/usr/bin/python3
"""Owned host-side CONNECT relay. Never decrypts TLS or logs headers/bodies."""
import argparse
import contextlib
import ipaddress
import json
import os
import re
import select
import socket
import stat
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import cast


def client_allowed(peer, config):
    address = ipaddress.IPv4Address(peer)
    if config.get('allow_host_probe') and str(address) == config['listen_address']:
        return True
    return any(address in ipaddress.IPv4Network(cidr) for cidr in config['client_cidrs'])


def relay(client, upstream):
    readers = [client, upstream]
    last = time.monotonic()
    while readers and time.monotonic() - last < 300:
        ready, _, _ = select.select(readers, [], [], 5)
        for source in ready:
            other = upstream if source is client else client
            data = source.recv(65536)
            if not data:
                readers.remove(source)
                with contextlib.suppress(OSError):
                    other.shutdown(socket.SHUT_WR)
            else:
                other.sendall(data)
                last = time.monotonic()


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    server_version = 'herdr-sandbox-exposure'

    def setup(self):
        super().setup()
        self.connection.settimeout(10)

    def log_message(self, format, *args):
        pass

    def do_CONNECT(self):
        config = cast(ProxyServer, self.server).proxy_config
        match = re.fullmatch(r'([0-9.]+):([0-9]{1,5})', self.path)
        allowed = False
        port = 0
        host = ''
        if match and client_allowed(self.client_address[0], config):
            host, port_text = match.groups()
            try:
                port = int(port_text)
                allowed = str(ipaddress.IPv4Address(host)) == config['target'] and port in config['target_ports']
            except ValueError:
                allowed = False
        print(json.dumps({'client': self.client_address[0], 'method': 'CONNECT',
                          'target': host, 'port': port, 'allowed': allowed}), flush=True)
        self.close_connection = True
        if not allowed:
            self.send_error(403)
            return
        try:
            upstream = socket.create_connection((host, port), timeout=5)
        except OSError:
            self.send_error(502)
            return
        with upstream:
            self.send_response(200, 'Connection established')
            self.end_headers()
            self.wfile.flush()
            with contextlib.suppress(OSError):
                relay(self.connection, upstream)

    def unsupported(self):
        self.close_connection = True
        self.send_error(405, 'CONNECT only')

    do_GET = unsupported
    do_POST = unsupported
    do_PUT = unsupported
    do_DELETE = unsupported
    do_HEAD = unsupported
    do_OPTIONS = unsupported


class ProxyServer(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 64
    proxy_config: dict

    def __init__(self, address, config):
        self.proxy_config = config
        self.slots = threading.BoundedSemaphore(64)
        super().__init__(address, Handler)

    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()


def make_server(config, address=None):
    return ProxyServer(address or (config['listen_address'], config['listen_port']), config)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    args = parser.parse_args()
    path = Path(args.config)
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022:
        raise ValueError('proxy config must be a root-owned regular file, not writable by others')
    try:
        config = json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        raise ValueError('unable to read proxy config') from exc
    with make_server(config) as server:
        notify = os.environ.get('NOTIFY_SOCKET')
        if notify:
            with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sender:
                sender.connect('\0' + notify[1:] if notify.startswith('@') else notify)
                sender.sendall(b'READY=1\nSTATUS=Host CONNECT proxy listening')
        server.serve_forever()


if __name__ == '__main__':
    main()
