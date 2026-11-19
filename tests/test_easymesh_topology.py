from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('luajit') or shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua required')
class EasyMeshTopology(unittest.TestCase):
    def run_lua(self, script):
        result = subprocess.run([LUA, '-', str(ROOT)], input=script,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_assets_and_parent_cycles(self):
        self.run_lua(r'''
local root = arg[1]
package.path = root .. '/www/lua/?.lua;' .. package.path
local open = io.open
io.open = function(path, mode)
  return open(path:gsub('^/www/',root .. '/www/'),mode)
end
local t = require('easymesh_topology')
assert(t.plain(nil)=='')
assert(t.image('DGA4130','gateway')=='gateway_AGTEF.png')
assert(t.image('Technicolor DGA4132')=='gateway_AGTHP.png')
assert(t.image('MediaAccess DGA4331')=='gateway_AGTHF.png')
assert(t.image('DGA4331')=='gateway_AGTHF.png')
assert(t.image('../../etc/passwd','gateway')=='gateway_icon.png')
assert(t.image('Unknown model')=='extender_icon.png')
assert(t.image(nil,'gateway')=='gateway_icon.png')
local nodes = {
 {macAddr='AA',parentAccessPoint='bb'},
 {macAddr='BB',parentAccessPoint='aa'},
 {macAddr='CC',parentAccessPoint='cc'},
 {macAddr='DD',parentAccessPoint='missing'},
 {macAddr='EE',parentAccessPoint='dd'},
}
local roots = t.forest(nodes)
local seen = {}
local function visit(list)
 for _,n in ipairs(list) do
  assert(not seen[n.macAddr]); seen[n.macAddr]=true
  visit(n.children)
 end
end
visit(roots)
for _,n in ipairs(nodes) do assert(seen[n.macAddr] and n.children==nil) end
assert(t.mac('aa-bb')=='AA:BB')
''')

    def test_legacy_inventory_render_and_missing_optional_services(self):
        self.run_lua(r'''
local root=arg[1]
package.path=root..'/www/lua/?.lua;'..package.path
local open=io.open
io.open=function(path,mode) return open(path:gsub('^/www/',root..'/www/'),mode) end
T=function(s)return s end
gettext={textdomain=function()end}
local output, controller, optional={},'1',true
ngx={print=function(...) for i=1,select('#',...) do output[#output+1]=tostring(select(i,...)) end end}
package.preload.easymesh_helper=function()return {is_supported=function()return true end}end
package.preload['web.ui_helper']=function()return {
 createHeader=function()return '<header>'end,createFooter=function()return '<footer>'end,
 createAlertBlock=function(s)return s end}end
package.preload['web.web']=function()return {html_escape=function(s)
 return (s:gsub('&','&amp;'):gsub('<','&lt;'):gsub('"','&quot;')) end}end
package.preload['web.lp']=function()return {setpath=function()end,include=function()end}end
local vals={['rpc.multiap.ExtenderNumberOfEntries']='1',
 ['uci.env.var.prod_friendly_name']='DGA4130',
 ['uci.system.system.@system[0].hostname']='<Gateway>',
 ['uci.multiap.controller.macaddress']='AA', ['uci.multiap.agent.macaddress']='AA',
 ['uci.multiap.agent.enabled']='1'}
package.preload.datamodel=function()return {
 get=function(path)
  if path=='uci.multiap.controller.enabled' then return {{value=controller}} end
  if path=='rpc.multiap.device.' then
   if not optional then error('absent') end
   return {{al_mac='BB',productclass='DGA4132',device_name='agent_bb',FriendlyName='<Booster>',parent='aa',
    backhaul_interface_type='Ethernet',eth_clients='00:11:22:33:44:55',
    radio_sta_list='00:11:22:33:44:55'}}
  end
  if path=='rpc.multiap.eth.' then
   if not optional then error('optional Ethernet inventory absent') end
   return {{MacAddress='00:11:22:33:44:66'},{MacAddress='00:11:22:33:44:55'},{MacAddress='bb'}}
  end
  if path:sub(-1)=='.' then return {} end
  return {{value=vals[path] or ''}}
 end,
 getPN=function() error('optional AP inventory absent') end}end
package.preload['web.content_helper']=function()return {
 convertResultToObject=function(_,r)return r end,
 loadTableData=function()error('hostmanager absent')end}end
local page=assert(loadfile(root..'/www/docroot/modals/wifi-extender-status.lp'))
page()
local html=table.concat(output)
assert(html:find('gateway_AGTEF.png',1,true))
assert(html:find('gateway_AGTHP.png',1,true))
assert(html:find('&lt;Gateway>',1,true) and not html:find('<Gateway>',1,true))
assert(html:find('DGA4132',1,true) and html:find('Controller',1,true))
assert(html:find('&lt;Booster>',1,true))
assert(html:find('00:11:22:33:44:66',1,true))
local _,count=html:gsub('00:11:22:33:44:55','')
assert(count==2) -- one node: fallback name and MAC, not duplicate associations
assert(not html:find('src="img/',1,true))
controller='0';optional=false;output={};page()
html=table.concat(output)
assert(html:find('Agent',1,true) and html:find('gateway_AGTEF.png',1,true))
''')
