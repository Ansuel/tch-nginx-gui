--pretranslated: do not change this file
 
-- Localization
--NG-101457 [TI] - Language Pack : [CTS-Workaround] Translation on Modal Parental Controle not taken into account
gettext.textdomain('webui-parental')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local table, ipairs = table, ipairs
local uinetwork = require("web.uinetwork_helper")
local hosts_ac, hosts_ac_v6 = uinetwork.getAutocompleteHostsList()
local match, format  = string.match, string.format
local tonumber, tostring = tonumber, tostring
local validateURL = post_helper.validateURL
local session = ngx.ctx.session

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean
local vSII = post_helper.validateStringIsIP
local vSIM = post_helper.validateStringIsMAC

local device = "All"
local site = ""

local function validateSite(value,data,key)
  local siteName = session:retrieve("parental_site")
  -- session variable duplicateCheck is used as a flag to check if Rules are duplicate
  session:store("duplicateCheck", "")
  if siteName then
    for _, v in ipairs(siteName) do
      if(v[2] == value) and data.devices_mac == v[1] then
        session:store("duplicateCheck", "true")
        return nil, T"Cannot add the same site for a MAC multiple time"
      end
    end
  end
  local url = string.match(value,"([^%s]+)")
  local success, err = validateURL(url,"http")
  if success then
    return true
  end
  return nil,err
end

if ngx.var.request_method == "POST" then
    local content = ngx.req.get_post_args()

    -- os.execute("/etc/init.d/urlfilterd-tch stop")
    -- os.execute("/etc/init.d/urlfilterd-tch start")
end

-- In UCI
-- config 'URLfilter'
--        option 'site' 'xxx.com'
--        option 'device' 'IPaddr (or "All")'

-- In Transformer
-- uci.parental.general.enable
-- uci.parental.general.exclude
-- uci.parental.@URLfilter[i].site
-- uci.parental.@URLfilter[i].device

local hostlist = {}
local hosts_mac = {}
for k, v in pairs(hosts_ac) do
  local mac = match(k, "%[(.*)%]")
  hosts_mac[#hosts_mac+1] = {mac, mac}
end
hosts_mac[#hosts_mac+1] = {"custom",T"custom"}

local qry_params = {
    sites_enabled = "uci.parental.general.enable",
    --sites_exclude = "uci.parental.general.exclude",
}

local qry_valid = {
    sites_enabled = vB,
}

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)

local uci_parental_path = "uci.parental.URLfilter."
local parental_columns = {
 {
        header = T"MAC Address",
        name = "devices_mac",
        param = "mac",
        type = "select",
        values = hosts_mac,
        attr = { input = { class = "span2",maxlength="17",id="lease_mac"}, autocomplete=hosts_mac },
    },
    {
        header = T"Site",
        name = "site",
        param = "site",
        type = "text",
        attr = { input = { class="span2" } },
    },
    {
        header = T"Device",
        name = "device",
        param = "device",
        type = "text",
        default = "All",
        attr = { input = { class="span2", maxlength="15"}, autocomplete=hosts_ac },
    },
}

local parental_options = {
    tableid         = "URLfilter",
    basepath        = uci_parental_path,
    createMsg       = T"Add New Site",
    canAdd          = true,
    canDelete       = true,
    canApply        = true,
    canEdit         = true,
}

local function validateDevice(value, object, key)
    -- confirm the entered value is a valid IP address or the special "All" entry
    if vSII(value) or (value == "All") then
        return true
    end

    -- the entry is not valid, mark it and return the help string
    return nil, T"Invalid device, entry must be either a valid IP or \"All\""
end

local entries_valid = {
    ["site"] = validateSite,
    ["device"] = validateDevice,
    ["devices_mac"] = vSIM,
}
local parental_filter = function(data)
  if not string.match(data["site"], "^http://") then
    local value = data["site"]
    data["site"] = "http://".. data["site"]
  end
  return true
end

local parental_data, parental_helpmsg = post_helper.handleTableQuery(parental_columns, parental_options, parental_filter, nil, entries_valid)
-- session variable parental_site contains all the Rules
session:store("parental_site", parental_data)

if ngx.var.request_method == "POST" then
  post_data = ngx.req.get_post_args()
  if ( post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT"  or  post_data.action == "TABLE-ADD") then
    local text_mac_index = tonumber(post_data.index)
    local text_mac
    if  post_data.action == "TABLE-ADD" then
      text_mac = post_data["devices_mac"]
    else
      text_mac = parental_data[text_mac_index][1]
    end
    local isDuplicate = session:retrieve("duplicateCheck")
    for _, mac in ipairs(hosts_mac) do
      if text_mac == mac[1] or isDuplicate == "true" then
        parental_columns[1] = {
        header = T"MAC address",
        name = "devices_mac",
        param = "mac",
        type = "text",
        attr = { input = { class="span2", maxlength="17", id= "lease_mac", value = text_mac }},
      }
        break
      end
    end
  end
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Parental Controls", false, false, nil) ); ngx.print('\
\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-tod.lp")
	gettext.textdomain('webui-parental')
  ngx.print('\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages()) ); ngx.print('\
  <form class="form-horizontal" method="post" action="modals/parental-modal.lp">\
    <legend>');  ngx.print( T"Site Blocking" ); ngx.print('</legend>\
');  ngx.print(
        ui_helper.createSwitch(T"Enabled", "sites_enabled", qry_data["sites_enabled"], nil, qry_helpmsg["sites_enabled"]),
        --ui_helper.createSwitch(T"Exclude Mode", "sites_exclude", qry_data["sites_exclude"], nil, qry_helpmsg["sites_exclude"]),
        ui_helper.createAlertBlock(T"Note:Parental control url filter not supported for https sites.",exporting_alert),
        ui_helper.createTable(parental_columns, parental_data, parental_options, nil, parental_helpmsg)
); ngx.print('\
  </form>\
</div>\
<script type=\'text/javascript\'>\
$("[name =\'devices_mac\']").change(function () {\
    if ((this.value) == "custom") {\
          $(this).replaceWith($(\'<input/>\',{\'type\':\'text\', \'name\':\'devices_mac\'}));\
    }\
});\
</script>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
\
'); 