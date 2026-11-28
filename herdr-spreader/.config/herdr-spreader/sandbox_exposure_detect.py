"""Read-only exposure recommendations; Ethernet alone does not prove DHCP support."""
import ipaddress


def detect(links, addresses, wsl=False, healthy=None, probes=None):
    by_name = {row['ifname']: row for row in addresses}
    probes = probes or {}
    result = []
    for link in links:
        name = link['ifname']
        kind = link.get('linkinfo', {}).get('info_kind')
        flags = link.get('flags', [])
        if 'UP' not in flags or 'LOOPBACK' in flags or kind in {'bridge', 'veth', 'dummy', 'macvlan', 'vxlan'}:
            continue
        values = [entry for entry in by_name.get(name, {}).get('addr_info', [])
                  if entry.get('family') == 'inet' and entry.get('scope') == 'global'
                  and not ipaddress.IPv4Address(entry['local']).is_link_local]
        if not values:
            continue
        state = 'unverified'
        mode = 'dhcp'
        reason = 'Ethernet candidate; DHCP service and extra-MAC policy are unverified. Explicitly test before relying on multiple addresses.'
        if 'POINTOPOINT' in flags or kind in {'tun', 'wireguard'} or link.get('link_type') != 'ether':
            state, mode = 'not-l2', 'host-address'
            reason = 'L3/point-to-point uplink; use its existing address, not macvlan DHCP.'
        elif name in probes:
            evidence = probes[name]
            state = 'probe-succeeded' if evidence['success'] else 'probe-failed'
            mode = 'dhcp' if evidence['success'] else 'host-address'
            reason = evidence['reason'] + '; this is a recent test, not a permanent capacity guarantee.'
        elif wsl and any(v.get('prefixlen') == 32 for v in values):
            mode = 'host-address'
            reason = 'WSL mirrored /32 VPN-like address; single-address mode recommended. This does not prove DHCP availability.'
        elif any(r.get('parent') == name and r.get('status') == 'ready' and r.get('listen_address')
                 and r.get('mode', 'dhcp') == 'dhcp' for r in healthy or []):
            state = 'existing-lease-verified'
            reason = 'An existing extra DHCP lease is healthy; additional pool/MAC capacity is not guaranteed.'
        result.append({'parent': name, 'addresses': [v['local'] for v in values],
                       'recommended_mode': mode, 'multiple_address': state, 'reason': reason,
                       'changes_made': False})
    return result
