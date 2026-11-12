#!/usr/bin/env python3
"""AppArmor preflight/policy tests; never load policy or touch live networking."""
import importlib.util
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'herdr/.config/herdr-spreader/sandbox-exposure.py'
sys.path.insert(0, str(SOURCE.parent))
POLICY = SOURCE.with_name('sandbox-exposure-apparmor.conf')
PARENT = '/{,usr/}sbin/dhclient'
CHILD = PARENT + '//herdr-exposure-hook-v1'


class AppArmorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('exposure_apparmor', SOURCE)
        assert spec is not None and spec.loader is not None
        cls.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.mod)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.enabled = self.root / 'enabled'
        self.profiles = self.root / 'profiles'
        self.installed = self.root / 'installed'
        self.local = self.root / 'local'
        self.template = self.root / 'template'
        for path, content in ((self.enabled, 'Y\n'), (self.profiles, PARENT + ' (enforce)\n'),
                              (self.template, '# test policy v1\n'), (self.installed, '# test policy v1\n'),
                              (self.local, '#include <local/herdr-sandbox-exposure>\n')):
            path.write_text(content)
            path.chmod(0o600)

    def check(self):
        return self.mod.check_dhcp_apparmor(self.enabled, self.profiles, self.installed, self.local, self.template)

    def test_disabled_apparmor_does_not_require_policy(self):
        self.enabled.write_text('N\n')
        self.installed.unlink()
        self.check()

    def test_unconfined_dhclient_does_not_require_local_policy(self):
        self.profiles.write_text('/other/profile (enforce)\n')
        self.installed.unlink()
        self.check()

    def test_missing_policy_is_rejected(self):
        self.installed.unlink()
        with self.assertRaisesRegex(self.mod.ExposureError, 'AppArmor'):
            self.check()

    def test_policy_must_be_loaded_not_just_installed(self):
        with self.assertRaisesRegex(self.mod.ExposureError, 'AppArmor'):
            self.check()
        self.profiles.write_text(PARENT + ' (enforce)\n' + CHILD + ' (enforce)\n')
        self.check()

    def test_mismatched_policy_or_missing_include_is_rejected(self):
        self.profiles.write_text(PARENT + ' (enforce)\n' + CHILD + ' (enforce)\n')
        for path in (self.installed, self.local):
            original = path.read_text()
            path.write_text('# incorrect or inactive policy\n')
            with self.subTest(path=path.name), self.assertRaisesRegex(self.mod.ExposureError, 'AppArmor'):
                self.check()
            path.write_text(original)

    def test_symlink_or_writable_policy_is_rejected(self):
        self.profiles.write_text(PARENT + ' (enforce)\n' + CHILD + ' (enforce)\n')
        self.installed.chmod(0o666)
        with self.assertRaisesRegex(self.mod.ExposureError, 'AppArmor'):
            self.check()
        self.installed.unlink()
        self.installed.symlink_to(self.template)
        with self.assertRaisesRegex(self.mod.ExposureError, 'AppArmor'):
            self.check()

    @unittest.skipUnless(shutil.which('apparmor_parser'), 'AppArmor parser not installed')
    def test_shipped_policy_compiles_without_loading(self):
        snippet = POLICY.read_text()
        self.assertNotIn('Ux', snippet)
        self.assertNotIn('ux', snippet)
        self.assertNotIn('complain', snippet)
        self.assertIn('rCx -> herdr-exposure-hook-v1', snippet)
        wrapper = self.root / 'profile'
        wrapper.write_text('#include <tunables/global>\n' + PARENT + ' {\n' + snippet + '\n}\n')
        result = subprocess.run(['apparmor_parser', '-Q', '-K', str(wrapper)],
                                capture_output=True, text=True, check=False)
        self.assertEqual(0, result.returncode, result.stderr)


if __name__ == '__main__':
    unittest.main()
