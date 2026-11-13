#!/usr/bin/env python3
"""Shared action errors: real child commands, isolated state, fake Herdr API."""
import importlib.util
import io
import json
import os
import shlex
import socket
import stat
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import tomllib

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / 'herdr/.config/herdr-spreader'
RUNNER = SCRIPTS / 'herdr-action-errors.py'
ACTIONS = ROOT / 'herdr/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions'


def load_runner():
    spec = importlib.util.spec_from_file_location('action_errors', RUNNER)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = dict(os.environ, HOME=str(self.home), XDG_STATE_HOME=str(self.home / 'state'))
        for key in list(self.env):
            if key.startswith('HERDR_'):
                self.env.pop(key)

    def run_command(self, command, name='Fixture action', **kwargs):
        return subprocess.run([sys.executable, str(RUNNER), 'run', '--name', name, '--', *command],
                              env=self.env, capture_output=True, text=True, timeout=10, check=False, **kwargs)

    def logs(self):
        return list((self.home / 'state/herdr/action-errors').glob('*.log'))

    def test_runner_exists(self):
        self.assertTrue(RUNNER.is_file(), 'shared error runner has not been implemented')

    @unittest.skipUnless(RUNNER.exists(), 'runner not implemented yet')
    def test_success_preserves_arguments_stdin_output_and_leaves_no_failure_log(self):
        code = 'import sys; print(repr(sys.argv[1:])); print(input()); print("stderr", file=sys.stderr)'
        result = self.run_command([sys.executable, '-c', code, "a'b", 'two words', '$(false)'], input='hello\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(repr(["a'b", 'two words', '$(false)']), result.stdout)
        self.assertIn('hello', result.stdout)
        self.assertIn('stderr', result.stdout + result.stderr)
        self.assertEqual(self.logs(), [])

    @unittest.skipUnless(RUNNER.exists(), 'runner not implemented yet')
    def test_failure_retains_private_unique_logs_metadata_and_original_status(self):
        for _ in range(2):
            result = self.run_command(['sh', '-c', 'echo progress; echo "Error: fixture" >&2; exit 7'])
            self.assertEqual(result.returncode, 7, result.stderr)
            self.assertIn('Error: fixture', result.stdout + result.stderr)
            self.assertIn('log:', result.stderr.lower())
        logs = self.logs()
        self.assertEqual(len(logs), 2)
        for log in logs:
            self.assertEqual(stat.S_IMODE(log.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(log.parent.stat().st_mode), 0o700)
            self.assertIn('progress', log.read_text())
            self.assertIn('Error: fixture', log.read_text())
            meta = json.loads(log.with_suffix('.json').read_text())
            self.assertEqual(meta['name'], 'Fixture action')
            self.assertEqual(meta['status'], 7)

    @unittest.skipUnless(RUNNER.exists(), 'runner not implemented yet')
    def test_nested_runner_reports_only_once(self):
        result = self.run_command([sys.executable, str(RUNNER), 'run', '--name', 'Inner', '--', 'sh', '-c', 'echo nested; exit 9'])
        self.assertEqual(result.returncode, 9)
        self.assertEqual(len(self.logs()), 1)
        meta = json.loads(self.logs()[0].with_suffix('.json').read_text())
        self.assertEqual(meta['name'], 'Fixture action')

    @unittest.skipUnless(RUNNER.exists(), 'runner not implemented yet')
    def test_background_failure_can_report_existing_logs_despite_inherited_marker(self):
        source = self.home / 'worker.log'
        source.write_text('Error: background build failed\n')
        self.env['HERDR_ACTION_ERROR_ACTIVE'] = '1'
        result = subprocess.run([sys.executable, str(RUNNER), 'notify', '--name', 'Background fixture',
                                 '--status', '6', '--message', 'Worker failed after launch',
                                 '--source-log', str(source)], env=self.env, capture_output=True,
                                text=True, timeout=10, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.logs()), 1)
        self.assertIn('Error: background build failed', self.logs()[0].read_text())
        self.assertEqual(source.read_text(), 'Error: background build failed\n')
        self.assertEqual(json.loads(self.logs()[0].with_suffix('.json').read_text())['status'], 6)

    @unittest.skipUnless(RUNNER.exists(), 'runner not implemented yet')
    def test_missing_executable_is_reported_as_127(self):
        result = self.run_command(['/nonexistent/herdr-test-command'])
        self.assertEqual(result.returncode, 127)
        self.assertEqual(len(self.logs()), 1)

    @unittest.skipUnless(RUNNER.exists(), 'runner not implemented yet')
    def test_missing_socket_does_not_mask_action_status(self):
        self.env.update(HERDR_ENV='1', HERDR_SOCKET_PATH=str(self.home / 'missing.sock'))
        result = self.run_command(['sh', '-c', 'echo failure >&2; exit 23'])
        self.assertEqual(result.returncode, 23)
        self.assertEqual(len(self.logs()), 1)
        self.assertNotIn('Traceback', result.stderr)

    @unittest.skipUnless(RUNNER.exists(), 'runner not implemented yet')
    def test_metadata_write_failure_does_not_replace_action_status(self):
        module = load_runner()
        with patch.dict(os.environ, self.env, clear=True), \
             patch.object(module.json, 'dump', side_effect=OSError('fixture full disk')), \
             patch.object(module, 'forward_output'):
            self.assertEqual(module.run_action('Fixture', ['sh', '-c', 'exit 19']), 19)

    @unittest.skipUnless(RUNNER.exists(), 'runner not implemented yet')
    def test_background_child_does_not_hold_runner_output_pipe_open(self):
        started = time.monotonic()
        result = self.run_command(['sh', '-c', 'sleep 2 & echo done'])
        self.assertEqual(result.returncode, 0)
        self.assertLess(time.monotonic() - started, 1.5)


@unittest.skipUnless(RUNNER.exists(), 'runner not implemented yet')
class ReporterTests(unittest.TestCase):
    def setUp(self):
        self.module = load_runner()
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.log = Path(self.temp.name) / 'failure.log'
        self.log.write_text('progress\n\x1b[31mError: fixture\x1b[0m\n')
        self.meta = {'name': "Fixture ' action", 'status': 7, 'cwd': self.temp.name, 'time': '2026-11-13T00:00:00'}
        self.log.with_suffix('.json').write_text(json.dumps(self.meta))
        self.calls = []
        self.workspaces = [{'label': 'HERDR-ACTION-ERRORS', 'workspace_id': 'wError'}]

    def api(self, method, params):
        self.calls.append((method, params))
        if method == 'workspace.list':
            return {'workspaces': list(self.workspaces)}
        if method == 'workspace.create':
            self.workspaces.append({'label': 'HERDR-ACTION-ERRORS', 'workspace_id': 'wNew'})
            return {'workspace': {'workspace_id': 'wNew'}, 'root_pane': {'pane_id': 'wNew:p1'}}
        return {}

    def report(self):
        with patch.object(self.module, 'api', side_effect=self.api):
            self.module.report_failure(self.log)

    def test_reuses_workspace_opens_new_log_tab_and_popup_without_notification_api(self):
        self.report()
        methods = [method for method, _ in self.calls]
        self.assertNotIn('workspace.create', methods)
        popup = next(params for method, params in self.calls if method == 'plugin.pane.open' and params['placement'] == 'popup')
        self.assertEqual(popup['placement'], 'popup')
        self.assertEqual(popup['plugin_id'], 'local.action-errors')
        self.assertNotIn('target_pane_id', popup)
        self.assertNotIn('notification.show', methods)
        log_tab = next(params for method, params in self.calls if method == 'plugin.pane.open' and params['placement'] == 'tab')
        self.assertEqual(log_tab['workspace_id'], 'wError')
        self.assertEqual(log_tab['env']['HERDR_ACTION_ERROR_LOG'], str(self.log))
        self.assertFalse(log_tab['focus'])
        self.assertNotIn('pane.run', methods)
        self.assertNotIn('pane.send_input', methods)

    def test_first_report_uses_new_workspaces_initial_tab(self):
        self.workspaces = []
        self.report()
        log_views = [params for method, params in self.calls
                     if method == 'plugin.pane.open' and params['entrypoint'] == 'log']
        self.assertEqual(len(log_views), 1)
        self.assertEqual(log_views[0]['placement'], 'zoomed')
        self.assertEqual(log_views[0]['target_pane_id'], 'wNew:p1')
        self.assertEqual(log_views[0]['workspace_id'], 'wNew')
        self.assertEqual(log_views[0]['env']['HERDR_ACTION_ERROR_LOG'], str(self.log))
        self.assertFalse(log_views[0]['focus'])
        methods = [method for method, _ in self.calls]
        self.assertNotIn('pane.run', methods)
        self.assertNotIn('pane.send_input', methods)
        self.report()
        later_log = [params for method, params in self.calls
                     if method == 'plugin.pane.open' and params['entrypoint'] == 'log'][-1]
        self.assertEqual(later_log['placement'], 'tab')
        self.assertNotIn('target_pane_id', later_log)

    def test_creates_workspace_only_once_for_successive_reports(self):
        self.workspaces = []
        self.report()
        self.report()
        self.assertEqual(sum(method == 'workspace.create' for method, _ in self.calls), 1)
        self.assertEqual(sum(method == 'plugin.pane.open' and params['placement'] == 'popup' for method, params in self.calls), 2)

    def test_first_log_failure_does_not_prevent_popup(self):
        self.workspaces = []
        original = self.api
        def fail(method, params):
            if method == 'plugin.pane.open' and params['placement'] == 'zoomed':
                raise RuntimeError('fixture initial log failure')
            return original(method, params)
        with patch.object(self.module, 'api', side_effect=fail):
            self.module.report_failure(self.log)
        self.assertTrue(any(method == 'plugin.pane.open' and params['placement'] == 'popup'
                            for method, params in self.calls))

    def test_log_tab_failure_does_not_prevent_popup(self):
        original = self.api
        def fail(method, params):
            if method == 'plugin.pane.open' and params['placement'] == 'tab':
                raise RuntimeError('fixture tab failure')
            return original(method, params)
        with patch.object(self.module, 'api', side_effect=fail):
            self.module.report_failure(self.log)
        self.assertIn('plugin.pane.open', [method for method, _ in self.calls])

    def test_concurrent_reports_create_only_one_workspace(self):
        self.workspaces = []
        original = self.api
        def slow_api(method, params):
            if method == 'workspace.create':
                time.sleep(0.03)
            return original(method, params)
        with patch.object(self.module, 'api', side_effect=slow_api):
            threads = [threading.Thread(target=self.module.report_failure, args=(self.log,)) for _ in range(3)]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join(timeout=3)
                self.assertFalse(thread.is_alive())
        self.assertEqual(sum(method == 'workspace.create' for method, _ in self.calls), 1)
        placements = [params['placement'] for method, params in self.calls
                      if method == 'plugin.pane.open' and params['entrypoint'] == 'log']
        self.assertEqual(placements.count('zoomed'), 1)
        self.assertEqual(placements.count('tab'), 2)

    def test_deferred_report_waits_for_picker_to_disappear(self):
        with patch.object(self.module, 'api', side_effect=[{}, {}, RuntimeError('pane not found')]) as fake_api, \
             patch.object(self.module.time, 'sleep') as sleep, \
             patch.object(self.module, 'report_failure') as report:
            self.module.deferred_report(self.log, 'wPicker:p1')
        self.assertEqual(fake_api.call_count, 3)
        self.assertEqual(sleep.call_count, 2)
        report.assert_called_once_with(self.log)

    def test_log_view_labels_its_own_tab_and_prints_complete_output(self):
        with patch.dict(os.environ, {'HERDR_TAB_ID': 'wError:t2'}), \
             patch.object(self.module, 'api') as fake_api, \
             patch.object(sys, 'stdout', new_callable=io.StringIO) as output:
            self.module.show_log(self.log)
        fake_api.assert_called_once()
        self.assertEqual(fake_api.call_args.args[0], 'tab.rename')
        self.assertEqual(fake_api.call_args.args[1]['tab_id'], 'wError:t2')
        self.assertIn(self.meta['name'], fake_api.call_args.args[1]['label'])
        self.assertIn('Error: fixture', output.getvalue())
        self.assertIn('Workspace: HERDR-ACTION-ERRORS', output.getvalue())
        self.assertNotIn('\x1b', output.getvalue())

    def test_popup_requests_terminal_default_background(self):
        screen = Mock()
        with patch.object(self.module.curses, 'start_color'), \
             patch.object(self.module.curses, 'use_default_colors') as defaults, \
             patch.object(self.module.curses, 'color_pair', return_value=0):
            self.module.configure_popup_colors(screen)
        defaults.assert_called_once_with()
        screen.bkgd.assert_called_once_with(' ', 0)
        screen.attrset.assert_called_once_with(0)

    def test_popup_color_setup_degrades_on_terminals_without_default_colors(self):
        screen = Mock()
        with patch.object(self.module.curses, 'start_color', side_effect=self.module.curses.error('unsupported')):
            self.module.configure_popup_colors(screen)
        screen.bkgd.assert_not_called()

    def test_display_strips_terminal_control_sequences(self):
        self.assertEqual(self.module.display_text('hello\x1b[31m red\x1b[0m\x1b]52;c;evil\x07\x00'), 'hello red')


@unittest.skipUnless(RUNNER.exists(), 'runner not implemented yet')
class SocketIntegrationTests(RunnerTests):
    def test_picker_report_survives_runner_exit_and_uses_actual_socket_protocol(self):
        path = self.home / 'herdr.sock'
        self.env.update(HERDR_ENV='1', HERDR_SOCKET_PATH=str(path),
                        HERDR_PLUGIN_ENTRYPOINT_ID='quick-actions-picker', HERDR_PANE_ID='wPicker:p1')
        calls = []
        finished = threading.Event()
        with socket.socket(socket.AF_UNIX) as server:
            server.bind(str(path))
            server.listen()
            server.settimeout(4)
            def serve():
                try:
                    while not finished.is_set():
                        connection, _ = server.accept()
                        with connection, connection.makefile() as stream:
                            request = json.loads(stream.readline())
                            calls.append(request)
                            method = request['method']
                            response = {'id': request['id'], 'result': {}}
                            if method == 'pane.get':
                                response = {'id': request['id'], 'error': {'message': 'pane not found'}}
                            elif method == 'workspace.list':
                                response['result'] = {'workspaces': [{'label': 'HERDR-ACTION-ERRORS', 'workspace_id': 'wError'}]}
                            connection.sendall((json.dumps(response) + '\n').encode())
                            if method == 'plugin.pane.open' and request['params']['placement'] == 'popup':
                                finished.set()
                except OSError:
                    finished.set()
            thread = threading.Thread(target=serve, daemon=True)
            thread.start()
            result = self.run_command(['sh', '-c', 'echo "Error: socket fixture"; exit 17'])
            self.assertEqual(result.returncode, 17)
            self.assertTrue(finished.wait(4), 'detached reporter did not open popup')
            thread.join(timeout=4)
        self.assertTrue(any(call['method'] == 'plugin.pane.open' and call['params']['placement'] == 'tab' for call in calls))
        self.assertTrue(any(call['method'] == 'plugin.pane.open' and call['params']['placement'] == 'popup' for call in calls))


class IntegrationTests(unittest.TestCase):
    def test_all_existing_actions_use_shared_runner(self):
        actions = list(ACTIONS.glob('*.toml'))
        self.assertGreaterEqual(len(actions), 44)
        for action in actions:
            data = tomllib.loads(action.read_text())
            with self.subTest(action=action.name):
                command = shlex.split(data['command'])
                self.assertIn('herdr-action-errors.py', command[1])
                self.assertEqual(command[2:4], ['run', '--name'])
                self.assertEqual(command[4], data['name'])
                self.assertIn('--', command)

    @unittest.skipUnless(RUNNER.exists(), 'runner not implemented yet')
    def test_every_configured_action_retains_a_forced_launcher_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            scripts = home / '.config/herdr-spreader'
            scripts.mkdir(parents=True)
            (scripts / RUNNER.name).symlink_to(RUNNER)
            binary = home / 'bin'
            binary.mkdir()
            spreader = binary / 'herdr-spreader'
            spreader.write_text('#!/bin/sh\necho "Error: forced spreader failure" >&2\nexit 31\n')
            spreader.chmod(0o700)
            env = {key: value for key, value in os.environ.items() if not key.startswith('HERDR_')}
            env.update(HOME=str(home), XDG_STATE_HOME=str(home / 'state'), PATH=f'{binary}:{env["PATH"]}')
            for path in sorted(ACTIONS.glob('*.toml')):
                action = tomllib.loads(path.read_text())
                command = action['command']
                for argument in shlex.split(command):
                    if argument.endswith('.sh'):
                        stub = home / argument.removeprefix('~/')
                        stub.write_text('#!/bin/sh\necho "Error: forced action failure" >&2\nexit 31\n')
                rendered = command.replace('{{.Value}}', 'fixture-value')
                if action.get('type') == 'form' and '{{.Value}}' not in command:
                    rendered += ' fixture-value'
                result = subprocess.run(['sh', '-c', rendered], env=env, capture_output=True,
                                        text=True, timeout=10, check=False)
                self.assertEqual(result.returncode, 31, f'{path.name}: {result.stderr}')
            metadata = [json.loads(path.read_text()) for path in (home / 'state/herdr/action-errors').glob('*.json')]
            self.assertEqual({item['name'] for item in metadata}, {tomllib.loads(p.read_text())['name'] for p in ACTIONS.glob('*.toml')})

    def test_legacy_wrappers_use_shared_runner_and_never_type_into_pane(self):
        for wrapper in SCRIPTS.glob('*-notify.sh'):
            with self.subTest(wrapper=wrapper.name):
                source = wrapper.read_text()
                self.assertIn('herdr-action-errors.py', source)
                self.assertNotIn('herdr pane run', source)


if __name__ == '__main__':
    unittest.main()
