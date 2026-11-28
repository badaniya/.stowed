import contextlib
import importlib.machinery
import importlib.util
import io
import os
import re
import secrets
import shutil
import socket
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / 'secrets/.local/bin/pass-recovery-backup'


class RecoveryTests(unittest.TestCase):
    def load(self):
        self.assertTrue(SCRIPT.exists(), 'recovery helper missing')
        loader = importlib.machinery.SourceFileLoader('pass_recovery', str(SCRIPT))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        assert spec is not None
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        return module

    def test_passphrase_is_only_sent_through_inherited_fd(self):
        module = self.load()
        observed = {}
        def execute(args, **kwargs):
            observed['args'] = args
            observed['env'] = kwargs['env']
            observed['passphrase'] = os.read(kwargs['pass_fds'][0], 4096)
            observed['input'] = kwargs['input']
            return subprocess.CompletedProcess(args, 0, stdout=b'ciphertext', stderr=b'')
        with patch('subprocess.run', side_effect=execute):
            output = module.gpg_password(['--symmetric'], 'synthetic-passphrase', {'HOME': '/test'}, b'synthetic-data')
        self.assertEqual(output, b'ciphertext')
        self.assertEqual(observed['passphrase'], b'synthetic-passphrase\n')
        self.assertEqual(observed['input'], b'synthetic-data')
        self.assertNotIn('synthetic-passphrase', ' '.join(observed['args']))
        self.assertNotIn('synthetic-passphrase', str(observed['env']))

    @unittest.skipUnless(shutil.which('gpg') and shutil.which('gpgconf'), 'GnuPG unavailable')
    def test_real_encrypted_recovery_round_trip_with_disposable_key(self):
        module = self.load()
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            keydir = home / '.gnupg'
            keydir.mkdir(mode=0o700)
            env = {**os.environ, 'HOME': str(home), 'GNUPGHOME': str(keydir)}
            password = secrets.token_urlsafe(24)
            base = ['gpg', '--batch', '--pinentry-mode', 'loopback', '--passphrase-fd', '0', '--status-fd', '1']
            try:
                result = subprocess.run([*base, '--quick-generate-key', 'Recovery fixture <fixture@invalid.test>', 'ed25519', 'cert,sign', '1d'], input=password.encode(), env=env, capture_output=True, check=True)
                match = re.search(rb'KEY_CREATED [PB] ([0-9A-F]{40})', result.stdout)
                assert match is not None
                fingerprint = match.group(1).decode()
                subprocess.run([*base, '--quick-add-key', fingerprint, 'cv25519', 'encr', '1d'], input=password.encode(), env=env, capture_output=True, check=True)
                namespace = home / '.password-store/hosts' / socket.gethostname()
                namespace.mkdir(parents=True)
                (namespace / '.gpg-id').write_text(fingerprint + '\n')
                captured = io.StringIO()
                with patch.dict(os.environ, {'HOME': str(home)}), patch('sys.stdin.isatty', return_value=True), patch('getpass.getpass', return_value=password), contextlib.redirect_stdout(captured):
                    self.assertEqual(module.main(), 0, captured.getvalue())
                files = list((home / '.private-pass-recovery').rglob('*.tar.gpg'))
                self.assertEqual(len(files), 1)
                self.assertEqual(files[0].stat().st_mode & 0o777, 0o600)
                self.assertNotIn(b'BEGIN PGP PRIVATE KEY BLOCK', files[0].read_bytes())
            finally:
                subprocess.run(['gpgconf', '--kill', 'gpg-agent'], env=env, capture_output=True, check=False)

    def test_empty_password_is_rejected_before_execution(self):
        module = self.load()
        with patch('subprocess.run') as execute:
            with self.assertRaises(ValueError):
                module.gpg_password(['--symmetric'], '', {}, b'')
            execute.assert_not_called()


if __name__ == '__main__':
    unittest.main()
