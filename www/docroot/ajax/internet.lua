-- Enable localization
gettext.textdomain('webui-mobiled')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local json = require("dkjson")
local utils = require("web.lte-utils")

local ppp_status, ppp_light_map, ppp_state_map

local table = table
local format = string.format
local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_auto = "uci.network.interface.@wan.auto",
  wan_ipv6 = "uci.network.interface.@wan.ipv6",
}
content_helper.getExactContent(content_uci)

local content_rpc = {
  wan_ppp_state = "rpc.network.interface.@wan.ppp.state",
  wan_ppp_error = "rpc.network.interface.@wan.ppp.error",
  ipaddr = "rpc.network.interface.@wan.ipaddr",
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = string.match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
  if intf then
    if intf == "6rd" then
      content_rpc.ip6addr = "rpc.network.interface.@6rd.ip6addr"
      content_rpc.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
    elseif intf == "wan6" then
     content_rpc.ip6addr = "rpc.network.interface.@wan6.ip6addr"
     content_rpc.ip6prefix = "rpc.network.interface.@wan6.ip6prefix"
    end
  end
end

content_helper.getExactContent(content_rpc)

local IPv6State = "none"

if content_uci.wan_ipv6 ~= "1" then
     IPv6State = "disabled"
elseif content_rpc.ip6prefix ~= "" then
     IPv6State = "prefix"
elseif content_rpc.ip6prefix == "" then
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

local ppp_state_map = {
    disabled = T"PPP disabled",
    disconnecting = T"PPP disconnecting",
    connected = T"PPP connected",
    connecting = T"PPP connecting",
    disconnected = T"PPP disconnected",
    error = T"PPP error",
    AUTH_TOPEER_FAILED = T"PPP authentication failed",
    NEGOTIATION_FAILED = T"PPP negotiation failed",
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

local ppp_status
if content_uci.wan_auto ~= "0" then
  -- WAN enabled
  content_uci.wan_auto = "1"
  ppp_status = format("%s", content_rpc.wan_ppp_state) -- untaint
  if ppp_status == "" or ppp_status == "authenticating" then
    ppp_status = "connecting"
  elseif not ppp_state_map[ppp_status] then
    ppp_status = "error"
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

local ppp_light, ppp_state, WAN_IP, ipv6_light, ipv6_state
if ppp_status then
  ppp_light = ppp_light_map[ppp_status]
  ppp_state = ppp_state_map[ppp_status]
  if content_rpc["ipaddr"] and content_rpc["ipaddr"]:len() > 0 then
    WAN_IP = content_rpc["ipaddr"]
  elseif content_rpc["ip6addr"] and content_rpc["ip6addr"]:len() > 0 then
    WAN_IP = content_rpc["ip6addr"]
  end
  if ppp_status == "connected" and IPv6State ~= "disabled" then
     ipv6_light = ipv6_light_map[IPv6State]
     ipv6_state = ipv6_state_map[IPv6State]
  end
end

local data = {
  ppp_status = ppp_status or "",
  ppp_light = ppp_light or "" ,
  ppp_state = ppp_state or "",
  WAN_IP = WAN_IP or "",
  ipv6_light = ipv6_light or "",
  ipv6_state = ipv6_state or ""
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
 ngx.header.content_type = "application/json"
 ngx.print(buffer)
else
 ngx.print("{}")
end

