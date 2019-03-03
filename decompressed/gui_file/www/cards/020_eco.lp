--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")

local content = {
	eco_led = "uci.ledfw.status_led.enable",
	cpuspeed = "uci.power.cpu.cpuspeed",
	eee = "uci.power.ethernet.eee",
}

content_helper.getExactContent(content)

if content.eco_led == "1" then
	content.eco_led_text = T"Eco LED enabled"
else
	content.eco_led_text = T"Eco LED disabled"
end

if content.cpuspeed == "256" then
	content.cpuspeed_status = "1"
else
	content.cpuspeed_status = "0"
end

if content.eee == "1" then
	content.eee_text = T"Energy Efficent Ethernet enabled"
else
	content.eee_text = T"Energy Efficent Ethernet disabled"
end

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/eco-modal.lp") then
	modalPath = "/modals/eco-modal.lp"
end

if content.cpuspeed == "256" then
	content.cpuspeed = T"CPU Frequency Auto Scaling"
elseif content.cpuspeed == "0" then
	content.cpuspeed = T"100% of max Frequency in SYNC mode"
elseif content.cpuspeed == "1" then
	content.cpuspeed = T"100% of max Frequency in ASYNC mode"
elseif content.cpuspeed == "2" then
	content.cpuspeed = T"50% of max Frequency in ASYNC mode"
elseif content.cpuspeed == "4" then
	content.cpuspeed = T"25% of max Frequency in ASYNC mode"
elseif content.cpuspeed == "8" then
	content.cpuspeed = T"10% of max Frequency in ASYNC mode"
end

ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"Eco Settings", modalPath, switchName, nil) ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf06c;">\
	  <div class="divtable">\
\
      ');
local html = {}

	html[#html + 1] = ui_helper.createSimpleLight(content.eco_led, content.eco_led_text, nil, "fas fa-leaf"  )
	html[#html + 1] = ui_helper.createSimpleLight(content.cpuspeed_status, content.cpuspeed, nil, "fas fa-microchip"  )
	html[#html + 1] = ui_helper.createSimpleLight(content.eee, content.eee_text, nil, "fas fa-exchange-alt"  )

ngx.print(html)
ngx.print('\
\
	  </div>\
    </div>\
  </div>\
</div>\
'); 
