-- Enable localization
gettext.textdomain('webui-core')

local json = require("dkjson")
local ngx = ngx

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local port_columns = {
  {--[1]
    header = T"Type",
    name = "type",
    param = "paramindex",
    type = "text",
    readonly = true,
  },
  {--[2]
    header = T"Status",
    name = "status",
    param = "status",
    type = "text",
    readonly = true,
  },
  {--[3]
    header = T"Speed",
    name = "speed",
    param = "speed",
    type = "text",
    readonly = true,
  },
  {--[4]
    header = T"Mode",
    name = "mode",
    param = "mode",
    type = "text",
    readonly = true,
  },
}

local  port_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "port",
    basepath = "sys.eth.port.@.",
}

-- Reuse the Ethernet snapshot to identify the WAN-capable port, rather than
-- reading eth4 again. Keep only request-local values; configuration can change
-- between polls and must never be served from a shared cache.
local ethernet_ports = content_helper.convertResultToObject(port_options.basepath,
	proxy.get("sys.eth.port."))
local ethname = "eth3"
for _, port in ipairs(ethernet_ports) do
	if port.paramindex == "eth4" and port.status then ethname = "eth4"; break end
end

local snapshot = {
	quantenna = "uci.env.var.qtn_eth_mac",
	wan = "uci.ethernet.port.@" .. ethname .. ".wan",
}
local radios = {}
for _, entry in ipairs(proxy.getPN("rpc.wireless.radio.", true) or {}) do
	local radio = entry.path:match("^rpc%.wireless%.radio%.@([^%.]+)%.$")
	if radio then
		local keys = {}
		for name, parameter in pairs({status = "admin_state", speed = "phy_rate",
			mode = "standard", band = "supported_frequency_bands"}) do
			local key = "radio_" .. (#radios + 1) .. "_" .. name
			keys[name] = key
			snapshot[key] = "rpc.wireless.radio.@" .. radio .. "." .. parameter
		end
		radios[#radios + 1] = {name = radio, keys = keys}
	end
end
-- Batch supported paths, but recover the available fields individually when
-- an older firmware rejects a missing optional path in the batch.
require("internethelper").getOptionalContent(snapshot)
local quantenna_wifi = snapshot.quantenna ~= ""

local port_filter = function(data)

	data.status_light = "1"

	if data.speed == "1000" then
		data.status_light = "1"
		data.speed = "1 Gbps"
	elseif data.speed == "100" then
		data.status_light = "2"
		data.speed = "100 Mbps"
	elseif data.speed == "10" then
		data.status_light = "3"
		data.speed = "10 Mbps"
	elseif data.speed == "" or data.speed == "0" then
		data.status_light = "0"
		data.speed = ""
	end

	data.status = ui_helper.createSimpleLight(data.status_light, "", {}, "fas fa-ethernet") --status

	if quantenna_wifi and data.paramindex:match("eth5") then
		return false
	elseif data.paramindex == ethname and snapshot.wan == "1" then
		data.paramindex = "WAN"
	else
		local port = data.paramindex:match("^eth(%d+)$")
		if port then
			data.paramindex = "LAN - " .. tonumber(port) + 1
		end
	end

  return true
end

local port_data = {}
for _, port in ipairs(ethernet_ports) do
	if port_filter(port) then
		port_data[#port_data + 1] = {port.paramindex, port.status or "", port.speed or "", port.mode or ""}
	end
end

local mode_labels = {
	bgn = "b/g/n",
	gn = "g/n",
	anac = "a/n/ac",
	an = "a/n",
}

for _, radio in ipairs(radios) do
	local wifi_content = {}
	for name, key in pairs(radio.keys) do wifi_content[name] = snapshot[key] end
	local enabled = wifi_content.status == "1"
	local speed = tonumber(wifi_content.speed)
	local band = wifi_content.band ~= "" and wifi_content.band or radio.name
	port_data[#port_data+1] = {
		"Wi-Fi " .. band,
		ui_helper.createSimpleLight(wifi_content.status or "0", "", {}, "fa fa-wifi"),
		enabled and speed and (speed / 1000 .. " Mbps") or "",
		enabled and (mode_labels[wifi_content.mode] or wifi_content.mode or "") or "",
	}
end

table.sort(port_data, function (a, b)
    return a[1] < b[1]
end)

local port_table = ui_helper.createTable(port_columns, port_data, port_options, nil, nil)

local port_string = {}

local function concat_table(port_table)
	for _ , table_string in pairs(port_table) do
		if type(table_string) == "table" then
			concat_table(table_string)
		elseif type(table_string) == "userdata" then
			port_string[#port_string+1] = string.untaint(table_string)
		else
			port_string[#port_string+1] = table_string
		end
	end
end

concat_table(port_table)

local data = {
	port_table = table.concat(port_string) or ""
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)
