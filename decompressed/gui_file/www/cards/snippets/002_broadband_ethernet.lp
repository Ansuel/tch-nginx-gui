--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local format, match = string.format, string.match
local floor = math.floor
local tonumber = tonumber

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local find, sub = string.find, string.sub

-- TODO: only one eth wan interface is defined in the current product. If in the future, more than one eth wan interfaces are defined, need to use a list instead.
local ethPortPath = "uci.ethernet.port."
local ethIntf
local ethIntfList = proxy.getPN(ethPortPath, true)
if ethIntfList ~= nil then
    for _,v in pairs(ethIntfList) do
        if proxy.get(v.path.."wan")[1].value:untaint() == "1" then
            local startIndex, intfStart = find(v.path, ethPortPath.."@")
            if intfStart ~= nil then
                local intfEnd = find(sub(v.path, intfStart+1), "%.")
                if intfEnd ~= nil then
                    ethIntf = sub(sub(v.path, intfStart+1), 1, intfEnd-1)
                    break
                end
            end
        end
    end
end

local wan = {
    iface = "uci.network.interface.@wan.ifname",
}
content_helper.getExactContent(wan)

-- Here we just try to remove the potential vlan id from the interface name.
local iface = string.match(wan.iface, "([^%.]+)")
local stats

if iface and ethIntf and find(iface, ethIntf) then
    ethIntf = ethIntf:untaint()
    stats = {
        operstate = "sys.class.net.@" .. ethIntf .. ".operstate",
        carrier = "sys.class.net.@" .. ethIntf .. ".carrier",
        speed = "sys.class.net.@" .. ethIntf .. ".speed",
    }
    content_helper.getExactContent(stats)
else
    stats = {
        operstate = "down",
        carrier = "0",
        speed = "0",
    }
end

-- Figure out interface state
local intf_state = "disabled"
local intf_state_map = {
    disabled = "WAN ETH " .. T"disabled",
    connected = "WAN ETH " .. T"connected",
    disconnected = "WAN ETH " .. T"disconnected",
}

local intf_light_map = {
    disabled = "0", --"off"
    disconnected = "4",--"red"
    connected = "1",--"green"
}

if stats.operstate == "up" then
    if stats.carrier ~= "0" then
        intf_state = "connected"
    else
        intf_state = "disconnected"
    end
else
    intf_state = "disabled"
end

local session = ngx.ctx.session
local modalPath

if session:hasAccess("/modals/broadband-modal.lp") then
    modalPath = "/modals/broadband-modal.lp"
end
ngx.print('\
\
');  ngx.print( ui_helper.createCardHeader(T"Broadband", modalPath) ); ngx.print('\
<div class="content card_bg" data-bg-text="&#xf0b2;">\
  <div class="divtable">\
    ');  ngx.print( ui_helper.createSimpleLight(intf_light_map[intf_state] , intf_state_map[intf_state], { light = {} },"fas fa-retweet") );
if intf_state == "connected" then
    ngx.print('<p class="subinfos">'); ngx.print(T"Speed"); ngx.print(": <strong>"); ngx.print(stats.speed); ngx.print('Mbps</strong></p>');
end
ngx.print('\
  </div>\
</div>\
'); 