--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")

local upnp_tch = true

local upnp_non_tch = io.open("/etc/init.d/miniupnpd","r")

if upnp_non_tch then
	upnp_tch = nil
	upnp_non_tch:close()
end

local vB = post_helper.validateBoolean

local igd_select = {
    { "igdv1", T'1'},
    { "igdv2", T'2'},
}

local  mapParams = {
	status = "uci.upnpd.config.enable_upnp",
    natpmp = "uci.upnpd.config.enable_natpmp",
    secure_mode = "uci.upnpd.config.secure_mode",
}
  
local  mapValid = {
	status = vB,
    natpmp = vB,
    secure_mode = vB,
}

if upnp_tch then
	mapParams["igd_version"] = "uci.upnpd.config.datamodel_version"
	mapValid["igd_version"] = post_helper.getValidateInEnumSelect(igd_select)
end

local data, helpmsg = post_helper.handleQuery(mapParams, mapValid)

-- UPnP forwarding rules
local upnp_columns = {
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto",
    default = "tcp",
    type = "select",
    values = {
      { "tcp", "TCP"},
      { "udp", "UDP"},
      { "tcpudp", "TCP+UDP"}
    },
    attr = { select = { class="span2" } },
  },
  {
    header = T"WAN port",
    name = "wanport",
    param = "src_dport",
    type = "text",
    attr = { input = { class="span1", maxlength="5" } },
  },
  {
    header = T"LAN port",
    name = "lanport",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" } },
  },
  {
    header = T"Destination",
    name = "destinationip",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"} },
  },
  {
    header = T"Description",
    name = "description",
    param = "description",
    type = "text",
    attr = { input = { class="span2", maxlength="15"} },
  },
}

local upnp_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "upnpportforwarding",
    basepath = "sys.upnp.redirect.",
}

local upnp_data, upnp_helpmsg = post_helper.handleTableQuery(upnp_columns, upnp_options, nil, nil, nil)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"UPnP", false, false))   ngx.print('\
\
<div class="modal-body update">\
');
	local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-wanservices.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="/modals/upnp-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
      <fieldset>\
      ');  
        local html = {}
		
        html[ #html + 1 ] = ui_helper.createSwitch(T"UPnP IGD Enabled", "status", data["status"], nil, helpmsg["status"])
        html[ #html + 1 ] = ui_helper.createSwitch(T"NAT-PMP Enabled", "natpmp", data["natpmp"], nil, helpmsg["natpmp"])
        html[ #html + 1 ] = ui_helper.createSwitch(T"Secure Mode Enabled", "secure_mode", data["secure_mode"], nil, helpmsg["secure_mode"])
		if upnp_tch then
			html[ #html + 1 ] = ui_helper.createInputSelect(T"Datamodel Version", "igd_version", igd_select, data["igd_version"], nil)
			html[ #html + 1 ] = ui_helper.createLabel(T"", T"Note: Datamodel version <b>1</b> may be required for older applications.", {span = {class = "span6"},})
		end
        html[ #html + 1 ] = ui_helper.createTable(upnp_columns, upnp_data, upnp_options, nil, upnp_helpmsg)
        
		ngx.print(html)
		
        ngx.print('\
      </fieldset>\
	</form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');