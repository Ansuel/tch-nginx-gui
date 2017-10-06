--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")

lp.include("broadband-ethernet.lp")
lp.include("broadband-vlan.lp")
  ngx.print('\
'); 