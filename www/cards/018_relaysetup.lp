--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local session = ngx.ctx.session
local modalPath = "/modals/relay-modal.lp"
if session:hasAccess(modalPath) then

local dhcprelay_state
local relay_Params = {
    uci_relay_status = "uci.dhcprelay.config.enabled",
    uci_relay_ip = "uci.dhcprelay.config.serverip",
    uci_lan_ip = "uci.network.interface.@lan.ipaddr",

}
content_helper.getExactContent(relay_Params)

local dhcp_light_map = {
  disabled = "off",
  connected = "green",
}
local dhcp_state_map = {
    disabled = T"DHCP Relay disabled",
    connected = T"DHCP Relay enabled",
}

if relay_Params["uci_relay_status"] == "1" then
  dhcprelay_state = "connected"
else
  dhcprelay_state = "disabled"
end

  ngx.print('\r\
<div class="span3">\r\
    <div class="smallcard">\r\
      ');  ngx.print( ui_helper.createCardHeader(T"Relay Setup", "modals/relay-modal.lp") ); ngx.print('\r\
      <div class="content card_bg" data-bg-text="&#xf079;">\r\
	  <div class="divtable">\r\
        <p class="subinfos">\r\
          ');  ngx.print(format('%s <strong id=\"relaysetupcard_pppstatus\">%s</strong></br>', T"PPP status", T"Not configured"))
          ngx.print(format('%s : <strong id="relaysetupcard_lanip">%s</strong></br>', T"LAN IP", relay_Params["uci_lan_ip"]))   ngx.print('\r\
        </p>\r\
        ');  ngx.print(ui_helper.createSimpleLight(nil, dhcp_state_map[dhcprelay_state] , { light = { class = dhcp_light_map[dhcprelay_state], id = "relaysetupcard_dhcprelaystatusled" },  span = { id = "relaysetupcard_dhcprelaystatus" }}))
        if relay_Params["uci_relay_status"] == "1" then
          ngx.print(format('<p class = "subinfos" > Relay IP : <strong id="relaysetupcard_relayip">%s</strong></p>',relay_Params["uci_relay_ip"] ))
        end
          ngx.print('\r\
     </div>\r\
    </div>\r\
	</div>\r\
</div>\r\
');  
end
  ngx.print('\r\
'); 