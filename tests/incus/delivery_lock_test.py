import importlib.util
import multiprocessing
import os
import tempfile
import time
import unittest
from pathlib import Path

SOURCE = (
    Path(__file__).resolve().parents[2]
    / "incus/.local/lib/labctl/pass-credential-sync.py"
)
SPEC = importlib.util.spec_from_file_location("delivery_lock_fixture", SOURCE)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def contender(home):
    os.environ["HOME"] = home
    marker = Path(home) / "active-operation"
    with MODULE.delivery_lock("agent-sandbox", "review-fixture"):
        with marker.open("x"):
            time.sleep(0.08)
        marker.unlink()


class DeliveryLockTest(unittest.TestCase):
    def test_parallel_operations_on_same_instance_are_serialized(self):
        self.assertTrue(hasattr(MODULE, "delivery_lock"))
        with tempfile.TemporaryDirectory() as home:
            processes = [
                multiprocessing.get_context("fork").Process(
                    target=contender, args=(home,)
                )
                for _ in range(4)
            ]
            for p in processes:
                p.start()
            for p in processes:
                p.join(10)
                self.assertEqual(p.exitcode, 0)
            lock = (
                Path(home)
                / ".local/state/labctl/credential-delivery-locks/agent-sandbox.review-fixture.lock"
            )
            self.assertEqual(lock.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
