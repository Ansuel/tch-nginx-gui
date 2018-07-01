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
	fco_mcast_learn = "uci.fcctlsettings.option.mcast-learn"
}

local fco_valid = { 
	fco_enable = vB,
	fco_l2tp = vB,
	fco_gre = vB,
	fco_ipv6 = vB,
	fco_mcast = vB,
	fco_mcast_learn = vB
}

local fco_content, fco_helpmessage = post_helper.handleQuery(fco_Params, fco_valid)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Fast Cache Option", false, false))   ngx.print('\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/fast-cache-option-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
    <fieldset>\
      ');  
			local html = {}
			html[#html + 1] = ui_helper.createSwitch(T"Enabled", "fco_enable", fco_enable)
			html[#html + 1] = ui_helper.createSwitch(T"L2tp", "fco_l2tp", fco_l2tp)
			html[#html + 1] = ui_helper.createSwitch(T"GRE", "fco_gre", fco_gre)
			html[#html + 1] = ui_helper.createSwitch(T"IPv6", "fco_ipv6", fco_ipv6)
			html[#html + 1] = ui_helper.createSwitch(T"MCast", "fco_mcast", fco_mcast)
			html[#html + 1] = ui_helper.createSwitch(T"MCast-Learn", "fco_mcast_learn", fco_mcast_learn)
			ngx.print(html)
        ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 