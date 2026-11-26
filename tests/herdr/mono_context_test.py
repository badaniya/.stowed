#!/usr/bin/env python3
"""Exercise mono context aggregation with real, isolated local Git worktrees."""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / 'herdr-spreader/.config/herdr-spreader'


class MonoContextTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        home = self.root / 'home'
        self.workspace = home / 'workspace/tester'
        (self.workspace / 'master').mkdir(parents=True)
        self.scripts = home / '.config/herdr-spreader'
        self.scripts.mkdir(parents=True)
        for name in ['monorepo-worktree-sandbox-base.sh', 'multirepo-worktree.sh', 'private-env.sh']:
            shutil.copy2(SCRIPTS / name, self.scripts / name)
        binary = self.root / 'bin'
        binary.mkdir()
        gh = binary / 'gh'
        gh.write_text('#!/bin/sh\nexit 1\n')
        gh.chmod(0o700)
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith(('HERDR_', 'MONOREPO_', 'MULTIREPO_', 'GIT_', 'CLAUDE_'))}
        self.env.update(HOME=str(home), MONOREPO_NAME='mono-repo', USER='tester', PATH=f'{binary}:{os.environ["PATH"]}',
                        MULTIREPO_EXTRA_URL='https://git.example.com/owner/extra-repo.git',
                        MULTIREPO_TICKET_PREFIX='MULTI', MULTIREPO_EXTRA_REPO='extra-repo',
                        MONOREPO_GH_USER='fixture-user', MONOREPO_CONTEXT_SOURCES='app platform/services',
                        WS_ROOT=str(self.workspace), WS_OWNER='tester',
                        GIT_CONFIG_GLOBAL=str(home / '.gitconfig'), GIT_CONFIG_NOSYSTEM='1',
                        GIT_AUTHOR_NAME='Fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
                        GIT_COMMITTER_NAME='Fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid',
                        MONO_REVIEW_MODE='false', MULTIREPO_WORKSPACE='false')
        seed = self.root / 'seed'
        self.run_command('git', 'init', '-q', '-b', 'main', seed)
        self.put(seed / 'app/.agents/skills/app-only/SKILL.md', 'App skill')
        self.put(seed / 'app/.agents/skills/shared/SKILL.md', 'App wins')
        (seed / 'app/.claude').mkdir()
        (seed / 'app/.claude/skills').symlink_to('../.agents/skills')
        self.put(seed / 'platform/services/.claude/skills/ps-only/SKILL.md', 'PS skill')
        self.put(seed / 'platform/services/.claude/skills/shared/SKILL.md', 'PS loses')
        self.put(seed / 'platform/services/.claude/skills/shared/references/ps.md', 'PS reference')
        self.run_command('git', '-C', seed, 'add', '.')
        self.run_command('git', '-C', seed, 'commit', '-qm', 'fixture')
        self.run_command('git', 'clone', '-q', '--bare', seed,
                         self.workspace / 'master/mono-repo')
        cloud = self.root / 'cloud'
        self.run_command('git', 'init', '-q', '-b', 'master', cloud)
        self.put(cloud / '.claude/skills/extra-only/SKILL.md', 'extra skill')
        self.run_command('git', '-C', cloud, 'add', '.')
        self.run_command('git', '-C', cloud, 'commit', '-qm', 'fixture')
        self.run_command('git', 'config', '--global', f'url.{cloud}.insteadOf',
                         'https://git.example.com/owner/extra-repo.git')

    @staticmethod
    def put(path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def run_command(self, *args, extra=None, check=True):
        result = subprocess.run([str(x) for x in args], env=self.env | (extra or {}),
                                capture_output=True, text=True, timeout=20, check=False)
        if check:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def launch(self, ticket='ABC-990001', multirepo=False, check=True):
        return self.run_command('bash', self.scripts / 'monorepo-worktree-sandbox-base.sh',
                                ticket, 'main', extra={'MULTIREPO_WORKSPACE': str(multirepo).lower()},
                                check=check)

    def assert_combined(self, project):
        skills = project / '.agents/skills'
        self.assertTrue((skills / 'ps-only/SKILL.md').is_symlink())
        self.assertEqual((skills / 'ps-only/SKILL.md').read_text(), 'PS skill')
        self.assertEqual((skills / 'shared/SKILL.md').read_text(), 'App wins')
        self.assertEqual((skills / 'shared/references/ps.md').read_text(), 'PS reference')
        self.assertEqual((project / '.claude/skills').resolve(), skills.resolve())

    def test_regular_merges_claude_only_ps_skills_without_app_symlink_shadowing(self):
        self.launch()
        project = self.workspace / 'ABC-990001'
        self.assert_combined(project)
        self.assertEqual(self.run_command('git', '-C', project, 'status', '--porcelain').stdout, '')

    def test_reuse_discovers_new_skills_without_modifying_sources(self):
        self.launch()
        project = self.workspace / 'ABC-990001'
        source = project / 'platform/services/.claude/skills/new-ps/SKILL.md'
        self.put(source, 'new PS skill')
        self.launch()
        self.assertTrue((project / '.agents/skills/new-ps/SKILL.md').is_symlink())
        self.assertEqual(source.read_text(), 'new PS skill')
        self.assertEqual((project / 'app/.agents/skills/shared/SKILL.md').read_text(), 'App wins')

    def test_symlinked_source_skill_root_is_followed(self):
        self.launch()
        project = self.workspace / 'ABC-990001'
        ps = project / 'platform/services'
        (ps / '.claude/skills').rename(ps / 'agent-skills')
        (ps / '.claude/skills').symlink_to('../agent-skills')
        self.launch()
        self.assert_combined(project)

    def test_multirepo_parent_merges_all_three_sources(self):
        self.launch('MULTI-990002-MONO', multirepo=True)
        project = self.workspace / 'MULTI-990002-MONO'
        self.assert_combined(project)
        self.assertEqual((project / '.agents/skills/extra-only/SKILL.md').read_text(), 'extra skill')
        self.assertFalse((project / '.git').exists())

    def test_unmanaged_context_is_not_replaced(self):
        self.launch()
        project = self.workspace / 'ABC-990001'
        (project / '.agents/.herdr-aggregate-context').unlink()
        result = self.launch(check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('refusing to replace unmanaged', result.stderr)
        self.assertEqual((project / '.agents/skills/shared/SKILL.md').read_text(), 'App wins')


if __name__ == '__main__':
    unittest.main()
