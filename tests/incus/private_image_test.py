import concurrent.futures
import hashlib
import importlib.util
import json
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

SOURCE = (
    Path(__file__).resolve().parents[2]
    / "incus/.local/lib/labctl/ensure-private-image.py"
)


class PrivateImageTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.root = self.home / ".private-sandbox-images"
        self.root.mkdir(mode=0o700)
        self.archive = self.root / "golden.tar.gz"
        self.archive.write_bytes(b"synthetic-image-archive")
        self.archive.chmod(0o600)
        self.sha = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        self.manifest = self.root / "manifest.json"
        self.record = {
            "alias": "golden:fixture",
            "archive": self.archive.name,
            "fingerprint": self.sha,
            "sha256": self.sha,
            "bytes": self.archive.stat().st_size,
            "type": "container",
            "architecture": "x86_64",
        }
        self.save_manifest()
        self.target = None
        self.calls = []
        self.server_ok = True
        self.assertTrue(SOURCE.exists(), "private image helper must exist")
        spec = importlib.util.spec_from_file_location("private_image_fixture", SOURCE)
        assert spec is not None and spec.loader is not None
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def save_manifest(self):
        self.manifest.write_text(
            json.dumps({"schema_version": 1, "images": [self.record]})
        )
        self.manifest.chmod(0o600)

    def runner(self, command):
        self.calls.append(command)
        if "query" in command:
            if not self.server_ok:
                return subprocess.CompletedProcess(
                    command, 1, b"", b"connection refused"
                )
            if "/projects/" in command[-1]:
                return subprocess.CompletedProcess(command, 0, b"{}", b"")
            if self.target:
                return subprocess.CompletedProcess(
                    command, 0, json.dumps({"target": self.target}).encode(), b""
                )
            return subprocess.CompletedProcess(command, 1, b"", b"Error: not found")
        time.sleep(0.02)
        self.target = self.sha
        return subprocess.CompletedProcess(command, 0, b"", b"")

    def ensure(self, dry_run=False):
        return self.module.ensure_image(
            "local:golden:fixture", "agent-sandbox", self.home, self.runner, dry_run
        )

    def test_concurrent_creations_import_once(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda _: self.ensure(), range(4)))
        self.assertEqual(sum("import" in call for call in self.calls), 1)

    def test_archive_symlink_rejected(self):
        self.archive.rename(self.root / "real.tar.gz")
        self.archive.symlink_to(self.root / "real.tar.gz")
        with self.assertRaises((ValueError, OSError)):
            self.ensure()

    def test_explicit_non_golden_selection_is_not_replaced(self):
        self.module.ensure_image(
            "images:ubuntu/24.04/cloud", "agent-sandbox", self.home, self.runner
        )
        self.assertEqual(self.calls, [])

    def test_shared_launch_aborts_before_init_on_image_failure(self):
        source = SOURCE.with_name("incus.sh").read_text()
        launch = source[
            source.index("labctl_incus_launch() {") : source.index(
                "\nlabctl_incus_redact_systemd_credentials()"
            )
        ]
        setup = 'labctl_normalize_ticket(){ echo "$1"; }; labctl_config_is_ipv4(){ return 0; }; labctl_incus_validate_launch_profiles(){ return 0; }; python3(){ return 17; }; labctl_run(){ echo INSTANCE_INIT; }; LABCTL_INSTANCE_IMAGE=local:golden:fixture; LABCTL_INCUS_PROJECT=agent-sandbox\n'
        result = subprocess.run(
            [
                "bash",
                "-c",
                setup + launch + "\nlabctl_incus_launch fixture 172.30.19.11",
            ],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("INSTANCE_INIT", result.stdout)

    def test_missing_alias_imports_verified_archive(self):
        self.ensure()
        self.assertTrue(any("import" in call for call in self.calls))
        self.assertEqual(self.target, self.sha)

    def test_existing_alias_reused_without_import(self):
        self.target = self.sha
        self.ensure()
        self.assertFalse(any("import" in call for call in self.calls))

    def test_corrupt_archive_fails_closed(self):
        self.archive.write_bytes(b"corrupt")
        with self.assertRaises(ValueError):
            self.ensure()
        self.assertFalse(any("import" in call for call in self.calls))

    def test_missing_archive_fails_closed(self):
        self.archive.unlink()
        with self.assertRaises((ValueError, OSError)):
            self.ensure()

    def test_mismatched_alias_is_not_replaced(self):
        self.target = "0" * 64
        with self.assertRaises(ValueError):
            self.ensure()
        self.assertFalse(any("import" in call for call in self.calls))

    def test_daemon_failure_is_not_treated_as_missing_alias(self):
        self.server_ok = False
        with self.assertRaises(ValueError):
            self.ensure()
        self.assertFalse(any("import" in call for call in self.calls))

    def test_manifest_permissions_and_archive_path_are_enforced(self):
        self.manifest.chmod(0o644)
        with self.assertRaises(ValueError):
            self.ensure()
        self.manifest.chmod(0o600)
        self.record["archive"] = "../escape.tar.gz"
        self.save_manifest()
        with self.assertRaises(ValueError):
            self.ensure()

    def test_dry_run_never_imports_or_creates_lock_files(self):
        self.ensure(dry_run=True)
        self.assertFalse(any("import" in call for call in self.calls))
        self.assertFalse(
            (self.home / ".local/state/labctl/private-image-locks").exists()
        )


if __name__ == "__main__":
    unittest.main()
