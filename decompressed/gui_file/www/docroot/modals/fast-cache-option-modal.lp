--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local string, ngx = string, ngx

local vB = post_helper.validateBoolean

local fco_Params = { 
	fco_enable = "uci.fcctlsettings.state.enabled",
	fco_l2tp = "uci.fcctlsettings.option.l2tp", 
	fco_gre = "uci.fcctlsettings.option.gre", 
	fco_ipv6 = "uci.fcctlsettings.option.ipv6", 
	fco_mcast = "uci.fcctlsettings.option.mcast", 
	fco_mcast_learn = "uci.fcctlsettings.option.mcast_learn"
}

local mcast_option = {
	{ "0", T'Disabled'},
    { "1", T'Only IPv4'},
    { "2", T'Only IPv6'},
	{ "3", T'IPv4/IPv6'},
}

local gre_option = {
	{ "0", T'Disabled'},
    { "1", T'GRE without PassThru'},
    { "2", T'Only PassThru'},
}

local l2tp_option = {
	{ "0", T'Disabled'},
    { "1", T'L2TP without UDP-Checksum check'},
    { "2", T'L2TP with UDP-Checksum check'},
}

local fco_valid = { 
	fco_enable = vB,
	fco_l2tp = post_helper.getValidateInEnumSelect(l2tp_option),
	fco_gre = post_helper.getValidateInEnumSelect(gre_option),
	fco_ipv6 = vB,
	fco_mcast = post_helper.getValidateInEnumSelect(mcast_option),
	fco_mcast_learn = vB
}

local fco_content, fco_helpmessage = post_helper.handleQuery(fco_Params, fco_valid)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Flow Cache", false, false))   ngx.print('\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-internet.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/fast-cache-option-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
    <fieldset>\
      ');  
			local html = {}
			html[#html + 1] = '<legend>' .. T"Settings" .. '</legend>'
			html[#html + 1] = ui_helper.createSwitch(T"Enabled", "fco_enable", fco_content["fco_enable"])
			html[#html + 1] = ui_helper.createInputSelect(T"L2TP", "fco_l2tp", l2tp_option, fco_content["fco_l2tp"])
			html[#html + 1] = ui_helper.createInputSelect(T"GRE", "fco_gre", gre_option, fco_content["fco_gre"])
			html[#html + 1] = ui_helper.createSwitch(T"IPv6", "fco_ipv6", fco_content["fco_ipv6"])
			html[#html + 1] = ui_helper.createInputSelect(T"Multicast", "fco_mcast", mcast_option, fco_content["fco_mcast"])
			html[#html + 1] = ui_helper.createSwitch(T"Muticast-Learn", "fco_mcast_learn", fco_content["fco_mcast_learn"])
			ngx.print(html)
        ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 