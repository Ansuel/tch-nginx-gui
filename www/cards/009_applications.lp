--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local insert, format = table.insert, string.format

local mapParams = {
    gui_version = "uci.env.var.gui_version",
	luci_webui = "uci.env.var.luci_webui",										 
    aria2_webui = "uci.env.var.aria2_webui",
    transmission_webui = "uci.env.var.transmission_webui",
}
content_helper.getExactContent(mapParams)

local luci_webuiState_text = ""
local luci_webuiState

if mapParams["luci_webui"] and mapParams["luci_webui"] == "1" then
  luci_webuiState_text = T"Luci WebUi installed"
  luci_webuiState = "1"
else
  luci_webuiState_text = T"Luci WebUi not installed"
  luci_webuiState = "0"
end

local aria2_webuiState_text = ""
local aria2_webuiState

if mapParams["aria2_webui"] and mapParams["aria2_webui"] == "1" then
  aria2_webuiState_text = T"Aria2 WebUi installed"
  aria2_webuiState = "1"
else
  aria2_webuiState_text = T"Aria2 WebUi not installed"
  aria2_webuiState = "0"
end

local transmission_webuiState_text = ""
local transmission_webuiState

if mapParams["transmission_webui"] and mapParams["transmission_webui"] == "1" then
  transmission_webuiState_text = T"Transmission WebUi installed"
  transmission_webuiState = "1"
else
  transmission_webuiState_text = T"Transmission WebUi not installed"
  transmission_webuiState = "0"
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
	  <div class="divtable">\
\
      ');  
        local html = {}
		
		html[#html + 1] = "<strong>"
		html[#html + 1] = T"Gui Version: " .. mapParams["gui_version"]
		html[#html + 1] = "</strong></br>"
        html[#html + 1] = ui_helper.createSimpleLight(luci_webuiState, luci_webuiState_text, nil, nil  )
		html[#html + 1] = "</br>"
		html[#html + 1] = ui_helper.createSimpleLight(aria2_webuiState, aria2_webuiState_text, nil, nil  )
		html[#html + 1] = "</br>"
		html[#html + 1] = ui_helper.createSimpleLight(transmission_webuiState, transmission_webuiState_text, nil, nil )
		
		ngx.print(html)
        ngx.print('\
\
	  </div>\
    </div>\
  </div>\
</div>\
'); 