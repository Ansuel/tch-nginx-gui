"""Render live extension cards and check their shared polling clients."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
CARDS = ROOT / 'decompressed/gui_file/www/cards'


class ExtensionCards(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node.js required')
    def test_polling_lifecycle(self):
        result = subprocess.run(['node', 'tests/test_extension_cards.js'], cwd=ROOT,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(shutil.which('lua'), 'Lua required')
    def test_server_snapshots_and_access(self):
        for name, filename, connected, stopped in [
            ('tailscale', '016_tailscale.lp', 'Tailscale connected', 'Tailscale disconnected'),
            ('wireguard', '016_wireguard.lp', 'Peers connected', 'Tunnel disabled'),
            ('openvpn', '015_openvpn-server.lp', 'OpenVPN server enabled', 'OpenVPN server disabled'),
        ]:
            for enabled in ('0', '1'):
                for access in ('yes', 'no'):
                    with self.subTest(name=name, enabled=enabled, access=access):
                        result = subprocess.run(['lua', '-', str(CARDS / filename), name, enabled, access,
                                                 connected if enabled == '1' else stopped], input=r'''
local output = {}
T = function(value) return value end
N = function(single, plural, count) return count == 1 and single or plural end
gettext = {textdomain = function() end}
string.untaint = function(value) return value end
ngx = {ctx = {session = {hasAccess = function() return arg[4] == "yes" end}},
 print = function(...) for _, value in ipairs({...}) do output[#output + 1] = tostring(value) end end}
package.preload["web.ui_helper"] = function() return {
 createCardHeader = function(title) return title end,
 createSimpleLight = function(_, text) return '<span><i class="light"></i>' .. text .. '</span>' end
} end
package.preload["web.content_helper"] = function() return {getExactContent = function(content)
 for key in pairs(content) do content[key] = "" end
 content.enabled = arg[3]; content.client_enabled = "0"; content.connected_clients = "2"
end} end
io.popen = function(command)
 assert(command:find(arg[2], 1, true))
 local lines = arg[3] == "1" and {'online=true', 'running=true', 'live=2', 'peers=3', 'ip=<unsafe>&'} or {}
 local i = 0
 return {lines = function() return function() i = i + 1; return lines[i] end end, close = function() end}
end
assert(loadfile(arg[1]))()
local html = table.concat(output)
assert(html:find('id="' .. arg[2] .. '-card"', 1, true))
assert(html:find(arg[5], 1, true))
assert(not html:find('<unsafe>', 1, true))
if arg[2] ~= "openvpn" and arg[3] == "1" then assert(html:find('&lt;unsafe&gt;&amp;', 1, true)) end
assert((html:find('new modgui.createAjaxUpdateCard(', 1, true) ~= nil) == (arg[4] == "yes"))
''', text=True, capture_output=True, timeout=5)
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
