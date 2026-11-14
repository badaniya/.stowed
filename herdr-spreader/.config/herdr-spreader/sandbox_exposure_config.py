"""Desired, sandbox-keyed exposure configuration; explicit scoped pruning."""
import ipaddress
import json
from pathlib import Path
from typing import Any

from sandbox_exposure_proxy import ProxyError, normalize_proxy, require, sandbox_name


def read_config(path, parse_ports):
    try:
        config = json.loads(Path(path).read_text())
    except (OSError, ValueError) as exc:
        raise ProxyError('unable to read exposure config JSON') from exc
    require(isinstance(config, dict) and set(config) == {'schema_version', 'id', 'sandboxes'}, 'invalid exposure config keys')
    require(type(config['schema_version']) is int and config['schema_version'] == 1, 'unsupported config schema_version')
    sandbox_name(config['id'])
    require(isinstance(config['sandboxes'], dict), 'sandboxes must be an object keyed by sandbox name')
    interfaces, targets, addresses = set(), set(), set()
    result = {}
    allowed = {'interface', 'parent', 'network', 'project', 'target', 'ports', 'expected_address', 'proxy', 'legacy_dhcp_pid'}
    for name, value in config['sandboxes'].items():
        sandbox_name(name)
        require(isinstance(value, dict) and not set(value) - allowed, f'unknown config key for {name}')
        require({'interface', 'parent', 'target', 'ports'} <= set(value), f'missing exposure settings for {name}')
        interface = value['interface']
        require(isinstance(interface, str) and interface.startswith('xiqfwd') and len(interface) <= 15, 'invalid interface')
        suffix = interface[6:]
        require(suffix.isascii() and suffix.isdecimal() and (suffix == '0' or not suffix.startswith('0')), 'invalid interface')
        target = str(ipaddress.IPv4Address(value['target']))
        require(interface not in interfaces and target not in targets, 'interfaces and sandbox targets must be unique')
        interfaces.add(interface)
        targets.add(target)
        entry: dict[str, Any] = dict(value, target=target, network=value.get('network', 'agentbr0'), project=value.get('project', 'default'),
                     ports=parse_ports(value['ports']), proxy=normalize_proxy(value.get('proxy')))
        if entry.get('expected_address') is not None:
            entry['expected_address'] = str(ipaddress.IPv4Address(entry['expected_address']))
            require(entry['expected_address'] not in addresses, 'expected lab addresses must be unique')
            addresses.add(entry['expected_address'])
        if 'legacy_dhcp_pid' in entry:
            require(type(entry['legacy_dhcp_pid']) is int and 1 < entry['legacy_dhcp_pid'] < 2**31, 'invalid legacy DHCP PID')
        result[name] = entry
    return dict(config, sandboxes=result)


class ConfigManager:
    def __init__(self, controller):
        self.ctl = controller

    def records(self):
        if not self.ctl.root.exists():
            return []
        self.ctl.safe_path(self.ctl.root, directory=True)
        return [self.ctl.load(path.stem) for path in self.ctl.root.glob('xiqfwd*.json')]

    def preflight(self, config, selected):
        for sandbox, entry in selected.items():
            for key in ('parent', 'network', 'project'):
                value = entry[key]
                require(isinstance(value, str) and len(value) <= 63 and value
                        and value[0].isalnum() and all(c.isascii() and (c.isalnum() or c in '_.-') for c in value),
                        'invalid network identifier')
            self.ctl.validate_target({'network': entry['network'], 'project': entry['project']}, entry['target'])
            for record in self.records():
                if record['name'] == entry['interface']:
                    require(record.get('sandbox') in (None, sandbox), 'interface belongs to a different sandbox')
                    require(record.get('config_id') in (None, config['id']), 'interface belongs to a different config')
                    require(all(record[key] == entry[key] for key in ('parent', 'network', 'project')),
                            'changing parent/network/project requires explicit delete and recreate')
                    if not record.get('sandbox'):
                        require(record['target'] == entry['target'] and record['ports'] == entry['ports'],
                                'adopting an existing managed interface must preserve its current target and ports')
                    if entry.get('expected_address') and record.get('address'):
                        require(entry['expected_address'] == record['address'], 'expected lab address differs from owned lease')
                else:
                    require(record.get('sandbox') != sandbox, 'sandbox already owns another interface')
                    require(record['target'] != entry['target'], 'target already belongs to another exposure')

    def apply(self, config, only=None, prune=False):
        require(not (only and prune), '--sandbox cannot be combined with --prune')
        require(only is None or only in config['sandboxes'], 'sandbox is absent from desired config')
        selected = {only: config['sandboxes'][only]} if only else config['sandboxes']
        self.preflight(config, selected)
        results = []
        for sandbox, entry in selected.items():
            name = entry['interface']
            record = self.ctl.load(name)
            network_args = {key: entry[key] for key in ('parent', 'network', 'project', 'target', 'ports')}
            if record is None or record['stage'] in ('creating', 'adopting'):
                if entry.get('legacy_dhcp_pid'):
                    record = self.ctl.adopt(name, **network_args, legacy_dhcp_pid=entry['legacy_dhcp_pid'])
                else:
                    record = self.ctl.create(name, **network_args)
            if record is None or record['stage'] != 'ready':
                raise ProxyError('exposure is incomplete; inspect before applying config')
            if entry.get('expected_address'):
                require(record['address'] == entry['expected_address'], 'DHCP did not provide expected_address; inspect retained exposure')
            # Never let two sandbox identities claim the same leased address.
            require(not any(other['name'] != name and other.get('address') == record['address'] for other in self.records()),
                    'lab IP is already owned by another exposure')
            if record.get('sandbox') != sandbox or record.get('config_id') != config['id']:
                record.update(sandbox=sandbox, config_id=config['id'])
                self.ctl.save(record)
            results.append(self.ctl.update(name, target=entry['target'], ports=entry['ports'], proxy=entry['proxy']))
        if prune:
            for record in self.records():
                if record.get('config_id') == config['id'] and record.get('sandbox') not in config['sandboxes']:
                    self.ctl.delete(record['name'])
        return results
