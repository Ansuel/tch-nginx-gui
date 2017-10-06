-- @module models.igd.xtmconnection
--
-- @usage
-- local xtmconn = require "transformer.shared.models.igd.xtmconnection"
--
-- Used to order IGD.WANDevice{i}.WANConnectionDevice DSL objects based on xtmdevices
-- ordered in dmordering config and based on statickeys configured, persistent index
-- for the active wanconnectiondevice will be provided.
-- where ADSL and VDSL connections need same index of 1 based on active connection.

-- To use specific order dmordering to be populated with xtmdevices order in dmordering
-- For eg.,
-- config ordering 'xtmdevice'
--	list order 'ptm0'
--	list order 'atm_8_35'
--
-- To have fixed index(active = 1) populate dmordering with fixedkey section
-- Assumption of having (one active atmdevice or one ptmdevice) as per generic config
-- Limited to use fixed keys for first two devices only, to provide index 1 to active connection.
-- For eg.,
-- config fixedkey 'xtmdevicekeys'
--	list devicekey 'activeXTM'
--	list devicekey 'inactiveXTM'

local require = require
local match, lower = string.match, string.lower

local M = {}

local xdsl = require("transformer.shared.models.xdsl")
local dmordering = require("transformer.shared.models.dmordering")
local nwcommon = require("transformer.mapper.nwcommon")
local uciconfig = require("transformer.shared.models.uciconfig").Loader()
local split_key = nwcommon.split_key

-- fixed key related variables
local newkeys = {}
local xtm_static_key = {}
local xdslmode = "NONE"
local statkeys = {}
local dmorder
local valid_dsl_mode = {
			["ATM"] = true,
			["PTM"] = true,
			["NONE"] = true }

local function statickeys_present()
	return #statkeys ~= 0
end

-- static_keys to be updated only if the dsl connection type changes
-- Dont need to update static keys when moving to "NONE" (disconnected).
local function statickeys_update_needed()
	if not statickeys_present() then
		return false
	end
	local current_xdslmode = xdsl.mode()
	if current_xdslmode ~= xdslmode then
		if valid_dsl_mode[current_xdslmode] and current_xdslmode ~= "NONE" then
			xdslmode = current_xdslmode
			return true
		else
			xdslmode = "NONE"
		end
	end
	return false
end

-- Replace active dsl connection device key with static key to get
-- active connection device as first object(index) and other devices in orginal order
local function update_static_keys(devicelist)
	local devices = {}
	local devicecount = 0
	local keymode = { active = 1, inactive = 2 }

	for _, device in ipairs(devicelist) do
		devices[#devices + 1] = device
	end
	devicecount = #devices
	if devicecount == 0 then
		return
	end
	if match(devices[keymode.active], lower(xdslmode)) or xdslmode == "NONE" or devicecount == 1 then
		xtm_static_key[statkeys[keymode.active]] = devices[keymode.active]
		xtm_static_key[statkeys[keymode.inactive]] = devices[keymode.inactive]
	else
		xtm_static_key[statkeys[keymode.active]] = devices[keymode.inactive]
		xtm_static_key[statkeys[keymode.inactive]] = devices[keymode.active]
	end
	devices[keymode.active] = statkeys[keymode.active]
	devices[keymode.inactive] = devices[keymode.inactive] and statkeys[keymode.inactive]
	newkeys = devices
	return newkeys
end

--sort xtmdevices in the dmordering order
local function sortOnKeyMatch(device_keys , order)
	if not order then
		return device_keys
	end
	local all = {}
	local result = {}

	for _, keyset in ipairs(device_keys) do
		local _, index = split_key(keyset)
		all[index] = keyset
	end
	--add the devicelist as per xtmdevice order in dmordering
	for _, key in ipairs(order) do
		if all[key] then
			result[#result + 1] = all[key]
			all[key] = nil
		end
	end
	-- append other xtmdevices in original order
	for _, keyset in ipairs(device_keys) do
		local _, index = split_key(keyset)
		if all[index] then
			result[#result + 1] = all[index]
		end
	end
	return result
end

local config_loaded = false
-- Load necessary dmordering configuration on first load or config change
local function load_dmmodel_config()

	if not config_loaded then
		uciconfig:load("xtm")
		local dmordercfg = uciconfig:load("dmordering")
		dmorder = dmordering.getOrder("xtmdevice")
		-- config.sectiontype.sectionname.option (list)
		if dmordercfg.fixedkey then
			statkeys = dmordercfg.fixedkey.xtmdevicekeys.devicekey
		end
		if statickeys_present() then
			xdslmode = xdsl.mode()
		end
	end
	return true
end

-- Check for updates if any in the dmordering or xtm config
-- If config changed or dsl connection type changed, load config
local function devicekeys_update_needed()
	local config_updated = false
	if uciconfig:config_changed() then
		config_loaded = false
		config_updated = load_dmmodel_config()
	end
	if statickeys_update_needed() then
		return true
	end
	return config_updated
end

-- dmordering is mandatory for persistentkeys, if no dmorder return actual keys
-- statickeys to be updated only on dsl connection change or on config update
function M.loadStatic_keys(device_keys)
	load_dmmodel_config()
	if not dmorder then
		config_loaded = true
		return device_keys
	end

	if config_loaded and not devicekeys_update_needed() then
		return newkeys
	end

	config_loaded = true
	newkeys = sortOnKeyMatch(device_keys, dmorder)

	if not statickeys_present() then
		return newkeys
	end
	return update_static_keys(newkeys)
end

-- resolve the static key to actual devicename
function M.resolve_key(key)
	return xtm_static_key[key] or key
end

-- find corresponding static key for the devicename
function M.get_static_key(devname)
	if not statickeys_present() then
		return devname
	end
	for key, value in pairs(xtm_static_key) do
		if match(value, devname) then
			return key
		end
	end
	return devname
end

return M
