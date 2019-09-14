--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local insert, format = table.insert, string.format

local dhcpState_text = ""
local dhcpState

local mapParams = {
    dhcpv4State = "uci.dhcp.dhcp.@lan.dhcpv4",
    dhcpIgnore = "uci.dhcp.dhcp.@lan.ignore",
    localdevIP = "uci.network.interface.@lan.ipaddr",
    localdevmask = "uci.network.interface.@lan.netmask",
    dhcpv6State = "uci.dhcp.dhcp.@lan.dhcpv6",
    raState = "uci.dhcp.dhcp.@lan.ra",
    localIPv6Prefix = "rpc.network.interface.@lan.ip6prefix_assignment"
}
content_helper.getExactContent(mapParams)

if mapParams["dhcpIgnore"] == "1" or mapParams["dhcpv4State"] == "disabled" then
  dhcpState_text = T"DHCP disabled"
  dhcpState = "0"
else
  dhcpState_text = T"DHCP enabled"
  dhcpState = "1"
end

local LANv6 = "none"

if mapParams["dhcpv6State"] == "server" and mapParams["raState"] == "server" then
    LANv6 = "noprefix"
    if mapParams["localIPv6Prefix"] ~= "" then
      LANv6 = "prefix"
    end
end

local ipv6_state_map = {
    none = T"IPv6 Disabled",
    noprefix = T"IPv6 Not Assigned",
    prefix = T"IPv6 Assigned",
}

setmetatable(ipv6_state_map, untaint_mt)

local ipv6_light_map = {
    none = "0", --"off"
    noprefix = "2", --"orange"
    prefix = "1", --"green"
}
setmetatable(ipv6_light_map, untaint_mt)

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/ethernet-modal.lp") then
    modalPath = "/modals/ethernet-modal.lp"
end
  ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"Local Network", modalPath, switchName, nil) ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf015;">\
	  <div class="divtable">\
\
      ');  
        ngx.print(
            ui_helper.createSimpleLight(dhcpState, dhcpState_text, nil,"fa fa-home" ),
            '<p class="subinfos">',
            format(T'Gateway IP is <strong id="Gateway_Ip">%s</strong> and Mask is <strong id="Netmask_Ip">%s</strong>', mapParams["localdevIP"], mapParams["localdevmask"]),
            '</p>',
			ui_helper.createSimpleLight(ipv6_light_map[LANv6] or "4" --[[ red ]], ipv6_state_map[LANv6] or T "Unknown", nil, "fa fa-home")
        )
        ngx.print('\
\
	  </div>\
    </div>\
  </div>\
</div>\
'); 
