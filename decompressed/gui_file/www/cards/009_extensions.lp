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
