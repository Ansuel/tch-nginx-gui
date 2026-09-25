-- Enable localization
gettext.textdomain('webui-core')

local json = require("dkjson")
local ngx = ngx

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local function getValue(path)
	local result = proxy.get(path)
	return result and result[1] and result[1].value or ""
end

local quantenna_wifi = getValue("uci.env.var.qtn_eth_mac") ~= ""
--Support ethernet mode for devices with no eth4 port
local ethname = proxy.get("sys.eth.port.@eth4.status")
if ethname and ethname[1] and ethname[1].value then
	ethname =  "eth4"
else
	ethname =  "eth3"
end

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
	elseif data.paramindex == ethname and getValue("uci.ethernet.port.@"..ethname..".wan") == "1" then
		data.paramindex = "WAN"
	else
		local port = data.paramindex:match("^eth(%d+)$")
		if port then
			data.paramindex = "LAN - " .. tonumber(port) + 1
		end
	end

  return true
end

local  port_data = content_helper.loadTableData(port_options.basepath, port_columns,  port_filter , nil) or {}

local mode_labels = {
	bgn = "b/g/n",
	gn = "g/n",
	anac = "a/n/ac",
	an = "a/n",
}

local radio_names = proxy.getPN("rpc.wireless.radio.", true) or {}
for _, radio_entry in ipairs(radio_names) do
	local radio = radio_entry.path:match("rpc%.wireless%.radio%.@([^%.]+)%.")
	if radio then
		local base_path = "rpc.wireless.radio.@" .. radio .. "."
		local wifi_content = {
			status = base_path .. "admin_state",
			speed = base_path .. "phy_rate",
			mode = base_path .. "standard",
			band = base_path .. "supported_frequency_bands",
		}
		content_helper.getExactContent(wifi_content)
		local enabled = wifi_content.status == "1"
		local speed = tonumber(wifi_content.speed)
		local band = wifi_content.band and wifi_content.band ~= "" and wifi_content.band or radio
		port_data[#port_data+1] = {
			"Wi-Fi " .. band,
			ui_helper.createSimpleLight(wifi_content.status or "0", "", {}, "fa fa-wifi"),
			enabled and speed and (speed / 1000 .. " Mbps") or "",
			enabled and (mode_labels[wifi_content.mode] or wifi_content.mode or "") or "",
		}
	end
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
