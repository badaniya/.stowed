import base64
import errno
import importlib.util
import os
import unittest
from pathlib import Path

FILE=Path(__file__).resolve().parents[2]/'incus/.local/lib/labctl/credential-broker.py'
SPEC=importlib.util.spec_from_file_location('non_git_broker',FILE)
assert SPEC is not None and SPEC.loader is not None
MODULE=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class NonGitTests(unittest.TestCase):
    def test_environment_is_data_not_shell_execution(self):
        value=MODULE.parse_environment("export SAMPLE='literal $(not-executed)'\nexport PORT='1234'\n")
        self.assertEqual(value['SAMPLE'],'literal $(not-executed)')
        self.assertEqual(value['PORT'],'1234')
        with self.assertRaises(ValueError):
            MODULE.parse_environment('echo execute-me\n')
        with self.assertRaises(ValueError):
            MODULE.parse_environment('export SAMPLE=one\nexport SAMPLE=two\n')

    def test_blob_cannot_be_returned_as_git_password(self):
        data=base64.b64encode(b'export SAMPLE=value\n').decode()
        payload=MODULE.validate_payload({'kind':'blob','format':'environment','data':data})
        self.assertEqual(MODULE.credential_response(payload,{'protocol':'https','host':'git.example.test'}),{})

    def test_template_fd_is_anonymous_and_read_only(self):
        fd=MODULE.sealed_template(b'template-fixture\n')
        try:
            self.assertEqual(os.read(fd,100),b'template-fixture\n')
            self.assertIn('memfd:',os.readlink('/proc/self/fd/'+str(fd)))
            with self.assertRaises(OSError) as error:
                os.write(fd,b'altered')
            self.assertEqual(error.exception.errno,errno.EPERM)
        finally:
            os.close(fd)


if __name__=='__main__':
    unittest.main()
