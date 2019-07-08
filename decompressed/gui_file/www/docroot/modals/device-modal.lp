--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local string, ngx, os = string, ngx, os
local tonumber = tonumber
local format, match = string.format, string.match
local gOrV = post_helper.getOrValidation
local vSIDN = post_helper.validateStringIsDomainName
local gVIES = post_helper.getValidateInEnumSelect
local pattern = "^Unknown%-%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$"
local proxy = require("datamodel")
local content_helper = require("web.content_helper")

local function validateUnknownHostname(value)
   return value:match(pattern)
end

-- devices forwarding rules
local devicetypes = {
    { "Generic", T"Generic" },
    { "DesktopComputer", T"DesktopComputer" },
    { "Laptop", T"Laptop" },
    { "STB", T"STB" },
    { "PDA", T"PDA" },
    { "GS", T"GS" },
    { "Phone", T"Phone" },
    { "GSM", T"GSM" },
    { "Printer", T"Printer" },
    { "Storage", T"Storage" },
    { "None", T"None" },
}
local priorityvalues = {
	{ "1", T"Priority"},
	{ "0", T"Normal"},
}
local devices_columns = {
  {--[1]
    header = T"Status",
    name = "state",
    param = "State",
    type = "light",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[2]
    header = T"Hostname",
    name = "FriendlyName",
    param = "FriendlyName",
    type = "text",
    attr = { input = { class="span3" } },
  },
  {--[3]
    header = T"IPv4",
    name = "ipv4",
    param = "IPv4",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[4]
    header = T"IPv6",
    name = "ipv6",
    param = "IPv6",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[5]
    header = T"MAC address",
    name = "macaddress",
    param = "MACAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[6]
    header = T"InterfaceType",
    name = "interfacetype",
    param = "InterfaceType",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[7]
    header = T"Priority",
    name = "priority",
    param = "Priority",
    type = "select",
	values = priorityvalues,
    attr = { select = { class="span2" } },
  },
  {--[8]
    header = T"Connection Time",
    name = "ConnectionTime",
    param = "ConnectedTime",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[9]
    header = T"Lease time",
    name = "dhcpLeaseTime",
    param = "DhcpLeaseTime",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[10]
    header = T"Device Type",
    name = "devicetype",
    param = "DeviceType",
    type = "select",
    values = devicetypes,
    attr = { select = { class="span2" } },
  },
  {--[11]
    header = T"SSID",
    name = "ssid",
    param = "SSID",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
}

local device_valid = {
    FriendlyName = gOrV(vSIDN, validateUnknownHostname),
	DeviceType = gVIES(devicetypes),
	Priority = gVIES(priorityvalues),
}
local devices_options = {
    canEdit = true,
    canAdd = false,
    canDelete = false,
    tableid = "devices",
    basepath = "rpc.hosts.host.",
}


--Construct the device type based on value of L2Interface
local devices_filter = function(data)
  --Display only the IP Address of physically connected devices
  if data["State"] and data["State"] == "0" then
     data["IPAddress"] = ""
  end

  --Display Interface Type to the user
  if data["L2Interface"] == "" then
    return false
  elseif match(data["L2Interface"], "^wl0") then
    data["InterfaceType"] = "wireless - 2.4GHz"
  elseif match(data["L2Interface"], "^wl1") then
    data["InterfaceType"] = "wireless - 5GHz"
  elseif match(data["L2Interface"], "eth*") then
    data["InterfaceType"] = format("Ethernet - %s",data["Port"])
  elseif match(data["L2Interface"], "moca*") then
    data["InterfaceType"] = "MoCA"
  end

  return true
end

local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter , nil, device_valid)

for k, v in pairs (devices_data) do
   devices_data[k][1] = format("%s",v[1])
   devices_data[k][5] = format("%s",v[5])

    if v[1] == "1" then
      if v[9] ~= "" and v[8] ~= "" then
        v[9] = post_helper.secondsToTime(tonumber(v[9])- (os.time()- tonumber(v[8]))%tonumber(v[9])) or T"Infinite"
      else
        v[9]="-"
      end

      if v[8] ~= "" then
        v[8] = post_helper.secondsToTime(os.time()- tonumber(v[8]))
      else
        v[8] = "-"
      end
    else
      v[8] = "-"
      v[9] = "-"
    end
end


  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Devices", false, true) ); ngx.print('\
<div class="modal-body update no-save">\
');
	local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-device.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/device-modal.lp">\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
\
    <fieldset>\
      <legend>');  ngx.print( T"Devices" ); ngx.print('</legend>\
      ');  ngx.print( ui_helper.createTable(devices_columns, devices_data, devices_options, nil, devices_helpmsg) ); ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 
