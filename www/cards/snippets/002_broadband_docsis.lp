--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")

local content_helper = require("web.content_helper")

-- docsis data
local docsis_data = {
  docsis_status = "rpc.docsis.status",
}
content_helper.getExactContent(docsis_data)

local session = ngx.ctx.session

local modalPath

if session:hasAccess("/modals/broadband-modal.lp") then
    modalPath = "modals/broadband-modal.lp"
end
  ngx.print('\
\
');  ngx.print( ui_helper.createCardHeader(T"Broadband", modalPath, nil, 0) ); ngx.print('\
<div class="content">\
');  
  if (docsis_data["docsis_status"] == "Operational") then
    ngx.print(
      "<div class=\"light green\"></div><p>",
      T"Connected",
      "</p>"
    )
  elseif docsis_data["docsis_status"] == "Not synchronized" then
    ngx.print(
      "<div class=\"light red\"></div><p>",
      T"Disconnected",
      "</p>"
    )
  else
    ngx.print(
      "<div class=\"light orange\"></div><p>",
      T"Connecting...</p>"
    )
  end
  ngx.print('\
\
</div>\
'); 