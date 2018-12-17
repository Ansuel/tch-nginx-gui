--pretranslated: do not change this file

-- NG.... hide manual switching if wansensing is enabled
--NG-100650 Set 4th Ethernet Port as WAN or LAN Port on GUI
--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")

local bmh = require("broadbandmode_helper")
local tabdata = dyntab_helper.process(bmh)

local mode_current = tabdata.current.name
local mode_options = tabdata.options

local vB = post_helper.validateBoolean
local gOV = post_helper.getOptionalValidation

local variant = proxy.get("uci.env.var.prod_friendly_name")[1].value or ""

mapParam = {
	wsens = "uci.wansensing.global.enable",
	iface = "uci.network.interface.@wan.ifname",
	dsl_status = "sys.class.xdsl.@line0.Status",
	sfp = "uci.env.rip.sfp",
}

content_helper.getExactContent(mapParam)

if not tabdata.current.ajax then
	-- only display if not doing an ajax request
	ngx.print(ui_helper.createHeader(T"Broadband", true, true))

	ngx.print('\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/broadband-modal.lp">\
')
	ngx.print(ui_helper.createMessages(message_helper.popMessages()))
	ngx.print('\
<fieldset id="conn_mode" class="advanced hide">\
<legend>');ngx.print(T"Broadband type");ngx.print('</legend>')

	local html = {}

	local mode_attributes = {
		radio = {
			class = "inline"
		},
		input = {
			class = "no-save",
			["data-for"] = "SWITCH_MODE",
		}
	}
	local mode_button = {
		button = {
			["data-name"] = "action",
			["data-value"] = "SWITCH_MODE",
		}
	}

	html[#html+1] = ui_helper.createInputRadio(T"Mode", "newmode", mode_options, mode_current, mode_attributes)
	html[#html+1] = ui_helper.createButton("", T"Switch connection mode", "icon-cog", mode_button)

	ngx.print(html)
	ngx.print('\
</fieldset>\
')
end
lp.setpath("/www/snippets/")
lp.include(tabdata.current.view)
if not tabdata.current.ajax then
	-- only display if not doing an ajax request

	ngx.print('</form>\
</div>\
')
	ngx.print(ui_helper.createFooter())
end