--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")

-- Process POST query
local post_helper = require("web.post_helper")

  ngx.print('\
\
<fieldset>\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"Bridged connection" ); ngx.print('</legend>\
\
');  
    local html = {}
    local bridge_info = {
        alert = {
            class = "alert-info"
        }
    }

    html[#html + 1] = ui_helper.createAlertBlock(T"No configuration available for internet connectivity when in bridge mode.", bridge_info)

    ngx.print(html)
  ngx.print('\
\
</fieldset>'); 