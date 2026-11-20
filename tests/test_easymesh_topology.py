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

    def test_history_uses_native_fastweb_records_and_escapes_event_text(self):
        self.run_lua(r'''
local root = arg[1]
local records, recorded, output
local nativePath = 'uci.fastweb.topology_events.@topology_events.back_up_events.'
package.preload['web.content_helper'] = function() return {
  addListContent = function(content, paths)
    assert(paths.events == nativePath)
    content.events = records
  end,
} end
local data = {
  first = {time='2025-01-09 09:00:00', topology_msg='Extender connected'},
  second = {time='2025-01-09 09:00:12', topology_msg='<b>Backhaul changed</b>'},
  invalid = {time='2025-01-09 09:00:32'},
}
package.preload.dkjson = function() return {decode=function(value) return data[value] end} end
package.preload.topology_history = function() return {read=function() return recorded end} end
package.preload['web.web'] = function() return {html_escape=function(value)
  return (value:gsub('<', '&lt;'):gsub('>', '&gt;'))
end} end
T = function(text) return text end
ngx = {print=function(...) for _, value in ipairs({...}) do output[#output+1] = value end end}
local page = assert(loadfile(root .. '/www/snippets/easymesh-history.lp'))
local function render(values)
  records, output = values, {}
  page()
  return table.concat(output)
end
assert(render(nil) == '')
assert(render({}):find('No topology changes recorded.', 1, true))
local html = render({'first', 'invalid', 'malformed', 'second'})
local first = assert(html:find('Extender connected', 1, true))
local second = assert(html:find('&lt;b&gt;Backhaul changed&lt;/b&gt;', 1, true))
assert(first < second and not html:find('<b>Backhaul changed</b>', 1, true))
assert(not html:find('09:00:32', 1, true))
recorded = {{
  kind='changed', time=1736413212, address='00:11:22:33:44:55',
  before={link='Ethernet', parent=''}, after={link='5GHz', parent='AA:BB:CC:DD:EE:FF'},
}}
html = render(nil)
assert(html:find('00:11:22:33:44:55 · Backhaul changed · Ethernet → 5GHz (AA:BB:CC:DD:EE:FF)', 1, true))
assert(render({}):find('Ethernet → 5GHz', 1, true))
assert(not render({'first'}):find('Ethernet → 5GHz', 1, true))
''')

    def test_history_polls_only_topology_fields_and_skips_partial_snapshots(self):
        self.run_lua(r'''
local history = dofile(arg[1] .. '/usr/lib/lua/topology_history.lua')
local events, sample, callback
history.read = function() return {} end
history.write = function(value) events = value; return true end
package.preload.topology_history = function() return history end
local path = 'rpc.multiap.device.@1.'
local function topologyRows(link)
  return {
    {path=path, param='al_mac', value='00:11:22:33:44:55'},
    {path=path, param='backhaul_interface_type', value=link},
  }
end
package.preload.datamodel = function() return {
  getPN = function(query, nextLevel)
    assert(query == 'rpc.multiap.device.' and nextLevel and sample ~= 1)
    if sample == 3 then return {{path=path}, {path='rpc.multiap.device.@2.'}} end
    return {{path=path}}
  end,
  get = function(query, abort)
    if query == 'uci.multiap.controller.enabled' then return {{value=sample == 1 and '0' or '1'}} end
    assert(abort == false and #query == (sample == 3 and 8 or 4))
    assert(query[1] == path .. 'al_mac' and query[3] == path .. 'backhaul_interface_type')
    return topologyRows(sample == 2 and 'Ethernet' or '5GHz')
  end,
} end
package.preload.uloop = function() return {
  init = function() end,
  timer = function(run)
    callback = run
    return {set=function(_, delay) assert(delay == ({[0]=1000, 60000, 15000, 15000, 15000})[sample]) end}
  end,
  run = function()
    for index=1,4 do
      sample=index
      callback()
      if index < 4 then assert(events == nil) end
    end
  end,
} end
sample = 0
dofile(arg[1] .. '/usr/bin/topology_chg.lua')
assert(#events == 1 and events[1].before.link == 'Ethernet' and events[1].after.link == '5GHz')
''')

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
