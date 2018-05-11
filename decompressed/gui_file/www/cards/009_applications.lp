--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local insert, format = table.insert, string.format

local gui_version = proxy.get("uci.env.var.gui_version")[1].value

local marketing_version = proxy.get("uci.version.version.@version[0].marketing_version")[1].value

local mapParams = {
	xupnp_application = "uci.env.var.xupnp_app",
	luci_webui = "uci.env.var.luci_webui",										 
    aria2_webui = "uci.env.var.aria2_webui",
    transmission_webui = "uci.env.var.transmission_webui",
	blacklist_application = "uci.env.var.blacklist_app",
}
content_helper.getExactContent(mapParams)

local StateParams = {}
local ParamsText = {}

for Params in pairs(mapParams) do
	local ParamsName = Params:gsub("_(.*)",""):gsub("^%l", string.upper)
	if Params == "xupnp_application" and tonumber(marketing_version) >= 17.3 then
		if mapParams[Params] and mapParams[Params] == "1" then
			StateParams[Params] = "1"
			ParamsText[Params] = ParamsName .. T" is installed"
		else
			StateParams[Params] = "0"
			ParamsText[Params] = ParamsName .. T" is not installed"
		end
	else
		if mapParams[Params] and mapParams[Params] == "1" then
			StateParams[Params] = "1"
			ParamsText[Params] = ParamsName .. T" is installed"
		else
			StateParams[Params] = "0"
			ParamsText[Params] = ParamsName .. T" is not installed"
		end
	end
end

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/applications-modal.lp") then
    modalPath = "/modals/applications-modal.lp"
end
  ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="fade-up" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"Gui State", modalPath, switchName, nil) ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf015;">\
	  <div class="divtable" style="width: 110%; margin-top: -10px;">\
\
      ');  
        local html = {}
		
		for Params in pairs(mapParams) do
			html[#html + 1] = ui_helper.createSimpleLight(StateParams[Params], ParamsText[Params], nil, nil  )
		end
		
		ngx.print(html)
        ngx.print('\
\
	  </div>\
    </div>\
  </div>\
</div>\
'); 