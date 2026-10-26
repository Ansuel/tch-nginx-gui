"""Exercise cron GUI callbacks and mapping against a temporary crontab."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('luajit') or shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua interpreter required')
class Cron(unittest.TestCase):
    def run_lua(self, script, initial=''):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'crontab'
            if initial is not None:
                path.write_text(initial)
            setup = '''
local originalOpen = io.open
io.open = function(path, mode)
  if path == '/etc/crontabs/root' then path = CRON_PATH end
  return originalOpen(path, mode)
end
local now = 100
os.time = function() return now end
local mappings = {}
register = function(mapping) mappings[#mappings + 1] = mapping end
local function loadMapping()
  mappings = {}
  dofile(MAPPING_PATH)
  return mappings[1], mappings[2]
end
local function readCron()
  local f = assert(io.open('/etc/crontabs/root', 'r'))
  local text = f:read('*a')
  f:close()
  return text
end
local parent, entries = loadMapping()
'''.replace('CRON_PATH', repr(str(path))).replace(
                'MAPPING_PATH', repr(str(ROOT / 'usr/share/transformer/mappings/rpc/system.cron.map')))
            result = subprocess.run([LUA, '-'], input=setup + script, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_gui_add_modify_and_reload_preserve_commands(self):
        self.run_lua(r'''
local options
ngx = {print = function() end}
gettext = {textdomain = function() end}
T = function(value) return value end
local calls = {}
package.preload.datamodel = function() return {
  set = function(path, value)
    calls[#calls + 1] = {path, value}
    assert(path == 'rpc.system.cron.editCronRuleNumber')
    assert(parent.set.editCronRuleNumber(nil, nil, value))
    return true
  end,
} end
package.preload['web.ui_helper'] = function() return {
  createHeader = function() return '' end,
  createTable = function() return '' end,
  createFooter = function() return '' end,
} end
package.preload['web.post_helper'] = function() return {
  validateNonEmptyString = function() return true end,
  handleTableQuery = function(columns, opts) options = opts; return {}, {} end,
} end
package.preload['web.lp'] = function() return {
  setpath = function() end, include = function() end,
} end
dofile(MODAL_PATH)
local function add(index, command)
  -- addNewObject sets the submitted fields using the key returned by add().
  local key = entries.add()
  local found = false
  for _, value in ipairs(entries.entries()) do
    if value == key then found = true end
  end
  assert(found, 'add must return a key exposed by entries')
  local content = {minute = '*/5', hour = '1,9', day = '*', month = '*', week = '1-5', command = command}
  for param, value in pairs(content) do
    assert(entries.set[param](nil, param, value, key))
  end
  options.onAdd(index, content)
  assert(calls[#calls][2] == index, 'GUI must use the actual instance index')
end
add('7', "printf '%s' hello >> /tmp/cron.log")
add('9', '/usr/bin/second --flag')
assert(#calls == 2, 'GUI must not write parameters a second time')
assert(not readCron():find('ID_RULE', 1, true))
parent, entries = loadMapping()
local key
for _, value in ipairs(entries.entries()) do
  if entries.get.command(nil, nil, value) == '/usr/bin/second --flag' then key = value end
end
assert(key)
assert(entries.get.hour(nil, nil, key) == '1,9')
assert(entries.set.command(nil, 'command', 'echo changed', key))
now = now + 31 -- pending changes must survive the normal cache expiry
options.onModify('9', {})
parent, entries = loadMapping()
assert(readCron():find('*/5 1,9 * * 1-5 echo changed', 1, true))
assert(readCron():find("printf '%s' hello >> /tmp/cron.log", 1, true))
for _, value in ipairs(entries.entries()) do
  if entries.get.command(nil, nil, value) == 'echo changed' then
    assert(entries.delete(nil, value))
  end
end
assert(not readCron():find('echo changed', 1, true))
assert(readCron():find('# existing comment', 1, true))
assert(readCron():find('@reboot /usr/bin/start', 1, true))
'''.replace('MODAL_PATH', repr(str(ROOT / 'www/docroot/modals/system-cron-modal.lp'))),
            initial='# existing comment\n@reboot /usr/bin/start\n')

    def test_first_rule_can_be_added_without_existing_crontab(self):
        self.run_lua('''
assert(#entries.entries() == 0)
local key = entries.add()
assert(entries.set.command(nil, 'command', 'echo first', key))
parent.set.editCronRuleNumber(nil, nil, '1')
parent, entries = loadMapping()
local keys = entries.entries()
assert(#keys == 1)
assert(entries.get.command(nil, nil, keys[1]) == 'echo first')
assert(readCron() == '* * * * * echo first\\n')
''', initial=None)


if __name__ == '__main__':
    unittest.main()
