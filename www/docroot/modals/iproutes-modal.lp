--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')
local format = string.format
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local vSII = post_helper.validateStringIsIP
local role = ngx.ctx.session:getrole()

local dyn_route_columns = {
    {
    header = T"Interface",
    name = "Iface",
    param = "Iface",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Destination",
    name = "Destination",
    param = "Destination",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Mask",
    name = "Mask",
    param = "Mask",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Gateway",
    name = "Gateway",
    param = "Gateway",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Source",
    name = "Source",
    param = "Source",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Metric",
    name = "Metric",
    param = "Metric",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
}

local dyn_route_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "dynamicroutes",
    basepath = "sys.class.iproutes.",
}

local dyn_route_data, dyn_route_helpmsg = post_helper.handleTableQuery(dyn_route_columns, dyn_route_options)

function split(x,sep)
    x = tostring(x)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    x:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

local dns_data = {}
local network_rpc_path = "rpc.network.interface."
local network_rpc_content = content_helper.getMatchedContent (network_rpc_path)

local dns_count = 1
local wan_intfs = {}
for _, v in pairs (network_rpc_content) do
   local path = split(split(format("%s",v["path"]),"@")[2],".")
   if (v["type"] == "wan" or "lan") and v["dnsservers"]  then
      local subcount = split(format("%s",v["dnsservers"]),",")
      dns_data[dns_count] = {path[1],subcount[1] or "",subcount[2] or "",subcount[3] or ""}
      dns_count = dns_count +1
   end
   if (v["type"] == "wan"  or "lan" ) then
       wan_intfs[#wan_intfs+1] = { path[1], T(path[1]) }
   end
end

local static_route_columns = {
  {
    header = T"Destination",
    name = "Destination",
    param = "target",
    type = "text",
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Mask",
    name = "Mask",
    param = "netmask",
    type = "text",
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Gateway",
    name = "Gateway",
    param = "gateway",
    type = "text",
    attr = { input = { class="span2 centered", id ="iproutesmodal_gateway" }},
  },
  {
    header = T"Metric",
    name = "Metric",
    param = "metric",
    type = "text",
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Interface",
    name = "Iface",
    param = "interface",
    default = "voip",
    type = "select",
    values = wan_intfs,
    attr = { select = { class="span2 centered" } },
  },
}

local static_route_options = {
    tableid = "staticroutes",
    basepath = "uci.network.route.",
}

if (role == "engineer") then
     static_route_options.createMsg = T"Add new static IPv4 route"
elseif (role == "admin") then
    static_route_options.canEdit = false
    static_route_options.canAdd = false
    static_route_options.canDelete = false
end


local function validateMask(value)
    if value == "" or vSII(value) then
        return true
    end
    return nil,T"invalid netmask"
end

local function validateGw(value)
    if value == "" or vSII(value) then
        return true
    end
    return nil,T"invalid gateway IP"
end

local static_route_valid = {
    Destination =  vSII,
    Mask = validateMask,
    Gateway = validateGw,
    Metric = post_helper.getValidateNumberInRange(1, 9999),
    Interface = post_helper.getValidateInEnumSelect(wan_intfs),
}
local static_route_data, static_route_helpmsg = post_helper.handleTableQuery(static_route_columns, static_route_options, nil, nil, static_route_valid)

local dns_columns = {
  {
    header = T"Interface",
    name = "Iface",
    param = "Iface",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"DNS Server 1",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"DNS Server 2",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"DNS Server 3",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
}

local dns_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "dnsinfo",
    basepath = "rpc.network.interface.",
}
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"IP Extras", false, true))   ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/iproutes-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"IPv4 Routes" ); ngx.print('</legend>\
      ');  
        ngx.print(
          ui_helper.createTable(dyn_route_columns, dyn_route_data, dyn_route_options, nil, dyn_route_helpmsg)
        )
        ngx.print('\
    </fieldset>\
\
    <fieldset>\
      <legend>');  ngx.print( T"IPv4 Static Routes Configuration" ); ngx.print('</legend>\
      ');  
        ngx.print(
          ui_helper.createTable(static_route_columns, static_route_data, static_route_options, nil, static_route_helpmsg)
        )
        ngx.print('\
    </fieldset>\
\
    <fieldset>\
      <legend>');  ngx.print( T"DNS" ); ngx.print('</legend>\
      ');  
        ngx.print(
          ui_helper.createTable(dns_columns, dns_data, dns_options, nil , nil)
        )
        ngx.print('\
    </fieldset>\
\
  </form>\
</div>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 