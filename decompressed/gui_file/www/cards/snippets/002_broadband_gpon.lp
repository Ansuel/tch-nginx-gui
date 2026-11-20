--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local integrated = require("bridgehelper").hasIntegratedGpon()
local content = {
    gpon_state = integrated and "rpc.gpon.ploam.state" or "rpc.optical.Interface.1.Status",
    optical_signal_level = integrated and "rpc.gpon.trsv.info.status.DS_Rx_RSSI"
        or "rpc.optical.Interface.1.OpticalSignalLevel",
}
require("internethelper").getOptionalContent(content)

local gpon_state_map = {
    connected = T"Up",
    connecting = T"Down",
}

local gpon_status = "connecting"
if content.gpon_state == "Up" or content.gpon_state == "OPERATION (O5)" then
    gpon_status = "connected"
end

local gpon_light_map = {
    connecting = "orange",
    connected = "green",
}

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
');
    local html = {}
html[#html + 1] = string.format("<strong>%s</strong><br/>",T"GPON Status")
local status = content.gpon_state ~= "" and gpon_state_map[gpon_status] or T"Unavailable"
html[#html + 1] = ui_helper.createSimpleLight(nil, status, { light = { class = gpon_light_map[gpon_status] } })
local signal = tonumber(content.optical_signal_level)
if signal then
    html[#html + 1] = string.format('<p id="Line_Rate_Down" class="subinfos">&emsp; <i class="fas fa-certificate"></i>%.2f dBm</p>',
        integrated and signal or signal / 1000)
end
    ngx.print(html)

ngx.print('\
</div>\
</div>');
