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
local uniqueKey = post_helper.getRandomKey()
local gAV = post_helper.getAndValidation

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

local function split(x, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    for field in x:gmatch(pattern) do
      fields[#fields+1] = field
    end
    return fields
end

local network_rpc_path = "rpc.network.interface."
local network_rpc_content = content_helper.getMatchedContent (network_rpc_path)

local wan_intfs = {}
for _, v in ipairs (network_rpc_content) do
   local path = split(split(format("%s",v.path),"@")[2],".")
   if v.type == "wan" or v.type == "lan" then
     if v.proto ~= "dhcpv6" and v.proto ~= "6rd" then
       wan_intfs[#wan_intfs+1] = { path[1], T(path[1]) }
     end
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

--@function to validate Duplicate Static Route
--@param object All object details coming from each rows in GUI the above table static_route_columns.
--@return #boolean, #string
local function validateDuplicateRoute(object)
  for k = 1, #object do
    for n = k+1, #object do
      if object[k][1] == object[n][1] and object[k][2] == object[n][2] and object[k][3] == object[n][3] and object[k][4] == object[n][4] and object[k][5] == object[n][5] then
      return nil, {Iface = T"Duplicate Static Route Found"}
      end
    end
  end
  return true
end

local static_route_options = {
    tableid = "staticroutes",
    basepath = "uci.network.route.@.",
    createMsg = T"Add new static IPv4 route",
    objectName  = "static_route_" .. uniqueKey,
    addNamedObject = true,
    valid = validateDuplicateRoute,
}

local function validateGW(ipAddress, object)
    local gwIP, ipErr = vSII(ipAddress)
    if gwIP then
      return gAV(post_helper.advancedIPValidation, post_helper.reservedIPValidation, post_helper.validateLXC)(ipAddress, object)
    end
    return nil, T"Invalid gateway IP."
end

local static_route_valid = {
    Destination = post_helper.validateIPAndSubnet,
    Mask = post_helper.validateIPv4Netmask,
    Gateway = validateGW,
    Metric = post_helper.getValidateNumberInRange(-9999, 9999),
    Interface = post_helper.getValidateInEnumSelect(wan_intfs),
}

local static_route_data, static_route_helpmsg = post_helper.handleTableQuery(static_route_columns, static_route_options, nil, nil, static_route_valid)

local dns_columns = {
  {
    header = T"Interface",
    name = "Ifname",
    param = "Ifname",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"DNS Used",
	name = "dnsservers",
	param = "dnsservers",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Custom DNS",
	name = "static_dns_servers",
	param = "static_dns_servers",
    type = "text",
    attr = { input = { class="span2 centered" } },
  },
}

local dns_options = {
    canEdit = true,
    canAdd = false,
    canDelete = false,
    tableid = "dnsinfo",
    basepath = "rpc.network.interface.",
}

local function validateCustoDns(value, object, key)
	
	local ret, err
	local servers = split(value,",")
	for _, server in pairs(servers) do
		ret, err = vSII(server)
		if not ret then
			return nil, err
		end
	end

	return true
end

local dns_valid = {
	static_dns_servers = validateCustoDns,
}

local dns_filer = function(data)

	if data.type == "wan" or data.type == "lan" then

		data.Ifname = data.paramindex:gsub("^@","")

		return true
	end

	return false
end

local dns_data, dns_helpmsg = post_helper.handleTableQuery(dns_columns, dns_options, dns_filer,nil,dns_valid)
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"IP Extras", false, true))   ngx.print('\
\
<div class="modal-body update">\
');
	local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-internet.lp")
ngx.print('\
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
          ui_helper.createTable(dns_columns, dns_data, dns_options, nil , dns_helpmsg)
        )
        ngx.print('\
    </fieldset>\
\
  </form>\
</div>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 