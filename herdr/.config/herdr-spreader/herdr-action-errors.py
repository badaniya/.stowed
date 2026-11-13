#!/usr/bin/env python3
"""Run Herdr Plus actions and retain failures in a log tab and floating popup."""
import argparse
import curses
import fcntl
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import textwrap
import time
from contextlib import suppress
from datetime import datetime, timezone
from pathlib import Path

PLUGIN_ID = 'local.action-errors'
SCRIPT = Path(__file__).resolve()
ACTIVE = 'HERDR_ACTION_ERROR_ACTIVE'
# Remove ANSI CSI/OSC (including clipboard writes), other escape sequences,
# and control characters before displaying untrusted command output.
ESCAPES = re.compile(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-?]*[ -/]*[@-~]|\x1b[@-_]|[\x00-\x08\x0b-\x1f\x7f-\x9f]')


def display_text(text):
    return ESCAPES.sub('', text).expandtabs(4)


def api(method, params):
    request = {'jsonrpc': '2.0', 'id': 'action-errors', 'method': method, 'params': params}
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(4)
        connection.connect(os.environ['HERDR_SOCKET_PATH'])
        connection.sendall((json.dumps(request) + '\n').encode())
        try:
            with connection.makefile() as stream:
                response = json.loads(stream.readline(4 * 1024 * 1024))
        except (OSError, ValueError) as error:
            raise RuntimeError(f'invalid Herdr API response: {error}') from error
    if 'error' in response:
        raise RuntimeError(response['error'].get('message', str(response['error'])))
    return response['result']


def warn(message):
    print(f'Herdr action errors: {message}', file=sys.stderr)


def read_metadata(log):
    try:
        return json.loads(log.with_suffix('.json').read_text())
    except (OSError, ValueError) as error:
        raise RuntimeError(f'cannot read error metadata for {log}: {error}') from error


def report_failure(log):
    """Best-effort reporting; no input is ever sent to an existing pane."""
    log = Path(log).resolve()
    meta = read_metadata(log)
    env = {'HERDR_ACTION_ERROR_LOG': str(log)}
    # Serialize lookup/create across simultaneous action failures.
    lock_fd = os.open(log.parent / '.workspace.lock', os.O_CREAT | os.O_RDWR, 0o600)
    try:
        with os.fdopen(lock_fd, 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            workspaces = api('workspace.list', {}).get('workspaces', [])
            workspace = next((item for item in workspaces if item.get('label') == 'HERDR-ACTION-ERRORS'), None)
            placement = {'placement': 'tab'}
            if workspace is None:
                created = api('workspace.create', {'label': 'HERDR-ACTION-ERRORS', 'cwd': str(log.parent), 'focus': False})
                workspace = created['workspace']
                # Cover only the fresh root pane; later reports get new tabs.
                placement = {'placement': 'zoomed', 'target_pane_id': created['root_pane']['pane_id']}
            api('plugin.pane.open', {
                'plugin_id': PLUGIN_ID, 'entrypoint': 'log', **placement,
                'workspace_id': workspace['workspace_id'], 'focus': False,
                'cwd': str(log.parent), 'env': env,
            })
    except (OSError, KeyError, ValueError, RuntimeError) as error:
        warn(f'could not open log tab: {error}; log: {log}')
    # Do not let a log-tab error prevent the summary popup.
    try:
        api('plugin.pane.open', {
            'plugin_id': PLUGIN_ID, 'entrypoint': 'popup', 'placement': 'popup',
            'width': '70%', 'height': '55%', 'focus': True, 'env': env,
        })
    except (OSError, KeyError, ValueError, RuntimeError) as error:
        warn(f'could not open popup: {error}; {meta["name"]} failed; log: {log}')


def deferred_report(log, picker):
    """Wait for the action picker to close so its teardown cannot hide the popup."""
    if picker:
        for _ in range(100):
            try:
                api('pane.get', {'pane_id': picker})
            except RuntimeError:
                break  # The picker exited.
            time.sleep(0.1)
    report_failure(log)


def launch_report(log):
    if os.environ.get('HERDR_ENV') != '1' or not os.environ.get('HERDR_SOCKET_PATH'):
        return
    if os.environ.get('HERDR_PLUGIN_ENTRYPOINT_ID') == 'quick-actions-picker':
        # The picker exits immediately after the command. Do not block it or
        # leave the reporter connected to its dying terminal.
        with log.with_suffix('.report.log').open('ab') as errors:
            os.chmod(errors.name, 0o600)
            subprocess.Popen(
                [sys.executable, str(SCRIPT), 'report', '--log', str(log),
                 '--picker', os.environ.get('HERDR_PANE_ID', '')],
                stdin=subprocess.DEVNULL, stdout=errors, stderr=errors,
                start_new_session=True,
            )
    else:
        report_failure(log)


def exit_status(code):
    return 128 - code if code < 0 else code


def create_log():
    state = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'herdr/action-errors'
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(state, 0o700)
    fd, filename = tempfile.mkstemp(prefix=datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S-'), suffix='.log', dir=state)
    return fd, Path(filename)


def notify_failure(name, status, message, sources):
    """Snapshot a background job's logs, regardless of inherited nesting markers."""
    fd, log = create_log()
    with os.fdopen(fd, 'wb') as output:
        output.write((message + '\n').encode())
        for source in sources:
            output.write(f'\n--- {source} ---\n'.encode())
            try:
                with source.open('rb') as stream:
                    remaining = os.fstat(stream.fileno()).st_size
                    while remaining > 0:
                        chunk = stream.read(min(65536, remaining))
                        if not chunk:
                            break
                        output.write(chunk)
                        remaining -= len(chunk)
            except OSError as error:
                output.write(f'Unable to read log: {error}\n'.encode())
    finish_failure(log, name, status)


def run_action(name, command):
    if os.environ.get(ACTIVE) == '1':
        # An outer runner owns the capture, status, and single notification.
        try:
            return exit_status(subprocess.call(command))
        except FileNotFoundError as error:
            warn(str(error))
            return 127
    fd, log = create_log()
    env = dict(os.environ, **{ACTIVE: '1'})
    # Use a regular file, not a pipe: detached descendants must not keep the
    # launcher waiting forever after its immediate action exits.
    with os.fdopen(fd, 'wb') as capture, log.open('rb') as reader:
        try:
            process = subprocess.Popen(command, stdout=capture, stderr=subprocess.STDOUT, env=env)
        except OSError as error:
            capture.write(f'Error: {error}\n'.encode())
            capture.flush()
            status = 127 if isinstance(error, FileNotFoundError) else 126
        else:
            try:
                while process.poll() is None:
                    forward_output(reader)
                    time.sleep(0.03)
                status = exit_status(process.wait())
            except KeyboardInterrupt:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                status = 130
        forward_output(reader)
    if status == 0:
        log.unlink()
        return 0
    finish_failure(log, name, status)
    return status


def finish_failure(log, name, status):
    metadata = {'name': name, 'status': status, 'cwd': os.getcwd(), 'time': datetime.now(timezone.utc).isoformat()}
    warn(f'{name} failed (exit {status}); log: {log}')
    try:
        meta_fd = os.open(log.with_suffix('.json'), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(meta_fd, 'w') as stream:
            json.dump(metadata, stream)
        launch_report(log)
    except (OSError, KeyError, ValueError, RuntimeError) as error:
        warn(f'could not report failure: {error}; log: {log}')


def forward_output(reader):
    while chunk := reader.read(65536):
        try:
            sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()
        except BrokenPipeError:
            return


def read_failure(log):
    log = Path(log)
    meta = read_metadata(log)
    # Bound popup memory for very large build logs; the complete log stays on disk.
    with log.open('rb') as stream:
        stream.seek(max(0, log.stat().st_size - 128 * 1024))
        output = display_text(stream.read().decode(errors='replace'))
    errors = [line for line in output.splitlines() if re.search(r'error|failed|fatal|exception|refusing', line, re.IGNORECASE)]
    summary = errors[-1] if errors else next((line for line in reversed(output.splitlines()) if line.strip()), 'Command exited without output.')
    header = f'{display_text(meta["name"])}\nExit status: {meta["status"]}   {meta["time"]}\n\n{summary}\n\nFull log: {log}\nWorkspace: HERDR-ACTION-ERRORS\n\n'
    return header, output


def show_log(log):
    header, _ = read_failure(log)
    meta = read_metadata(log)
    if tab := os.environ.get('HERDR_TAB_ID'):
        try:
            label = f'{meta["time"][11:19]} · {display_text(meta["name"])[:64]}'
            api('tab.rename', {'tab_id': tab, 'label': label})
        except (OSError, KeyError, ValueError, RuntimeError) as error:
            warn(f'could not label log tab: {error}')
    print(header)
    with log.open(errors='replace') as stream:
        for line in stream:
            print(display_text(line), end='')


def configure_popup_colors(screen):
    # Request terminal-default foreground/background, allowing the host's
    # transparency where supported rather than curses' solid color defaults.
    with suppress(curses.error):
        curses.start_color()
        curses.use_default_colors()
        screen.bkgd(' ', curses.color_pair(0))
        screen.attrset(curses.color_pair(0))


def show_popup(log):
    header, output = read_failure(log)

    def draw(screen):
        curses.curs_set(0)
        configure_popup_colors(screen)
        screen.keypad(True)
        offset = 0
        while True:
            height, width = screen.getmaxyx()
            rows = []
            for line in (header + output).splitlines():
                rows.extend(textwrap.wrap(line, max(1, width - 4), replace_whitespace=False) or [''])
            available = max(1, height - 2)
            offset = min(offset, max(0, len(rows) - available))
            screen.erase()
            for row, text in enumerate(rows[offset:offset + available]):
                with suppress(curses.error):
                    screen.addnstr(row, 2, text, max(0, width - 4))
            footer = 'Enter/Esc/q: close   Up/Down/PgUp/PgDn: scroll'
            with suppress(curses.error):
                screen.addnstr(height - 1, 1, footer, max(0, width - 2), curses.A_DIM)
            screen.refresh()
            key = screen.getch()
            if key in (10, 13, 27, ord('q')):
                return
            if key in (curses.KEY_DOWN, ord('j')):
                offset += 1
            elif key in (curses.KEY_UP, ord('k')):
                offset = max(0, offset - 1)
            elif key == curses.KEY_NPAGE:
                offset += available
            elif key == curses.KEY_PPAGE:
                offset = max(0, offset - available)
    curses.wrapper(draw)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest='mode', required=True)
    run = modes.add_parser('run')
    run.add_argument('--name', required=True)
    run.add_argument('command', nargs=argparse.REMAINDER)
    notify = modes.add_parser('notify')
    notify.add_argument('--name', required=True)
    notify.add_argument('--status', type=int, required=True)
    notify.add_argument('--message', required=True)
    notify.add_argument('--source-log', action='append', type=Path, default=[])
    report = modes.add_parser('report')
    report.add_argument('--log', required=True, type=Path)
    report.add_argument('--picker', default='')
    for mode in ('popup', 'log'):
        viewer = modes.add_parser(mode)
        viewer.add_argument('--log', default=os.environ.get('HERDR_ACTION_ERROR_LOG'), type=Path)
    args = parser.parse_args()
    if args.mode == 'run':
        command = args.command[1:] if args.command[:1] == ['--'] else args.command
        if not command:
            parser.error('run requires a command after --')
        return run_action(args.name, command)
    if args.mode == 'notify':
        if not 1 <= args.status <= 255:
            parser.error('notify requires a failure status from 1 to 255')
        notify_failure(args.name, args.status, args.message, args.source_log)
        return 0
    if not args.log:
        parser.error('a log path is required')
    if args.mode == 'report':
        deferred_report(args.log, args.picker)
    elif args.mode == 'popup':
        show_popup(args.log)
    else:
        show_log(args.log)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
