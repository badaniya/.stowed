"""Review teardown handles lost Git registration without touching other worktrees."""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / 'herdr-spreader/.config/herdr-spreader/monorepo-review-sandbox-remove.sh'


class ReviewMonoRemoveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.bin = self.root / 'bin'
        self.workspace = self.root / 'workspace'
        self.bare = self.workspace / 'master/mono-repo'
        self.key = 'REVIEW-JIRA-12345'
        self.project = self.workspace / self.key
        self.state = self.root / 'state/herdr-spreader'
        self.log = self.root / 'commands.log'
        self.env = dict(os.environ, HOME=str(self.home), MONOREPO_NAME='mono-repo', XDG_STATE_HOME=str(self.root / 'state'),
                        PATH=f'{self.bin}:{os.environ["PATH"]}', WS_ROOT=str(self.workspace),
                        WS_OWNER='tester', TEST_LOG=str(self.log),
                        GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=str(self.home / '.gitconfig'))
        for key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR'):
            self.env.pop(key, None)
        self.bin.mkdir()
        (self.home / '.local/bin').mkdir(parents=True)
        self.bare.parent.mkdir(parents=True)
        self.command(self.home / '.local/bin/labctl', 'printf "labctl %s\\n" "$*" >>"$TEST_LOG"\n[[ ${TEST_FAIL_DESTROY:-false} != true ]]\n')
        self.command(self.bin / 'sg', '[[ $1 == incus-admin && $2 == -c ]] || exit 2\nbash -c "$3"\n')
        self.command(self.bin / 'sudo', '[[ $1 == chown ]] || exit 2\nprintf "sudo %s\\n" "$*" >>"$TEST_LOG"\n')
        self.command(self.bin / 'herdr', '''
printf 'herdr %s\\n' "$*" >>"$TEST_LOG"
if [[ $1 == workspace && $2 == list ]]; then
  printf '%s\\n' '{"result":{"workspaces":[{"label":"REVIEW-JIRA-12345 - Review","workspace_id":"w1"},{"label":"REVIEW-JIRA-123450","workspace_id":"w2"}]}}'
else
  [[ $1 == workspace && $2 == close && $3 == w1 ]]
fi
''')
        seed = self.root / 'seed'
        self.git('init', '-q', '-b', 'main', str(seed))
        (seed / 'file').write_text('base\n')
        self.git('-C', str(seed), 'add', '.')
        self.git('-C', str(seed), '-c', 'user.name=Fixture', '-c', 'user.email=test@example.invalid',
                 'commit', '-qm', 'initial')
        self.git('clone', '-q', '--bare', str(seed), str(self.bare))
        self.git('-C', str(self.bare), 'worktree', 'add', '-q', '-b', 'alice/JIRA-12345', str(self.project), 'main')
        (self.project / 'file').write_text('unpushed commit\n')
        self.git('-C', str(self.project), '-c', 'user.name=Fixture', '-c', 'user.email=test@example.invalid',
                 'commit', '-qam', 'local work')
        self.commit = self.git('-C', str(self.project), 'rev-parse', 'HEAD').strip()
        (self.project / 'dirty-file').write_text('local changes\n')
        self.admin = Path(self.git('-C', str(self.project), 'rev-parse', '--absolute-git-dir').strip())
        self.other = self.workspace / 'JIRA-12346'
        self.git('-C', str(self.bare), 'worktree', 'add', '-q', '--detach', str(self.other), 'main')
        (self.state / f'{self.key}.stages').mkdir(parents=True)
        (self.state / f'{self.key}.log').touch()
        (self.state / f'{self.key}-other.log').touch()
        self.log.write_text('')

    def command(self, path, body):
        path.write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + body)
        path.chmod(0o755)

    def git(self, *args):
        return subprocess.run(['git', *args], env=self.env, check=True,
                              capture_output=True, text=True).stdout

    def remove(self, *args, fail_destroy=False):
        return subprocess.run(['bash', str(SCRIPT), self.key, *args],
                              env=dict(self.env, TEST_FAIL_DESTROY=str(fail_destroy).lower()),
                              capture_output=True, text=True)

    def assert_cleaned(self):
        self.assertFalse(self.project.exists())
        self.assertEqual(self.git('-C', str(self.bare), 'rev-parse', 'alice/JIRA-12345').strip(), self.commit)
        self.assertEqual(self.git('-C', str(self.other), 'rev-parse', '--is-inside-work-tree').strip(), 'true')
        self.assertFalse((self.state / f'{self.key}.log').exists())
        self.assertTrue((self.state / f'{self.key}-other.log').exists())
        calls = self.log.read_text().splitlines()
        self.assertIn(f'labctl destroy {self.key} --yes', calls)
        self.assertEqual(calls[-1], 'herdr workspace close w1')

    def check_suffixed_identity(self, key):
        old_key = self.key
        old_project = self.project
        self.key = key
        self.project = self.workspace / key
        self.git('-C', str(self.bare), 'worktree', 'move', str(old_project), str(self.project))
        for suffix in ('.stages', '.log', '-other.log'):
            (self.state / f'{old_key}{suffix}').rename(self.state / f'{key}{suffix}')
        # The unsuffixed and longer identities must not be closed by teardown.
        self.command(self.bin / 'herdr', f'''
printf 'herdr %s\\n' "$*" >>"$TEST_LOG"
if [[ $1 == workspace && $2 == list ]]; then
  printf '%s\\n' '{{"result":{{"workspaces":[{{"label":"{key} - Review","workspace_id":"w1"}},{{"label":"{old_key}","workspace_id":"w2"}},{{"label":"{key}-OTHER","workspace_id":"w3"}}]}}}}'
else
  [[ $1 == workspace && $2 == close && $3 == w1 ]]
fi
''')
        result = self.remove()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_cleaned()
        self.assertNotIn(f'labctl destroy {old_key} --yes', self.log.read_text())

    def test_suffixed_jira_identity_is_removed_without_truncation(self):
        self.check_suffixed_identity('REVIEW-JIRA-12345-TEST')

    def test_suffixed_pr_identity_is_removed_without_truncation(self):
        self.check_suffixed_identity('REVIEW-PR-9795-TEST-2')

    def test_unsafe_suffixes_are_rejected_before_destroy(self):
        for key in ('REVIEW-JIRA-12345-../OTHER', 'REVIEW-JIRA-12345-TEST/OTHER',
                    'REVIEW-JIRA-12345-TEST;', 'REVIEW-JIRA-12345-', 'REVIEW-JIRA-12345--TEST'):
            with self.subTest(key=key):
                self.key = key
                result = self.remove()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.log.read_text(), '')
                self.assertTrue(self.project.exists())

    def test_registered_worktree_cleanup_preserves_pr_branch(self):
        result = self.remove()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_cleaned()

    def test_lost_registration_cleanup_preserves_branch_and_other_registrations(self):
        shutil.rmtree(self.admin)
        # A separate missing checkout must not be globally pruned by this action.
        missing = self.root / 'temporarily-unmounted'
        self.git('-C', str(self.bare), 'worktree', 'add', '-q', '--detach', str(missing), 'main')
        missing_admin = Path(self.git('-C', str(missing), 'rev-parse', '--absolute-git-dir').strip())
        shutil.rmtree(missing)
        result = self.remove()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_cleaned()
        self.assertTrue(missing_admin.exists())

    def test_foreign_dangling_gitfile_is_rejected_before_destroy(self):
        (self.project / '.git').write_text(f'gitdir: {self.root}/foreign/worktrees/{self.key}\n')
        result = self.remove()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.log.read_text(), '')
        self.assertTrue((self.project / 'dirty-file').exists())

    def test_wrong_valid_repository_is_rejected_before_destroy(self):
        self.git('-C', str(self.bare), 'worktree', 'remove', '--force', str(self.project))
        foreign = self.root / 'foreign'
        self.git('clone', '-q', '--bare', str(self.root / 'seed'), str(foreign))
        self.git('-C', str(foreign), 'worktree', 'add', '-q', '--detach', str(self.project), 'main')
        result = self.remove()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.log.read_text(), '')

    def test_failed_destroy_leaves_orphan_and_state_untouched(self):
        shutil.rmtree(self.admin)
        result = self.remove(fail_destroy=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.project / 'dirty-file').exists())
        self.assertTrue((self.state / f'{self.key}.log').exists())
        self.assertNotIn('sudo ', self.log.read_text())
        self.assertNotIn('workspace close', self.log.read_text())

    def test_keep_worktrees_preserves_orphan_and_state(self):
        shutil.rmtree(self.admin)
        result = self.remove('--keep-worktrees')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.project / 'dirty-file').exists())
        self.assertTrue((self.state / f'{self.key}.log').exists())
        self.assertNotIn('sudo ', self.log.read_text())

    def test_symlink_project_is_rejected_before_destroy(self):
        moved = self.root / 'moved'
        self.project.rename(moved)
        self.project.symlink_to(moved)
        result = self.remove()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.log.read_text(), '')


if __name__ == '__main__':
    unittest.main()
