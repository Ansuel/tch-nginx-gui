--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local modalPath = "/modals/xdsl-low-modal.lp"
local untaint = string.untaint
local lfs = require"lfs"

local content = {
      dsl0_enabled = "uci.xdsl.xdsl.@dsl0.enabled",
	  xdsl_version = "rpc.xdsl.dslversion",
  }
content_helper.getExactContent(content)

if session:hasAccess(modalPath) and lfs.attributes("/etc/config/xdsl", "mode") == "file" then

  local state_map_DSL = {
      ["0"] = T"xDSL Disabled",
      ["1"] = T"xDSL Enabled",
  }

  local light_map = {
      ["0"] = "off",
      ["1"] = "green",
  }
  -- The following lines have been added to prevent the page crash.
  -- When content.dsl0_enabled doesn't contain valid values.
  local status_msg = content.dsl0_enabled and state_map_DSL[untaint(content.dsl0_enabled)] or state_map_DSL["0"]
  local status = content.dsl0_enabled and light_map[untaint(content.dsl0_enabled)] or light_map["0"]
    ngx.print('\
\
  <div class="span3">\
      <div class="smallcard" data-aos="fade-up" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
          ');  ngx.print( ui_helper.createCardHeader(T"xDSL Config", modalPath) ); ngx.print('\
          <div class="content card_bg" data-bg-text="&#xf2db;">\
          <div class="divtable">\
                ');  
                html={}
                html[#html+1] = ui_helper.createSimpleLight(nil, status_msg, { light = {class=status}})
				html[#html+1] = '<p class="subinfos">'
                html[#html+1] = format(T"Driver Version: </br><strong id=\"cwmpconfcard_acsurl\">%s</strong>", content.xdsl_version )
				html[#html+1] = '</p>'
                ngx.print(html)
                  ngx.print('\
           </div>\
           </div>\
      </div>\
  </div>\
');  
end
  ngx.print('\
\
'); 