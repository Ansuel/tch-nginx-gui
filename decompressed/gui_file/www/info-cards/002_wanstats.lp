--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")
local dyntab_helper = require("web.dyntab_helper")
local untaint_mt = require("web.taint").untaint_mt

local bmh = require("broadbandmode_helper")

local tabdata = dyntab_helper.process(bmh)

-- Process the selected mode if any
local imh = require("internetmode_helper")

local mode_data = {}
local mode_default = "" -- the default mode to use
for _,v in ipairs(imh) do
    mode_data[v.name] = v
    if v.default == true then
        mode_default = v.name
    end
end

mode_data = setmetatable(mode_data, untaint_mt)

local mode_active = "default"
local content_mode = {
    mode_active = "uci.network.config.wan_mode",
    wan_proto = "uci.network.interface.@wan.proto",
    wwan_up = "rpc.network.interface.@wwan.up",
}
content_helper.getExactContent(content_mode)
if content_mode.mode_active ~= "" then
    -- Get current mode by 'wan_mode'
    mode_active = content_mode.mode_active
elseif content_mode.wan_proto ~="" then
    --'wan_mode' not there, then get @wan.proto
    mode_active = content_mode.wan_proto
end

local content = {
  wan_ppp_state = "rpc.network.interface.@wan.ppp.state",
  wan_ppp_error = "rpc.network.interface.@wan.ppp.error",
  wan_ppp_ll_intf = "rpc.network.interface.@wan.ppp.ll_intf",
  up = "rpc.network.interface.@wan.up",
  ipaddr = "rpc.network.interface.@wan.ipaddr",
  nexthop = "rpc.network.interface.@wan.nexthop",
  dns_wan = "rpc.network.interface.@wan.dnsservers",
  uptime = "rpc.network.interface.@wan.uptime",
}

content_helper.getExactContent(content)

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
	
	basic.span["data-bind"] = "text: status"
    html[#html + 1] = ui_helper.createLabel(T"Status", ui_helper.createSimpleLight(content.up, content.up == "1" and T"Connected" or T"Disconnected", nil, "fa fa-at"), basic)
	basic.span["data-bind"] = nil
	html[#html + 1] = ui_helper.createLabel(T"Broadband Connection", tabdata.current.description , basic)
	html[#html + 1] = ui_helper.createLabel(T"Connection Type", mode_data[mode_active].description , basic)
	basic.span["data-bind"] = "text: wanip"
	html[#html+1] = ui_helper.createLabel(T"IP address", content["ipaddr"], basic)
	basic.span["data-bind"] = "text: wangateway"
	html[#html+1] = ui_helper.createLabel(T"Gateway", content["nexthop"], basic)
	basic.span["data-bind"] = "text: wandns"
	html[#html+1] = ui_helper.createLabel(T"DNS servers", content["dns_wan"], basic)
	basic.span["data-bind"] = "text: wanuptime"
	html[#html + 1] = ui_helper.createLabel(T"Uptime", content["uptime"],  basic)
	
	ngx.print(html)
ngx.print('\
	  </fieldset>\
	  </form>\
	  </div>\
    </div>\
  </div>\
</div>\
<script>\
var InfoWanStatsCardInterval;\
$(document).ready(function () {\
	new createAjaxUpdateCard("wanstatsinfotab","/ajax/internet.lua",InfoWanStatsCardInterval,5000);\
})\
</script>\
'); 
