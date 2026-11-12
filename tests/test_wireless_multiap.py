"""Native GUI credential paths must not intercept agent radio writes."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / 'decompressed/gui_file'
RUNTIMES = list(filter(None, (shutil.which('lua'), shutil.which('luajit'))))


class WirelessMultiAP(unittest.TestCase):
    @unittest.skipUnless(RUNTIMES, 'Lua required')
    def test_managed_save_skips_legacy_bandsteer_thresholds(self):
        modal = (GUI / 'www/docroot/modals/wireless-modal.lp').read_text()
        start = modal.index('  if content["action"] == "SAVE"')
        block = modal[start:modal.index('  -- End of parameters saving / loading', start)]
        script = r'''
local content, multiap_credential = {action='SAVE'}, 'uci.multiap.controller_credentials.@cred0.'
local args={rssi_threshold='-60',rssi_5g_threshold='-80'}
local ngx={req={get_post_args=function() return args end}}
local format=string.format
local bandsteerpath='uci.wireless.wifi-bandsteer.'
local writes,applies=0,0
local proxy={set=function(path) assert(path:find('@bs0.',1,true)); writes=writes+1; return true end,
 apply=function() applies=applies+1 end}
local function save()
''' + block + r'''
end
save(); assert(writes==0 and applies==0)
multiap_credential=nil; content.bsid='bs0'
save(); assert(writes==2 and applies==1)
'''
        for runtime in RUNTIMES:
            with self.subTest(runtime=runtime):
                result = subprocess.run([runtime, '-'], input=script, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(RUNTIMES, 'Lua required')
    def test_native_gui_path_selection(self):
        modal = (GUI / 'www/docroot/modals/wireless-modal.lp').read_text()
        function = modal[modal.index('local function getMultiapCredential()'):modal.index('\nlocal multiap_credential = getMultiapCredential()')]
        post = (GUI / 'usr/lib/lua/web/content_helper.lua').read_text()
        convert = post[post.index('local function convertResultToObject('):post.index('\n---', post.index('local function convertResultToObject('))]
        script = r'''
local match, sort, concat = string.match, table.sort, table.concat
local untaint = function(v) return type(v)=='table' and v.raw or v end
local function tainted(s)
 return setmetatable({raw=s},{__concat=function() error('Untaint credential names before building paths') end})
end
local curiface = 'wl0'
local controller, agent, guest = '1','1','0'
local lists, fields = {}, {}
local writes = 0
local proxy = {get=function(path) return lists[path] or (fields[path] and {{value=fields[path]}}) end,
 set=function() writes=writes+1; error('Rendering must not write') end}
''' + convert + r'''
local content_helper = {convertResultToObject=convertResultToObject,
 getExactContent=function(t) t.controller,t.agent=controller,agent end}
local function list(network,kind,values)
 local path='uci.web.network.@'..network..'.'..kind..'.'
 lists[path]={}
 for i=#values,1,-1 do
  lists[path][#lists[path]+1]={path=path..'@'..i..'.',param='value',value=values[i]}
 end
end
list('main','intf',{'wl0','wl1'})
list('main','cred',{tainted('renamed24'),tainted('renamed5')})
list('guest','intf',{'wl0_1','wl1_1'})
list('guest','cred',{tainted('guest24'),tainted('guest5')})
local base='uci.multiap.controller_credentials.@'
for _,name in ipairs({'renamed24','renamed5','guest24','guest5'}) do fields[base..name..'.backhaul']='0' end
fields[base..'renamed24.frequency_bands']='radio_2G'
fields[base..'guest24.frequency_bands']='radio_2G'
''' + function + r'''
assert(getMultiapCredential()==base..'renamed24.')
curiface='wl1'; assert(getMultiapCredential()==base..'renamed5.')
fields[base..'renamed24.frequency_bands']='radio_2G,radio_5Gu,radio_5Gl'
assert(getMultiapCredential()==base..'renamed24.')
fields[base..'renamed24.backhaul']='1'; assert(getMultiapCredential()==false)
fields[base..'renamed24.backhaul']='0'
curiface='wl0_1'; assert(getMultiapCredential()==nil)
fields['uci.multiap.tch_feature_extensions.enable']='1'
assert(getMultiapCredential()==base..'guest24.')
curiface='wl1_1'; assert(getMultiapCredential()==base..'guest5.')
curiface='wl0'; lists['uci.web.network.@main.cred.']=nil
assert(getMultiapCredential()==false)
for _,state in ipairs({{'0','0'},{'0','1'},{'1','0'},{'',''}}) do
 controller,agent=state[1],state[2]; assert(getMultiapCredential()==nil)
end
assert(writes==0)
'''
        for runtime in RUNTIMES:
            with self.subTest(runtime=runtime):
                result = subprocess.run([runtime, '-'], input=script, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
