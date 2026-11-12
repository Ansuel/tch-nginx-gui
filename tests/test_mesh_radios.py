from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('luajit') or shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua required')
class MeshRadios(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node required')
    def test_native_javascript_preserves_hidden_roles_and_uses_gui_confirmation(self):
        script = r'''
const assert = require('assert'), fs = require('fs'), vm = require('vm');
const source = fs.readFileSync('decompressed/gui_file/www/docroot/js/easymesh-configuration-modal-newEM.js','utf8');
const start = source.indexOf('if ($("#easyMeshAgent").length)');
const end = source.indexOf('if (($("#easyMeshAgent").val()',start);
assert(start > 0 && end > start);
let agent, controller, writes = [];
const init = {$: selector => ({length: (selector.includes('Agent') ? agent : controller) !== undefined,
  val: () => selector.includes('Agent') ? agent : controller}),
  enableParams: id => writes.push([id,'1']), disableParams: id => writes.push([id,'0'])};
vm.runInNewContext(source.slice(start,end),init);
assert.deepStrictEqual(writes,[]); // Combined admin switch has no individual controls.
agent='1'; controller='0';
vm.runInNewContext(source.slice(start,end),init);
assert.deepStrictEqual(writes,[['agentEnable','1'],['controllerEnable','0']]);
let handler, confirmHandler, popup = 0, enabled = 0, disabled = 0, current='0';
const clicked = {};
const ctx = {confirmPopup:true, easyMeshDisableMessage:'Disable', disableTitle:'Disable',
  easyMeshEnableMessage:'Enable',enableTitle:'Enable',
  confirmationDialogue: () => popup++, easyMeshEnable: () => enabled++, easyMeshDisable: () => disabled++,
  $: selector => {
    if(selector === '.switch') return {click: fn => handler=fn};
    if(selector === clicked) return {find: name => ({length:name==='#easyMeshEnable'?1:0})};
    if(selector === '#easyMeshEnable') return {val:()=>current};
    if(selector === '#ok') return {one:(event,fn)=>{assert.strictEqual(event,'click');confirmHandler=fn;}};
    throw Error('Unexpected selector '+selector);
  }};
const clickStart=source.indexOf('//EasyMesh Agent and Controller Services click function');
const clickEnd=source.indexOf('//On change of frequency band checkboxes',clickStart);
vm.runInNewContext(source.slice(clickStart,clickEnd),ctx);
handler.call(clicked); assert.strictEqual(popup,1); assert.strictEqual(enabled,0);
confirmHandler(); assert.strictEqual(enabled,1);
current='1'; handler.call(clicked); confirmHandler(); assert.strictEqual(disabled,1);
console.log('Native newEM roles and GUI confirmation integration OK');
'''
        result = subprocess.run(['node', '-e', script], cwd=ROOT.parents[1],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_original_newem_pages_render_for_admin_and_engineer(self):
        script = r'''
string.untaint = function(s) return s end
T = function(s) return s end
gettext = {textdomain = function() end}
local role, enabled, output = 'admin', '0', {}
local variants = {ExtenderPage = {extenderConfig = {
  showEMConfigPage = {value=true}, extenderInfo = {value=true}, backhaulConfig = {value=true},
}}, Wireless = {wireless = {}}}
package.preload.variant_helper = function() return variants end
local function value(path)
  if path:match('%.enabled$') then return enabled end
  if path:match('supported_security_modes$') then return 'wpa2-psk wpa3-psk' end
  if path:match('frequency_bands$') then return 'radio_2G' end
  if path:match('security_mode$') then return 'wpa2-psk' end
  if path:match('hostname$') then return 'Gateway' end
  if path:match('NumberOfEntries$') then return '0' end
  return ''
end
local proxy = {
  get = function(path)
    if path == 'uci.multiap.controller_credentials.' then
      return {{paramindex='@cred2', backhaul='1', fronthaul='0'}}
    end
    if path:sub(-1) == '.' then return {} end
    return {{value=value(path)}}
  end,
  getPN = function() return {} end,
  set = function() error('GET must not write configuration') end,
}
package.preload.datamodel = function() return proxy end
package.preload['web.content_helper'] = function() return {
  convertResultToObject = function(_, data) return data end,
  getExactContent = function(map) for key,path in pairs(map) do map[key]=value(path) end end,
  loadTableData = function() return {},{} end,
} end
local function valid() return true end
local post = {
  getVariant = function(v, section, page) return v[section] and v[section][page] end,
  getVariantValue = function(v, key) return v and v[key] and v[key].value or false end,
  isFeatureEnabled = function() return false end,
  validatePSK = valid, validateBoolean = valid, validateNonEmptyString = valid,
  getAndValidation = function() return valid end,
  getValidateStringLengthInRange = function() return valid end,
  getValidationIfPropInList = function() return valid end,
  getValidateInEnumSelect = function() return valid end,
  handleQuery = function(map)
    local params = {}; for key,path in pairs(map) do params[key]=value(path) end
    return params,{}
  end,
  handleTableQuery = function() return {},{} end,
}
package.preload['web.post_helper'] = function() return post end
package.preload['web.ui_helper'] = function() return setmetatable({}, {
  __index = function() return function() return '' end end,
}) end
package.preload['web.uimessage_helper'] = function() return {popMessages=function() return {} end} end
package.preload['web.web'] = function() return {html_escape=function(s) return s end} end
package.preload['web.lp'] = function() return {setpath=function() end, include=function() end} end
package.preload.dkjson = function() return {encode=function() return '{}' end} end
package.preload.easymesh_helper = function() return {
  is_supported=function() return true end, use_new_layout=function() return true end,
  handle_card_toggle=function() return false end,
} end
local function emit(v)
  if type(v)=='table' then for _,item in ipairs(v) do emit(item) end
  else output[#output+1]=tostring(v) end
end
ngx = {ctx={session={getrole=function() return role end}}, var={request_method='GET'},
  req={get_uri_args=function() return {} end, get_method=function() return 'GET' end},
  print=function(...) for i=1,select('#',...) do emit(select(i,...)) end end}
'''
        script += f'local root = {str(ROOT)!r}\n'
        script += r'''
for _, current_role in ipairs({'admin','engineer'}) do
  role = current_role
  for _, state in ipairs({'0','1'}) do
    enabled = state
    for _, name in ipairs({'configuration','topology','devices-info'}) do
      output = {}
      assert(loadfile(root .. '/www/docroot/modals/easymesh-' .. name .. '-modal-newEM.lp'))()
      assert(#table.concat(output) > 100, name)
    end
  end
end
'''
        for runtime in filter(None, (shutil.which('lua'), shutil.which('luajit'))):
            with self.subTest(runtime=runtime):
                result = subprocess.run([runtime, '-'], input=script, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_newem_selection_uses_native_flag_and_keeps_legacy_fallback(self):
        script = r'''
local layout, variants = '0', {ExtenderPage = {extenderConfig = {showEMConfigPage = {value = true}}}}
package.preload.uci = function() return {cursor = function() return {
  get = function(_, config, section, option)
    assert(config == 'env' and section == 'var' and option == 'em_new_ui_layout')
    return layout
  end, unload = function() end,
} end} end
package.preload.variant_helper = function() return variants end
'''
        script += f'local mesh = assert(loadfile({str(ROOT / "www/lua/easymesh_helper.lua")!r}))()\n'
        script += r'''
assert(not mesh.use_new_layout())
layout = '1'; assert(mesh.use_new_layout())
variants.ExtenderPage = nil; assert(not mesh.use_new_layout())
variants.ExtenderPage = {extenderConfig = {}}; assert(not mesh.use_new_layout())
package.loaded.variant_helper = nil
package.preload.variant_helper = function() error('not provided by legacy firmware') end
assert(not mesh.use_new_layout())
'''
        result = subprocess.run([LUA, '-'], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_native_formatters_and_progress_widgets(self):
        post = (ROOT / 'usr/lib/lua/web/post_helper.lua').read_text()
        ui = (ROOT / 'usr/lib/lua/web/ui_helper.lua').read_text()
        formatters = post[post.index('--function to convert tx/rx rate'):post.rindex('return M')]
        start = ui.index('function createProgressBar(')
        progress = ui[start:ui.index('\nend', start) + 4]
        script = 'local M, format, find = {}, string.format, string.find\n' + formatters + '\n' + progress
        script += r'''
assert(M.convertData('2000') == '2.00 KB')
assert(M.convertData('2000000') == '2.00 MB')
assert(M.convertPhyRate('866', true) == '866 Mbps')
assert(M.convertPhyRate('866000', false) == '866.00 Mbps')
assert(M.convertData('invalid') == nil)
assert(#createProgressBar(nil) == 0)
assert(table.concat(createProgressBar('controller')):find('id=controller7', 1, true))
assert(table.concat(createProgressBar('agent')):find('id=agent6', 1, true))
'''
        result = subprocess.run([LUA, '-'], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_saved_combinations_survive_temporarily_missing_radios(self):
        source = (ROOT / 'www/docroot/modals/easy-mesh-configuration.lp').read_text()
        block = source[source.index('  local known_frequencies = {}'):source.index('  local credParamIndex, ap')]
        script = r'''
local preferredInterface = {{'radio_2G', '2.4GHz'}}
local getCredentials = {{frequency_bands = 'radio_2G,radio_6G'},
  {frequency_bands = 'radio_2G,radio_6G'}, {frequency_bands = 'radio_2G'},
  {frequency_bands = '../invalid'}, {}}
string.untaint = string.untaint or function(s) return s end
T = function(s) return s end
''' + block + r'''
assert(#preferredInterface == 2)
assert(preferredInterface[2][1] == 'radio_2G,radio_6G')
assert(preferredInterface[2][2] == 'Current configuration')
'''
        result = subprocess.run([LUA, '-'], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_radio_choices_follow_discovered_hardware_and_tolerate_missing_paths(self):
        script = r'''
local names, bands = {}, {}
package.preload.uci = function() return {} end
package.preload.datamodel = function() return {
  getPN = function() return names end,
  get = function(path)
    local name = path:match('@([^%.]+)%.supported_frequency_bands$')
    if bands[name] == 'error' then error('unsupported path') end
    if bands[name] then return {{value = bands[name]}} end
  end,
} end
'''
        script += f'local mesh = assert(loadfile({str(ROOT / "www/lua/easymesh_helper.lua")!r}))()\n'
        script += r'''
assert(#mesh.get_frequency_options() == 0)
for _, name in ipairs({'radio_5Gl', 'radio_2G', 'radio_5Gu', 'radio_6G', 'radio_6G', 'unknown'}) do
  names[#names+1] = {path = 'rpc.wireless.radio.@' .. name .. '.'}
end
bands = {radio_2G = '2.4GHz', radio_5Gu = '5GHz', radio_5Gl = '5GHz', radio_6G = '6GHz', unknown = 'error'}
local choices = mesh.get_frequency_options()
assert(#choices == 4)
assert(choices[1][1] == 'radio_2G' and choices[1][2] == '2.4GHz')
assert(choices[2][1] == 'radio_5Gl,radio_5Gu' and choices[2][2] == '5GHz')
assert(choices[3][1] == 'radio_6G' and choices[3][2] == '6GHz')
assert(choices[4][1] == 'radio_2G,radio_5Gl,radio_5Gu,radio_6G')
names = {{path = 'rpc.wireless.radio.@radio_5G.'}}
bands = {radio_5G = '5GHz'}
choices = mesh.get_frequency_options()
assert(#choices == 1 and choices[1][1] == 'radio_5G')
bands = {}; assert(#mesh.get_frequency_options() == 0)
'''
        result = subprocess.run([LUA, '-'], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
