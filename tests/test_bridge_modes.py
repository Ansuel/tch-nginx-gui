"""Exercise bridge/routed transitions against firmware-shaped datamodels."""
from pathlib import Path
import json
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua interpreter required')
class BridgeModes(unittest.TestCase):
    def test_routed_exit_detaches_preexisting_designated_wan_before_lan_services(self):
        self.run_lua('''
values[sensing] = '0'
values[lan] = 'eth0 eth1 eth2 eth3 eth4'
names[#names + 1] = {path = 'uci.ethernet.port.@eth4.'}
values['uci.ethernet.port.@eth4.wan'] = '1'
values['uci.dhcp.dhcp.@lan.ignore'] = '0'
values['uci.dhcp.dhcp.@lan.ra'] = 'server'
assert(bridge.enter())
assert(values[cfg .. 'bridge_added_ifnames'] == '')
local execute = os.execute
os.execute = function(command)
  if command:find('/etc/init.d/dnsmasq restart', 1, true) then
    assert(values[lan] == 'eth0 eth1 eth2 eth3')
  end
  return execute(command)
end
assert(bridge.leave('dhcp'))
assert(values[lan] == 'eth0 eth1 eth2 eth3')
assert(values['uci.dhcp.dhcp.@lan.ignore'] == '0')
''')

    def test_runner_bridge_pins_lan_profiles_and_restores_only_created_devices(self):
        self.run_lua('''
values[sensing] = '0'
local taint = string.taint or function(value) return value end
values['uci.qos.interface.@lan.classgroup'] = taint('TO_LAN')
for index = 0, 4 do
  local name = 'eth' .. index
  names[#names + 1] = {path = 'uci.ethernet.port.@' .. name .. '.'}
  values['uci.ethernet.port.@' .. name .. '.wan'] = index == 4 and '1' or '0'
end
names[#names + 1] = {path = 'uci.qos.device.@eth4.'}
values['uci.qos.device.@eth4.classgroup'] = 'TO_WAN'
assert(bridge.enter())
for index = 0, 3 do assert(values['uci.qos.device.@eth' .. index .. '.classgroup'] == 'TO_LAN') end
assert(values['uci.qos.device.@eth4.classgroup'] == 'TO_WAN')
assert(values[cfg .. 'bridge_qos_devices']:find('eth0=TO_LAN', 1, true))
local saved = values[cfg .. 'bridge_qos_devices']
assert(bridge.enter() and values[cfg .. 'bridge_qos_devices'] == saved)
-- Keep a profile explicitly edited while bridge mode was active.
values['uci.qos.device.@eth2.classgroup'] = 'CUSTOM'
values['uci.qos.device.@eth1.enable'] = '0'
assert(bridge.leave('dhcp'))
assert(values['uci.qos.device.@eth0.classgroup'] == nil)
assert(values['uci.qos.device.@eth1.classgroup'] == 'TO_LAN')
assert(values['uci.qos.device.@eth1.enable'] == '0')
assert(values['uci.qos.device.@eth2.classgroup'] == 'CUSTOM')
assert(values['uci.qos.device.@eth3.classgroup'] == nil)
assert(values['uci.qos.device.@eth4.classgroup'] == 'TO_WAN')
assert(values[cfg .. 'bridge_qos_devices'] == '')
''')

    def test_runner_protection_skips_non_runner_and_distinct_wan_ports(self):
        self.run_lua('''
values[sensing] = '0'
values['uci.qos.interface.@lan.classgroup'] = 'TO_LAN'
names[#names + 1] = {path = 'uci.ethernet.port.@eth4.'}
values['uci.ethernet.port.@eth4.wan'] = '1'
os.execute = function(command)
  if command == '[ -x /usr/bin/setuprunner ]' then return 1 end
  return 0
end
assert(bridge.enter())
assert(values[cfg .. 'bridge_qos_devices'] == nil)
assert(bridge.leave('dhcp'))
values[wan .. 'ifname'] = 'ptm0'
os.execute = function() return 0 end
assert(bridge.enter())
assert(values[cfg .. 'bridge_qos_devices'] == nil)
''')

    def test_runner_profiles_cover_wan_without_an_existing_device_profile(self):
        self.run_lua('''
values[sensing] = '0'
values['uci.qos.interface.@lan.classgroup'] = 'TO_LAN'
values['uci.qos.interface.@wan.classgroup'] = 'TO_WAN'
for index = 0, 4 do
  local path = 'uci.ethernet.port.@eth' .. index .. '.'
  names[#names + 1] = {path = path}
  values[path .. 'wan'] = index == 4 and '1' or '0'
end
assert(bridge.enter())
assert(values['uci.qos.device.@eth4.classgroup'] == 'TO_WAN')
assert(values[cfg .. 'bridge_qos_devices']:find('eth4=TO_WAN', 1, true))
assert(bridge.leave('dhcp'))
assert(values['uci.qos.device.@eth4.classgroup'] == nil)
values['uci.qos.interface.@wan.classgroup'] = nil
assert(not bridge.enter())
assert(values[cfg .. 'wan_mode'] == 'dhcp')
assert(values['uci.qos.device.@eth0.classgroup'] == nil)
''')

    def test_runner_profile_creation_failure_removes_partial_additions(self):
        self.run_lua('''
values[sensing] = '0'
values['uci.qos.interface.@lan.classgroup'] = 'TO_LAN'
for index = 0, 4 do
  local path = 'uci.ethernet.port.@eth' .. index .. '.'
  names[#names + 1] = {path = path}
  values[path .. 'wan'] = index == 4 and '1' or '0'
end
local add = proxy.add
proxy.add = function(prefix, name)
  if prefix == 'uci.qos.device.' and name == 'eth1' then return false, 'cannot add' end
  return add(prefix, name)
end
assert(not bridge.enter())
assert(values[cfg .. 'wan_mode'] == 'dhcp')
for _, entry in ipairs(names) do assert(entry.path ~= 'uci.qos.device.@eth0.') end
''')

    def test_broadband_follows_physical_bridge_uplink_and_its_link_state(self):
        self.run_lua('''
local taint = string.taint or function(value) return value end
values[sensing] = '0'
values[cfg .. 'wan_mode'] = taint('bridge')
values[wan .. 'ifname'] = taint('br-lan')
values[wan .. 'proto'] = 'dhcp'
values[lan] = taint('eth0 eth1 eth2 eth3')
names[#names + 1] = {path = 'uci.ethernet.port.@eth3.'}
values['uci.ethernet.port.@eth3.wan'] = '1'
values['sys.class.net.@eth3.operstate'] = 'up'
values['sys.class.net.@eth3.carrier'] = '1'
values['sys.class.net.@eth3.speed'] = '1000'
assert(bridge.getUplink() == 'eth3')
local stats = bridge.ethernetLink()
assert(stats.operstate == 'up' and stats.carrier == '1' and stats.speed == '1000')
for _, name in ipairs({'web.ui_helper', 'web.content_helper', 'web.uimessage_helper', 'web.post_helper'}) do
  package.preload[name] = function() return {} end
end
local modes = require('broadbandmode_helper')
for _, mode in ipairs(modes) do assert(mode.check() == (mode.name == 'ethernet')) end
-- A saved uplink and VLAN take precedence over the first WAN-designated port.
names[#names + 1] = {path = 'uci.ethernet.port.@eth10.'}
values['uci.ethernet.port.@eth10.wan'] = '1'
device('vendor_vlan', 'vendor_vlan', 'eth10', '835')
values[cfg .. 'bridge_ifname'] = taint('@uplink')
values['uci.network.interface.@uplink.ifname'] = taint('vendor_vlan')
values['sys.class.net.@eth10.operstate'] = 'up'
values['sys.class.net.@eth10.carrier'] = '1'
values['sys.class.net.@eth10.speed'] = '2500'
assert(bridge.ethernetPort('eth3') == 'eth10')
assert(bridge.ethernetLink().speed == '2500')
for _, mode in ipairs(modes) do assert(mode.check() == (mode.name == 'ethernet')) end
values['sys.class.net.@eth10.carrier'] = '0'
assert(bridge.ethernetLink().carrier == '0')
assert(#events == 0)
''')

    def test_uplink_readers_preserve_tainted_strings_without_table_concat(self):
        self.run_lua('''
local taint, raw = string.taint, string.untaint
if not taint then
    local cache, mt = {}, {}
    raw = function(value) return type(value) == 'table' and value.text or value end
    taint = function(value)
        if not cache[value] then cache[value] = setmetatable({text = value}, mt) end
        return cache[value]
    end
    mt.__concat = function(a, b) return taint(raw(a) .. raw(b)) end
    mt.__index = function(value, key)
        if key == 'gmatch' then return function(_, pattern)
            local nextValue = value.text:gmatch(pattern)
            return function() local item = nextValue(); if item then return taint(item) end end
        end end
        return function(_, ...) return string[key](value.text, ...) end
    end
end
values[wan .. 'ifname'] = taint('eth4')
assert(raw(bridge.resolveUplinks(taint('eth4 eth4 eth5'))) == 'eth4 eth5')
assert(raw(bridge.getUplink()) == 'eth4')
assert(raw(bridge.vlanContext().connection) == 'eth4')
values[lan] = taint('eth0 eth1 eth2 eth3')
assert(raw(bridge.lanWith(taint('eth4'))) == 'eth0 eth1 eth2 eth3 eth4')
assert(raw(bridge.lanWithout(taint('eth1'))) == 'eth0 eth2 eth3')
''')

    def test_bridge_suspends_only_overlapping_relay_ports_and_restores_them(self):
        self.run_lua('''
local relay = 'uci.network.interface.@lan.pppoerelay.'
names[#names + 1] = {path = relay .. '@1.'}
names[#names + 1] = {path = relay .. '@2.'}
values[relay .. '@1.value'] = 'eth4'
values[relay .. '@2.value'] = 'ptm0'
assert(bridge.enter())
assert(values[relay .. '@1.value'] == '')
assert(values[relay .. '@2.value'] == 'ptm0')
assert(bridge.leave('dhcp'))
assert(values[relay .. '@1.value'] == 'eth4')
assert(values[relay .. '@2.value'] == 'ptm0')
assert(values[cfg .. 'bridge_lan_relays'] == '')
''')

    def run_lua(self, script):
        prelude = r'''
T = function(s) return s end
gettext = {textdomain = function() end}
local values, names, events = {}, {{path = 'uci.wansensing.L2State.@L2Sense.'}}, {}
local failSet, failApply, stopStatus = false, false, 0
local wan = 'uci.network.interface.@wan.'
local cfg = 'uci.network.config.'
local lan = 'uci.network.interface.@lan.ifname'
local sensing = 'uci.wansensing.global.enable'
values[wan .. 'ifname'] = 'eth4'
values[wan .. 'proto'] = 'dhcp'
values[cfg .. 'wan_mode'] = 'dhcp'
values[lan] = 'eth0 eth1 eth2 eth3'
values[sensing] = '1'
local proxy = {}
function proxy.get(path)
    if string.untaint then path = string.untaint(path) end
    if values[path] == nil then return nil end
    return {{value = values[path]}}
end
function proxy.getPN(prefix)
    local result = {}
    for _, entry in ipairs(names) do
        if entry.path:sub(1, #prefix) == prefix then result[#result + 1] = entry end
    end
    return result
end
function proxy.set(path, value)
    if failSet then return false, 'write failed' end
    if type(path) == 'table' then
        for parameter, item in pairs(path) do
            local key = string.untaint and string.untaint(parameter) or parameter
            values[key] = item
        end
        events[#events + 1] = 'network-set'
    else
        if string.untaint then path = string.untaint(path) end
        values[path] = value
        events[#events + 1] = path .. '=' .. value
    end
    return true
end
function proxy.apply()
    events[#events + 1] = 'apply'
    if failApply then return false, 'apply failed' end
    return true
end
function proxy.add(prefix, name)
    names[#names + 1] = {path = prefix .. '@' .. name .. '.'}
    return true
end
function proxy.del(path)
    if string.untaint then path = string.untaint(path) end
    for key in pairs(values) do if key:sub(1, #path) == path then values[key] = nil end end
    for index = #names, 1, -1 do
        if names[index].path:sub(1, #path) == path then table.remove(names, index) end
    end
    events[#events + 1] = 'delete:' .. path
    return true
end
os.execute = function(command)
    events[#events + 1] = command
    return stopStatus
end
package.preload.datamodel = function() return proxy end
package.preload['transformer.shared.sfp'] = function() return {
    readSFPFlag = function() return values['uci.env.rip.sfp'] == '1' and 1 or 0 end,
} end
package.path = LUA_DIR .. '/?.lua;' .. package.path
local bridge = require('bridgehelper')
local function device(section, name, parent, vid)
    local path = 'uci.network.device.@' .. section .. '.'
    names[#names + 1] = {path = path}
    values[path .. 'name'] = name
    values[path .. 'ifname'] = parent
    values[path .. 'vid'] = vid
    values[path .. 'type'] = '8021q'
    return path
end
'''.replace('LUA_DIR', repr(str(ROOT / 'www/lua')))
        result = subprocess.run([LUA, '-'], input=prelude + script,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_sensing_is_committed_and_stopped_before_bridge_then_restored(self):
        self.run_lua('''
values[wan .. 'proto'] = 'pppoe'
values['uci.network.interface.@wantag.auto'] = '1'
assert(bridge.enter())
assert(events[1] == sensing .. '=0' and events[2] == 'apply')
assert(events[3]:match('/etc/init.d/wansensing stop'))
assert(events[4] == 'network-set' and events[5]:match('ifdown wantag'))
assert(values[sensing] == '0' and values[cfg .. 'bridge_wansensing'] == '1')
assert(values['uci.network.interface.@wantag.auto'] == '0')
assert(values[lan] == 'eth0 eth1 eth2 eth3 eth4')
assert(values[cfg .. 'bridge_proto'] == 'pppoe')
-- Reload the helper as another HTTP request would; repeated activation must
-- retain the original state rather than saving the bridge's disabled sensing.
package.loaded.bridgehelper = nil
bridge = require('bridgehelper')
assert(bridge.enter())
assert(values[cfg .. 'bridge_wansensing'] == '1')
assert(bridge.leave('dhcp'))
assert(values[sensing] == '1' and values[wan .. 'proto'] == 'dhcp')
assert(values[lan] == 'eth0 eth1 eth2 eth3')
assert(values['uci.network.interface.@wantag.auto'] == '1')
assert(values[cfg .. 'bridge_ifname'] == '')
''')

    def test_manual_sensing_stays_disabled_and_exact_members_survive(self):
        self.run_lua('''
values[sensing] = '0'
values[wan .. 'ifname'] = 'eth4.835'
values[lan] = 'eth0 eth4.8350 eth4.835'
assert(bridge.enter())
assert(values[lan] == 'eth0 eth4.8350 eth4.835')
assert(values[cfg .. 'bridge_added_ifnames'] == '')
assert(bridge.leave('static'))
assert(values[sensing] == '0')
assert(values[lan] == 'eth0 eth4.8350 eth4.835')
''')

    def test_native_aliases_resolve_to_bridge_ports_and_keep_native_vid(self):
        self.run_lua('''
local path = device('vlan_eth4', 'vlan_eth4', 'eth4', '835')
device('waneth4', 'waneth4', 'eth4', '100')
values[wan .. 'ifname'] = '@vlan_wan_eth4'
values['uci.network.interface.@vlan_wan_eth4.ifname'] = 'vlan_eth4'
local channel = bridge.vlanContext()
assert(channel.path == path and channel.vid == '835' and channel.connection == 'eth4')
assert(bridge.enter())
assert(values[lan] == 'eth0 eth1 eth2 eth3 vlan_eth4')
assert(values[cfg .. 'bridge_ifname'] == '@vlan_wan_eth4')
assert(values[path .. 'vid'] == '835')
assert(bridge.leave('dhcp'))
assert(values[wan .. 'ifname'] == '@vlan_wan_eth4')
''')

    def test_local_connection_can_be_removed_and_sensing_can_exit_bridge(self):
        self.run_lua('''
values[sensing] = '0'
values[wan .. 'proto'] = 'pppoe'
assert(bridge.enter())
assert(bridge.setLocalProtocol('dhcp'))
assert(values[wan .. 'ifname'] == 'br-lan')
assert(bridge.vlanContext().connection == 'eth4')
assert(bridge.setLocalProtocol('bridge'))
assert(values[wan .. 'ifname'] == 'eth4')
assert(bridge.setLocalProtocol('pppoe'))
assert(bridge.setSensing('1'))
assert(not bridge.isBridged() and values[wan .. 'proto'] == 'pppoe')
assert(values[wan .. 'ifname'] == 'eth4' and values[sensing] == '1')
assert(values[lan] == 'eth0 eth1 eth2 eth3')
''')

    def test_vlan_and_broadband_changes_move_bridge_with_local_connection(self):
        self.run_lua('''
values[sensing] = '0'
assert(bridge.enter())
assert(bridge.setLocalProtocol('dhcp'))
assert(bridge.setUplink('eth4.835'))
assert(values[wan .. 'ifname'] == 'br-lan')
assert(values[lan] == 'eth0 eth1 eth2 eth3 eth4.835')
assert(bridge.vlanContext().vid == '835')
assert(bridge.changeUplink(function() return proxy.set(wan .. 'ifname', 'ptm0.100') end))
assert(values[wan .. 'ifname'] == 'br-lan')
assert(values[lan] == 'eth0 eth1 eth2 eth3 ptm0.100')
assert(bridge.leave('pppoe'))
assert(values[wan .. 'ifname'] == 'ptm0.100')
assert(values[lan] == 'eth0 eth1 eth2 eth3')
''')

    def test_failed_stop_or_disable_never_enables_bridge(self):
        self.run_lua('''
for _, failure in ipairs({'write', 'apply', 'stop'}) do
    values[sensing] = '1'
    failSet, failApply = failure == 'write', failure == 'apply'
    stopStatus = failure == 'stop' and 1 or 0
    local ok = bridge.enter()
    assert(ok == false)
    assert(values[cfg .. 'wan_mode'] == 'dhcp')
    assert(values[lan] == 'eth0 eth1 eth2 eth3')
end
''')

    def test_missing_sensing_and_unsafe_aliases(self):
        self.run_lua('''
values[sensing] = nil
assert(bridge.enter() and bridge.leave('dhcp'))
assert(values[sensing] == nil)
for _, ifname in ipairs({'br-lan', '@lan', '@cycle', '', 'eth4 lo'}) do
    values[wan .. 'ifname'] = ifname
    values['uci.network.interface.@lan.ifname'] = 'br-lan'
    values['uci.network.interface.@cycle.ifname'] = '@cycle'
    assert(not bridge.enter())
    assert(values[cfg .. 'wan_mode'] == 'dhcp')
end
''')

    def test_real_internet_mode_dispatch_and_explicit_abort(self):
        self.run_lua('''
local posted = {action = 'SWITCH_MODE', newmode = 'bridge'}
ngx = {var = {request_method = 'POST'}, req = {get_post_args = function() return posted end}}
getmetatable('').__index.untaint = function(s) return s end
package.preload['web.post_helper'] = function() return {
    getValidateInEnumSelect = function(options) return function(value)
        for _, option in ipairs(options) do if option[1] == value then return true end end
        return false
    end end,
} end
local errors = {}
package.preload['web.uimessage_helper'] = function() return {
    pushMessage = function(message) errors[#errors + 1] = message end,
} end
local modes = require('internetmode_helper')
local dyntab = dofile(DYNTAB)
assert(dyntab.process(modes).current.name == 'bridge')
assert(bridge.setLocalProtocol('dhcp'))
posted = {action = 'AJAX-GET'}
assert(dyntab.process(modes).current.name == 'bridge')
posted = {action = 'SWITCH_MODE', newmode = 'static'}
assert(dyntab.process(modes).current.name == 'static')
assert(values[sensing] == '1')
posted = {action = 'SWITCH_MODE', newmode = 'bridge'}
stopStatus = 1
local count = #events
assert(dyntab.process(modes).current.name == 'static')
assert(#errors == 1 and events[#events]:match('/etc/init.d/wansensing stop'))
'''.replace('DYNTAB', repr(str(ROOT / 'usr/lib/lua/web/dyntab_helper.lua'))))

    def test_broadband_switch_preserves_active_native_vlan(self):
        self.run_lua('''
values[sensing] = '0'
values['sys.eth.port.@eth4.status'] = 'Up'
values['uci.env.rip.sfp'] = '0'
values[wan .. 'ifname'] = '@vlan_wan_eth4'
values['uci.network.interface.@vlan_wan_eth4.ifname'] = 'vlan_eth4'
device('waneth4', 'waneth4', 'eth4', '100')
device('vlan_eth4', 'vlan_eth4', 'eth4', '835')
for _, name in ipairs({'web.ui_helper', 'web.content_helper', 'web.uimessage_helper', 'web.post_helper'}) do
    package.preload[name] = function() return {} end
end
local modes = require('broadbandmode_helper')
for _, mode in ipairs(modes) do
    if mode.name == 'ethernet' then assert(mode.operations()) end
end
assert(values[wan .. 'ifname'] == '@vlan_wan_eth4')
assert(bridge.vlanContext().vid == '835')
assert(bridge.enter())
assert(values[lan] == 'eth0 eth1 eth2 eth3 vlan_eth4')
''')

    def test_vlan_modal_changes_active_device_and_preserves_bridge_local_connection(self):
        self.run_lua('''
values[sensing] = '0'
local path = device('vlan_eth4', 'vlan_eth4', 'eth4', '835')
local other = device('waneth4', 'waneth4', 'eth4', '100')
values[wan .. 'ifname'] = 'vlan_eth4'
assert(bridge.enter() and bridge.setLocalProtocol('dhcp'))
local posted = {action = 'SAVE', intf_vlan = 'eth4', intf_vlanid = '836', auswahlliste = 'devnot'}
local errors, shown = {}, {}
ngx = {var = {request_method = 'POST'}, print = function() end,
    ctx = {session = {getrole = function() return 'engineer' end}},
    req = {get_post_args = function() return posted end}}
package.preload['web.lp'] = function() return {} end
package.preload['web.post_helper'] = function() return {} end
package.preload['web.content_helper'] = function() return {} end
package.preload.broadbandmode_helper = function() return {} end
package.preload['web.uimessage_helper'] = function() return {
    pushMessage = function(message) errors[#errors + 1] = message end,
    popMessages = function() return {} end,
} end
package.preload['web.ui_helper'] = function() return setmetatable({}, {__index = function(_, key)
    return function(label, name, value)
        if key == 'createInputText' then shown[name] = value end
        return ''
    end
end}) end
dofile(VLAN_MODAL)
assert(#errors == 0 and values[path .. 'vid'] == '836' and values[other .. 'vid'] == '100')
assert(shown.intf_vlanid == '836' and values[wan .. 'ifname'] == 'br-lan')
posted.auswahlliste = 'dotnot'
dofile(VLAN_MODAL)
assert(#errors == 0 and values[wan .. 'ifname'] == 'br-lan')
assert(values[lan] == 'eth0 eth1 eth2 eth3 eth4.836')
assert(values[path .. 'ifname'] == '')
local count = #events
posted.intf_vlanid = '835.5'
dofile(VLAN_MODAL)
assert(#errors == 1 and #events == count)
posted.intf_vlan = '0'
dofile(VLAN_MODAL)
assert(values[lan] == 'eth0 eth1 eth2 eth3 eth4')
assert(bridge.leave('dhcp') and values[wan .. 'ifname'] == 'eth4')
-- A SAVE that re-enables sensing also contains stale VLAN form fields.
-- Those fields must not override the interface selected by the daemon.
values[sensing] = '1'
posted.intf_vlan = 'eth4'
posted.intf_vlanid = '100'
posted.auswahlliste = 'devnot'
count = #events
dofile(VLAN_MODAL)
assert(#events == count and values[wan .. 'ifname'] == 'eth4')
'''.replace('VLAN_MODAL', repr(str(ROOT / 'www/snippets/broadband-vlan.lp'))))

    def test_physical_device_is_not_mistaken_for_a_vlan(self):
        self.run_lua('''
local path = device('if0atm', 'atm0', '', '')
values[path .. 'type'] = ''
values[wan .. 'ifname'] = 'atm0'
local channel = bridge.vlanContext()
assert(channel.connection == 'atm0' and channel.difname == '')
assert(channel.path ~= path)
''')

    def test_legacy_bridge_exit_and_uplink_replacement(self):
        self.run_lua('''
values[sensing] = '0'
values[wan .. 'proto'] = 'bridge'
values[cfg .. 'wan_mode'] = 'bridge'
values[lan] = 'eth0 eth1 eth4'
assert(bridge.setSensing('1'))
assert(values[lan] == 'eth0 eth1' and values[wan .. 'proto'] == 'dhcp')
values[sensing] = '0'
values[wan .. 'proto'] = 'bridge'
values[cfg .. 'wan_mode'] = 'bridge'
values[lan] = 'eth0 eth1 eth4'
assert(bridge.changeUplink(function() return proxy.set(wan .. 'ifname', 'ptm0') end))
assert(values[lan] == 'eth0 eth1 ptm0')
assert(bridge.leave('pppoe') and values[lan] == 'eth0 eth1')
''')

    def test_broadband_modal_sensing_enable_exits_bridge_and_refreshes_mode(self):
        self.run_lua('''
values[sensing] = '0'
values[wan .. 'proto'] = 'pppoe'
assert(bridge.enter())
local includes, errors = {}, {}
ngx = {var = {request_method = 'POST'}, print = function() end,
    req = {get_post_args = function() return {action = 'SAVE', wsens = '1'} end}}
package.preload.broadbandmode_helper = function() return {} end
package.preload['web.dyntab_helper'] = function() return {process = function()
    return {current = {name = 'ethernet', view = 'broadband-ethernet-advanced.lp'}, options = {}}
end} end
package.preload['web.content_helper'] = function() return {} end
package.preload['web.post_helper'] = function() return {
    validateBoolean = function(value) return value == '0' or value == '1' end,
} end
package.preload['web.uimessage_helper'] = function() return {
    pushMessage = function(message, level) if level == 'error' then errors[#errors + 1] = message end end,
    popMessages = function() return {} end,
} end
package.preload['web.ui_helper'] = function() return setmetatable({}, {__index = function()
    return function() return '' end
end}) end
package.preload['web.lp'] = function() return {
    setpath = function() end,
    include = function(path) includes[#includes + 1] = path end,
} end
dofile(BROADBAND_MODAL)
assert(#errors == 0 and values[sensing] == '1')
assert(not bridge.isBridged() and values[wan .. 'proto'] == 'pppoe')
assert(values[lan] == 'eth0 eth1 eth2 eth3')
assert(includes[1] == 'broadband-ethernet-advanced.lp')
'''.replace('BROADBAND_MODAL', repr(str(ROOT / 'www/docroot/modals/broadband-modal.lp'))))

    def test_sampled_firmware_broadband_to_bridge_roundtrips(self):
        fixtures = json.loads((Path(__file__).parent / 'fixtures/bridge-firmwares.json').read_text())
        for fixture in fixtures:
            kinds = ['ethernet']
            for mode, section_kind in [('adsl', 'atmdevice'), ('vdsl', 'ptmdevice')]:
                if any(s['kind'] == section_kind for s in fixture['xtm']):
                    kinds.append(mode)
            seed = []
            for config_name in ['network', 'xtm', 'ethernet']:
                for section in fixture[config_name]:
                    if not section['section']:
                        continue
                    path = f"uci.{config_name}.{section['kind']}.@{section['section']}."
                    seed.append(f"names[#names + 1] = {{path = {path!r}}}")
                    for option, value in section['options'].items():
                        seed.append(f"values[{path + option!r}] = {value!r}")
            enable = fixture['sensing_enable']
            if not fixture['state_count']:
                seed.insert(0, 'names = {}')
            seed.append(f"values[sensing] = {enable!r}" if enable is not None else "values[sensing] = nil")
            ports = [s['section'] for s in fixture['ethernet'] if s['kind'] == 'port']
            if 'eth4' in ports:
                seed.append("values['sys.eth.port.@eth4.status'] = 'Up'")
            for kind in kinds:
                with self.subTest(firmware=fixture['branch'], broadband=kind):
                    self.run_lua('\n'.join(seed) + '''
values[wan .. 'ifname'] = 'unselected0'
values['uci.env.rip.sfp'] = '0'
if values[sensing] ~= nil then values[sensing] = '0' end
for _, name in ipairs({'web.ui_helper', 'web.content_helper', 'web.uimessage_helper', 'web.post_helper'}) do
    package.preload[name] = function() return {} end
end
local modes = require('broadbandmode_helper')
local mode
for _, entry in ipairs(modes) do if entry.name == KIND then mode = entry end end
assert(mode and mode.operations())
local chosen = values[wan .. 'ifname']
local member = bridge.resolveUplink(chosen)
assert(member and member ~= 'unselected0')
assert(mode.check())
-- A second selection of the same technology must retain the chosen PVC/VLAN.
assert(mode.operations() and values[wan .. 'ifname'] == chosen)
local before = values[lan]
local vids = {}
for path, value in pairs(values) do if path:match('%.vid$') then vids[path] = value end end
local ulp = values['uci.xtm.atmdevice.@' .. bridge.vlanContext().connection .. '.ulp']
if ulp == 'ppp' then
    local ok, message = bridge.enter()
    assert(ok == false and message:match('PPPoA'))
    assert(not bridge.isBridged() and values[lan] == before)
    assert(values['uci.xtm.atmdevice.@' .. bridge.vlanContext().connection .. '.ulp'] == 'ppp')
    return
end
assert(bridge.enter())
assert(values[cfg .. 'bridge_ifname'] == chosen)
local _, count = values[lan]:gsub(member:gsub('(%W)', '%%%1'), '')
assert(count >= 1)
assert(bridge.setLocalProtocol('dhcp'))
assert(values[wan .. 'ifname'] == 'br-lan' and bridge.getUplink() == chosen)
assert(bridge.setLocalProtocol('bridge') and values[wan .. 'ifname'] == chosen)
assert(bridge.leave('dhcp'))
assert(values[lan] == before and values[wan .. 'ifname'] == chosen)
for path, value in pairs(vids) do assert(values[path] == value) end
assert(bridge.enter())
if HAS_STATES then
    assert(bridge.setSensing('1'))
    assert(not bridge.isBridged() and values[sensing] == '1')
    assert(values[wan .. 'ifname'] == chosen and values[lan] == before)
else
    local ok = bridge.setSensing('1')
    assert(ok == false and bridge.isBridged())
    assert(bridge.leave('dhcp'))
end
'''.replace('KIND', repr(kind)).replace('HAS_STATES', str(bool(fixture['state_count'])).lower()))

    def test_arbitrary_devices_aliases_multiport_wan_and_vlan_names(self):
        self.run_lua('''
values[sensing] = '0'
for _, ifname in ipairs({'eth3', 'eth5', 'eth10.835', 'ptm1', 'ptm1.100', 'atm0', 'atm_8_35',
    'atm_wan', 'atmwan', 'gpon0', 'sfp0', 'enet7', 'dsl_data', 'ptm0_v881'}) do
    values[wan .. 'ifname'] = ifname
    local before = values[lan]
    assert(bridge.enter())
    assert(bridge.getUplink() == ifname)
    assert(bridge.leave('dhcp') and values[lan] == before)
end
values['uci.network.interface.@outer.ifname'] = '@inner'
values['uci.network.interface.@inner.ifname'] = 'eth5 ptm1.100'
values[wan .. 'ifname'] = '@outer'
values[wan .. 'type'] = 'bridge'
assert(bridge.enter())
assert(values[lan] == 'eth0 eth1 eth2 eth3 eth5 ptm1.100')
assert(values[wan .. 'type'] == '')
assert(bridge.leave('dhcp'))
assert(values[wan .. 'type'] == 'bridge' and values[wan .. 'ifname'] == '@outer')
assert(values[lan] == 'eth0 eth1 eth2 eth3')
''')

    def test_only_competing_clients_are_suspended_and_restored(self):
        self.run_lua('''
values[sensing] = '0'
for _, client in ipairs({
    {'ipoe', 'dhcp', 'eth4', ''},
    {'ppp', 'pppoe', 'eth4', '1'},
    {'wan6', 'dhcpv6', '@wan', '0'},
    {'voip', 'dhcp', 'eth4.855', '1'},
}) do
    local path = 'uci.network.interface.@' .. client[1] .. '.'
    names[#names + 1] = {path = path}
    values[path .. 'proto'], values[path .. 'ifname'], values[path .. 'auto'] = client[2], client[3], client[4]
end
assert(bridge.enter())
assert(values['uci.network.interface.@ipoe.auto'] == '0')
assert(values['uci.network.interface.@ppp.auto'] == '0')
assert(values['uci.network.interface.@wan6.auto'] == '0')
assert(values['uci.network.interface.@voip.auto'] == '1')
assert(bridge.leave('dhcp'))
assert(values['uci.network.interface.@ipoe.auto'] == '')
assert(values['uci.network.interface.@ppp.auto'] == '1')
assert(values['uci.network.interface.@wan6.auto'] == '0')
''')

    def test_unconfigured_sensing_cannot_exit_a_working_bridge(self):
        self.run_lua('''
values[sensing] = '0'
names = {}
assert(bridge.enter())
local before, count = values[lan], #events
local ok, message = bridge.setSensing('1')
assert(ok == false and message:match('no configured detection states'))
assert(bridge.isBridged() and values[lan] == before and #events == count)
''')

    def test_pppoa_preflight_does_not_change_a_working_bridge(self):
        self.run_lua('''
values[sensing] = '0'
values['sys.eth.port.@eth4.status'] = 'Up'
local path = 'uci.xtm.atmdevice.@atm0.'
names[#names + 1] = {path = path}
values[path .. 'ulp'], values[path .. 'vpi'], values[path .. 'vci'] = 'ppp', '0', '38'
for _, name in ipairs({'web.ui_helper', 'web.content_helper', 'web.uimessage_helper', 'web.post_helper'}) do
    package.preload[name] = function() return {} end
end
assert(bridge.enter())
local before, count = values[lan], #events
for _, mode in ipairs(require('broadbandmode_helper')) do
    if mode.name == 'adsl' then
        local ok, message = mode.operations()
        assert(ok == false and message:match('PPPoA'))
    end
end
assert(values[wan .. 'ifname'] == 'eth4' and values[lan] == before and #events == count)
''')

    def test_optical_and_nonstandard_ethernet_selection_survive_bridge(self):
        self.run_lua('''
values[sensing] = '0'
values['sys.eth.port.@eth4.status'] = 'Up'
values['uci.env.rip.sfp'] = '1'
values['uci.ethernet.globals.eth4lanwanmode'] = '0'
for _, name in ipairs({'web.ui_helper', 'web.content_helper', 'web.uimessage_helper', 'web.post_helper'}) do
    package.preload[name] = function() return {} end
end
local modes = require('broadbandmode_helper')
for _, mode in ipairs(modes) do
    if mode.name == 'gpon' then assert(mode.operations() and mode.check()) end
end
assert(values['uci.ethernet.globals.eth4lanwanmode'] == '1')
assert(bridge.enter() and values[cfg .. 'bridge_ifname'] == 'eth4')
assert(bridge.leave('dhcp'))
-- The WAN port is discovered from Ethernet configuration, not its number.
values['uci.env.rip.sfp'] = '0'
values[wan .. 'ifname'] = 'carrier_vlan'
local path = 'uci.ethernet.port.@eth5.'
names[#names + 1] = {path = path}
values[path .. 'wan'] = '1'
device('custom_section', 'carrier_vlan', 'eth5', '881')
package.loaded.broadbandmode_helper = nil
for _, mode in ipairs(require('broadbandmode_helper')) do
    if mode.name == 'ethernet' then assert(mode.operations() and mode.check()) end
end
assert(values[wan .. 'ifname'] == 'carrier_vlan')
assert(bridge.enter() and values[cfg .. 'bridge_ifname'] == 'carrier_vlan')
assert(bridge.leave('dhcp') and values[wan .. 'ifname'] == 'carrier_vlan')
''')

    def test_stop_check_handles_legacy_exit_codes_and_async_shutdown(self):
        source = (ROOT / 'www/lua/bridgehelper.lua').read_text()
        command = source.split('local status = os.execute([[', 1)[1].split(']])', 1)[0]
        command = command.replace('/etc/init.d/wansensing stop', 'stop_service')
        for behavior, expected in [('gone', 0), ('async', 0), ('still_running', 1)]:
            with self.subTest(daemon=behavior):
                prelude = '''
stop_service() { return 1; }
sleep() { return 0; }
checks=0
pidof() {
    checks=$((checks + 1))
    case "BEHAVIOR" in
      gone) return 1 ;;
      async) [ "$checks" -lt 3 ] ;;
      still_running) return 0 ;;
    esac
}
'''.replace('BEHAVIOR', behavior)
                result = subprocess.run(['/bin/sh', '-c', prelude + command], capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_legacy_local_bridge_recovers_only_unique_configured_wan_port(self):
        self.run_lua('''
values[sensing] = '0'
values[cfg .. 'wan_mode'] = 'bridge'
values[wan .. 'ifname'] = 'br-lan'
values[wan .. 'proto'] = 'dhcp'
names[#names + 1] = {path = 'uci.ethernet.port.@eth3.'}
values['uci.ethernet.port.@eth3.wan'] = '1'
assert(bridge.getUplink() == 'eth3')
assert(bridge.enter())
assert(values[wan .. 'ifname'] == 'br-lan' and values[wan .. 'proto'] == 'dhcp')
assert(values[cfg .. 'bridge_ifname'] == 'eth3')
assert(bridge.leave('dhcp') and values[wan .. 'ifname'] == 'eth3')
assert(values[lan] == 'eth0 eth1 eth2')
values[cfg .. 'wan_mode'] = 'bridge'
values[wan .. 'ifname'] = 'br-lan'
values[lan] = 'eth0 eth1 eth2 eth3'
names[#names + 1] = {path = 'uci.ethernet.port.@eth2.'}
values['uci.ethernet.port.@eth2.wan'] = '1'
assert(bridge.getUplink() == 'br-lan')
assert(not bridge.enter())
''')

    def test_lan_dhcp_and_ra_are_suspended_before_bridge_and_restored_after_detach(self):
        self.run_lua('''
values[sensing] = '0'
local path = 'uci.dhcp.dhcp.@lan.'
values[path .. 'ignore'] = '0'
values[path .. 'ra'] = 'server'
values[path .. 'dhcpv6'] = 'server'
values[path .. 'ndp'] = ''
local phases = {}
os.execute = function(command)
    phases[#phases + 1] = command
    if command:match('odhcpd') and not bridge.isBridged() and #phases == 1 then
        assert(values[lan] == 'eth0 eth1 eth2 eth3')
        assert(values[path .. 'ignore'] == '1' and values[path .. 'ra'] == 'disabled')
    end
    if command:match('/etc/init.d/network reload') then
        assert(not bridge.isBridged() and values[lan] == 'eth0 eth1 eth2 eth3')
        assert(values[path .. 'ignore'] == '1' and values[path .. 'ra'] == 'disabled')
    end
    return 0
end
assert(bridge.enter())
assert(values[path .. 'ignore'] == '1' and values[path .. 'dhcpv6'] == 'disabled')
assert(bridge.enter())
assert(bridge.leave('dhcp'))
assert(values[path .. 'ignore'] == '0' and values[path .. 'ra'] == 'server')
assert(values[path .. 'dhcpv6'] == 'server' and values[path .. 'ndp'] == '')
assert(values[cfg .. 'bridge_lan_dhcp'] == '')
assert(phases[2]:match('/etc/init.d/network reload') and phases[3]:match('odhcpd'))
''')


if __name__ == '__main__':
    unittest.main()
