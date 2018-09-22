--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local mapParams = {
      wans_enable           = "uci.wansensing.global.enable",
      wans_l3type           = "uci.wansensing.global.l3type",
}
content_helper.getExactContent(mapParams)
local WS_en = format("%s", mapParams.wans_enable) -- untaint
local WS_mode = format("%s", mapParams.wans_l3type) -- untaint
if WS_mode == "" then
  WS_mode = "NONE"
end
local WS_State = ""
if WS_en == "1" then
   if WS_mode == "NONE" then
      WS_State = "None"
      WS_state_map = "WAN Sensing L3: None"
   else
      WS_State = "Enabled"
      WS_state_map = format(T"WAN Sensing L3: %s",WS_mode)
   end
else
   WS_State = "Disabled"
   WS_state_map = "WAN Sensing: Disabled"
end

local WS_light_map = {
  Disabled = "off",
  None = "orange",
  Enabled = "green",
}

  ngx.print('\
');  ngx.print( ui_helper.createSimpleLight(nil, WS_state_map, { light = { class = WS_light_map[WS_State] } }) ); ngx.print('\
'); 