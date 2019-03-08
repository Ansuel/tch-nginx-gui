--pretranslated: do not change this file
 
-- NG-84683; NG-89573 

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local tonumber = tonumber
local match, format = string.match, string.format
local post_helper = require("web.post_helper")
local session = ngx.ctx.session
-- State data
local dhcp_state = "connecting"
local dhcp_state_map = {
    disabled = T"Disabled",
    connected = T"Connected",
    connecting = T"Connecting",
}

local dhcp_light_map = {
  disabled = "off",
  connecting = "orange",
  connected = "green",
}

local ajax_attr = {
    span = {
      ["data-ajaxrefresh"] = "5",
    }
}
local ajax_attr_light = {
    light = {
        class = "",
	id = "DHCP_Status_LED"
    },
    controls = {
        id = "wan_status",
        ["data-ajaxrefresh"] = "5",
    }
}

local vSII = post_helper.validateStringIsIP
local gOV = post_helper.getOptionalValidation

local dns_options = {
    tableid = "dns_servers",
    basepath = "uci.network.interface.@wan.dns.@.",
    createMsg = T"Add new DNS server",
    minEntries = 0,
    maxEntries = 3,
}

local dns_columns = {
    {
        header = T"DNS IP",
        name = "dns_server",
        param = "value",
        type = "text",
    }
}

local dns_valid = {
    dns_server = gOV(vSII)
}

local dns_data, dns_helpmsg = post_helper.handleTableQuery(dns_columns, dns_options, nil, nil, dns_valid)
session:store("dns_data",dns_data)

local function get_dhcp_state(wan_auto, ipaddr)
    -- Figure out interface state
    if wan_auto ~= "0" then
        if ipaddr:len() > 0 then
            return "connected"
        else
            return "connecting"
        end
    else
        return "disabled"
    end
end

local function split(str, ang)
	local tab = {}
	for vari in string.gfind(format("%s",str), ang) do
		table.insert(tab, vari)
	end
	return tab
end 

local function dns_filter(tab)
	local ipv4_dns = ""
	local ipv6_dns = ""
	
	for _,v in ipairs(tab) do
		if match(v, "^(%d+)%.(%d+)%.(%d+)%.(%d+)$") then
			ipv4_dns=ipv4_dns..format("%s,", v)
		else
			ipv6_dns=ipv6_dns..format("%s,", v)
		end
	end
	
	if #ipv4_dns > 1 then
		ipv4_dns = string.sub(ipv4_dns,1,#ipv4_dns-1)
	end
	if #ipv6_dns > 1 then
		ipv6_dns = string.sub(ipv6_dns,1,#ipv6_dns-1)
	end
	return ipv4_dns, ipv6_dns
end
-- Process POST query
local post_helper = require("web.post_helper")
local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.",firewall_zone)
local zonenum = ""
for _, v in ipairs(firewall_zone_path) do
  if (v["name"] == "wan") then
    zonenum = v["paramindex"]
    break
  end
end
local firewall_forwarding = proxy.get("uci.firewall.forwarding.")
local firewall_forwarding_path = content_helper.convertResultToObject("uci.firewall.forwarding.",firewall_forwarding)
local forwdnum = ""
for _, v in ipairs(firewall_forwarding_path) do
  if (v["src"] == "wan" and v["dest"] == "lan") then
    forwdnum = v["paramindex"]
    break
  end
end
local firewall_value = {["uci.firewall.forwarding.@"..forwdnum..".src"] = "wan",
                        ["uci.firewall.forwarding.@"..forwdnum..".dest"] = "lan",
                        ["uci.firewall.forwarding.@"..forwdnum..".name"] = "for_w2l"}
local function validateNat(value, object, key)
  local valid, msg = post_helper.validateBoolean(value, object, key)
  if valid and zonenum ~= "" and value ~= proxy.get("uci.firewall.zone."..zonenum..".masq")[1].value then
    proxy.set("uci.firewall.zone."..zonenum..".conntrack", "1")
    local key = "forwarding"..post_helper.getRandomKey()
    if value == "1" then
      if forwdnum == "" then
        forwdnum = proxy.add("uci.firewall.forwarding.", key)
        proxy.set(firewall_value)
        proxy.set("uci.firewall.forwarding.@"..forwdnum..".enabled", "0")
      else
        proxy.set("uci.firewall.forwarding.@"..forwdnum..".enabled", "0")
      end
    else
      if forwdnum == "" then
        forwdnum = proxy.add("uci.firewall.forwarding.", key)
        proxy.set(firewall_value)
        proxy.set("uci.firewall.forwarding.@"..forwdnum..".enabled", "1")
      else
        proxy.set("uci.firewall.forwarding.@"..forwdnum..".enabled", "1")
      end
    end
    proxy.apply()
  end
  return valid, msg
end

-- Configurable data
local mapParams = {
    uci_wan_auto = "uci.network.interface.@wan.auto",
    uci_wan_masq = "uci.firewall.zone."..zonenum..".masq",
	uci_wan_ipv6 = "uci.network.interface.@wan.ipv6", --custo TCOMITAGW-2157
    uci_wan_mac = "uci.network.interface.@wan.macaddr",
    uci_wan_peerdns = "uci.network.interface.@wan.peerdns",
}

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean

------------------custo start TCOMITAGW-2157
local function IPv6andUsername(value, object, key)
	local valid, msg = vB(value)
	
	if valid then
	local ipv6_realm = proxy.get("uci.env.var.ppp_realm_ipv6")[1].value
	local ipv4_realm = proxy.get("uci.env.var.ppp_realm_ipv4")[1].value
		if value == "1" then
			proxy.set("uci.network.interface.@wan6.auto", "1")
			proxy.set("uci.network.interface.@wan.username", ipv6_realm)
			proxy.set("uci.network.device.@waneth4.ipv6", "1")
			proxy.set("uci.network.device.@wanptm0.ipv6", "1")			
		else
			proxy.set("uci.network.interface.@wan6.auto", "0")
			proxy.set("uci.network.interface.@wan.username", ipv4_realm)
			proxy.set("uci.network.device.@waneth4.ipv6", "0")
			proxy.set("uci.network.device.@wanptm0.ipv6", "0")
		end
	proxy.apply()
	end
	return valid, msg
end
-----------------custo end TCOMITAGW-2157

local mapValid = {
    uci_wan_auto = vB,
    uci_wan_masq = validateNat,
	uci_wan_ipv6 = IPv6andUsername,--custo TCOMITAGW-2157
    uci_wan_mac = gOV(post_helper.validateStringIsMAC),
    uci_wan_peerdns = vB,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- default value
if content["uci_wan_auto"] ~= "0" then
    content["uci_wan_auto"] = "1"
end

local wan_ppp_ll_intf = proxy.get("rpc.network.interface.@wan.ppp.ll_intf")
local wan_ppp_over_atm = ""
local wan_atm_uci_path = ""

if wan_ppp_ll_intf and wan_ppp_ll_intf[1].value then
	wan_ppp_ll_intf = wan_ppp_ll_intf[1].value
	wan_atm_uci_path = format("uci.xtm.atmdevice.@%s.", wan_ppp_ll_intf)
	wan_ppp_over_atm = proxy.get(wan_atm_uci_path) ~= nil
else
	wan_ppp_ll_intf = ""
end

if wan_ppp_over_atm then
  local content_uci_xtm = {
    wan_atm_ulp = wan_atm_uci_path.."ulp",
    wan_vpi = "uci.network.interface.@wan.vpi",
    wan_vci = "uci.network.interface.@wan.vci",
  }
  content_helper.getExactContent(content_uci_xtm)

  local params = {}
  local setting = false
  if content_uci_xtm.wan_vpi ~= "" then
    params["uci.network.interface.@wan.vpi"] = ""
    setting = true
  end
  if content_uci_xtm.wan_vci ~= "" then
    params["uci.network.interface.@wan.vci"] = ""
    setting = true
  end
  if content_uci_xtm.wan_atm_ulp ~= "eth" then
    params[wan_atm_uci_path.."ulp"] = "eth"
    setting = true
  end

  if setting then
    proxy.set(params)
    proxy.apply()
  end
end

-- Non-configurable data
local cs = {
    ipaddr = "rpc.network.interface.@wan.ipaddr",
    nexthop = "rpc.network.interface.@wan.nexthop",
    dns_wan = "rpc.network.interface.@wan.dnsservers",
    dns_loopback = "rpc.network.interface.@loopback.dnsservers", -- Added to include static dns servers configured on loopback interface (for TI custo)
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
    local intf = match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
    if intf then
        if intf == "6rd" then
            cs.ip6addr = "rpc.network.interface.@6rd.ip6addr"
	    cs.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
	    cs.dnsv6 = "rpc.network.interface.@6rd.dnsservers"
        elseif intf == "wan6" then
            cs.ip6addr = "rpc.network.interface.@wan6.ip6addr"
	    cs.ip6prefix = "rpc.network.interface.@wan6.ip6prefix"
	    cs.dnsv6 = "rpc.network.interface.@wan6.dnsservers"
            break
        elseif intf == "wan" then
              cs.ip6addr = "rpc.network.interface.@wan.ip6addr"
              cs.ip6prefix = "rpc.network.interface.@wan.ip6prefix"
        end
    end
end

local dhcp_lease = {
        uptime = "rpc.system.uptime",
        connect_time = "uci.network.interface.@wan.connect_time",
        lease = "uci.network.interface.@wan.lease",
        lease_expires = "uci.network.interface.@wan.lease_expires",
}

function getLeaseTime(uptime, lease, expires)
    local leaseobtained = os.date("%F %T", os.time() - (tonumber(uptime) - (tonumber(expires ~="" and expires or 0) - tonumber(lease ~="" and lease or 0))))
    local leaseexpires = os.date("%F %T", os.time() + (tonumber(expires ~="" and expires or 0) - tonumber(uptime)))
    return leaseobtained, leaseexpires
end
ajax_helper.handleAjaxQuery(cs, function(c)
    -- this will add the HTML for the light
    local ds = get_dhcp_state(content["uci_wan_auto"], c["ipaddr"])
	local dnstab = split(proxy.get("rpc.network.interface.@loopback.dnsservers")[1].value, "[^%,]+")
	local dnsv4, dnsv6 = dns_filter(dnstab)
    ajax_attr_light.light.class = dhcp_light_map[ds]
    c.wan_status = ui_helper.createSimpleLight(nil, dhcp_state_map[ds], ajax_attr_light)
	if proxy.get("uci.network.interface.@wan.auto")[1].value == "1" then
		c.dns = content_helper.getMergedList(proxy.get("rpc.network.interface.@wan.dnsservers")[1].value, dnsv4)
	else
		c.dns = dnsv4
	end
    local ipv6_enabled = proxy.get("uci.network.interface.@wan.ipv6")
    if ipv6_enabled and ipv6_enabled[1].value == "1" then
		c.dnsv6 = content_helper.getMergedList(c.dnsv6, dnsv6)
	end
	if ds == "connected" then
        content_helper.getExactContent(dhcp_lease)
        c["leaseobtained"], c["leaseexpires"] = getLeaseTime(dhcp_lease["uptime"],  dhcp_lease["lease"], dhcp_lease["lease_expires"])
    end
end)
-- will stop in handleAjaxQuery if it is an actual AJAX query
content_helper.getExactContent(cs)

local dnstab = split(cs.dns_loopback, "[^%,]+")
local dnsv4, dnsv6 = dns_filter(dnstab)
cs.dns = content_helper.getMergedList(cs.dns_wan, dnsv4)
if dnsv6 and cs.dnsv6 then
	cs.dnsv6 = content_helper.getMergedList(cs.dnsv6, dnsv6)
end

-- account for inconsistencies in DNS display format by removing extra spaces
if cs["dns"] and cs["dns"]:len() > 0 then
    cs["dns"] = cs["dns"]:gsub("%s+", "")
end
if cs["dnsv6"] and cs["dnsv6"]:len() > 0 then
    cs["dnsv6"] = cs["dnsv6"]:gsub("%s+", "")
end

dhcp_state = get_dhcp_state(content["uci_wan_auto"], cs["ipaddr"])

-- dhcp lease data
cs["leaseobtained"] = ""
cs["leaseexpires"] = ""
if dhcp_state == "connected" then

    content_helper.getExactContent(dhcp_lease)
	cs["leaseobtained"],  cs["leaseexpires"] = getLeaseTime(dhcp_lease["uptime"],  dhcp_lease["lease"], dhcp_lease["lease_expires"]) 
end

  ngx.print('\
\
<fieldset>\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"DHCP connection" ); ngx.print('</legend>\
\
');  
    local html = {}
    ajax_attr_light.light.class = dhcp_light_map[dhcp_state]
    html[#html + 1] = ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], ajax_attr_light)
    html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content["uci_wan_auto"])
    html[#html + 1] = ui_helper.createSwitch(T"NAT", "uci_wan_masq", content.uci_wan_masq)
    html[#html + 1] = ui_helper.createInputText(T"MAC Spoof (Wan MAC)","uci_wan_mac", content["uci_wan_mac"], nil, helpmsg["uci_wan_mac"])
    ajax_attr.span.id = "leaseobtained"
    html[#html+1] = ui_helper.createLabel(T"Lease obtained", cs["leaseobtained"], ajax_attr)
    ajax_attr.span.id = "leaseexpires"
    html[#html+1] = ui_helper.createLabel(T"Lease expires", cs["leaseexpires"], ajax_attr)
    ajax_attr.span.id = "ipaddr"
    html[#html+1] = ui_helper.createLabel(T"IP address", cs["ipaddr"], ajax_attr)
    ajax_attr.span.id = "nexthop"
    html[#html+1] = ui_helper.createLabel(T"Gateway", cs["nexthop"], ajax_attr)
    ajax_attr.span.id = "dns"
    html[#html+1] = ui_helper.createLabel(T"DNS servers", cs["dns"],ajax_attr)
	local ipv6_enabled = proxy.get("uci.network.interface.@wan.ipv6")
	if ipv6_enabled and ipv6_enabled[1].value == "1" then
		if cs["ip6addr"] and cs["ip6addr"]:len() > 0 then
			ajax_attr.span.id = "ip6addr"
			html[#html+1] = ui_helper.createLabel(T"IPv6 address", cs["ip6addr"], ajax_attr)
		end
		if cs["ip6prefix"] and cs["ip6prefix"]:len() > 0 then
			ajax_attr.span.id = "ip6prefix"
			html[#html+1] = ui_helper.createLabel(T"IPv6 Prefix", cs["ip6prefix"], ajax_attr)
		end
		if cs["dnsv6"] and cs["dnsv6"]:len() > 0 then
			-- make sure auto-refresh updates control with ONLY DNSv6 servers
			ajax_attr.span.id = "dnsv6"
			html[#html+1] = ui_helper.createLabel(T"IPv6 DNS", cs["dnsv6"], ajax_attr)
		end
	end
    if content["uci_wan_peerdns"] == "" then
        content["uci_wan_peerdns"] = "1"
    end
    html[#html+1] = ui_helper.createSwitch(T"Auto Discover DNS", "uci_wan_peerdns", content["uci_wan_peerdns"])
    html[#html+1] = format('<label class="control-label">%s</label><div class="controls">', T"DNS servers")
    html[#html+1] = ui_helper.createTable(dns_columns, dns_data, dns_options, nil, dns_helpmsg)

    ngx.print(html)
  ngx.print('\
\
</fieldset>\
'); 