"""Exercise scalar/list bridge membership using the modal's Lua helpers."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'decompressed/gui_file/www/docroot/modals/bridge-grouping-modal.lp'


def selection_script():
    source = SOURCE.read_text()
    helpers = source[source.index('local function interfaceList'):source.index('local bridge_columns')]
    return '''
local untaint = string.untaint or function(s) return s end
local taint = string.taint or function(s) return s end
local lanintfs = {{'eth0','eth0'}, {'eth1','eth1'}, {'wl0','wl0'}}
local wanintfs = {{'wan','WAN'}, {'voip','VoIP'}}
''' + helpers + '''
local function eq(actual, expected)
 assert(table.concat(actual, ',') == expected, table.concat(actual, ','))
end
eq(interfaceList(nil), '')
eq(interfaceList(''), '')
eq(interfaceList({'', 'eth0', taint('eth1'), 'eth0'}), 'eth0,eth1')
local lan, wan = bridgeSelections(taint('eth0 eth1 eth5 wan wl0'), taint('voip'))
eq(lan, 'eth0,eth1,eth5,wl0')
eq(wan, 'wan,voip')
assert(lanintfs[#lanintfs][1] == 'eth5')
local count = #lanintfs
bridgeSelections('eth5', '')
assert(#lanintfs == count)
lan, wan = bridgeSelections('', '')
eq(lan, '')
eq(wan, '')
print('Bridge selection cases passed')
'''


@unittest.skipUnless(shutil.which('lua'), 'Lua interpreter required')
class BridgeGrouping(unittest.TestCase):
    def test_membership_selection(self):
        result = subprocess.run(['lua', '-'], input=selection_script(), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
