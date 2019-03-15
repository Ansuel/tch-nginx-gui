--pretranslated: do not change this file

local ngx = ngx

-- Enable localization
gettext.textdomain('webui-mobiled')

local datamodel = require ("datamodel")
local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")
local format = string.format

local params = utils.get_params()

local session = ngx.ctx.session
local lte_state, error = datamodel.get("uci.mobiled.device_defaults.enabled")

if lte_state then
    lte_state = format("%s",lte_state[1].value)
else
    lte_state = "0"
end

local switchName = nil

-- In case we are waiting for the user to enter the PIN code, we redirect to the SIM page
local allowSimRedirect = false
if session:hasAccess("/modals/lte-sim.lp") then
	allowSimRedirect = true
end

local light = {
	status = "0",
	desc = T"Disabled"
}

local uci_device_path = utils.get_uci_device_path()
local result = utils.getContent(uci_device_path .. "enabled")
if result['enabled'] == "1" then
	light.status = "1"
	light.desc = T"Enabled"
end

local modalPath = nil
if session:hasAccess("/modals/lte-modal.lp") then 
	switchName = "lte_enabled"
	modalPath = "/modals/lte-modal.lp"
end


  ngx.print('\
\
<link href="/css/mobiled.css" rel="stylesheet">\
<div class="span3" id="mobiletab">\
	<div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
		');  ngx.print( ui_helper.createCardHeader(params.card_title, modalPath, switchName, lte_state) ); ngx.print('\
		<div class="content card_bg" data-bg-text="&#xf012;">\
		<div class="divtable">\
			');  ngx.print( ui_helper.createSimpleLight(light.status, light.desc)); ngx.print('\
				<div id="signal-strength-indicator-small-card">\
					<div>\
						<div class="bar-small bar-small1"></div>\
						<div class="bar-small bar-small2"></div>\
						<div class="bar-small bar-small3"></div>\
						<div class="bar-small bar-small4"></div>\
						<div class="bar-small bar-small5"></div>\
					</div>\
				</div>'); ngx.print('\
			<p class="subinfos">\
				<div style="height: 25px; margin: 20px;" data-bind="visible: mobileStatus().length > 0">\
					<label class="card-label">');  ngx.print( T"Status"..":" ); ngx.print('</label>\
					<div class="controls">\
						<strong data-bind="text: mobileStatus"></strong>\
					</div>\
				</div>\
				<div style="height: 25px;" data-bind="visible: radioType().length > 0">\
					<label class="card-label">');  ngx.print( T"Radio Type"..":" ); ngx.print('</label>\
					<div class="card-control">\
						<strong data-bind="text: radioType"></strong>\
					</div>\
				</div>\
				<div style="height: 25px;" data-bind="visible: signalQuality().length > 0">\
					<label class="card-label">');  ngx.print( T"Quality"..":" ); ngx.print('</label>\
					<div class="controls">\
						<strong data-bind="text: signalQuality"></strong>\
					</div>\
				</div>\
				<div style="height: 25px; margin: 20px;" data-bind="visible: deviceStatus().length > 0">\
					<div class="controls">\
						<strong data-bind="text: deviceStatus"></strong>\
					</div>\
				</div>\
			</p>\
		</div>\
		</div>\
	</div>\
</div>\
<script>\
var LetCardInterval;\
$(document).ready(function () {\
	var allowSimRedirect = ');  ngx.print( allowSimRedirect ); ngx.print(';\
	var LetCardBinding = {\
		signalQuality: ko.observable(""),\
		radioType: ko.observable(""),\
		mobileStatus: ko.observable(""),\
		deviceStatus: ko.observable(""),\
	};\
	function updateBars(bars) {\
				$(\'#signal-strength-indicator-small .absolute\').children(\'.bar-small\').each(function (index) {\
					if(index < bars) {\
						$(this).addClass(\'bar-small-active\');\
					} else {\
						$(this).removeClass(\'bar-small-active\');\
					}\
				});\
			};\
	function LetCardRefresh() {\
		$.post("/ajax/mobiletab.lua?auto_update=true", [tch.elementCSRFtoken()], function(data) {\
					if(data.bars != undefined) {\
						updateBars(data.bars);\
					}\
					if(data.radio_interface != undefined) {\
						LetCardBinding.radioType(data.radio_interface);\
					}\
					if(data.status != undefined) {\
						LetCardBinding.mobileStatus(data.status);\
					}\
					if(data.signal_quality != undefined) {\
						LetCardBinding.signalQuality(data.signal_quality);\
					}\
					if(data.no_device != undefined) {\
						LetCardBinding.deviceStatus(data.no_device);\
					}\
					if(data.redirect_sim != undefined) {\
						if(data.redirect_sim === true && allowSimRedirect) {\
							$.each($(\'.settings[data-id="lte-modal"]\'), function () {\
								$(this).attr(\'data-id\', \'lte-sim\');\
								$(this).attr(\'data-remote\', \'/modals/lte-sim.lp\');\
							});\
						} else {\
							$.each($(\'.settings[data-id="lte-sim"]\'), function () {\
								$(this).attr(\'data-id\', \'lte-modal\');\
								$(this).attr(\'data-remote\', \'/modals/lte-modal.lp\');\
							});\
						}\
					}\
				}, "json");\
	};\
\
	LetCardRefresh();\
	ko.applyBindings(LetCardBinding, document.getElementById("mobiletab"));\
	LetCardInterval = setInterval(LetCardRefresh, 50000);\
	KoRequest.push(LetCardInterval);\
})\
</script>\
'); 
