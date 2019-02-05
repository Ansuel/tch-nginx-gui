--pretranslated: do not change this file

-- Enable localization

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")

-- Non-configurable data
local content = {
  gui_version = "uci.modgui.gui.gui_version",
  outdated_ver = "uci.modgui.gui.outdated_ver",
}

content_helper.getExactContent(content)

if content.outdated_ver == "1" then
	content.outdated_ver = "5"
	content.outdated_ver_text = T"GUI is outdated"
else
	content.outdated_ver = "1"
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
  <div class="smallcard" data-aos="fade-up" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"GUI Settings", modalPath, switchName, nil) ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf06c;">\
	  <div class="divtable">\
\
      ');
	local html = {}
	html[#html + 1] = string.format(T"GUI Version %s", content.gui_version)
	html[#html + 1] = ui_helper.createSimpleLight(content.outdated_ver, content.outdated_ver_text, nil, "fas fa-cog" )

ngx.print(html)
ngx.print('\
\
	  </div>\
    </div>\
  </div>\
</div>\
'); 