import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "herdr-spreader/.config/herdr-spreader/monorepo-worktree-sandbox.sh"


class MonitorLabelTest(unittest.TestCase):
    def test_stopped_prefix_match_does_not_break_exact_instance_lookup(self):
        source = SCRIPT.read_text()
        function = source[
            source.index("monitor_label() {") : source.index(
                "\npublish_monitor_label() {"
            )
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "incus"
            path.write_text("#!/bin/sh\nprintf '%s\\n' \"$FIXTURE_JSON\"\n")
            path.chmod(0o700)
            items = [
                {
                    "name": "review-nvo-20130",
                    "status": "Running",
                    "state": {
                        "network": {
                            "eth0": {
                                "addresses": [
                                    {
                                        "family": "inet",
                                        "scope": "global",
                                        "address": "172.30.19.11",
                                    }
                                ]
                            }
                        }
                    },
                },
                {
                    "name": "review-nvo-20130-before-golden",
                    "status": "Stopped",
                    "state": {"network": None},
                },
            ]
            env = dict(
                os.environ,
                PATH=directory + ":" + os.environ["PATH"],
                FIXTURE_JSON=json.dumps(items),
            )
            setup = 'run_labctl_without_ticket(){ echo agent-sandbox; }; sg(){ bash -c "$3"; }; normalized_ticket=review-nvo-20130\n'
            result = subprocess.run(
                ["bash", "-c", setup + function + "\nmonitor_label"],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "172.30.19.11")


if __name__ == "__main__":
    unittest.main()
