--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local string, ngx = string, ngx
local proxy = require("datamodel")
local test_modern = proxy.getPN("uci.firewall_helpers.helper.", true)
local is_modern = (test_modern and #test_modern > 0)
local basepath = is_modern and "uci.firewall_helpers.helper." or "uci.firewall.helper.@."

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
    name = is_modern and "name" or "helper",
    param = is_modern and "name" or "helper",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } }
  },
  {
    header = T"Dest Port",
    name = is_modern and "port" or "dest_port",
    param = is_modern and "port" or "dest_port",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" }}
  },
  {
    header = T"Protocol",
    name = "proto",
    param = "proto",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" }}
  },
}

local hlp_attributes = {
}

-- Warning, this uses transformer paths. So use correct naming
local hlp_defaultObject = {
}

-- Removing duplicate entries having interface as loopback
local function hlp_filter(object)
  if not is_modern and object["intf"] == "loopback" then
     return nil
  end
  return true
end

local hlp_options = {
    tableid = "helper",
    basepath = basepath,
    canAdd = false,
    canDelete = false,
    canEdit = true,
    objectName  = post_helper.getRandomKey(),
    addNamedObject = true,
}

local hlp_data, hlp_helpmsg = post_helper.handleTableQuery(hlp_columns, hlp_options, hlp_filter, hlp_defaultObject)

--Look for the enable set to nothing
for k, v in pairs (hlp_data or {}) do
     if v[1] == "" then
        hlp_data[k][1] = is_modern and "0" or "1"
     end
     hlp_data[k][2] = string.upper(v[2] or "")
end

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"NAT Helpers (ALG's)", false, false))   ngx.print('\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/nat-alg-helper-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
        ngx.print(ui_helper.createAlertBlock(T"NAT Helpers (ALG) allow protocols that embed network addresses to traverse NAT. In bridge mode, NAT is bypassed and managed by the upstream router.", { alert = { class = "alert-info" } }))
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
