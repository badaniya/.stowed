#!/usr/bin/env python3
"""Reconnect an existing sandbox's Build panes without interrupting active jobs."""
import argparse
import contextlib
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

LABELS = ('Monitor', 'LazyDocker', 'Database', 'Platform', 'App')
# Multirepo aliases (<PREFIX>-N-MONO) and review sandboxes (REVIEW-[<REPO>-]PR-N).
TICKET = re.compile(
    r'(?:[A-Z][A-Z0-9]+-[0-9]+'
    r'|[A-Z][A-Z0-9]+-[0-9]+-MONO'
    r'|REVIEW-[A-Z][A-Z0-9]+-[0-9]+'
    r'|REVIEW-(?:[A-Z][A-Z0-9]*-)?PR-[1-9][0-9]*)'
)


def herdr(*args, read=True) -> dict:
    result = subprocess.run(['herdr', *args], capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(f'herdr {args[0]} {args[1]} failed: {result.stderr.strip() or result.stdout.strip()}')
    if not read:
        return {}
    try:
        response = json.loads(result.stdout)
    except (ValueError, TypeError) as error:
        raise RuntimeError(f'Invalid response from herdr {args[0]} {args[1]}: {error}') from error
    if not isinstance(response, dict):
        raise RuntimeError('Herdr response must be an object.')
    if 'error' in response:
        raise RuntimeError(str(response['error']))
    payload = response.get('result')
    if not isinstance(payload, dict):
        raise RuntimeError('Herdr response has no result object.')
    return payload


def only(items, description):
    if len(items) != 1:
        raise RuntimeError(f'Expected exactly one {description}; found {len(items)}. No attach commands submitted.')
    return items[0]


def is_attachment(info, instance):
    for process in info.get('foreground_processes', []):
        argv = process.get('argv', [])
        # Do not mistake a sandbox name in the guest command for the exec target.
        host_args = argv[:argv.index('--')] if '--' in argv else argv
        if argv and Path(argv[0]).name == 'incus' and 'exec' in host_args and instance in host_args:
            return True
    return False


def is_completed_bootstrap_viewer(pane, info, instance):
    """Recognize only the launcher's own completed Monitor log viewer."""
    label = pane.get('label', '')
    project = Path(pane.get('cwd', ''))
    if (label != 'Monitor' and not label.startswith('Monitor - ')) or project.name.lower() != instance:
        return False
    state_dir = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'herdr-spreader'
    log = state_dir / f'{project.name}.log'
    foreground = info.get('foreground_processes', [])
    if len(foreground) != 1:
        return False
    process = foreground[0]
    argv = process.get('argv', [])
    if (not argv or Path(argv[0]).name != 'tail'
            or argv[1:] != ['-n', '+1', '-F', str(log)]
            or process.get('pid') == info.get('shell_pid')):
        return False
    try:
        with log.open() as stream:
            return any(line.rstrip('\n') in ('SANDBOX_BOOTSTRAP_SUCCESS', 'SANDBOX_BOOTSTRAP_FAILED')
                       for line in stream)
    except (OSError, UnicodeError):
        return False


def process_state(pane, instance):
    """Classify safe attachments, idle shells, and recoverable Monitor viewers."""
    # space-usage claims idle Build panes with pseudo-agent='usage'; only real
    # coding agents occupy the terminal interactively.
    if pane.get('agent') not in (None, '', 'usage'):
        raise RuntimeError(f'{pane["label"]}: an agent occupies this pane; refusing to send input.')
    info = herdr('pane', 'process-info', '--pane', pane['pane_id'])['process_info']
    foreground = info.get('foreground_processes', [])
    if is_attachment(info, instance):
        return 'attached'
    if is_completed_bootstrap_viewer(pane, info, instance):
        return 'bootstrap-log'
    if (len(foreground) == 1 and foreground[0].get('pid') == info.get('shell_pid')
            and foreground[0].get('name') in ('zsh', 'bash')):
        return 'shell'
    raise RuntimeError(f'{pane["label"]}: no idle host shell detected; refusing to interrupt a foreground job.')


def private_work(key):
    # Project names and paths are internal; they live in ~/.private_work.env
    # (see private-env.sh). An exported variable of the same name wins.
    value = os.environ.get(key, '')
    env_file = Path.home() / '.private_work.env'
    if not value and env_file.is_file():
        for line in env_file.read_text().splitlines():
            match = re.fullmatch(r'(?:export )?' + re.escape(key) + r'=["\']?([^"\']*)["\']?', line.strip())
            if match:
                value = match.group(1)
    return value


def mono_repo_name():
    name = private_work('MONOREPO_NAME')
    return name if re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', name) else ''


def resolve_mono_dir(project):
    name = mono_repo_name()
    if name and (project / name).is_dir():
        return project / name
    return project


PANE_DIRS = {'Database': 'MONOREPO_DB_DIR', 'Platform': 'MONOREPO_PLATFORM_DIR', 'App': 'MONOREPO_APP_DIR'}


def guest_command(label, project, workspace_type='mono'):
    # Match the reconnect commands generated by monorepo-worktree-sandbox.sh.
    if label == 'Monitor':
        command = private_work('MONOREPO_MONITOR_COMMAND')
        if not command:
            raise RuntimeError('Set MONOREPO_MONITOR_COMMAND in ~/.private_work.env.')
        return command
    if label == 'LazyDocker':
        return 'lazydocker'
    relative = private_work(PANE_DIRS[label])
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._/-]*', relative) or '..' in relative:
        raise RuntimeError(f'Set a relative {PANE_DIRS[label]} in ~/.private_work.env.')
    base = resolve_mono_dir(project) if workspace_type == 'mono' else project
    return f'cd {shlex.quote(str(base / relative))} && exec bash -l'


def wait_for_shell(pane_id, timeout=5.0):
    deadline = time.monotonic() + timeout
    settled = 0
    while True:
        info = herdr('pane', 'process-info', '--pane', pane_id)['process_info']
        foreground = info.get('foreground_processes', [])
        if (len(foreground) == 1 and foreground[0].get('pid') == info.get('shell_pid')
                and foreground[0].get('name') in ('zsh', 'bash')):
            settled += 1
            if settled >= 5:
                return
        else:
            settled = 0
        if time.monotonic() >= deadline:
            raise RuntimeError(f'Monitor pane {pane_id} did not reach an idle host shell within {timeout:g}s.')
        time.sleep(0.1)


def moved_pane_id(response, fallback):
    pane = response.get('move_result', {}).get('pane')
    if isinstance(pane, dict) and isinstance(pane.get('pane_id'), str):
        return pane['pane_id']
    return fallback


def recreate_monitor_pane(workspace_id, tab_id, build_panes, project, ip=None):
    """Recreate a closed top-row Monitor pane above the existing Build split."""
    order = ('LazyDocker', 'Database', 'Platform', 'App')
    anchors = {pane.get('label'): pane['pane_id'] for pane in build_panes if pane.get('label') in order}
    for label in order:
        if label not in anchors:
            raise RuntimeError(f'Cannot recreate Monitor pane in {tab_id}; missing {label} pane.')
    split_pane = herdr('pane', 'split', anchors['LazyDocker'], '--direction', 'down',
                       '--cwd', str(project), '--no-focus')['pane']
    monitor_id = split_pane['pane_id']
    if not re.fullmatch(re.escape(workspace_id) + r':p[A-Za-z0-9]+', monitor_id):
        raise RuntimeError('Unsafe Monitor pane ID returned by Herdr.')
    monitor_label = f'Monitor - {ip}' if ip and re.fullmatch(r'(?:[0-9]{1,3}\.){3}[0-9]{1,3}', str(ip)) else 'Monitor'
    herdr('pane', 'rename', monitor_id, monitor_label, read=False)

    staged = herdr('pane', 'move', anchors['LazyDocker'], '--new-tab', '--no-focus')
    stage_pane = staged.get('move_result', {}).get('pane', {})
    stage_tab_id = stage_pane.get('tab_id')
    if not isinstance(stage_tab_id, str) or not re.fullmatch(re.escape(workspace_id) + r':t[A-Za-z0-9]+', stage_tab_id):
        raise RuntimeError('Unsafe staging tab ID returned by Herdr.')
    anchors['LazyDocker'] = moved_pane_id(staged, anchors['LazyDocker'])
    for label in order[1:]:
        moved = herdr('pane', 'move', anchors[label], '--tab', stage_tab_id, '--split', 'down', '--no-focus')
        anchors[label] = moved_pane_id(moved, anchors[label])

    reinsert = (
        ('LazyDocker', monitor_id, 'down', '0.42'),
        ('Database', anchors['LazyDocker'], 'right', '0.65'),
        ('Platform', anchors['Database'], 'down', '0.33'),
        ('App', anchors['Platform'], 'down', '0.5'),
    )
    for label, target_id, direction, ratio in reinsert:
        moved = herdr('pane', 'move', anchors[label], '--tab', tab_id, '--target-pane', target_id,
                      '--split', direction, '--ratio', ratio, '--no-focus')
        anchors[label] = moved_pane_id(moved, anchors[label])

    state_dir = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'herdr-spreader'
    if state_dir.is_dir():
        with contextlib.suppress(OSError):
            (state_dir / f'{project.name}.log.monitor-pane').write_text(f'{monitor_id}\n')
    wait_for_shell(monitor_id)
    refreshed = herdr('pane', 'list', '--workspace', workspace_id)['panes']
    return only([pane for pane in refreshed if pane.get('pane_id') == monitor_id],
                f'recreated Monitor pane {monitor_id} in Build tab {tab_id}')


def submit_attach(pane_id, command):
    # zsh-vi-mode's read-key engine consumes rapidly batched Escape/i/paste as
    # one escape sequence and leaks its internal \\s encoding into the buffer.
    # Separate the transitions and allow each to settle before the next write.
    for key in ('esc', 'i', 'ctrl+u'):
        herdr('pane', 'send-keys', pane_id, key, read=False)
        time.sleep(0.2)
    herdr('pane', 'run', pane_id, command, read=False)


def wait_for_attachment(pane_id, instance, timeout):
    deadline = time.monotonic() + timeout
    while True:
        info = herdr('pane', 'process-info', '--pane', pane_id)['process_info']
        if is_attachment(info, instance):
            return
        if time.monotonic() >= deadline:
            raise RuntimeError(f'No Incus exec attachment to {instance} appeared within {timeout:g}s; inspect the pane output.')
        time.sleep(0.1)


def resolve_project_dir(ticket, build_panes):
    # Pane cwd is the launcher's canonical host ticket root; registry paths in
    # older records can be incorrectly lowercased on a case-sensitive filesystem.
    present = [pane for pane in build_panes
               if pane.get('label') in LABELS or pane.get('label', '').startswith('Monitor - ')]
    roots = {Path(pane['cwd']) for pane in present
             if pane.get('cwd') and Path(pane['cwd']).name.upper() == ticket}
    project = only(list(roots), 'canonical ticket directory from Build panes')
    if not project.is_absolute() or not project.is_dir():
        raise RuntimeError(f'Ticket directory is unavailable: {project}')
    return project


def ensure_monitor_pane(workspace_id, tab_id, build_panes, project, instance, ip=None):
    monitor_matches = [pane for pane in build_panes
                       if pane.get('label') == 'Monitor' or pane.get('label', '').startswith('Monitor - ')]
    non_monitor = [label for label in LABELS if label != 'Monitor']
    if len(monitor_matches) != 0 or len(build_panes) != len(non_monitor):
        return build_panes
    for label in non_monitor:
        pane = only([p for p in build_panes if p.get('label') == label], f'{label} pane in Build tab {tab_id}')
        if not re.fullmatch(re.escape(workspace_id) + r':p[A-Za-z0-9]+', pane['pane_id']):
            raise RuntimeError('Unsafe pane ID returned by Herdr.')
        process_state(pane, instance)
    recreated = recreate_monitor_pane(workspace_id, tab_id, build_panes, project, ip)
    panes = herdr('pane', 'list', '--workspace', workspace_id)['panes']
    refreshed = [pane for pane in panes if pane.get('tab_id') == tab_id]
    if not any(p.get('pane_id') == recreated['pane_id'] for p in refreshed):
        refreshed.insert(0, recreated)
    return refreshed


def select_build_panes(workspace_id, tab_id, build_panes):
    selected = []
    for label in LABELS:
        matches = [pane for pane in build_panes if pane.get('label') == label
                   or (label == 'Monitor' and pane.get('label', '').startswith('Monitor - '))]
        pane = only(matches, f'{label} pane in Build tab {tab_id}')
        if not re.fullmatch(re.escape(workspace_id) + r':p[A-Za-z0-9]+', pane['pane_id']):
            raise RuntimeError('Unsafe pane ID returned by Herdr.')
        selected.append((label, pane))
    if len({pane['pane_id'] for _, pane in selected}) != len(LABELS):
        raise RuntimeError('Build panes do not have unique IDs.')
    return selected


def load_sandbox_record(ticket):
    instance = ticket.lower()
    state = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'labctl/sandboxes.json'
    try:
        registry = json.loads(state.read_text())
    except (OSError, ValueError) as error:
        raise RuntimeError(f'Cannot read sandbox registry {state}: {error}') from error
    if not isinstance(registry, dict) or not isinstance(registry.get('sandboxes'), dict):
        raise RuntimeError('Invalid sandbox registry.')
    record = registry['sandboxes'].get(instance)
    if registry.get('schema_version') != 1 or not isinstance(record, dict) or record.get('status') == 'destroyed':
        raise RuntimeError(f'Sandbox is not registered or is destroyed: {ticket}')
    if record.get('status') == 'paused':
        raise RuntimeError(f'Resume {ticket} before attaching its panes.')
    workspace_type = record.get('workspace_type') or 'harness'
    if workspace_type not in ('harness', 'mono', 'single-repo'):
        raise RuntimeError(f'Unsupported workspace type for {ticket}: {workspace_type}')
    return instance, record, workspace_type


def attach(ticket, workspace_id=None, timeout=15.0):
    if os.environ.get('HERDR_ENV') != '1':
        raise RuntimeError('Agent Sandbox: Attach must run inside Herdr.')
    ticket = ticket.upper()
    if not TICKET.fullmatch(ticket):
        raise RuntimeError('Invalid sandbox ticket; use a ticket or full REVIEW identity.')
    instance, record, workspace_type = load_sandbox_record(ticket)

    workspaces = herdr('workspace', 'list')['workspaces']
    candidates = [item for item in workspaces
                  if item.get('label', '').split(' ', 1)[0].upper() == ticket
                  and (workspace_id is None or item['workspace_id'] == workspace_id)]
    workspace = only(candidates, f'workspace for {ticket} (use --workspace ID to disambiguate)')
    workspace_id = workspace['workspace_id']
    if not re.fullmatch(r'w[A-Za-z0-9]+', workspace_id):
        raise RuntimeError('Unsafe workspace ID returned by Herdr.')
    tabs = herdr('tab', 'list', '--workspace', workspace_id)['tabs']
    build = only([tab for tab in tabs if re.fullmatch(r'(?:[0-9]+\s*-\s*)?Build', tab.get('label', ''))],
                 f'Build tab by label in {workspace_id}')
    tab_id = build['tab_id']
    if not re.fullmatch(re.escape(workspace_id) + r':t[A-Za-z0-9]+', tab_id):
        raise RuntimeError('Build tab does not belong to the selected workspace.')
    panes = herdr('pane', 'list', '--workspace', workspace_id)['panes']
    build_panes = [pane for pane in panes if pane.get('tab_id') == tab_id]
    project = resolve_project_dir(ticket, build_panes)
    build_panes = ensure_monitor_pane(workspace_id, tab_id, build_panes, project, instance, record.get('ip'))
    selected = select_build_panes(workspace_id, tab_id, build_panes)

    # Preflight every target before changing any shell, then recheck each just
    # before submission in case it became busy after discovery.
    for _, pane in selected:
        process_state(pane, instance)
    print(f'Build tab number {build["number"]}: {build["label"]} ({tab_id}), workspace {workspace_id}')
    failures = 0
    attached = 0
    for label, pane in selected:
        try:
            state = process_state(pane, instance)
            if state == 'attached':
                attached += 1
                print(f'{label}: already attached to {instance}; left unchanged.')
                continue
            if state == 'bootstrap-log':
                # Revalidate immediately before interrupting only the known viewer.
                if process_state(pane, instance) != 'bootstrap-log':
                    raise RuntimeError('Monitor process changed before recovery; refusing to interrupt it.')
                herdr('pane', 'send-keys', pane['pane_id'], 'ctrl+c', read=False)
                wait_for_shell(pane['pane_id'])
                if process_state(pane, instance) != 'shell':
                    raise RuntimeError('Monitor is no longer an idle host shell; refusing to send input.')
                print(f'{label}: stopped completed bootstrap-log viewer.')
            command = shlex.join(['exec_agent_sandbox', instance, '--command',
                                  guest_command(label, project, workspace_type)])
            submit_attach(pane['pane_id'], command)
            wait_for_attachment(pane['pane_id'], instance, timeout)
            attached += 1
            print(f'{label}: attached to {instance} in {pane["pane_id"]}.')
        except (RuntimeError, OSError, ValueError, KeyError) as error:
            failures += 1
            print(f'{label}: FAILED: {error}', file=sys.stderr)
    print(f'Summary: {attached} pane(s) attached; {failures} failed.')
    return 1 if failures else 0


def attachment_timeout(value):
    seconds = float(value)
    if not 0 < seconds <= 60:
        raise argparse.ArgumentTypeError('timeout must be greater than zero and at most 60 seconds')
    return seconds


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ticket')
    parser.add_argument('--workspace', help='explicit workspace ID when ticket labels are ambiguous')
    parser.add_argument('--timeout', type=attachment_timeout, default=15.0,
                        help='seconds to wait for each Incus exec attachment (default: 15; maximum: 60)')
    args = sys.argv[1:]
    # Herdr Plus passes its form value as one argument; direct CLI calls may
    # supply normal separate arguments. Split as data, never evaluate a shell.
    if len(args) == 1:
        try:
            args = shlex.split(args[0])
        except ValueError as error:
            parser.error(str(error))
    parsed = parser.parse_args(args)
    try:
        return attach(parsed.ticket, parsed.workspace, parsed.timeout)
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as error:
        print(f'Error: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
