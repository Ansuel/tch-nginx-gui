--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")
local bridge = require("bridgehelper")
local internethelper = require("internethelper")

local content_uci = {
    mode_active = "uci.network.config.wan_mode",
    wan_ifname = "uci.network.interface.@wan.ifname",
    wan_proto = "uci.network.interface.@wan.proto",
}
internethelper.getOptionalContent(content_uci)
local mode_active = internethelper.getConnectionMode(content_uci.mode_active, content_uci.wan_proto, content_uci.wan_ifname)
local connection_description
for _, mode in ipairs(require("internetmode_helper")) do
    if mode.name == mode_active then
        connection_description = mode.description
        break
    end
end

local broadband_description = T"Unknown"
local uplink = mode_active == "bridge" and bridge.resolveUplink(bridge.getUplink(true))
if mode_active ~= "bridge" or uplink then
    for _, mode in ipairs(require("broadbandmode_helper")) do
        if mode.check(uplink) then
            broadband_description = mode.description
            break
        end
    end
end

local proto = content_uci.wan_proto
local local_connection = proto == "dhcp" or proto == "pppoe" or proto == "pppoa" or proto == "static"
local show_connection = mode_active ~= "bridge" or local_connection

local content = {
  up = "rpc.network.interface.@wan.up",
  ipaddr = "rpc.network.interface.@wan.ipaddr",
  concentrator_name = "rpc.network.interface.@wan.ppp.access_concentrator_name",
  nexthop = "rpc.network.interface.@wan.nexthop",
  dns_wan = "rpc.network.interface.@wan.dnsservers",
  uptime = "rpc.network.interface.@wan.uptime",
}

for v6Key, v6Value in pairs(internethelper.getIpv6Content()) do
	content[v6Key] = v6Value
end

internethelper.getOptionalContent(content)
content.ip6addr = content.ip6addr or ""

if not ( content["uptime"] == "" ) then
	content["uptime"] = post_helper.secondsToTime(content["uptime"])
end

if content.dns_wan:match(",") then
	content.dns_wan = content.dns_wan:gsub(","," , ")
end

  ngx.print('\
\
<div class="infocard" id="wanstatsinfotab">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"WAN Stats", nil, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf0ac;">\
	<div class="divtable">\
	<form class="form-horizontal">\
	<fieldset>');
	
	local basic = {
      span = {
        class = "span4"
      },
    }
	
	local html = {}
	
	if show_connection then
		basic.span["data-bind"] = "text: status"
		html[#html + 1] = ui_helper.createLabel(T"Status", ui_helper.createSimpleLight(content.up, content.up == "1" and T"Connected" or T"Disconnected", nil, "fa fa-at"), basic)
	end
	basic.span["data-bind"] = nil
	html[#html + 1] = ui_helper.createLabel(T"Broadband Connection", broadband_description, basic)
	html[#html + 1] = ui_helper.createLabel(T"Connection Type", connection_description, basic)
	if show_connection then
		basic.span["data-bind"] = "text: WAN_IP"
		html[#html+1] = ui_helper.createLabel(T"IPv4 address", content["ipaddr"], basic)
		basic.span["data-bind"] = "text: WAN_IPv6"
		html[#html+1] = ui_helper.createLabel(T"IPv6 address", content["ip6addr"], basic)
		if content_uci.wan_proto:match("ppp") and content["concentrator_name"] ~= "" then
			basic.span["data-bind"] = "text: concentrator_name"
			html[#html+1] = ui_helper.createLabel(T"Concentrator Name", content["concentrator_name"], basic)
		end
		basic.span["data-bind"] = "text: wangateway"
		html[#html+1] = ui_helper.createLabel(T"Gateway", content["nexthop"], basic)
		basic.span["data-bind"] = "text: wandns"
		html[#html+1] = ui_helper.createLabel(T"DNS servers", content["dns_wan"], basic)
		basic.span["data-bind"] = "text: wan_uptime_extended"
		html[#html + 1] = ui_helper.createLabel(T"Uptime", content["uptime"],  basic)
	end
	
	ngx.print(html)
ngx.print('\
	  </fieldset>\
	  </form>\
	  </div>\
    </div>\
  </div>\
</div>\
<script>\
$(document).ready(function () {\
	new modgui.createAjaxUpdateCard("wanstatsinfotab","/ajax/internet.lua","InfoWanStatsCardInterval",5000);\
})\
</script>\
'); 
