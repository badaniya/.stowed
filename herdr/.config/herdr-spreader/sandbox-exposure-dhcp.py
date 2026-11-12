#!/usr/bin/python3
"""ISC dhclient hook: only addresses on the specifically marked exposure NIC.

No distro dhclient hooks, DNS writes, default routes, or global address flushes.
A changed/expired lease deliberately does not move the Incus forward: status
reports degradation and the operator deletes/recreates the exposure explicitly.
"""
import ipaddress
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path


def acknowledge(env, address):
    path = env.get('HERDR_EXPOSURE_ACK_FILE')
    if not path:
        return
    destination = Path(path)
    directory = destination.parent.lstat()
    if (not stat.S_ISDIR(directory.st_mode) or directory.st_uid != os.geteuid()
            or directory.st_mode & 0o022):
        raise RuntimeError('unsafe DHCP ACK directory')
    fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as handle:
        info = os.fstat(handle.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid():
            raise RuntimeError('unsafe DHCP ACK file')
        json.dump({'marker': env['HERDR_EXPOSURE_MARKER'], 'address': address}, handle)
        handle.flush()
        os.fsync(handle.fileno())


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=15,
                          env=dict(os.environ, PATH='/usr/sbin:/usr/bin:/sbin:/bin')).stdout


def preserve_adopted_address(name, new, old, expected, command):
    if not expected:
        return False
    if str(ipaddress.IPv4Interface(new).ip) != str(ipaddress.IPv4Address(expected)):
        raise RuntimeError('DHCP offered a different address; refusing to change the adopted lease')
    if old and str(ipaddress.IPv4Interface(old).ip) != expected:
        raise RuntimeError('DHCP old lease does not match the adopted address')
    # Replacing an existing address with noprefixroute can remove its connected
    # route. A handoff must leave both the address and its route alone.
    try:
        values = json.loads(command(['ip', '-json', '-4', 'addr', 'show', 'dev', name]))
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        raise RuntimeError('unable to inspect adopted DHCP address') from exc
    prefixes = [entry['prefixlen'] for value in values for entry in value.get('addr_info', [])
                if entry.get('local') == expected]
    if prefixes and prefixes != [ipaddress.IPv4Interface(new).network.prefixlen]:
        raise RuntimeError('DHCP changed the adopted subnet prefix; refusing address changes')
    return bool(prefixes)


def configure(env, command=run):
    name = env.get('interface', '')
    if (name != env.get('HERDR_EXPOSURE_INTERFACE') or len(name) > 15
            or not re.fullmatch(r'xiqfwd(?:0|[1-9][0-9]*)', name)):
        raise ValueError('DHCP interface does not match the owned exposure')
    try:
        links = json.loads(command(['ip', '-details', '-json', 'link', 'show']))
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        raise RuntimeError('unable to inspect DHCP exposure link inventory') from exc
    link = next((value for value in links if value['ifname'] == name), None)
    if link is None:
        if env.get('reason') in ('RELEASE', 'EXPIRE', 'FAIL', 'STOP'):
            return
        raise RuntimeError('DHCP exposure interface disappeared')
    if not env.get('HERDR_EXPOSURE_MARKER') or link.get('ifalias') != env['HERDR_EXPOSURE_MARKER']:
        raise RuntimeError('DHCP exposure ownership mismatch')

    def address(prefix):
        ip = env.get(f'{prefix}_ip_address')
        if not ip:
            return None
        return str(ipaddress.IPv4Interface(f"{ip}/{env.get(f'{prefix}_subnet_mask', '255.255.255.255')}"))

    reason = env.get('reason')
    old = address('old')
    if reason in ('BOUND', 'RENEW', 'REBIND', 'REBOOT', 'TIMEOUT'):
        # Do not accept dhclient's TIMEOUT fallback to an unverified stale lease.
        if reason == 'TIMEOUT':
            raise RuntimeError('DHCP timed out; refusing an unverified lease')
        new = address('new')
        if not new:
            raise ValueError('DHCP returned no IPv4 lease')
        expected = env.get('HERDR_EXPOSURE_EXPECT_ADDRESS')
        preserve = preserve_adopted_address(name, new, old, expected, command)
        if not preserve:
            command(['ip', '-4', 'address', 'replace', new, 'dev', name, 'noprefixroute'])
        if old and old != new and not expected:
            remove(command, old, name)
        acknowledge(env, str(ipaddress.IPv4Interface(new).ip))
    elif reason in ('EXPIRE', 'FAIL', 'RELEASE', 'STOP') and old:
        remove(command, old, name)


def remove(command, address, name):
    # dhclient can omit old_subnet_mask. Resolve the real prefix rather than
    # guessing /32, and skip only an already absent address (not other errors).
    old_ip = str(ipaddress.IPv4Interface(address).ip)
    try:
        values = json.loads(command(['ip', '-json', '-4', 'addr', 'show', 'dev', name]))
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        raise RuntimeError('unable to inspect old DHCP lease address; refusing cleanup') from exc
    for value in values:
        for entry in value.get('addr_info', []):
            if entry.get('local') == old_ip:
                command(['ip', '-4', 'address', 'delete', f"{old_ip}/{entry['prefixlen']}", 'dev', name])


if __name__ == '__main__':
    try:
        configure(os.environ)
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError) as exc:
        print(f'exposure DHCP hook: {exc}', file=sys.stderr)
        sys.exit(1)
