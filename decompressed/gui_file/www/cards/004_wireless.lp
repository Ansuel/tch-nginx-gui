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
local attributes = { light = { } ,span = { class = "span4" } }

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

for i,v in ipairs(ssid_list) do
  if i <= 4 then
	wifi_text = format('<strong>%s</strong>(%s)',v.ssid or nil ,v.radio or nil)
  end
  attributes.light.id = "WiFi_Enabled_Led"
  attributes.span.id = "WiFi_Enabled"
  ngx.print(ui_helper.createSimpleLight(v.state or "0", wifi_text, attributes,"fa fa-wifi"))
end
  ngx.print('\
	  </div>\
    </div>\
  </div>\
</div>\
'); 