import importlib.util
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import Mock, patch

PATH = Path(__file__).resolve().parents[2]/'incus/.local/libexec/labctl-agent-egress'
LOADER = SourceFileLoader('egress_helper', str(PATH))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC is not None
MODULE = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(MODULE)


class EgressTests(unittest.TestCase):
    def test_rules_are_scoped_and_never_flush_or_change_policy(self):
        with patch.object(MODULE.os, 'geteuid', return_value=0), patch.object(MODULE.sys, 'argv', ['helper','--bridge','agentbr0']), patch.object(MODULE.subprocess, 'check_output', side_effect=['labctl\n','10.20.0.1/24\n','[{"dev":"eth0"}]']), patch.object(MODULE.shutil, 'which', side_effect=lambda name:'/usr/sbin/'+name), patch.object(MODULE.subprocess, 'run', return_value=Mock(returncode=1)) as run:
            MODULE.main()
        inserts=[call.args[0] for call in run.call_args_list if '-I' in call.args[0]]
        self.assertEqual(len(inserts),4)
        for command in inserts:
            self.assertIn('agentbr0',command)
            self.assertIn('10.20.0.0/24',command)
            self.assertNotIn('-F',command)
            self.assertNotIn('-P',command)

    def test_unowned_bridge_stops_before_firewall_mutations(self):
        with patch.object(MODULE.os, 'geteuid', return_value=0), patch.object(MODULE.sys, 'argv', ['helper','--bridge','agentbr0']), patch.object(MODULE.subprocess, 'check_output', return_value='someone-else\n'), patch.object(MODULE.subprocess, 'run') as run, self.assertRaises(ValueError):
            MODULE.main()
        run.assert_not_called()


if __name__=='__main__':
    unittest.main()
