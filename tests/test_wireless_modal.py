"""Wireless modal regressions, based on AGTHF 1.3.6 radio values."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / 'decompressed/gui_file'
LUA = shutil.which('luajit') or shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua required')
class WirelessModal(unittest.TestCase):
    def run_radio(self, assertions):
        modal = (GUI / 'www/docroot/modals/wireless-modal.lp').read_text()
        choices = modal[modal.index('local wifi_standard_24GHz ='):modal.index('local supported_modes_data')]
        validator = modal[modal.index('local function getValidateChannelWidth'):modal.index('local function getValidateExtraSpaces')]
        post = (GUI / 'usr/lib/lua/web/post_helper.lua').read_text()
        enum = post[post.index('function M.getValidateInEnumSelect('):post.index('\n---', post.index('function M.getValidateInEnumSelect('))]
        normalization = modal[modal.index('if native_channelwidth and content['):modal.index('\nif ngx.req.get_method()', modal.index('if native_channelwidth and content['))]
        script = r'''
local M, untaint_mt = {}, {}
local T = function(s) return s end
local untaint = function(s) return s end
local format, match, gsub = string.format, string.match, string.gsub
local tinsert = table.insert
local function listboxToText(options, value)
  for _, option in ipairs(options) do
    if option[1] == value then return option[2] end
  end
  return value
end
local variantSetting
package.preload.variant_helper = function()
  if variantSetting == nil then error('legacy firmware: no variant helper') end
  return {Wireless = {wireless = {channelWithNo160MHz = {value = variantSetting}}}}
end
''' + enum + r'''
local gVIES = M.getValidateInEnumSelect
local function radio(supported, band, width, quantenna, no160)
  variantSetting = no160
  package.loaded.variant_helper = nil
  local curradio, isIntRemman = 'radio_5G', quantenna and '1' or '0'
  local radioData = {[curradio] = {supported_standards = supported,
    supported_frequency_bands = band, requested_channel_width = width}}
  local content_helper = {getExactContent = function(t) t.standard = 'anac' end}
''' + choices + validator + r'''
  local function normalize(standard, width)
    local content = {standard = standard, requested_channel_width = width}
''' + normalization + r'''
    return content.requested_channel_width
  end
  return {standards = wifi_standard, widths = channelwidth, controls = cw,
    validate = getValidateChannelWidth, lists = cwmaps, normalize = normalize,
    powers = wifipower}
end
local function has(choices, value)
  for _, option in ipairs(choices) do
    -- The rendered options must have actual labels, rather than nil text.
    assert(type(option[2]) == 'string')
    string.format('<option value=%q>%s</option>', option[1], option[2])
    if option[1] == value then return true end
  end
  return false
end
''' + assertions
        result = subprocess.run([LUA, '-'], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_agthf_main_and_guest_have_ax_labels_and_native_widths(self):
        self.run_radio(r'''
local r = radio('anacax', '5GHz', '20/40/80', false, true)
assert(has(r.standards, 'anacax'))
assert(has(r.standards, 'anac'))
assert(has(r.widths, '20/40/80')) -- Guest label also calls listboxToText on this list.
assert(not has(r.widths, 'auto')) -- AGTHF disables 160 MHz in variant_helper.
assert(not has(r.widths, '20MHz'))
assert(r.controls.anacax == 'channelwidth160')
assert(r.normalize('anacax', '20/40/80MHz') == '20/40/80')
assert(r.normalize('anacax', 'auto') == '20/40/80')
assert(r.normalize('anac', 'auto') == '20/40/80')
assert(r.normalize('an', 'auto') == 'auto')
for _, standard in ipairs({'nac', 'nacax', 'acax'}) do
  assert(has(r.standards, standard) and r.controls[standard])
end
''')

    def test_width_validation_rejects_invalid_values_and_ignores_hidden_controls(self):
        self.run_radio(r'''
local r = radio('anacax', '5GHz', '20/40/80', false, true)
local data = {standard = 'anacax', requested_channel_width = '20/40/80'}
local validate = r.validate(r.widths)
assert(validate('20/40', data, 'channelwidth160'))
assert(data.requested_channel_width == '20/40')
assert(not validate('160', data, 'channelwidth160'))
assert(not validate('auto', data, 'channelwidth160'))
assert(data.requested_channel_width == '20/40')
assert(r.validate(r.lists.channelwidth40)('auto', data, 'channelwidth40'))
assert(data.requested_channel_width == '20/40')
local unrestricted = radio('anacax', '5GHz', '20/40/80', false, false)
assert(has(unrestricted.widths, 'auto'))
assert(unrestricted.validate(unrestricted.widths)('auto', data, 'channelwidth160'))
assert(data.requested_channel_width == 'auto')
assert(unrestricted.normalize('anac', '20/40/80MHz') == 'auto')
assert(unrestricted.normalize('anacax', '20/40/80MHz') == '20/40/80')
''')

    def test_wifi6_24ghz_and_legacy_radios_keep_their_own_choices(self):
        self.run_radio(r'''
local r = radio('bgnax', '2.4GHz', 'auto', false, true)
assert(has(r.standards, 'bgnax') and not has(r.standards, 'bg'))
assert(r.controls.bgnax == 'channelwidth40')
assert(has(r.widths, '20') and has(r.widths, 'auto'))
assert(not has(r.widths, '20/40/80'))
local old = radio('bgn', '2.4GHz', '20MHz', false)
assert(has(old.standards, 'bg') and not has(old.standards, 'bgnax'))
assert(has(old.standards, 'n') and old.controls.n == 'channelwidth40')
local legacy5g = radio('anac', '5GHz', '20/40MHz', false)
for _, standard in ipairs({'nac', 'ac'}) do
  assert(has(legacy5g.standards, standard))
  assert(legacy5g.controls[standard] == 'channelwidth80')
  local posted = {standard = standard, requested_channel_width = 'auto'}
  assert(legacy5g.validate(legacy5g.widths)('20/40MHz', posted, 'channelwidth80'))
  assert(posted.requested_channel_width == '20/40MHz')
end
assert(has(old.widths, '20MHz') and not has(old.widths, '20'))
local qtn = radio('anac', '5GHz', '20/40MHz', true)
assert(has(qtn.standards, 'anac') and not has(qtn.standards, 'an'))
assert(has(qtn.widths, '20/40MHz') and not has(qtn.widths, '20/40'))
local native = radio('anac', '5GHz', '20/40', false)
assert(has(native.widths, '20/40') and not has(native.widths, '20/40MHz'))
''')

    def test_modal_compiles(self):
        path = GUI / 'www/docroot/modals/wireless-modal.lp'
        result = subprocess.run([LUA, '-e', f'assert(loadfile({str(path)!r}))'],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_power_preserves_native_zero_and_legacy_signed_values(self):
        self.run_radio(r'''
local powers = radio('anacax', '5GHz', '20/40/80', false, true).powers
-- A missing current value makes the browser select -6 and saves it with
-- unrelated Wi-Fi edits. Native and legacy firmware both return "0".
assert(has(powers, '0'))
assert(not has(powers, '+0'))
assert(has(powers, '-6') and has(powers, '+1') and has(powers, '+2'))
local validate = gVIES(powers)
assert(validate('0') and validate('+2') and validate('-3'))
''')


@unittest.skipUnless(LUA, 'Lua required')
class WirelessClientMonitor(unittest.TestCase):
    def test_ajax_clears_capabilities_when_monitored_client_disconnects(self):
        modal = GUI / 'www/docroot/modals/wireless-client-modal.lp'
        source = modal.read_text()
        ajax = source[source.index('local TIMERJS'):source.index('local args =')]
        script = r'''
local mac = '00:11:22:33:44:55'
local ap_path = 'rpc.wireless.ap.'
local station_path = ap_path .. '@ap0.station.'
local target = {paramindex = '@' .. mac, flags = 'active', rssi = '-45',
                capabilities = '802.11n', assoc_time = '60'}
local other = {paramindex = '@00:11:22:33:44:66', flags = 'active', rssi = '-50',
               capabilities = '802.11ac'}
local data = {[ap_path] = {{paramindex = '@ap0', ssid = 'wl0'}},
              [station_path] = {target, other}}
local ssid_reads = 0
local proxy = {get = function(path) return data[path] end}
local content_helper = {
  convertResultToObject = function(_, result) return result or {} end,
  getExactContent = function(content)
    ssid_reads = ssid_reads + 1
    assert(content.ssid == 'rpc.wireless.ssid.@wl0.ssid')
    content.ssid, content.radio = 'Test WiFi', 'radio_2G'
  end,
}
local match, format, floor = string.match, string.format, math.floor
local T = function(s) return s end
local ngx = {print = function(parts) print(table.concat(parts)) end}
''' + ajax + r'''
local requested = {untaint = function() return mac end}
AJAX(requested)
target.flags, target.rssi = '', '0'
AJAX(requested)
data[station_path] = {other}
AJAX(requested)
data[station_path] = {}
AJAX(requested)
target.flags, target.rssi, target.capabilities = 'active', '-42', '802.11ax'
data[station_path] = {target, other}
AJAX(requested)
assert(ssid_reads == 2)
'''
        result = subprocess.run([LUA, '-'], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        connected, stale, absent, empty, reconnected = map(json.loads, result.stdout.splitlines())
        self.assertEqual(connected['capabilities'], '802.11n')
        self.assertEqual(connected['ssid'], 'Test WiFi')
        self.assertEqual(connected['freq'], '2.4GHz')
        for response in (stale, absent, empty):
            self.assertEqual(response['capabilities'], '')
            self.assertEqual(response['ssid'], '')
            self.assertEqual(response['freq'], '')
            self.assertEqual(response['rssi'], '-100')
        self.assertEqual(reconnected['capabilities'], '802.11ax')


class ModalJavascript(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node required')
    def test_slider_and_failed_load_lifecycle(self):
        result = subprocess.run(['node', 'tests/test_modal_sliders.js'], cwd=ROOT,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
