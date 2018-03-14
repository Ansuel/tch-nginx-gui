--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local format,sub,match,untaint = string.format, string.sub, string.match, string.untaint

local function appapply(action)
  proxy.set("rpc.system." .. action, "1")
  local uci_set = action:gsub("(.*)_","")
  local action_type = action:gsub("_(.*)","")
  if action_type == "install" then
	state = "1"
  else
	state = "0"
  end
  proxy.set("uci.env.var." .. uci_set .. "_webui",state)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_post_args().action
  -- do not call get_post_args before we know that we don't have a file sent otherwise it will fail
  if action == "install_luci" then
	return appapply("install_luci")
  end
  if action == "remove_luci" then
	return appapply("remove_luci")
  end
  if action == "install_aria2" then
	return appapply("install_aria2")
  end
  if action == "remove_aria2" then
	return appapply("remove_aria2")
  end
  if action == "install_transmission" then
	return appapply("install_transmission")
  end
  if action == "remove_transmission" then
	return appapply("remove_transmission")
  end
end

local mapParams = {
	luci_webui = "uci.env.var.luci_webui",										 
    aria2_webui = "uci.env.var.aria2_webui",
    transmission_webui = "uci.env.var.transmission_webui",
	local_ip_modem = "uci.network.interface.@lan.ipaddr",
}
content_helper.getExactContent(mapParams)

local luci_webuiState

if mapParams["luci_webui"] and mapParams["luci_webui"] == "1" then
  luci_webuiState = ""
else
  luci_webuiState = "not"
end

local aria2_webuiState

if mapParams["aria2_webui"] and mapParams["aria2_webui"] == "1" then
  aria2_webuiState = ""
else
  aria2_webuiState = "not"
end

local transmission_webuiState

if mapParams["transmission_webui"] and mapParams["transmission_webui"] == "1" then
  transmission_webuiState = ""
else
  transmission_webuiState = "not"
end

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Application List", false, false))   ngx.print('\
<div class="modal-body update">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))

  ngx.print('\
<fieldset>\
    <form class="form-horizontal" method="post" action="modals/applications-modal.lp">\
    ');  
	  local info_box = {
        alert = {
			class = "alert alert-info",
		}
      }
	  local install_luci = {
        button = {
          id = "btn-install-luci"
        }
      }
	  local remove_luci = {
        button = {
          id = "btn-remove-luci"
        }
      }
      local html = {}
	  html[#html+1] = '<div class="span3">'
	  html[#html+1] = "<fieldset>"
	  html[#html + 1] = '<legend>' .. T"Luci GUI !! BROKEN !!" .. '</legend>'
	  html[#html + 1] = ui_helper.createAlertBlock(T"This will install uhttpd and luci", info_box)
	  html[#html + 1] = T"State: "
	  html[#html + 1] = "<strong>" .. T"Luci is " .. luci_webuiState .. " installed" .. "</strong></br>"
	  html[#html + 1] = T"Webui on: " .. "http://" .. mapParams.local_ip_modem .. "/luci" 
	  html[#html + 1] = "</br>"
	  html[#html + 1] = T" (or " .. mapParams.local_ip_modem .. ":9080" .. " )"
	  html[#html + 1] = "</br>"
	  html[#html + 1] = "</br>"
	  if mapParams["luci_webui"] and mapParams["luci_webui"] == "1" then
		html[#html + 1] = ui_helper.createSimpleButton(T"Remove Luci", "icon-refresh", remove_luci)
	  else
		html[#html + 1] = ui_helper.createSimpleButton(T"Install Luci", "icon-refresh", install_luci)
	  end
	  html[#html + 1] = "</br>"
	  html[#html + 1] = "<strong>Disabled for now... need to wait @Roleo</strong>"
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "</div>"
	  local install_aria2 = {
        button = {
          id = "btn-install-aria2"
        }
      }
	  local remove_aria2 = {
        button = {
          id = "btn-remove-aria2"
        }
      }
	  html[#html+1] = '<div class="span3">'
	  html[#html+1] = "<fieldset>"
	  html[#html + 1] = '<legend>' .. T"Aria2 GUI" .. '</legend>'
	  html[#html + 1] = ui_helper.createAlertBlock(T"This will install aria2 and ariang webui", info_box)
	  html[#html + 1] = T"State: "
	  html[#html + 1] = "<strong>" .. T"Aria2 is " .. aria2_webuiState .. " installed" .. "</strong></br>"
	  html[#html + 1] = T"Webui on: " .. "http://" .. mapParams.local_ip_modem .. "/aria"
	  html[#html + 1] = "</br>"
	  html[#html + 1] = "</br>"
	  if mapParams["aria2_webui"] and mapParams["aria2_webui"] == "1" then
		html[#html + 1] = ui_helper.createSimpleButton(T"Remove Aria2", "icon-refresh", remove_aria2)
	  else
		html[#html + 1] = ui_helper.createSimpleButton(T"Install Aria2", "icon-refresh", install_aria2)
	  end
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "</div>"
	  local install_transmission = {
        button = {
          id = "btn-install-transmission"
        }
      }
	  local remove_transmission = {
        button = {
          id = "btn-remove-transmission"
        }
      }
	  html[#html+1] = '<div class="span3">'
	  html[#html+1] = "<fieldset>"
	  html[#html + 1] = '<legend>' .. T"Transmission GUI" .. '</legend>'
	  html[#html + 1] = ui_helper.createAlertBlock(T"This will install transmission and transmission-webui", info_box)
	  html[#html + 1] = T"State: "
	  html[#html + 1] = "<strong>" .. T"Transmission is " .. transmission_webuiState .. " installed" .. "</strong></br>"
	  html[#html + 1] = T"Webui on: " .. "http://" .. mapParams.local_ip_modem .. "/transmission/web/"
	  html[#html + 1] = "</br>"
	  html[#html + 1] = "</br>"
	  if mapParams["transmission_webui"] and mapParams["transmission_webui"] == "1" then
		html[#html + 1] = ui_helper.createSimpleButton(T"Remove Transmission", "icon-refresh", remove_transmission)
	  else
		html[#html + 1] = ui_helper.createSimpleButton(T"Install Transmission", "icon-refresh", install_transmission)
	  end
	  html[#html+1] = "</fieldset>"
	  html[#html + 1] = "</br>"
	  html[#html+1] = "</div>"
      ngx.print(html)
      ngx.print('\
    </form>\
  </fieldset>\
</div>\
\
<script>\
(function() {\
  var target = $(".modal form").attr("action");\
\
  function post(action) {\
    $.post(\
      target,\
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      null,\
      "json"\
    );\
    return false;\
  }\
  $("#btn-install-luci").click(function() {\
     --post("install_luci" );\
	 setTimeout(function(){location.reload();}, 2000);\
     });\
  $("#btn-remove-luci").click(function() {\
     --post("remove_luci" );\
	 setTimeout(function(){location.reload();}, 2000);\
     });\
  $("#btn-install-aria2").click(function() {\
     post("install_aria2" );\
	 setTimeout(function(){location.reload();}, 2000);\
     });\
  $("#btn-remove-aria2").click(function() {\
     post("remove_aria2" );\
	 setTimeout(function(){location.reload();}, 2000);\
     });\
  $("#btn-install-transmission").click(function() {\
     post("install_transmission" );\
	 setTimeout(function(){location.reload();}, 2000);\
     });\
  $("#btn-remove-transmission").click(function() {\
     post("remove_transmission" );\
	 setTimeout(function(){location.reload();}, 2000);\
     });\
}());\
</script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
');