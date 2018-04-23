local format, setmetatable, ipairs, pairs, ngx = string.format, setmetatable, ipairs, pairs, ngx

local intl = require("web.intl")
local function log_gettext_error(msg)
	ngx.log(ngx.NOTICE, msg)
end

local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext

local function setlanguage()
	gettext.language(ngx.header['Content-Language'])
end

-- Enable localization
-- NG-92675 implement changes required from the customer														
gettext.textdomain('webui-mobiled')

local lteParams = require("web.lte-params")
local proxy = require("datamodel")

local internal = {}

local map_empty_string = { __index = function() return "" end }

internal.radio_interface_map = {
	["no_service"]	= T"No service",
	["cdma"]		= T"CDMA",
	["umts"]		= T"UMTS",
	["gsm"]			= T"GSM",
	["lte"]			= T"LTE"
}

internal.radio_tech_map = {
	["cdma"]	= T"CDMA",
	["lte"]		= T"LTE",
	["umts"]	= T"UMTS",
	["gsm"]		= T"GSM",
	["auto"]	= T"Auto"
}

internal.radio_preference_map = {
	["auto"]           = T"Auto",
	["lte_preferred"]  = T"LTE Preferred",
	["lte_only"]       = T"LTE Only",
	["lte"]            = T"LTE",
	["umts_preferred"] = T"UMTS Preferred",
	["umts_only"]      = T"UMTS Only",
	["umts"]           = T"UMTS",
	["gsm_preferred"]  = T"GSM Preferred",
	["gsm_only"]       = T"GSM Only",
	["gsm"]            = T"GSM"
}

internal.antenna_map = {
	["internal"]	= T"Internal",
	["external"]	= T"External",
	["auto"]		= T"Auto"
}

internal.rrc_state_map = {
	["idle"]		= T"Idle",
	["connected"]	= T"Connected"
}

internal.mobiled_state_map = {
	["no_device"]			= T"Unplugged",
	["configuring_device"]	= T"Configuring device",
	["initializing_sim"]	= T"SIM locked",
	["connecting"]			= T"Connecting",
	["connected"]			= T"Connected",
	["disconnected"]		= T"Disconnected",
	["scanning_network"]	= T"Scanning networks",
	["upgrading_firmware"]	= T"Upgrading firmware",
	["SelectAntenna"]		= T"Selecting antenna",
	["disabled"]			= T"Disabled",
	["error"]				= T"Error"
}

internal.sim_state_map = {
	["error"]		= T"SIM error",
	["ready"]		= T"SIM ready",
	["not_present"]	= T"SIM not present"
}

internal.signal_quality_map = {
	["1"] = T"Poor",
	["2"] = T"Weak",
	["3"] = T"Fair",
	["4"] = T"Good",
	["5"] = T"Superb"
}

internal.nas_state_map = {
	["not_registered"]				= T"Not registered",
	["registered"]					= T"Registered",
	["not_registered_searching"]	= T"Searching for network",
	["registration_denied"]			= T"Registration denied"
}

internal.session_state_map = {
	["disconnected"]	= T"Disconnected",
	["disconnecting"]	= T"Disconnecting",
	["connected"]		= T"Connected",
	["connecting"]		= T"Connecting",
	["suspended"]		= T"Suspended",
	["authenticating"]	= T"Authenticating"
}

internal.pin_state_map = {
	["not_initialized"]			= T"Not initialized",
	["enabled_not_verified"]	= T"Not verified",
	["enabled_verified"]		= T"Verified",
	["disabled"]				= T"Disabled",
	["blocked"]					= T"Blocked",
	["permanently_blocked"]		= T"Permanently blocked"
}

internal.power_mode_map = {
	["online"]		= T"Online",
	["lowpower"]	= T"Low-power mode",
	["airplane"]	= T"Airplane mode"
}

internal.string_map = {
	["no_device"] = T"0 device connected",
}

internal.service_state_map = {
	["limited_regional_service"]	= T"Limited regional service",
	["limited_service"]				= T"Limited service",
	["normal_service"]				= T"Normal service",
	["no_service"]					= T"No service",
	["sleeping"]					= T"Sleeping"
}

local M = setmetatable({}, {
	__index = function(t, key)
		setlanguage()
		local requested_table = {}
		for k,v in pairs(internal[key]) do requested_table[k] = T(v) end
		setmetatable(requested_table, map_empty_string)
		return requested_table
	end
})

function M.getContent(path)
	local result = proxy.get(path)
	local temp = {}
	setmetatable(temp, { __index = function() return "" end })
	for _, v in ipairs(result or {}) do
		temp[v.param] = format("%s", v.value)
	end
	return temp
end

function M.Len(TABLE)
	local count = 0
	for _, _ in pairs(TABLE) do count = count + 1 end
	return count
end

function M.isTableValue(t, v)
	for _, val in pairs(t) do
		if v == val then
			return true
		end
	end
	return false
end

function M.sendResponse(content)
	ngx.say(content)
	ngx.exit(ngx.HTTP_OK)
end

function M.get_params()
	return lteParams.get_params()
end

function M.get_uci_device_path()
	local v = proxy.get("rpc.mobiled.device.@1.info.device_config_parameter")
	local device_config_parameter = ""
	if type(v) == "table" then device_config_parameter = v[1].value end
	if device_config_parameter ~= "" then
		v = proxy.get("rpc.mobiled.device.@1.info." .. device_config_parameter)
		local value
		if type(v) == "table" then value = v[1].value end
		if value then
			local data = proxy.get("uci.mobiled.device.")
			for _, d in pairs(data) do
				if d.param == device_config_parameter and d.value == value then
					return d.path
				end
			end
		end
	end
	return "uci.mobiled.device_defaults."
end

return M
