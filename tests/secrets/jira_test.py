import json
import os
import secrets
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

WRAPPER = Path(__file__).resolve().parents[2] / 'secrets/.local/bin/jira-work'


class JiraTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home/'bin'
        self.bin.mkdir()
        self.token = secrets.token_urlsafe(32)
        self.config = self.home/'cloud.yaml'
        self.config.write_text('server: https://fixture.atlassian.net\ninstallation: Cloud\nauth_type: basic\n')
        self.config.chmod(0o600)
        self.cli = self.bin/'jira'
        self.cli.write_text('#!/usr/bin/env python3\nimport os,sys\nassert os.environ["JIRA_API_TOKEN"] == '+repr(self.token)+'\nassert os.environ["JIRA_AUTH_TYPE"] == "basic"\nassert sys.argv[1:3] == ["--config", '+repr(str(self.config))+']\nprint("scoped-auth-ok")\n')
        self.cli.chmod(0o700)
        self.pass_cmd = self.bin/'pass'
        self.pass_cmd.write_text('#!/bin/sh\nprintf "%s\\n" '+repr(self.token)+'\n')
        self.pass_cmd.chmod(0o700)
        self.settings = self.home/'.private_jira_work.json'
        self.settings.write_text(json.dumps({'host':'fixture.atlassian.net','secret':'jira/work/token','config':str(self.config),'binary':str(self.cli)}))
        self.settings.chmod(0o600)
        self.env = dict(os.environ,HOME=str(self.home),PATH=str(self.bin)+os.pathsep+os.environ['PATH'],JIRA_API_TOKEN=secrets.token_urlsafe(24),JIRA_AUTH_TYPE='bearer',JIRA_CONFIG_FILE='/wrong')

    def run_cli(self, *args):
        return subprocess.run([sys.executable,str(WRAPPER),*args],env=self.env,capture_output=True,text=True)

    def test_command_scoped_auth_and_config(self):
        result=self.run_cli('me')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.strip(),'scoped-auth-ok')
        self.assertNotIn(self.token,result.stdout+result.stderr)

    def test_blocks_overrides_debug_and_init(self):
        for args in [('init',),('--config','/evil','me'),('-cevil','me'),('--debug','me')]:
            result=self.run_cli(*args)
            self.assertNotEqual(result.returncode,0)
            self.assertNotIn(self.token,result.stdout+result.stderr)

    def test_rejects_host_mismatch_and_loose_permissions(self):
        self.config.write_text('server: https://other.atlassian.net\ninstallation: cloud\nauth_type: basic\n')
        self.assertNotEqual(self.run_cli('me').returncode,0)
        self.settings.chmod(0o644)
        self.assertNotEqual(self.run_cli('me').returncode,0)

    def test_provider_error_does_not_expose_output(self):
        self.pass_cmd.write_text('#!/bin/sh\nprintf "%s" '+repr(self.token)+'\nexit 1\n')
        result=self.run_cli('me')
        self.assertNotEqual(result.returncode,0)
        self.assertNotIn(self.token,result.stdout+result.stderr)


if __name__=='__main__':
    unittest.main()
