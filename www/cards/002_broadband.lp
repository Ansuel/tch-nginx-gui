--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local dyntab_helper = require("web.dyntab_helper")

local bmh = require("broadbandmode_helper")
local tabdata = dyntab_helper.process(bmh)

if tabdata and tabdata.current.card then
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
');  
    lp.setpath("/www/cards/snippets/")
    lp.include(tabdata.current.card)
    -- have to bring it back to original value ... singleton
    lp.setpath("/www/cards/")
  ngx.print('\
  </div>\
</div>\
');  end   ngx.print('\
'); 