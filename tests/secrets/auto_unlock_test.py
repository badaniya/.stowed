import importlib.util
import secrets
import types
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('auto_root', ROOT/'secrets/.local/lib/dotfiles-secrets/auto_unlock_root.py')
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class AutoUnlockTests(unittest.TestCase):
    def test_valid_payload_preserves_passphrase_in_pipe_bytes(self):
        phrase = secrets.token_urlsafe(32)
        data, grips = MODULE.validate_payload({'uid':1000,'passphrase':phrase,'keygrips':['A'*40]},1000)
        self.assertEqual(data,phrase.encode()+b'\n')
        self.assertEqual(grips,['A'*40])

    def test_rejects_foreign_identity_and_unsafe_fields(self):
        for payload in [{'uid':1001,'passphrase':'fixture','keygrips':['A'*40]},
                        {'uid':1000,'passphrase':'bad\nline','keygrips':['A'*40]},
                        {'uid':1000,'passphrase':'fixture','keygrips':['../escape']},
                        {'uid':1000,'passphrase':'fixture','keygrips':[]}]:
            with self.assertRaises(ValueError):
                MODULE.validate_payload(payload,1000)

    def test_preset_receives_secret_via_stdin_not_args_or_environment(self):
        phrase=secrets.token_urlsafe(32).encode()
        user=types.SimpleNamespace(pw_name='fixture',pw_uid=1000,pw_gid=1000,pw_dir='/home/fixture')
        with patch.object(MODULE.subprocess,'run',return_value=Mock(returncode=0)) as run:
            MODULE.child_as_user(user,[MODULE.PRESET,'--preset','A'*40],phrase)
        args,kwargs=run.call_args
        self.assertNotIn(phrase.decode(),str(args))
        self.assertNotIn(phrase.decode(),str(kwargs['env']))
        self.assertEqual(kwargs['input'],phrase)
        self.assertIn('preexec_fn',kwargs)

    def test_cache_clear_uses_normal_mode_and_checks_agent_errors(self):
        loader = SourceFileLoader('enroll_helper', str(ROOT/'secrets/.local/bin/enroll-pass-auto-unlock'))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        assert spec is not None
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        with patch.object(module.subprocess, 'run', return_value=Mock(returncode=0, stdout=b'OK\n')) as run:
            module.clear_key_cache(['A'*40])
        self.assertIn('CLEAR_PASSPHRASE --mode=normal ' + 'A'*40, run.call_args.args[0])
        with patch.object(module.subprocess, 'run', return_value=Mock(returncode=0, stdout=b'ERR failure\n')), self.assertRaises(ValueError):
            module.clear_key_cache(['A'*40])

    def test_direct_non_sudo_invocation_is_rejected_before_io(self):
        with patch.object(MODULE.os,'geteuid',return_value=1000), self.assertRaises(ValueError):
            MODULE.main()


if __name__=='__main__':
    unittest.main()
