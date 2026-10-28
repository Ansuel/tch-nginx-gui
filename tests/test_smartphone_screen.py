"""Check capability-driven controls and the authenticated, uncached PNG response."""
from pathlib import Path
import shutil
import subprocess
import unittest

APP = Path(__file__).resolve().parents[1] / 'decompressed/smartphone'
LUA = shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua interpreter required')
class SmartphoneScreenTest(unittest.TestCase):
    def test_connection_error_code_survives_rpc_and_modal_response(self):
        self.run_lua(r'''
local root = arg[1]
for _, code in ipairs({"unauthorized", "offline", "no_device", "multiple_devices", "adb_missing", "adb_error", "usb_only"}) do
    local registration
    register = function(mapping) registration = mapping end
    io.popen = function()
        return {read = function() return "ERROR|Connection problem\nERROR_CODE|" .. code .. "\nUSB_DEV|moto g32\nHOST_IF|usb0\nHOST_CARRIER|1\nEXIT_STATUS|1\n" end,
            close = function() end}
    end
    assert(loadfile(root .. "/usr/share/transformer/mappings/rpc/smartphone.map"))()
    local stats = registration.get.stats()
    assert(stats == "ERROR|Connection problem\nERROR_CODE|" .. code .. "\nUSB_DEV|moto g32\nHOST_IF|usb0\nHOST_CARRIER|1")
    local ok, err = registration.set.action(nil, nil, "reboot")
    assert(ok == nil and err == "Connection problem")
    string.untaint = function(v) return v end
    gettext = {textdomain = function() end}
    ngx = {ctx = {}, req = {get_method = function() return "POST" end,
        get_post_args = function() return {action = "get_stats"} end},
        header = {}, HTTP_OK = 200, print = function(v) assert(v == "encoded") end,
        exit = function(v) assert(v == 200) end}
    package.loaded.datamodel = {get = function() return {{value = stats}} end}
    package.loaded["web.ui_helper"] = {}
    package.loaded["web.lp"] = {}
    package.loaded.dkjson = {encode = function(data)
        assert(data.ERROR == "Connection problem" and data.ERROR_CODE == code and data.USB_DEV == "moto g32")
        assert(data.HOST_IF == "usb0" and data.HOST_CARRIER == "1")
        return "encoded"
    end}
    assert(loadfile(root .. "/www/docroot/modals/smartphone-modal.lp"))()
end
''')

    def run_lua(self, source, *args):
        result = subprocess.run([LUA, '-', str(APP), *args], input=source,
                                text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_root_only_buttons_are_absent_on_a_non_root_phone(self):
        for rooted in ('0', '1'):
            self.run_lua(r'''
local root, rooted = arg[1], arg[2]
local output = {}
string.untaint = function(v) return v end
gettext = {textdomain = function() end}
T = function(v) return v end
ngx = {ctx = {session = {getCSRFtoken = function() return "fixture-token" end}},
    req = {get_method = function() return "GET" end},
    HTTP_OK = 200, exit = function() end,
    print = function(...) for _, v in ipairs({...}) do output[#output+1] = v end end}
package.preload.datamodel = function()
    return {get = function()
        return {{value = "DEV|Example\nROOT_ACCESS|" .. rooted .. "\nTAILSCALE_CLI|0\nSCREEN_CAPTURE|1\n"}}
    end}
end
package.preload["web.ui_helper"] = function()
    return {createHeader = function() return "" end, createFooter = function() return "" end,
        createLabel = function(label, value) return label .. value end}
end
package.preload["web.web"] = function() return {html_escape = function(v) return v end} end
package.preload["web.lp"] = function() return {} end
package.preload.dkjson = function() return {} end
assert(loadfile(root .. "/www/docroot/modals/smartphone-modal.lp"))()
local html = table.concat(output)
local root_button = html:find('onclick="sendAdb(\'reconnect_data\')"', 1, true)
assert((root_button ~= nil) == (rooted == "1"))
assert((html:find('id="btn_vpn"', 1, true) ~= nil) == (rooted == "1"))
assert(not html:find('onclick="getPeers()"', 1, true))
assert(html:find('onclick="sendAdb(\'screen_wake\')"', 1, true))
assert(html:find('id="btn_screen_capture"', 1, true))
assert(not html:find('onclick="sendAdb(\'screen\')"', 1, true))
''', rooted)

    def test_image_endpoint_streams_png_without_caching_or_user_paths(self):
        for present in ('0', '1'):
            self.run_lua(r'''
local root, present = arg[1], arg[2] == "1"
local chunks, closed, status = {}, false, nil
local png = string.char(137) .. "PNG\r\n" .. string.char(26) .. "\nfixture"
io.open = function(path, mode)
    assert(path == "/var/run/modgui-smartphone-screen/frame.png" and mode == "rb")
    if not present then return nil end
    local read = false
    return {read = function(_, size)
        assert(size == 32768)
        if read then return nil end
        read = true; return png
    end, close = function() closed = true end}
end
ngx = {header = {}, HTTP_OK = 200, HTTP_NOT_FOUND = 404,
    print = function(chunk) chunks[#chunks+1] = chunk end,
    exit = function(code) status = code end}
assert(loadfile(root .. "/www/docroot/modals/smartphone-screen.lp"))()
assert(ngx.header["Cache-Control"] == "no-store, private")
assert(ngx.header["X-Content-Type-Options"] == "nosniff")
if present then
    assert(status == 200 and closed and table.concat(chunks) == png)
    assert(ngx.header.content_type == "image/png")
else
    assert(status == 404 and #chunks == 0)
end
''', present)


if __name__ == '__main__':
    unittest.main()
