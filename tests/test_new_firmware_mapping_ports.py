"""Regression tests for behavior ported from newer gateway firmware."""
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1] / "decompressed/gui_file"
LUA = shutil.which("lua")


def source(path):
    return (ROOT / path).read_text()


def lua_function(text, signature):
    start = text.index(signature)
    end = text.index("\nend", start) + len("\nend")
    return text[start:end]


@unittest.skipUnless(LUA, "Lua interpreter required")
class NewFirmwareMappingPorts(unittest.TestCase):
    def run_lua(self, script):
        result = subprocess.run([LUA, "-"], input=script, text=True,
                                capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_transmit_power_is_bounded_and_validated(self):
        text = source("usr/lib/lua/transformer/shared/wifi.lua")
        get_power = lua_function(text, "function M.getTxPower")
        set_power = lua_function(text, "function M.setTxPower")
        self.run_lua("""
local M = {}
""" + get_power + "\n" + set_power + """
assert(M.getTxPower('15.0', '17.0') == 100)
assert(M.getTxPower('21.0', '21.0') == 100)
assert(M.getTxPower('0.0', '0.0') == '')
assert(M.setTxPower('15.0', '50') == -7)
local value, err = M.setTxPower('15.0', '55')
assert(value == nil and err:find('multiple of 10', 1, true))
value, err = M.setTxPower('15.0', 'not-a-number')
assert(value == nil and err ~= nil)
""")

    def test_upgrade_filename_uses_allowlist(self):
        text = source("usr/share/transformer/mappings/rpc/system.fwupgrade.map")
        start = text.index("filename = function(mapping, param, value)")
        end = text.index("\n  end,", start) + len("\n  end")
        setter = text[start + len("filename = "):end]
        self.run_lua("""
local fwupgrade_mapdata = {state = 'None'}
local function fwupgrade_reset() fwupgrade_mapdata = {state = 'None'} end
local setter = """ + setter + """
for _, value in ipairs({'bad>name', 'bad name', 'bad$name', 'bad\\name', "bad'name"}) do
  local ok, err = setter(nil, nil, value)
  assert(ok == nil and err ~= nil, value)
end
assert(setter(nil, nil, 'GUI_9.8-29.tar.bz2') == nil)
assert(fwupgrade_mapdata.filename == 'GUI_9.8-29.tar.bz2')
setter(nil, nil, '')
assert(fwupgrade_mapdata.filename == '')
""")

    def test_incomplete_port_forward_is_ignored(self):
        text = source("usr/share/transformer/mappings/rpc/network.firewall.portforward.map")
        delete_connection = lua_function(text, "local function deletePfwConnection")
        self.run_lua("""
local opened, written, notified = 0, nil, 0
local values = {src_dport = '8080', proto = '', dest_ip = '192.168.1.2'}
local mapping = {uciMap = {get = function(_, name) return values[name] end}}
local io = {open = function()
  opened = opened + 1
  return {write = function(_, value) written = value end, close = function() end}
end}
local commitapply = {newset = function() notified = notified + 1 end}
""" + delete_connection + """
deletePfwConnection(mapping, 'rule')
assert(opened == 0 and notified == 0)
values.proto = {'tcp'}
deletePfwConnection(mapping, 'rule')
assert(opened == 1 and written == '8080 tcp 192.168.1.2' and notified == 1)
""")

    def test_tcpdump_handles_empty_statvfs_result(self):
        text = source("usr/share/transformer/mappings/rpc/system.tcpdump.map")
        get_refcount = lua_function(text, "local function getrefcountusb")
        self.run_lua("""
local tcpdump_info = {refcountusb = '0'}
local function getUSBStatus() return 'Connected' end
local function getDirName() return '/mnt/usb' end
local posix = {statvfs = function() return nil end}
""" + get_refcount + """
assert(getrefcountusb() == '0')
posix.statvfs = function() return {f_bsize = 1024, f_bfree = 200} end
assert(getrefcountusb() == '100')
""")

    def test_optional_conntrack_helper_is_guarded(self):
        text = source("usr/share/transformer/commitapply/uci_firewall.ca")
        self.assertIn("[ -x /usr/bin/remove_conntrack.sh ] &&", text)


if __name__ == "__main__":
    unittest.main()
