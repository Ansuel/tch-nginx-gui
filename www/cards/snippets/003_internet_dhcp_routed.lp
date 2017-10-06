<%
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local format = string.format
local match = string.match

local function getNetIntfPath(protocol)
	local uciPath = "uci.network.interface.@wan."
	local rpcPath = "rpc.network.interface.@wan."

	local content_wan = {
		wan_protype = "uci.network.interface.@wan.proto",
	}
	content_helper.getExactContent(content_wan)
	if content_wan.wan_protype ~= protocol then
		uciPath = "uci.network.interface.@wan2."
		rpcPath = "rpc.network.interface.@wan2."
	end

	return uciPath, rpcPath
end

local content_uci = {
  wan_ipv6 = "uci.network.interface.@wan.ipv6",
}

for _,rpcPath in ipairs(proxy.getPN("rpc.network.interface.", true)) do
   local intf = match(rpcPath.path, "rpc%.network%.interface%.@([^%.]+)%.")
     if intf == "6rd" then
       content_uci.ip6addr = "rpc.network.interface.@6rd.ip6addr"
       content_uci.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
     elseif intf == "wan6" then
       content_uci.ip6addr = "rpc.network.interface.@wan6.ip6addr"
       content_uci.ip6prefix = "rpc.network.interface.@wan6.ip6prefix"
     end
end

content_helper.getExactContent(content_uci)

local uci_dhcp_path, rpc_dhcp_path = getNetIntfPath("dhcp")

-- Non-configurable data
local cs = {
    uci_wan_auto = uci_dhcp_path.."auto",
    ipaddr = rpc_dhcp_path.."ipaddr",
}

local IPv6State = "none"

if content_uci.wan_ipv6 ~= "1" then
	IPv6State = "disabled"
elseif content_uci.ip6prefix ~= "" then
	IPv6State = "prefix"
elseif content_uci.ip6prefix == "" then
	IPv6State = "noprefix"
end

local untaint_mt = require("web.taint").untaint_mt
local ipv6_state_map = {
     none = T"IPv6 Disabled",
     noprefix = T"IPv6 Connecting",
     prefix = T"IPv6 Connected",
}
setmetatable(ipv6_state_map, untaint_mt)

local ipv6_light_map = {
     none = "off",
     noprefix = "orange",
     prefix = "green",
}
setmetatable(ipv6_light_map, untaint_mt)

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
    if intf == "6rd" then
      cs.ip6addr = "rpc.network.interface.@6rd.ip6addr"
    elseif intf == "wan6" then
      cs.ip6addr = "rpc.network.interface.@wan6.ip6addr"
    elseif intf == "wan" then
      cs.ip6addr = "rpc.network.interface.@wan.ip6addr"
    end
end

content_helper.getExactContent(cs)

-- Figure out interface state
local dhcp_state = "connecting"
local dhcp_state_map = {
    disabled = T"DHCP disabled",
    connected = T"DHCP on",
    connecting = T"DHCP connecting",
}

local dhcp_light_map = {
  disabled = "off",
  connecting = "orange",
  connected = "green",
}

if cs["uci_wan_auto"] ~= "0" then
    cs["uci_wan_auto"] = "1"
    if cs["ipaddr"]:len() > 0 then
        dhcp_state = "connected"
    else
        dhcp_state = "connecting"
    end
else
    dhcp_state = "disabled"
end

local switchName = nil
local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    switchName = "uci_wan_auto"
    modalPath = "/modals/internet-modal.lp"
end

%>

<%= ui_helper.createCardHeader(T"Internet Access", modalPath) %>
<div class="content">
  <%= ui_helper.createSimpleLight(nil, dhcp_state_map[dhcp_state], { light = { class = dhcp_light_map[dhcp_state], id = "Internet_DHCP_LED" }, span = {id = "Internet_DHCP_Status"} }) %>
  <p class="subinfos">
     <%if dhcp_state == "connected" then
        if cs["ipaddr"] and cs["ipaddr"]:len() > 0 then
	  ngx.print(format(T'WAN IP is <strong id ="wan_ip">%s</strong>', cs["ipaddr"]))
	elseif cs["ip6addr"] and cs["ip6addr"]:len() > 0 then
	  ngx.print(format(T'WAN IP is <strong id ="wan_ip">%s</strong>', cs["ip6addr"]))
	end
	if dhcp_state == "connected" and IPv6State ~= "disabled" then
          ngx.print(ui_helper.createSimpleLight(nil, ipv6_state_map[IPv6State] or T"Unknown", { light = { class = ipv6_light_map[IPv6State] or "red" } }))
	end
      end%>
  </p>
</div>
