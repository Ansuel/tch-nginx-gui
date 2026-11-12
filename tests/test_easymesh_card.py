"""EasyMesh header switches use the normal card SAVE lifecycle."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / 'decompressed/gui_file'
RUNTIMES = list(filter(None, (shutil.which('lua'), shutil.which('luajit'))))


@unittest.skipUnless(RUNTIMES, 'Lua required')
class EasyMeshCard(unittest.TestCase):
    def run_lua(self, script):
        for runtime in RUNTIMES:
            with self.subTest(runtime=runtime):
                result = subprocess.run([runtime, '-'], input=script, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_card_header_targets_configuration_and_respects_access(self):
        self.run_lua(r'''
local agent,controller,newLayout,configAccess,viewAccess,defaultUser
local header, output
T=function(s) return s end
N=function(one,many,n) local s=n==1 and one or many;return (s:gsub('%%[12]%$','%%')) end
gettext={textdomain=function() end}
package.preload.uci=function() return {} end
package.preload.datamodel=function() return {} end
package.preload.variant_helper=function() return {} end
package.preload['web.post_helper']=function() return {getVariant=function() return {} end} end
package.preload.easymesh_helper=function() return {is_supported=function() return true end,
 use_new_layout=function() return newLayout end} end
package.preload['web.content_helper']=function() return {getExactContent=function(c)
 c.agentState,c.controllerState,c.count=agent,controller,'0';return true
end} end
package.preload['web.ui_helper']=function() return {
 createCardHeader=function(_,path,name,value) header={path=path,name=name,value=value};return '' end,
 createSimpleLight=function() return '' end} end
ngx={print=function(s) output=output..tostring(s) end,ctx={session={
 hasAccess=function(_,path) if path:find('topology',1,true) then return viewAccess end;return configAccess end,
 isdefaultuser=function() return defaultUser end}}}
''' + f'local card={str(GUI / "www/cards/020_wifiExtender.lp")!r}\n' + r'''
for _,layout in ipairs({false,true}) do
 newLayout=layout;configAccess=true;viewAccess=true;defaultUser=false
 for _,states in ipairs({{'0','0'},{'1','0'},{'0','1'},{'1','1'}}) do
  agent,controller=states[1],states[2];header=nil;output='';assert(loadfile(card))()
  local expected=layout and '/modals/easymesh-configuration-modal-newEM.lp' or '/modals/easy-mesh-configuration.lp'
  assert(header.path==expected and header.name=='easyMeshCardEnable')
  assert(header.value==((agent=='1' or controller=='1') and '1' or '0'))
 end
end
newLayout=true;agent='1';controller='0';configAccess=false;viewAccess=true
header=nil;output='';assert(loadfile(card))()
assert(header.path=='/modals/easymesh-topology-modal-newEM.lp' and header.name==nil)
viewAccess=false;header=nil;output='';assert(loadfile(card))();assert(header==nil)
defaultUser=true;header=nil;output='';assert(loadfile(card))();assert(header.path==nil and header.name==nil)
''')

    def test_card_save_changes_only_service_flags(self):
        post = (GUI / 'usr/lib/lua/web/post_helper.lua').read_text()
        handle = post[post.index('function M.handleQuery('):post.index('\n---', post.index('function M.handleQuery('))]
        boolean = post[post.index('function M.validateBoolean('):post.index('\n---', post.index('function M.validateBoolean('))]
        content = (GUI / 'usr/lib/lua/web/content_helper.lua').read_text()
        validate = content[content.index('function M.validateObject('):content.index('\n--Comparing', content.index('function M.validateObject('))]
        set_object = content[content.index('function M.setObject('):content.index('\nlocal function extractSubPaths', content.index('function M.setObject('))]
        script = r'''
local M, content_helper = {}, {}
local method,args,db,exited,messages,applies,agentOnly,conductor
local pairs,match,next= pairs,string.match,next
T=function(s) return s end
local setlanguage=function() end
local function errorsFound() return false end
local message_helper={pushMessage=function(s,level) messages[#messages+1]=level end}
local proxy={get=function() return conductor and {{value='1'}} or nil end,
 set=function(values) for path,value in pairs(values) do
  assert(path=='uci.multiap.agent.enabled' or path=='uci.multiap.controller.enabled' or path=='uci.wifi_conductor.global.multiap_enabled')
  db[path]=value
 end;return true end,
 apply=function() applies=applies+1;return true end}
content_helper.getExactContent=function(c) for name,path in pairs(c) do c[name]=assert(db[path]) end;return true end
ngx={HTTP_OK=200,ERR=3,log=function() end,print=function() end,exit=function(code) exited=code end,
 var={request_method='POST',content_type='application/x-www-form-urlencoded'},
 req={get_method=function() return method end,get_post_args=function() return args end}}
package.preload.uci=function() return {} end
package.preload.datamodel=function() return proxy end
package.preload.variant_helper=function() return {} end
package.preload['web.uimessage_helper']=function() return {popMessages=function() return messages end} end
package.preload['web.ui_helper']=function() return {createMessages=function() return '' end} end
'''
        script += boolean + handle + '\nlocal post=M\n'
        script += "post.getVariant=function() return {} end\npost.getVariantValue=function() return not agentOnly end\n"
        script += "package.preload['web.post_helper']=function() return post end\nM=content_helper\n"
        script += validate + set_object
        script += f'\nlocal mesh=assert(loadfile({str(GUI / "www/lua/easymesh_helper.lua")!r}))()\n'
        script += r'''
local function reset()
 method='POST';args={action='SAVE',easyMeshCardEnable='0'};exited=nil;messages={};applies=0
 agentOnly=false;conductor=false
 db={['uci.multiap.agent.enabled']='1',['uci.multiap.controller.enabled']='1',
 ['uci.wifi_conductor.global.multiap_enabled']='1',credential='unchanged'}
end
for _,optional in ipairs({false,true}) do
 reset();conductor=optional;args['ssid@cred0']='must not write credentials'
 assert(mesh.handle_card_toggle() and exited==200)
 assert(db['uci.multiap.agent.enabled']=='0' and db['uci.multiap.controller.enabled']=='0')
 assert(db.credential=='unchanged' and applies==1)
 if optional then assert(db['uci.wifi_conductor.global.multiap_enabled']=='0') end
 args.easyMeshCardEnable='1';assert(mesh.handle_card_toggle())
 assert(db['uci.multiap.agent.enabled']=='1' and db['uci.multiap.controller.enabled']=='1')
end
reset();agentOnly=true;args.easyMeshCardEnable='1';assert(mesh.handle_card_toggle())
assert(db['uci.multiap.agent.enabled']=='1' and db['uci.multiap.controller.enabled']=='0')
for _,value in ipairs({'2','invalid',{}}) do
 reset();args.easyMeshCardEnable=value;assert(mesh.handle_card_toggle())
 assert(applies==0 and db['uci.multiap.agent.enabled']=='1' and db['uci.multiap.controller.enabled']=='1')
 assert(messages[#messages]=='error')
end
reset();method='GET';assert(not mesh.handle_card_toggle() and exited==nil and applies==0)
reset();args.fromModal='YES';assert(not mesh.handle_card_toggle() and exited==nil)
reset();args.easyMeshCardEnable=nil;assert(not mesh.handle_card_toggle() and exited==nil)
'''
        self.run_lua(script)


if __name__ == '__main__':
    unittest.main()
