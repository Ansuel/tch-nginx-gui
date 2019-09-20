--pretranslated: do not change this file
ngx.print('<style>\
	.card-label {\
		float: left;\
		padding-right: 5px;\
		font-weight: 500;\
		font-size: 16px;\
		cursor: default;\
	}\
	.card-control {\
		cursor: default;\
	}\
</style>\
');
local ngx = ngx

-- Enable localization
gettext.textdomain('webui-mobiled')

local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")

local params = utils.get_params()

local session = ngx.ctx.session

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
	modalPath = "/modals/lte-modal.lp"
elseif not session:isdefaultuser() then
	return
end
ngx.print('\
\
<link href="/css/mobiled.css" rel="stylesheet">\
<div class="span3" id="mobiletab">\
	<div class="smallcard">\
		');  ngx.print( ui_helper.createCardHeader(params.card_title, modalPath) ); ngx.print('\
		<div id="signal-strength-indicator-small">\
			<div class="absolute">\
				<div class="bar-small bar-small1"></div>\
				<div class="bar-small bar-small2"></div>\
				<div class="bar-small bar-small3"></div>\
				<div class="bar-small bar-small4"></div>\
				<div class="bar-small bar-small5"></div>\
			</div>\
		</div>\
		<div class="content card_bg" data-bg-text="&#xf012;">\
			');  ngx.print( ui_helper.createSimpleLight(light.status, light.desc, nil,"fa fa-signal") ); ngx.print('\
			<p class="subinfos">\
				<div style="height: 25px;" data-bind="visible: mobileStatus().length > 0">\
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
				<div style="height: 25px;" data-bind="visible: deviceStatus().length > 0">\
					<div class="controls">\
						<strong data-bind="text: deviceStatus"></strong>\
					</div>\
				</div>\
			</p>\
		</div>\
	</div>\
</div>\
<script>\
	$(document).ready(function () {\
		var allowSimRedirect = ');  ngx.print( allowSimRedirect ); ngx.print(';\
		var LteCard = function () {\
                        var clearRefreshInterval = function () {\
                        clearInterval(refreshInterval);\
                        };\
			var self = this;\
			this.signalQuality = ko.observable("");\
			this.radioType = ko.observable("");\
			this.mobileStatus = ko.observable("");\
			this.deviceStatus = ko.observable("");\
			this.updateBars = function(bars) {\
				$(\'#signal-strength-indicator-small .absolute\').children(\'.bar-small\').each(function (index) {\
					if(index < bars) {\
						$(this).addClass(\'bar-small-active\');\
					} else {\
						$(this).removeClass(\'bar-small-active\');\
					}\
				});\
			};\
			this.refresh = function () {\
				$.ajax({ type: "POST", url: "/ajax/mobiletab.lua?auto_update=true",dataType: "json", data: [tch.elementCSRFtoken()], success: function(data) {\
					if(data.bars != undefined) {\
						self.updateBars(data.bars);\
					}\
					if(data.radio_interface != undefined) {\
						self.radioType(data.radio_interface);\
					}\
					if(data.status != undefined) {\
						self.mobileStatus(data.status);\
					}\
					if(data.signal_quality != undefined) {\
						self.signalQuality(data.signal_quality);\
					}\
					if(data.no_device != undefined) {\
						self.deviceStatus(data.no_device);\
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
				}, error: clearRefreshInterval });\
			};\
			var refreshInterval = setInterval(self.refresh, 20000);\
			self.refresh();\
		};\
		var lteCard = new LteCard();\
		ko.applyBindings(lteCard, document.getElementById(\'mobiletab\'));\
	});\
</script>\
');
