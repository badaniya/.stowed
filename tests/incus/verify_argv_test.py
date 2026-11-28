import subprocess
import unittest
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / 'incus/.local/lib/labctl/network.sh'


class VerifyArgvTest(unittest.TestCase):
    def test_guest_shell_has_zero_argument_before_five_payload_arguments(self):
        text = SOURCE.read_text()
        self.assertIn('runuser -u "$LABCTL_INSTANCE_USER" -- bash -c', text)
        tail = text[text.index("done' labctl-verify "):].splitlines()[0]
        self.assertIn("done' labctl-verify ", tail)
        result = subprocess.run(['bash', '-c', 'test "$#" = 5 && test "$1" = fixture && test "$5" = /work', 'labctl-verify', 'fixture', '1004', '1004', '/master', '/work'])
        self.assertEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
