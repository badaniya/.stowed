"""Per-sandbox host CONNECT proxy and narrowly scoped owned nft exception."""
import contextlib
import ipaddress
import json
import os
import re
import stat
import tempfile
from pathlib import Path


class ProxyError(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise ProxyError(message)


def sandbox_name(value):
    require(isinstance(value, str) and bool(re.fullmatch(r'[a-z][a-z0-9-]{0,62}', value)), 'invalid sandbox name')
    return value


def normalize_proxy(value):
    if value is None:
        return None
    require(isinstance(value, dict), 'proxy must be an object or null')
    allowed = {'enabled', 'listen_port', 'client_cidrs', 'target_ports', 'allow_host_probe'}
    require(not set(value) - allowed, 'unknown proxy config key')
    require(type(value.get('enabled', True)) is bool, 'proxy.enabled must be boolean')
    if not value.get('enabled', True):
        return None
    port = value.get('listen_port', 3128)
    require(type(port) is int and port == 3128, 'host proxy listen_port must be 3128')
    cidrs = value.get('client_cidrs', ['10.64.195.0/24'])
    require(isinstance(cidrs, list) and bool(cidrs), 'proxy client_cidrs must not be empty')
    networks = []
    try:
        for cidr in cidrs:
            require(isinstance(cidr, str), 'client CIDR must be a string')
            network = ipaddress.IPv4Network(cidr, strict=True)
            require(network.prefixlen >= 8 and not network.is_multicast and not network.is_unspecified,
                    'open or invalid proxy client range')
            networks.append(str(network))
    except ValueError as exc:
        raise ProxyError('invalid proxy client CIDR') from exc
    ports = value.get('target_ports', [443])
    require(isinstance(ports, list) and 443 in ports
            and all(type(p) is int and p in (80, 443) for p in ports), 'proxy target_ports may contain only 443 and optional 80')
    probe = value.get('allow_host_probe', True)
    require(type(probe) is bool, 'allow_host_probe must be boolean')
    return {'enabled': True, 'listen_port': port, 'client_cidrs': sorted(set(networks)),
            'target_ports': sorted(set(ports)), 'allow_host_probe': probe}


def canonical_nft(value):
    if isinstance(value, list):
        redundant_tcp = {'match': {'op': '==', 'left': {'meta': {'key': 'l4proto'}}, 'right': 'tcp'}}
        rows = [canonical_nft(row) for row in value
                if (not isinstance(row, dict) or 'metainfo' not in row) and row != redundant_tcp]
        # nft lists all chain declarations before their rules and hides the
        # redundant TCP dependency implied by a typed TCP payload expression.
        if rows and all(isinstance(row, dict) and any(k in row for k in ('table', 'chain', 'rule')) for row in rows):
            def key(row):
                kind = next(k for k in ('table', 'chain', 'rule') if k in row)
                return (('table', 'chain', 'rule').index(kind), row[kind].get('chain', row[kind].get('name', '')))
            rows.sort(key=key)
        return rows
    if isinstance(value, dict):
        return {key: None if key == 'counter' else canonical_nft(item)
                for key, item in value.items() if key not in ('handle', 'index', 'position')}
    return value


class ProxyManager:
    def __init__(self, root, runner, unit_dir=Path('/etc/systemd/system')):
        self.root = Path(root)
        self.runner = runner
        self.unit_dir = Path(unit_dir)
        self.source = Path(__file__).with_name('sandbox_exposure_proxy_server.py')

    def run(self, args, data=None):
        try:
            return self.runner.run(args, data=data)
        except (OSError, RuntimeError) as exc:
            raise ProxyError(str(exc)) from exc

    def json_run(self, args):
        try:
            return json.loads(self.run(args))
        except ValueError as exc:
            raise ProxyError('invalid JSON from proxy resource inventory') from exc

    def ids(self, record):
        name = record['name']
        sandbox = sandbox_name(record['sandbox'])
        require(bool(re.fullmatch(r'xiqfwd(?:0|[1-9][0-9]*)', name)) and len(name) <= 15, 'invalid proxy interface')
        require(bool(re.fullmatch(r'herdr-sandbox-exposure:' + re.escape(name) + r':[a-f0-9]{32}', record['marker'])),
                'invalid proxy ownership marker')
        address = ipaddress.IPv4Address(record['address'])
        require(not (address.is_unspecified or address.is_loopback or address.is_multicast or address.is_link_local),
                'proxy must bind a specific lab address, never a wildcard/loopback address')
        ipaddress.IPv4Address(record['target'])
        return (self.root / f'{name}.proxy', f'herdr-sandbox-exposure-proxy-{sandbox}.service',
                'herdr_sandbox_exposure_' + sandbox.replace('-', '_') + '_proxy')

    def table_name(self, record):
        return self.ids(record)[2]

    def server_config(self, record, config):
        self.ids(record)
        return dict(config, listen_address=record['address'], target=record['target'],
                    marker=record['marker'], sandbox=record['sandbox'])

    def unit_text(self, record):
        directory, _, _ = self.ids(record)
        return (f'# Owned by {record["marker"]}\n[Unit]\n'
                f'Description=herdr-sandbox-exposure CONNECT proxy {record["sandbox"]}\n'
                'After=network-online.target\nWants=network-online.target\n'
                f'ConditionPathExists=/sys/class/net/{record["name"]}\n\n[Service]\n'
                f'Type=notify\nNotifyAccess=main\nDynamicUser=yes\nUser=herdr-{record["name"]}\n'
                f'ExecStart=/usr/bin/python3 -I -B {directory}/server.py --config {directory}/config.json\n'
                'TimeoutStartSec=10\nRestart=on-failure\nRestartSec=5\n'
                'NoNewPrivileges=yes\nCapabilityBoundingSet=\nPrivateTmp=yes\n'
                'ProtectSystem=strict\nProtectHome=yes\nRestrictAddressFamilies=AF_INET AF_UNIX\n'
                '\n[Install]\nWantedBy=multi-user.target\n')

    def nft_objects(self, record):
        _, _, table = self.ids(record)
        result = [{'table': {'family': 'ip', 'name': table, 'comment': record['marker']}}]
        for hook in ('prerouting', 'output'):
            result.append({'chain': {'family': 'ip', 'table': table, 'name': hook,
                                     'type': 'nat', 'hook': hook, 'prio': -110, 'policy': 'accept'}})
            expressions = [
                {'match': {'op': '==', 'left': {'payload': {'protocol': 'ip', 'field': 'daddr'}}, 'right': record['address']}},
                {'match': {'op': '==', 'left': {'meta': {'key': 'l4proto'}}, 'right': 'tcp'}},
                {'match': {'op': '==', 'left': {'payload': {'protocol': 'tcp', 'field': 'dport'}}, 'right': 3128}},
                {'counter': None}, {'dnat': {'addr': record['address'], 'port': 3128}},
            ]
            result.append({'rule': {'family': 'ip', 'table': table, 'chain': hook,
                                    'expr': expressions, 'comment': record['marker']}})
        return result

    def safe(self, path, directory=False):
        info = path.lstat()
        require(info.st_uid == os.geteuid() and not info.st_mode & 0o022
                and (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)),
                f'unsafe proxy resource: {path}')

    def read_json(self, path):
        self.safe(path)
        try:
            return json.loads(path.read_text())
        except (OSError, ValueError) as exc:
            raise ProxyError(f'invalid proxy metadata: {path}') from exc

    def active(self, unit):
        return self.run(['systemctl', 'show', unit, '--property=ActiveState', '--value']).strip() == 'active'

    def inventory(self, record):
        directory, unit, table = self.ids(record)
        unit_path = self.unit_dir / unit
        if directory.exists() or directory.is_symlink():
            self.safe(directory, directory=True)
            entries = list(directory.iterdir())
            require(all(p.name in ('owner.json', 'config.json', 'server.py') for p in entries),
                    'unknown file in proxy directory; refusing adoption/removal')
            for path in entries:
                self.safe(path)
            if entries:
                owner = self.read_json(directory / 'owner.json')
                require(owner == {'marker': record['marker'], 'sandbox': record['sandbox'], 'interface': record['name']},
                        'proxy directory belongs to another owner')
        if unit_path.exists() or unit_path.is_symlink():
            self.safe(unit_path)
            require(unit_path.read_text() == self.unit_text(record), 'proxy unit ownership/template mismatch')
            require((directory / 'owner.json').exists(), 'proxy unit lacks ownership metadata')
        else:
            require(not self.active(unit), 'active proxy unit without verifiable owned unit file')
        tables = self.json_run(['nft', '-j', 'list', 'tables'])['nftables']
        exists = any(row.get('table', {}).get('family') == 'ip' and row['table']['name'] == table for row in tables)
        current = None
        if exists:
            current = self.json_run(['nft', '-j', 'list', 'table', 'ip', table])['nftables']
            owners = [row['table'] for row in current if 'table' in row]
            require(len(owners) == 1 and owners[0].get('comment') == record['marker'], 'proxy nft table belongs to another owner')
        return directory, unit, unit_path, current

    def write(self, path, data):
        if path.exists() or path.is_symlink():
            self.safe(path)
            if path.read_bytes() == data:
                return False
        fd, temporary = tempfile.mkstemp(prefix='.proxy-', dir=path.parent)
        try:
            with os.fdopen(fd, 'wb') as handle:
                os.fchmod(handle.fileno(), 0o644)
                handle.write(data)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        return True

    def nft_transaction(self, commands):
        data = json.dumps({'nftables': commands})
        self.run(['nft', '-c', '-j', '-f', '-'], data=data)
        self.run(['nft', '-j', '-f', '-'], data=data)

    def apply(self, record, config):
        config = normalize_proxy(config)
        require(config is not None, 'apply requires an enabled proxy config')
        directory, unit, unit_path, current = self.inventory(record)
        try:
            self.root.mkdir(mode=0o755, parents=True, exist_ok=True)
            self.safe(self.root, directory=True)
            self.unit_dir.mkdir(mode=0o755, parents=True, exist_ok=True)
            self.safe(self.unit_dir, directory=True)
            directory.mkdir(mode=0o755, exist_ok=True)
            self.safe(directory, directory=True)
            owner = {'marker': record['marker'], 'sandbox': record['sandbox'], 'interface': record['name']}
            desired = self.server_config(record, config)
            changed = self.write(directory / 'owner.json', json.dumps(owner, sort_keys=True).encode())
            changed = self.write(directory / 'config.json', json.dumps(desired, sort_keys=True).encode()) or changed
            changed = self.write(directory / 'server.py', self.source.read_bytes()) or changed
            unit_changed = self.write(unit_path, self.unit_text(record).encode())
            if unit_changed:
                self.run(['systemctl', 'daemon-reload'])
            if changed or unit_changed or not self.active(unit):
                self.run(['systemctl', 'enable', unit])
                self.run(['systemctl', 'restart', unit])
            expected = self.nft_objects(record)
            if canonical_nft(current) != canonical_nft(expected):
                commands = [{'delete': {'table': {'family': 'ip', 'name': self.table_name(record)}}}] if current else []
                commands.extend({'add': row} for row in expected)
                self.nft_transaction(commands)
            self.status(record, config)
        except (OSError, RuntimeError) as exc:
            # Never keep an old-target proxy running after a failed reconcile.
            with contextlib.suppress(ProxyError):
                self.run(['systemctl', 'stop', unit])
            raise ProxyError('host proxy reconcile incomplete; state retained: ' + str(exc)) from exc

    def remove(self, record):
        directory, unit, unit_path, current = self.inventory(record)
        if unit_path.exists():
            self.run(['systemctl', 'disable', '--now', unit])
        if current:
            self.nft_transaction([{'delete': {'table': {'family': 'ip', 'name': self.table_name(record)}}}])
        if unit_path.exists():
            unit_path.unlink()
            self.run(['systemctl', 'daemon-reload'])
        if directory.exists():
            for path in directory.iterdir():
                self.safe(path)
                path.unlink()
            directory.rmdir()

    def status(self, record, config):
        directory, unit, unit_path, current = self.inventory(record)
        require(unit_path.exists() and self.active(unit), 'host proxy unit is not active')
        require(self.read_json(directory / 'config.json') == self.server_config(record, normalize_proxy(config)),
                'host proxy config drift')
        require((directory / 'server.py').read_bytes() == self.source.read_bytes(), 'host proxy executable drift')
        require(canonical_nft(current) == canonical_nft(self.nft_objects(record)), 'host proxy nft drift')
        return {'service': unit, 'table': self.table_name(record), 'listen': f"{record['address']}:3128", 'status': 'ready'}
