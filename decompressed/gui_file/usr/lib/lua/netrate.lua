-- Read network counters without subprocesses and calculate rates per client.
-- Samples have no shared mutable state: another browser cannot change a baseline.
local M = {}
local open = io.open
local WRAP32 = 4294967296
local WRAP_WINDOW = 268435456
local MAX_INTERVAL = 30
local MAX_WRAP_RATE = 1250000000 -- 10 Gbit/s; only a plausibility bound for wraps
local LINE = "^%s*(%S+):%s*(%d+)" .. string.rep("%s+%d+", 7) .. "%s+(%d+)"

local function firstLine(path)
    local file = open(path, "r")
    if not file then return nil end
    local line = file:read("*l")
    file:close()
    return line
end

local function nonnegative(value)
    local number = tonumber(value)
    if number and number >= 0 and number <= 9007199254740991 then return number end
end

function M.sample(interface)
    -- Taint support can be initialized after this module is first required.
    if string.untaint then interface = string.untaint(interface) end
    if type(interface) ~= "string" or #interface > 15 or not interface:match("^[%w_.-]+$") then
        return nil, "invalid_interface"
    end
    local uptime = firstLine("/proc/uptime")
    local time = uptime and nonnegative(uptime:match("^(%d+%.?%d*)"))
    if not time then return nil, "clock_unavailable" end

    -- On the supported gateways sysfs is substantially cheaper than scanning
    -- every interface. Keep proc as a fallback for missing driver attributes.
    local base = "/sys/class/net/" .. interface .. "/statistics/"
    local rx, tx = nonnegative(firstLine(base .. "rx_bytes")), nonnegative(firstLine(base .. "tx_bytes"))
    if not rx or not tx then
        local file = open("/proc/net/dev", "r")
        if file then
            for line in file:lines() do
                local name, received, sent = line:match(LINE)
                if name == interface then rx, tx = received, sent; break end
            end
            file:close()
        end
    end
    rx, tx = nonnegative(rx), nonnegative(tx)
    if not rx or not tx then return nil, "interface_unavailable" end
    return {rx = rx, tx = tx, time = time}
end

local function delta(previous, current, elapsed)
    if current >= previous then return current - previous end
    -- Treat decreases as resets except plausible 32-bit boundary crossings.
    -- Once a counter exceeds 32 bits, a decrease cannot be a 32-bit wrap.
    if previous < WRAP32 and previous >= WRAP32 - WRAP_WINDOW and current <= WRAP_WINDOW then
        local difference = WRAP32 - previous + current
        if difference / elapsed <= MAX_WRAP_RATE then return difference end
    end
end

function M.rate(previous, current)
    local before, after = {}, {}
    for _, key in ipairs({"rx", "tx", "time"}) do
        before[key] = nonnegative((previous or {})[key])
        after[key] = nonnegative((current or {})[key])
        if not before[key] or not after[key] then return nil, "initial_sample" end
    end
    local elapsed = after.time - before.time
    if elapsed <= 0 then return nil, "clock_reset" end
    if elapsed > MAX_INTERVAL then return nil, "stale_sample" end
    local rx = delta(before.rx, after.rx, elapsed)
    local tx = delta(before.tx, after.tx, elapsed)
    if not rx or not tx then return nil, "counter_reset" end
    return {rx = rx / elapsed, tx = tx / elapsed}
end

return M
