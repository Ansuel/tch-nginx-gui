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
lan, wan = bridgeSelections({'', 'eth5'}, {'', 'wan'})
eq(lan, 'eth5')
eq(wan, 'wan')
lan, wan = bridgeSelections('', '')
eq(lan, '')
eq(wan, '')
print('Bridge selection cases passed')
'''


def validation_script():
    source = SOURCE.read_text()
    helpers = source[source.index('local function interfaceList'):source.index('local function bridgeSelections')]
    validation = source[source.index('local selection_post'):source.index('local bridge_validate')]
    return """
local untaint = string.untaint or function(s) return s end
local T = function(s) return s end
local post
local ngx = {var={request_method='POST'}, req={get_post_args=function() return post end}}
""" + helpers + "local function run(object, wanFirst)\n" + validation + """
 if wanFirst then validateWANIfname(object.wanintf, object) end
 local ok, message = validateLANIfname(object.lanintf, object)
 if not wanFirst then validateWANIfname(object.wanintf, object) end
 return ok, message
end
for _, wanFirst in ipairs({false, true}) do
 for _, empty in ipairs({{}, {lanintf='',wanintf=''}, {lanintf={'','  '},wanintf={''}}}) do
  post = empty
  local ok, message = run(empty, wanFirst)
  assert(ok == nil and message == 'Select at least one interface for the bridge.')
 end
 for _, case in ipairs({
  {lanintf='eth0',wanintf='',expected='eth0'},
  {lanintf='',wanintf={'','wan'},expected='wan'},
  {lanintf={'','eth0','eth5'},wanintf={'','wan'},expected='eth0 eth5 wan'}
 }) do
  post = case
  assert(run(case, wanFirst) == true)
  assert(case.lanintf == case.expected and case.wanintf == '')
 end
end
print('Empty bridge and validator ordering cases passed')
"""


@unittest.skipUnless(shutil.which('lua'), 'Lua interpreter required')
class BridgeGrouping(unittest.TestCase):
    def test_reject_empty_membership(self):
        result = subprocess.run(['lua', '-'], input=validation_script(), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_membership_selection(self):
        result = subprocess.run(['lua', '-'], input=selection_script(), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
