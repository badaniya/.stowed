import importlib.util
import io
import json
import secrets
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

FILE=Path(__file__).resolve().parents[2]/'incus/.local/lib/labctl/pass-credential-sync.py'
SPEC=importlib.util.spec_from_file_location('pass_delivery',FILE)
assert SPEC is not None and SPEC.loader is not None
MODULE=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DeliveryTests(unittest.TestCase):
    def test_token_only_transferred_through_stdin(self):
        with tempfile.TemporaryDirectory() as temporary:
            home=Path(temporary)
            config=home/'.private_gh_accounts.json'
            config.write_text(json.dumps({'work':{'host':'git.example.test','secret':'github/work/token'}}))
            config.chmod(0o600)
            token=secrets.token_urlsafe(32)
            calls=[]
            def run(command,data=None,env=None):
                calls.append((command,data,env))
                return (token+'\n').encode() if command[0]=='/usr/bin/pass' else b''
            args=['sync','--instance','fixture','--project','agent-sandbox','--host','git.example.test','--name','git-module-token','--user','fixture']
            with patch.object(MODULE.Path,'home',return_value=home), patch.object(MODULE.sys,'argv',[str(FILE),*args]), patch.object(MODULE,'run',side_effect=run), patch.object(MODULE,'remove_legacy'), patch.object(MODULE.sys,'stdout',io.StringIO()) as output:
                MODULE.main()
            self.assertNotIn(token,output.getvalue())
            for command,_data,env in calls:
                self.assertNotIn(token,str(command))
                self.assertNotIn(token,str(env))
            transfers=[data for command,data,env in calls if 'inject' in command]
            self.assertEqual(len(transfers),1)
            self.assertEqual(json.loads(transfers[0])['password'],token)
            code_transfers=[data for command,data,env in calls if 'sh' in command]
            self.assertTrue(code_transfers)
            self.assertNotIn(token.encode(),code_transfers[0])


if __name__=='__main__':
    unittest.main()
