"""Run the JavaScript callback regression checks alongside the Python suite."""
from pathlib import Path
import shutil
import subprocess
import unittest


@unittest.skipUnless(shutil.which('node'), 'Node.js required')
class CardRefresh(unittest.TestCase):
    def test_table_mutations_and_async_refresh(self):
        root = Path(__file__).resolve().parents[1]
        result = subprocess.run(['node', 'tests/test_card_refresh.js'], cwd=root,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
