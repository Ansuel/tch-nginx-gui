from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('luajit') or shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua required')
class GponDiagnostics(unittest.TestCase):
    def test_network_reset_applies_once_and_keeps_integrated_gpon_read_only(self):
        source = (ROOT / 'www/docroot/modals/diagnostics-network-modal.lp').read_text()
        reset = source[source.index('local function statsPath'):source.index('local param = {"rx_bytes"')]
        result = subprocess.run([LUA, '-'], input=r'''
local ports = {'eth0', 'gpon', 'wl0'}
local match = string.match
local function run(integrated_gpon, args, expected)
  local remaining, applies = {}, 0
  for _, path in ipairs(expected) do remaining[path] = true end
  local ngx = {var={request_method='POST'}, req={get_post_args=function() return args end}}
  local proxy = {
    set=function(path, value)
      assert(value == '1' and remaining[path], path)
      remaining[path] = nil
      return true
    end,
    apply=function() applies = applies + 1 end,
  }
''' + reset + r'''
  assert(next(remaining) == nil and applies == (#expected > 0 and 1 or 0))
end
local eth = 'sys.class.net.@eth0.statistics.reset'
local wifi = 'rpc.wireless.ssid.@wl0.stats.reset'
local sfp = 'rpc.optical.Interface.1.Stats.reset'
run(true, {stats_reset='RESET'}, {eth, wifi})
run(false, {action='resetall'}, {eth, wifi, sfp})
run(true, {action='gpon'}, {})
run(false, {action='gpon'}, {sfp})
''', text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_optional_ubus_and_fresh_fec_driver_counters(self):
        result = subprocess.run([LUA, '-', str(ROOT)], input=r'''
local root = arg[1] .. '/usr/share/transformer/mappings/rpc/'
local board, reply, reads = 'gpon', nil, 0
local registered = {}
function register(mapping) registered[mapping.objectType.name] = mapping end
function mapper() return {connect=function()
  return {call=function() return reply end}
end} end
package.preload['transformer.shared.optical'] = function()
  return {getBoardtype=function() return board end}
end
package.preload['transformer.logger'] = function() return {error=function() end} end
io.open = function(path) assert(path == '/bin/gponctl'); return {close=function() end} end
package.preload.modgui = function() return {popen=function(command)
  assert(command == '/bin/gponctl getGtcCounters')
  reads = reads+1
  local output = {'BIP error: ' .. reads, 'FEC corrected codewords: 28', 'FEC correction seconds: invalid'}
  local index = 0
  return {lines=function() return function() index = index+1; return output[index] end end,
    close=function() end}
end} end
dofile(root .. 'gpon.stat.gtc.map')
local fec = registered['rpc.gpon.stat.gtc.fec.']
assert(reads == 0)
local counters = fec.getall(fec)
assert(reads == 1 and counters.BIP_error == '1' and counters.FEC_corrected_codewords == '28')
assert(counters.FEC_correction_seconds == nil)
assert(fec.get(fec, 'BIP_error') == '2')
reply = {fec={['BIP error']=14}}
assert(fec.get(fec, 'BIP_error') == '14' and reads == 2)
board, reply = 'gpon_sfp', {}
dofile(root .. 'gpon.stat.gtc.map')
fec = registered['rpc.gpon.stat.gtc.fec.']
assert(next(fec.getall(fec)) == nil and reads == 2)
dofile(root .. 'gpon.trsv.info.map')
local status = registered['rpc.gpon.trsv.info.status.']
assert(status.get(status, 'DS_Rx_RSSI') == '')
assert(next(status.getall(status)) == nil)
''', text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
