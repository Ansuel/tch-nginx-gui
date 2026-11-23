--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")

local format = string.format

-- Non-configurable data
local content = {
  gui_version = "rpc.system.modgui.gui_version",
  outdated_ver = "uci.modgui.gui.outdated_ver",
  new_ver = "uci.modgui.gui.new_ver",
}

content_helper.getExactContent(content)

local outdated = content.outdated_ver == "1"
local available_version_text = T"Available GUI version: %s"
local status_text = T"GUI is updated"
if outdated then
	local version = content.new_ver or ""
	if version == "" or version == "Unknown" or version == "Exact path not found!" then
		status_text = T"Update Found"
	else
		status_text = format(available_version_text, version)
	end
end

local modalPath = nil

if ngx.ctx.session:hasAccess("/modals/modgui-modal.lp") then
   modalPath = "/modals/modgui-modal.lp"
end

ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"GUI Settings", modalPath, nil, nil) ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf55f;">\
	  <div class="divtable">\
\
      ');

	local html = {}
	html[#html + 1] = format(T"GUI Version <a onclick=\"event.stopPropagation()\" target=\"_blank\" href=https://github.com/Ansuel/tch-nginx-gui/releases/tag/%s>%s</a>", content.gui_version:match("(.+)-"), content.gui_version)
	html[#html + 1] = '<span class="simple-desc">'
	html[#html + 1] = '  <div class="light_icon fas fa-cog gui_version_status '..(outdated and 'yellow' or 'green')..'"></div>'
	html[#html + 1] = '<span class="gui_version_status_text" data-available-version="'..available_version_text..'">'
	html[#html + 1] = status_text
	html[#html + 1] = '</span>'
	if modalPath then
		html[#html + 1] = ' <button type="button" class="btn btn-small upgrade_gui'..(outdated and '' or ' hide')..'">'..T"Install update"..'</button>'
	end
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
	modgui.linkCheckUpdate();\
  });\
  </script>\
</div>\
');
