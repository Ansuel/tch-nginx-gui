local tonumber, ngx, tinsert = tonumber, ngx, table.insert
local io = { open = io.open }
local math = { floor = math.floor }

-- Enable localization
gettext.textdomain('webui-mobiled')

local uci = require("uci")
local json = require("dkjson")
local sqlite3 = require ("lsqlite3")
local utils = require("web.lte-utils")

local function parsePeriod(value)
	if not value then return nil end
	local pattern = "^(%d+)([dhms])$"
	local number, precision = value:match(pattern)
	number = number and tonumber(number)
	if not number or number < 1 then return nil end
	if precision == "m" then
		return number * 60
	elseif precision == "h" then
		return number * 3600
	elseif precision == "d" then
		return number * 3600 * 24
	end
	return number
end

local function get_uptime()
	local f = io.open("/proc/uptime")
	local line = f:read("*line")
	f:close()
	return math.floor(tonumber(line:match("[%d%.]+")))
end

local post_data = ngx.req.get_post_args()
local period = parsePeriod(post_data.data_period)
if not period then
	utils.sendResponse({'{ error = "Invalid period" }'})
end

local x = uci.cursor()
local path = x:get("lte-doctor", "logger", "path")
if not path or path == "" then
	path = "/tmp/lte-doctor.db"
end

local db = sqlite3.open(path)
if not db then
	utils.sendResponse({'{ error : "Failed to open database" }'})
end

db:busy_timeout(1000)

local table_exists = false
for line in db:nrows("SELECT name FROM sqlite_master WHERE type='table';") do
	if line.name == "log" then
		table_exists = true
	end
end

if not table_exists then
	utils.sendResponse({'{ error : "Failed to open log table" }'})
end

local answer = {
	data = {}
}

local query
local last_uptime = tonumber(post_data.last_uptime)

local starting_uptime = 0
local current_uptime = get_uptime()
if current_uptime > period then
	starting_uptime = current_uptime - period
end

-- Check if this is the first request. If so, return the entire data set
if not last_uptime then
	query = 'SELECT * FROM log WHERE uptime > ' .. starting_uptime .. ' ORDER BY uptime;'
else
	if last_uptime < starting_uptime then
		last_uptime = starting_uptime
	end
	query = 'SELECT * FROM log WHERE uptime > ' .. last_uptime .. ' ORDER BY uptime;'
	answer.starting_uptime = starting_uptime
end

answer.uptime = current_uptime
answer.period_seconds = period

for line in db:nrows(query) do
	tinsert(answer.data, line)
end

local buffer = {}
local success = json.encode (answer, { indent = false, buffer = buffer })
if success and buffer then
	utils.sendResponse(buffer)
end
utils.sendResponse({'{ error : "Failed to encode data" }'})
