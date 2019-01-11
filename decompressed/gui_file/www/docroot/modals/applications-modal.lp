--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format,sub,match = string.format, string.sub, string.match

local app_list = {
	"luci",
	"aria2",
	"transmission",
	"blacklist",
	"xupnp",
	"telstra",
	"amule",
}

local marketing_version = proxy.get("uci.version.version.@version[0].marketing_version")

local prod_friendly_name = proxy.get("uci.env.var.prod_friendly_name")

if marketing_version and marketing_version[1].value then
	marketing_version = marketing_version[1].value:sub(1,4)
else
	marketing_version = nil
end

local function appapply(action)
	proxy.set("rpc.system.modgui.app." .. action, "1")
	if ( action == "install_emptyblacklist" ) then
		action = "install_blacklist"
	end
	local uci_set = action:gsub("(.*)_","")
	local action_type = action:gsub("_(.*)","")
	if action_type == "install" or action_type == "remove" then
		if action_type == "install" then
			state = "1"
		else
			state = "0"
		end
		if not ( uci_set == "blacklist" ) and not ( uci_set == "xupnp" ) then
			proxy.set("uci.env.var." .. uci_set .. "_webui",state)
		else
			proxy.set("uci.env.var." .. uci_set .. "_app",state)
		end
	end
	ngx.header.content_type = "application/json"
	ngx.print('{ "success":"true" }')
	ngx.timer.at(0, function()
		proxy.apply()
	end)
	ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" then
	local action = string.untaint(ngx.req.get_post_args().action)
	if action:match("install") or action:match("remove") or action:match("start") or action:match("stop") then
		return appapply(action)
	end
end

local mapParams = {
	marketing_version = "uci.version.version.@version[0].marketing_version",
	local_ip_modem = "uci.network.interface.@lan.ipaddr",
}
if prod_friendly_name and prod_friendly_name[1].value then
	if prod_friendly_name[1].value:match("DGA413") or
			prod_friendly_name[1].value:match("TG799") or
			prod_friendly_name[1].value:match("TG789") then
		mapParams.luci_webui = "uci.env.var.luci_webui"
	end
	if prod_friendly_name[1].value:match("TG799") or
			prod_friendly_name[1].value:match("TG789") then
		mapParams.amule_webui = "uci.env.var.amule_webui"
	end
	mapParams.aria2_webui = "uci.env.var.aria2_webui"
	mapParams.transmission_webui = "uci.env.var.transmission_webui"
	if prod_friendly_name[1].value:match("DGA413") then
		mapParams.blacklist_application = "uci.env.var.blacklist_app"
		if tonumber(marketing_version) >= 17.3 then
			mapParams.xupnp_application = "uci.env.var.xupnp_app"
		end
	end
	mapParams.telstra_webui = "uci.env.var.telstra_webui"
end
content_helper.getExactContent(mapParams)

local StateParams = {}

for Params in pairs(mapParams) do
	if mapParams[Params] and mapParams[Params] == "1" then
		StateParams[Params] = ""
	else
		StateParams[Params] = T"not"
	end
end

ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Application List", false, false))   ngx.print('\
<div class="modal-body update">\
<fieldset>\
    <form class="form-horizontal" method="post" action="modals/applications-modal.lp">\
    ');
local info_box = {
	alert = {
		class = "alert alert-info",
	}
}
local html = {}

local btn_table = {}

for _, app in ipairs(app_list) do
	btn_table[app] = {}
	for _, action in ipairs({"install","remove","start","stop"}) do
		btn_table[app][action] =
		{
			button = {
				id = "btn-"..action.."_"..app
			}
		}
	end
end

if StateParams["luci_webui"] ~= nil then
	html[#html+1] = '<div class="span3">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"Luci GUI" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install uhttpd and luci", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"Luci is " .. StateParams["luci_webui"] .. T" installed" .. "</strong></br>"
	local luci_link = format("http://%s:9080",mapParams.local_ip_modem)
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. luci_link .. '">' .. luci_link .. "</a>"
	html[#html+1] = "</br>"
	html[#html+1] = "</br>"
	if mapParams["luci_webui"] and mapParams["luci_webui"] == "1" then
		html[#html+1] = ui_helper.createSimpleButton(T"Remove".." Luci", "fa fa-times-circle", btn_table.luci.remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install".." Luci", "fa fa-download", btn_table.luci.install)
	end
	html[#html+1] = "</br>"
	html[#html+1] = "</fieldset>"
	html[#html+1] = "</div>"
end

if StateParams["amule_webui"] ~= nil then
	html[#html+1] = '<div class="span3">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"aMule" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install aMule webui", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"aMule is " .. StateParams["amule_webui"] .. T" installed" .. "</strong></br>"
	local amule_direct_link = format("http://%s:4711/",mapParams.local_ip_modem)
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. amule_direct_link .. '">' .. amule_direct_link .. "</a>"
	html[#html+1] = "</br>"
	if mapParams["amule_webui"] and mapParams["amule_webui"] == "1" then
        if prod_friendly_name[1].value:match("TG799") or prod_friendly_name[1].value:match("TG789") then
            html[#html+1] = ui_helper.createSimpleButton(T"Start".." aMule", "fa fa-play", btn_table.amule.start)
            html[#html+1] = ui_helper.createSimpleButton(T"Stop".." aMule", "fa fa-stop", btn_table.amule.stop)
        end
		html[#html+1] = ui_helper.createSimpleButton(T"Remove".." aMule", "fa fa-times-circle", btn_table.amule.remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install".." aMule", "fa fa-download", btn_table.amule.install)
	end
	html[#html+1] = "</fieldset>"
	html[#html+1] = "</div>"
end

if StateParams["aria2_webui"] ~= nil then
	html[#html+1] = '<div class="span3">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"Aria2 GUI" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install aria2 and ariang webui", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"Aria2 is " .. StateParams["aria2_webui"] .. T" installed" .. "</strong></br>"
	local aria_link =  '/aria'
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. aria_link .. '">' .. aria_link .."</a>"
	html[#html+1] = "</br>"
	html[#html+1] = "</br>"
	if mapParams["aria2_webui"] and mapParams["aria2_webui"] == "1" then
        if prod_friendly_name[1].value:match("TG799") or prod_friendly_name[1].value:match("TG789") then
            html[#html+1] = ui_helper.createSimpleButton(T"Start".." Aria2", "fa fa-play", btn_table.aria2.start)
            html[#html+1] = ui_helper.createSimpleButton(T"Stop".." Aria2", "fa fa-stop", btn_table.aria2.stop)
        end
		html[#html+1] = ui_helper.createSimpleButton(T"Remove".." Aria2", "fa fa-times-circle", btn_table.aria2.remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install".." Aria2", "fa fa-download", btn_table.aria2.install)
	end
	html[#html+1] = "</fieldset>"
	html[#html+1] = "</div>"
end

if StateParams["transmission_webui"] ~= nil then
	html[#html+1] = '<div class="span3">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"Transmission GUI" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install transmission and transmission-webui", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"Transmission is " .. StateParams["transmission_webui"] .. T" installed" .. "</strong></br>"
	local transmission_direct_link = format("http://%s:9091/transmission",mapParams.local_ip_modem)
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. transmission_direct_link .. '">' .. transmission_direct_link .. "</a>"
	html[#html+1] = "</br>"
	html[#html+1] = "</br>"
	if mapParams["transmission_webui"] and mapParams["transmission_webui"] == "1" then
        if prod_friendly_name[1].value:match("TG799") or prod_friendly_name[1].value:match("TG789") then
            html[#html+1] = ui_helper.createSimpleButton(T"Start".." Tansmission", "fa fa-play", btn_table.transmission.start)
            html[#html+1] = ui_helper.createSimpleButton(T"Stop".." Transmission", "fa fa-stop", btn_table.transmission.stop)
        end
		html[#html+1] = ui_helper.createSimpleButton(T"Remove".." Transmission", "fa fa-times-circle", btn_table.transmission.remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install".." Transmission", "fa fa-download", btn_table.transmission.install)
	end
	html[#html+1] = "</fieldset>"
	html[#html+1] = "</div>"
end

if StateParams["blacklist_application"] ~= nil then
	btn_table.blacklist.installempty = {
		button = {
			id = "btn-installempty_blacklist"
		}
	}
	html[#html+1] = '<div class="span3">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"Blacklist App" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install the blacklist application", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"The Blacklist app is " .. StateParams["blacklist_application"] .. T" installed" .. "</strong></br>"
	local blacklist_link = "http://blacklist.satellitar.it/"
	html[#html+1] = T"Support site: " .. '<a  target="_blank" href="' .. blacklist_link .. '">' .. blacklist_link .."</a>"
	html[#html+1] = "</br>"
	html[#html+1] = "</br>"
	local empty_blacklist_msg = ""
	if mapParams["blacklist_application"] and mapParams["blacklist_application"] == "1" then
		html[#html+1] = ui_helper.createSimpleButton(T"Remove".." Blacklist", "fa fa-times-circle", btn_table.blacklist.remove)
		empty_blacklist_msg = T"Update blacklist app"
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install".." Blacklist", "fa fa-download", btn_table.blacklist.install)
		empty_blacklist_msg = T"Install empty blacklist"
	end
	html[#html+1] = ui_helper.createSimpleButton(empty_blacklist_msg, "fa fa-download", btn_table.blacklist.installempty)

	html[#html+1] = "</fieldset>"
	html[#html+1] = "</div>"
end

if StateParams["xupnp_application"] ~= nil then
	html[#html+1] = '<div class="span3">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"XUPnP App" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install the XUPnP application", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"The XUPnP app is " .. StateParams["xupnp_application"] .. T" installed" .. "</strong></br>"
	local xupnp_link = format("http://%s:4044/ui/",mapParams.local_ip_modem)
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. xupnp_link .. '">' .. xupnp_link .."</a>"
	html[#html+1] = "</br>"
	html[#html+1] = "</br>"
	if mapParams["xupnp_application"] and mapParams["xupnp_application"] == "1" then
		html[#html+1] = ui_helper.createSimpleButton(T"Remove".." XUPnP", "fa fa-times-circle", btn_table.xupnp.remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install".." XUPnP", "fa fa-download", btn_table.xupnp.install)
	end
	html[#html+1] = "</fieldset>"
	html[#html+1] = "</br>"
	html[#html+1] = "</div>"
end

if StateParams["telstra_webui"] ~= nil then
	html[#html+1] = '<div class="span3">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"Telstra GUI" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install Telstra webui", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"Telstra is " .. StateParams["telstra_webui"] .. T" installed" .. "</strong></br>"
	local telstra_gui = "/telstra-gui.lp"
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. telstra_gui .. '">' .. telstra_gui .."</a>"
	html[#html+1] = "</br>"
	html[#html+1] = T"Change the default page in system-extra to set this gui as default"
	html[#html+1] = "</br>"
	if mapParams["telstra_webui"] and mapParams["telstra_webui"] == "1" then
		html[#html+1] = ui_helper.createSimpleButton(T"Remove".." Telstra GUI", "fa fa-times-circle", btn_table.telstra.remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install".." Telstra GUI", "fa fa-download", btn_table.telstra.install)
	end
	html[#html+1] = "</fieldset>"
	html[#html+1] = "</div>"
end
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
  function post(action,processMsg) {\
    $.post(\
      target,\
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      null,\
      "json"\
    );\
	tch.showProgress(processMsg);\
    return false;\
  }');
ngx.print('\
    $("div[id^=\'btn-\']").on("click", function() {\
      var btnact = $(this).attr("id").replace("btn-", "");\
      if(btnact.startsWith("start")){\
      	post(btnact,"');  ngx.print(T'Starting...'); ngx.print('");\
      	setTimeout(function(){tch.removeProgress();}, 2000);\
      } else if(btnact.startsWith("stop")){\
      	post(btnact,"');  ngx.print(T'Stopping...'); ngx.print('");\
      	setTimeout(function(){tch.removeProgress();}, 2000);\
      } else if(btnact.startsWith("remove")){\
      	post(btnact,"');  ngx.print(T'Removing...'); ngx.print('");\
      	setTimeout(function(){location.reload();}, 2000);\
      } else if(btnact.startsWith("install")) {\
      	post(btnact,"');  ngx.print(T'Installing...'); ngx.print('");\
      	setTimeout(function(){location.reload();}, 2000);\
      }\
    });\
}());\
</script>\
');  
ngx.print(ui_helper.createFooter())
