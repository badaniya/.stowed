import json
import os
import socket
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / 'secrets/.local/bin/docker-credential-private-pass'


class DockerHelperTests(unittest.TestCase):
    def test_protocol_and_host_store_are_preserved(self):
        self.assertTrue(SCRIPT.exists(), 'Docker adapter missing')
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            namespace = home / '.password-store/hosts' / socket.gethostname()
            namespace.mkdir(parents=True)
            (namespace / '.gpg-id').write_text('synthetic-public-fingerprint')
            binary = home / 'bin'
            binary.mkdir()
            backend = binary / 'docker-credential-pass'
            backend.write_text('#!' + sys.executable + '\nimport os,sys,json\nprint(json.dumps({"args":sys.argv[1:],"store":os.environ["PASSWORD_STORE_DIR"],"input":sys.stdin.read()}))\n')
            backend.chmod(0o755)
            env = {**os.environ, 'HOME': str(home), 'PATH': f'{binary}:{os.defpath}'}
            result = subprocess.run([sys.executable, str(SCRIPT), 'get'], input='registry.example.test\n', env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            output = json.loads(result.stdout)
            self.assertEqual(output['store'], str(namespace))
            self.assertEqual(output['args'], ['get'])
            self.assertEqual(output['input'], 'registry.example.test\n')

    def test_missing_namespace_fails_without_creating_a_store(self):
        self.assertTrue(SCRIPT.exists(), 'Docker adapter missing')
        with tempfile.TemporaryDirectory() as home:
            result = subprocess.run([sys.executable, str(SCRIPT), 'list'], env={**os.environ, 'HOME': home}, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, '')
            self.assertFalse((Path(home) / '.password-store').exists())


if __name__ == '__main__':
    unittest.main()
