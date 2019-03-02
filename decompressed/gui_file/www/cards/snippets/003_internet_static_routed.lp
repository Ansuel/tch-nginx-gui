--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local format = string.format

local attributes = { light = { } ,span = { class = "span4" } }

-- Non-configurable data
local content_rpc = {
    uci_wan_auto = "uci.network.interface.@wan.auto",
    ipaddr = "rpc.network.interface.@wan.ipaddr",
}

content_helper.getExactContent(content_rpc)

-- Figure out interface state
local static_state = "disabled"
local static_state_map = {
    disabled = T"Static disabled",
    connected = T"Static on",
}

local static_light_map = {
  disabled = "0",--"off",
  connected = "1",--"green",
}

if content_rpc["uci_wan_auto"] ~= "0" and content_rpc["ipaddr"]:len() > 0 then
    content_rpc["uci_wan_auto"] = "1"
    static_state = "connected"
end

local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    modalPath = "/modals/internet-modal.lp"
end

ngx.print('\
<span id="static-internet-tab">\
  <span data-bind="html: status_light">\
  '); ngx.print( ui_helper.createSimpleLight(static_light_map[static_state], static_state_map[static_state] , attributes , "fa-at") ); ngx.print('\
  </span>\
  <p class="subinfos">')
	 local WAN_IP_text = '<span data-bind="html: WAN_IP_text"></span>'
	 local uptime_text = '<span data-bind="html: uptime_text"></span>'
     if ppp_status == "connected" then
       if content_rpc["ipaddr"] and content_rpc["ipaddr"]:len() > 0 then
		 WAN_IP_text = '<span data-bind="html: WAN_IP_text">'..format(T'WAN IP is <strong>%s</strong>'..'<br/>', content_rpc["ipaddr"])..'</span>'
	     if content_rpc["uptime"] then
		   uptime_text = '<span data-bind="html: uptime_text">'..format(T"Uptime : <strong>%s</strong>",(post_helper.secondsToTimeShort(content_rpc["uptime"]) or ""))..'</span>'
		 end
		end
     end
     ngx.print(WAN_IP_text)
	 ngx.print(uptime_text)
	ngx.print('\
  </p>\
</span>\
<script>\
var StaticCardInterval;\
$(document).ready(function () {\
	new createAjaxUpdateCard("static-internet-tab","/ajax/internet.lua",StaticCardInterval,3000);\
})\
</script>\
');