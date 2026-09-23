--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local insert, format = table.insert, string.format

local marketing_version = proxy.get("uci.version.version.@version[0].marketing_version")
local cputype = proxy.get("rpc.system.modgui.CPUtype")[1].value

local extension_supported = 0

local function kernel_has_tun()
	local command = io.popen("[ -c /dev/net/tun ] || zcat /proc/config.gz 2>/dev/null | grep -q '^CONFIG_TUN=y$'; echo $?", "r")
	if not command then
		return false
	end
	local result = command:read("*line")
	command:close()
	return result == "0"
end

if marketing_version then
	marketing_version = tonumber(marketing_version[1].value:sub(1,4))
end

local mapParams = {
	telstra_webui = "uci.modgui.app.telstra_webui"
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
	if kernel_has_tun() then
		mapParams.openvpn_application = "uci.modgui.app.openvpn_app"
	end
end
if cputype:match("^armv7") or cputype == "aarch64" or cputype == "arm64" then
	mapParams.speedtest_application = "uci.modgui.app.speedtest_app"
	mapParams.adguardhome_application = "uci.modgui.app.adguardhome_app"
	if kernel_has_tun() then
		mapParams.wireguard_application = "uci.modgui.app.wireguard_app"
		mapParams.tailscale_application = "uci.modgui.app.tailscale_app"
	end
end
if marketing_version >= 17.3 then
	mapParams.xupnp_application = "uci.modgui.app.xupnp_app"
end

content_helper.getExactContent(mapParams)

local StateParams = {}

for Params in pairs(mapParams) do
	extension_supported = extension_supported + 1
	if mapParams[Params] and mapParams[Params] == "1" then
		StateParams[Params] = "1"
	else
		StateParams[Params] = "0"
	end
end

local extension_items = {
	{ key = "luci_webui", title = T"LuCI" },
	{ key = "aria2_webui", title = T"Aria2" },
	{ key = "transmission_webui", title = T"Transmission" },
	{ key = "voipblock_for_mmpbx", title = T"Voipblock MMPBX" },
	{ key = "voipblock_for_asterisk", title = T"Voipblock Asterisk" },
	{ key = "blacklist_application", title = T"Blacklist" },
	{ key = "xupnp_application", title = T"XUPnP" },
	{ key = "telstra_webui", title = T"Telstra GUI" },
	{ key = "amule_webui", title = T"aMule" },
	{ key = "adblock_application", title = T"Adblock" },
	{ key = "rsyncd_application", title = T"Rsync" },
	{ key = "speedtest_application", title = T"Speedtest" },
	{ key = "adguardhome_application", title = T"AdGuard Home" },
	{ key = "openspeedtest_application", title = T"OpenSpeedTest" },
	{ key = "wireguard_application", title = T"WireGuard" },
	{ key = "l2tpipsec_application", title = T"L2TP/IPsec" },
	{ key = "openvpn_application", title = T"OpenVPN" },
	{ key = "tailscale_application", title = T"Tailscale" },
}

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/applications-modal.lp") and extension_supported > 0 then
	modalPath = "/modals/applications-modal.lp"
end
ngx.print('\
<div class="span3">\
  <div class="smallcard extensions-card" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"Extensions", modalPath, switchName, nil) ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf015;">\
	  <div class="divtable extensions-status-grid">\
\
      ');
local html = {}

for _, item in ipairs(extension_items) do
	if StateParams[item.key] ~= nil then
		html[#html + 1] = ui_helper.createSimpleLight(
			StateParams[item.key],
			item.title,
			{ span = { class = "simple-desc extension-status" } },
			nil
		)
	end
end

if extension_supported == 0 then
	html[#html + 1] = '<span class="simple-desc">'
	html[#html + 1] =	"<strong>"
	html[#html + 1] =		"No Extensions are supported on this device<br/>"
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
