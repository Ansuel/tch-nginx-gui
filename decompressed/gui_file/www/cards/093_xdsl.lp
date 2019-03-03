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
	  dsl0_status = "sys.class.xdsl.@line0.Status",
	  xdsl_version = "rpc.xdsl.dslversion",
	  dslam_chipset = "rpc.xdslctl.DslamChipset",
	  dslam_version = "rpc.xdslctl.DslamVersion"
  }
content_helper.getExactContent(content)

if content.dslam_chipset:match("BDCM") then
	content.dslam_chipset = "Broadcom"
elseif content.dslam_chipset:match("IFTN") then
	content.dslam_chipset = "Infineon"
end

if not content.dslam_chipset then
	content.dslam_chipset = T"Not Up"
	content.dslam_version = " "
end

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
      <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
         ');  ngx.print( ui_helper.createCardHeader(T"xDSL Config", modalPath) ); ngx.print('\
          <div class="content card_bg" data-bg-text="&#xf2db;">\
          <div class="divtable" style="width: 105%;">\
                ');  
                html={}
                html[#html+1] = ui_helper.createSimpleLight(content["dsl0_enabled"], status_msg, { light = {}},"fas fa-microchip")
				html[#html+1] = '<p class="subinfos">'
				if not ( content.dslam_chipset == "" ) and ( content.dsl0_status == "Up" ) then
                	html[#html+1] = format(T"Driver Version: <strong>%s</strong>", content.xdsl_version )
					html[#html+1] = '</br>'
					html[#html+1] = format(T"DSLAM Chipset: <strong>%s</strong>", content.dslam_chipset )
					html[#html+1] = '</br>'
					html[#html+1] = format(T"DSLAM Version: <strong>%s</strong>", content.dslam_version )
				end
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
