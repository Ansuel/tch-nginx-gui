--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local string, ngx = string, ngx
-- Firewall forwarding rules
local hlp_columns = {
  {
    header = T"Enable",
    name = "enable",
    param = "enable",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "left" }}
  },
  {
    header = T"Name",
    name = "helper",
    param = "helper",
    type = "text",
    unique = true,
    attr = { input = { class="span2", readonly="true"} },
  },
  {
    header = T"Dest Port",
    name = "dest_port",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", readonly="true" }},
  },
    {
    header = T"Protocol",
    name = "proto",
    param = "proto",
    type = "text",
    attr = { input = { class="span1", readonly="true" }},
  },
}

local hlp_attributes = {
}

-- Warning, this uses transformer paths. So use correct naming
local hlp_defaultObject = {
}

-- Removing duplicate entries having interface as loopback
local function hlp_filter(object)
  if object["intf"] == "loopback" then
     return nil
  end
  return true
end

local hlp_options = {
    tableid = "helper",
    basepath = "uci.firewall.helper.@.",
    canAdd = false,
    canDelete = false,
    canEdit = true,
    objectName  = post_helper.getRandomKey(),
    addNamedObject = true,
}

local hlp_data, hlp_helpmsg = post_helper.handleTableQuery(hlp_columns, hlp_options, hlp_filter, hlp_defaultObject)

--Look for the enable set to nothing and set to default "1"
for k, v in pairs (hlp_data) do
     if v[1] == "" then
        hlp_data[k][1] = "1"
     end
     hlp_data[k][2] = string.upper(v[2])
end

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"NAT Helpers (ALG's)", false, false))   ngx.print('\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/nat-alg-helper-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
    <fieldset>\
      ');  
        ngx.print(ui_helper.createTable(hlp_columns, hlp_data, hlp_options, hlp_attributes, hlp_helpmsg))
        ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 