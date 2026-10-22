"""Exercise optional dashboard integration using synthetic network state."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import unittest

GUI = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('lua')

PRELUDE = r'''
local root, mode, enabled = arg[1], arg[2], arg[3]
package.path = root .. '/usr/lib/lua/?.lua;' .. package.path
string.untaint = function(v) return v end
T = function(v) return v end
gettext = {textdomain = function() end}
local calls = {}
local values = {['uci.modgui.app.smartphone_app']='1',
    ['uci.network.interface.@smartphone.ifname']='usb7',
    ['rpc.network.interface.@smartphone.up']='1',
    ['uci.mobiled.device_defaults.enabled']=enabled or '1'}
if mode == 'absent' then values['uci.modgui.app.smartphone_app']='0'
elseif mode == 'unconfigured' then values['uci.network.interface.@smartphone.ifname']=nil
elseif mode == 'down' then values['rpc.network.interface.@smartphone.up']='0'
elseif mode == 'error' then values['rpc.network.interface.@smartphone.up']=nil
elseif mode == 'unsafe' then values['uci.network.interface.@smartphone.ifname']='<script>' end
local session = {hasAccess=function(_, path)
    return mode ~= 'denied' or path ~= '/modals/smartphone-modal.lp'
end}
package.preload.datamodel = function() return {get=function(path)
    calls[#calls+1] = path
    if mode == 'error' and path == 'rpc.network.interface.@smartphone.up' then error('backend unavailable') end
    local value = values[path]
    if value then return {{value=value}} end
end} end
local utils = {string_map={no_device='0 device connected'},
    get_params=function() return {card_title='Mobile'} end,
    get_uci_device_path=function() return 'uci.mobiled.device_defaults.' end,
    getContent=function(path)
        if path == 'rpc.mobiled.DeviceNumberOfEntries' then return {DeviceNumberOfEntries='0'} end
        return {enabled=enabled or '1'}
    end}
package.preload['web.lte-utils'] = function() return utils end
package.preload['web.ui_helper'] = function() return {
    createCardHeader=function() return '' end, createSimpleLight=function() return '' end} end
package.preload['web.web'] = function() return {html_escape=function(v) return v end} end
ngx = {ctx={session=session}}
'''


@unittest.skipUnless(LUA, 'Lua interpreter required')
class MobileTetheringTest(unittest.TestCase):
    def lua(self, source, mode='active', enabled='1'):
        result = subprocess.run([LUA, '-', str(GUI), mode, enabled], input=PRELUDE+source,
                                text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        return result.stdout

    def test_optional_state_and_access_gate(self):
        for mode, status in [('active','Active (usb7)'), ('down','Inactive (usb7)'),
                             ('unconfigured','Not configured'), ('error','Status unavailable (usb7)'),
                             ('unsafe','Status unavailable'), ('absent',''), ('denied','')]:
            with self.subTest(mode=mode):
                out = self.lua(r'''
local result = require('web.smartphone-tether').get_status(session)
assert(result.visible == (mode ~= 'absent' and mode ~= 'denied'))
if mode == 'denied' then assert(#calls == 0) end
if mode == 'absent' then assert(#calls == 1) end
for _, path in ipairs(calls) do assert(not path:find('rpc.smartphone',1,true)) end
io.write(result.status)
''', mode)
                self.assertEqual(out, status)

    def test_native_modem_count_and_ajax_fields_remain_separate(self):
        for mode in ('active','absent','denied'):
            self.lua(r'''
local result
package.preload.dkjson = function() return {encode=function(data)
    result=data; return true
end} end
utils.sendResponse=function()
    assert(result.no_device == (mode == 'active' and 'Mobile modems: 0' or '0 device connected'))
    assert(result.redirect_sim == 'false')
    assert(result.smartphone_visible == (mode == 'active'))
    assert(result.smartphone_status == (mode == 'active' and 'Active (usb7)' or ''))
    error('response complete')
end
local ok, err = pcall(dofile, root .. '/www/docroot/ajax/mobiletab.lua')
assert(not ok and err:find('response complete',1,true),err)
''',mode)

    @unittest.skipUnless(shutil.which('node'), 'Node required')
    def test_card_refresh_also_works_when_native_mobile_is_disabled(self):
        for enabled in ('0','1'):
            html = self.lua(r'''
ngx.print=function(...) for _, v in ipairs({...}) do io.write(tostring(v)) end end
dofile(root .. '/www/cards/010_lte.lp')
''', enabled=enabled)
            self.assertIn('data-remote="/modals/smartphone-modal.lp"',html)
            self.assertIn('USB tethering',html)
            script = re.search(r'<script>(.*?)</script>',html,re.S).group(1)
            harness = r'''
var document={}, observed={};
var binding={smartphoneVisible:function(v){observed.visible=v},smartphoneStatus:function(v){observed.status=v}};
if (ENABLED) ['radioType','mobileStatus','signalQuality','deviceStatus'].forEach(function(k){binding[k]=function(){}});
function $(value){return {ready:function(f){f()},children:function(){return this},each:function(){}}}
$.each=function(){};
$.post=function(url,args,callback){callback({bars:'',radio_interface:'',status:'',signal_quality:'',no_device:'0 device connected',redirect_sim:false,smartphone_visible:true,smartphone_status:'Active (usb7)'})};
var tch={elementCSRFtoken:function(){return 'fixture-token'}};
var modgui={createAjaxUpdateCard:function(a,b,c,d,refresh){refresh(binding)}};
'''.replace('ENABLED',json.dumps(enabled=='1'))
            result = subprocess.run(['node','-e',harness+script+"\nif(observed.visible!==true || observed.status!=='Active (usb7)') throw Error('missing summary');"],
                                    text=True,capture_output=True,timeout=5)
            self.assertEqual(result.returncode,0,result.stderr)

    def test_absent_app_does_not_add_a_link(self):
        html=self.lua(r'''
ngx.print=function(...) for _, v in ipairs({...}) do io.write(tostring(v)) end end
dofile(root .. '/www/cards/010_lte.lp')
''','absent','0')
        self.assertNotIn('smartphone-modal.lp',html)
        self.assertNotIn('LteCardRefresh',html)


if __name__ == '__main__':
    unittest.main()
