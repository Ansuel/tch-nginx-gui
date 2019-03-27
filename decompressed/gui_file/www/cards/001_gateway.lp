--pretranslated: do not change this file

-- Enable localization
-- NG-92675 implement changes required from the customer
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")

local find, sub = string.find, string.sub
local version = proxy.get("uci.version.version.@version[0].marketing_version")[1].value or ""

local name = proxy.get("uci.version.version.@version[0].marketing_name")[1].value or ""

local content = {}

content["loadavg"] = content_helper.readfile("/proc/loadavg","string")
local cpuload = content["loadavg"]
cpuload = string.sub(cpuload,1,14)

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session

local model = proxy.get("uci.env.var.prod_friendly_name")[1].value or ""

if  ( model == "DGA4130" ) then
	model = "AGTEF"
elseif ( model == "DGA4132" ) then
	model = "AGTHP"
elseif ( model == "MediaAccess DGA4131FWB" ) then
	model = "DGA4131FWB"
elseif ( model:match("TG788") ) then
	model = "TG788vn"
elseif ( model:match("TG789") ) then
	model = "TG789vac"
elseif ( model == "Technicolor TG799vac" ) then
	model = "TG799vac"
elseif ( model == "Technicolor TG800vac" ) then
	model = "TG800vac"
end

if session:hasAccess("/modals/gateway-modal.lp") then
   modalPath = "/modals/gateway-modal.lp"
   switchName = nil
end

ngx.print('\
\
<div class="span3" id="gateway-card">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print( ui_helper.createCardHeader(T"Modem", modalPath, switchName, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf129;">\
	<div class="divtable">\
	  <p>\
      <i class="fa fa-info" id="Gateway_=LED_Id"></i>\
      <strong id = "Version_Id">');  ngx.print(string.format(T"Version %s (%s)", name, version)); ngx.print('</strong></br>');
	  ngx.print('<span class="subinfos">' ..  T"CPU Load"..":" ); ngx.print('\
					<strong data-bind="text: cpuload">\
					</strong></span>\
      <div data-remote="/modals/gateway-modal.lp" data-id="gateway-modal" style="text-align: center;">\
	    <picture>\
		    <source srcset="/img/gateway_'); ngx.print(model); ngx.print('.webp" type="image/webp">\
		    <source srcset="/img/gateway_'); ngx.print(model); ngx.print('.png" type="image/png">\
        <img class="someInfos" href="#" rel="tooltip" data-placement="top" data-original-title="');  ngx.print( T"Your Gateway" ); ngx.print('" src="/img/gateway_'); ngx.print(model); ngx.print('.png" alt="gateway">\
		</picture>\
		</div>\
      </div>\
    </div>\
  </div>\
</div>\
<script>\
var GatewayCardInterval;\
$(document).ready(function () {\
	new createAjaxUpdateCard("gateway-card","/ajax/cpuload.lua",GatewayCardInterval,5000);\
})\
</script>\
');
