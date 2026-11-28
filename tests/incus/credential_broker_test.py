import importlib.util
import io
import secrets
import unittest
from pathlib import Path
from unittest.mock import patch

FILE = Path(__file__).resolve().parents[2]/'incus/.local/lib/labctl/credential-broker.py'


def load():
    spec=importlib.util.spec_from_file_location('credential_broker',FILE)
    assert spec is not None and spec.loader is not None
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BrokerTests(unittest.TestCase):
    def test_https_host_scope(self):
        module=load()
        token=secrets.token_urlsafe(32)
        value=module.validate_credential({'host':'git.example.test','username':'fixture','password':token})
        self.assertEqual(module.credential_response(value,{'protocol':'https','host':'git.example.test'})['password'],token)
        self.assertEqual(module.credential_response(value,{'protocol':'http','host':'git.example.test'}),{})
        self.assertEqual(module.credential_response(value,{'protocol':'https','host':'other.example.test'}),{})
        self.assertEqual(module.credential_response(value,{'protocol':'https','host':'git.example.test:443'}),{})

    def test_git_operation_after_options_is_accepted(self):
        module=load()
        with patch.object(module.sys,'argv',['broker','git','--name','git-module-token','get']), patch.object(module.sys,'stdin',io.StringIO('protocol=https\nhost=git.example.test\n')), patch.object(module,'exchange',return_value={}):
            module.main()

    def test_rejects_multiline_tokens_and_invalid_hosts(self):
        module=load()
        for field,value in [('password','bad\nvalue'),('host','git.example.test/escape'),('username','bad\nvalue')]:
            data={'host':'git.example.test','username':'fixture','password':secrets.token_urlsafe(32)}
            data[field]=value
            with self.assertRaises(ValueError):
                module.validate_credential(data)


if __name__=='__main__':
    unittest.main()
