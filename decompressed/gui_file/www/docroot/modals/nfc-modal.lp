--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-nfc')

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local format = string.format
local vB = post_helper.validateBoolean

local qry_params = {
    enabled = "rpc.nfc.enabled",
}
local qry_valid = {
    enabled = vB,
}
local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)

local booleanMap = {
    ["true"] = "1",
    ["false"] = "0",
    ["1"] = "1",
    ["0"] = "0",
}

local nfc_columns = {
    {--[1]
        header = T"WIFI Interface",
        name = "wifi_iface",
        param = "wifi_iface",
        type = "text",
        readonly = true,
    },
    {--[2]
        header = "WIFI Status",
        name = "state",
        param = "state",
        type = "light",
        readonly = true,
    },
}

local nfc_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "nfc",
}

local function iface_state(iface)
    local statedata = proxy.get("rpc.wireless.ssid.@".. iface .. ".oper_state")
    local state = statedata and statedata[1] and statedata[1].value
    return state
end

local nfc_data = {}
local nfc_iface_number = proxy.get("uci.nfc.wifi_iface.iface.")
for i=1, #nfc_iface_number do
    local nfc_iface = {}
    local iface =  proxy.get("uci.nfc.wifi_iface.iface.@" .. i .. ".value")[1].value
    local iface_ssid = proxy.get("rpc.wireless.ssid.@" .. iface ..".ssid")[1].value
    nfc_iface[1] = iface_ssid
    nfc_iface[2] = iface_state(iface)
    nfc_data[#nfc_data + 1] = nfc_iface
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  
  local header = ui_helper.createHeader(T"NFC", false, true, nil, nil)
  header[1] = header[1]:gsub("span4", "span6")
  ngx.print(header)
  ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="/modals/nfc-modal.lp">\
    <fieldset>\
      <legend>');  ngx.print( T"Global Information" ); ngx.print('</legend>\
        ');  ngx.print( ui_helper.createSwitch(T"NFC Status", "enabled", booleanMap[string.untaint(qry_data["enabled"])]) ); ngx.print('\
    </fieldset>\
    <fieldset>\
      <legend>');  ngx.print( T"Wi-Fi Interface Status" ); ngx.print('</legend>\
      ');  ngx.print( ui_helper.createTable(nfc_columns, nfc_data, nfc_options, nil, nil) ); ngx.print('\
    </fieldset>\
  </form>\
</div>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
\
<script>\
$(function(){\
    $(\'#nfc tbody tr\').each (function() {\
        var status = $(this).find("td").eq(1).find("div");\
        var status_class = status.attr("class");\
        var status_hint = "Disabled";\
        if (status_class == "light green") {\
            status_hint = "Enabled";\
        }\
        status.attr({"class": "someInfos " + status_class, "rel": "tooltip", "data-placement": "top", "data-original-title": status_hint});\
    })\
    $(\'.someInfos\').tooltip();\
});\
</script>\
'); 