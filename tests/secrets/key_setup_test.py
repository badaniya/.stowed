import importlib.machinery
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'secrets/.local/bin/setup-secrets-key'


class KeySetupTests(unittest.TestCase):
    def load(self):
        self.assertTrue(SCRIPT.exists(), 'key setup helper missing')
        loader = importlib.machinery.SourceFileLoader('key_setup', str(SCRIPT))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        assert spec is not None, 'could not create module specification'
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        return module

    def test_binary_key_format_and_unprotected_key_rejection(self):
        module = self.load()
        with tempfile.TemporaryDirectory() as folder:
            key = Path(folder) / 'fixture.key'
            key.write_bytes(b'(protected-private-key fixture)\xc4')
            self.assertTrue(module.is_protected_key(key))
            key.write_bytes(b'(21:protected-private-key fixture)\xff')
            self.assertTrue(module.is_protected_key(key))
            key.write_bytes(b'(private-key fixture)')
            self.assertFalse(module.is_protected_key(key))
            key.write_bytes(b'(unprotected-private-key fixture)')
            self.assertFalse(module.is_protected_key(key))

    def test_blank_password_does_not_generate_keys(self):
        module = self.load()
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {'HOME': home}), patch('sys.stdin.isatty', return_value=True), patch('getpass.getpass', return_value=''), patch('subprocess.run') as run:
            run.return_value = subprocess.CompletedProcess([], 0, stdout='', stderr='')
            self.assertNotEqual(module.main(), 0)
            self.assertFalse(any('--quick-generate-key' in call.args[0] for call in run.call_args_list))

    def test_password_only_goes_through_stdin(self):
        module = self.load()
        calls = []
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {'HOME': home}), patch('sys.stdin.isatty', return_value=True), patch('getpass.getpass', return_value='synthetic-passphrase'):
            def execute(args, **kwargs):
                calls.append((args, kwargs))
                if '--quick-generate-key' in args:
                    private = Path(home) / '.gnupg/private-keys-v1.d'
                    private.mkdir(parents=True, exist_ok=True)
                    # GPG private-key files may contain binary, non-UTF-8 bytes.
                    (private / 'test.key').write_bytes(b'(protected-private-key fixture)\xc4')
                    return subprocess.CompletedProcess(args, 0, stdout='[GNUPG:] KEY_CREATED P ' + 'A' * 40 + '\n', stderr='')
                if args[:2] == ['pass', 'init']:
                    (Path(home) / '.password-store').mkdir(parents=True)
                return subprocess.CompletedProcess(args, 0, stdout='', stderr='')
            with patch('subprocess.run', side_effect=execute):
                self.assertEqual(module.main(), 0)
            key_calls = [(a, k) for a, k in calls if '--quick-generate-key' in a or '--quick-add-key' in a]
            self.assertEqual(len(key_calls), 2)
            for args, kwargs in key_calls:
                self.assertNotIn('synthetic-passphrase', ' '.join(args))
                self.assertEqual(kwargs['input'], b'synthetic-passphrase')
                self.assertIn('--passphrase-fd', args)
                self.assertNotIn('synthetic-passphrase', str(kwargs.get('env', {})))


if __name__ == '__main__':
    unittest.main()
