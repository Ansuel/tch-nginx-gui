--pretranslated: do not change this file
 
-- Enable localization
-- NG-92675/TCOMITAGW-2102 implement changes required from the customer
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local model_helper = require("model_helper")

local content = {
	version = "uci.version.version.@version[0].marketing_version",
	name = "uci.version.version.@version[0].marketing_name",
	model = "uci.env.var.prod_friendly_name",
}

content_helper.getExactContent(content)
local model = string.untaint(content.model or "")
local png = model_helper.gateway_image(model, "png") or "gateway_icon.png"
local webp = model_helper.gateway_image(model, "webp")
local imageUrl = "/img/" .. ngx.escape_uri(png)

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session

if session:hasAccess("/modals/gateway-modal.lp") then
   modalPath = "/modals/gateway-modal.lp"
   switchName = nil
end

local isAgthf = string.find(webp, "gateway_AGTHF", 1, true) ~= nil
local contentStyle = isAgthf and ' style="overflow: hidden;"' or ''
local pStyle = isAgthf and ' style="margin-bottom: 0px;"' or ''
local divStyle = isAgthf and ' style="text-align: center; margin-top: -19px;"' or ' style="text-align: center;"'
local imgStyle = isAgthf and ' style="height: 118px !important; width: auto !important; max-width: none !important;"' or ''

ngx.print('\
\
<div class="span3" id="gateway-card">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print( ui_helper.createCardHeader(T"Modem", modalPath, switchName, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf129;"', contentStyle, '>\
	<div class="divtable">\
	  <p', pStyle, '>\
      <i class="fa fa-info" id="Gateway_=LED_Id"></i>\
      <strong id = "Version_Id">');  ngx.print(string.format(T"Version %s (%s)", content.name, content.version)); ngx.print('</strong><br/>');
	  ngx.print('<span class="subinfos">' ..  T"CPU Load"..":" ); ngx.print('\
					<strong data-bind="text: cpuload">\
					</strong></span></p>\
      <div data-remote="/modals/gateway-modal.lp" data-id="gateway-modal"', divStyle, '>\
	    <picture>\
        ')
        if webp then ngx.print('<source srcset="/img/', ngx.escape_uri(webp), '" type="image/webp">') end
        ngx.print('<img class="someInfos"', imgStyle, ' href="#" rel="tooltip" data-placement="top" data-original-title="',
            T"Your Gateway", '" src="', imageUrl, '" alt="', content.model, '">')
        ngx.print('\
		</picture>\
		</div>\
      </div>\
    </div>\
  </div>\
</div>\
<script>\
$(document).ready(function () {\
	new modgui.createAjaxUpdateCard("gateway-card","/ajax/cpuload.lua","GatewayCardInterval",5000);\
})\
</script>\
');
