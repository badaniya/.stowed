"""Git tracks Pi configuration while excluding explicit runtime state fields."""
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


class PiSettingsFilterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / 'repo'
        self.home = self.root / 'home'
        self.bin = self.root / 'bin'
        for path in (self.repo / 'scripts', self.home, self.bin):
            path.mkdir(parents=True)
        shutil.copy(REPO / 'scripts/bootstrap.sh', self.repo / 'scripts/bootstrap.sh')
        shutil.copy(REPO / '.gitattributes', self.repo / '.gitattributes')
        # Exercise the real Git-filter bootstrap; unrelated installers are isolated.
        for name in ('private-links.sh', 'claude-settings.sh', 'pi-bootstrap.sh'):
            path = self.repo / 'scripts' / name
            path.write_text('#!/usr/bin/env bash\nexit 0\n')
            path.chmod(0o755)
        for name in ('bash', 'git', 'jq', 'rg', 'dirname'):
            executable = shutil.which(name)
            assert executable is not None, f'{name} is required for these tests'
            (self.bin / name).symlink_to(executable)
        (self.bin / 'stow').symlink_to('/bin/true')
        (self.home / '.private_bash_profile').write_text(
            'export LANGFUSE_PUBLIC_KEY=fixture\nexport LANGFUSE_SECRET_KEY=fixture\nexport LANGFUSE_BASE_URL=fixture\n')
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin),
                        GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=str(self.home / '.gitconfig'),
                        PI_LAUNCHER=str(self.home / 'absent-pi'))
        for key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR'):
            self.env.pop(key, None)
        self.git('init', '-q')
        self.settings = self.repo / 'pi/.pi/agent/settings.json'
        self.settings.parent.mkdir(parents=True)

    def git(self, *args, check=True):
        return subprocess.run(['git', '-C', str(self.repo), *args], env=self.env,
                              capture_output=True, text=True, check=check)

    def bootstrap(self, *args):
        return subprocess.run(['bash', str(self.repo / 'scripts/bootstrap.sh'), *args],
                              env=self.env, capture_output=True, text=True)

    def configure(self):
        result = self.bootstrap()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_bootstrap_requires_filter_and_is_idempotent(self):
        self.configure()
        self.assertEqual(self.git('config', '--get', 'filter.pi-settings.required', check=False).stdout.strip(), 'true')
        self.configure()
        result = self.bootstrap('--check')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_check_detects_optional_filter_without_mutating_config(self):
        self.git('config', 'filter.pi-settings.clean', "jq 'del(.lastChangelogVersion, .extensionChangelogVersions)'")
        result = self.bootstrap('--check')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('pi-settings', result.stdout)
        self.assertNotEqual(self.git('config', '--get', 'filter.pi-settings.required', check=False).returncode, 0)

    def test_state_is_excluded_but_new_configuration_is_tracked(self):
        self.configure()
        data = {'theme': 'dark', 'lastChangelogVersion': '1.0.0',
                'extensionChangelogVersions': {'fixture': '1.0.0'}}
        self.settings.write_text(json.dumps(data))
        original = self.settings.read_bytes()
        self.git('add', '.gitattributes', 'pi/.pi/agent/settings.json')
        staged = json.loads(self.git('show', ':pi/.pi/agent/settings.json').stdout)
        self.assertEqual(staged, {'theme': 'dark'})
        self.assertEqual(self.settings.read_bytes(), original)
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture')
        data['lastChangelogVersion'] = '2.0.0'
        data['extensionChangelogVersions'] = {'fixture': '2.0.0'}
        self.settings.write_text(json.dumps(data))
        self.git('add', 'pi/.pi/agent/settings.json')
        self.assertEqual(self.git('diff', '--cached', '--exit-code').returncode, 0)
        data['futureConfigKey'] = True
        self.settings.write_text(json.dumps(data))
        self.git('add', 'pi/.pi/agent/settings.json')
        staged = json.loads(self.git('show', ':pi/.pi/agent/settings.json').stdout)
        self.assertEqual(staged, {'theme': 'dark', 'futureConfigKey': True})
        self.assertEqual(json.loads(self.settings.read_text()), data)

    def test_invalid_json_cannot_be_staged(self):
        self.configure()
        self.settings.write_text('{invalid JSON')
        result = self.git('add', 'pi/.pi/agent/settings.json', check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotEqual(self.git('show', ':pi/.pi/agent/settings.json', check=False).returncode, 0)


if __name__ == '__main__':
    unittest.main()
