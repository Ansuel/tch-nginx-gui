-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local proxy = require("datamodel")
local utils = require("web.lte-utils")

local string, setmetatable = string, setmetatable

local function validate_pin(value)
	local errmsg = T"The PIN code must be composed of 4 to 8 digits."
	local pin = value:match("^(%d+)$")
	if pin ~= nil then
		if string.len(pin) >= 4 and string.len(pin) <= 8 then
			return true
		end
	end
	return nil, errmsg
end

local function validate_puk(value)
	local errmsg = T"The PUK code must be composed of 8 to 16 digits."
	local pin = value:match("^(%d+)$")
	if pin ~= nil then
		if string.len(pin) >= 8 and string.len(pin) <= 16 then
			return true
		end
	end
	return nil, errmsg
end

local function pin_error(action)
	local data = utils.getContent("rpc.mobiled.device.@1.sim.pin.")
	local unlock_retries = tonumber(data.unlock_retries_left) or 0
	local unblock_retries = tonumber(data.unblock_retries_left) or 0
	local err
	if action == "unlock" then
		err = string.format(N("Failed to verify the PIN code. ( %d retry left ) Please make sure you entered the correct PIN.",
								"Failed to verify the PIN code. ( %d retries left ) Please make sure you entered the correct PIN.",
								unlock_retries), unlock_retries)
	elseif action == "disable" then
		err = string.format(N("Failed to disable the PIN code. ( %d retry left ) Please make sure you entered the correct PIN.",
				"Failed to disable the PIN code. ( %d retries left ) Please make sure you entered the correct PIN.",
				unlock_retries), unlock_retries)
	elseif action == "enable" then
		err = string.format(N("Failed to enable the PIN code. ( %d retry left ) Please make sure you entered the correct PIN.",
				"Failed to enable the PIN code. ( %d retries left ) Please make sure you entered the correct PIN.",
				unlock_retries), unlock_retries)
	elseif action == "change" then
		err = string.format(N("Failed to change the PIN code. ( %d retry left ) Please make sure you entered the correct PIN.",
				"Failed to change the PIN code. ( %d retries left ) Please make sure you entered the correct PIN.",
				unlock_retries), unlock_retries)
	elseif action == "unblock" then
		err = string.format(N("Failed to verify the PUK code. ( %d retry left ) Please make sure you entered the correct PUK.",
				"Failed to verify the PUK code. ( %d retries left ) Please make sure you entered the correct PUK.",
				unblock_retries), unblock_retries)
	end
	if err then
		return false, err
	end
	return false, T"Unknown PIN action"
end

local function execute_action(post_data)
	local invalid_pin_error = T"Please enter a valid PIN."

	if post_data["action"] == "default" then
		return true
	elseif post_data["action"] == "change" then
		local ret, msg = validate_pin(post_data["old_pin"])
		if not ret then
			return false, invalid_pin_error .. " " .. msg
		end
		ret, msg = validate_pin(post_data["new_pin"])
		if ret ~= true then
			return false, invalid_pin_error .. " " .. msg
		end
		ret = proxy.set("rpc.mobiled.device.@1.sim.pin.change", post_data["old_pin"] .. ',' .. post_data["new_pin"])
		if not ret then
			return pin_error(post_data["action"])
		end
		return true
	elseif post_data["action"] == "disable" then
		local ret, msg = validate_pin(post_data["pin"])
		if not ret then
			return false, invalid_pin_error .. " " .. msg
		end
		ret = proxy.set("rpc.mobiled.device.@1.sim.pin.disable", post_data["pin"])
		if not ret then
			return pin_error(post_data["action"])
		end
		return true
	elseif post_data["action"] == "enable" then
		local ret, msg = validate_pin(post_data["pin"])
		if not ret then
			return false, invalid_pin_error .. " " .. msg
		end
		ret = proxy.set("rpc.mobiled.device.@1.sim.pin.enable", post_data["pin"])
		if not ret then
			return pin_error(post_data["action"])
		end
		return true
	elseif post_data["action"] == "unlock" then
		local ret, msg = validate_pin(post_data["pin"])
		if not ret then
			return false, invalid_pin_error .. " " .. msg
		end
		ret = proxy.set("rpc.mobiled.device.@1.sim.pin.unlock", post_data["pin"])
		if not ret then
			return pin_error(post_data["action"])
		end
		return true
	elseif post_data["action"] == "unblock" then
		local ret, msg = validate_pin(post_data["pin"])
		if not ret then
			return false, invalid_pin_error .. " " .. msg
		end
		ret, msg = validate_puk(post_data["puk"])
		if not ret then
			return false, msg
		end
		ret = proxy.set("rpc.mobiled.device.@1.sim.pin.unblock", post_data["pin"] .. ',' .. post_data["puk"])
		if not ret then
			return pin_error(post_data["action"])
		end
		return true
	end
	return false
end

local post_data = ngx.req.get_post_args()
setmetatable(post_data, { __index = function() return "" end })
local ret, msg = execute_action(post_data)

local pinInfo = utils.getContent("rpc.mobiled.device.@1.sim.pin.")
pinInfo['pin_state_hr'] = utils.pin_state_map[pinInfo['pin_state']]

local simInfo = utils.getContent("rpc.mobiled.device.@1.sim.imsi")

local data = {
	status = ret,
	error = msg,
	pin_info = pinInfo,
	sim_info = simInfo
}

local buffer = {}
ret = json.encode (data, { indent = false, buffer = buffer })
if ret then
	utils.sendResponse(buffer)
end
utils.sendResponse("{}")
