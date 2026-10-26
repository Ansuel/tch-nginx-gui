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

-- Follow the selected physical uplink, including local WAN sessions on br-lan.
local stats = require("bridgehelper").ethernetLink()

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