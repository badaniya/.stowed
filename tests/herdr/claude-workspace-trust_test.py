#!/usr/bin/env python3
"""Trust only a launch directory; never change permission policy."""

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
SCRIPT = (
    Path(__file__).resolve().parents[2]
    / "herdr-spreader/.config/herdr-spreader/claude-workspace-trust.py"
)


class WorkspaceTrustTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not SCRIPT.is_file():
            raise AssertionError("workspace trust helper is missing")
        spec = importlib.util.spec_from_file_location("workspace_trust", SCRIPT)
        assert spec is not None and spec.loader is not None
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.workspace = self.root / "EMULATOR-10"
        self.workspace.mkdir()
        self.config = self.root / ".claude.json"

    def test_exact_canonical_directory_preserves_settings_and_other_projects(self):
        original = {
            "theme": "dark",
            "projects": {"/other": {"hasTrustDialogAccepted": False}},
        }
        self.config.write_text(json.dumps(original))
        alias = self.root / "alias"
        alias.symlink_to(self.workspace, target_is_directory=True)
        self.module.trust_directory(alias, self.config)
        data = json.loads(self.config.read_text())
        self.assertEqual(data["theme"], "dark")
        self.assertEqual(data["projects"]["/other"], original["projects"]["/other"])
        self.assertEqual(
            data["projects"][str(self.workspace)], {"hasTrustDialogAccepted": True}
        )
        self.assertNotIn(str(self.root), data["projects"])
        self.assertNotIn(str(alias), data["projects"])
        self.assertNotIn("permissions", data)

    def test_existing_project_options_survive_and_repeat_is_noop(self):
        self.config.write_text(
            json.dumps(
                {"projects": {str(self.workspace): {"allowedTools": [], "custom": 7}}}
            )
        )
        self.config.chmod(0o600)
        self.module.trust_directory(self.workspace, self.config)
        self.assertEqual(
            json.loads(self.config.read_text())["projects"][str(self.workspace)][
                "custom"
            ],
            7,
        )
        before = self.config.stat()
        self.module.trust_directory(self.workspace, self.config)
        self.assertEqual(self.config.stat().st_mtime_ns, before.st_mtime_ns)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)

    def test_missing_config_is_created_restrictively(self):
        self.module.trust_directory(self.workspace, self.config)
        self.assertTrue(
            json.loads(self.config.read_text())["projects"][str(self.workspace)][
                "hasTrustDialogAccepted"
            ]
        )
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)

    def test_invalid_config_is_never_overwritten(self):
        for content in [
            "{broken",
            "[]",
            '{"projects": []}',
            '{"projects": {"' + str(self.workspace) + '": null}}',
        ]:
            self.config.write_text(content)
            with self.assertRaises((ValueError, TypeError)):
                self.module.trust_directory(self.workspace, self.config)
            self.assertEqual(self.config.read_text(), content)

    def test_missing_directory_does_not_change_config(self):
        with self.assertRaises((ValueError, FileNotFoundError)):
            self.module.trust_directory(self.root / "missing", self.config)
        self.assertFalse(self.config.exists())


if __name__ == "__main__":
    unittest.main()
