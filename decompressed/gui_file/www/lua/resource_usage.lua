local M = {}

function M.format_mib(kib, omit_unit)
    if not kib then return "-" end
    return string.format(omit_unit and "%.1f" or "%.1f MiB", kib / 1024)
end

function M.memory()
    local file = io.open("/proc/meminfo", "r")
    if not file then return end

    local info = {}
    for line in file:lines() do
        local key, value = line:match("^(%w+):%s+(%d+)%s+kB$")
        if key then info[key] = tonumber(value) end
    end
    file:close()

    local total, free = info.MemTotal, info.MemFree
    if not total or total <= 0 or not free then return end
    local cache = math.max(0, (info.Cached or 0) + (info.SReclaimable or 0) - (info.Shmem or 0))
    local available = info.MemAvailable or (free + (info.Buffers or 0) + cache)
    available = math.min(total, available)
    return {total = total, free = free, available = available, used = total - available, cache = cache}
end

function M.cpu()
    local file = io.open("/proc/stat", "r")
    if not file then return end
    local line = file:read("*l")
    file:close()

    local fields = line and line:match("^cpu%s+([%d%s]+)$")
    if not fields then return end
    local ticks = {}
    for value in fields:gmatch("%d+") do
        ticks[#ticks + 1] = tonumber(value)
    end
    if #ticks < 4 then return end

    -- Guest times are already counted in user/nice. Treat I/O wait as idle.
    local total = 0
    for i = 1, math.min(#ticks, 8) do
        total = total + ticks[i]
    end
    return {total = total, idle = ticks[4] + (ticks[5] or 0)}
end

local function capacity(statvfs, path)
    local ok, stat = pcall(statvfs, path)
    if not ok or type(stat) ~= "table" then return {} end
    local blocks = tonumber(stat.f_bavail)
    local total_blocks = tonumber(stat.f_blocks)
    local size = tonumber(stat.f_frsize)
    if not size or size <= 0 then size = tonumber(stat.f_bsize) end
    if not size or size <= 0 then return {} end
    return {
        available = blocks and blocks >= 0 and blocks * size or nil,
        total = total_blocks and total_blocks > 0 and total_blocks * size or nil,
    }
end

function M.format_storage(bytes)
    if not bytes then return "-" end
    local mib = bytes / 1048576
    if mib >= 1024 then return string.format("%.2f GiB", mib / 1024) end
    return string.format("%.1f MiB", mib)
end

function M.format_capacity(space)
    if not space.total then return M.format_storage(space.available) end
    local units, format, divisor = "MiB", "%.1f", 1048576
    if space.total >= 1073741824 then
        units, format, divisor = "GiB", "%.2f", 1073741824
    end
    local available = space.available and string.format(format, space.available / divisor) or "-"
    return available .. "/" .. string.format(format, space.total / divisor) .. " " .. units
end

function M.storage()
    local ok, posix = pcall(require, "tch.posix")
    local usb = {}
    if not ok or type(posix.statvfs) ~= "function" then return {}, usb end
    local mounts = io.open("/proc/mounts", "r")
    if mounts then
        for line in mounts:lines() do
            local device, mount = line:match("^/dev/(sd[a-z]%d*)%s+(/tmp/run/mountd/sd[a-z]%d*)%s")
            if device and mount == "/tmp/run/mountd/" .. device then
                if string.untaint then mount = string.untaint(mount) end
                local space = capacity(posix.statvfs, mount)
                space.device = device
                usb[#usb + 1] = space
            end
        end
        mounts:close()
    end
    -- /usr is on the filesystem used by the application installers.
    return capacity(posix.statvfs, "/usr"), usb
end

local interval = 9 -- Coalesce requests from dashboard and statistics.
local lifetime = 600
local limit = 60
local archive_lifetime = 3600
-- The GUI runs with one nginx worker and loads this module once per worker.
local samples = {}
local previous_cpu, previous_wan, previous_lan
local lan_interface = "br-lan"

local directory = "/tmp/trafficmon/"

local function read_archive_file(name, now)
    local lfs = require("lfs")
    local path = directory .. name
    local updated = lfs.attributes(path, "modification")
    if not updated or updated > now or now - updated >= archive_lifetime then return {}, {} end
    local file = io.open(path, "r")
    if not file then return {}, {} end

    -- trafficmon stores local HH:MM only. Anchor it to the file's latest write
    -- and verify the wall clock after crossing midnight or a DST boundary.
    local anchor = updated - updated % 60
    local minute = tonumber(os.date("%H", anchor)) * 60 + tonumber(os.date("%M", anchor))
    local header = tonumber(file:read("*l"))
    local slots = {}
    local rows = 0
    for line in file:lines() do
        rows = rows + 1
        if rows > 145 then break end
        local value, hour, min = line:match("^%s*(%d+%.?%d*)%s+(%d%d):(%d%d)%s*$")
        if value and tonumber(hour) < 24 and tonumber(min) < 60 then
            local difference = (minute - (tonumber(hour) * 60 + tonumber(min))) % 1440
            local time = anchor - difference * 60
            if now - time < archive_lifetime and time < now and os.date("%H:%M", time) == hour .. ":" .. min then
                -- The service overwrites matching HH:MM rows only. Older days
                -- can leave a second row one minute off the current schedule.
                local slot = math.floor((difference + 5) / 10)
                local distance = math.abs(difference - slot * 10)
                if not slots[slot] or distance < slots[slot].distance then
                    slots[slot] = {time = time, value = tonumber(value), distance = distance}
                end
            end
        end
    end
    file:close()
    if lfs.attributes(path, "modification") ~= updated then return {}, {} end
    local values, times = {}, {}
    for _, sample in pairs(slots) do
        values[sample.time] = sample.value
        times[#times + 1] = sample.time
    end
    table.sort(times)
    return values, times, header
end

local function rates(values, times)
    local result = {}
    for i = 2, #times do
        local elapsed = times[i] - times[i - 1]
        -- The rows hold byte differences, and the stock timer is 10 minutes.
        if elapsed >= 540 and elapsed <= 660 then
            result[times[i]] = values[times[i]] / elapsed
        end
    end
    return result
end

local function read_archive(now, interface, lan_interface)
    local cpu = read_archive_file("stats_cpu", now)
    local mem, _, total = read_archive_file("stats_mem", now)
    local points = {}
    local function point(time)
        if not points[time] then
            points[time] = {time = time, historical = true, interface = interface, lan = lan_interface ~= nil}
        end
        return points[time]
    end
    for time, value in pairs(cpu) do
        if value <= 100 then point(time).cpu = value end
    end
    if total and total > 0 then
        for time, available in pairs(mem) do
            if available <= total then point(time).ram = (total - available) * 100 / total end
        end
    end
    local function add_traffic(device, rx_field, tx_field)
        if type(device) ~= "string" or #device > 15 or not device:match("^[%w_.-]+$") then return end
        local rx = rates(read_archive_file(device .. "_rx_bytes", now))
        local tx = rates(read_archive_file(device .. "_tx_bytes", now))
        for time, received in pairs(rx) do
            if tx[time] then
                local sample = point(time)
                sample[rx_field], sample[tx_field] = received, tx[time]
            end
        end
    end
    add_traffic(interface, "rx", "tx")
    add_traffic(lan_interface, "lan_rx", "lan_tx")
    local result = {}
    for _, sample in pairs(points) do result[#result + 1] = sample end
    table.sort(result, function(a, b) return a.time < b.time end)
    return result
end

local function cpu_usage(previous, current)
    if not previous or not current then return end
    local total = current.total - previous.total
    local idle = current.idle - previous.idle
    if total > 0 and idle >= 0 and idle <= total then
        return (total - idle) * 100 / total
    end
end

local function collect(now, elapsed)
    local netrate = require("netrate")
    local cpu = M.cpu()
    local memory = M.memory()
    local traffic, _, interface = require("internethelper").sampleWanTraffic()
    local lan = netrate.sample(lan_interface)
    local point = {time = now, ram = memory and (memory.used * 100 / memory.total)}
    if elapsed and elapsed <= 30 then point.cpu = cpu_usage(previous_cpu, cpu) end
    if traffic and interface then
        point.interface = interface
        if previous_wan and previous_wan.interface == interface then
            local rate = netrate.rate(previous_wan.sample, traffic)
            if rate then point.rx, point.tx = rate.rx, rate.tx end
        end
    end
    if lan then
        point.lan = true
        local rate = netrate.rate(previous_lan, lan)
        if rate then point.lan_rx, point.lan_tx = rate.rx, rate.tx end
    end
    previous_cpu = cpu
    previous_wan = point.interface and {interface = interface, sample = traffic}
    previous_lan = lan
    if not elapsed or elapsed >= lifetime then
        samples = read_archive(now, point.interface, lan and lan_interface)
    end
    samples[#samples + 1] = point
end

function M.history(now, after)
    local last = samples[#samples]
    if last and now < last.time then
        samples, previous_cpu, previous_wan, previous_lan = {}, nil, nil, nil
        last = nil
    end
    local elapsed = last and (now - last.time)
    if not elapsed or elapsed >= interval then collect(now, elapsed) end
    for i = #samples, 1, -1 do
        local age = now - samples[i].time
        if i <= #samples - limit or age >= (samples[i].historical and archive_lifetime or lifetime) then
            table.remove(samples, i)
        end
    end

    local result = {}
    local offset
    if after then
        for i, sample in ipairs(samples) do
            if not sample.historical and sample.time == after then offset = i; break end
        end
    end
    for i = (offset or 0) + 1, #samples do
        result[#result + 1] = samples[i]
    end
    return {samples = result, replace = not offset}
end

return M
