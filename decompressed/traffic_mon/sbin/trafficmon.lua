#! /usr/bin/lua

local lfs = require("lfs")
local processinfo = require("transformer.shared.processinfo")
local uloop = require("uloop")
local history = require("traffic_history")

local directory, interval = history.directory, history.interval

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

local function write_sample(name, total, value, now, counter, initialize)
    if not total then return end
    local path = directory .. name
    if initialize and lfs.attributes(path, "mode") then return end
    local values, times, previous, updated = history.read(name, now)

    if counter and previous and updated then
        local elapsed = now - updated
        if elapsed >= interval - 60 and elapsed <= interval + 60 then
            value = math.max(0, total - previous)
        end
    end
    -- Store Unix timestamps so midnight and repeated hours do not reorder samples.
    local output = {string.format("%.0f", total), "\n"}
    for _, time in ipairs(times) do
        if time < now then
            output[#output + 1] = string.format("%s %d\n", tostring(values[time]), time)
        end
    end
    if value then output[#output + 1] = string.format("%s %d\n", tostring(value), now) end
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

local function collect_safely(initialize)
    -- Readers use atomic snapshots. An advisory lock serializes writers and
    -- is released by the kernel if the collector exits during a write.
    local file = io.open(directory .. ".writer.lock", "a+")
    if not file then return end
    if lfs.lock(file, "w") then
        local ok, err = pcall(collect, initialize)
        if not ok then io.stderr:write(tostring(err), "\n") end
    end
    file:close()
end

uloop.init()
if not lfs.attributes(directory, "mode") then lfs.mkdir(directory) end

local timer
local function schedule()
    timer = uloop.timer(function()
        collect_safely()
        schedule()
    end, interval * 1000)
end

collect_safely(true)
schedule()
uloop.run()
