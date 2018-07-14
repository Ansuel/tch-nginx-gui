--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")

local attributes = { light = { } ,span = { class = "span4" } }
local table = table
local format = string.format
local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_auto = "uci.network.interface.@wan.auto",
  wan_ipv6 = "uci.network.interface.@wan.ipv6",
}
content_helper.getExactContent(content_uci)

local content_rpc = {
  uptime = "rpc.network.interface.@wan.uptime",
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
    none = "0",--"off"
    noprefix = "2",--"orange"
    prefix = "1",--"green"
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
    disabled = "0",--"off"
    disconnected = "4",--"red"
    disconnecting = "2",--"orange"
    connecting = "2",--"orange"
    connected = "1",--"green"
    error = "4",--"red"
    AUTH_TOPEER_FAILED = "4",--"red"
    NEGOTIATION_FAILED = "4",--"red"
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

local switchName = nil
local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    switchName = "uci_wan_auto"
    modalPath = "/modals/internet-modal.lp"
end

attributes.light.id = "Internet_State_Led"
attributes.span.id = "Internet_State_Enabled"

ngx.print( ui_helper.createCardHeader(T"Internet Access", modalPath, switchName, content_uci.wan_auto) )
ngx.print('\
<div id="pppoe-internet-tab" class="content card_bg" data-bg-text="&#xf0ac;">\
<div class="divtable">\
  '); ngx.print( ui_helper.createSimpleLight(ppp_light_map[ppp_status], ppp_state_map[ppp_status] , attributes , "fa-globe") ); ngx.print('\
  <p class="subinfos">')
     if ppp_status == "connected" then
       if content_rpc["ipaddr"] and content_rpc["ipaddr"]:len() > 0 then
         ngx.print(format(T'WAN IP is <strong>%s</strong>' .. "<br/>", content_rpc["ipaddr"]))
	     if IPv6State == "disabled" and content_rpc["uptime"] then
		   ngx.print(T"Uptime" .. ": " .. '<strong data-bind="text: pppoe_uptime"></strong>')
		 end
       elseif content_rpc["ip6addr"] and content_rpc["ip6addr"]:len() > 0 then
	 ngx.print(format(T'WAN IP is <strong>%s</strong>', content_rpc["ip6addr"]))
       end
	   if ppp_status == "connected" and IPv6State ~= "disabled" then
         ngx.print(ui_helper.createSimpleLight(ipv6_light_map[IPv6State] or "4" --[[ red ]] , ipv6_state_map[IPv6State] or T"Unknown", attributes,"fa-globe"))
        end
     end
	ngx.print('\
  </p>\
</div>\
</div>\
<script>\
$(document).ready(function () {\
		var PPPoEInternetCard = function () {\
			var self = this;\
			this.pppoe_uptime = ko.observable("");\
			this.refresh = function () {\
				$.post("/ajax/internet.lua?auto_update=true", [tch.elementCSRFtoken()], function(data) {\
					if(data.pppoe_uptime != undefined) {\
						self.pppoe_uptime(data.pppoe_uptime);\
					}\
				}, "json");\
			};\
			setInterval(self.refresh, 5000);\
			self.refresh();\
		};\
\
		var PPPoEInternetCard = new PPPoEInternetCard();\
		ko.applyBindings(PPPoEInternetCard, document.getElementById("pppoe-internet-tab"));\
})\
</script>\
');