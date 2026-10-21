--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local internethelper = require("internethelper")
local post_helper = require("web.post_helper")
local format = string.format

  ngx.print('\
\
\
  <p class="subinfos">\
    ');  ngx.print( T("Gateway in bridge mode") ); ngx.print('\
  </p>\
');

-- The bridge itself has no WAN address. An optional local DHCP/PPP/static
-- session on br-lan still belongs to logical WAN, never to the LAN's IP.
local protocol = internethelper.getValue("uci.network.interface.@wan.proto")
if protocol == "dhcp" or protocol == "pppoe" or protocol == "static" then
    local runtime = {
        ipaddr = "rpc.network.interface.@wan.ipaddr",
        up = "rpc.network.interface.@wan.up",
        uptime = "rpc.network.interface.@wan.uptime",
    }
    for key, path in pairs(internethelper.getIpv6Content()) do runtime[key] = path end
    internethelper.getOptionalContent(runtime)
    local auto = internethelper.getValue("uci.network.interface.@wan.auto")
    local state, light = T"Connecting", "2"
    if auto == "0" then state, light = T"Disabled", "0"
    elseif runtime.up == "1" then state, light = T"Connected", "1" end
    ngx.print('<div data-bind="html: status_light">', ui_helper.createSimpleLight(light, state), '</div>')
    local ipv4, ipv6, uptime = "", "", ""
    if runtime.ipaddr ~= "" then ipv4 = format(T'WAN IP is <strong>%s</strong><br/>', runtime.ipaddr) end
    if (runtime.ip6addr or "") ~= "" then ipv6 = format(T'WAN IPv6 is <strong>%s</strong><br/>', runtime.ip6addr) end
    if tonumber(runtime.uptime) then
        uptime = format(T'Uptime: <strong>%s</strong>', post_helper.secondsToTimeShort(tonumber(runtime.uptime)) or "")
    end
    -- Keep the bindings even before the address arrives, so polling can fill it.
    ngx.print('<div data-bind="html: WAN_IP_text">', ipv4, '</div>',
        '<div data-bind="html: WAN_IPv6_text">', ipv6, '</div>',
        '<div data-bind="html: uptime_text">', uptime, '</div>')
end
