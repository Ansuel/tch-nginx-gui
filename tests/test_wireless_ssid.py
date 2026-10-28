"""Exercise wireless card recovery without restarting the Lua worker."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'


class WirelessSSID(unittest.TestCase):
    def test_radio_band_recovers_after_failed_or_empty_read(self):
        source = ROOT / 'www/lua/wirelessSSID_helper.lua'
        for lua in filter(None, (shutil.which('lua'), shutil.which('luajit'))):
            with self.subTest(runtime=lua):
                script = r'''
local bands = {radio_2G = '2.4GHz'}
local reads, missing, failure = {}, false, nil
local interfaces = {
  wl0 = {radio = 'radio_2G', ssid = 'My WiFi'},
  wl1 = {radio = 'radio_5G', ssid = 'My WiFi'},
}
package.preload.datamodel = function() return {
  getPN = function()
    if missing then return nil end
    return {{path = 'rpc.wireless.ssid.@wl0.'},
            {path = 'rpc.wireless.ssid.@wl1.'}}
  end,
  get = function(path, ...)
    local radio = path:match('radio%.@([^%.]+)%.supported_frequency_bands$')
    if radio then
      reads[radio] = (reads[radio] or 0) + 1
      if bands[radio] == nil then return failure end
      return {{value = bands[radio]}}
    end
    local iface, param = path:match('ssid%.@([^%.]+)%.([^%.]+)$')
    if select('#', ...) > 0 then
      if missing then return nil end
      return {{value = interfaces[iface].radio},
              {value = interfaces[iface].ssid}, {value = '1'}}
    end
    return {{value = ''}}
  end,
} end
'''
                script += f'local helper = assert(loadfile({str(source)!r}))()\n'
                script += r'''
-- Keep using the same helper instance, as nginx does across requests.
for _, unavailable in ipairs({false, {}, {{value = ''}}}) do
  failure = unavailable or nil
  local networks = helper.getSSID()
  assert(#networks == 2 and networks[1].radio == '2.4GHz')
  assert(networks[2].radio == '' and networks[2].ssid == 'My WiFi')
end
bands.radio_5G = '5GHz'
local networks = helper.getSSID()
assert(networks[2].radio == '5GHz' and networks[2].ssid == 'My WiFi')
assert(reads.radio_2G == 1 and reads.radio_5G == 4)
helper.getSSID()
assert(reads.radio_5G == 4) -- Successful values still use the cache.
missing = true
assert(#helper.getSSID() == 0)
missing = false
assert(helper.getSSID()[2].radio == '5GHz')
'''
                result = subprocess.run([lua, '-'], input=script, text=True,
                                        capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        if not shutil.which('lua') and not shutil.which('luajit'):
            self.skipTest('Lua or LuaJIT required')


if __name__ == '__main__':
    unittest.main()
