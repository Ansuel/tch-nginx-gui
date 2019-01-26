--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")

local session = ngx.ctx.session
local modalPath = "/modals/relay-modal.lp"
if session:hasAccess(modalPath) then

local dhcprelay_state = "connected"

local relay_Params = {
    uci_relay_server_ip = "uci.dhcp.relay.@relay.server_addr",
    uci_relay_local_ip = "uci.dhcp.relay.@relay.local_addr",
    interface = "uci.dhcp.relay.@relay.interface",
    uci_pppoerelay_interface = "uci.network.interface.@lan.pppoerelay.@1.value"
}
local getBackUpValues = content_helper.convertResultToObject("uci.dhcp.relaybackup.", proxy.get("uci.dhcp.relaybackup."))
content_helper.getExactContent(relay_Params)

local server_addr = proxy.get("uci.dhcp.relay.@relay.server_addr")

if not server_addr or (server_addr[1].value == "" and proxy.get("uci.dhcp.relay.@relay.local_addr")[1].value == "") then
  dhcprelay_state = "disabled"
  if getBackUpValues and next(getBackUpValues) then
    for _, v in pairs(getBackUpValues) do
      relay_Params["uci_relay_server_ip"] = v.server_addr
      relay_Params["uci_relay_local_ip"]  = v.local_addr
      relay_Params["interface"]  = v.interface
    end
  end
end

local dhcp_light_map = {
  disabled = "off",
  connected = "green",
}
local dhcp_state_map = {
    disabled = T"DHCP Relay disabled",
    connected = T"DHCP Relay enabled",
}
local ppp_light_map = {
  disabled = "off",
  connected = "green",
}
local ppp_state_map = {
    disabled = T"PPPoE Relay disabled",
    connected = T"PPPoE Relay enabled",
}

  pppoerelay_state = "disabled"
if proxy.get("uci.network.interface.@wan.ifname")[1].value == relay_Params["uci_pppoerelay_interface"] then
  pppoerelay_state = "connected"
end

  ngx.print('\
<div class="span3">\
    <div class="smallcard" data-aos="fade-up" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
      ');  ngx.print( ui_helper.createCardHeader(T"Relay Setup", "modals/relay-modal.lp") ); ngx.print('\
      <div class="content card_bg" data-bg-text="&#xf079;">\
	  <div class="divtable">\
        ');
--		ngx.print(ui_helper.createSimpleLight(nil, dhcp_state_map[dhcprelay_state] , { light = { class = dhcp_light_map[dhcprelay_state], id = "relaysetupcard_dhcprelaystatusled" },  span = { id = "relaysetupcard_dhcprelaystatus" }}))
--          if server_addr and not server_addr[1].value == "" then
--		    ngx.print(format('<p class = "subinfos" > Server IP : <strong id="relaysetupcard_relayip_server_ip">%s</strong></p>',relay_Params["uci_relay_server_ip"] ))
--            ngx.print(format('<p class = "subinfos" > Local IP : <strong id="relaysetupcard_relayip_local_ip">%s</strong></p>',relay_Params["uci_relay_local_ip"] ))
--            ngx.print(format('<p class = "subinfos" > Interface : <strong id="relaysetupcard_relay_interface">%s</strong></p>',relay_Params["interface"] ))
--          end
		ngx.print(ui_helper.createSimpleLight(nil, ppp_state_map[pppoerelay_state] , { light = { class = ppp_light_map[pppoerelay_state], id = "relaysetupcard_pppoerelaystatusled" },  span = { id = "relaysetupcard_pppoerelaystatusled" }}))
		  if pppoerelay_state == "connected" then
		    ngx.print(format('<p class = "subinfos">'..T'Interface'..': <strong id="relaysetupcard_pppoerelay_interface">%s</strong></p>', relay_Params["uci_pppoerelay_interface"]))
          end
		  ngx.print('\
     </div>\
	 </div>\
    </div>\
</div>\
');  
end
  ngx.print('\
'); 