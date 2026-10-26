--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
  ngx.print('\
\
');  ngx.print( ui_helper.createSimpleLight(nil, "Trying to connect", { light = { class = "orange"} }) ); ngx.print('\
'); 