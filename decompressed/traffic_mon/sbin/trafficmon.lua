#! /usr/bin/lua

local lfs = require("lfs")
local processinfo = require("transformer.shared.processinfo")
local uloop = require("uloop")

local directory = "/tmp/trafficmon/"
local interval = 600
local retention = 24 * 60 * 60

local function read_number(path)
    local file = io.open(path, "r")
    if not file then return end
    local value = tonumber(file:read("*l"))
    file:close()
    return value
end

local function memory()
    local file = io.open("/proc/meminfo", "r")
    if not file then return end
    local total, available
    for line in file:lines() do
        total = total or tonumber(line:match("^MemTotal:%s+(%d+)"))
        available = available or tonumber(line:match("^MemAvailable:%s+(%d+)"))
        if total and available then break end
    end
    file:close()
    return total, available
end

local function read_history(path, now)
    local rows = {}
    local updated = lfs.attributes(path, "modification")
    if not updated or updated > now or now - updated >= retention then return rows end
    local file = io.open(path, "r")
    if not file then return rows end
    local previous = tonumber(file:read("*l"))
    local anchor = updated - updated % 60
    local minute = tonumber(os.date("%H", anchor)) * 60 + tonumber(os.date("%M", anchor))
    for line in file:lines() do
        local value, hour, min = line:match("^%s*(%d+%.?%d*)%s+(%d%d):(%d%d)%s*$")
        if value and tonumber(hour) < 24 and tonumber(min) < 60 then
            local age = (minute - tonumber(hour) * 60 - tonumber(min)) % 1440
            local time = anchor - age * 60
            -- Use the previous write's phase when importing legacy rows, so
            -- 08:54 and 08:55 are treated as alternatives for the same slot.
            local offset = math.floor((age + 5) / 10)
            local distance = math.abs(age - offset * 10)
            if now - time < retention and os.date("%H:%M", time) == hour .. ":" .. min
                and (not rows[offset] or distance < rows[offset].distance) then
                rows[offset] = {time = time, value = value, distance = distance}
            end
        end
    end
    file:close()
    return rows, previous, updated
end

local function write_sample(name, total, value, now, counter, initialize)
    if not total then return end
    local path = directory .. name
    if initialize and lfs.attributes(path, "mode") then return end
    local rows, previous, updated = read_history(path, now)

    if counter and previous and updated then
        local elapsed = now - updated
        if elapsed >= interval - 60 and elapsed <= interval + 60 then
            value = math.max(0, total - previous)
        end
    end
    if value then rows[-1] = {time = now, value = value} end

    -- The existing traffic and modem-statistics views expect a header followed
    -- by "value HH:MM" rows in clock order. Keep only the newer repeated label.
    local by_label, labels = {}, {}
    for _, sample in pairs(rows) do
        local time = sample.time
        local label = os.date("%H:%M", time)
        local existing = by_label[label]
        if not existing then labels[#labels + 1] = label end
        if not existing or time > existing.time then
            by_label[label] = {time = time, value = sample.value}
        end
    end
    table.sort(labels)
    local output = {string.format("%.0f", total), "\n"}
    for _, label in ipairs(labels) do
        output[#output + 1] = tostring(by_label[label].value) .. " " .. label .. "\n"
    end
    local tmp = path .. ".tmp"
    local file = io.open(tmp, "w")
    if not file then return end
    local written = file:write(table.concat(output))
    local closed = file:close()
    if written and closed and os.rename(tmp, path) then return end
    os.remove(tmp)
end

local function collect(initialize)
    local now = os.time()
    for device in lfs.dir("/sys/class/net/") do
        if device ~= "." and device ~= ".." then
            for _, counter in ipairs({"tx_bytes", "rx_bytes"}) do
                local total = read_number("/sys/class/net/" .. device .. "/statistics/" .. counter)
                write_sample(device .. "_" .. counter, total, nil, now, true, initialize)
            end
        end
    end
    local total, available = memory()
    write_sample("stats_cpu", 100, tonumber(processinfo.getCPUUsage()), now, false, initialize)
    write_sample("stats_mem", total, available, now, false, initialize)
end

local function collect_locked(initialize)
    local lock = lfs.lock_dir(directory)
    if not lock then return end
    local ok, err = pcall(collect, initialize)
    lock:free()
    if not ok then io.stderr:write(tostring(err), "\n") end
end

uloop.init()
if not lfs.attributes(directory, "mode") then lfs.mkdir(directory) end

local timer
local function schedule()
    timer = uloop.timer(function()
        collect_locked()
        schedule()
    end, interval * 1000)
end

collect_locked(true)
schedule()
uloop.run()
