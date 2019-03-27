--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")

local untaint = string.untaint

local uniqueKey = post_helper.getRandomKey()

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean

local intfs_select = {}

local intfs_pn = proxy.getPN("uci.network.interface.",true)
if intfs_pn then
    for _,v in ipairs(intfs_pn) do
        local path = v["path"]
        local intf_name = path:match("@([^@%.]-)%.")
        if intf_name and intf_name ~= "loopback" and intf_name ~= "lan" then
            intfs_select[#intfs_select + 1] = {intf_name,intf_name}
        end
    end
end

local function generate_ddns_supported_services()

	local ddns_supported_services = {}
	
    -- open the supported services file that come with the ddns package
    local f = io.open("/etc/ddns/services", "r")
    if f then
        for line in f:lines() do
            --a service in this file is  indicated as a url between quotes, we want a list with urls and name of service in capitals
            local service = line:match('^%b""')
            if service then
                service = service:gsub('"','')
                local serviceline = { service , service:upper() }
                ddns_supported_services[#ddns_supported_services + 1] = serviceline
            end
        end
        f:close()
    end
	
	return ddns_supported_services 
end

local ddns_supported_services = generate_ddns_supported_services()

local ddns_columns = {
  {
    header = T"State",
    name = "State",
    param = "ddns_light",
    type = "text",
	readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Update Info",
    name = "State",
    param = "ddns_status",
    type = "text",
	readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"",
    name = "State",
    param = "enabled",
    type = "switch",
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Service",
    name = "Service",
    param = "service_name",
    type = "select",
	values = ddns_supported_services,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Domain",
    name = "Domain",
    param = "domain",
    type = "text",
    attr = { input = { class="span2 centered", id ="iproutesmodal_gateway" }},
  },
  {
    header = T"Username",
    name = "Username",
    param = "username",
    type = "text",
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Password",
    name = "Password",
    param = "password",
    type = "password",
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"HTTPS",
    name = "HTTPS",
    param = "use_https",
    default = "1",
    type = "switch",
    attr = { select = { class="span2 centered" } },
  },
  {
    header = T"Interface",
    name = "Interface",
    param = "interface",
    default = "wan",
    type = "select",
	values = intfs_select,
    attr = { select = { class="span2 centered" } },
  },
}

local function onAddDDns(index, content)

	local ddns_path = "uci.ddns.service.@"..index

	proxy.set(ddns_path..".cacert","IGNORE")
	proxy.set(ddns_path..".lookup_host",untaint(content.Domain))
	proxy.set(ddns_path..".ip_network",untaint(content.Interface))
end

local function onUpdateDDns(index, content)

	local ddns_path = "uci.ddns.service.@"..index
	local domain = untaint(content.Domain)
	local interface = untaint(content.Domain)

	if not domain then
		domain = proxy.get(ddns_path..".domain")[1].value
	end
	
	if not interface then
		interface = proxy.get(ddns_path..".interface")[1].value
	end
	
	local ddns_lookup_host_path = ddns_path..".lookup_host"
	local ddns_lookup_host = proxy.get(ddns_lookup_host_path)
	
	if domain and ddns_lookup_host and domain ~= ddns_lookup_host[1].value then
		proxy.set(ddns_lookup_host_path,untaint(content.Domain))
	end
	
	local ddns_ip_network_path = ddns_path..".ip_network"
	local ddns_ip_network = proxy.get(ddns_ip_network_path)
	
	if interface and ddns_ip_network and domain ~= ddns_ip_network[1].value then
		proxy.set(ddns_ip_network_path,untaint(content.Interface))
	end
end

local ddns_options = {
    tableid = "ddnsoptions",
    basepath = "uci.ddns.service.@.",
    createMsg = T"Add new DDns Rule",
    objectName  = "ddns_"..uniqueKey,
    addNamedObject = true,
	canEdit = true,
	canAdd = true,
	canDelete = true,
	onAdd = onAddDDns,
	onModify = onUpdateDDns,
}

local ddns_valid = {
    State = vB,
	Service = post_helper.getValidateInEnumSelect(ddns_supported_services),
	Domain = post_helper.getOrValidation(post_helper.validateStringIsDomainName, post_helper.validateStringIsIP),
	Username = post_helper.validateNonEmptyString,
	Password = post_helper.getValidationPassword,
	HTTPS = vB,
}

local ddns_state_map = {
  disabled = T"Disabled",
  updating = T"Updating",
  updated = T"Updated",
  error = T"ERROR",
}

local ddns_light_map = {
  disabled = "0",--"off",
  updating = "2",--"orange",
  updated = "1",--"green",
  error = "4",--"red",
}

local function ddns_filter(data)

	local rpc_ddns_status = proxy.get("rpc.ddns.service.@"..data["paramindex"]..".status")
	
	local ddns_message = "No error"
	local ddns_status = "disabled"
	

	if rpc_ddns_status then
		
		rpc_ddns_status = rpc_ddns_status[1].value
	
		if rpc_ddns_status == "Domain's IP updated" then
			ddns_message = T"Domain's IP updated"
			ddns_status = "updated"
		elseif rpc_ddns_status == "No error received from server" then
			ddns_message = T"No error received from server"
			ddns_status = "updating"
		else
			ddns_message = rpc_ddns_status
			ddns_status = "error"
		end
	end

	data.ddns_light = ui_helper.createSimpleLight(ddns_light_map[ddns_status], "", {})
    data.ddns_status = string.format("%s : %s", ddns_state_map[ddns_status] , ddns_message or rpc_ddns_status or "")
	
	return true
end

local ddns_data, ddns_helpmsg = post_helper.handleTableQuery(ddns_columns, ddns_options, ddns_filter, nil, ddns_valid)

local info_box = {
    alert = {
      class = "alert-info"
    },
}

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"DynDns", false, false))   ngx.print('\
\
<div class="modal-body update">\
');
	local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-wanservices.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="/modals/dyndns-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"DynDNS" ); ngx.print('</legend>\
      ');
         ngx.print(
			ui_helper.createAlertBlock(T"Note: HTTPS mode will enable encryption but not certificate-based authentication of DynDNS service",info_box),
			ui_helper.createTable(ddns_columns, ddns_data, ddns_options, nil , ddns_helpmsg)
          )
        ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');