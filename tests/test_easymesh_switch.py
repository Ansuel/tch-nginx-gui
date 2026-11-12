"""Run the EasyMesh switch against the real shared widget lifecycle."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class EasyMeshSwitch(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node required')
    def test_shared_widget_and_confirmation(self):
        result = subprocess.run(['node', 'tests/test_easymesh_switch.js'], cwd=ROOT,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
