--pretranslated: do not change this file
 
-- Enable localization
-- NG-92675 implement changes required from the customer
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")

local find, sub = string.find, string.sub
local version = proxy.get("uci.version.version.@version[0].marketing_version")
if version then
    version = version[1].value
else
    version = ""
end
local name = proxy.get("uci.version.version.@version[0].marketing_name")
if name then
    name = name[1].value
else
    name = ""
end

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session

local variant = proxy.get("uci.env.var.hardware_version")[1].value

if  ( variant == "VBNT-K" ) then
	model = "AGTEF"
end

if ( variant == "VBNT-S" ) then
	model = "AGTHP"
end
	
if session:hasAccess("/modals/gateway-modal.lp") then
   modalPath = "/modals/gateway-modal.lp"
   switchName = nil
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard" data-aos="fade-up" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print( ui_helper.createCardHeader(T"Gateway", modalPath, switchName, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf129;">\
	<div class="divtable">\
      <div class="light green" id="Gateway_=LED_Id"></div>\
      <p><strong id = "Version_Id">');  ngx.print(string.format(T"Version %s (%s)", name, version)); ngx.print('</strong></p>\
      <div data-remote="modals/gateway-modal.lp" data-id="gateway-modal">\
	    <picture>\
		    <source srcset="/img/gateway_'); ngx.print(model); ngx.print('.webp" type="image/webp">\
		    <source srcset="/img/gateway_'); ngx.print(model); ngx.print('.png" type="image/png">\
        <img class="someInfos" href="#" rel="tooltip" data-placement="top" data-original-title="');  ngx.print( T"your gateway" ); ngx.print('" src="/img/gateway_'); ngx.print(model); ngx.print('.png" alt="gateway">\
		</picture>\
		</div>\
      </div>\
    </div>\
  </div>\
</div>\
'); 