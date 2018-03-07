--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local session = ngx.ctx.session
local modalPath = "/modals/relay-modal.lp"
if session:hasAccess(modalPath) then

-- TODO: Hardcoded to "1" since there’s no option to enable/disable dhcp relay
local uci_relay_status = "0"
local dhcprelay_state = "disabled"

local relay_Params = {
    uci_relay_server_ip = "uci.dhcp.relay.@relay.server_addr",
    uci_relay_local_ip = "uci.dhcp.relay.@relay.local_addr",
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

  ngx.print('\r\
<div class="span3">\r\
    <div class="smallcard" data-aos="fade-up" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\r\
      ');  ngx.print( ui_helper.createCardHeader(T"Relay Setup", "modals/relay-modal.lp") ); ngx.print('\r\
      <div class="content card_bg" data-bg-text="&#xf079;">\r\
        ');  ngx.print(ui_helper.createSimpleLight(nil, dhcp_state_map[dhcprelay_state] , { light = { class = dhcp_light_map[dhcprelay_state], id = "relaysetupcard_dhcprelaystatusled" },  span = { id = "relaysetupcard_dhcprelaystatus" }}))
          if uci_relay_status == "1" then
		    ngx.print(format('<p class = "subinfos" > Server IP : <strong id="relaysetupcard_relayip">%s</strong></p>',relay_Params["uci_relay_server_ip"] ))
            ngx.print(format('<p class = "subinfos" > Local IP : <strong id="relaysetupcard_relayip">%s</strong></p>',relay_Params["uci_relay_local_ip"] ))		   
          end
		  ngx.print('\r\
     </div>\r\
    </div>\r\
</div>\r\
');  
end
  ngx.print('\r\
'); 