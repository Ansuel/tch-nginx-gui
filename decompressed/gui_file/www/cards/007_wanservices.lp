--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ngx = ngx
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local dynDns_attributes = {
	light = { id = "DynDNS_Status_Led" },
	span = { class = "span4",
	id = "DynDNS_Status"}
}

local dmz_attributes = {
	light = { id = "DMZ_Status_Led" },
	span = { class = "span4",
	id = "DMZ_Status"}
}

local upnp_attributes = {
	light = { id = "UPNP_Status_Led" },
	span = { class = "span4",
	id = "UPNP_Status"}
}

-- WAN services data
local wan_services_data = {
  dmz_enable = "rpc.network.firewall.dmz.enable",
  dmz_blocked = "rpc.network.firewall.dmz.blocked",
  upnp_enabled = "uci.upnpd.config.enable_upnp",
  upnp_rules = "sys.upnp.RedirectNumberOfEntries",
  ddns_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
  --ddns_status = "rpc.ddns.status",
}
content_helper.getExactContent(wan_services_data)

local ddns_enabled_map = {
  ["0"] = T"DynDNS disabled",
  ["1"] = T"DynDNS enabled",
  [""] = T"DynDNS disabled",
}

local ddns_light_map = {
  ["0"] = "0",
  ["1"] = "1",
}

local state
local dmzstate
if wan_services_data["dmz_blocked"] == "1" then
  dmzstate = T"DMZ blocked"
  state = "0"
else
  if wan_services_data["dmz_enable"] == "1" then
    dmzstate = T"DMZ enabled"
    state = "1"
  else
    dmzstate = T"DMZ disabled"
    state = "0"
  end
end

local pf_path = proxy.get("rpc.network.firewall.portforward.")
local pf_data = content_helper.convertResultToObject("rpc.network.firewall.portforward.",pf_path)
local pf_rule_len = {}
for _,v in ipairs(pf_data) do
  if v.src == "wan" and v.dest == "lan" then
    pf_rule_len[#pf_rule_len+1] = 1
  end
end

local n_redir_rules = #pf_rule_len
local n_upnp_rules = tonumber(wan_services_data["upnp_rules"])
local modalPath = nil
local switchName = nil
local modal_link_port  = ""
local modal_link_upnp = ""
local session = ngx.ctx.session
if session:hasAccess("/modals/wanservices-modal.lp") then
  modalPath = "/modals/wanservices-modal.lp"
  modal_link_port = 'class="modal-link" id="PortForwarding_Id" data-toggle="modal" data-remote="/modals/wanservices-modal.lp" data-id="wanservices-modal"'
  modal_link_upnp = 'class="modal-link" id="upnp_Id" data-toggle="modal" data-remote="/modals/wanservices-modal.lp" data-id="wanservices-modal"'
end

local upnpstate_text
local upnpstate
if wan_services_data["upnp_enabled"] == "1" then
  upnpstate_text = format( N("<strong %s>%d UPnP</strong> rule is active",
                      "<strong %s>%d UPnP</strong> rules are active", n_upnp_rules),
                      modal_link_upnp, n_upnp_rules)
  upnpstate = "1"
else
  upnpstate_text = T"UPnP disabled"
  upnpstate = "0"
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"WAN Services", modalPath, switchName, nil) ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf0c2;">\
	<div class="divtable">\
    ');  ngx.print(
	    ui_helper.createSimpleLight(state, dmzstate, dmz_attributes,"fas fa-cogs"),
            ui_helper.createSimpleLight(ddns_light_map[format("%s", wan_services_data["ddns_enabled"])] or "0", ddns_enabled_map[format("%s", wan_services_data["ddns_enabled"])], dynDns_attributes,"fas fa-link"),
			ui_helper.createSimpleLight(upnpstate, upnpstate_text, dmz_attributes,"fas fa-random"),
            '<p></p>',
            '<p class="subinfos">',
            format( N("<strong %s>%d port forwarding</strong> rule is defined",
                      "<strong %s>%d port forwarding</strong> rules are defined", n_redir_rules),
                      modal_link_port, n_redir_rules),
	    '<br/>',
            '</p>'
        )
      ngx.print('\
	  </div>\
    </div>\
  </div>\
</div>\
'); 