#!/usr/bin/python3
"""Manage owned macvlan/DHCP/Incus exposures; explicit, confirmed legacy adoption."""
import argparse
import contextlib
import fcntl
import ipaddress
import json
import os
import re
import select
import signal
import stat
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any

from sandbox_exposure_proxy import (
    ProxyError,
    ProxyManager,
    normalize_proxy,
    sandbox_name,
)

PROXY_UNSET = object()
STATE = Path('/var/lib/herdr-sandbox-exposure')
PREFIX = 'herdr-sandbox-exposure:'
NAME = re.compile(r'xiqfwd(?:0|[1-9][0-9]*)\Z')
IDENTIFIER = re.compile(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,62}\Z')


class ExposureError(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise ExposureError(message)


def check_dhcp_apparmor(enabled=Path('/sys/module/apparmor/parameters/enabled'),
                        profiles=Path('/sys/kernel/security/apparmor/profiles'),
                        policy=Path('/etc/apparmor.d/local/herdr-sandbox-exposure'),
                        local=Path('/etc/apparmor.d/local/sbin.dhclient'), template=None):
    """Reject the known confined-DHCP failure before changing any network resources.

    This checks our installed policy/version and loaded enforcing child profile;
    it is not a general proof that all possible host security policies permit DHCP.
    """
    try:
        if not enabled.exists() or enabled.read_text().strip() != 'Y':
            return
        loaded = set(profiles.read_text().splitlines())
        parents = {name for name in ('/{,usr/}sbin/dhclient', '/usr/sbin/dhclient', '/sbin/dhclient')
                   if name + ' (enforce)' in loaded}
        if not parents:
            return
        message = ('AppArmor exposure DHCP policy is missing, unsafe, outdated or not loaded; '
                   'install/reload sandbox-exposure-apparmor.conf as documented in SANDBOX_EXPOSURE.md')
        for path in (policy, local):
            info = path.lstat()
            require(stat.S_ISREG(info.st_mode) and info.st_uid == os.geteuid()
                    and not info.st_mode & 0o022, message)
        template = template or Path(__file__).resolve().with_name('sandbox-exposure-apparmor.conf')
        require(policy.read_bytes() == template.read_bytes(), message)
        require('#include <local/herdr-sandbox-exposure>' in {line.strip() for line in local.read_text().splitlines()}, message)
        require(all(name + '//herdr-exposure-hook-v1 (enforce)' in loaded for name in parents), message)
    except OSError as exc:
        raise ExposureError('AppArmor DHCP preflight could not inspect the required policy; see SANDBOX_EXPOSURE.md') from exc


def valid_name(name):
    require(bool(NAME.fullmatch(name)) and len(name) <= 15, 'invalid name: use xiqfwd0, xiqfwd1, ... (max 15 characters)')
    return name


def identifier(value):
    require(bool(IDENTIFIER.fullmatch(value)), f'invalid local identifier: {value}')
    return value


def parse_decimal(value, context):
    try:
        return int(value)
    except ValueError as exc:
        raise ExposureError(f'invalid {context}') from exc


def parse_ports(value):
    if value == 'all':
        return 'all'
    require(bool(value), 'ports must be all or tcp:PORT,udp:START-END')
    result = []
    used = {'tcp': set(), 'udp': set()}
    for item in value.split(','):
        match = re.fullmatch(r'(tcp|udp):([1-9][0-9]{0,4})(?:-([1-9][0-9]{0,4}))?', item)
        if match is None:
            raise ExposureError(f'invalid port entry: {item}')
        protocol, start, end = match.groups()
        first = parse_decimal(start, f'port entry: {item}')
        last = parse_decimal(end or start, f'port entry: {item}')
        require(1 <= first <= last <= 65535, f'invalid port range: {item}')
        numbers = set(range(first, last + 1))
        require(not used[protocol].intersection(numbers), f'overlapping port entry: {item}')
        used[protocol].update(numbers)
        result.append((protocol, first, last))
    return ','.join(f'{proto}:{first}' + (f'-{last}' if first != last else '')
                    for proto, first, last in sorted(result))


def forward_payload(record, target, ports):
    payload = {'description': record['marker'], 'config': {}, 'ports': []}
    if ports == 'all':
        payload['config']['target_address'] = target
    else:
        for entry in ports.split(','):
            protocol, listen = entry.split(':')
            payload['ports'].append({'protocol': protocol, 'listen_port': listen,
                                     'target_address': target, 'target_port': listen})
    return payload


def writable_forward(value):
    return {key: value.get(key, default) for key, default in
            (('description', ''), ('config', {}), ('ports', []))}


def process_command(pid):
    try:
        return Path(f'/proc/{pid}/cmdline').read_bytes().decode().strip('\0').split('\0')
    except FileNotFoundError:
        return None


def process_identity(pid):
    require(isinstance(pid, int) and 1 < pid < 2**31, 'invalid DHCP PID')
    directory = Path(f'/proc/{pid}')
    try:
        start = (directory / 'stat').read_text().rsplit(')', 1)[1].split()[19]
        args = process_command(pid)
        if not args or args == ['']:
            return None
        identity = {'pid': pid, 'uid': directory.stat().st_uid,
                    'exe': os.readlink(directory / 'exe'), 'netns': os.readlink(directory / 'ns/net'),
                    'args': args, 'start_ticks': start}
        require((directory / 'stat').read_text().rsplit(')', 1)[1].split()[19] == start,
                'DHCP PID changed during inspection')
        return identity
    except FileNotFoundError:
        return None


def dhcp_processes(name):
    result = []
    for directory in Path('/proc').iterdir():
        if not directory.name.isdigit():
            continue
        pid = parse_decimal(directory.name, 'process directory PID')
        if pid <= 1:
            continue
        identity = process_identity(pid)
        if identity and name in identity['args'] and (Path(identity['exe']).name == 'dhclient'
                or Path(identity['args'][0]).name == 'dhclient'):
            result.append(identity)
    return sorted(result, key=lambda p: p['pid'])


def validate_legacy_client(identity, name):
    require(identity is not None, 'legacy DHCP process is absent')
    args = identity['args']
    require(bool(args), 'legacy DHCP command is empty')
    prefix = args[:1] + (['-v'] if args[1:2] == ['-v'] else [])
    require(identity['uid'] == 0 and identity['exe'] == os.path.realpath('/usr/sbin/dhclient')
            and identity.get('netns') == os.readlink('/proc/self/ns/net')
            and Path(args[0]).name == 'dhclient'
            and args == prefix + ['-lf', '/run/xiqfwd/lease', '-pf', '/run/xiqfwd/pid', '-sf', '/bin/true', name],
            'unsupported legacy DHCP process; refusing to take over arbitrary clients')


def stop_legacy_client(identity):
    # Hold a kernel handle to the exact process, then recheck identity before signaling.
    require(hasattr(os, 'pidfd_open') and hasattr(signal, 'pidfd_send_signal'), 'adoption requires Linux pidfd support')
    try:
        fd = os.pidfd_open(identity['pid'])
    except ProcessLookupError:
        return
    try:
        current = process_identity(identity['pid'])
        if current is None:
            return
        require(current == identity, 'legacy DHCP PID identity changed; refusing to signal it')
        signal.pidfd_send_signal(fd, signal.SIGTERM)
        poll = select.poll()
        poll.register(fd, select.POLLIN)
        require(bool(poll.poll(5000)), 'legacy DHCP process did not stop; inspect before retrying')
    finally:
        os.close(fd)


class Runner:
    def run(self, args, data=None):
        # Never resolve a user-configured Incus remote or an untrusted executable.
        env = dict(os.environ, PATH='/usr/sbin:/usr/bin:/sbin:/bin', LC_ALL='C')
        try:
            result = subprocess.run(args, input=data, text=True, capture_output=True,
                                    timeout=60 if args[0] == 'dhclient' else 30, env=env, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise ExposureError(f'{args[0]} failed: {exc}') from exc
        if result.returncode:
            raise ExposureError(f'{args[0]} failed ({result.returncode}): {result.stderr.strip()}')
        return result.stdout


class Controller:
    def __init__(self, root, runner, confirm):
        self.root = Path(root)
        self.runner = runner
        self.confirm = confirm
        self.proxy = ProxyManager(self.root, self.runner)

    def resolve_name(self, name, missing_ok=False):
        if NAME.fullmatch(name):
            return name
        sandbox_name(name)
        if self.root.exists():
            self.safe_path(self.root, directory=True)
            matches = [path.stem for path in self.root.glob('xiqfwd*.json')
                       if (record := self.load(path.stem)) is not None and record.get('sandbox') == name]
            if not matches and missing_ok:
                return None
            require(len(matches) == 1, 'sandbox name is unknown or ambiguous')
            return matches[0]
        if missing_ok:
            return None
        raise ExposureError('sandbox name is unknown')

    def unique_target(self, name, target):
        if self.root.exists():
            self.safe_path(self.root, directory=True)
            for path in self.root.glob('xiqfwd*.json'):
                other = self.load(path.stem)
                require(other is None or other['name'] == name or other['target'] != target,
                        'sandbox target is already owned by another exposure')

    def unique_address(self, record):
        try:
            inventory = json.loads(self.runner.run(['ip', '-json', '-4', 'addr', 'show']))
        except (ValueError, OSError) as exc:
            raise ExposureError('unable to verify unique lab address') from exc
        require(not any(link.get('ifname') != record['name'] and any(entry.get('local') == record['address']
                        for entry in link.get('addr_info', [])) for link in inventory),
                'lab address is already assigned to another interface; refusing to capture shared traffic')

    def reconcile_proxy(self, record, proxy=PROXY_UNSET):
        desired = record.get('proxy') if proxy is PROXY_UNSET else normalize_proxy(proxy)
        if proxy is PROXY_UNSET and desired is None and not record.get('proxy_pending'):
            return record
        sandbox_name(record.get('sandbox'))
        self.unique_address(record)
        record.update(proxy=desired, proxy_pending=True)
        self.save(record)
        if desired is None:
            self.proxy.remove(record)
        else:
            self.proxy.apply(record, desired)
        record['proxy_pending'] = False
        self.save(record)
        return record

    def safe_path(self, path, directory=False):
        info = path.lstat()
        require(not stat.S_ISLNK(info.st_mode) and info.st_uid == os.geteuid()
                and not info.st_mode & 0o022, f'unsafe ownership/permissions: {path}')
        require(stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode), f'unsafe file type: {path}')

    def ensure_root(self):
        self.root.mkdir(mode=0o755, parents=True, exist_ok=True)
        self.safe_path(self.root, directory=True)

    @contextlib.contextmanager
    def lock(self):
        self.ensure_root()
        lock_path = self.root / '.lock'
        fd = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        try:
            self.safe_path(lock_path)
            with os.fdopen(fd, 'r+') as handle:
                fd = -1
                try:
                    fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError as exc:
                    raise ExposureError('another exposure operation is running') from exc
                yield
        finally:
            if fd != -1:
                os.close(fd)

    def save(self, record):
        self.ensure_root()
        destination = self.root / f"{valid_name(record['name'])}.json"
        if destination.exists() or destination.is_symlink():
            self.safe_path(destination)
        fd, temporary = tempfile.mkstemp(prefix='.record-', dir=self.root)
        try:
            with os.fdopen(fd, 'w') as handle:
                os.fchmod(handle.fileno(), 0o644)
                json.dump(record, handle, sort_keys=True)
                handle.write('\n')
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, destination)
            directory_fd = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def load(self, name) -> dict[str, Any] | None:
        valid_name(name)
        if not self.root.exists() and not self.root.is_symlink():
            return None
        self.safe_path(self.root, directory=True)
        path = self.root / f'{name}.json'
        if not path.exists() and not path.is_symlink():
            return None
        self.safe_path(path)
        try:
            record = json.loads(path.read_text())
        except (OSError, ValueError) as exc:
            raise ExposureError(f'unable to read ownership record for {name}') from exc
        require(isinstance(record, dict) and record.get('version') == 1 and record.get('name') == name,
                'invalid ownership record')
        require(bool(re.fullmatch(PREFIX + re.escape(name) + r':[0-9a-f]{32}', record.get('marker', ''))),
                'invalid ownership marker')
        for key in ('parent', 'network', 'project'):
            identifier(record[key])
        require(bool(re.fullmatch(r'(?:[0-9a-f]{2}:){5}[0-9a-f]{2}', record['mac'])), 'invalid recorded MAC')
        require(record['stage'] in ('creating', 'adopting', 'ready', 'deleting'), 'invalid recovery stage')
        ipaddress.IPv4Address(record['target'])
        parse_ports(record['ports'])
        if record['address'] is not None:
            ipaddress.IPv4Address(record['address'])
        for key in ('forward', 'pending'):
            payload = record[key]
            require(payload is None or (isinstance(payload, dict) and payload.get('description') == record['marker']),
                    'invalid recorded forward')
        return record

    def links(self):
        try:
            values = json.loads(self.runner.run(['ip', '-details', '-json', 'link', 'show']))
        except json.JSONDecodeError as exc:
            raise ExposureError('ip returned invalid link inventory') from exc
        return {value['ifname']: value for value in values}

    def addresses(self, name):
        try:
            values = json.loads(self.runner.run(['ip', '-json', '-4', 'addr', 'show', 'dev', name]))
        except json.JSONDecodeError as exc:
            raise ExposureError(f'ip returned invalid addresses for {name}') from exc
        return sorted({a['local'] for value in values for a in value.get('addr_info', [])
                       if a.get('family') == 'inet' and a.get('scope') == 'global'})

    def incus(self, record, *args, data=None):
        return self.runner.run(['incus', '--force-local', '--project', record['project'], *args], data=data)

    def validate_target(self, record, target):
        address = ipaddress.IPv4Address(target)
        try:
            networks = json.loads(self.incus(record, 'network', 'list', '--format', 'json'))
        except json.JSONDecodeError as exc:
            raise ExposureError('Incus returned invalid network inventory') from exc
        matches = [n for n in networks if n['name'] == record['network']]
        require(len(matches) == 1, 'network is absent or ambiguous in the selected project')
        bridge = matches[0]
        require(bridge.get('type') == 'bridge' and bridge.get('managed'), 'network must be a managed bridge')
        interface = ipaddress.IPv4Interface(bridge['config']['ipv4.address'])
        require(address in interface.network and address not in
                (interface.ip, interface.network.network_address, interface.network.broadcast_address),
                'target must be a sandbox IPv4 address inside the bridge subnet, not the gateway/network/broadcast')
        require(not address.is_loopback and not address.is_multicast and not address.is_unspecified,
                'target must be unicast IPv4')
        return str(address)

    def owned_link(self, record, links):
        link = links.get(record['name'])
        if link is not None:
            require(link.get('ifalias') == record['marker'] and link.get('address') == record['mac']
                    and link.get('link') == record['parent']
                    and link.get('linkinfo', {}).get('info_kind') == 'macvlan'
                    and link.get('linkinfo', {}).get('info_data', {}).get('mode') == 'bridge',
                    f"interface ownership mismatch: {record['name']}")
        return link

    def forwards(self, record):
        try:
            return json.loads(self.incus(record, 'network', 'forward', 'list', record['network'], '--format', 'json'))
        except json.JSONDecodeError as exc:
            raise ExposureError(f"Incus returned invalid forward inventory for {record['project']}/{record['network']}") from exc

    def owned_forward(self, record):
        if record['address'] is None:
            return None
        values = self.forwards(record)
        matches = [f for f in values if f['listen_address'] == record['address']]
        require(len(matches) <= 1, 'ambiguous forward ownership')
        if not matches:
            return None
        forward = writable_forward(matches[0])
        require(forward['description'] == record['marker'], 'forward address conflict: unmanaged/not owned')
        require(forward in (record['forward'], record['pending']), 'forward drift: configuration changed outside this action')
        return forward

    def dhcp_files(self, record):
        directory = self.root / f"{record['name']}.dhcp"
        directory.mkdir(mode=0o700, exist_ok=True)
        self.safe_path(directory, directory=True)
        for path in directory.iterdir():
            self.safe_path(path)
        hook = directory / 'hook.py'
        if not hook.exists():
            hook.write_bytes(Path(__file__).with_name('sandbox-exposure-dhcp.py').read_bytes())
            hook.chmod(0o700)
        config = directory / 'dhclient.conf'
        if not config.exists():
            requested = f"send dhcp-requested-address {record['address']};\n" if 'adoption' in record else ''
            config.write_text('timeout 30;\nretry 5;\n' + requested
                              + 'request subnet-mask, broadcast-address, dhcp-lease-time, dhcp-renewal-time, dhcp-rebinding-time;\n')
            config.chmod(0o600)
        return directory

    def dhcp(self, record, release=False):
        directory = self.dhcp_files(record)
        pid_file = directory / 'client.pid'
        if pid_file.exists():
            value = pid_file.read_text().strip()
            require(bool(re.fullmatch(r'[1-9][0-9]{0,9}', value)), 'invalid dedicated DHCP PID file')
            pid = parse_decimal(value, 'dedicated DHCP PID')
            args = process_command(pid)
            if args:
                require(Path(args[0]).name == 'dhclient' and args[-1] == record['name']
                        and '-pf' in args and args[args.index('-pf') + 1] == str(pid_file)
                        and '-lf' in args and args[args.index('-lf') + 1] == str(directory / 'client.leases'),
                        'DHCP PID belongs to a different process; refusing to signal it')
                require(release, 'dedicated DHCP process is already running; wait for its lease or delete explicitly')
        extra = []
        if 'adoption' in record:
            extra = ['-e', f"HERDR_EXPOSURE_EXPECT_ADDRESS={record['address']}",
                     '-e', f"HERDR_EXPOSURE_ACK_FILE={directory / 'ack.json'}"]
        self.runner.run(['dhclient', '-4', '-r' if release else '-1',
                         '-pf', str(directory / 'client.pid'), '-lf', str(directory / 'client.leases'),
                         '-cf', str(directory / 'dhclient.conf'), '-sf', str(directory / 'hook.py'),
                         '-e', f"HERDR_EXPOSURE_INTERFACE={record['name']}",
                         '-e', f"HERDR_EXPOSURE_MARKER={record['marker']}", *extra, record['name']])

    def adoption_resources(self, record):
        links = self.links()
        link = links.get(record['name'])
        if link is None:
            raise ExposureError('adoption interface disappeared')
        adoption = record['adoption']
        require(not any(name != record['name'] and other.get('address') == record['mac']
                        for name, other in links.items()), 'adoption MAC is already in use')
        self.unique_address(record)
        require(link.get('ifindex') == adoption['ifindex']
                and link.get('address') == record['mac'] and link.get('link') == record['parent']
                and link.get('ifalias', '') in ('', record['marker'])
                and link.get('linkinfo', {}).get('info_kind') == 'macvlan'
                and link.get('linkinfo', {}).get('info_data', {}).get('mode') == 'bridge',
                'adoption interface identity/ownership changed')
        require(self.addresses(record['name']) == [record['address']], 'adoption address changed or is ambiguous')
        matches = [f for f in self.forwards(record) if f['listen_address'] == record['address']]
        require(len(matches) == 1, 'adoption requires exactly one existing forward')
        forward = writable_forward(matches[0])
        require(forward in (adoption['original_forward'], record['forward']), 'adoption forward drift or another owner')
        legacy = adoption['legacy']
        current = process_identity(legacy['pid'])
        require(current is None or current == legacy, 'legacy DHCP PID identity changed')
        return link, forward

    def adoption_clients(self, record):
        clients = dhcp_processes(record['name'])
        legacy = record['adoption']['legacy']
        require(len(clients) <= 1, 'ambiguous DHCP clients; refusing adoption')
        if not clients or clients == [legacy]:
            return clients
        directory = self.root / f"{record['name']}.dhcp"
        pid_file = directory / 'client.pid'
        require(pid_file.exists(), 'unrecognized DHCP client during adoption')
        self.safe_path(directory, directory=True)
        self.safe_path(pid_file)
        client = clients[0]
        args = client['args']
        expected = ['dhclient', '-4', '-1', '-pf', str(pid_file), '-lf', str(directory / 'client.leases'),
                    '-cf', str(directory / 'dhclient.conf'), '-sf', str(directory / 'hook.py'),
                    '-e', f"HERDR_EXPOSURE_INTERFACE={record['name']}", '-e', f"HERDR_EXPOSURE_MARKER={record['marker']}",
                    '-e', f"HERDR_EXPOSURE_EXPECT_ADDRESS={record['address']}",
                    '-e', f"HERDR_EXPOSURE_ACK_FILE={directory / 'ack.json'}", record['name']]
        require(client['uid'] == 0 and client['exe'] == os.path.realpath('/usr/sbin/dhclient')
                and client.get('netns') == os.readlink('/proc/self/ns/net')
                and str(client['pid']) == pid_file.read_text().strip() and args == expected,
                'unrecognized DHCP client during adoption')
        return clients

    def adoption_ack(self, record):
        path = self.root / f"{record['name']}.dhcp/ack.json"
        require(path.exists(), 'no verified DHCP ACK for the original lease; adoption remains incomplete')
        self.safe_path(path)
        try:
            receipt = json.loads(path.read_text())
        except (OSError, ValueError) as exc:
            raise ExposureError('invalid DHCP ACK receipt; adoption remains incomplete') from exc
        require(receipt == {'marker': record['marker'], 'address': record['address']},
                'DHCP ACK does not match the adopted address/ownership')

    def new_adoption_record(self, name, parent, network, project, target, ports, legacy_dhcp_pid):
        require(hasattr(os, 'pidfd_open') and hasattr(signal, 'pidfd_send_signal'), 'adoption requires Linux pidfd support')
        link = self.links().get(name)
        if link is None or link.get('ifalias'):
            raise ExposureError('adoption requires an existing unmarked interface')
        addresses = self.addresses(name)
        require(len(addresses) == 1, 'adoption requires exactly one IPv4 address')
        address = ipaddress.IPv4Address(addresses[0])
        require(not (address.is_unspecified or address.is_loopback or address.is_multicast or address.is_link_local),
                'adoption requires a unicast DHCP IPv4 address')
        legacy = process_identity(legacy_dhcp_pid)
        validate_legacy_client(legacy, name)
        require(dhcp_processes(name) == [legacy], 'ambiguous or missing legacy DHCP client')
        record = {'version': 1, 'name': name, 'parent': parent, 'network': network, 'project': project,
                  'target': target, 'ports': ports, 'marker': f'{PREFIX}{name}:{uuid.uuid4().hex}',
                  'mac': link['address'], 'address': str(address), 'pending': None, 'stage': 'adopting'}
        record['target'] = self.validate_target(record, target)
        self.unique_target(name, record['target'])
        record['forward'] = forward_payload(record, record['target'], ports)
        record['adoption'] = {'legacy': legacy, 'ifindex': link['ifindex'],
                              'original_forward': dict(record['forward'], description='')}
        return record

    def adopt(self, name, parent, network, project, target, ports, legacy_dhcp_pid):
        check_dhcp_apparmor()
        valid_name(name)
        for value in (parent, network, project):
            identifier(value)
        ports = parse_ports(ports)
        require(isinstance(legacy_dhcp_pid, int) and 1 < legacy_dhcp_pid < 2**31, 'invalid legacy DHCP PID')
        record = self.load(name)
        if record is None:
            record = self.new_adoption_record(name, parent, network, project, target, ports, legacy_dhcp_pid)
        require('adoption' in record and record['stage'] in ('adopting', 'ready'),
                'not an adoption record or deletion already started')
        require(all(record[key] == value for key, value in
                    (('parent', parent), ('network', network), ('project', project), ('target', target), ('ports', ports)))
                and record['adoption']['legacy']['pid'] == legacy_dhcp_pid,
                'adoption arguments differ from the recorded expectations')
        self.validate_target(record, target)
        self.adoption_resources(record)
        clients = self.adoption_clients(record)
        if record['stage'] == 'ready':
            require(clients and clients != [record['adoption']['legacy']], 'managed DHCP client is not running')
            require(self.owned_link(record, self.links()) is not None and self.owned_forward(record) is not None,
                    'adopted resources are degraded')
            self.adoption_ack(record)
            return self.reconcile_proxy(record)
        require(self.confirm(f"Adopt {name} on {parent}: preserve {record['address']} -> {target}, ports {ports}, "
                             f"on {project}/{network}? Mark the existing interface/forward and transfer DHCP from PID "
                             f"{legacy_dhcp_pid} without releasing the lease; a different offered IP will be refused."),
                'cancelled; no adoption changes made')
        link, forward = self.adoption_resources(record)
        self.adoption_clients(record)
        # Save recovery expectations before changing either ownership marker.
        self.save(record)
        self.dhcp_files(record)
        if link.get('ifalias') != record['marker']:
            self.runner.run(['ip', 'link', 'set', 'dev', name, 'alias', record['marker']])
        _, forward = self.adoption_resources(record)
        if forward != record['forward']:
            self.incus(record, 'network', 'forward', 'edit', network, record['address'], data=json.dumps(record['forward']))
        self.adoption_resources(record)
        clients = self.adoption_clients(record)
        if clients == [record['adoption']['legacy']]:
            stop_legacy_client(record['adoption']['legacy'])
            clients = self.adoption_clients(record)
            require(not clients, 'legacy DHCP client is still running')
        if not clients:
            directory = self.dhcp_files(record)
            ack = directory / 'ack.json'
            if ack.exists():
                self.safe_path(ack)
                ack.unlink()
            self.dhcp(record)
        clients = self.adoption_clients(record)
        require(clients and clients != [record['adoption']['legacy']], 'managed DHCP client did not remain running')
        self.adoption_ack(record)
        self.adoption_resources(record)
        require(self.owned_link(record, self.links()) is not None and self.owned_forward(record) is not None,
                'adoption ownership markers changed during handoff')
        record['stage'] = 'ready'
        self.save(record)
        return self.reconcile_proxy(record)

    def create(self, name, parent, network, project, target, ports):
        check_dhcp_apparmor()
        valid_name(name)
        identifier(parent)
        identifier(network)
        identifier(project)
        require(parent != name, 'parent must differ from exposure name')
        ports = parse_ports(ports)
        record = self.load(name)
        links = self.links()
        if record is None:
            require(name not in links, f'unmanaged interface already exists: {name}')
            require(parent in links, f'parent interface is absent: {parent}')
            token = uuid.uuid4().hex
            record = {'version': 1, 'name': name, 'parent': parent, 'network': network, 'project': project,
                      'target': target, 'ports': ports, 'marker': f'{PREFIX}{name}:{token}',
                      'mac': '02:' + ':'.join(token[i:i + 2] for i in range(0, 10, 2)),
                      'address': None, 'forward': None, 'pending': None, 'stage': 'creating'}
            record['target'] = self.validate_target(record, target)
            self.unique_target(name, record['target'])
            self.save(record)
        else:
            require(record['stage'] != 'adopting', 'adoption is incomplete; repeat adopt before other mutations')
            require(record['stage'] != 'deleting', 'delete is incomplete; repeat delete before creating')
            require(all(record[key] == value for key, value in
                        (('parent', parent), ('network', network), ('project', project), ('target', target), ('ports', ports))),
                    'existing exposure differs; use update to retarget/change ports, or delete then recreate')
            self.validate_target(record, target)
        link = self.owned_link(record, links)
        current = self.owned_forward(record)
        if record['stage'] == 'ready':
            require(record['pending'] is None and current == record['forward'],
                    'pending update: repeat update or delete; create cannot reconcile a retarget')
            require(link is not None and current is not None, 'exposure degraded: delete and recreate to repair missing resources')
            require(self.addresses(name) == [record['address']], 'lease address changed; delete and recreate')
            return self.reconcile_proxy(record)
        if link is None:
            require(record['address'] is None, 'exposure interface disappeared; delete and recreate')
            require(not any(other.get('address') == record['mac'] for other in links.values()), 'MAC is already in use')
            self.runner.run(['ip', 'link', 'add', 'link', parent, 'name', name, 'address', record['mac'],
                             'alias', record['marker'], 'type', 'macvlan', 'mode', 'bridge'])
        self.runner.run(['sysctl', '-w', f'net.ipv6.conf.{name}.disable_ipv6=1'])
        self.runner.run(['ip', 'link', 'set', 'dev', name, 'up'])
        addresses = self.addresses(name)
        if not addresses:
            self.dhcp(record)
            addresses = self.addresses(name)
        require(len(addresses) == 1, 'DHCP must provide exactly one global IPv4 address')
        ipaddress.IPv4Address(addresses[0])
        require(record['address'] in (None, addresses[0]), 'lease address changed; delete and recreate')
        record['address'] = addresses[0]
        self.unique_address(record)
        desired = forward_payload(record, target, ports)
        record['pending'] = desired
        self.save(record)
        current = self.owned_forward(record)
        if current is None:
            self.incus(record, 'network', 'forward', 'create', network, record['address'], data=json.dumps(desired))
        elif current != desired:
            raise ExposureError('existing forward differs; use update')
        record.update(forward=desired, pending=None, stage='ready')
        self.save(record)
        return self.reconcile_proxy(record)

    def update(self, name, target=None, ports=None, proxy=PROXY_UNSET):
        record = self.load(name)
        if record is None:
            raise ExposureError('exposure is unmanaged/not owned')
        require(record['stage'] == 'ready', 'exposure is incomplete; repeat create or delete first')
        link = self.owned_link(record, self.links())
        current = self.owned_forward(record)
        if link is None or current is None:
            raise ExposureError('exposure degraded: missing interface/forward')
        require(self.addresses(name) == [record['address']], 'lease address changed; delete and recreate')
        self.unique_address(record)
        target = self.validate_target(record, target if target is not None else record['target'])
        self.unique_target(name, target)
        ports = parse_ports(ports) if ports is not None else record['ports']
        desired = forward_payload(record, target, ports)
        if current != desired:
            active_target = current['config'].get('target_address') or current['ports'][0]['target_address']
            active_ports = 'all' if current['config'].get('target_address') else ','.join(
                f"{p['protocol']}:{p['listen_port']}" for p in current['ports'])
            require(self.confirm(f"Change {name} ({record['address']}) on {record['project']}/{record['network']}: "
                                 f"target {active_target} -> {target}; ports {active_ports} -> {ports}?"), 'cancelled; no changes made')
            # Re-read after the operator's pause, before changing anything.
            require(self.owned_link(record, self.links()) is not None, 'interface disappeared during confirmation')
            require(self.owned_forward(record) == current, 'forward changed during confirmation')
            require(self.addresses(name) == [record['address']], 'lease address changed during confirmation')
            record['pending'] = desired
            self.save(record)
            self.incus(record, 'network', 'forward', 'edit', record['network'], record['address'], data=json.dumps(desired))
        record.update(target=target, ports=ports, forward=desired, pending=None)
        self.save(record)
        return self.reconcile_proxy(record, proxy)

    def delete(self, name):
        check_dhcp_apparmor()
        record = self.load(name)
        require(record is None or record['stage'] != 'adopting', 'adoption is incomplete; repeat adopt before delete')
        links = self.links()
        if record is None:
            require(name not in links, 'interface is unmanaged/not owned; refusing delete')
            return
        link = self.owned_link(record, links)
        current = self.owned_forward(record)
        require(self.confirm(f"Delete {name}: {record['address']} -> recorded target {record['target']}, ports {record['ports']}, "
                             f"on {record['project']}/{record['network']}? Active forward: {json.dumps(current, sort_keys=True)}. "
                             'Release its lease and remove its macvlan?'),
                'cancelled; no changes made')
        self.owned_link(record, self.links())
        require(self.owned_forward(record) == current, 'forward changed during confirmation')
        record['stage'] = 'deleting'
        self.save(record)
        if record.get('proxy') or record.get('proxy_pending'):
            self.proxy.remove(record)
        if current is not None:
            self.incus(record, 'network', 'forward', 'delete', record['network'], record['address'])
        directory = self.root / f'{name}.dhcp'
        if link is not None or directory.exists():
            self.dhcp(record, release=True)
        # Revalidate ownership after DHCP and before removing the interface.
        if self.owned_link(record, self.links()) is not None:
            self.runner.run(['ip', 'link', 'delete', 'dev', name])
        if directory.exists():
            self.safe_path(directory, directory=True)
            allowed = {'client.pid', 'client.leases', 'client.leases~', 'dhclient.conf', 'hook.py', 'ack.json'}
            for path in directory.iterdir():
                require(path.name in allowed, f'unexpected DHCP file; inspect before retrying delete: {path}')
                self.safe_path(path)
                path.unlink()
            directory.rmdir()
        (self.root / f'{name}.json').unlink()

    def status(self, name=None, network='agentbr0', project='default'):
        if name is not None:
            valid_name(name)
        links = self.links()
        names = {n for n in links if NAME.fullmatch(n)}
        if self.root.exists():
            self.safe_path(self.root, directory=True)
            names.update(p.stem for p in self.root.glob('xiqfwd*.json'))
        if name is not None:
            names = {name}
        result = []
        for entry in sorted(names):
            record = self.load(entry)
            addresses = self.addresses(entry) if entry in links else []
            row: dict[str, Any] = {'name': entry, 'status': 'absent', 'addresses': addresses}
            if record is None:
                row['status'] = 'unmanaged' if entry in links else 'absent'
                # Display existing forwards for unmanaged interfaces without adopting them.
                if addresses:
                    values = self.forwards({'project': identifier(project), 'network': identifier(network)})
                    row['forwards'] = [f for f in values if f['listen_address'] in addresses]
            else:
                row.update(network=record['network'], project=record['project'], parent=record['parent'],
                           listen_address=record['address'], target=record['target'], ports=record['ports'],
                           status=record['stage'], stage=record['stage'], pending=record['pending'] is not None,
                           sandbox=record.get('sandbox'), config_id=record.get('config_id'), proxy=record.get('proxy'))
                try:
                    link = self.owned_link(record, links)
                    forward = self.owned_forward(record)
                    row['active_forward'] = forward
                    require(link is not None and forward is not None and addresses == [record['address']]
                            and record['pending'] is None, 'missing resources, changed lease, or incomplete operation')
                    require(not record.get('proxy_pending'), 'host proxy reconcile is pending')
                    if record.get('proxy'):
                        row['proxy_status'] = self.proxy.status(record, record['proxy'])
                except (ExposureError, ProxyError) as exc:
                    row.update(status='degraded', detail=str(exc))
            result.append(row)
        return result


def confirm_tty(message):
    print(message, flush=True)
    try:
        # A buffered r+ stream requires seeking, which a controlling TTY cannot
        # provide. Separate read/write handles work without weakening confirmation.
        with open('/dev/tty', 'w') as output, open('/dev/tty') as input_tty:
            output.write('Type yes to confirm (anything else cancels): ')
            output.flush()
            return input_tty.readline().strip() == 'yes'
    except OSError:
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    for verb in ('create', 'adopt', 'update', 'delete', 'status', 'list'):
        command = sub.add_parser(verb)
        if verb != 'list':
            command.add_argument('name')
        if verb in ('create', 'adopt', 'list', 'status'):
            command.add_argument('--network', default='agentbr0')
            command.add_argument('--project', default='default', help='network project, not the sandbox instance project')
        if verb in ('create', 'adopt'):
            command.add_argument('--parent', required=True)
        if verb == 'adopt':
            command.add_argument('--legacy-dhcp-pid', type=int, required=True)
        if verb in ('create', 'adopt', 'update'):
            command.add_argument('--target', required=verb != 'update')
            command.add_argument('--ports', required=verb != 'update', help='all or tcp:443,udp:5000-5002; update omission preserves policy')
    apply_parser = sub.add_parser('apply', help='reconcile sandbox-keyed desired JSON config')
    apply_parser.add_argument('--config', required=True)
    apply_parser.add_argument('--sandbox', dest='only')
    apply_parser.add_argument('--prune', action='store_true', help='confirm deletion of this config id\'s removed sandboxes')
    args = vars(parser.parse_args())
    action = args.pop('action')
    # State files belong to root, including for a non-root read-only status call.
    ctl = Controller(STATE, Runner(), confirm_tty)
    try:
        if action == 'apply':
            from sandbox_exposure_config import ConfigManager, read_config
            require(os.geteuid() == 0, 'config apply requires root')
            config = read_config(args.pop('config'), parse_ports)
            with ctl.lock():
                result = ConfigManager(ctl).apply(config, **args)
        elif action in ('status', 'list'):
            # State ownership is checked as root; use sudo for status when records exist.
            require(os.geteuid() == 0 or not STATE.exists(), 'run status/list with sudo to inspect root-owned state')
            if 'name' in args:
                args['name'] = ctl.resolve_name(args['name'])
            result = ctl.status(**args)
        else:
            require(os.geteuid() == 0, 'mutations require root: sudo -- python3 sandbox-exposure.py ...')
            with ctl.lock():
                if action != 'create' and 'name' in args:
                    args['name'] = ctl.resolve_name(args['name'], missing_ok=action == 'delete')
                result = None if args.get('name') is None else getattr(ctl, action)(**args)
        print(json.dumps(result, indent=2, sort_keys=True))
    except (ExposureError, ProxyError, ValueError, KeyError, TypeError, OSError) as exc:
        print(f'Error: {exc}. State retained where applicable; inspect status before retrying.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
