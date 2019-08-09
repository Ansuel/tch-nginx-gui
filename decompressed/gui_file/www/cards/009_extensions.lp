--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local insert, format = table.insert, string.format

local marketing_version = proxy.get("uci.version.version.@version[0].marketing_version")
local prod_friendly_name = proxy.get("uci.env.var.prod_friendly_name")

local extension_supported = 0

if marketing_version then
	marketing_version = tonumber(marketing_version[1].value:sub(1,4))
end

local mapParams = {
	telstra_webui = "uci.modgui.app.telstra_webui"
}
--if prod_friendly_name and prod_friendly_name[1].value and marketing_version and marketing_version < 18 then
	if prod_friendly_name[1].value:match("DGA413") or 
		prod_friendly_name[1].value:match("TG7") then
		mapParams.luci_webui = "uci.modgui.app.luci_webui"
	end
	if prod_friendly_name[1].value:match("TG7") then
		mapParams.amule_webui = "uci.modgui.app.amule_webui"
	end
	mapParams.aria2_webui = "uci.modgui.app.aria2_webui"
	mapParams.transmission_webui = "uci.modgui.app.transmission_webui"
	if prod_friendly_name[1].value:match("DGA413") then
		mapParams.blacklist_application = "uci.modgui.app.blacklist_app"
		if marketing_version >= 17.3 then
			mapParams.xupnp_application = "uci.modgui.app.xupnp_app"
		end
	end
--end

content_helper.getExactContent(mapParams)

local StateParams = {}
local ParamsText = {}

for Params in pairs(mapParams) do
	extension_supported = extension_supported + 1
	local ParamsName = Params:gsub("_(.*)",""):gsub("^%l", string.upper)
	if mapParams[Params] and mapParams[Params] == "1" then
		StateParams[Params] = "1"
		ParamsText[Params] = ParamsName .. T" is installed"
	else
		StateParams[Params] = "0"
		ParamsText[Params] = ParamsName .. T" is not installed"
	end
end

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/applications-modal.lp") and extension_supported > 0 then
	modalPath = "/modals/applications-modal.lp"
end
ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"Extensions", modalPath, switchName, nil) ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf015;">\
	  <div class="divtable" style="width: 110%; margin-top: -10px;">\
\
      ');
local html = {}

for Params in pairs(mapParams) do
	html[#html + 1] = ui_helper.createSimpleLight(StateParams[Params], ParamsText[Params], nil, nil  )
end

if extension_supported == 0 then
	html[#html + 1] = '<span class="simple-desc">'
	html[#html + 1] =	"<strong>"
	html[#html + 1] =		"No Extensions are supported on this device<br>"
	html[#html + 1] =	"</strong>"
	html[#html + 1] = "</span>"
end
ngx.print(html)
ngx.print('\
\
	  </div>\
    </div>\
  </div>\
</div>\
'); 
