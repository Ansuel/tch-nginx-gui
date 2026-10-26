-- Enable localization
gettext.textdomain('webui-mobiled')

local content_helper = require("web.content_helper")
local utils = require("web.lte-utils")
local proxy = require("datamodel")
local json = require("dkjson")

local post_data = ngx.req.get_post_args()

local max_age = tonumber(post_data.max_age) or 5
local dev_idx = tonumber(post_data.dev_idx) or 1

local function setfield(t, f, v)
	for w, d in string.gmatch(f, "([%w_]+)(.?)") do
		if d == "." then
			t[w] = t[w] or {}
			t = t[w]
		else
			t[w] = v
		end
	end
end

local function convert_to_object(data, basepath, output)
	if not output then output = {} end
	if data and basepath then
		for _, entry in pairs(data) do
			local additional_path = entry.path:gsub(basepath, '')
			if additional_path and additional_path ~= '' then
				setfield(output, additional_path .. entry.param, entry.value)
			else
				output[entry.param] = entry.value
			end
		end
	end
	return output
end

if not post_data.data_period then
	utils.sendResponse({'{ error : "Invalid data_period" }'})
	return
end

if not post_data.request_data then
	utils.sendResponse({'{ error : "Invalid request_data" }'})
	return
end

local request_data = json.decode(string.untaint(post_data.request_data))

local path

-- Retrieve signal quality history
local history
if request_data.history then
	history = {}
	path = string.format("rpc.ltedoctor.signal_quality.@%s.", post_data.data_period)
	proxy.set(path .. "dev_idx", tostring(dev_idx))
	local uptime_info = {
		period_seconds = path .. 'period_seconds',
		current_uptime = path .. 'current_uptime'
	}
	content_helper.getExactContent(uptime_info)
	history.period_seconds = tonumber(uptime_info.period_seconds)
	history.current_uptime = tonumber(uptime_info.current_uptime)

	if request_data.history.last_uptime then
		path = "rpc.ltedoctor.signal_quality.@diff."
		proxy.set(path .. "since_uptime", tostring(request_data.history.last_uptime))
		proxy.apply()
	end

	history.starting_uptime = 0
	if history.period_seconds and history.current_uptime > history.period_seconds then
		history.starting_uptime = history.current_uptime - history.period_seconds
	end

	path = path .. 'entries.'
	history.data = content_helper.convertResultToObject(path, proxy.get(path))
end

-- Retrieve current signal quality parameters
local current_data
if request_data.current then
	current_data = {}

	local base_path = string.format('rpc.mobiled.device.@%d.', dev_idx)

	proxy.set(base_path .. 'radio.signal_quality.max_age', tostring(max_age))
	path = base_path .. 'radio.signal_quality.'
	local signal_quality = proxy.get(path)
	convert_to_object(signal_quality, path, current_data)

	path = base_path .. 'radio.signal_quality.additional_carriers.'
	current_data.additional_carriers = content_helper.convertResultToObject(path, proxy.get(path))

	proxy.set(base_path .. 'network.serving_system.max_age', tostring(max_age))
	path = base_path .. 'network.serving_system.'
	local serving_system = proxy.get(path)
	convert_to_object(serving_system, path, current_data)

	path = base_path .. 'leds.bars'
	local leds = proxy.get(path)
	if leds then
		current_data['bars'] = leds[1].value
	end

	local filter = {
		"AdditionalCarriersNumberOfEntries",
		"NeighbourCellsNumberOfEntries"
	}
	for _, f in pairs(filter) do
		current_data[f] = nil
	end
end

-- Retrieve alarms
local alarms
if request_data.alarms then
	alarms = {}
	path = string.format("rpc.ltedoctor.alarms.@%s.", post_data.data_period)
	proxy.set(path .. "dev_idx", tostring(dev_idx))
	local uptime_info = {
		period_seconds = path .. 'period_seconds',
		current_uptime = path .. 'current_uptime'
	}
	content_helper.getExactContent(uptime_info)
	alarms.period_seconds = tonumber(uptime_info.period_seconds)
	alarms.current_uptime = tonumber(uptime_info.current_uptime)

	if request_data.alarms.last_uptime then
		path = "rpc.ltedoctor.alarms.@diff."
		proxy.set(path .. "since_uptime", tostring(request_data.alarms.last_uptime))
		proxy.apply()
	end

	alarms.starting_uptime = 0
	if alarms.period_seconds and alarms.current_uptime > alarms.period_seconds then
		alarms.starting_uptime = alarms.current_uptime - alarms.period_seconds
	end

	path = path .. 'entries.'
	alarms.data = content_helper.convertResultToObject(path, proxy.get(path))
	for _, alarm in pairs(alarms.data) do
		alarm.uptime = tonumber(alarm.uptime)
	end
end

-- Retrieve stats
local stats
if request_data['stats'] then
	stats = {
		network = {}
	}
	local network_stats = proxy.get("rpc.mobiled.device.@1.stats.network.")
	if network_stats then
		for _, entry in pairs(network_stats) do
			stats.network[entry.param] = entry.value
		end
	end
	path = "rpc.mobiled.device.@1.stats.sessions."
	stats.sessions = content_helper.convertResultToObject(path, proxy.get(path))
end

local data = {
	current = current_data,
	history = history,
	alarms = alarms,
	stats = stats,
	data_period = post_data.data_period
}

local buffer = {}
local success = json.encode (data, { indent = false, buffer = buffer })
if success and buffer then
	utils.sendResponse(buffer)
end

utils.sendResponse({'{ error : "Failed to encode data" }'})
