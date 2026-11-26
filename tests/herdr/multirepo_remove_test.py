"""Mono removal must preserve alias identity and isolate side-by-side workspaces."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[2] / 'herdr-spreader/.config/herdr-spreader'


class MultirepoMonoRemoveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.bin = self.root / 'bin'
        self.workspace = self.home / 'workspace/tester'
        self.log = self.root / 'commands.log'
        self.env = dict(os.environ, HOME=str(self.home), MONOREPO_NAME='mono-repo', MULTIREPO_EXTRA_URL='https://git.example.com/owner/extra-repo.git',
                        MULTIREPO_TICKET_PREFIX='MULTI', MULTIREPO_EXTRA_REPO='extra-repo',
                        PATH=f'{self.bin}:{os.environ["PATH"]}',
                        WS_ROOT=str(self.workspace), WS_OWNER='tester',
                        GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=str(self.home / '.gitconfig'),
                        GIT_ALLOW_PROTOCOL='file', TEST_LOG=str(self.log))
        for key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR'):
            self.env.pop(key, None)
        self.bin.mkdir(parents=True)
        (self.home / '.local/bin').mkdir(parents=True)
        (self.workspace / 'master').mkdir(parents=True)
        self.command(self.home / '.local/bin/labctl', '''
printf 'labctl %s\\n' "$*" >>"$TEST_LOG"
[[ ${TEST_FAIL_DESTROY:-false} != true ]]
''')
        self.command(self.bin / 'sg', '[[ $1 == incus-admin && $2 == -c ]] || exit 2\nbash -c "$3"\n')
        self.command(self.bin / 'sudo', 'printf "sudo %s\\n" "$*" >>"$TEST_LOG"\n')
        self.command(self.bin / 'herdr', '''
printf 'herdr %s\\n' "$*" >>"$TEST_LOG"
if [[ $1 == workspace && $2 == list ]]; then
  printf '%s\\n' '{"result":{"workspaces":[{"label":"MULTI-12","workspace_id":"w1"},{"label":"MULTI-12-MONO","workspace_id":"w2"},{"label":"MULTI-12-MONO editor","workspace_id":"w3"},{"label":"MULTI-12-MONO-extra","workspace_id":"w4"}]}}'
fi
''')
        seed = self.root / 'seed'
        self.git('init', '-q', '-b', 'master', str(seed))
        self.git('-C', str(seed), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                 'commit', '-qm', 'initial', '--allow-empty')
        for repo in ('extra-repo', 'mono-repo'):
            self.git('clone', '-q', '--bare', str(seed), str(self.workspace / 'master' / repo))
        extra = str(self.workspace / 'master/extra-repo')
        self.git('-C', extra, 'config', 'remote.origin.url',
                 'https://git.example.com/owner/extra-repo.git')
        self.git('-C', extra, 'config', 'remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*')
        self.git('-C', extra, 'update-ref', 'refs/remotes/origin/master', 'master')
        for ticket in ('MULTI-12', 'MULTI-12-MONO'):
            project = self.workspace / ticket
            for repo, branch in (('extra-repo', f'tester/extra-repo/{ticket}'),
                                 ('mono-repo', f'tester/{ticket}')):
                bare = str(self.workspace / 'master' / repo)
                self.git('-C', bare, 'worktree', 'add', '-q', '-b', branch, str(project / repo), 'master')
                if repo == 'extra-repo':
                    self.git('-C', bare, 'config', f'branch.{branch}.remote', 'origin')
                    self.git('-C', bare, 'config', f'branch.{branch}.merge', 'refs/heads/master')
                (project / repo / 'local-edits').write_text('preserve unless explicitly removed\n')
            for context in ('.agents', '.claude'):
                (project / context).mkdir()
                (project / context / '.herdr-aggregate-context').touch()
        self.log.write_text('')

    def command(self, path, body):
        path.write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + body)
        path.chmod(0o755)

    def git(self, *args):
        return subprocess.run(['git', *args], env=self.env, check=True,
                              capture_output=True, text=True).stdout

    def remove(self, *args, shared=False, fail_destroy=False):
        script = 'monorepo-worktree-sandbox-remove.sh' if shared else 'multirepo-worktree-sandbox-remove.sh'
        env = dict(self.env, TEST_FAIL_DESTROY=str(fail_destroy).lower())
        return subprocess.run(['bash', str(SCRIPTS / script), *args], env=env, check=False,
                              capture_output=True, text=True)

    def assert_preserved(self, ticket):
        for repo in ('extra-repo', 'mono-repo'):
            path = self.workspace / ticket / repo
            self.assertTrue((path / 'local-edits').is_file(), str(path))
            listing = self.git('-C', str(self.workspace / 'master' / repo), 'worktree', 'list', '--porcelain')
            self.assertIn(f'worktree {path}\n', listing)

    def assert_removed_alias_only(self):
        self.assertFalse((self.workspace / 'MULTI-12-MONO').exists())
        self.assert_preserved('MULTI-12')
        for repo, branch in (('extra-repo', 'tester/extra-repo/MULTI-12-MONO'),
                             ('mono-repo', 'tester/MULTI-12-MONO')):
            bare = str(self.workspace / 'master' / repo)
            self.assertEqual(self.git('-C', bare, 'rev-parse', '--is-bare-repository').strip(), 'true')
            self.assertNotIn('MULTI-12-MONO', self.git('-C', bare, 'worktree', 'list', '--porcelain'))
            self.assertEqual(self.git('-C', bare, 'branch', '--list', branch), '')
        calls = self.log.read_text().splitlines()
        self.assertIn('labctl destroy MULTI-12-MONO --yes', calls)
        self.assertNotIn('labctl destroy MULTI-12 --yes', calls)
        self.assertEqual([line for line in calls if line.startswith('herdr workspace close ')],
                         ['herdr workspace close w2', 'herdr workspace close w3'])

    def test_form_alias_removes_only_alias_worktrees_and_views(self):
        result = self.remove('MULTI-12-MONO')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_removed_alias_only()

    def test_shared_remover_accepts_alias_without_stripping_suffix(self):
        result = self.remove('MULTI-12-MONO', '--force', shared=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_removed_alias_only()

    def test_single_form_keep_worktrees_preserves_both_workspaces(self):
        result = self.remove('MULTI-12-MONO --keep-worktrees')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_preserved('MULTI-12-MONO')
        self.assert_preserved('MULTI-12')
        self.assertNotIn('sudo ', self.log.read_text())

    def test_positional_force_accepts_alias(self):
        result = self.remove('MULTI-12-MONO', '--force')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_removed_alias_only()

    def test_failed_destroy_does_not_remove_worktrees_or_close_views(self):
        result = self.remove('MULTI-12-MONO', fail_destroy=True)
        self.assertNotEqual(result.returncode, 0)
        calls = self.log.read_text().splitlines()
        self.assertEqual(calls, ['labctl destroy MULTI-12-MONO --yes'])
        self.assert_preserved('MULTI-12-MONO')
        self.assert_preserved('MULTI-12')

    def test_plain_ticket_still_supported(self):
        result = self.remove('MULTI-12')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.workspace / 'MULTI-12').exists())
        self.assert_preserved('MULTI-12-MONO')

    def test_rejects_malformed_aliases_before_any_destruction(self):
        for ticket in ('MULTI-12-MONO-extra', 'MULTI-12-mono', 'ABC-12-MONO',
                       'MULTI-12-MONO/../MULTI-12', 'MULTI - 12-MONO',
                       'MULTI-12-MONO --unknown',
                       'MULTI-12-MONO --force --keep-worktrees'):
            for shared in (False, True):
                if shared and ticket.endswith('--force --keep-worktrees'):
                    continue  # The dedicated launcher owns the conflicting-flag check.
                with self.subTest(ticket=ticket, shared=shared):
                    result = self.remove(ticket, shared=shared)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(self.log.read_text(), '')
        self.assert_preserved('MULTI-12-MONO')
        self.assert_preserved('MULTI-12')

    def test_branch_checked_out_in_external_worktree_does_not_fail_cleanup(self):
        bare = str(self.workspace / 'master/mono-repo')
        extra_wt = self.root / 'scratchpad/rebase-wt'
        self.git('-C', bare, 'worktree', 'add', '-q', '--detach', str(extra_wt), 'tester/MULTI-12-MONO')
        self.git('-C', str(extra_wt), 'switch', '-q', '--ignore-other-worktrees', 'tester/MULTI-12-MONO')
        result = self.remove('MULTI-12-MONO')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Note: keeping local branch tester/MULTI-12-MONO (still checked out in another worktree)',
                      result.stdout)
        self.assertFalse((self.workspace / 'MULTI-12-MONO').exists())
        self.assert_preserved('MULTI-12')
        self.assertNotIn(str(self.workspace / 'MULTI-12-MONO'),
                         self.git('-C', bare, 'worktree', 'list', '--porcelain'))
        self.assertIn('tester/MULTI-12-MONO', self.git('-C', bare, 'branch', '--list', 'tester/MULTI-12-MONO'))
        calls = self.log.read_text().splitlines()
        self.assertEqual([line for line in calls if line.startswith('herdr workspace close ')],
                         ['herdr workspace close w2', 'herdr workspace close w3'])


if __name__ == '__main__':
    unittest.main()
