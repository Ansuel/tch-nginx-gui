--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")

local mapParams, mapValid

local wol_dest_port_select = {
    { "7", '7'},
    { "9", '9'},
}

local wol = io.open("/etc/init.d/wol", "r") and proxy.get("uci.wol.config.")

if wol then
  mapParams = {
	enabled = "uci.wol.config.enabled",
	ip = "uci.wol.config.dest_ip",
	port = "uci.wol.config.src_dport",
	dest_port = "uci.wol.config.dest_dport",
  }
  
  mapValid = {
	enabled = post_helper.validateBoolean,
	port = post_helper.validateStringIsPort,
	ip = post_helper.validateStringIsIP,
	dest_port = post_helper.getValidateInEnumSelect(wol_dest_port_select),
  }
  
  local data, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"WoL (Wake on LAN) & WoW (Wake on WAN)", false, false))   ngx.print('\
\
<div class="modal-body update">\
');
	local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-wanservices.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="/modals/wol-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
      <fieldset>\
        ');  
          ngx.print(ui_helper.createSwitch(T"Enabled", "WOL_enabled", data["enabled"], nil, helpmsg["enabled"]),
                    ui_helper.createInputText(T"Remote/WAN port", "WOL_port", data["port"], nil, helpmsg["port"]),
					ui_helper.createLabel(T"", T"You need to enter an unused LAN IP to make Wake on LAN/WAN work.", {span = {class = "span6"},}),
					ui_helper.createInputText(T"Unused IP", "WOL_ip", data["ip"], nil, helpmsg["ip"]),
					ui_helper.createInputSelect(T"Local/LAN Port", "WOL_dest_port", wol_dest_port_select, data["dest_port"],nil)
					)
          ngx.print('\
      </fieldset>\
	</form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');

end