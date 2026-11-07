"""Render the actual wireless card with more than the four stock SSIDs."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
LUA = shutil.which('luajit') or shutil.which('lua')
CARD = ROOT / 'decompressed/gui_file/www/cards/004_wireless.lp'


@unittest.skipUnless(LUA, 'Lua runtime required')
class WirelessCard(unittest.TestCase):
    def test_every_ssid_has_its_own_label_band_and_state(self):
        source = r'''
gettext={textdomain=function() end}
T=function(value) return value end
ngx={ctx={session={hasAccess=function() return true end}},print=function() end}
package.loaded.datamodel={}
local networks,rows={},{}
package.loaded.wirelessSSID_helper={getSSID=function() return networks end}
package.loaded['web.ui_helper']={
 createCardHeader=function() return '' end,
 createSimpleLight=function(state,label)
  rows[#rows+1]={state=state,label=label}; return ''
 end
}
wifi_text='must not be overwritten'
for _,count in ipairs({0,1,4,5,8}) do
 networks={}; rows={}
 for i=1,count do
  networks[i]={ssid='Network-'..i,radio=i%2==0 and '5GHz' or '2.4GHz',state=i%2==0 and '0' or '1'}
 end
 assert(loadfile(CARD))()
 assert(#rows==count)
 for i,network in ipairs(networks) do
  assert(rows[i].label=='<strong>'..network.ssid..'</strong>('..network.radio..')')
  assert(rows[i].state==network.state)
 end
 assert(wifi_text=='must not be overwritten')
end
'''
        result = subprocess.run([LUA, '-'], input='local CARD=' + repr(str(CARD)) + '\n' + source,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
