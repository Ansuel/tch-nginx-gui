--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ipairs, ngx, string = ipairs, ngx, string
local format = string.format
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local wirelessSSID_helper = require("wirelessSSID_helper")
local modalPath
local session = ngx.ctx.session
local attributes = { light = {}, span = {} }

if session:hasAccess("/modals/wireless-modal.lp") then
  modalPath = "/modals/wireless-modal.lp"
end
local ssid_list = wirelessSSID_helper.getSSID()
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print(ui_helper.createCardHeader(T"Wireless", modalPath, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf1eb;">\
	  <div class="divtable">\
');  

for _,v in ipairs(ssid_list) do
  -- A long network name is cut with "..." on one line; the full name stays in the tooltip
  local wifi_text = format('<span class="wifi-ssid-line" title="%s (%s)"><strong>%s</strong><span class="wifi-ssid-radio">(%s)</span></span>', v.ssid or "", v.radio or "", v.ssid or "", v.radio or "")
  attributes.light.id = "WiFi_Enabled_Led"
  attributes.span.id = "WiFi_Enabled"
  ngx.print(ui_helper.createSimpleLight(v.state or "0", wifi_text, attributes,"fa fa-wifi"))
end
  ngx.print('\
	  </div>\
    <style>\
    .wifi-ssid-line { display:inline-flex; align-items:baseline; min-width:0; max-width:calc(100% - 32px); vertical-align:bottom; }\
    .wifi-ssid-line > strong { min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }\
    .wifi-ssid-radio { flex:0 0 auto; white-space:nowrap; }\
    </style>\
    </div>\
  </div>\
</div>\
');
