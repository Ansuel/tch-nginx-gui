--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")

local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsList()

local content = {
	dest_mac = "rpc.network.firewall.dmz.redirect.dest_mac",
	gw = "uci.network.interface.@lan.ipaddr",
	netmask = "uci.network.interface.@lan.netmask"
}

content_helper.getExactContent(content)

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local vSIDIP = gVSIDIP(content["gw"], content["netmask"])
local vQTN = post_helper.validateQTN
local gOV = post_helper.getOptionalValidation
local gAV = post_helper.getAndValidation

local mapParams = {
	enable = "rpc.network.firewall.dmz.enable",
    destinationip = "rpc.network.firewall.dmz.redirect.dest_ip",
}

local mapValid = {
	enable = post_helper.validateBoolean,
    destinationip = gAV(gVIPIL(vSIDIP,"enable",{"1"}),gOV(vQTN)),
}
 
local data, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"DMZ", false, false))   ngx.print('\
\
<div class="modal-body update">\
');
	local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-wanservices.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="/modals/dmz-modal.lp">\
    ');  
      ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
	  <fieldset>\
      ');

		local html = {}
		
		local dmz_switch = {
			input = {
				class = "monitor-changes",
			}
		}
		local dmz_switch_mon_1 = {
			group = {
				class ="monitor-enable monitor-1",
			},
			autocomplete = hosts_ac,
		}
		
        html[#html+1] = ui_helper.createSwitch(T"Enabled", "enable", data["enable"], dmz_switch, helpmsg["enable"])
        html[#html+1] = ui_helper.createInputText(T"Destination IP", "destinationip", data["destinationip"], dmz_switch_mon_1, helpmsg["destinationip"])
        html[#html+1] = ui_helper.createLabel(T"Destination MAC", content["dest_mac"], dmz_switch_mon_1)
				  
		ngx.print(html)
        ngx.print('\
	  </fieldset>\
	</form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');