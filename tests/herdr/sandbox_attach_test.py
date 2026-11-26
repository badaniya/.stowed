#!/usr/bin/env python3
"""Exercise Agent Sandbox: Attach against a fake CLI, never a live Herdr socket."""
import fcntl
import importlib.util
import io
import json
import os
import pty
import select
import shlex
import shutil
import subprocess
import tempfile
import termios
import time
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / 'herdr-spreader/.config/herdr-spreader/agent-sandbox-attach.sh'
MONITOR = 'tail --retry -F /var/log/app/app-server.log | /usr/local/bin/loggo stream -t ~/.private-monorepo-loggo.tpl'
LABELS = ['Monitor', 'LazyDocker', 'Database', 'Platform', 'App']
FAKE_CLI = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
fixture = json.loads(Path(os.environ['ATTACH_FIXTURE']).read_text())
log = Path(os.environ['ATTACH_CALLS'])
with log.open('a') as stream:
    stream.write(json.dumps(args) + '\n')
command = tuple(args[:2])
if fixture.get('malformed_response') == list(command):
    print('not-json')
    sys.exit(0)
result = {}
if command == ('workspace', 'list'):
    result = {'workspaces': fixture['workspaces']}
elif command == ('tab', 'list'):
    assert args[2:] == ['--workspace', 'wRepair']
    result = {'tabs': fixture['tabs']}
elif command == ('pane', 'list'):
    assert args[2:] == ['--workspace', 'wRepair']
    result = {'panes': fixture['panes']}
elif command == ('pane', 'process-info'):
    assert args[2] == '--pane'
    info = fixture['processes'][args[3]]
    marker = Path(os.environ['ATTACH_ARMED'] + args[3] + '-attached')
    if marker.exists():
        info = dict(info, foreground_processes=[{'pid': 999, 'name': 'incus', 'argv': ['incus', 'exec', marker.read_text(), '--', 'bash']}])
    if fixture.get('busy_on_recheck') == args[3]:
        count_path = Path(os.environ['ATTACH_ARMED'] + args[3] + '-checks')
        count = int(count_path.read_text()) + 1 if count_path.exists() else 1
        count_path.write_text(str(count))
        if count >= fixture.get('busy_after_checks', 2):
            info = dict(info, foreground_processes=[{'pid': 998, 'name': 'nvim', 'argv': ['nvim']}])
    result = {'process_info': info}
elif command == ('pane', 'split'):
    pane_id = 'wRepair:pRecreated'
    cwd = args[args.index('--cwd') + 1] if '--cwd' in args else ''
    pane = {'pane_id': pane_id, 'workspace_id': 'wRepair', 'tab_id': 'wRepair:tBuild', 'cwd': cwd}
    fixture['panes'].insert(0, pane)
    fixture['processes'][pane_id] = {
        'shell_pid': 777,
        'foreground_process_group_id': 777,
        'foreground_processes': [{'pid': 777, 'name': 'zsh', 'argv': ['zsh']}],
    }
    Path(os.environ['ATTACH_FIXTURE']).write_text(json.dumps(fixture))
    result = {'pane': pane}
elif command == ('pane', 'move'):
    pane_id = args[2]
    pane = next(item for item in fixture['panes'] if item['pane_id'] == pane_id)
    if '--new-tab' in args:
        pane['tab_id'] = 'wRepair:tStage'
    elif '--tab' in args:
        assert '--split' in args, 'cross-tab pane move requires --split'
        pane['tab_id'] = args[args.index('--tab') + 1]
    Path(os.environ['ATTACH_FIXTURE']).write_text(json.dumps(fixture))
    result = {'move_result': {'pane': pane}}
elif command == ('pane', 'swap'):
    result = {'type': 'ok'}
elif command == ('pane', 'rename'):
    pane_id, label = args[2], args[3]
    for item in fixture['panes']:
        if item['pane_id'] == pane_id:
            item['label'] = label
    Path(os.environ['ATTACH_FIXTURE']).write_text(json.dumps(fixture))
    result = {'type': 'ok'}
elif command == ('pane', 'send-keys'):
    assert len(args) == 4, 'vi mode transitions must not be batched'
    if fixture.get('fail_keys') == args[2]:
        sys.exit(1)
    armed = Path(os.environ['ATTACH_ARMED'] + args[2])
    if args[3] == 'ctrl+c':
        info = fixture['processes'][args[2]]
        if fixture.get('ignore_interrupt') != args[2]:
            info['foreground_processes'] = [{'pid': info['shell_pid'], 'name': 'zsh', 'argv': ['zsh']}]
            Path(os.environ['ATTACH_FIXTURE']).write_text(json.dumps(fixture))
    elif args[3] == 'esc':
        armed.write_text('escaped')
    elif args[3] == 'i':
        assert armed.read_text() == 'escaped'
        armed.write_text('insert')
    elif args[3] == 'ctrl+u':
        assert armed.read_text() == 'insert'
        armed.write_text('ready')
    else:
        raise AssertionError('unexpected key')
elif command == ('pane', 'run'):
    # Model the real bug: a command submitted while in vi command mode is unsafe.
    armed = Path(os.environ['ATTACH_ARMED'] + args[2])
    assert armed.read_text() == 'ready', 'pane was not in insert mode'
    armed.unlink()
    if fixture.get('fail_run') == args[2]:
        sys.exit(1)
    if fixture.get('returns_to_shell') != args[2]:
        import shlex
        instance = shlex.split(args[3])[1]
        Path(os.environ['ATTACH_ARMED'] + args[2] + '-attached').write_text(instance)
else:
    raise AssertionError('unexpected CLI mutation: ' + repr(args))
print(json.dumps({'result': result}))
'''


class SandboxAttachTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home with spaces'
        self.project = self.home / 'workspace/fixture/ABC-20130'
        self.project.mkdir(parents=True)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        cli = self.bin / 'herdr'
        cli.write_text(FAKE_CLI)
        cli.chmod(0o700)
        self.calls_path = self.root / 'calls.jsonl'
        self.fixture_path = self.root / 'fixture.json'
        self.registry_path = self.root / 'state/labctl/sandboxes.json'
        self.registry_path.parent.mkdir(parents=True)
        self.registry = {'schema_version': 1, 'sandboxes': {'abc-20130': {'status': 'running'}}}
        self.fixture = {
            'workspaces': [{'workspace_id': 'wRepair', 'label': 'ABC-20130 - fixture'},
                           {'workspace_id': 'wOther', 'label': 'ABC-20224 - unrelated'}],
            'tabs': [{'workspace_id': 'wRepair', 'tab_id': 'wRepair:tAgent', 'label': '1 - Agent', 'number': 1},
                     {'workspace_id': 'wRepair', 'tab_id': 'wRepair:tBuild', 'label': '2 - Build', 'number': 2}],
            'panes': [], 'processes': {},
        }
        for number, label in enumerate(LABELS, 2):
            pane = f'wRepair:p{number}'
            self.fixture['panes'].append({'pane_id': pane, 'workspace_id': 'wRepair',
                                         'tab_id': 'wRepair:tBuild', 'label': label, 'cwd': str(self.project)})
            self.fixture['processes'][pane] = {'shell_pid': 100 + number,
                                             'foreground_process_group_id': 100 + number,
                                             'foreground_processes': [{'pid': 100 + number, 'name': 'zsh', 'argv': ['zsh']}]}
        # An identically named pane in Agent must never be repaired.
        self.fixture['panes'].insert(0, {'pane_id': 'wRepair:pAgent', 'tab_id': 'wRepair:tAgent', 'label': 'App'})
        self.env = {key: value for key, value in os.environ.items() if not key.startswith('HERDR_')}
        self.env['MONOREPO_NAME'] = 'mono-repo'
        self.env.update(MONOREPO_MONITOR_COMMAND=MONITOR, MONOREPO_DB_DIR='db/scripts/development',
                        MONOREPO_PLATFORM_DIR='platform/scripts/development', MONOREPO_APP_DIR='app/scripts/development')
        self.env.update(HOME=str(self.home), XDG_STATE_HOME=str(self.root / 'state'), HERDR_ENV='1',
                        PATH=f'{self.bin}:{self.env["PATH"]}', ATTACH_FIXTURE=str(self.fixture_path),
                        ATTACH_CALLS=str(self.calls_path), ATTACH_ARMED=str(self.root / 'armed-'))

    def run_attach(self, *args):
        self.fixture_path.write_text(json.dumps(self.fixture))
        self.registry_path.write_text(json.dumps(self.registry))
        if len(args) == 1:
            args = (args[0] + ' --timeout 0.4',)
        else:
            args = (*args, '--timeout', '0.4')
        return subprocess.run(['bash', str(LAUNCHER), *args], env=self.env,
                              capture_output=True, text=True, timeout=15, check=False)

    def calls(self):
        return [json.loads(line) for line in self.calls_path.read_text().splitlines()] if self.calls_path.exists() else []

    def writes(self):
        return [args for args in self.calls() if args[:2] in (['pane', 'send-keys'], ['pane', 'run'])]

    def assert_no_writes(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.writes(), [])

    def test_six_second_startup_succeeds_by_default_and_honors_explicit_timeout(self):
        # A five-second default reports failure even though Incus attaches at six.
        spec = importlib.util.spec_from_file_location('sandbox_attach', LAUNCHER.with_suffix('.py'))
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.registry_path.write_text(json.dumps(self.registry))
        cases = (
            ('api default', None, 0),
            ('CLI default', ['ABC-20130'], 0),
            ('CLI short override', ['ABC-20130', '--timeout', '5'], 1),
            ('CLI longer override', ['ABC-20130', '--timeout', '10'], 0),
        )
        for name, arguments, expected_status in cases:
            with self.subTest(name=name):
                clock = [0.0]
                submitted = {}

                def sleep(seconds, clock=clock):
                    clock[0] += seconds

                def fake_herdr(*args, read=True, clock=clock, submitted=submitted):
                    operation = args[:2]
                    if operation == ('workspace', 'list'):
                        return {'workspaces': self.fixture['workspaces']}
                    if operation == ('tab', 'list'):
                        return {'tabs': self.fixture['tabs']}
                    if operation == ('pane', 'list'):
                        return {'panes': self.fixture['panes']}
                    if operation == ('pane', 'process-info'):
                        pane_id = args[3]
                        info = self.fixture['processes'][pane_id]
                        if pane_id in submitted and clock[0] - submitted[pane_id] >= 6.0:
                            info = dict(info, foreground_processes=[{
                                'pid': 999, 'name': 'incus',
                                'argv': ['incus', '--project', 'agent-sandbox', 'exec',
                                         '--force-interactive', 'abc-20130', '--', 'bash'],
                            }])
                        return {'process_info': info}
                    if operation == ('pane', 'send-keys'):
                        return {}
                    if operation == ('pane', 'run'):
                        submitted[args[2]] = clock[0]
                        return {}
                    raise AssertionError(args)

                with patch.dict(os.environ, self.env, clear=True), \
                        patch.object(module, 'herdr', side_effect=fake_herdr), \
                        patch.object(module.time, 'monotonic', side_effect=lambda clock=clock: clock[0]), \
                        patch.object(module.time, 'sleep', side_effect=sleep), \
                        patch('sys.argv', ['sandbox-attach', *(arguments or [])]), \
                        patch('sys.stdout', new_callable=io.StringIO) as output, \
                        patch('sys.stderr', new_callable=io.StringIO) as errors:
                    status = module.attach('ABC-20130') if arguments is None else module.main()
                self.assertEqual(status, expected_status, output.getvalue() + errors.getvalue())
                summary = '5 pane(s) attached; 0 failed' if expected_status == 0 else '0 pane(s) attached; 5 failed'
                self.assertIn(summary, output.getvalue())

    def test_discovers_build_by_label_and_resets_vi_mode_before_each_exact_attach(self):
        self.fixture['panes'].reverse()
        self.fixture['panes'][-2]['label'] = 'Monitor - 192.0.2.10'
        result = self.run_attach('ABC-20130')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('2 - Build', result.stdout)
        self.assertIn('number 2', result.stdout)
        writes = self.writes()
        self.assertEqual(len(writes), 20)
        expected = [MONITOR, 'lazydocker',
                    f'cd {shlex.quote(str(self.project / "db/scripts/development"))} && exec bash -l',
                    f'cd {shlex.quote(str(self.project / "platform/scripts/development"))} && exec bash -l',
                    f'cd {shlex.quote(str(self.project / "app/scripts/development"))} && exec bash -l']
        for index, guest in enumerate(expected):
            pane = f'wRepair:p{index + 2}'
            self.assertEqual(writes[index * 4:index * 4 + 3], [
                ['pane', 'send-keys', pane, 'esc'], ['pane', 'send-keys', pane, 'i'],
                ['pane', 'send-keys', pane, 'ctrl+u']])
            run = writes[index * 4 + 3]
            self.assertEqual(run[:3], ['pane', 'run', pane])
            self.assertEqual(shlex.split(run[3]), ['exec_agent_sandbox', 'abc-20130', '--command', guest])

    def test_review_build_tab_uses_discovered_number_not_label_prefix_or_tab_position(self):
        self.registry['sandboxes'] = {'review-abc-18711': {'status': 'created'}}
        ticket = 'REVIEW-ABC-18711'
        project = self.project.with_name(ticket)
        project.mkdir()
        self.fixture['workspaces'][0]['label'] = ticket + ' - review'
        self.fixture['tabs'][1].update(label='4 - Build', number=7)
        self.fixture['tabs'].reverse()
        for pane in self.fixture['panes']:
            if pane['tab_id'] == 'wRepair:tBuild':
                pane['cwd'] = str(project)
        result = self.run_attach(ticket)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('number 7', result.stdout)
        self.assertIn('4 - Build', result.stdout)
        for run in self.writes()[3::4]:
            self.assertEqual(shlex.split(run[3])[1], 'review-abc-18711')

    def test_ambiguous_workspace_requires_explicit_selector_and_form_string_is_supported(self):
        self.fixture['workspaces'].append({'workspace_id': 'wDuplicate', 'label': 'ABC-20130 - another'})
        self.assert_no_writes(self.run_attach('ABC-20130'))
        result = self.run_attach('ABC-20130 --workspace wRepair')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.writes()), 20)

    def test_wrong_workspace_missing_or_duplicate_build_or_panes_fail_before_writes(self):
        self.assert_no_writes(self.run_attach('ABC-20130', '--workspace', 'wOther'))
        self.fixture['tabs'][1]['label'] = '2 - Other'
        self.assert_no_writes(self.run_attach('ABC-20130'))
        self.fixture['tabs'][1]['label'] = '2 - Build'
        self.fixture['tabs'].append({'tab_id': 'wRepair:tDuplicate', 'label': '4 - Build', 'number': 4})
        self.assert_no_writes(self.run_attach('ABC-20130'))
        self.fixture['tabs'].pop()
        removed = self.fixture['panes'].pop()
        self.assert_no_writes(self.run_attach('ABC-20130'))
        self.fixture['panes'].extend([removed, dict(removed, pane_id='wRepair:pDuplicate')])
        self.assert_no_writes(self.run_attach('ABC-20130'))

    def test_busy_pane_is_not_interrupted_and_no_other_pane_is_changed(self):
        self.fixture['processes']['wRepair:p6']['foreground_processes'] = [{'pid': 999, 'name': 'nvim', 'argv': ['nvim']}]
        self.assert_no_writes(self.run_attach('ABC-20130'))

    def bootstrap_viewer(self, contents: str | None = 'SANDBOX_BOOTSTRAP_SUCCESS\n'):
        log = self.root / 'state/herdr-spreader/ABC-20130.log'
        log.parent.mkdir(parents=True, exist_ok=True)
        if contents is not None:
            log.write_text(contents)
        self.fixture['processes']['wRepair:p2']['foreground_processes'] = [
            {'pid': 888, 'name': 'tail', 'argv': ['tail', '-n', '+1', '-F', str(log)]}]
        return log

    def test_completed_bootstrap_viewer_is_stopped_and_all_panes_attach(self):
        self.bootstrap_viewer()
        result = self.run_attach('ABC-20130')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('5 pane(s) attached; 0 failed', result.stdout)
        self.assertEqual(self.writes()[0], ['pane', 'send-keys', 'wRepair:p2', 'ctrl+c'])
        self.assertEqual(len([c for c in self.writes() if c[:2] == ['pane', 'run']]), 5)

    def test_unfinished_missing_or_unrelated_log_viewers_are_never_interrupted(self):
        for contents in (None, 'still building\n', 'prefix SANDBOX_BOOTSTRAP_SUCCESS suffix\n'):
            with self.subTest(contents=contents):
                self.bootstrap_viewer(contents)
                self.assert_no_writes(self.run_attach('ABC-20130'))
        log = self.bootstrap_viewer()
        log.rename(log.with_name('OTHER.log'))
        self.fixture['processes']['wRepair:p2']['foreground_processes'][0]['argv'][-1] = str(log.with_name('OTHER.log'))
        self.assert_no_writes(self.run_attach('ABC-20130'))

    def test_recoverable_monitor_does_not_bypass_other_busy_pane_preflight(self):
        self.bootstrap_viewer()
        self.fixture['processes']['wRepair:p6']['foreground_processes'] = [
            {'pid': 999, 'name': 'make', 'argv': ['make']}]
        self.assert_no_writes(self.run_attach('ABC-20130'))

    def test_job_replacing_monitor_viewer_after_preflight_is_not_interrupted(self):
        for check in (2, 3):
            with self.subTest(check=check):
                for marker in self.root.glob('armed-*'):
                    marker.unlink()
                if self.calls_path.exists():
                    self.calls_path.unlink()
                self.bootstrap_viewer()
                self.fixture['busy_on_recheck'] = 'wRepair:p2'
                self.fixture['busy_after_checks'] = check
                result = self.run_attach('ABC-20130')
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(c[2] == 'wRepair:p2' for c in self.writes()))

    def test_bootstrap_viewer_with_agent_or_additional_foreground_job_is_not_interrupted(self):
        self.bootstrap_viewer()
        monitor = next(p for p in self.fixture['panes'] if p.get('label') == 'Monitor')
        monitor['agent'] = 'claude'
        self.assert_no_writes(self.run_attach('ABC-20130'))
        monitor.pop('agent')
        self.fixture['processes']['wRepair:p2']['foreground_processes'].append(
            {'pid': 889, 'name': 'make', 'argv': ['make']})
        self.assert_no_writes(self.run_attach('ABC-20130'))

    def test_bootstrap_tail_in_non_monitor_pane_is_not_interrupted(self):
        self.bootstrap_viewer()
        viewer = self.fixture['processes']['wRepair:p2']['foreground_processes']
        self.fixture['processes']['wRepair:p4']['foreground_processes'] = viewer
        self.assert_no_writes(self.run_attach('ABC-20130'))

    def test_viewer_that_ignores_interrupt_never_receives_attach_input(self):
        self.bootstrap_viewer()
        self.fixture['ignore_interrupt'] = 'wRepair:p2'
        result = self.run_attach('ABC-20130')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([c for c in self.writes() if c[2] == 'wRepair:p2'],
                         [['pane', 'send-keys', 'wRepair:p2', 'ctrl+c']])
        self.assertIn('4 pane(s) attached; 1 failed', result.stdout)

    def test_existing_attachment_is_skipped_not_nested(self):
        self.fixture['processes']['wRepair:p4']['foreground_processes'] = [
            {'pid': 999, 'name': 'incus', 'argv': ['incus', '--project', 'agent-sandbox', 'exec', 'abc-20130', '--', 'bash']}]
        result = self.run_attach('ABC-20130')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('already attached', result.stdout)
        self.assertEqual(len(self.writes()), 16)
        self.assertFalse(any(args[2] == 'wRepair:p4' for args in self.writes()))

    def test_failed_insert_reset_never_submits_command_and_other_targets_are_attempted(self):
        self.fixture['fail_keys'] = 'wRepair:p3'
        result = self.run_attach('ABC-20130')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len([args for args in self.writes() if args[:2] == ['pane', 'run']]), 4)
        self.assertFalse(any(args[:3] == ['pane', 'run', 'wRepair:p3'] for args in self.writes()))

    def test_queued_command_that_returns_to_host_shell_is_not_reported_as_attached(self):
        self.fixture['returns_to_shell'] = 'wRepair:p3'
        result = self.run_attach('ABC-20130')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('LazyDocker: FAILED', result.stderr)
        self.assertIn('Incus exec attachment', result.stderr)
        self.assertIn('4 pane(s) attached; 1 failed', result.stdout)

    @unittest.skipUnless(shutil.which('zsh'), 'requires an isolated real zsh PTY')
    def test_real_vi_plugin_executes_attach_function_with_unmodified_spaces(self):
        helper = LAUNCHER.with_suffix('.py')
        spec = importlib.util.spec_from_file_location('sandbox_attach', helper)
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        plugin = ROOT / 'zsh/.oh-my-zsh/custom/plugins/zsh-vi-mode/zsh-vi-mode.zsh'
        result_file = self.root / 'executed-arguments'
        self.registry_path.write_text(json.dumps(self.registry))
        shell = shutil.which('zsh')
        assert shell is not None
        terminal, slave = pty.openpty()

        def claim_terminal():
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        process = subprocess.Popen([shell, '-f'], stdin=slave, stdout=slave, stderr=slave,
                                   env=dict(self.env, ATTACH_RESULT=str(result_file)),
                                   start_new_session=True, preexec_fn=claim_terminal)
        os.close(slave)

        def drain(seconds):
            end = time.monotonic() + seconds
            while time.monotonic() < end:
                if select.select([terminal], [], [], 0.02)[0]:
                    try:
                        os.read(terminal, 65536)
                    except OSError:
                        break

        launched = set()

        def fake_herdr(*args, read=True):
            operation = args[:2]
            if operation == ('workspace', 'list'):
                return {'workspaces': self.fixture['workspaces']}
            if operation == ('tab', 'list'):
                return {'tabs': self.fixture['tabs']}
            if operation == ('pane', 'list'):
                return {'panes': self.fixture['panes']}
            if operation == ('pane', 'process-info'):
                info = self.fixture['processes'][args[3]]
                if args[3] in launched:
                    info = dict(info, foreground_processes=[{'pid': 999, 'name': 'incus',
                                                            'argv': ['incus', 'exec', 'abc-20130']}])
                return {'process_info': info}
            if operation == ('pane', 'send-keys'):
                mapping = {'esc': b'\x1b', 'i': b'i', 'ctrl+u': b'\x15'}
                os.write(terminal, b''.join(mapping[key] for key in args[3:]))
                return {}
            if operation == ('pane', 'run'):
                os.write(terminal, b'\x1b[200~' + args[3].encode() + b'\x1b[201~\r')
                drain(0.1)
                launched.add(args[2])
                return {}
            raise AssertionError(args)

        try:
            drain(0.2)
            # Source only the real managed vi plugin, never the user's private rc.
            # The sandbox function is local to this disposable PTY and just records argv.
            setup = ("exec_agent_sandbox(){ printf '%s\\0' \"$@\" >> \"$ATTACH_RESULT\"; }; "
                     "autoload -Uz bracketed-paste-magic; zle -N bracketed-paste bracketed-paste-magic; "
                     f"source {shlex.quote(str(plugin))}; PS1='READY> '\r")
            os.write(terminal, setup.encode())
            drain(0.7)
            with patch.dict(os.environ, self.env, clear=True), patch.object(module, 'herdr', side_effect=fake_herdr), \
                    patch('sys.stdout', new_callable=io.StringIO):
                self.assertEqual(module.attach('ABC-20130'), 0)
            drain(0.3)
            self.assertTrue(result_file.exists(), 'zsh never invoked exec_agent_sandbox: batched Escape corrupted spaces')
            arguments = result_file.read_bytes().split(b'\0')[:-1]
            self.assertEqual(len(arguments), 15)
            self.assertEqual(arguments[:3], [b'abc-20130', b'--command', MONITOR.encode()])
            self.assertEqual(arguments[3:6], [b'abc-20130', b'--command', b'lazydocker'])
        finally:
            process.kill()
            process.wait(timeout=3)
            os.close(terminal)

    def test_failed_command_submission_is_reported_and_other_panes_are_attempted(self):
        self.fixture['fail_run'] = 'wRepair:p3'
        result = self.run_attach('ABC-20130')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('LazyDocker: FAILED', result.stderr)
        self.assertEqual(len([args for args in self.writes() if args[:2] == ['pane', 'run']]), 5)

    def test_malformed_discovery_and_wrong_sandbox_attachment_never_receive_input(self):
        self.fixture['malformed_response'] = ['workspace', 'list']
        self.assert_no_writes(self.run_attach('ABC-20130'))
        self.fixture.pop('malformed_response')
        self.fixture['processes']['wRepair:p4']['foreground_processes'] = [
            {'pid': 999, 'name': 'incus', 'argv': ['incus', 'exec', 'abc-20224', '--', 'bash']}]
        self.assert_no_writes(self.run_attach('ABC-20130'))

    def test_invalid_unregistered_paused_destroyed_or_outside_herdr_targets_are_rejected(self):
        self.assert_no_writes(self.run_attach('ABC-20130; touch /tmp/injected'))
        self.assert_no_writes(self.run_attach('ABC-99999'))
        for status in ('paused', 'destroyed'):
            self.registry['sandboxes']['abc-20130']['status'] = status
            self.assert_no_writes(self.run_attach('ABC-20130'))
        self.registry['sandboxes']['abc-20130']['status'] = 'running'
        self.env.pop('HERDR_ENV')
        self.assert_no_writes(self.run_attach('ABC-20130'))

    def test_usage_pseudo_agent_allowed_while_real_agent_blocks(self):
        self.fixture['panes'][1]['agent'] = 'usage'
        result = self.run_attach('ABC-20130')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.calls_path.unlink()
        self.fixture['panes'][1]['agent'] = 'claude'
        self.assert_no_writes(self.run_attach('ABC-20130'))

    def test_monorepo_and_multirepo_mono_paths_and_ticket_aliases(self):
        for ticket, has_subrepo in (('ABC-20130-MONO', False), ('MULTI-12-MONO', True), ('REVIEW-PR-9838', False)):
            with self.subTest(ticket=ticket):
                if self.calls_path.exists():
                    self.calls_path.unlink()
                for marker in self.root.glob('armed-*'):
                    marker.unlink()
                project = self.project.with_name(ticket)
                project.mkdir(exist_ok=True)
                mono_root = project / 'mono-repo' if has_subrepo else project
                mono_root.mkdir(exist_ok=True)
                self.registry['sandboxes'] = {ticket.lower(): {'status': 'created', 'workspace_type': 'mono'}}
                self.fixture['workspaces'][0]['label'] = f'{ticket} - mono'
                for pane in self.fixture['panes']:
                    if pane['tab_id'] == 'wRepair:tBuild':
                        pane['cwd'] = str(project)
                result = self.run_attach(ticket)
                self.assertEqual(result.returncode, 0, result.stderr)
                runs = [shlex.split(args[3]) for args in self.writes()[3::4]]
                self.assertEqual(runs[2], [
                    'exec_agent_sandbox', ticket.lower(), '--command',
                    f'cd {shlex.quote(str(mono_root / "db/scripts/development"))} && exec bash -l',
                ])
                self.assertEqual(runs[3], [
                    'exec_agent_sandbox', ticket.lower(), '--command',
                    f'cd {shlex.quote(str(mono_root / "platform/scripts/development"))} && exec bash -l',
                ])
                self.assertEqual(runs[4], [
                    'exec_agent_sandbox', ticket.lower(), '--command',
                    f'cd {shlex.quote(str(mono_root / "app/scripts/development"))} && exec bash -l',
                ])

    def test_missing_monitor_pane_is_recreated_and_attached_when_other_build_panes_valid(self):
        self.registry['sandboxes']['abc-20130']['ip'] = '10.77.10.13'
        state_dir = self.root / 'state/herdr-spreader'
        state_dir.mkdir(parents=True)
        self.fixture['panes'] = [p for p in self.fixture['panes'] if p.get('label') != 'Monitor']
        for pane_id in ('wRepair:p3', 'wRepair:p4', 'wRepair:p5', 'wRepair:p6'):
            self.fixture['processes'][pane_id]['foreground_processes'] = [
                {'pid': 999, 'name': 'incus', 'argv': ['incus', '--project', 'agent-sandbox', 'exec', 'abc-20130', '--', 'bash']}
            ]
        result = self.run_attach('ABC-20130')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertIn(['pane', 'split', 'wRepair:p3', '--direction', 'down', '--cwd', str(self.project), '--no-focus'], calls)
        self.assertIn(['pane', 'rename', 'wRepair:pRecreated', 'Monitor - 10.77.10.13'], calls)
        self.assertIn(['pane', 'move', 'wRepair:p3', '--new-tab', '--no-focus'], calls)
        self.assertIn(['pane', 'move', 'wRepair:p4', '--tab', 'wRepair:tStage', '--split', 'down', '--no-focus'], calls)
        self.assertIn(['pane', 'move', 'wRepair:p3', '--tab', 'wRepair:tBuild', '--target-pane', 'wRepair:pRecreated',
                       '--split', 'down', '--ratio', '0.42', '--no-focus'], calls)
        self.assertIn(['pane', 'move', 'wRepair:p4', '--tab', 'wRepair:tBuild', '--target-pane', 'wRepair:p3',
                       '--split', 'right', '--ratio', '0.65', '--no-focus'], calls)
        self.assertIn(['pane', 'move', 'wRepair:p5', '--tab', 'wRepair:tBuild', '--target-pane', 'wRepair:p4',
                       '--split', 'down', '--ratio', '0.33', '--no-focus'], calls)
        self.assertIn(['pane', 'move', 'wRepair:p6', '--tab', 'wRepair:tBuild', '--target-pane', 'wRepair:p5',
                       '--split', 'down', '--ratio', '0.5', '--no-focus'], calls)
        self.assertEqual((state_dir / 'ABC-20130.log.monitor-pane').read_text().strip(), 'wRepair:pRecreated')
        runs = [args for args in self.writes() if args[:2] == ['pane', 'run']]
        self.assertEqual(len(runs), 1)
        self.assertEqual(runs[0][2], 'wRepair:pRecreated')
        self.assertEqual(shlex.split(runs[0][3]), ['exec_agent_sandbox', 'abc-20130', '--command', MONITOR])


if __name__ == '__main__':
    unittest.main()
