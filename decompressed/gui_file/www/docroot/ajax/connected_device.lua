-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local content_helper = require("web.content_helper")
local ngx = ngx

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local string, ngx, os = string, ngx, os
local tonumber = tonumber
local format, match = string.format, string.match
local gOrV = post_helper.getOrValidation
local vSIDN = post_helper.validateStringIsDomainName
local pattern = "^Unknown%-%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$"

local devices_columns = {
  {--[2]
    header = T"Hostname",
    name = "FriendlyName",
    param = "FriendlyName",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {--[3]
    header = T"IPv4",
    name = "ipv4",
    param = "IPAddress",
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
  {--[11]
    header = T"SSID",
    name = "ssid",
    param = "SSID",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
}

local device_valid = {
    FriendlyName = gOrV(vSIDN, validateUnknownHostname),
}
local devices_options = {
    canEdit = false,
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

  if match(data["L2Interface"], "^wl0") then
    data["InterfaceType"] = "wireless - 2.4GHz"
  elseif match(data["L2Interface"], "^wl1") then
    data["InterfaceType"] = "wireless - 5GHz"
  elseif match(data["L2Interface"], "eth*") then
    data["InterfaceType"] = "Ethernet"
  elseif match(data["L2Interface"], "moca*") then
    data["InterfaceType"] = "MoCA"
  end

  --Display some default device type, when DeviceType entry is empty
  if data["DeviceType"] == "" then
    if match(data["L2Interface"], "eth*") then
      data["DeviceType"] = "DesktopComputer"
    elseif match(data["L2Interface"], "^wl*") then
      data["DeviceType"] = "Phone"
    else
      data["DeviceType"] = "unknown"
    end
  end
  return true
end

local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter , nil, device_valid)

local connected_device = {}

for k, v in pairs(devices_data) do
	if proxy.get(format("rpc.hosts.host.%s.State",k))[1].value == "1" then
		table.insert(connected_device,devices_data[k])
	end
end

local buffer = {}
if json.encode (connected_device, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)