"""Check direct Lua metadata reads without invoking scripts or shell commands."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('luajit') or shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua interpreter required')
class LuaIO(unittest.TestCase):
    def run_lua(self, script):
        result = subprocess.run([LUA, '-'], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_init_metadata_is_read_once_and_ignores_comments_and_directories(self):
        self.run_lua(r'''
local files = {
  alpha = '# START=99\necho STOP=100\nSTART=8\nSTOP=90\n',
  beta = '  START = "22" # comment\r\nSTOP=\'7\'\r\n',
  dynamic = 'START=$SOME_VALUE\n',
  unreadable = false,
}
local names = {'.', '..', 'alpha', 'beta', 'dynamic', 'unreadable', 'directory'}
local registered, opens, closes = {}, 0, 0
io.popen = function() error('unexpected subprocess') end
os.execute = function() error('unexpected subprocess') end
io.open = function(path)
  local body = files[path:match('/([^/]+)$')]
  if not body then return nil end
  opens = opens + 1
  return {lines = function() return body:gmatch('([^\n]*)\n') end,
          close = function() closes = closes + 1 end}
end
package.preload.modgui = function() error('modgui must not be needed for grep') end
package.preload.lasync = function() return {execute = function() end} end
package.preload.lfs = function() return {
  dir = function(path)
    assert(path == '/etc/init.d/')
    local index = 0
    return function() index = index + 1; return names[index] end
  end,
  attributes = function(path)
    if path == '/etc/init.d/directory' then return 'directory' end
    if path:match('^/etc/init.d/') then return 'file' end
    if path == '/etc/rc.d/S08alpha' or path == '/etc/rc.d/S22beta' then return 'file' end
  end,
} end
register = function(mapping) registered[#registered + 1] = mapping end
dofile(MAPPING_PATH)
local mapping = registered[2]
assert(mapping.get.start_order(nil, nil, 'alpha') == '8')
assert(mapping.get.stop_order(nil, nil, 'alpha') == '90')
assert(mapping.get.start_order(nil, nil, 'beta') == '22')
assert(mapping.get.stop_order(nil, nil, 'beta') == '7')
assert(mapping.get.start_order(nil, nil, 'dynamic') == '')
assert(mapping.get.start_order(nil, nil, 'unreadable') == '')
assert(mapping.get.active(nil, nil, 'alpha') == '1')
assert(mapping.get.active(nil, nil, 'beta') == '1')
assert(mapping.get.active(nil, nil, 'unknown') == '0')
local entries = mapping.entries()
assert(#entries == 4 and opens == 3 and opens == closes)
'''.replace('MAPPING_PATH', repr(str(ROOT / 'usr/share/transformer/mappings/rpc/system.init.map'))))

    def test_conntrack_limit_falls_back_on_missing_or_empty_proc_files(self):
        source = (ROOT / 'www/info-cards/001_gateway.lp').read_text()
        block = source[source.index('content["total_connection"] = ""'):
                       source.index('content["system_time"]')]
        self.run_lua('''
local files, calls = {}, {}
local content, content_helper = {}, {readfile = function(path)
  calls[#calls + 1] = path
  return files[path] or ''
end}
local function readLimit()
''' + block + '''
  return content.total_connection
end
assert(readLimit() == '')
files['/proc/sys/net/netfilter/nf_conntrack_max'] = '16384'
assert(readLimit() == '16384')
files['/proc/sys/net/ipv4/netfilter/ip_conntrack_max'] = '8192'
assert(readLimit() == '8192')
files['/proc/sys/net/nf_conntrack_max'] = '32768'
assert(readLimit() == '32768')
files['/proc/sys/net/nf_conntrack_max'] = ''
assert(readLimit() == '8192')
''')


if __name__ == '__main__':
    unittest.main()
