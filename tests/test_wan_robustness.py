"""Run WAN readers and validators against missing/partial firmware datamodels."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('lua')
HELPER = ROOT / 'www/lua/internethelper.lua'
MAPPING = ROOT / 'usr/share/transformer/mappings/rpc/network.interface.map'


@unittest.skipUnless(LUA, 'Lua interpreter required')
class WanRobustness(unittest.TestCase):
    def test_internet_card_uses_actual_protocol_but_keeps_bridge_topology(self):
        self.run_lua('''
local included
gettext = {textdomain = function() end}
ngx = {print = function() end, ctx = {session = {hasAccess = function() return true end}}}
package.preload['web.content_helper'] = function() return {getExactContent = helper.getOptionalContent} end
package.preload['web.ui_helper'] = function() return {createCardHeader = function() return '' end} end
package.preload['web.taint'] = function() return {untaint_mt = {}} end
package.preload['web.lp'] = function() return {
  setpath = function() end, include = function(view) included = view end,
} end
package.preload.internetmode_helper = function() return {
  {name = 'bridge', card = 'bridge'}, {name = 'dhcp', card = 'dhcp'},
  {name = 'pppoe', card = 'pppoe'}, {name = 'static', card = 'static'},
} end
for _, case in ipairs({
  {'pppoe', 'dhcp', 'dhcp'}, {'dhcp', 'pppoe', 'pppoe'},
  {'pppoe', 'static', 'static'}, {'', 'dhcp', 'dhcp'},
  {'bridge', 'dhcp', 'bridge'}, {'bridge', 'pppoe', 'bridge'},
}) do
  values['uci.network.config.wan_mode'] = case[1]
  values['uci.network.interface.@wan.proto'] = case[2]
  dofile(CARD)
  assert(included == case[3])
end
assert(#writes == 0)
'''.replace('CARD', repr(str(ROOT / 'www/cards/003_internet.lp'))))

    def test_bridge_popup_protocol_lookup_accepts_tainted_datamodel_values(self):
        source = (ROOT / 'www/docroot/modals/internet-modal.lp').read_text()
        start = source.index('    local protocol = proxy.get(')
        end = source.index('\nend', start)
        self.run_lua('''
local selected
local token = {}
package.preload['web.taint'] = function()
    return {untaint_mt = {__index = function(map, key)
        if key == token then return rawget(map, 'dhcp') end
    end}}
end
values['uci.network.interface.@wan.proto'] = token
local lp = {include = function(view) selected = view end}
''' + source[start:end] + '''
assert(selected == 'internet-dhcp-routed.lp')
''')

    def run_lua(self, script):
        prelude = '''
unpack = unpack or table.unpack
T = function(s) return s end
local values, names, writes, reads = {}, nil, {}, 0
local proxy = {
  get = function(...)
    reads = reads + 1
    local result = {}
    for _, path in ipairs({...}) do
      if values[path] == nil then return nil, 'missing path' end
      local base, param = path:match('^(.*%.)([^%.]+)$')
      result[#result + 1] = {path = base, param = param, value = values[path]}
    end
    return result
  end,
  getPN = function() return names end,
  set = function(path, value) writes[#writes + 1] = {path, value}; values[path] = value end,
  apply = function() end,
}
package.preload.datamodel = function() return proxy end
local helper = dofile(HELPER_PATH)
package.preload.internethelper = function() return helper end
'''.replace('HELPER_PATH', repr(str(HELPER)))
        result = subprocess.run([LUA, '-'], input=prelude + script,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_optional_reads_keep_available_fields_and_default_missing_ones(self):
        self.run_lua('''
values['rpc.wan.address'] = '192.0.2.1'
local data = {ip = 'rpc.wan.address', v6 = 'rpc.wan.ip6addr'}
helper.getOptionalContent(data)
assert(data.ip == '192.0.2.1' and data.v6 == '')
values['rpc.wan.ip6addr'] = '2001:db8::1'
reads = 0
data = {ip = 'rpc.wan.address', v6 = 'rpc.wan.ip6addr'}
helper.getOptionalContent(data)
assert(reads == 1 and data.v6 == '2001:db8::1')
assert(helper.getValue('missing.path') == '')
helper.getOptionalContent({})
assert(#writes == 0)
''')

    def test_ipv6_detection_survives_missing_interfaces_and_empty_candidates(self):
        self.run_lua('''
local result = helper.getIpv6Content()
assert(result.ip6addr == nil)
for _, intf in ipairs({'6rd', 'wan_6', 'wan6', 'wan'}) do
  names = {{path = 'rpc.network.interface.@' .. intf .. '.'}}
  result = helper.getIpv6Content()
  assert(result.ip6addr == nil)
  local path = 'rpc.network.interface.@' .. intf .. '.ip6addr'
  values[path] = '2001:db8::1'
  result = helper.getIpv6Content()
  assert(result.ip6addr == path)
  values[path] = nil
end
names = {{path = 'rpc.network.interface.@wan6.'}, {path = 'rpc.network.interface.@6rd.'}}
values['rpc.network.interface.@6rd.ip6addr'] = '2001:db8::2'
assert(helper.getIpv6Content().ip6addr == 'rpc.network.interface.@6rd.ip6addr')
assert(#writes == 0)
''')

    def test_ppp_ipv6_roundtrip_preserves_username_without_isp_realm(self):
        for protocol in ('pppoe', 'pppoa', 'dhcp'):
            source = (ROOT / f'www/snippets/internet-{protocol}-routed.lp').read_text()
            start = source.index('local function IPv6andUsername(')
            validator = source[start:source.index('\nend', start) + 4]
            with self.subTest(protocol=protocol):
                self.run_lua('''
local getValue = helper.getValue
local function vB(v) return v == '0' or v == '1' end
''' + validator + '''
values['uci.network.interface.@wan.username'] = 'customer@example.net'
values['uci.network.interface.@wan.ipv6'] = '0'
for _, state in ipairs({'1', '0', '1'}) do
  assert(IPv6andUsername(state))
  assert(values['uci.network.interface.@wan.username'] == 'customer@example.net')
  assert(values['uci.network.interface.@wan6.auto'] == state)
  values['uci.network.interface.@wan.ipv6'] = state
end
local count = #writes
assert(IPv6andUsername('1') and #writes == count)
assert(not IPv6andUsername('invalid') and #writes == count)
values['uci.env.var.ppp_realm_ipv4'] = 'isp-specific-user'
assert(IPv6andUsername('0'))
assert(values['uci.network.interface.@wan.username'] == 'isp-specific-user')
''')

    def test_mtu_protocol_ipv6_and_underlying_link_limits(self):
        self.run_lua('''
for _, protocol in ipairs({'pppoe', 'pppoa', 'dhcp', 'static'}) do
  local validate = helper.getMtuValidator(protocol)
  local maximum = protocol == 'pppoe' and 1492 or 1500
  assert(validate('') and validate(tostring(maximum)))
  assert(not validate(tostring(maximum + 1)))
  assert(validate('576', {uci_wan_ipv6 = '0'}))
  assert(not validate('1279', {uci_wan_ipv6 = '1'}))
  assert(validate('1280', {uci_wan_ipv6 = '1'}))
  for _, value in ipairs({'575', '-1', '1e3', '1280.5', ' 1280', 'garbage'}) do
    assert(not validate(value))
  end
end
values['rpc.network.interface.@wan.ppp.ll_intf'] = 'eth4'
values['sys.class.net.@eth4.mtu'] = '1508'
assert(helper.getMtuValidator('pppoe')('1500'))
assert(not helper.getMtuValidator('pppoe')('1501'))
values['uci.network.interface.@wan.ifname'] = 'eth4'
values['sys.class.net.@eth4.mtu'] = '9000'
assert(helper.getMtuValidator('dhcp')('9000'))
assert(not helper.getMtuValidator('dhcp')('9001'))
values['sys.class.net.@eth4.mtu'] = nil
values['uci.network.interface.@wan.mtu'] = '9000'
assert(helper.getMtuValidator('dhcp')('9000'))
values['uci.network.interface.@wan.mtu'] = '576'
assert(not helper.getMtuValidator('dhcp')('576', {uci_wan_ipv6 = '1'}))
assert(#writes == 0)
''')

    def test_dns_accepts_strings_lists_and_deduplicates_complete_addresses(self):
        source = MAPPING.read_text()
        block = source[source.index('local dnsServer1 ='):source.index('\nlocal config = "ipping"')]
        self.run_lua('''
local static, status
local get_interface = function(key) return key end
local uci_helper = {get_from_uci = function() return static end}
local interface_status = {get = function() return status end}
''' + block + '''
for _, config in ipairs({
  '11.1.1.1 2001:db8::11',
  {'11.1.1.1', '2001:db8::11', '11.1.1.1'},
}) do
  static = config
  status = {['dns-server'] = {'1.1.1.1', '2001:db8::1', '11.1.1.1'}}
  getDnsServers('wan')
  assert(servers == '11.1.1.1,2001:db8::11,1.1.1.1,2001:db8::1', servers)
  assert(dnsServer1 == '1.1.1.1')
end
for _, config in ipairs({'', {}, false}) do
  static, status = config, {inactive = {['dns-server'] = {'8.8.8.8'}}}
  getDnsServers('wan'); assert(servers == '8.8.8.8')
end
static, status = nil, nil
getDnsServers('wan'); assert(servers == '' and dnsServer1 == '' and dnsServer2 == '')
''')

    def test_partial_ipv6_prefix_entries_do_not_raise(self):
        source = MAPPING.read_text()
        block = source[source.index('  ip6prefix = function'):source.index('\n  dnsservers = function')]
        self.run_lua('''
local status
local get_interface = function(key) return key end
local interface_status = {get = function() return status end}
local getters = {
''' + block + '''
}
for _, value in ipairs({{}, {address = '2001:db8::'}, {mask = 64}, {address = '2001:db8::', mask = 64}}) do
  status = {['ipv6-prefix'] = {value}, ['ipv6-prefix-assignment'] = {value}}
  for name, getter in pairs(getters) do
    local result = getter(nil, nil, 'wan')
    if value.address and value.mask then assert(result:match('/64$'))
    else assert(result == '') end
  end
end
status = nil
assert(getters.ip6prefix(nil, nil, 'wan') == '')
''')

    def test_wan_endpoint_handles_missing_ipv6_and_reports_ppp_status(self):
        self.run_lua('''
local output
gettext = {textdomain = function() end}
ngx = {ctx = {}, HTTP_OK = 200,
  req = {get_method = function() return 'POST' end, get_uri_args = function() return {} end},
  say = function() end, exit = function() end}
package.preload['web.content_helper'] = function() return {getExactContent = helper.getOptionalContent} end
package.preload['web.ui_helper'] = function() return {createSimpleLight = function(color, text) return color .. ':' .. text end} end
package.preload['web.post_helper'] = function() return {
  secondsToTime = function(v) assert(type(v) == 'number'); return '' end,
  secondsToTimeShort = function(v) assert(type(v) == 'number'); return '' end,
} end
package.preload['web.taint'] = function() return {untaint_mt = {}} end
package.preload.dkjson = function() return {encode = function(data) output = data; return true end} end
values['uci.network.interface.@wan.auto'] = '1'
values['uci.network.interface.@wan.ipv6'] = '1'
for _, mode in ipairs({'pppoe', 'pppoa', 'static', 'dhcp', 'bridge'}) do
  values['uci.network.config.wan_mode'] = mode
  values['rpc.network.interface.@wan.ppp.state'] = 'connected'
  dofile(%s)
  assert(output.WAN_IP == '' and output.WAN_IPv6 == '')
  assert(output.WAN_IP_text == '' and output.WAN_IPv6_text == '')
  if mode == 'pppoe' or mode == 'pppoa' then
    assert(output.ppp_status == 'connected' and output.ppp_light == '1')
    assert(output.ipv6_state == 'IPv6 Connecting')
  end
end
values['uci.network.config.wan_mode'] = 'bridge'
values['uci.network.interface.@wan.ifname'] = 'br-lan'
values['rpc.network.interface.@wan.up'] = '1'
dofile(%s)
assert(output.status == 'Connected')
values['rpc.network.interface.@br-lan.up'] = '0'
dofile(%s)
assert(output.status == 'Disconnected')
assert(#writes == 0)
''' % ((repr(str(ROOT / 'www/docroot/ajax/internet.lua')), ) * 3))

    def test_idle_dsl_skips_blocking_dslam_queries(self):
        self.run_lua('''
local output, dslam_reads = nil, 0
gettext = {textdomain = function() end}
ngx = {HTTP_OK = 200, req = {get_method = function() return 'POST' end,
  get_uri_args = function() return {datatype = 'xdsl'} end}, say = function() end, exit = function() end}
package.preload['web.ui_helper'] = function() return {} end
package.preload['web.post_helper'] = function() return {} end
package.preload.dkjson = function() return {encode = function(data) output = data; return true end} end
local status, rate = 'Idle', '0'
package.preload['web.content_helper'] = function() return {getExactContent = function(data)
  for key, path in pairs(data) do
    if path:match('^rpc.xdslctl') then
      dslam_reads = dslam_reads + 1
      assert(rate ~= '0', 'Idle DSL must not query DSLAM RPCs')
      data[key] = key == 'dslam_version_raw' and '0x1234' or 'BDCM'
    else data[key] = key == 'status' and status or key == 'dsl_type' and 'ADSL' or rate end
  end
end} end
dofile(%s)
assert(output.status == 'Idle' and output.dsl_profile == 'N/A' and dslam_reads == 0)
status, rate = 'Showtime', '12000'
dofile(%s)
assert(output.status == 'Connected' and tonumber(output.dsl_linerate_down:match('^(%%S+)')) == 12)
assert(dslam_reads == 6 and output.dslam_chipset == 'Broadcom ( BDCM )')
''' % ((repr(str(ROOT / 'www/docroot/ajax/internet.lua')), ) * 2))

    def test_card_file_checks_close_descriptors(self):
        source = (ROOT / 'usr/lib/lua/web/content_helper.lua').read_text()
        start = source.index('function M.fileExists(')
        block = source[start:source.index('\nend', start) + 4]
        self.run_lua('''
local M, active = {}, 0
local untaint = function(value) return value end
local open = function(path)
  if path == 'missing' then return nil end
  active = active + 1
  return {close = function() active = active - 1 end}
end
''' + block + '''
for i = 1, 500 do
  assert(M.fileExists('existing'))
  assert(not M.fileExists('missing'))
  assert(active == 0)
end
''')

    def test_telstra_ppp_settings_only_read_for_pppoe_connections(self):
        source = (ROOT.parent / 'telstra_gui/www/docroot/telstra-modals/broadband.lp').read_text()
        block = source[source.index('local content_wan = {'):source.index('local content_rpc = {')]
        self.run_lua('''
local internethelper = helper
local calls = 0
package.preload['web.post_helper'] = function() return {
  handleQuery = function(params)
    calls = calls + 1
    local expected = calls == 1 and 'wan' or 'ppp'
    assert(params.uci_wan_username == 'uci.network.interface.@' .. expected .. '.username')
    return {}, {}
  end,
} end
local function render()
''' + block + '''
return wan_mode, content, helpmsg
end
values['uci.network.interface.@wan.proto'] = 'dhcp'
local mode, content, helpmsg = render()
assert(mode == 'IPoE' and calls == 0 and next(content) == nil and next(helpmsg) == nil)
values['rpc.network.interface.@wwan.ipaddr'] = '192.0.2.2'
mode = render()
assert(mode == 'Mobile' and calls == 0)
values['rpc.network.interface.@wwan.ipaddr'] = nil
values['uci.network.interface.@wan.proto'] = 'pppoe'
mode = render()
assert(mode == 'PPPoE' and calls == 1)
values['uci.network.interface.@wan.proto'] = nil
mode = render()
assert(mode == 'PPPoE' and calls == 2)
''')

    def test_telstra_missing_mobile_interface_keeps_ethernet_wan(self):
        source = (ROOT.parent / 'telstra_gui/www/telstra-snippets/networkmap.lp').read_text()
        block = source[source.index('local wan_intf = "wan"'):source.index('local wifihtml = {}')]
        self.run_lua('''
local internethelper = helper
local sub, find = string.sub, string.find
values['rpc.network.interface.@wan.ipaddr'] = '192.0.2.1'
values['uci.version.version.@version[0].version'] = '17.2'
local function render()
''' + block + '''
return wan_type, wanhtml
end
local mode, html = render()
assert(mode == 'Ethernet' and html:find('192.0.2.1', 1, true))
assert(not html:find('Exact path not found', 1, true))
values['rpc.network.interface.@wwan.ipaddr'] = '192.0.2.2'
mode, html = render()
assert(mode == 'Mobile' and html:find('192.0.2.2', 1, true))
''')


    def test_bridge_card_renders_local_wan_addresses_and_keeps_pending_bindings(self):
        self.run_lua('''
local printed = {}
gettext = {textdomain = function() end}
ngx = {ctx = {}, print = function(...)
  for _, part in ipairs({...}) do printed[#printed + 1] = tostring(part) end
end}
package.preload['web.ui_helper'] = function() return {
  createSimpleLight = function(light, state) return light .. ':' .. state end,
} end
package.preload['web.post_helper'] = function() return {
  secondsToTimeShort = function(value) return tostring(value) end,
} end
values['uci.network.config.wan_mode'] = 'bridge'
values['uci.network.interface.@wan.auto'] = '1'
values['rpc.network.interface.@wan.ipaddr'] = '192.0.2.7'
values['rpc.network.interface.@wan.ip6addr'] = '2001:db8::7'
values['rpc.network.interface.@wan.up'] = '1'
values['rpc.network.interface.@wan.uptime'] = '123'
for _, protocol in ipairs({'dhcp', 'pppoe', 'static'}) do
  values['uci.network.interface.@wan.proto'] = protocol
  printed = {}
  dofile(CARD)
  local html = table.concat(printed)
  assert(html:find('Gateway in bridge mode', 1, true))
  assert(html:find('192.0.2.7', 1, true) and html:find('2001:db8::7', 1, true))
end
values['rpc.network.interface.@wan.ipaddr'] = ''
values['rpc.network.interface.@wan.ip6addr'] = ''
printed = {}
dofile(CARD)
assert(table.concat(printed):find('data-bind="html: WAN_IP_text"', 1, true))
values['uci.network.interface.@wan.proto'] = 'bridge'
printed = {}
dofile(CARD)
assert(not table.concat(printed):find('data-bind="html: WAN_IP_text"', 1, true))
assert(#writes == 0)
'''.replace('CARD', repr(str(ROOT / 'www/cards/snippets/003_internet_bridged.lp'))))

    def test_bridge_local_session_polling_uses_its_protocol_and_logical_wan(self):
        self.run_lua('''
local output
gettext = {textdomain = function() end}
ngx = {ctx = {}, HTTP_OK = 200,
  req = {get_method = function() return 'POST' end, get_uri_args = function() return {} end},
  say = function() end, exit = function() end}
package.preload['web.content_helper'] = function() return {getExactContent = helper.getOptionalContent} end
package.preload['web.ui_helper'] = function() return {createSimpleLight = function(light, text) return light .. ':' .. text end} end
package.preload['web.post_helper'] = function() return {
  secondsToTime = function() return '' end, secondsToTimeShort = function() return '' end,
} end
package.preload['web.taint'] = function() return {untaint_mt = {}} end
package.preload.dkjson = function() return {encode = function(data) output = data; return true end} end
values['uci.network.config.wan_mode'] = 'bridge'
values['uci.network.interface.@wan.ifname'] = 'br-lan'
values['uci.network.interface.@wan.auto'] = '1'
values['rpc.network.interface.@wan.up'] = '1'
values['rpc.network.interface.@br-lan.up'] = '0'
values['rpc.network.interface.@wan.ipaddr'] = '192.0.2.7'
values['rpc.network.interface.@wan.ppp.state'] = 'connected'
for _, protocol in ipairs({'dhcp', 'pppoe', 'static'}) do
  values['uci.network.interface.@wan.proto'] = protocol
  dofile(ENDPOINT)
  assert(output.status == 'Connected' and output.WAN_IP == '192.0.2.7')
  assert(output.WAN_IP_text:find('192.0.2.7', 1, true))
  assert(output.status_light ~= '')
  if protocol == 'pppoe' then assert(output.ppp_status == 'connected') end
end
values['uci.network.config.wan_mode'] = 'pppoe'
values['uci.network.interface.@wan.proto'] = 'dhcp'
values['rpc.network.interface.@wan.ppp.state'] = ''
dofile(ENDPOINT)
assert(output.status == 'Connected' and not output.status_light:find('PPP', 1, true))
assert(#writes == 0)
'''.replace('ENDPOINT', repr(str(ROOT / 'www/docroot/ajax/internet.lua'))))

    def test_wan_stats_shows_local_bridge_session_but_not_pure_bridge(self):
        self.run_lua('''
local labels = {}
gettext = {textdomain = function() end}
ngx = {print = function() end}
package.preload['web.content_helper'] = function() return {getExactContent = helper.getOptionalContent} end
package.preload['web.ui_helper'] = function() return {
  createCardHeader = function() return '' end,
  createSimpleLight = function() return '' end,
  createLabel = function(label, value) labels[label] = value; return '' end,
} end
package.preload['web.post_helper'] = function() return {secondsToTime = function() return '' end} end
package.preload['web.taint'] = function() return {untaint_mt = {}} end
package.preload['web.dyntab_helper'] = function() return {process = function()
  return {current = {description = 'Ethernet'}}
end} end
package.preload.broadbandmode_helper = function() return {} end
package.preload.internetmode_helper = function() return {
  {name = 'bridge', description = 'Bridge'}, {name = 'dhcp', description = 'DHCP'},
  {name = 'pppoe', description = 'PPPoE'},
} end
values['uci.network.config.wan_mode'] = 'bridge'
values['rpc.network.interface.@wan.ipaddr'] = '192.0.2.7'
for _, protocol in ipairs({'dhcp', 'pppoe', 'static', 'bridge'}) do
  values['uci.network.interface.@wan.proto'] = protocol
  labels = {}
  dofile(INFOCARD)
  if protocol == 'bridge' then assert(labels['IPv4 address'] == nil)
  else assert(labels['IPv4 address'] == '192.0.2.7') end
end
values['uci.network.config.wan_mode'] = 'pppoe'
values['uci.network.interface.@wan.proto'] = 'dhcp'
labels = {}
dofile(INFOCARD)
assert(labels['Connection Type'] == 'DHCP')
assert(#writes == 0)
'''.replace('INFOCARD', repr(str(ROOT / 'www/info-cards/002_wanstats.lp'))))


if __name__ == '__main__':
    unittest.main()
