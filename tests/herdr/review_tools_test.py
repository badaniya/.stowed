import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


class ReviewToolsTest(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('review_tools', ROOT / 'scripts/review-tools.py')
        assert spec is not None and spec.loader is not None
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.tool('node', 'v24.0.0')
        for name in ['npm', 'git', 'jq', 'rg', 'nvim', 'incus', 'pass', 'gpg', 'labctl', 'gh-work', 'pass-unlocked']:
            self.tool(name, 'fixture 1.0.0')
        self.tool('tuicr', 'tuicr 0.30.0')
        self.tool('gh', 'gh dash\tdlvhdr/gh-dash\tv4.26.0')
        self.tool('gh-dash', 'gh-dash version 4.26.0')
        pi = self.home / '.pi/agent/bin/pi'
        pi.parent.mkdir(parents=True)
        pi.write_text('#!/bin/sh\necho 1.6.1\n')
        pi.chmod(0o755)
        version = self.home / '.pi/agent/install/current-version'
        version.parent.mkdir(parents=True)
        version.write_text('1.6.1\n')
        self.checker = self.mod.Tooling(home=self.home, env={'PATH': str(self.bin), 'GH_TOKEN': 'synthetic-credential'})

    def tool(self, name, output, code=0):
        p = self.bin / name
        p.write_text('#!/bin/sh\nprintf "%s\\n" ' + repr(output) + '\nexit ' + str(code) + '\n')
        p.chmod(0o755)

    def bad(self):
        return {r['tool'] for r in self.checker.check() if not r['ok']}

    def test_complete_fixture_passes(self):
        self.assertEqual(self.bad(), set())

    def test_exact_pin_and_broken_shim_are_reported(self):
        self.tool('tuicr', 'tuicr 0.29.0')
        self.tool('nvim', 'synthetic-credential', code=1)
        self.assertEqual(self.bad(), {'tuicr', 'nvim'})
        self.assertNotIn('synthetic-credential', json.dumps(self.checker.check()))

    def test_extension_registration_and_version_both_required(self):
        self.tool('gh', 'no extensions')
        self.assertIn('gh-dash', self.bad())
        self.tool('gh', 'gh dash\tdlvhdr/gh-dash\tv4.26.0')
        self.tool('gh-dash', 'gh-dash version 4.25.0')
        self.assertIn('gh-dash', self.bad())

    def test_missing_managed_pi_and_version_disagreement(self):
        (self.home / '.pi/agent/install/current-version').unlink()
        self.assertIn('pi', self.bad())
        (self.home / '.pi/agent/install/current-version').write_text('9.9.9\n')
        self.assertIn('pi', self.bad())

    def test_check_does_not_install_or_use_tokens(self):
        self.assertNotIn('GH_TOKEN', self.checker.env)
        with patch.object(self.checker, 'install', side_effect=AssertionError('must not install')):
            self.checker.check()

    def test_node_floor(self):
        self.tool('node', 'v22.18.0')
        self.assertIn('node', self.bad())

    def test_path_does_not_shadow_inherited_binary(self):
        self.assertTrue(self.checker.env['PATH'].startswith(str(self.bin) + os.pathsep))

    def test_installer_is_idempotent_for_complete_host(self):
        with patch.object(self.checker, 'execute', side_effect=AssertionError('must not install')):
            self.checker.install()

    def test_install_unusable_prerequisite_fails_without_sudo(self):
        self.tool('nvim', '', code=1)
        with patch.object(self.checker, 'execute', side_effect=AssertionError('must not install')), self.assertRaises(RuntimeError):
            self.checker.install()

    def test_extension_upgrade_preserves_rollback_copy(self):
        local_bin = self.home / '.local/bin'
        local_bin.mkdir(parents=True)
        (local_bin / 'gh-work').symlink_to(self.bin / 'gh-work')
        extension = self.home / '.local/share/gh/extensions/gh-dash'
        extension.mkdir(parents=True)
        (extension / 'gh-dash').write_text('old fixture binary')
        with patch.object(self.checker, 'check', side_effect=[[{'tool': 'gh-dash', 'ok': False}], []]), patch.object(self.checker, 'execute') as execute:
            self.checker.install()
        self.assertTrue(any('remove' in call.args[0] for call in execute.call_args_list))
        self.assertTrue(any('v4.26.0' in call.args[0] for call in execute.call_args_list))
        backups = list((self.home / '.local/state/dotfiles/review-tools').glob('gh-dash-*/gh-dash'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'old fixture binary')

    def test_failed_preflight_creates_no_workspace_state(self):
        gate = self.home / '.stowed/scripts/review-tools.py'
        gate.parent.mkdir(parents=True)
        gate.write_text('raise SystemExit(1)\n')
        env = dict(os.environ, HOME=str(self.home), PATH='/usr/bin:/bin',
                   REVIEW_MODE='true', REVIEW_KEY='REVIEW-ABC-12',
                   REVIEW_BRANCH='test/ABC-12', REVIEW_JIRA_TICKET='ABC-12',
                   SANDBOX_BOOTSTRAP_WORKER='false')
        result = subprocess.run(['bash', str(ROOT / 'herdr-spreader/.config/herdr-spreader/monorepo-worktree-sandbox.sh'),
                                 'REVIEW-ABC-12', 'test/ABC-12'], env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Review tools incomplete', result.stderr)
        self.assertFalse((self.home / '.local/state').exists())
        self.assertFalse((self.home / 'workspace').exists())

    def test_bootstrap_detects_work_host_but_honors_public_override(self):
        source = (ROOT / 'scripts/bootstrap.sh').read_text()
        block = source[source.index('step "Review workspace host tools"'):source.index('step "Git filters"')]
        (self.home / '.private_work.env').write_text('fixture; contents must not be sourced\n')
        python = self.bin / 'python3'
        python.write_text('#!/bin/sh\nif [ "$2" = --path ]; then printf "%s" "$PATH"; else echo install-ran; fi\n')
        python.chmod(0o755)
        env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + ':/usr/bin:/bin')
        env.pop('DOTFILES_PROFILE', None)
        script = 'step(){ :; }; note(){ echo "$@"; }; repo_root=/fixture; check_only=false; ' + block
        result = subprocess.run(['bash', '-c', script], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('install-ran', result.stdout)
        env['DOTFILES_PROFILE'] = 'public'
        result = subprocess.run(['bash', '-c', script], env=env, capture_output=True, text=True)
        self.assertNotIn('install-ran', result.stdout)

    def test_integration_precedes_workspace_creation(self):
        coordinator = (ROOT / 'herdr-spreader/.config/herdr-spreader/monorepo-worktree-sandbox.sh').read_text()
        self.assertLess(coordinator.index('review-tools.py'), coordinator.index('workspace_json=$(herdr workspace create'))
        bootstrap = (ROOT / 'scripts/bootstrap.sh').read_text()
        self.assertIn('review-tools.py', bootstrap)
        self.assertIn('DOTFILES_PROFILE', bootstrap)


if __name__ == '__main__':
    unittest.main()
