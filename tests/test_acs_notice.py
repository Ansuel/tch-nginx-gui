"""Exercise acknowledgement without changing firmware update permissions."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
LUA = shutil.which('lua')


def regression_script():
    source = (ROOT / 'decompressed/gui_file/www/docroot/modals/modgui-modal.lp').read_text()
    block = source[source.index('local function isBlockedACSNotice'):source.index('local modgui_settings, helpmsg')]
    return '''
local message, method, action, setOK, applyOK, writes, applies
local untaint = string.untaint or function(value) return value end
local proxy = {
 set = function(path, value)
  assert(path == 'uci.modgui.var.reboot_reason_msg' and value == '')
  writes = writes + 1
  return setOK
 end,
 apply = function() applies = applies + 1; return applyOK end
}
local content_helper = {getExactContent = function(t) t.message = string.taint and string.taint(message) or message end}
local ngx = {req = {get_method = function() return method end,
 get_post_args = function() return {action = action} end}}
local messages = {}
local message_helper = {pushMessage = function(text, kind) messages[#messages+1] = kind end}
local T = function(t) return t end
local function run()
''' + block + '''
return acs_notice_dismissed
end
for _, reason in ipairs({
 'TIM ACS asked for firmware update. Go to Modgui Settings to allow this.',
 'ACS asked for firmware update from: https://example.invalid/fw Go to Modgui Settings to allow this.',
 'apply OBP planning', '', 'unknown reason'
}) do
 for _, request in ipairs({'GET', 'POST'}) do
  for _, command in ipairs({'SAVE', 'DISMISS_ACS_NOTICE'}) do
   for _, failures in ipairs({'none', 'set', 'apply'}) do
    message, method, action = reason, request, command
    setOK, applyOK = failures ~= 'set', failures ~= 'apply'
    writes, applies, messages = 0, 0, {}
    local eligible = reason:find('ACS asked', 1, true) ~= nil and request == 'POST' and command == 'DISMISS_ACS_NOTICE'
    assert(run() == (eligible and failures == 'none'))
    assert(writes == (eligible and 1 or 0))
    assert(applies == (eligible and setOK and 1 or 0))
    if eligible then assert(messages[1] == (failures == 'none' and 'success' or 'error')) end
   end
  end
 end
end
print('ACS notice: 60 cases passed')
'''


@unittest.skipUnless(LUA, 'Lua interpreter required')
class ACSNotice(unittest.TestCase):
    def test_acknowledgement(self):
        result = subprocess.run([LUA, '-'], input=regression_script(), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
