local M = {
	time_entries = {
		last_five_minutes = {
			period_seconds = 300
		},
		last_twenty_minutes = {
			period_seconds = 1200
		},
		last_hour = {
			period_seconds = 3600
		},
		last_twentyfour_hours = {
			period_seconds = 86400
		},
		last_week = {
			period_seconds = 604800
		},
		last_month = {
			period_seconds = 2678400
		},
		diff = {},
		all = {}
	}
}

local dev_idx = 1
local export_location = "/tmp/"
local signal_quality_diff_since_uptime, alarms_diff_since_uptime

function M.getUptime(conn)
	local data = conn:call("system", "info", {})
	if data then
		return tonumber(data.uptime)
	end
end

function M.setSignalQualityDiffSinceUptime(uptime)
	signal_quality_diff_since_uptime = uptime
end

function M.getSignalQualityDiffSinceUptime()
	return signal_quality_diff_since_uptime
end

function M.setAlarmsDiffSinceUptime(uptime)
	alarms_diff_since_uptime = uptime
end

function M.getAlarmsDiffSinceUptime()
	return alarms_diff_since_uptime
end

function M.setDeviceIndex(idx)
	dev_idx = tonumber(idx) or 1
end

function M.getDeviceIndex()
	return dev_idx
end

local function get_error_info(err)
	if type(err) == 'string' then return err end
	if type(err) ~= 'table' or type(err.info) ~= 'table' then return nil end
	return string.format("line=%d, name=%s", err.info.currentline, err.info.name or "?")
end

local function export_set_error(export_mapdata, info)
	export_mapdata.state = "Error"
	export_mapdata.info = info or ""
end

function M.export_reset(export_mapdata)
	export_mapdata.state = "None"
	export_mapdata.info = ""
end

function M.export_init(location)
	local export_mapdata = {}
	M.export_reset(export_mapdata)
	if location then
		export_mapdata.location = location
	else
		export_mapdata.location = export_location
	end
	return export_mapdata
end

local function export_execute(export_mapdata)
	local rv
	local conn = require("ubus").connect()
	if not conn then
		return
	end
	-- write export data to file
	export_mapdata.info = "writing export data"
	rv = conn:call("ltedoctor", "export", { path = export_mapdata.location .. export_mapdata.filename })
	if rv and rv.error then
		export_set_error(export_mapdata, string.format("write export data failed (%s)", get_error_info(rv.error) or "?"))
		return
	end

	export_mapdata.state = "Complete"
	export_mapdata.info = "export succesfully completed"
end

function M.export_start(export_mapdata)
	if not export_mapdata.filename or export_mapdata.filename == "" then
		export_set_error(export_mapdata, "invalid filename")
		return
	end
	export_execute(export_mapdata)
end

return M
