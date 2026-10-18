from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('luajit') or shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua required')
class MeshRadios(unittest.TestCase):
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
