#!/usr/bin/env python3
"""Exercise Sandbox: Attach against a fake CLI, never a live Herdr socket."""
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
LAUNCHER = ROOT / 'herdr-spreader/.config/herdr-spreader/nvo-sandbox-attach.sh'
MONITOR = ('tail --retry -F /var/log/network/network-server.log /var/log/edge/edge-server.log '
           '/var/log/scheduler/scheduler-server.log /var/log/system/system-server.log '
           '/var/log/orchestration/orchestration-server.log /var/log/runonce/runonce-server.log '
           '/var/log/tagging/tagging-server.log | /usr/local/bin/loggo stream -t ~/.private-nvo-loggo.tpl')
LABELS = ['Monitor', 'LazyDocker', 'PlatformCommonModels', 'PlatformServices', 'GoDCApp']
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
    result = {'process_info': info}
elif command == ('pane', 'send-keys'):
    assert len(args) == 4, 'vi mode transitions must not be batched'
    if fixture.get('fail_keys') == args[2]:
        sys.exit(1)
    armed = Path(os.environ['ATTACH_ARMED'] + args[2])
    if args[3] == 'esc':
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
        self.project = self.home / 'workspace/fixture/NVO-20130'
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
        self.registry = {'schema_version': 1, 'sandboxes': {'nvo-20130': {'status': 'running'}}}
        self.fixture = {
            'workspaces': [{'workspace_id': 'wRepair', 'label': 'NVO-20130 - fixture'},
                           {'workspace_id': 'wOther', 'label': 'NVO-20224 - unrelated'}],
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
        self.fixture['panes'].insert(0, {'pane_id': 'wRepair:pAgent', 'tab_id': 'wRepair:tAgent', 'label': 'GoDCApp'})
        self.env = {key: value for key, value in os.environ.items() if not key.startswith('HERDR_')}
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

    def test_discovers_build_by_label_and_resets_vi_mode_before_each_exact_attach(self):
        self.fixture['panes'].reverse()
        self.fixture['panes'][-2]['label'] = 'Monitor - 192.0.2.10'
        result = self.run_attach('NVO-20130')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('2 - Build', result.stdout)
        self.assertIn('number 2', result.stdout)
        writes = self.writes()
        self.assertEqual(len(writes), 20)
        expected = [MONITOR, 'lazydocker',
                    f'cd {shlex.quote(str(self.project / "PlatformCommonModels/scripts/development"))} && exec bash -l',
                    f'cd {shlex.quote(str(self.project / "PlatformServices/scripts/development"))} && exec bash -l',
                    f'cd {shlex.quote(str(self.project / "GoDCApp/NVO/scripts/development"))} && exec bash -l']
        for index, guest in enumerate(expected):
            pane = f'wRepair:p{index + 2}'
            self.assertEqual(writes[index * 4:index * 4 + 3], [
                ['pane', 'send-keys', pane, 'esc'], ['pane', 'send-keys', pane, 'i'],
                ['pane', 'send-keys', pane, 'ctrl+u']])
            run = writes[index * 4 + 3]
            self.assertEqual(run[:3], ['pane', 'run', pane])
            self.assertEqual(shlex.split(run[3]), ['exec_agent_sandbox', 'nvo-20130', '--command', guest])

    def test_review_build_tab_uses_discovered_number_not_label_prefix_or_tab_position(self):
        self.registry['sandboxes'] = {'nvo-review-cfd-18711': {'status': 'created'}}
        ticket = 'NVO-REVIEW-CFD-18711'
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
            self.assertEqual(shlex.split(run[3])[1], 'nvo-review-cfd-18711')

    def test_ambiguous_workspace_requires_explicit_selector_and_form_string_is_supported(self):
        self.fixture['workspaces'].append({'workspace_id': 'wDuplicate', 'label': 'NVO-20130 - another'})
        self.assert_no_writes(self.run_attach('NVO-20130'))
        result = self.run_attach('NVO-20130 --workspace wRepair')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.writes()), 20)

    def test_wrong_workspace_missing_or_duplicate_build_or_panes_fail_before_writes(self):
        self.assert_no_writes(self.run_attach('NVO-20130', '--workspace', 'wOther'))
        self.fixture['tabs'][1]['label'] = '2 - Other'
        self.assert_no_writes(self.run_attach('NVO-20130'))
        self.fixture['tabs'][1]['label'] = '2 - Build'
        self.fixture['tabs'].append({'tab_id': 'wRepair:tDuplicate', 'label': '4 - Build', 'number': 4})
        self.assert_no_writes(self.run_attach('NVO-20130'))
        self.fixture['tabs'].pop()
        removed = self.fixture['panes'].pop()
        self.assert_no_writes(self.run_attach('NVO-20130'))
        self.fixture['panes'].extend([removed, dict(removed, pane_id='wRepair:pDuplicate')])
        self.assert_no_writes(self.run_attach('NVO-20130'))

    def test_busy_pane_is_not_interrupted_and_no_other_pane_is_changed(self):
        self.fixture['processes']['wRepair:p6']['foreground_processes'] = [{'pid': 999, 'name': 'nvim', 'argv': ['nvim']}]
        self.assert_no_writes(self.run_attach('NVO-20130'))

    def test_existing_attachment_is_skipped_not_nested(self):
        self.fixture['processes']['wRepair:p4']['foreground_processes'] = [
            {'pid': 999, 'name': 'incus', 'argv': ['incus', '--project', 'agent-sandbox', 'exec', 'nvo-20130', '--', 'bash']}]
        result = self.run_attach('NVO-20130')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('already attached', result.stdout)
        self.assertEqual(len(self.writes()), 16)
        self.assertFalse(any(args[2] == 'wRepair:p4' for args in self.writes()))

    def test_failed_insert_reset_never_submits_command_and_other_targets_are_attempted(self):
        self.fixture['fail_keys'] = 'wRepair:p3'
        result = self.run_attach('NVO-20130')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len([args for args in self.writes() if args[:2] == ['pane', 'run']]), 4)
        self.assertFalse(any(args[:3] == ['pane', 'run', 'wRepair:p3'] for args in self.writes()))

    def test_queued_command_that_returns_to_host_shell_is_not_reported_as_attached(self):
        self.fixture['returns_to_shell'] = 'wRepair:p3'
        result = self.run_attach('NVO-20130')
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
                                                            'argv': ['incus', 'exec', 'nvo-20130']}])
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
                self.assertEqual(module.attach('NVO-20130'), 0)
            drain(0.3)
            self.assertTrue(result_file.exists(), 'zsh never invoked exec_agent_sandbox: batched Escape corrupted spaces')
            arguments = result_file.read_bytes().split(b'\0')[:-1]
            self.assertEqual(len(arguments), 15)
            self.assertEqual(arguments[:3], [b'nvo-20130', b'--command', MONITOR.encode()])
            self.assertEqual(arguments[3:6], [b'nvo-20130', b'--command', b'lazydocker'])
        finally:
            process.kill()
            process.wait(timeout=3)
            os.close(terminal)

    def test_failed_command_submission_is_reported_and_other_panes_are_attempted(self):
        self.fixture['fail_run'] = 'wRepair:p3'
        result = self.run_attach('NVO-20130')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('LazyDocker: FAILED', result.stderr)
        self.assertEqual(len([args for args in self.writes() if args[:2] == ['pane', 'run']]), 5)

    def test_malformed_discovery_and_wrong_sandbox_attachment_never_receive_input(self):
        self.fixture['malformed_response'] = ['workspace', 'list']
        self.assert_no_writes(self.run_attach('NVO-20130'))
        self.fixture.pop('malformed_response')
        self.fixture['processes']['wRepair:p4']['foreground_processes'] = [
            {'pid': 999, 'name': 'incus', 'argv': ['incus', 'exec', 'nvo-20224', '--', 'bash']}]
        self.assert_no_writes(self.run_attach('NVO-20130'))

    def test_invalid_unregistered_paused_destroyed_or_outside_herdr_targets_are_rejected(self):
        self.assert_no_writes(self.run_attach('NVO-20130; touch /tmp/injected'))
        self.assert_no_writes(self.run_attach('NVO-99999'))
        for status in ('paused', 'destroyed'):
            self.registry['sandboxes']['nvo-20130']['status'] = status
            self.assert_no_writes(self.run_attach('NVO-20130'))
        self.registry['sandboxes']['nvo-20130']['status'] = 'running'
        self.env.pop('HERDR_ENV')
        self.assert_no_writes(self.run_attach('NVO-20130'))


if __name__ == '__main__':
    unittest.main()
