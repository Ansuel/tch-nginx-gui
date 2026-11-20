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
for _, code in ipairs({"unauthorized", "offline", "no_device", "multiple_devices", "adb_missing", "adb_error", "usb_only", "adb_server_error", "telemetry_error", "telemetry_timeout", "helper_error"}) do
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

    def test_modal_hides_missing_telemetry_and_shows_diagnostic_status(self):
        self.run_lua(r'''
local output = {}
string.untaint = function(v) return v end
gettext = {textdomain = function() end}
ngx = {
    ctx = {session = {getCSRFtoken = function() return "fixture-token" end}},
    req = {get_method = function() return "GET" end}, HTTP_OK = 200,
    exit = function() end,
    print = function(...) for _, value in ipairs({...}) do output[#output+1] = value end end,
}
package.loaded.datamodel = {get = function() return {{value = [[
DEV|Example
HOST_IF|usb0
HOST_ADMIN|up
HOST_CARRIER|1
HOST_RNDIS|1
HOST_NCM_BLOCKED|1
UPLINK_PHONE_HEALTH|offline
NR_RSRP|N/A
ECI|0
]]}} end}
package.loaded["web.ui_helper"] = {
    createHeader = function() return "" end, createFooter = function() return "" end,
    createLabel = function(label, value) return label .. value end,
}
package.loaded["web.web"] = {html_escape = function(v) return v end}
package.loaded["web.lp"] = {}
package.loaded.dkjson = {}
assert(loadfile(arg[1] .. "/www/docroot/modals/smartphone-modal.lp"))()
local html = table.concat(output)
local function contains(markup) assert(html:find(markup, 1, true), markup) end
contains('<fieldset class="phone-stat-section" style="display:none"><legend>Batteria e Salute')
contains('<div class="phone-stat" style="display:none">5G NR SS-RSRP:<span id="live_nr_rsrp"></span>')
contains('ECI (LTE):<span id="live_eci">0</span>')
contains('class="icon-ok icon-large green"></i> <span id="host_link">Attivo</span>')
contains('class="icon-ban-circle icon-large red"></i> <span id="uplink-phone-health">Non raggiungibile</span>')
contains('<option value="ncm" disabled>')
contains('<p id="phone-usb-ncm-note">')
''')

    @unittest.skipUnless(shutil.which('node'), 'Node.js required')
    def test_modal_updates_rows_when_telemetry_changes(self):
        result = subprocess.run(['node', '-', str(APP / 'www/docroot/modals/smartphone-modal.lp')],
                                input=r'''
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.argv[2], 'utf8');
const script = source.slice(source.indexOf('    var statusIcons='), source.indexOf('    function update(){'));
const rows = new Map();
const context = vm.createContext({
    $: selector => {
        if (!rows.has(selector)) rows.set(selector, {});
        const row = rows.get(selector);
        return {
            closest: () => ({toggle: value => {row.visible = value;}}),
            text: value => {row.text = value;},
            siblings: () => ({attr: (_, value) => {row.icon = value;}}),
        };
    },
});
vm.runInContext(script, context);
context.showRow('nr_rsrp', context.withUnit('N/A', ' dBm'));
assert.deepEqual(rows.get('#nr_rsrp'), {text: '', visible: false});
context.showRow('nr_rsrp', context.withUnit('-83', ' dBm'));
assert.deepEqual(rows.get('#nr_rsrp'), {text: '-83 dBm', visible: true});
context.showRow('nr_rsrp', undefined);
assert.deepEqual(rows.get('#nr_rsrp'), {text: '', visible: false});
context.showHealth('phone', 'online');
assert.equal(rows.get('#phone').icon, 'icon-ok icon-large green');
context.showHealth('phone', 'offline');
assert.equal(rows.get('#phone').icon, 'icon-ban-circle icon-large red');
context.showHealth('phone');
assert.equal(rows.get('#phone').visible, false);
''', capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

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
