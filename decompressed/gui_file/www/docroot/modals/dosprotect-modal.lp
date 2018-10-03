--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local string, ngx = string, ngx

local vB = post_helper.validateBoolean

local dos_Params = { 
	dos_enable = "uci.dosprotect.globals.enabled",
	dos_rpfilter = "uci.dosprotect.globals.rpfilter",
}

local dos_valid = { 
	dos_enable = vB,
	dos_rpfilter = vB,
}

local dos_content, dos_helpmessage = post_helper.handleQuery(dos_Params, dos_valid)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Dos Protect Option", false, false))   ngx.print('\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-internet.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/dosprotect-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
    <fieldset>\
      ');  
			local html = {}
			html[#html + 1] = '<legend>' .. T"Settings" .. '</legend>'
			html[#html + 1] = ui_helper.createSwitch(T"Enabled", "dos_enable", dos_content["dos_enable"])
			html[#html + 1] = ui_helper.createSwitch(T"RpFilter", "dos_rpfilter", dos_content["dos_rpfilter"])
			ngx.print(html)
        ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 