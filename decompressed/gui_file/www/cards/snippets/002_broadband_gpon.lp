--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format, match = string.format, string.match
local floor = math.floor
local tonumber = tonumber

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")

local mapParams = {
      gpon_state = "rpc.optical.Interface.1.Status",
}
local mapValid = {
    gpon_state = function(value, object, key)
     return true
   end,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

local gpon_state_map = {
    connected = T"Up",
    connecting = T"Down",
}

local gpon_status = "connecting"
if content.gpon_state == "Up" then
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
<div class="content">\
  ');  
    local html = {}
      html[#html + 1] = ui_helper.createSimpleLight(nil, gpon_state_map[gpon_status], { light = { class = gpon_light_map[gpon_status] } })
    ngx.print(html)
    ngx.print('\
</div>\
'); 
