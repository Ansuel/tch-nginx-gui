--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local format = string.format

-- Non-configurable data
local cs = {
    uci_wan_auto = "uci.network.interface.@wan.auto",
    ipaddr = "rpc.network.interface.@wan.ipaddr",
}

content_helper.getExactContent(cs)

-- Figure out interface state
local static_state = "disabled"
local static_state_map = {
    disabled = T"Static disabled",
    connected = T"Static on",
}

local static_light_map = {
  disabled = "off",
  connected = "green",
}

if cs["uci_wan_auto"] ~= "0" and cs["ipaddr"]:len() > 0 then
    cs["uci_wan_auto"] = "1"
    static_state = "connected"
end

local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    modalPath = "/modals/internet-modal.lp"
end

  ngx.print('\
\
  ');  ngx.print( ui_helper.createSimpleLight(nil, static_state_map[static_state], { light = { class = static_light_map[static_state] } }) ); ngx.print('\
  ');  
    if static_state == "connected" then
        ngx.print('<p class="subinfos">',
          format(T'WAN IP is <strong>%s</strong>', cs["ipaddr"]),
          '</p>')
    end
    ngx.print('\
'); 