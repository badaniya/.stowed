"""Owned, single-sandbox TCP exposure using an existing host address; never changes a NIC."""
import ipaddress
import json
import re
import socket
import uuid
from pathlib import Path


def tcp_ports(value):
    result = set()
    for part in value.split(','):
        match = re.fullmatch(r'tcp:([0-9]+)(?:-([0-9]+))?', part)
        if not match:
            raise ValueError('Shared-address mode requires explicit TCP ports, not all/UDP')
        first, last = int(match[1]), int(match[2] or match[1])
        if not 1 <= first <= last <= 65535 or last - first >= 256:
            raise ValueError('Invalid or excessive TCP port range')
        ports = set(range(first, last + 1))
        if result & ports or len(result | ports) > 256:
            raise ValueError('Overlapping or excessive TCP ports')
        result |= ports
    return sorted(result)


def client_ranges(values):
    if not values:
        raise ValueError('Explicit allowed client CIDRs are required')
    result = []
    for value in values:
        network = ipaddress.IPv4Network(value, strict=True)
        if network.prefixlen < 8 or network.is_multicast or network.is_unspecified:
            raise ValueError('Open/invalid client CIDR')
        result.append(str(network))
    return sorted(set(result))


def validate_record(record):
    name = record['name']
    if (record.get('version') != 1 or record.get('mode') != 'host-address'
            or not re.fullmatch(r'agtsbxfwd(?:0|[1-9][0-9]*)', name) or len(name) > 15
            or not re.fullmatch(r'herdr-sandbox-exposure:' + re.escape(name) + r':[a-f0-9]{32}', record['marker'])
            or record['stage'] not in ('creating', 'ready', 'deleting')):
        raise ValueError('Invalid host-address ownership record')
    for key in ['parent', 'network', 'project']:
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,62}', record[key]):
            raise ValueError('Invalid host-address resource identifier')
    address = ipaddress.IPv4Address(record['address'])
    if address.is_unspecified or address.is_loopback or address.is_multicast or address.is_link_local:
        raise ValueError('Bind a specific existing external address')
    ipaddress.IPv4Address(record['target'])
    tcp_ports(record['ports'])
    client_ranges(record['clients'])


def unit_text(name, marker, directory):
    return (f'# Owned by {marker}\n[Unit]\nDescription=Sandbox host TCP exposure {name}\n'
            'After=network-online.target\nWants=network-online.target\n\n[Service]\n'
            f'ExecStart=/usr/bin/python3 -I -B {directory}/server.py --config {directory}/config.json\n'
            'Type=notify\nNotifyAccess=main\nTimeoutStartSec=10\nRestart=on-failure\nRestartSec=5\n'
            'DynamicUser=yes\nNoNewPrivileges=yes\nCapabilityBoundingSet=CAP_NET_BIND_SERVICE\n'
            'AmbientCapabilities=CAP_NET_BIND_SERVICE\nProtectSystem=strict\nProtectHome=yes\n'
            'PrivateTmp=yes\nRestrictAddressFamilies=AF_INET AF_UNIX AF_NETLINK\n'
            '\n[Install]\nWantedBy=multi-user.target\n')


class HostManager:
    def __init__(self, controller, unit_dir=Path('/etc/systemd/system')):
        self.ctl = controller
        self.unit_dir = Path(unit_dir)
        self.source = Path(__file__).with_name('sandbox_exposure_host_server.py')

    def run(self, args):
        return self.ctl.runner.run(args)

    def paths(self, record):
        validate_record(record)
        directory = self.ctl.root / (record['name'] + '.host')
        unit = 'herdr-sandbox-exposure-host-' + record['name'] + '.service'
        return directory, unit, self.unit_dir / unit

    def config(self, record):
        return {key: record[key] for key in ('marker', 'parent', 'address', 'target', 'clients')} | {'ports': tcp_ports(record['ports'])}

    def inventory(self, record):
        directory, unit, unit_file = self.paths(record)
        if directory.exists() or directory.is_symlink():
            self.ctl.safe_path(directory, directory=True)
            for p in directory.iterdir():
                if p.name not in {'owner.json', 'config.json', 'server.py'}:
                    raise ValueError('Unknown host-exposure resource; refusing overwrite/delete')
                self.ctl.safe_path(p)
            owner = directory / 'owner.json'
            try:
                valid_owner = (not list(directory.iterdir())) or (owner.exists() and json.loads(owner.read_text()) == {'marker': record['marker']})
            except (OSError, ValueError) as exc:
                raise ValueError('Host ownership metadata missing/invalid') from exc
            if not valid_owner:
                raise ValueError('Host service belongs to another owner')
        if unit_file.exists() or unit_file.is_symlink():
            self.ctl.safe_path(unit_file)
            if unit_file.read_text() != unit_text(record['name'], record['marker'], directory):
                raise ValueError('Host service unit ownership/template mismatch')
            if not (directory / 'owner.json').exists():
                raise ValueError('Host unit lacks ownership metadata')
        elif self.active(unit):
            raise ValueError('Active host service lacks an owned unit file')
        return directory, unit, unit_file

    def active(self, unit):
        return self.run(['systemctl', 'show', unit, '--property=ActiveState', '--value']).strip() == 'active'

    def address_present(self, record):
        if record['address'] not in self.ctl.addresses(record['parent']):
            raise ValueError('Selected host/VPN address disappeared; no interface fallback')
        self.ctl.validate_target(record, record['target'])

    def unused_ports(self, record):
        for port in tcp_ports(record['ports']):
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                try:
                    sock.bind((record['address'], port))
                except OSError as exc:
                    raise ValueError(f'Address/port unavailable or occupied: {record["address"]}:{port}') from exc

    def apply(self, record):
        self.address_present(record)
        directory, unit, unit_file = self.inventory(record)
        # Stop only this verified owned unit before changing its binding.
        if unit_file.exists():
            self.run(['systemctl', 'stop', unit])
        self.unused_ports(record)
        self.ctl.ensure_root()
        directory.mkdir(mode=0o755, exist_ok=True)
        self.ctl.safe_path(directory, directory=True)
        for name, data in [('owner.json', json.dumps({'marker': record['marker']})),
                           ('config.json', json.dumps(self.config(record))),
                           ('server.py', self.source.read_text())]:
            (directory / name).write_text(data)
            (directory / name).chmod(0o644)
        unit_file.write_text(unit_text(record['name'], record['marker'], directory))
        unit_file.chmod(0o644)
        self.run(['systemctl', 'daemon-reload'])
        self.run(['systemctl', 'enable', unit])
        try:
            self.run(['systemctl', 'start', unit])
            if not self.active(unit):
                raise ValueError('Host exposure service failed to start')
        except (OSError, RuntimeError, ValueError):
            self.run(['systemctl', 'stop', unit])
            raise
        record['stage'] = 'ready'
        self.ctl.save(record)
        return record

    def create(self, name, parent, network, project, target, ports, address, clients):
        record = self.ctl.load(name)
        if record is None:
            record = {'version': 1, 'mode': 'host-address', 'name': name, 'parent': parent,
                      'network': network, 'project': project, 'target': target, 'ports': ports,
                      'address': address, 'clients': client_ranges(clients), 'stage': 'creating',
                      'marker': 'herdr-sandbox-exposure:' + name + ':' + uuid.uuid4().hex}
            validate_record(record)
            if name in self.ctl.links():
                raise ValueError('Exposure ID is already an interface; refusing adoption')
            self.address_present(record)
            for p in self.ctl.root.glob('agtsbxfwd*.json'):
                other = self.ctl.load(p.stem)
                if other['target'] == target or other.get('address') == address:
                    raise ValueError('Sandbox target or shared address already has an exposure')
            self.unused_ports(record)
            if not self.ctl.confirm(f'Expose {target} through existing {parent} address {address}, {ports}, clients {clients}?'):
                raise ValueError('Cancelled; no changes made')
            self.ctl.save(record)
        else:
            if record['stage'] == 'deleting':
                raise ValueError('Delete is incomplete; repeat delete before creating')
            if record.get('mode') != 'host-address' or any(record[k] != v for k, v in
                    [('parent', parent), ('network', network), ('project', project), ('target', target),
                     ('ports', ports), ('address', address), ('clients', client_ranges(clients))]):
                raise ValueError('Existing exposure differs; update or explicitly delete/recreate')
            if record['stage'] == 'ready':
                self.status(record)
                return record
        return self.apply(record)

    def update(self, record, target=None, ports=None):
        if record['stage'] != 'ready':
            raise ValueError('Exposure is incomplete; repeat create/delete before updating')
        self.status(record)
        target = self.ctl.validate_target(record, target or record['target'])
        ports = ports or record['ports']
        tcp_ports(ports)
        if target == record['target'] and ports == record['ports']:
            self.status(record)
            return record
        if not self.ctl.confirm(f'Switch shared exposure {record["name"]}: {record["target"]} -> {target}, {ports}?'):
            raise ValueError('Cancelled; no changes made')
        for p in self.ctl.root.glob('agtsbxfwd*.json'):
            other = self.ctl.load(p.stem)
            if other['name'] != record['name'] and other['target'] == target:
                raise ValueError('Target already belongs to another exposure')
        record.update(target=target, ports=ports, stage='creating')
        self.ctl.save(record)
        return self.apply(record)

    def delete(self, record):
        directory, unit, unit_file = self.inventory(record)
        if not self.ctl.confirm(f'Delete shared exposure {record["name"]} only; preserve host NIC/address?'):
            raise ValueError('Cancelled; no changes made')
        if unit_file.exists():
            self.run(['systemctl', 'disable', '--now', unit])
            unit_file.unlink()
            self.run(['systemctl', 'daemon-reload'])
        if directory.exists():
            for p in directory.iterdir():
                p.unlink()
            directory.rmdir()
        (self.ctl.root / (record['name'] + '.json')).unlink()

    def status(self, record):
        self.address_present(record)
        directory, unit, unit_file = self.inventory(record)
        if not unit_file.exists() or not self.active(unit):
            raise ValueError('Host exposure service is not active')
        try:
            valid_code = (directory / 'server.py').read_bytes() == self.source.read_bytes()
            valid_config = json.loads((directory / 'config.json').read_text()) == self.config(record)
        except (OSError, ValueError) as exc:
            raise ValueError('Host exposure files missing/invalid') from exc
        if not valid_code:
            raise ValueError('Host exposure server code drift')
        if not valid_config:
            raise ValueError('Host exposure configuration drift')
        return {'name': record['name'], 'mode': 'host-address', 'status': 'ready',
                'parent': record['parent'], 'listen_address': record['address'],
                'target': record['target'], 'ports': record['ports'], 'clients': record['clients'],
                'detail': 'Service readiness, not end-to-end device/certificate verification'}
