--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")

local prod_friendly_name = proxy.get("uci.env.var.prod_friendly_name")
local vB = post_helper.validateBoolean


local mapValid = {
    eee = vB,
	autogreeen = vB,
	ethapd = vB,
	wait = vB,
	cpuspeed = post_helper.validateNonEmptyString,
	eco_led = vB,
	eco_led_timeout = post_helper.validatePositiveNum,
    ledfw_internet = vB,
    ledfw_voip = vB,
    ledfw_iptv = vB,
    ledfw_wifinsc = vB
}

local mapParams = {
	eee = "uci.power.ethernet.eee",
	autogreeen = "uci.power.ethernet.autogreeen",
	ethapd = "uci.power.ethernet.ethapd",
	wait = "uci.power.cpu.wait",
	cpuspeed = "uci.power.cpu.cpuspeed",
	eco_led = "uci.ledfw.status_led.enable",
	eco_led_timeout = "uci.ledfw.timeout.ms",
    ledfw_internet = "uci.ledfw.internet.check",
    ledfw_voip = "uci.ledfw.voip.check",
    ledfw_iptv = "uci.ledfw.iptv.check",
    ledfw_wifinsc = "uci.ledfw.wifi.nsc_on",
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

local cpu_step = {
	{'256', 'auto'},
	{'0', '1'},
	{'1', '1/1'},
	{'2', '1/2'},
	{'4', '1/4'},
	{'8', '1/8'}
}

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Eco Settings", false, false))   ngx.print('\
<div class="modal-body update">\
');
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/eco-modal.lp">\
  <fieldset>\
       ');
        local html = {}
		
		local basic = {
          span = {
            class = "span5"
          },
        }
		
		local info_box = {
          alert = {
		  	class = "alert alert-info",
		  }
        }
	    html[#html + 1] = '<legend>' .. T"Eco Settings" .. '</legend>'

		html[#html + 1] = ui_helper.createAlertBlock(T"Turning on Eco features can cause major latency.", info_box)
		html[#html + 1] = ui_helper.createSwitch(T"Ethernet EEE", "eee", content["eee"])
	    html[#html + 1] = ui_helper.createSwitch(T"Ethernet AutoGrEEEn", "autogreeen", content["autogreeen"])
	    html[#html + 1] = ui_helper.createSwitch(T"Ethernet Ethapd", "ethapd", content["ethapd"])
	    html[#html + 1] = ui_helper.createSwitch(T"CPU Wait", "wait", content["wait"])
	    html[#html + 1] = ui_helper.createInputSelect(T"CPU Speed", "cpuspeed", cpu_step , content["cpuspeed"])
	    
	    ngx.print(html)
	    
	    local html = {}
	    html[#html + 1] = '<legend>' .. T"LED Settings" .. '</legend>'
		if prod_friendly_name[1].value:match("DGA") or prod_friendly_name[1].value:match("TG789") then
			html[#html + 1] = ui_helper.createAlertBlock(T"Turn the WiFi LEDs on if at least one client is connected to the corresponding radio.", info_box)
			html[#html + 1] = ui_helper.createSwitch(T"WiFi NSC", "ledfw_wifinsc", content["ledfw_wifinsc"])
		end
	    html[#html + 1] = ui_helper.createAlertBlock(T"Turn off all LEDs except “Info” if all services are up and running. Press the “Info” / “WiFi” button to show the current LEDs status.", info_box)
	    html[#html + 1] = ui_helper.createSwitch(T"Eco Led", "eco_led", content["eco_led"])
	    html[#html + 1] = ui_helper.createInputText(T"Timeout", "eco_led_timeout", content["eco_led_timeout"], basic , helpmsg["eco_led_timeout"] )
        html[#html + 1] = ui_helper.createAlertBlock(T"Select the services to check on before turning the “Info” LED green and turning the services LEDs off (if ECO LED has been enabled).", info_box)
        html[#html + 1] = ui_helper.createSwitch(T"VoIP", "ledfw_voip", content["ledfw_voip"])
        html[#html + 1] = ui_helper.createSwitch(T"IPTV", "ledfw_iptv", content["ledfw_iptv"])
        html[#html + 1] = ui_helper.createSwitch(T"Internet", "ledfw_internet", content["ledfw_internet"])
        ngx.print(html)

         ngx.print('\
\
  </fieldset>\
\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
');
