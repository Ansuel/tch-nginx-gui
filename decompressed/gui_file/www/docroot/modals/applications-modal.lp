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
	"voipblockmmpbx",
	"voipblockasterisk",
	"blacklist",
	"xupnp",
	"telstra",
	"amule",
	"adblock",
	"rsyncd",
	"speedtest",
	"adguardhome",
	"openspeedtest",
	"wireguard",
	"l2tpipsec",
	"openvpn",
	"tailscale",
}

local marketing_version = proxy.get("uci.version.version.@version[0].marketing_version")
local cputype = proxy.get("rpc.system.modgui.CPUtype")[1].value
local specific_app = proxy.get("uci.modgui.app.specific_app")[1].value or "0"
if marketing_version then
	marketing_version = tonumber(marketing_version[1].value:sub(1,4))
end

local function appapply(action)
	proxy.set("rpc.system.modgui.app.sendcmd",action)
	if ( action == "install_blacklist_empty" ) then
		action = "install_blacklist"
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
	if action:match("install") or action:match("remove") or
		action:match("start") or action:match("stop") then
		return appapply(action)
	end
end

local mapParams = {
	local_ip_modem = "uci.network.interface.@lan.ipaddr",
	telstra_webui = "uci.modgui.app.telstra_webui",
}
if marketing_version >= 16.3 then
	mapParams.luci_webui = "uci.modgui.app.luci_webui"
	mapParams.blacklist_application = "uci.modgui.app.blacklist_app"
end
mapParams.voipblock_for_mmpbx = "uci.modgui.app.voipblock_for_mmpbx"
mapParams.voipblock_for_asterisk = "uci.modgui.app.voipblock_for_asterisk"
if cputype:match("mips") then
	mapParams.amule_webui = "uci.modgui.app.amule_webui"
end
mapParams.aria2_webui = "uci.modgui.app.aria2_webui"
mapParams.transmission_webui = "uci.modgui.app.transmission_webui"
mapParams.adblock_application = "uci.modgui.app.adblock_app"
mapParams.rsyncd_application = "uci.modgui.app.rsyncd_app"
mapParams.openspeedtest_application = "uci.modgui.app.openspeedtest_app"
if cputype:match("^armv7") or cputype:match("^mips") then
	mapParams.l2tpipsec_application = "uci.modgui.app.l2tpipsec_app"
end
if cputype:match("^armv7") or cputype:match("^mips") then
	mapParams.openvpn_application = "uci.modgui.app.openvpn_app"
end
if cputype:match("^armv7") or cputype == "aarch64" or cputype == "arm64" then
	mapParams.speedtest_application = "uci.modgui.app.speedtest_app"
	mapParams.adguardhome_application = "uci.modgui.app.adguardhome_app"
	mapParams.wireguard_application = "uci.modgui.app.wireguard_app"
	mapParams.tailscale_application = "uci.modgui.app.tailscale_app"
end
if marketing_version >= 17.3 then
	mapParams.xupnp_application = "uci.modgui.app.xupnp_app"
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
<fieldset style="display:flex;">\
    <form class="form-horizontal" method="post" action="modals/applications-modal.lp">\
    ');
local info_box = {
	alert = {
		class = "alert alert-info",
	}
}
local specific_box = {
	alert = {
		class = "alert-error"
	}
}
local html = {}

if specific_app == "0" then
	html[#html + 1] = ui_helper.createAlertBlock(T"Specific App are not installed. This can cause errors for app setup. Go to Mod GUI modal to install",specific_box)
end
html[#html + 1] = ui_helper.createAlertBlock(T"Make sure the gateway have an active internet connection to allow app download and installation",info_box)
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

local function escape_html(value)
	return (value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function append_extension_card(state_key, app, title, description, link, can_run, result)
	html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. title .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(description, info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. title .. " " .. StateParams[state_key] .. T" installed" .. "</strong><br/>"
	if link then
		html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. link .. '">' .. link .. "</a><br/>"
	end
	if result and result ~= "" then
		html[#html+1] = '<pre style="white-space:pre-wrap;max-height:12rem;overflow:auto;">' .. escape_html(result) .. '</pre>'
	end
	html[#html+1] = "<br/>"
	if mapParams[state_key] == "1" then
		if can_run then
			html[#html+1] = ui_helper.createSimpleButton(T"Start" .. " " .. title, "fa fa-play", btn_table[app].start)
			html[#html+1] = ui_helper.createSimpleButton(T"Stop" .. " " .. title, "fa fa-stop", btn_table[app].stop)
		end
		html[#html+1] = ui_helper.createSimpleButton(T"Remove" .. " " .. title, "fa fa-times-circle", btn_table[app].remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install" .. " " .. title, "fa fa-download", btn_table[app].install)
	end
	html[#html+1] = "</fieldset>"
	html[#html+1] = "</div>"
end

local function kernel_has_tun()
	local command = io.popen("[ -c /dev/net/tun ] || zcat /proc/config.gz 2>/dev/null | grep -q '^CONFIG_TUN=y$'; echo $?", "r")
	if not command then
		return false
	end
	local result = command:read("*line")
	command:close()
	return result == "0"
end

if StateParams["luci_webui"] ~= nil then
	html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"LuCI GUI" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install uHTTPd and LuCI", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"LuCI is " .. StateParams["luci_webui"] .. T" installed" .. "</strong><br/>"
	local luci_link = format("http://%s:9080",mapParams.local_ip_modem)
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. luci_link .. '">' .. luci_link .. "</a>"
	html[#html+1] = "<br/>"
	html[#html+1] = "<br/>"
	if mapParams["luci_webui"] and mapParams["luci_webui"] == "1" then
		html[#html+1] = ui_helper.createSimpleButton(T"Remove".." LuCI", "fa fa-times-circle", btn_table.luci.remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install".." LuCI", "fa fa-download", btn_table.luci.install)
	end
	html[#html+1] = "<br/>"
	html[#html+1] = "</fieldset>"
	html[#html+1] = "</div>"
end

if StateParams["amule_webui"] ~= nil then
	html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"aMule" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install aMule webui", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"aMule is " .. StateParams["amule_webui"] .. T" installed" .. "</strong><br/>"
	local amule_direct_link = format("http://%s:4711/",mapParams.local_ip_modem)
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. amule_direct_link .. '">' .. amule_direct_link .. "</a>"
	html[#html+1] = "<br/>"
	if mapParams["amule_webui"] and mapParams["amule_webui"] == "1" then
        if cputype:match("mips") then
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
	html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"Aria2 GUI" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install aria2 and ariang webui", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"Aria2 is " .. StateParams["aria2_webui"] .. T" installed" .. "</strong><br/>"
	local aria_link =  '/aria'
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. aria_link .. '">' .. aria_link .."</a>"
	html[#html+1] = "<br/>"
	html[#html+1] = "<br/>"
	if mapParams["aria2_webui"] and mapParams["aria2_webui"] == "1" then
        if cputype:match("mips") then
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
	html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"Transmission GUI" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install transmission and transmission-webui", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"Transmission is " .. StateParams["transmission_webui"] .. T" installed" .. "</strong><br/>"
	local transmission_direct_link = format("http://%s:9091/transmission",mapParams.local_ip_modem)
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. transmission_direct_link .. '">' .. transmission_direct_link .. "</a>"
	html[#html+1] = "<br/>"
	html[#html+1] = "<br/>"
	if mapParams["transmission_webui"] and mapParams["transmission_webui"] == "1" then
        if cputype:match("mips") then
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

if StateParams["adblock_application"] ~= nil then
	append_extension_card(
		"adblock_application",
		"adblock",
		T"Adblock",
		T"Blocks advertising domains at router level. Requires working opkg feeds.",
		nil,
		true
	)
end

if StateParams["rsyncd_application"] ~= nil then
	append_extension_card(
		"rsyncd_application",
		"rsyncd",
		T"Rsync daemon",
		T"Installs the rsync daemon. Configure authenticated shares before starting the service.",
		nil,
		true
	)
end

if StateParams["speedtest_application"] ~= nil then
	local speedtest_result = ""
	local speedtest_file = io.open("/tmp/speedtest-result.txt", "r")
	if speedtest_file then
		speedtest_result = speedtest_file:read("*all") or ""
		speedtest_file:close()
		if #speedtest_result > 4096 then
			speedtest_result = speedtest_result:sub(-4096)
		end
	end
	append_extension_card(
		"speedtest_application",
		"speedtest",
		T"Ookla Speedtest",
		T"Runs an internet speed test on this ARM gateway. Start runs a new test; reopen this window to see its result.",
		nil,
		true,
		speedtest_result
	)
end

if StateParams["adguardhome_application"] ~= nil then
	local adguard_port = "3000"
	local adguard_config = io.open("/opt/AdGuardHome/AdGuardHome.yaml", "r")
	if adguard_config then
		local in_http = false
		for line in adguard_config:lines() do
			if line:match("^http:%s*$") then
				in_http = true
			elseif line:match("^%S") then
				in_http = false
			elseif in_http then
				local configured_port = line:match("address:%s*.*:(%d+)%s*$")
				if configured_port then
					adguard_port = configured_port
					break
				end
			end
		end
		adguard_config:close()
	end
	local adguard_link = format("http://%s:%s", mapParams.local_ip_modem, adguard_port)
	append_extension_card(
		"adguardhome_application",
		"adguardhome",
		T"AdGuard Home",
		T"Installs AdGuard Home without changing dnsmasq or port 53. Complete the safe first-run setup in its web interface.",
		adguard_link,
		true
	)
end

if StateParams["openspeedtest_application"] ~= nil then
	local openspeedtest_link = format("http://%s:5678", mapParams.local_ip_modem)
	append_extension_card(
		"openspeedtest_application",
		"openspeedtest",
		T"OpenSpeedTest",
		T"Runs a browser-based LAN and Wi-Fi speed test directly against this gateway without using internet traffic.",
		openspeedtest_link,
		true
	)
end

if StateParams["wireguard_application"] ~= nil then
	if kernel_has_tun() then
		append_extension_card(
			"wireguard_application",
			"wireguard",
			T"WireGuard",
			T"Installs the checksum-verified userspace WireGuard runtime. It does not create tunnels, routes, keys or firewall rules.",
			nil,
			false
		)
	else
		html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
		html[#html+1] = "<fieldset>"
		html[#html+1] = '<legend>' .. T"WireGuard" .. '</legend>'
		html[#html+1] = ui_helper.createAlertBlock(T"Unavailable: this firmware kernel was built without TUN support. WireGuard cannot run safely on this device.", specific_box)
		html[#html+1] = "</fieldset>"
		html[#html+1] = "</div>"
	end
end

if StateParams["l2tpipsec_application"] ~= nil then
	append_extension_card(
		"l2tpipsec_application",
		"l2tpipsec",
		T"L2TP/IPsec VPN",
		T"Installs the legacy strongSwan and xl2tpd VPN server card. The server stays disabled after installation; prefer IKEv2 or WireGuard for new deployments.",
		nil,
		true
	)
end

if StateParams["openvpn_application"] ~= nil then
	if kernel_has_tun() then
		append_extension_card(
			"openvpn_application",
			"openvpn",
			T"OpenVPN",
			T"Installs OpenVPN server and client management. Both modes and the server WAN rule remain disabled until explicitly enabled.",
			nil,
			true
		)
	else
		html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
		html[#html+1] = "<fieldset><legend>" .. T"OpenVPN" .. "</legend>"
		html[#html+1] = ui_helper.createAlertBlock(T"Unavailable: this firmware kernel was built without TUN support.", specific_box)
		html[#html+1] = "</fieldset></div>"
	end
end

if StateParams["tailscale_application"] ~= nil then
	if kernel_has_tun() then
		append_extension_card(
			"tailscale_application",
			"tailscale",
			T"Tailscale",
			T"Installs a pinned official Tailscale runtime and a management card. The daemon, routes, exit-node mode and firewall access remain disabled until configured.",
			nil,
			false
		)
	else
		html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
		html[#html+1] = "<fieldset><legend>" .. T"Tailscale" .. "</legend>"
		html[#html+1] = ui_helper.createAlertBlock(T"Unavailable: this firmware kernel was built without TUN support.", specific_box)
		html[#html+1] = "</fieldset></div>"
	end
end

if StateParams["voipblock_for_mmpbx"] ~= nil then
	html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"Voipblock for mmpbx" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install Voipblock for mmpbx", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"The Voipblock for mmpbx is " .. StateParams["voipblock_for_mmpbx"] .. T" installed" .. "</strong><br/>"
	html[#html+1] = "<br/>"
	html[#html+1] = "<br/>"
	if mapParams["voipblock_for_mmpbx"] and mapParams["voipblock_for_mmpbx"] == "1" then
		html[#html+1] = ui_helper.createSimpleButton(T"Remove".." Voipblock for mmpbx", "fa fa-times-circle", btn_table.voipblockmmpbx.remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install".." Voipblock for mmpbx", "fa fa-download", btn_table.voipblockmmpbx.install)
	end
	html[#html+1] = "</fieldset>"
	html[#html+1] = "<br/>"
	html[#html+1] = "</div>"
end

if StateParams["voipblock_for_asterisk"] ~= nil then
	html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"Voipblock for asterisk" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install Voipblock for asterisk", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"The Voipblock for asterisk is " .. StateParams["voipblock_for_asterisk"] .. T" installed" .. "</strong><br/>"
	html[#html+1] = "<br/>"
	html[#html+1] = "<br/>"
	if mapParams["voipblock_for_asterisk"] and mapParams["voipblock_for_asterisk"] == "1" then
		html[#html+1] = ui_helper.createSimpleButton(T"Remove".." Voipblock for asterisk", "fa fa-times-circle", btn_table.voipblockasterisk.remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install".." Voipblock for asterisk", "fa fa-download", btn_table.voipblockasterisk.install)
	end
	html[#html+1] = "</fieldset>"
	html[#html+1] = "<br/>"
	html[#html+1] = "</div>"
end

if StateParams["blacklist_application"] ~= nil then
	btn_table.blacklist.installempty = {
		button = {
			id = "btn-install_blacklist_empty"
		}
	}
	html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"Blacklist App" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install the blacklist application", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"The Blacklist app is " .. StateParams["blacklist_application"] .. T" installed" .. "</strong><br/>"
	local blacklist_link = "http://blacklist.satellitar.it/"
	html[#html+1] = T"Support site: " .. '<a  target="_blank" href="' .. blacklist_link .. '">' .. blacklist_link .."</a>"
	html[#html+1] = "<br/>"
	html[#html+1] = "<br/>"
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
	html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"XUPnP App" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install the XUPnP application", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"The XUPnP app is " .. StateParams["xupnp_application"] .. T" installed" .. "</strong><br/>"
	local xupnp_link = format("http://%s:4044/ui/",mapParams.local_ip_modem)
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. xupnp_link .. '">' .. xupnp_link .."</a>"
	html[#html+1] = "<br/>"
	html[#html+1] = "<br/>"
	if mapParams["xupnp_application"] and mapParams["xupnp_application"] == "1" then
		html[#html+1] = ui_helper.createSimpleButton(T"Remove".." XUPnP", "fa fa-times-circle", btn_table.xupnp.remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install".." XUPnP", "fa fa-download", btn_table.xupnp.install)
	end
	html[#html+1] = "</fieldset>"
	html[#html+1] = "<br/>"
	html[#html+1] = "</div>"
end

if StateParams["telstra_webui"] ~= nil then
	html[#html+1] = '<div class="span3" style="margin-right:.5rem;margin-left:.5rem;">'
	html[#html+1] = "<fieldset>"
	html[#html+1] = '<legend>' .. T"Telstra GUI" .. '</legend>'
	html[#html+1] = ui_helper.createAlertBlock(T"This will install Telstra webui", info_box)
	html[#html+1] = T"State: "
	html[#html+1] = "<strong>" .. T"Telstra GUI is " .. StateParams["telstra_webui"] .. T" installed" .. "</strong><br/>"
	local telstra_gui = "/telstra-gui.lp"
	html[#html+1] = T"Webui on: " .. '<a target="_blank" href="' .. telstra_gui .. '">' .. telstra_gui .."</a>"
	html[#html+1] = "<br/>"
	html[#html + 1] = T "Change the default page in system-extra to set this GUI as default"
	html[#html+1] = "<br/>"
	if mapParams["telstra_webui"] and mapParams["telstra_webui"] == "1" then
		html[#html+1] = ui_helper.createSimpleButton(T"Remove" .. " " .. T"Telstra GUI", "fa fa-times-circle", btn_table.telstra.remove)
	else
		html[#html+1] = ui_helper.createSimpleButton(T"Install" .. " " .. T"Telstra GUI", "fa fa-download", btn_table.telstra.install)
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
    $("div[id^=\'btn-\']").on("click", function() {\
      var btnact = $(this).attr("id").replace("btn-", "");\
      modgui.postAction(btnact,1);\
    });\
}());\
</script>\
');
ngx.print(ui_helper.createFooter())
