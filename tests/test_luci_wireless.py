"""Exercise the native LuCI bridge without a router or real credentials."""
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "decompressed/luci_wireless/usr/lib/lua/luci/model/tch_wireless.lua"
INSTALLER = ROOT / "decompressed/luci_wireless/usr/share/transformer/scripts/configure_luci_wireless.lua"

FIXTURE = r'''
unpack = unpack or table.unpack
loadstring = loadstring or load
local b = dofile(BACKEND)
package.loaded["modgui.luci_qtn"] = nil
package.preload["modgui.luci_qtn"] = function() error("Remote adapter disabled in fixture") end
local config = {
  ["wifi-ap"] = {{[".name"]="ap0", iface="wl0", state="1", security_mode="wpa2-psk", bandsteer_id="off"}},
  ["wifi-bandsteer"] = {{state="0"}}
}
local cursor = {get=function() return nil end, foreach=function(self, _, kind, fn)
  for _, item in ipairs(config[kind] or {}) do fn(item) end
end}
local function bus(object)
  if object == "wireless.radio" then return {
    radio_2G={admin_state=1, oper_state=1, channel=1, channel_width="20MHz", band="2.4GHz",
      requested_channel="auto", requested_channel_width="auto", capabilities="802.11n 2x2 40MHz", allowed_channels="1 6 11"},
    radio_5G={admin_state=1, oper_state=1, channel=100, band="5GHz", requested_channel="auto",
      requested_channel_width="auto", capabilities="802.11ac 4x4 80MHz", allowed_channels="36 100"}
  } end
  if object == "wireless.ssid" then return {wl0={radio="radio_2G",ssid="Test",oper_state=1}} end
  if object == "wireless.accesspoint.station" then return {ap0={
    ["00:11:22:33:44:55"]={rssi=-60,rx_phy_rate=867000,tx_phy_rate=702000,password="MUST_NOT_ESCAPE"}
  }} end
end
local snapshot = assert(b.snapshot(cursor, bus))
local function data_for(s)
  local data = {}
  for id, field in pairs(b.fields(s)) do data[id] = field.value end
  return data
end
'''


@unittest.skipUnless(shutil.which("lua"), "Lua runtime required")
class LuciWireless(unittest.TestCase):
    def run_lua(self, code):
        source = "local BACKEND = " + repr(str(BACKEND)) + "\n" + FIXTURE + code
        result = subprocess.run(["lua", "-"], input=source, text=True,
                                capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_both_radios_and_sanitized_clients(self):
        self.run_lua('''
assert(#snapshot.radios == 2)
local n = snapshot.radios[1].networks[1]
assert(n.editable and #n.stations == 1)
assert(n.stations[1].signal == -60 and n.stations[1].rx == 867000)
assert(n.stations[1].password == nil)
assert(#snapshot.radios[2].widths == 4)
''')

    def test_backend_errors_are_distinct_from_no_clients(self):
        self.run_lua('''
local s = b.snapshot(cursor, function(obj)
  if obj == "wireless.accesspoint.station" then return {ap0={}} end
  return bus(obj)
end)
assert(#s.radios[1].networks[1].stations == 0)
assert(not s.radios[1].networks[1].station_error)
s = b.snapshot(cursor, function(obj)
  if obj == "wireless.accesspoint.station" then error("timeout") end
  return bus(obj)
end)
assert(s.radios[1].networks[1].station_error)
assert(not b.snapshot(cursor, function() return nil end))
''')

    def test_client_details_hosts_and_counters_are_whitelisted(self):
        self.run_lua('''
local function extended(obj,method,args)
 if obj=='hostmanager.device' then return {
  ['00:11:22:33:44:55']={hostname='Laptop',ipv4={ip0={address='192.0.2.5'}},ipv6={ip0={address='2001:db8::5'}},password='SECRET'}
 } end
 if obj=='wireless.accesspoint.station' then
  assert(not args.short)
  return {ap0={['00:11:22:33:44:55']={rssi=-60,rx_phy_rate=867000,tx_phy_rate=702000,
   assoc_time=90061,idle_time=0,rx_bytes=2048,tx_bytes='4096',rx_packets=10,tx_packets=0,
   rx_failures=-1,tx_failures='nan',flags='SGI 80MHz',capabilities='802.11ac 2x2',
   authentication='WPA2PSK',encryption='AES',password='SECRET',wpa_psk_key='SECRET'},
   ['00:11:22:33:44:66']={rssi=0,flags=''}}}
 end
 return bus(obj)
end
local s=assert(b.snapshot(cursor,extended)); local clients=s.radios[1].networks[1].stations
assert(#clients==1)
local client=clients[1]
assert(client.hostname=='Laptop' and client.ipv4[1]=='192.0.2.5' and client.ipv6[1]=='2001:db8::5')
assert(client.assoc_time==90061 and client.idle_time==0 and client.tx_packets==0)
assert(client.rx_bytes==2048 and client.tx_bytes==4096 and not client.rx_failures and not client.tx_failures)
assert(client.authentication=='WPA2PSK' and client.encryption=='AES')
assert(not client.password and not client.wpa_psk_key)
assert(b.format_bytes(2048)=='2.00 KiB' and b.format_bytes(0)=='0 B')
assert(b.format_duration(90061)=='1d 01:01:01' and b.format_duration(0)=='00:00:00')
assert(b.format_bytes(nil)=='?' and b.format_duration(nil)=='?')
''')

    def test_steering_blocks_paired_credentials(self):
        self.run_lua('''
config["wifi-bandsteer"][1].state = "1"
local s = assert(b.snapshot(cursor, bus))
assert(not b.fields(s).wl0_ssid and not b.fields(s).wl0_password)
config["wifi-bandsteer"][1].state = "0"
config["wifi-ap"][1].bandsteer_id = "bs0"
s = assert(b.snapshot(cursor, bus))
assert(not b.fields(s).wl0_ssid)
''')

    def test_noop_and_invalid_posts_never_write(self):
        self.run_lua('''
local proxy = {set=function() error("unexpected write") end}
local data = data_for(snapshot)
data.wl0_password = nil
assert(b.save(snapshot, data, proxy))
data.radio_2G_channel = "999"
assert(not b.save(snapshot, data, proxy))
data = data_for(snapshot); data.wl0_ssid = string.rep("x", 33)
assert(not b.save(snapshot, data, proxy))
data = data_for(snapshot); data.wl0_password = "short"
assert(not b.save(snapshot, data, proxy))
assert(not b.save(snapshot, {}, proxy))
''')

    def test_saved_password_is_read_only_in_edit_and_noop_preserves_it(self):
        self.run_lua('''
local value = "Fixture-only-password"
local proxy = {get=function() return {{value=value}} end,
  set=function() error("unexpected write") end}
assert(b.password("ap0", proxy) == value)
assert(not b.password("bad.path", proxy))
local data = data_for(snapshot); data.wl0_password = value
assert(b.save(snapshot, data, proxy))
local scoped, net = b.scope(snapshot, "wl0")
assert(scoped and net.id == "wl0" and #scoped.radios == 1)
assert(not b.scope(snapshot, "missing"))
''')

    def test_create_validation_slots_and_cleanup(self):
        self.run_lua('''
config["wifi-iface"] = {{[".name"]="wl0",device="radio_2G"}, {[".name"]="wl0_1",device="radio_2G"}}
config.interface = {{[".name"]="lan"}, {[".name"]="loopback"}}
cursor.get=function(self, _, id)
  if id == "wl0" or id == "wl0_1" or id == "ap0" then return "existing" end
end
local data = {radio="radio_2G",ssid="New network",network="lan",password="Fixture-only-password",enabled="0"}
local adds, writes, dels, applied = {}, {}, {}, 0
local proxy = {
 add=function(path,id) adds[#adds+1]=id; return id end,
 set=function(values) writes[#writes+1]=values; return true end,
 apply=function() applied=applied+1; return true end,
 del=function(path) dels[#dels+1]=path; return true end
}
assert(b.create(snapshot,data,cursor,proxy) == "wl0_2")
assert(adds[1] == "wl0_2" and adds[2] == "ap4")
assert(writes[1]["uci.wireless.wifi-ap.@ap4.security_mode"] == "wpa2-psk")
assert(writes[1]["uci.wireless.wifi-iface.@wl0_2.state"] == "0")
assert(applied == 1)
adds={}; data.password=""
assert(not b.create(snapshot,data,cursor,proxy)); assert(#adds == 0)
data.password="Fixture-only-password"; data.network="injected"
assert(not b.create(snapshot,data,cursor,proxy)); assert(#adds == 0)
data.network="lan"; proxy.set=function() error("failure") end
assert(not b.create(snapshot,data,cursor,proxy)); assert(#dels == 2)
assert(dels[1] == "uci.wireless.wifi-ap.@ap4.")
assert(dels[2] == "uci.wireless.wifi-iface.@wl0_2.")
snapshot.radios[1].type = "quantenna"
adds = {}; assert(not b.create(snapshot,data,cursor,proxy)); assert(#adds == 0)
snapshot.radios[1].type = "broadcom"
cursor.get=function() return "occupied" end
assert(not b.create(snapshot,data,cursor,proxy))
''')

    def test_remove_only_owned_networks(self):
        self.run_lua('''
local called = 0
local proxy={del=function() called=called+1; return true end,apply=function() return true end}
assert(not b.remove(snapshot,"wl0",proxy)); assert(called == 0)
snapshot.radios[1].networks[1].owned=true
assert(b.remove(snapshot,"wl0",proxy)); assert(called == 2)
''')

    def test_remote_adapter_uses_separate_settings(self):
        self.run_lua('''
local updated,created
local net={id="qtn_wifi2",ap="qtn_wifi2",qtn=true,owned=true,editable=true,enabled="0",ssid="New-5G",security="wpa2-psk",stations={}}
package.loaded["modgui.luci_qtn"]={
 available=function() return true end, primary_network=function() return "lan" end,
 list=function() return {} end, networks=function() return {net} end,
 password=function() return "Fixture-password" end,
 create=function(data) created=data; return "qtn_wifi2" end,
 start_job=function(data) created=data; return "fixture-job",nil,"pending" end,
 update=function(id,data) updated=data; return true,"Changes applied successfully" end
}
cursor.get=function(self,cfg,id,k)
 if cfg=="wireless" and id=="radio_5G" and k=="type" then return "quantenna" end
end
config.interface={{[".name"]="lan"}}
local s=assert(b.snapshot(cursor,bus))
local scoped=assert(b.scope(s,"qtn_wifi2"))
assert(b.password("qtn_wifi2")=="Fixture-password")
local data=data_for(scoped); data.qtn_wifi2_ssid="Changed-5G"
assert(b.save(scoped,data,{set=function() error("Unexpected native AP write") end}))
assert(updated.ssid=="Changed-5G")
assert(b.create(s,{radio="radio_5G",ssid="Extra-5G",network="lan",password="Fixture-password",enabled="0"},cursor)=="qtn_wifi2")
assert(created.network=="lan")
local token,_,pending=b.create(s,{radio="radio_5G",ssid="Extra-5G",network="lan",password="Fixture-password",enabled="0"},cursor,nil,true)
assert(token=="fixture-job" and pending=="pending")
''')

    def test_job_status_returns_json_without_rendering_a_form(self):
        self.run_lua('''
b.supported=function() return true end
local result
package.loaded['luci.dispatcher']={form=function() return {target=function() error('Form must not render for JSON') end} end}
package.loaded['luci.http']={formvalue=function() return '1' end,header=function() end,
 prepare_content=function(t) assert(t=='application/json') end,write_json=function(data) result=data end}
package.loaded['modgui.luci_qtn']={job_status=function() return {state='done',id='qtn_wifi2'} end}
local action=b.target({}); action:target('pending',string.rep('a',32))
assert(result.state=='done' and result.id=='qtn_wifi2')
''')

    def test_native_paths_apply_once_and_recover_failures(self):
        self.run_lua('''
local path = "rpc.wireless.ssid.@wl0.ssid"
local data = data_for(snapshot); data.wl0_ssid = "Changed"
data["rpc.system.reboot"] = "1"
local writes, applies = {}, 0
local proxy = {
  get=function(p) assert(p == path); return {{value="Test"}} end,
  set=function(values) writes[#writes+1]=values; return true end,
  apply=function() applies=applies+1; return true end
}
assert(b.save(snapshot, data, proxy))
assert(#writes == 1 and writes[1][path] == "Changed" and applies == 1)
assert(not writes[1]["rpc.system.reboot"])
writes = {}; applies = 0
proxy.apply=function() applies=applies+1; return applies > 1 end
local ok, err = b.save(snapshot, data, proxy)
assert(not ok and err:find("restored"))
assert(#writes == 2 and writes[2][path] == "Test")
writes = {}; applies = 0
proxy.apply=function() applies=applies+1; if applies == 1 then error("timeout") end; return true end
assert(not b.save(snapshot, data, proxy))
assert(#writes == 2 and writes[2][path] == "Test")
proxy.get=function() error("timeout") end
writes = {}; assert(not b.save(snapshot, data, proxy)); assert(#writes == 0)
''')

    def test_installer_is_idempotent_and_retains_other_pages(self):
        # Simulate the target filesystem; the Lua patcher never touches the host.
        code = '''
local path = "/usr/lib/lua/luci/controller/admin/network.lua"
local files = {[path] = [[
e=entry({"admin","network","wireless"},arcombine(cbi("admin_network/wifi_overview"),cbi("admin_network/wifi")),_("Wireless"),15)
e.subindex=true
if e.inreq then print("wireless") end
e.subindex=true
if e.inreq then print("interfaces") end
]]}
local original = files[path]
local source = assert(io.open(INSTALLER)):read("*a")
local real_open, real_remove, real_rename = io.open, os.remove, os.rename
package.loaded["luci.model.tch_wireless"] = {supported=function() return true end}
io.open=function(p, mode)
  if mode == "r" and not files[p] then return nil end
  return {read=function() return files[p] end,
    write=function(self, value) files[p]=value; return true end, close=function() return true end}
end
os.remove=function() return true end
os.rename=function(a,z) files[z]=files[a]; files[a]=nil; return true end
assert(loadstring(source))()
assert(files[path]:find('require("luci.model.tch_wireless").target(', 1, true))
assert(files[path]:find('if e.inreq then print("interfaces") end', 1, true))
assert(files[path .. ".modgui-wireless-original"] == original)
local once = files[path]; assert(loadstring(source))(); assert(files[path] == once)
files[path] = "-- Unsupported version"
assert(not pcall(assert(loadstring(source))))
assert(files[path] == "-- Unsupported version")
io.open, os.remove, os.rename = real_open, real_remove, real_rename
'''
        for overview in ("cbi", "template"):
            with self.subTest(overview=overview):
                fixture = code.replace('arcombine(cbi("admin_network/wifi_overview")',
                                       f'arcombine({overview}("admin_network/wifi_overview")')
                self.run_lua("local INSTALLER = " + repr(str(INSTALLER)) + "\n" + fixture)

    def test_templates_render_without_modern_url_global(self):
        code = '''
package.loaded['luci.model.tch_wireless'] = b
package.loaded['luci.dispatcher'] = {build_url=function(...) return '/' .. table.concat({...}, '/') end}
url = nil; token = nil; resource = '/resources'
pcdata = function(value) assert(type(value) == 'string'); return value end
translate = function(value) return value end
self = {snapshot=snapshot, creation={radios={}, unavailable={}}}
'''
        for filename in ('tch_wireless_overview.htm', 'tch_wireless_back.htm'):
            template = (BACKEND.parents[1] / 'view' / filename).read_text()
            chunks = ['do\n']
            for part in re.split(r'(<%.*?%>)', template, flags=re.S):
                if not part.startswith('<%'):
                    chunks.append('io.write([====[' + part + ']====])\n')
                elif part.startswith('<%#'):
                    continue
                elif part.startswith('<%:'):
                    chunks.append('io.write([====[' + part[3:-2] + ']====])\n')
                elif part.startswith('<%='):
                    chunks.append('io.write(tostring(' + part[3:-2] + '))\n')
                else:
                    chunks.append(part[2:-2] + '\n')
            chunks.append('end\n')
            code += ''.join(chunks)
        self.run_lua(code)


if __name__ == "__main__":
    unittest.main()
