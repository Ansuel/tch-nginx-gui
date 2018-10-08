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
	content.eco_led_text = T"Eco Led Enabled"
else
	content.eco_led_text = T"Eco Led Disabled"
end

if content.cpuspeed == "256" then
	content.cpuspeed = T"CPU Frequency Auto Scaling"
	content.cpuspeed_status = "1"
else
	content.cpuspeed = content.cpuspeed .. T" of max Frequency"
	content.cpuspeed_status = "0"
end

if content.eee == "1" then
	content.eee_text = T"Energy Efficent Ethernet Enabled"
else
	content.eee_text = T"Energy Efficent Ethernet Disabled"
end

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/eco-modal.lp") then
	modalPath = "/modals/eco-modal.lp"
end

ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="fade-up" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"Eco Settings", modalPath, switchName, nil) ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf015;">\
	  <div class="divtable" style="width: 110%; margin-top: -10px;">\
\
      ');
local html = {}

	html[#html + 1] = ui_helper.createSimpleLight(content.eco_led, content.eco_led_text, nil, nil  )
	html[#html + 1] = ui_helper.createSimpleLight(content.cpuspeed_status, content.cpuspeed, nil, nil  )
	html[#html + 1] = ui_helper.createSimpleLight(content.eee, content.eee_text, nil, nil  )

ngx.print(html)
ngx.print('\
\
	  </div>\
    </div>\
  </div>\
</div>\
'); 
