import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parents[2]
    / "herdr-spreader/.config/herdr-spreader/monorepo-review-sandbox.sh"
)


class ReviewPassTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        self.config = self.home / ".config/herdr-spreader"
        self.config.mkdir(parents=True)
        self.work = self.home / "workspace/master/fixture"
        self.work.mkdir(parents=True)
        (self.config / "private-env.sh").write_text(
            'monorepo_name(){ echo fixture; }; private_env_name(){ echo fixture-user; }; WS_ROOT="$HOME/workspace"\n'
        )
        (self.config / "monorepo-worktree-sandbox.sh").write_text(
            'printf "coordinator %s %s\\n" "$1" "$2"\n'
        )
        (self.home / ".private_gh_accounts.json").write_text(
            json.dumps({"work": {"host": "github.com", "secret": "github/work/token"}})
        )
        (self.home / ".private_gh_accounts.json").chmod(0o600)
        self.tool(
            "git",
            "if [[ $1 == config ]]; then echo https://github.com/fixture/repo.git; fi",
        )
        self.tool("gh", 'echo "native gh authentication forbidden" >&2; exit 99')
        self.tool("gh-work", 'printf \'[{"number":12,"baseRefName":"main"}]\\n\'')
        self.tool("jira", "exit 1")
        self.tool("pass-unlocked", "echo synthetic-review-fixture")
        self.tool(
            "tuicr",
            "[[ $GH_TOKEN == synthetic-review-fixture && -z ${GITHUB_TOKEN:-} && -z ${GH_ENTERPRISE_TOKEN:-} ]]; echo scoped-tool-ok",
        )

    def tool(self, name, body):
        p = self.bin / name
        p.write_text("#!/bin/bash\nset -euo pipefail\n" + body + "\n")
        p.chmod(0o755)

    def run_script(self, *args):
        stale = os.urandom(8).hex()
        env = dict(
            os.environ,
            HOME=str(self.home),
            PATH=str(self.bin) + ":" + os.environ["PATH"],
            GH_TOKEN=stale,
            GITHUB_TOKEN=stale,
            GH_ENTERPRISE_TOKEN=stale,
            XDG_STATE_HOME=str(self.home / "state"),
        )
        return subprocess.run(
            ["bash", str(SCRIPT), *args], env=env, text=True, capture_output=True
        )

    def test_discovery_uses_work_wrapper(self):
        r = self.run_script("fixture/NVO-12")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("coordinator REVIEW-NVO-12 fixture/NVO-12", r.stdout)

    def test_tuicr_uses_scoped_pass_without_secret_output(self):
        r = self.run_script("--tool", "tuicr", "pr", "12")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), "scoped-tool-ok")
        self.assertNotIn("synthetic-review-fixture", r.stdout + r.stderr)

    def test_git_setup_has_no_native_token_or_secret_header(self):
        source = SCRIPT.with_name("monorepo-worktree-sandbox-base.sh").read_text()
        self.assertNotIn("gh auth token", source)
        self.assertNotIn("Authorization: basic", source)
        self.assertIn("gh-work", source)

    def test_tool_fails_closed_on_pass_error(self):
        self.tool("pass-unlocked", "exit 1")
        r = self.run_script("--tool", "tuicr", "pr", "12")
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn("scoped-tool-ok", r.stdout)


if __name__ == "__main__":
    unittest.main()
