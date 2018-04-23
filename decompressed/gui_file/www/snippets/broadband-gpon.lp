--pretranslated: do not change this file
 
-- Enable localization
--NG-102397 GUI internal error when changing LAN4 LAN/WAN mode
gettext.textdomain('webui-core')

local format = string.format

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local mapParams = {
    gpon_state = "rpc.optical.Interface.1.Status",
    optical_signal_level = "rpc.optical.Interface.1.OpticalSignalLevel",
    transmit_optical_level = "rpc.optical.Interface.1.TransmitOpticalLevel",
}
content_helper.getExactContent(mapParams)

local gpon_status = "connecting"
if mapParams.gpon_state == "Up" then
    gpon_status = "connected"
end

local gpon_light_map = {
    connecting = "orange",
    connected = "green",
}

  ngx.print('\
\
<fieldset>\
  <legend>');  ngx.print( T"Physical link status" ); ngx.print('</legend>\
\
  ');  
    local html = {}
    -- Label that shows gpon status
    html[#html + 1] = ui_helper.createLight(T"Status",nil, T(mapParams["gpon_state"]), { light = { class = gpon_light_map[gpon_status] } })
    html[#html + 1] = ui_helper.createLabel(T"OpticalSignalLevel",T(mapParams["optical_signal_level"].." dBm"))
    html[#html + 1] = ui_helper.createLabel(T"TransmitOpticalLevel",T(mapParams["transmit_optical_level"].." dBm"))
    ngx.print(html)
    ngx.print('\
</fieldset>\
'); 