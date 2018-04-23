-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local utils = require("web.lte-utils")

local redirect_sim, status, no_device, radio_interface, bars, signal_quality

local result = utils.getContent("rpc.mobiled.DeviceNumberOfEntries")
local devices = tonumber(result.DeviceNumberOfEntries)
if not devices or devices == 0 then
	no_device = utils.string_map["no_device"]
else
	local dev_idx = 1
	local rpc_path = string.format("rpc.mobiled.device.@%d.", dev_idx)

	result = utils.getContent(rpc_path .. "status")
	if result then
		if result.status ~= "Disabled" then
			status = utils.mobiled_state_map[result.status]
			if result.status == "Idle" then
				result = utils.getContent(rpc_path .. "network.sessions.@1.session_state")
				if result.session_state == "disconnected" then
					status = T"Registered"
				end
			end
			result = utils.getContent(rpc_path .. "radio.signal_quality.radio_interface")
			radio_interface = utils.radio_interface_map[result.radio_interface]

			local sim_state = utils.getContent(rpc_path .. "sim.sim_state").sim_state
			local pin_state = utils.getContent(rpc_path .. "sim.pin.pin_state").pin_state
			if sim_state == "ready" and (pin_state == "enabled_verified" or pin_state == "disabled") then
				result = utils.getContent(rpc_path .. "leds.")
				bars = result.bars
				signal_quality = utils.signal_quality_map[bars]
			end

			if sim_state == "ready" or sim_state == "locked" or sim_state == "blocked" then
				if pin_state == "enabled_not_verified" or pin_state == "blocked" then
					redirect_sim = true
					if pin_state == "enabled_not_verified" then
						status = T"Please enter PIN"
					else
						status = T"Please enter PUK"
					end
				elseif pin_state == "permanently_blocked" then
					status = T"SIM permanently blocked"
				end
			elseif sim_state == "not_present" then
				status = T"SIM not present"
			end
		end
	end
end

local data = {
	status = status or "",
	no_device = no_device or "",
	radio_interface = radio_interface or "",
	signal_quality = signal_quality or "",
	bars = bars or "",
	redirect_sim = redirect_sim or "false"
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	utils.sendResponse(buffer)
end
utils.sendResponse("{}")
