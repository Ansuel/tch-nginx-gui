"""Test the privileged Android RPC and voice form with the real form framework."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / 'decompressed/gui_file'
PHONE = ROOT / 'decompressed/smartphone'
LUA = shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua interpreter required')
class SmartphoneVoiceTest(unittest.TestCase):
    def run_lua(self, source, *args):
        result = subprocess.run([LUA, '-', str(GUI), *args], input=source,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_distributed_modals_compile_and_have_access_rules(self):
        self.assertTrue((PHONE / 'usr/bin/phone_stats.sh').stat().st_mode & 0o111)
        self.assertIn('"smartphone"', (ROOT / 'inizialize_gui.sh').read_text())
        rules = (GUI / 'tmp/web_unlock').read_text()
        self.assertNotIn('/modals/smartphone-modal.lp', rules)
        self.assertNotIn('smartphone-modal.lp', (GUI / 'www/snippets/tabs-mobiled.lp').read_text())
        self.assertIn('/modals/mmpbx-advanced-modal.lp', rules)
        self.assertIn("list rules 'mmpbxadvancedmodal'", rules)
        self.assertIn('mmpbx-advanced-modal.lp', (GUI / 'www/snippets/tabs-voice.lp').read_text())
        for module, page in (('gui_file', 'mmpbx-advanced-modal.lp'), ('smartphone', 'smartphone-modal.lp')):
            self.run_lua('assert(loadfile(arg[1] .. "/../" .. arg[2] .. "/www/docroot/modals/" .. arg[3]))', module, page)

    def test_voice_field_paths_exist_in_installed_mapping_schemas(self):
        self.run_lua(r'''
local root, schemas = arg[1], {}
mapper = function()
    return {
        registerConfigMap = function() end,
        registerNamedMultiMap = function(m)
            schemas["uci." .. m.config .. "." .. m.type .. ".@"] = m.options
        end,
        registerSimpleMap = function(m)
            schemas["uci." .. m.config .. "." .. m.section .. "."] = m.options
        end,
    }
end
for _, name in ipairs({"mmpbx", "mmpbxrvsipnet", "mmpbxbrcmcountry", "mmpbxbrcmfxsdev"}) do
    dofile(root .. "/usr/share/transformer/mappings/uci/" .. name .. ".map")
end
local file = assert(io.open(root .. "/www/docroot/modals/mmpbx-advanced-modal.lp"))
local text = file:read("*a"); file:close()
for path in text:gmatch('path = "([^"]+)"') do
    local prefix, option = path:match("^(.*%.)([^.]+)$")
    prefix = prefix:gsub("@[^.]+%.$", "@")
    local options = assert(schemas[prefix], path)
    local found = false
    for _, name in ipairs(options) do if name == option then found = true end end
    assert(found, path)
end
''')

    def test_rpc_allowlist_and_helper_error_propagation(self):
        self.run_lua(r'''
local mapping, commands, response = nil, {}, "SUCCESS|done\n\nEXIT_STATUS|0\n"
register = function(value) mapping = value end
io.popen = function(command)
    commands[#commands + 1] = command
    return {read = function() return response end, close = function() end}
end
dofile(arg[1] .. "/../smartphone/usr/share/transformer/mappings/rpc/smartphone.map")
assert(mapping.set.action(nil, nil, "start_vpn"))
assert(commands[1]:find("phone_stats.sh start_vpn", 1, true))
local before = #commands
assert(not mapping.set.action(nil, nil, "start_vpn; reboot"))
assert(not mapping.set.action(nil, nil, "get_stats"))
assert(#commands == before)
response = "ERROR|Android root denied\n\nEXIT_STATUS|1\n"
local ok, err = mapping.set.action(nil, nil, "stop_vpn")
assert(not ok and err == "Android root denied")
assert(mapping.get.stats():find("ERROR|Android root denied", 1, true))
response = "\nEXIT_STATUS|124\n"
assert(not mapping.set.action(nil, nil, "screen"))
''')

    def test_voice_save_empty_values_validation_and_backend_failures(self):
        for mode in ('save', 'invalid', 'set_failure', 'apply_failure'):
            with self.subTest(mode=mode):
                self.run_lua(r'''
local root, mode = arg[1], arg[2]
package.path = root .. "/usr/lib/lua/?.lua;" .. package.path
unpack = unpack or table.unpack
string.untaint = function(value) return value end
string.istainted = function() return false end
T = function(value) return value end
gettext = {textdomain = function() end}
local messages, writes, applies = {}, {}, 0
local post = {action = "SAVE", nat_keepalive_method = "", stun_server = "", user_agent = "", wl0_number = ""}
if mode == "invalid" then post.user_agent = "bad\nvalue" end
ngx = {var = {uri = "/modals/mmpbx-advanced-modal.lp", request_method = "POST",
    content_type = "application/x-www-form-urlencoded"}, header = {},
    ctx = {session = {retrieve = function() return messages end}},
    req = {get_post_args = function() return post end}, log = function() end}
local function value(path)
    if path:find("ring_voltage", 1, true) then return nil end
    if path:find("nat_keepalive_method", 1, true) then return "options" end
    if path:find("dtmf_relay", 1, true) then return "rfc2833" end
    if path:find("fax_transport", 1, true) then return "t38" end
    if path:find("eon", 1, true) then return "#" end
    if path:find("stun_server", 1, true) then return "stun.example.org" end
    if path:find("user_agent", 1, true) then return "Old Agent" end
    if path:find("destination", 1, true) then return "123" end
    if path:find("areacode", 1, true) then return "1" end
    if path:find("powerring_frequency", 1, true) then return "20" end
    return "1"
end
local proxy = {
 get = function(...)
    local results = {}
    for _, path in ipairs({...}) do
        local v = value(path)
        if v == nil then return nil end
        local prefix, param = path:match("^(.*%.)([^.]+)$")
        if not prefix then return nil, "invalid path" end
        results[#results + 1] = {path = prefix, param = param, value = v}
    end
    return results
 end,
 set = function(values)
    writes[#writes + 1] = values
    if mode == "set_failure" then return nil, {{path="test", errcode=1, errmsg="denied"}} end
    return true
 end,
 apply = function()
    applies = applies + 1
    if mode == "apply_failure" then return nil, "denied" end
    return true
 end,
}
package.preload.datamodel = function() return proxy end
package.preload.bit = function() return {} end
package.preload["tch.inet"] = function() return {} end
package.preload["tch.posix"] = function() return {} end
package.preload["web.taint"] = function() return {untaint_mt = {}} end
local translations = {gettext = T, ngettext = T, language = function() end, textdomain = function() end}
package.preload["web.intl"] = function() return {load_gettext = function() return translations end} end
package.preload["web.ui_helper"] = function() return {} end
package.preload["web.post_helper"] = function()
    local file = assert(io.open(root .. "/usr/lib/lua/web/post_helper.lua"))
    local source = file:read("*a"); file:close()
    -- Lua 5.1 silently accepts these old escapes; newer host Lua rejects them.
    source = source:gsub("\\%-", "-")
    return assert((loadstring or load)(source))()
end
package.preload["web.uimessage_helper"] = function()
    return {pushMessage = function(text, level) messages[#messages + 1] = {text=text, level=level} end}
end
os.execute = function() error("web form must not execute shell commands") end
io.popen = function() error("web form must not execute shell commands") end
local f = assert(io.open(root .. "/www/docroot/modals/mmpbx-advanced-modal.lp"))
local template = f:read("*a"); f:close()
local code = assert(template:match("^(.-)%-%- Render the controls"))
assert((loadstring or load)(code))()
if mode == "invalid" then
    assert(#writes == 0 and applies == 0)
    assert(messages[#messages].level == "error")
else
    assert(#writes == 1)
    assert(writes[1]["uci.mmpbxrvsipnet.network.@sip_net.nat_keepalive_method"] == "")
    assert(writes[1]["uci.mmpbxrvsipnet.network.@sip_net.stun_server"] == "")
    assert(writes[1]["uci.mmpbxrvsipnet.network.@sip_net.user_agent"] == "")
    assert(writes[1]["uci.mmpbx.service.@WARMLINE_0.destination"] == "")
    assert(not writes[1]["uci.mmpbxbrcmcountry.global_provision.ring_voltage"])
    if mode == "set_failure" then assert(applies == 0) else assert(applies == 1) end
    assert(messages[#messages].level == (mode == "save" and "success" or "error"))
end
''', mode)


if __name__ == '__main__':
    unittest.main()
