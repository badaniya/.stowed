import json
import re
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
STATUSLINE = REPO_ROOT / "claude/.claude/statusline-command.sh"
ANSI_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


class StatuslineContextMeterTest(unittest.TestCase):
    def render_context_bar(self, used_percentage: int) -> str:
        payload = {
            "workspace": {"current_dir": str(REPO_ROOT)},
            "context_window": {
                "used_percentage": used_percentage,
                "remaining_percentage": 100 - used_percentage,
            },
        }
        result = subprocess.run(
            ["bash", str(STATUSLINE)],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            check=True,
        )
        return ANSI_ESCAPE.sub("", result.stdout).splitlines()[0]

    def test_context_meter_stays_32_cells_with_a_single_dot_column_gap(self):
        expected_prefixes = {
            # Left-only partial usage leaves its own right column as the gap.
            1: "⡆⣿",
            # Once usage reaches the right column, the first unused cell is right-only.
            2: "⣇⢸",
            # A fully used cell also makes the first unused cell right-only.
            3: "⣿⢸",
            # A later left-only partial cell already provides the gap.
            4: "⣿⡄⣿",
        }

        for used_percentage, expected_prefix in expected_prefixes.items():
            with self.subTest(used_percentage=used_percentage):
                line = self.render_context_bar(used_percentage)
                start = line.index("Ctx │") + len("Ctx │")
                end = line.index(f"│ {used_percentage}%", start)
                meter = line[start:end]
                self.assertEqual(len(meter), 32)
                self.assertTrue(meter.startswith(expected_prefix), meter)


if __name__ == "__main__":
    unittest.main()
