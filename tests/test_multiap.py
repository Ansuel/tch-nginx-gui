"""Native MultiAP credential routing and installation metadata regressions."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
RUNTIMES = list(filter(None, (shutil.which('lua'), shutil.which('luajit'))))


class MultiAP(unittest.TestCase):
    @unittest.skipUnless(RUNTIMES, 'Lua required')
    def test_native_credentials_and_agent_radio_rpcs(self):
        for lua in RUNTIMES:
            for helper in ('tests/fixtures/multiap-bandsteerhelper.lua',
                           'decompressed/gui_file/usr/lib/lua/transformer/shared/bandsteerhelper.lua'):
                with self.subTest(runtime=lua, helper=helper):
                    result = subprocess.run([
                        lua, str(ROOT / 'tests/test_multiap.lua'),
                        str(ROOT / 'decompressed/gui_file'), str(ROOT / helper),
                    ], text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(RUNTIMES, 'Lua required')
    def test_restore_only_missing_network_metadata_and_keep_lists(self):
        installer = (ROOT / 'decompressed/gui_file/etc/modgui_scripts/04_config.sh').read_text()
        source = installer.split("lua - <<'LUA' || return 1\n", 1)[1].split('\nLUA\n', 1)[0]
        script = r'''
local networks = {main = {['.name']='main', ['.type']='network',
  intf={'wl0','wl1'}, cred={'cred7','cred9'}, splitssid='0'},
  guest = {['.name']='guest', ['.type']='network',
  intf={'wl0_1','wl1_1'}, cred={'cred3','cred4'}, splitssid='1'}}
local restored, commits = {}, 0
package.preload.uci = function() return {cursor = function() return {
  foreach = function(_, config, kind, callback)
    assert(config=='web_back' and kind=='network')
    for _, section in pairs(networks) do callback(section) end
  end,
  get = function(_, config, name) assert(config=='web'); return restored[name] end,
  set = function(_, config, name, option, value)
    assert(config=='web')
    if value == nil then
      assert(option=='network'); restored[name]={}
    else
      assert(option:sub(1,1)~='.'); restored[name][option]=value
    end
    return true
  end,
  commit = function(_, config) assert(config=='web'); commits=commits+1; return true end,
  close = function() end,
} end} end
'''
        script += 'local restore = function()\n' + source + '\nend\n'
        script += r'''
restore()
assert(restored.main.intf[2]=='wl1' and restored.main.cred[2]=='cred9')
assert(restored.main.splitssid=='0' and commits==1)
restored.main.splitssid='1'
restore()
assert(restored.main.splitssid=='1' and commits==1)
networks={}
restore()
assert(commits==1)
'''
        for lua in RUNTIMES:
            with self.subTest(runtime=lua):
                result = subprocess.run([lua, '-'], input=script, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
