--pretranslated: do not change this file
 
-- Enable localization
-- NG-88797 WAN statistics is not automatically getting updates as LAN statistics
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local format, match, find, upper = string.format, string.match, string.find, string.upper
local iconUp = "<i class=\"icon-upload icon-large gray\"></i> "
local iconDown = " <i class=\"icon-download icon-large gray\"></i> "
-- Process POST query
local post_helper = require("web.post_helper")
local session = ngx.ctx.session

local tech = false
if session:getrole() == "engineer" then
	tech = true
end

local ppp_state_map = {
  disabled = T"Disabled",
  disconnecting = T"Disconnecting",
  connected = T"Connected",
  connecting = T"Connecting",
  disconnected = T"Disconnected",
  error = T"Error",
  AUTH_TOPEER_FAILED = T"Authentication failed",
  NEGOTIATION_FAILED = T"Negotiation failed",
}

local untaint_mt = require("web.taint").untaint_mt
setmetatable(ppp_state_map, untaint_mt)

local ppp_light_map = {
  disabled = "off",
  disconnected = "red",
  disconnecting = "orange",
  connecting = "orange",
  connected = "green",
  error = "red",
  AUTH_TOPEER_FAILED = "red",
  NEGOTIATION_FAILED = "red",
}

setmetatable(ppp_light_map, untaint_mt)

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

function get_dhcp_state(wan_auto, wan_ppp, wan_error, ipaddr)
    -- Figure out interface state
	if wan_auto ~= "0" then
	  -- WAN enabled
	  if wan_ppp == "" or wan_ppp == "authenticating" or wan_ppp == "networking" or (wan_ppp == "connecting" and not(wan_error == "AUTH_TOPEER_FAILED")) then
		return "connecting"
		elseif wan_ppp == "connected" then
			return "connected"
		elseif wan_ppp == "disconnecting" then
			return "disconnecting"
		elseif wan_ppp == "disconned" then
			return "disconned"
	  end

	  if not (wan_error == "" or wan_error == "USER_REQUEST") then
		if ppp_state_map[wan_error] then
		  return wan_error
		else
		  return "error"
		end
	  end
	else
	  -- WAN disabled
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

local mapParams = {
  uci_wan_auto = "uci.network.interface.@wan.auto",
  uci_wan_username = "uci.network.interface.@wan.username",
  uci_wan_password = "uci.network.interface.@wan.password",
  uci_wan_masq = "uci.firewall.zone."..zonenum..".masq",
}

local mapPPPstats = {
  discardR = "sys.class.net.@pppoe-wan.statistics.rx_dropped",
  discardS = "sys.class.net.@pppoe-wan.statistics.tx_dropped",
  broadcastR = "sys.class.net.@pppoe-wan.statistics.rx_broadcast",
  broadcastS = "sys.class.net.@pppoe-wan.statistics.tx_broadcast",
  multicastR = "sys.class.net.@pppoe-wan.statistics.multicast",
  multicastS = "sys.class.net.@pppoe-wan.statistics.txpckt",
  packetsR = "sys.class.net.@pppoe-wan.statistics.rx_packets",
  packetsS = "sys.class.net.@pppoe-wan.statistics.tx_packets",
  errorsR = "sys.class.net.@pppoe-wan.statistics.rx_errors",
  errorsS = "sys.class.net.@pppoe-wan.statistics.tx_errors",
  bytesR = "sys.class.net.@pppoe-wan.statistics.rx_bytes",
  bytesS = "sys.class.net.@pppoe-wan.statistics.tx_bytes",
  unicastR = "sys.class.net.@pppoe-wan.statistics.rx_unicast",
  unicastS = "sys.class.net.@pppoe-wan.statistics.tx_unicast",
  unknownR = "sys.class.net.@pppoe-wan.statistics.rxerr",
}

content_helper.getExactContent(mapPPPstats)

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gCV = post_helper.getConditionalValidation
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vSIP = post_helper.validateStringIsPort
local gVP = post_helper.getValidationPassword
local gOV = post_helper.getOptionalValidation

local function validateUsername (value, postdata)
  local err,msg = vNES(value)
  if not err then
    return err,msg
  end

  local content_uci = {
    wan_domain = "uci.network.interface.@wan.domain",
  }
  content_helper.getExactContent(content_uci)

  if content_uci["wan_domain"] ~= "" then
    if find(value, "@") then
      return nil, T"Invalid username, domain locked"
    end
    postdata["uci_wan_username"] = format('%s@%s', value, content_uci["wan_domain"])
  end

  return true
end
local firewall_value = {["uci.firewall.forwarding."..forwdnum..".src"] = "wan",
                        ["uci.firewall.forwarding."..forwdnum..".dest"] = "lan",
                        ["uci.firewall.forwarding."..forwdnum..".name"] = "for_w2l"}
local function validateNat(value, object, key)
  local valid, msg = post_helper.validateBoolean(value, object, key)
  if valid and zonenum ~= "" and value ~= proxy.get("uci.firewall.zone."..zonenum..".masq")[1].value then
    proxy.set("uci.firewall.zone."..zonenum..".conntrack", "1")
    if value == "1" then
      if forwdnum == "" then
        forwdnum = proxy.add("uci.firewall.forwarding.")
        proxy.set(firewall_value)
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "0")
      else
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "0")
      end
    else
      if forwdnum == "" then
        forwdnum = proxy.add("uci.firewall.forwarding.")
        proxy.set(firewall_value)
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "1")
      else
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "1")
      end
    end
    proxy.apply()
  end
  return valid, msg
end

local function isWanEnabled(value, object, key)
  return object["uci_wan_auto"] ~= "0"
end

-- Validation allows empty values if wan access disabled but will stil check for validity if the parameter is set
-- if wan is enabled then it checks for validaty anyway
local mapValid = {
  uci_wan_auto = vB,
  uci_wan_username = gCV(isWanEnabled, validateUsername, gOV(validateUsername)),
  uci_wan_password = gCV(isWanEnabled, gVP(vNES), gVP()),
  uci_wan_masq = validateNat,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process

local string = string

local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_domain = "uci.network.interface.@wan.domain",
}
content_helper.getExactContent(content_uci)

local content_rpc = {
  wan_ppp_state = "rpc.network.interface.@wan.ppp.state",
  wan_ppp_error = "rpc.network.interface.@wan.ppp.error",
  wan_ppp_ll_intf = "rpc.network.interface.@wan.ppp.ll_intf",
  ipaddr = "rpc.network.interface.@wan.ipaddr",
  nexthop = "rpc.network.interface.@wan.nexthop",
  dns_wan = "rpc.network.interface.@wan.dnsservers",
  dns_loopback = "rpc.network.interface.@loopback.dnsservers", -- Added to include static dns servers configured on loopback interface (for TI custo)
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
  if intf then
    if intf == "6rd" then
      content_rpc.ip6addr = "rpc.network.interface.@6rd.ip6addr"
      content_rpc.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
      content_rpc.dnsv6 = "rpc.network.interface.@6rd.dnsservers"
    elseif intf == "wan6" then
      content_rpc.ip6addr = "rpc.network.interface.@wan6.ip6addr"
      content_rpc.ip6prefix = "rpc.network.interface.@wan6.ip6prefix"
      content_rpc.dnsv6 = "rpc.network.interface.@wan6.dnsservers"
      break
    elseif intf == "wan" then
      content_rpc.ip6addr = "rpc.network.interface.@wan.ip6addr"
      content_rpc.ip6prefix = "rpc.network.interface.@wan.ip6prefix"
    end
  end
end

ajax_helper.handleAjaxQuery(content_rpc, function(c)
    -- this will add the HTML for the light
    local ds = get_dhcp_state(content["uci_wan_auto"], proxy.get("rpc.network.interface.@wan.ppp.state")[1].value, proxy.get("rpc.network.interface.@wan.ppp.error")[1].value, c["ipaddr"])
	local dnstab = split(proxy.get("rpc.network.interface.@loopback.dnsservers")[1].value, "[^%,]+")
	local dnsv4, dnsv6 = dns_filter(dnstab)
    ajax_attr_light.light.class = ppp_light_map[ds]
    c.wan_status = ui_helper.createSimpleLight(nil, ppp_state_map[ds], ajax_attr_light)
	if proxy.get("rpc.network.interface.@wan.ppp.state")[1].value == "connected" then
		c.dns = content_helper.getMergedList(proxy.get("rpc.network.interface.@wan.dnsservers")[1].value, dnsv4)
	else
		c.dns = dnsv4
		
	end
	if proxy.get("uci.network.interface.@wan.ipv6")[1].value == "1" then
	c.dnsv6 = content_helper.getMergedList(c.dnsv6, dnsv6)
	end
	c.discard = format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.discardS, iconDown, mapPPPstats.discardR)
	c.broadcast = format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.broadcastS, iconDown, mapPPPstats.broadcastR)
	c.multicast = format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.multicastS, iconDown, mapPPPstats.multicastR)
	c.unicast = format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.unicastS, iconDown, mapPPPstats.unicastR)
	c.packets = format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.packetsS, iconDown, mapPPPstats.packetsR)
	c.error = format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.errorsS, iconDown, mapPPPstats.errorsR)
	c.byte =  format("%s %s [B] %s %s [B]", iconUp, mapPPPstats.bytesS, iconDown, mapPPPstats.bytesR)
	c.unknown = format("%s %s [Pkt]", iconDown, mapPPPstats.unknownR)
end)

content_helper.getExactContent(content_rpc)

local dnstab = split(content_rpc.dns_loopback, "[^%,]+")
local dnsv4, dnsv6 = dns_filter(dnstab)
content_rpc.dns = content_helper.getMergedList(content_rpc.dns_wan, dnsv4)
content_rpc.dnsv6 = content_helper.getMergedList(content_rpc.dnsv6, dnsv6)

local wan_atm_uci_path = format("uci.xtm.atmdevice.@%s.", content_rpc["wan_ppp_ll_intf"])
local wan_ppp_over_atm = proxy.get(wan_atm_uci_path) ~= nil
local content_uci_xtm
if wan_ppp_over_atm then
  content_uci_xtm = {
    wan_atm_vpi = wan_atm_uci_path.."vpi",
    wan_atm_vci = wan_atm_uci_path.."vci",
    wan_atm_enc = wan_atm_uci_path.."enc",
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

if content_uci["wan_domain"] ~= "" then
  content["uci_wan_username"] = match(content["uci_wan_username"], "[^@]*")
end


local ppp_status
if content.uci_wan_auto ~= "0" then
  -- WAN enabled
  content.uci_wan_auto = "1"
  ppp_status = format("%s", content_rpc.wan_ppp_state) -- untaint
  if ppp_status == "" or ppp_status == "authenticating" or ppp_status == "networking" then
    ppp_status = "connecting"
  end

  if not (content_rpc.wan_ppp_error == "" or content_rpc.wan_ppp_error == "USER_REQUEST") then
    if ppp_state_map[content_rpc.wan_ppp_error] then
      ppp_status = content_rpc.wan_ppp_error
    else
      ppp_status = "error"
    end
  end
else
  -- WAN disabled
  ppp_status = "disabled"
end

  ngx.print('\
\
<fieldset>\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"PPP connection" ); ngx.print('</legend>\
\
');  
    local html = {}
    -- Label that shows PPP status
	ajax_attr_light.light.class = ppp_light_map[ppp_status]
    html[#html + 1] = ui_helper.createLight(T"Status", nil, ppp_state_map[ppp_status], ajax_attr_light)
    -- Switch PPP on/off
    html[#html + 1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content.uci_wan_auto)
    html[#html + 1] = ui_helper.createSwitch(T"NAT", "uci_wan_masq", content.uci_wan_masq)
    -- PPP username
    local class_username = {
      input = {
        maxlength= "128",
        class = "span6",
      }
    }
	if tech then
    html[#html + 1] = "<div class='control-group'><label class='control-label'>" .. T"Username" .. "</label><div class='controls'>"
    html[#html + 1] = ui_helper.createSimpleInputText("uci_wan_username", content["uci_wan_username"], class_username, helpmsg["uci_wan_username"])
    if content_uci["wan_domain"] ~= "" then
      html[#html + 1] = " @ " .. content_uci["wan_domain"]
    end
    html[#html + 1] = "</div></div>"

    -- PPP password
    local class_password = class_username
    html[#html + 1] = ui_helper.createInputPassword(T"Password", "uci_wan_password", content["uci_wan_password"], class_username, helpmsg["uci_wan_password"])
	end
	ajax_attr.span.id = "ipaddr"
    html[#html+1] = ui_helper.createLabel(T"IP address", content_rpc["ipaddr"], ajax_attr)
	ajax_attr.span.id = "nexthop"
    html[#html+1] = ui_helper.createLabel(T"Gateway", content_rpc["nexthop"], ajax_attr)
	ajax_attr.span.id = "dns"
    html[#html+1] = ui_helper.createLabel(T"DNS servers", content_rpc["dns"], ajax_attr)
	if proxy.get("uci.network.interface.@wan.ipv6")[1].value == "1" then
   --if content_rpc["ip6addr"] and content_rpc["ip6addr"]:len() > 0 then
		ajax_attr.span.id = "ip6addr"
        html[#html+1] = ui_helper.createLabel(T"IPv6 Address", content_rpc["ip6addr"], ajax_attr)
    --end
    --if content_rpc["ip6prefix"] and content_rpc["ip6prefix"]:len() > 0 then
		ajax_attr.span.id = "ip6prefix"
        html[#html+1] = ui_helper.createLabel(T"IPv6 Prefix", content_rpc["ip6prefix"], ajax_attr)
    --end
   --if content_rpc["dnsv6"] and content_rpc["dnsv6"]:len() > 0 then
		ajax_attr.span.id = "dnsv6"
        html[#html+1] = ui_helper.createLabel(T"IPv6 DNS", content_rpc["dnsv6"],ajax_attr)
   --end
   end


    -- ATM VP/VC
    if wan_ppp_over_atm then
      local advanced = {
        group = {
          class = "advanced hide",
        }
      }
      local vp_vc = format("%s / %s", content_uci_xtm["wan_atm_vpi"], content_uci_xtm["wan_atm_vci"])
      html[#html + 1] = ui_helper.createLabel(T"ATM VP / VC", vp_vc, advanced)
      html[#html + 1] = ui_helper.createLabel(T"Encapsulation", upper(content_uci_xtm["wan_atm_enc"]), advanced)
    end

    ngx.print(html)
  ngx.print('\
\
</fieldset>\
\
<fieldset>\
<legend>');  ngx.print( T"PPP statistics" ); ngx.print('</legend>\
');  

        local html = {}
		ajax_attr.span.id = "discard"
		ajax_attr.span.class = "span4 simple-desc"
        html[#html + 1] = ui_helper.createLabel(
            T"Discard Packets",
            format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.discardS, iconDown, mapPPPstats.discardR), ajax_attr
        )
		
		ajax_attr.span.id = "broadcast"
        html[#html + 1] = ui_helper.createLabel(
            T"Broadcast Packets",
            format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.broadcastS, iconDown, mapPPPstats.broadcastR), ajax_attr
        )

		ajax_attr.span.id = "multicast"
        html[#html + 1] = ui_helper.createLabel(
            T"Multicast Packets",
            format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.multicastS, iconDown, mapPPPstats.multicastR), ajax_attr
        )

		ajax_attr.span.id = "unicast"
        html[#html + 1] = ui_helper.createLabel(
            T"Unicast Packets",
            format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.unicastS, iconDown, mapPPPstats.unicastR), ajax_attr
        )

		ajax_attr.span.id = "packets"
        html[#html + 1] = ui_helper.createLabel(
            T"Packets",
            format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.packetsS, iconDown, mapPPPstats.packetsR), ajax_attr
        )

		ajax_attr.span.id = "error"
        html[#html + 1] = ui_helper.createLabel(
            T"Errors",
            format("%s %s [Pkt] %s %s [Pkt]", iconUp, mapPPPstats.errorsS, iconDown, mapPPPstats.errorsR), ajax_attr
        )
		ajax_attr.span.id = "byte"
        html[#html + 1] = ui_helper.createLabel(
            T"Bytes",
            format("%s %s [B] %s %s [B]", iconUp, mapPPPstats.bytesS, iconDown, mapPPPstats.bytesR), ajax_attr
        )

		ajax_attr.span.id = "unknown"
        html[#html + 1] = ui_helper.createLabel(
            T"Unknown Proto Packets",
            format("%s %s [Pkt]", iconDown, mapPPPstats.unknownR), ajax_attr
        )

        ngx.print(html)
  ngx.print('\
\
</fieldset>\
'); 