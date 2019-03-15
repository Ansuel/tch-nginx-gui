--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")

local format = string.format

-- Non-configurable data
local content = {
  gui_version = "uci.modgui.gui.gui_version",
  outdated_ver = "uci.modgui.gui.outdated_ver",
}

content_helper.getExactContent(content)

if content.outdated_ver == "1" then
	content.outdated_ver = "yellow"
	content.outdated_ver_text = T"GUI is outdated"
else
	content.outdated_ver = "green"
	content.outdated_ver_text = T"GUI is updated"
end

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session

local model = nil

if session:hasAccess("/modals/modgui-modal.lp") then
   modalPath = "/modals/modgui-modal.lp"
   switchName = nil
end

ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"GUI Settings", modalPath, switchName, nil) ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf55f;">\
	  <div class="divtable">\
\
      ');

	local html = {}
	html[#html + 1] = format(T"GUI Version %s", content.gui_version)
	html[#html + 1] = '<span class="simple-desc">'
	html[#html + 1] = '  <div class="light_icon fas fa-cog gui_version_status '..content.outdated_ver..'"></div>'
	html[#html + 1] = '<span class="gui_version_status_text">'..content.outdated_ver_text..'</span>'
	html[#html + 1] = '</span>'
	html[#html + 1] = '<span class="simple-desc">'
	html[#html + 1] =   '<div class="light_icon fas fa-sync check_update_spinner"></div>'
	html[#html + 1] =   format('<strong><a style="cursor: pointer;" class="check_update">%s</a></strong>',T"Check Update")
	html[#html + 1] = "</span>"

ngx.print(html)
ngx.print('\
\
	  </div>\
    </div>\
  </div>\
  <script>\
  $(document).ready(function(){\
	new linkCheckUpdate();\
  });\
  </script>\
</div>\
'); 