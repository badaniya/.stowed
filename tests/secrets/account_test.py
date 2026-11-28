import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / 'secrets/.local/bin/gh-account'


class AccountTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        binary = self.home / 'bin'
        binary.mkdir()
        provider = binary / 'pass'
        provider.write_text('#!/bin/sh\nif [ "$FAIL_PROVIDER" = 1 ]; then echo synthetic-secret >&2; exit 1; fi\nfor secret do :; done\nprintf "synthetic-%s\\n" "$secret"\n')
        provider.chmod(0o755)
        gh = binary / 'gh'
        gh.write_text('#!' + sys.executable + '\nimport os,sys,json\nprint(json.dumps({"args":sys.argv[1:],"token":os.getenv("GH_TOKEN"),"enterprise":os.getenv("GH_ENTERPRISE_TOKEN"),"host":os.getenv("GH_HOST"),"legacy":os.getenv("GITHUB_TOKEN")}))\n')
        gh.chmod(0o755)
        self.config = self.home / '.private_gh_accounts.json'
        self.config.write_text(json.dumps({'work': {'host': 'github.com', 'secret': 'github/work/token'}, 'enterprise': {'host': 'github.example.test', 'secret': 'github/enterprise/token'}}))
        self.config.chmod(0o600)
        self.env = {**os.environ, 'HOME': str(self.home), 'PATH': f'{binary}:{os.defpath}', 'GH_TOKEN': 'legacy-personal', 'GITHUB_TOKEN': 'legacy-personal', 'GH_ENTERPRISE_TOKEN': 'legacy-enterprise'}

    def invoke(self, *args):
        self.assertTrue(LAUNCHER.exists(), 'account launcher missing')
        return subprocess.run([sys.executable, str(LAUNCHER), *args], env=self.env, capture_output=True, text=True)

    def test_work_account_is_scoped_and_arguments_preserved(self):
        result = self.invoke('work', 'repo', 'view', 'name with spaces')
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data['args'], ['repo', 'view', 'name with spaces'])
        self.assertEqual(data['token'], 'synthetic-github/work/token')
        self.assertIsNone(data['enterprise'])
        self.assertIsNone(data['legacy'])

    def test_enterprise_uses_separate_variable_and_host(self):
        result = self.invoke('enterprise', 'api', 'user')
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertIsNone(data['token'])
        self.assertEqual(data['enterprise'], 'synthetic-github/enterprise/token')
        self.assertEqual(data['host'], 'github.example.test')

    def test_provider_failure_never_prints_provider_output(self):
        self.env['FAIL_PROVIDER'] = '1'
        result = self.invoke('work', 'api', 'user')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('synthetic-secret', result.stdout + result.stderr)

    def test_insecure_private_config_is_rejected(self):
        self.config.chmod(0o644)
        result = self.invoke('work', 'api', 'user')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('0600', result.stderr)

    def test_explicit_host_override_is_rejected(self):
        for args in [('api', '--hostname', 'other.example', 'user'), ('api', '-h', 'other.example', 'user')]:
            with self.subTest(args=args):
                result = self.invoke('enterprise', *args)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')

    def test_repo_host_override_is_rejected(self):
        result = self.invoke('enterprise', 'repo', 'view', '--repo', 'other.example/org/repo')
        self.assertNotEqual(result.returncode, 0)

    def test_token_printing_is_blocked(self):
        result = self.invoke('work', 'auth', 'token')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')

    def test_missing_account_is_rejected(self):
        result = self.invoke('missing', 'api', 'user')
        self.assertNotEqual(result.returncode, 0)

    def test_native_login_is_blocked(self):
        result = self.invoke('work', 'auth', 'login')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('manage credentials in pass;', result.stderr)


if __name__ == '__main__':
    unittest.main()
