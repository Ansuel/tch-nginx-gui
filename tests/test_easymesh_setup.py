"""Native initialization must preserve radio credentials and roles."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'decompressed/gui_file/usr/lib/lua/transformer/shared/easymesh_setup.lua'
GUI = ROOT / 'decompressed/gui_file/www/lua/easymesh_setup.lua'


class EasyMeshSetup(unittest.TestCase):
    def test_tabs_follow_the_universal_gui_helper_contract(self):
        for runtime in filter(None, (shutil.which('lua'), shutil.which('luajit'))):
            with self.subTest(runtime=runtime):
                script = r'''
T=function(v) return v end
gettext={textdomain=function() end}
local tabs
local layout,supported,access,missing=false,true,true,nil
package.preload['web.post_helper']=function() return {getVariant=function() return {} end,
 getVariantValue=function() return false end} end
package.preload.variant_helper=function() return {} end
package.preload.easymesh_helper=function() return {
 use_new_layout=function() return layout end,is_supported=function()return supported end} end
package.preload['web.ui_helper']=function() return {createModalTabs=function(items)
 for _,t in ipairs(items) do assert(type(t.desc)=='string' and type(t.target)=='string') end
 tabs=items;return '' end} end
io.open=function(path)
 if path:match('/([^/]+)$')==missing then return nil end
 return {close=function()end}
end
ngx={var={uri='/modals/easy-mesh-configuration.lp',args='setup=1&refresh=1'},print=function() end,
 ctx={session={hasAccess=function(_,p) assert(not p:find('?',1,true));return access end}}}
local render=assert(loadfile(TABS))
for _,new in ipairs({false,true}) do
 layout=new;render()
 assert(#tabs==4 and tabs[2].desc=='Setup and role' and tabs[2].active=='active')
 assert(tabs[3].desc=='Topology' and tabs[4].target=='/modals/easymesh-devices-info-modal-newEM.lp')
 assert(tabs[1].target==(new and '/modals/easymesh-configuration-modal-newEM.lp' or '/modals/easy-mesh-configuration.lp'))
 assert(tabs[3].target==(new and '/modals/easymesh-topology-modal-newEM.lp' or '/modals/wifi-extender-status.lp'))
 ngx.var.uri=tabs[4].target;ngx.var.args='refresh=1';render();assert(tabs[4].active=='active')
 ngx.var.uri='/modals/easy-mesh-configuration.lp';ngx.var.args='setup=1&refresh=1'
end
missing='easymesh-devices-info-modal-newEM.lp';render();assert(#tabs==3)
missing='easymesh-topology-modal-newEM.lp';render();assert(tabs[3].target=='/modals/wifi-extender-status.lp')
missing=nil;supported=false;render();assert(#tabs==1 and tabs[1].desc=='Setup and role')
access=false;render();assert(#tabs==0)
'''.replace('TABS', repr(str(ROOT / 'decompressed/gui_file/www/snippets/tabs-easyMesh.lp')))
                result = subprocess.run([runtime, '-'], input=script, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_initialization_checks_native_capabilities_and_explicit_rpc_opt_in(self):
        for runtime in filter(None, (shutil.which('lua'), shutil.which('luajit'))):
            with self.subTest(runtime=runtime):
                script = r'''
local existing,missing,executable,credentials=false,nil,true,true
local types={agent='global',controller='global',al_entity='global'}
local flags={agent='0',controller='0'}
package.preload.lfs=function() return {attributes=function(_,attribute)
 assert(attribute=='permissions');return executable and 'rwxr-xr-x' or 'rw-r--r--'
end} end
package.preload.uci=function() return {cursor=function(directory,savedir)
 assert(directory=='/rom/etc/config' and savedir=='/rom/tmp/.uci')
 return {
 get=function(_,config,section,option)
  assert(config=='multiap');return option=='enabled' and flags[section] or types[section]
 end,
 foreach=function(_,p,t,cb) assert(p=='multiap' and t=='controller_credentials');if credentials then cb({}) end end,
 unload=function() end} end} end
local original=io.open
io.open=function(path)
 if path=='/etc/config/multiap' then return existing and {close=function() end} or nil end
 if path==missing then return nil end
 return {close=function() end}
end
local setup=assert(loadfile(MODULE))()
assert(setup.can_initialize())
existing=true;assert(not setup.can_initialize());existing=false
missing='/usr/lib/libplatform_map.so';assert(not setup.can_initialize());missing=nil
executable=false;assert(not setup.can_initialize());executable=true
types.agent='unsupported';assert(not setup.can_initialize());types.agent='global'
flags.controller='unsupported';assert(not setup.can_initialize());flags.controller='1'
credentials=false;assert(not setup.can_initialize());credentials=true
assert(setup.can_initialize())
io.open=original
local mapping,initialized
register=function(m) mapping=m end
setup.initialize=function() initialized=true;return true end
package.preload['transformer.shared.easymesh_setup']=function() return setup end
assert(loadfile(MAPPING))()
assert(mapping.objectType.name=='rpc.system.easymesh.')
assert(not mapping.set.initialize(nil,nil,'0') and not initialized)
assert(not mapping.set.initialize(nil,nil,'arbitrary shell command') and not initialized)
assert(mapping.set.initialize(nil,nil,'1') and initialized)
'''.replace('MODULE', repr(str(MODULE))).replace(
                    'MAPPING', repr(str(ROOT / 'decompressed/gui_file/usr/share/transformer/mappings/rpc/system.easymesh.map')))
                result = subprocess.run([runtime, '-'], input=script, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_native_profiles_and_role_guards(self):
        for runtime in filter(None, (shutil.which('lua'), shutil.which('luajit'))):
            with self.subTest(runtime=runtime):
                script = r'''
package.preload.uci=function() return {} end
local setup=assert(loadfile(MODULE))()
local source, staged, writes
local function reset()
 source={web={main={intf={'wl0','wl1'},cred={'main24','main5'},splitssid='1'}}, wireless={
   wl0={device='radio_2G',ssid='Existing 24',state='1',network='lan'},
   wl1={device='radio_5G',ssid='Existing 5',state='1',network='lan'},
   ap0={['.type']='wifi-ap',iface='wl0',state='1',security_mode='wpa2-psk',wpa_psk_key='existing-key-24'},
   ap1={['.type']='wifi-ap',iface='wl1',state='1',security_mode='wpa2-psk',wpa_psk_key='existing-key-5'}}}
 staged={multiap={agent={['.type']='global',enabled='1'},controller={['.type']='global',enabled='1'},controller_selection={enabled='1'},
   factory={['.name']='factory',['.type']='controller_credentials',ssid='Factory',wpa_psk_key='factory-secret',state='1'}}}
 writes=0
end
local function cursor(db)
 return {get=function(_,p,s,k) local row=db[p] and db[p][s];return row and (k and row[k] or row['.type']) end,
 foreach=function(_,p,t,cb) for n,s in pairs(db[p] or {}) do if s['.type']==t then
   s['.name']=n;if cb(s)==false then break end end end end,
 set=function(_,p,s,k,v) writes=writes+1;db[p]=db[p] or {};db[p][s]=db[p][s] or {}
   if v==nil then db[p][s]['.type']=k else db[p][s][k]=v end;return true end}
end
reset();assert(setup.seed(cursor(staged),cursor(source)))
assert(staged.multiap.agent.enabled=='0' and staged.multiap.controller.enabled=='0')
assert(staged.multiap.factory.state=='0' and staged.multiap.factory.wpa_psk_key=='')
assert(staged.multiap.main24.ssid=='Existing 24' and staged.multiap.main24.wpa_psk_key=='existing-key-24')
assert(staged.multiap.main5.frequency_bands=='radio_5G' and staged.multiap.main5.backhaul=='0')
assert(staged.multiap.agent.bss_list=='wl0,wl1')
reset(); source.web.main.splitssid=nil; assert(setup.seed(cursor(staged),cursor(source)))
assert(staged.multiap.main24.state=='1' and staged.multiap.main5.state=='1')
reset(); source.web.main.splitssid=nil
source.wireless.wl1.ssid=source.wireless.wl0.ssid
source.wireless.ap1.wpa_psk_key=source.wireless.ap0.wpa_psk_key
assert(setup.seed(cursor(staged),cursor(source)))
assert(staged.multiap.main24.frequency_bands=='radio_2G,radio_5G' and staged.multiap.main5.state=='0')
local function with_native_backhaul()
 reset()
 staged.multiap.agent.backhaul_list='wl1_2'
 staged.multiap.factory.backhaul='1'
 staged.multiap.factory.fronthaul='0'
 staged.multiap.factory.security_mode='wpa2-psk'
 source.wireless.wl1_2={mode='ap', network='lan', backhaul='1', state='1', ssid='Existing backhaul'}
 source.wireless.ap4={['.type']='wifi-ap', iface='wl1_2', state='1',
  security_mode='wpa2-psk', wpa_psk_key='existing-backhaul-key'}
end
with_native_backhaul();assert(setup.seed(cursor(staged),cursor(source)))
assert(staged.multiap.factory.state=='1' and staged.multiap.factory.wpa_psk_key=='existing-backhaul-key')
assert(staged.multiap.factory.ssid=='Existing backhaul' and staged.multiap.agent.backhaul_list=='wl1_2')
assert(staged.multiap.agent.bss_list=='wl0,wl1,wl1_2' and staged.multiap.agent.fronthaul_list=='wl0,wl1')
with_native_backhaul();source.wireless.ap4.state='0';assert(setup.seed(cursor(staged),cursor(source)))
assert(staged.multiap.factory.state=='0' and staged.multiap.factory.wpa_psk_key=='')
assert(staged.multiap.agent.backhaul_list=='' and staged.multiap.agent.bss_list=='wl0,wl1')
reset();source.web.main.splitssid='0';source.wireless.wl1.ssid=source.wireless.wl0.ssid
source.wireless.ap1.wpa_psk_key=source.wireless.ap0.wpa_psk_key
assert(setup.seed(cursor(staged),cursor(source)))
assert(staged.multiap.main24.state=='1' and staged.multiap.main5.state=='0')
assert(staged.multiap.main24.frequency_bands=='radio_2G,radio_5G')
assert(staged.multiap.main24.wpa_psk_key=='existing-key-24')
for _,mutate in ipairs({
 function() source.web.main.splitssid='0' end,
 function() source.web.main.cred={'same','same'} end,
 function() source.web.main.cred={'agent','main5'} end,
 function() source.web.main.intf={'wl0'} end,
 function() source.wireless.ap1.wpa_psk_key='' end,
 function() source.wireless.ap1.security_mode='wpa3-psk' end,
 function() source.wireless.wl1.backhaul='1' end,
 function() source.wireless.wl1.network='guest' end,
 function() source.wireless.wl1.state='0' end,
 function() source.wireless.ap2={['.type']='wifi-ap',iface='wl1'} end,
}) do reset();mutate();assert(not setup.seed(cursor(staged),cursor(source)));assert(writes==0) end
setup=assert(loadfile(GUI))()
local applied, values, bridgeCalls=0,nil,0
local optional=true
local bridged,proto,uplink,localInterface=true,'bridge','eth5','eth5'
local ready,portExists,advertise,ethernet=true,true,false,true
package.preload.lfs=function() return {attributes=function() return portExists and 'directory' or nil end} end
package.preload.easymesh_helper=function() return {is_supported=function() return true end} end
package.preload.bridgehelper=function() return {
 isBridged=function() return bridged end,get=function(path)
  if path=='uci.network.interface.@wan.proto' then return proto end
  if path=='uci.network.interface.@wan.ifname' then return localInterface end
  if path=='uci.network.interface.@lan.ifname' then return 'eth5' end
  if path=='uci.network.interface.@lan.type' then return ready and 'bridge' or '' end
  if path=='uci.dhcp.dhcp.@lan.ignore' then return advertise and '0' or '1' end
  if path:match('^uci.dhcp') then return advertise and 'server' or 'disabled' end
  if path=='uci.ethernet.port.@eth5.wan' then return ethernet and '1' or '0' end
 end,getUplink=function() return uplink end,
 resolveUplinks=function(v) return v end,isDslInterface=function(v,k) return v:sub(1,#k)==k end,
 enter=function() bridgeCalls=bridgeCalls+1;return true end} end
package.preload.datamodel=function() return {get=function(path)
 if not optional and (path:find('wifi_conductor',1,true) or path:find('controller_selection',1,true)) then error('optional object absent') end
 return {{value='1'}} end,
 set=function(v) values=v;return true end,
 apply=function() applied=applied+1;return true end} end
assert(not setup.set_role('injected'));assert(applied==0)
assert(setup.set_role('off'));assert(values['uci.multiap.agent.enabled']=='0' and values['uci.multiap.controller.enabled']=='0')
assert(values['uci.wireless.wifi-bandsteer.@bs0.state']==nil)
assert(values['uci.wifi_conductor.global.multiap_enabled']=='0')
assert(values['uci.multiap.global.@controller_selection.enabled']=='0')
assert(setup.set_role('controller'));assert(values['uci.multiap.agent.enabled']=='1' and values['uci.multiap.controller.enabled']=='1')
assert(values['uci.wireless.wifi-bandsteer.@bs0.state']=='0')
assert(values['uci.wifi_conductor.global.multiap_enabled']=='1')
assert(values['uci.multiap.global.@controller_selection.enabled']=='0')
optional=false;assert(setup.set_role('controller'))
assert(values['uci.wifi_conductor.global.multiap_enabled']==nil)
assert(values['uci.multiap.global.@controller_selection.enabled']==nil)
optional=true
assert(bridgeCalls==0)
assert(setup.set_role('booster'));assert(values['uci.multiap.controller.enabled']=='0' and bridgeCalls==1)
local count=applied
bridged=false;assert(not setup.set_role('booster'));bridged=true
proto='dhcp';assert(not setup.set_role('booster'));proto='bridge'
proto='dhcp';localInterface='br-lan';assert(setup.set_role('booster'))
proto='static';assert(setup.set_role('booster'));proto='pppoe';assert(not setup.set_role('booster'))
-- An existing AP retains its management client and does not reconfigure networking.
bridged=false;proto='dhcp';uplink='eth5';localInterface='br-lan'
local entered=bridgeCalls;assert(setup.set_role('booster'));assert(bridgeCalls==entered)
local appliedBefore=applied
advertise=true;assert(not setup.set_role('booster'));advertise=false
portExists=false;assert(not setup.set_role('booster'));portExists=true
ethernet=false;assert(not setup.set_role('booster'));ethernet=true
ready=false;assert(not setup.set_role('booster'));ready=true
assert(applied==appliedBefore);bridged=true
proto='bridge';count=applied
uplink='ptm0';assert(not setup.set_role('booster'))
uplink='eth5 atm_8_35';assert(not setup.set_role('booster'));assert(applied==count)
'''.replace('MODULE', repr(str(MODULE))).replace('GUI', repr(str(GUI)))
                result = subprocess.run([runtime, '-'], input=script, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
