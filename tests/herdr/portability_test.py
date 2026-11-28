import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / 'herdr-spreader/.local/bin/herdr-spreader'


class PortabilityTests(unittest.TestCase):
    def test_private_check_does_not_create_exclude(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'scripts').mkdir()
            (root / 'scripts/private-links.sh').write_bytes((ROOT / 'scripts/private-links.sh').read_bytes())
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            exclude = root / '.git/info/exclude'
            exclude.unlink()
            home = root / 'home'
            home.mkdir()
            result = subprocess.run(['bash', str(root / 'scripts/private-links.sh'), '--check'], env={**os.environ, 'HOME': str(home)}, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(exclude.exists())

    def test_private_check_ignores_unrelated_broken_links(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'scripts').mkdir()
            (root / 'scripts/private-links.sh').write_bytes((ROOT / 'scripts/private-links.sh').read_bytes())
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            config = root / 'copilot/.config/.copilot'
            config.mkdir(parents=True)
            (config / 'config.json').symlink_to('/nonexistent/unrelated/config.json')
            home = root / 'home'
            home.mkdir()
            result = subprocess.run(['bash', str(root / 'scripts/private-links.sh'), '--check'], env={**os.environ, 'HOME': str(home)}, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout)

    def test_spreader_resolves_registry_without_fixed_checkout_path(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            checkout = home / 'arbitrary-install-id'
            binary = checkout / 'target/release/herdr-spreader'
            binary.parent.mkdir(parents=True)
            binary.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            binary.chmod(0o755)
            config = home / '.config/herdr'
            config.mkdir(parents=True)
            (config / 'plugins.json').write_text(json.dumps([{'plugin_id': 'herdr-spreader', 'enabled': True, 'plugin_root': str(checkout)}]))
            self.assertTrue(LAUNCHER.exists(), 'stable launcher is missing')
            result = subprocess.run(['python3', str(LAUNCHER), 'apply', '-f', 'path with spaces.yaml'], env={**os.environ, 'HOME': str(home)}, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), ['apply', '-f', 'path with spaces.yaml'])

    def test_missing_spreader_fails_actionably(self):
        with tempfile.TemporaryDirectory() as temp:
            self.assertTrue(LAUNCHER.exists(), 'stable launcher is missing')
            result = subprocess.run(['python3', str(LAUNCHER), '--version'], env={**os.environ, 'HOME': temp, 'XDG_CONFIG_HOME': temp}, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('herdr plugin install', result.stderr)

    def test_runtime_migration_preserves_state_and_links_only_tracked_config(self):
        import shutil
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp) / 'home'
            config = home / '.config'
            config.mkdir(parents=True)
            repo = Path(temp) / 'repo'
            source = repo / 'herdr/.config/herdr'
            source.mkdir(parents=True)
            (source / 'config.toml').write_text('theme = "test"\n')
            (source / 'session.json').write_text('{}')
            (repo / 'scripts').mkdir()
            migration = repo / 'scripts/migrate-herdr-runtime.py'
            original = ROOT / 'scripts/migrate-herdr-runtime.py'
            self.assertTrue(original.exists(), 'offline migration tool missing')
            shutil.copyfile(original, migration)
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            subprocess.run(['git', '-C', str(repo), 'add', 'herdr/.config/herdr/config.toml'], check=True)
            (config / 'herdr').symlink_to(source)
            result = subprocess.run(['python3', str(migration), '--apply'], env={**os.environ, 'HOME': str(home), 'XDG_CONFIG_HOME': str(config), 'HERDR_SOCKET_PATH': str(config / 'herdr/nonexistent.sock')}, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((config / 'herdr').is_symlink())
            self.assertTrue((config / 'herdr/config.toml').is_symlink())
            self.assertEqual((config / 'herdr/session.json').read_text(), '{}')


if __name__ == '__main__':
    unittest.main()
