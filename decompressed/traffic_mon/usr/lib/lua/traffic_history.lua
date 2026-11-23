local lfs = require("lfs")

local M = {directory = "/tmp/trafficmon/", retention = 24 * 60 * 60, interval = 600}

function M.read(name, now, retention)
    local values, times = {}, {}
    if type(name) ~= "string" then return values, times end
    if string.untaint then name = string.untaint(name) end
    if not name:match("^[%w_.-]+$") then return values, times end

    retention = retention or M.retention
    local path = M.directory .. name
    local updated = lfs.attributes(path, "modification")
    if not updated or updated > now or now - updated >= retention then return values, times end
    local file = io.open(path, "r")
    if not file then return values, times end
    local header = tonumber(file:read("*l"))

    local anchor = updated - updated % 60
    local minute = tonumber(os.date("%H", anchor)) * 60 + tonumber(os.date("%M", anchor))
    local legacy = {}
    for line in file:lines() do
        local value, time = line:match("^%s*(%d+%.?%d*)%s+(%d+)%s*$")
        if time then
            time = tonumber(time)
            if time <= now and now - time < retention then values[time] = tonumber(value) end
        else
            local hour, min
            value, hour, min = line:match("^%s*(%d+%.?%d*)%s+(%d%d):(%d%d)%s*$")
            if value and tonumber(hour) < 24 and tonumber(min) < 60 then
                -- Old files contain wall-clock labels only. Use the last write
                -- to recover their dates and discard duplicates from timer drift.
                local age = (minute - tonumber(hour) * 60 - tonumber(min)) % 1440
                time = anchor - age * 60
                local slot = math.floor((age * 60 + M.interval / 2) / M.interval)
                local distance = math.abs(age * 60 - slot * M.interval)
                if now - time < retention and os.date("%H:%M", time) == hour .. ":" .. min
                    and (not legacy[slot] or distance < legacy[slot].distance) then
                    legacy[slot] = {time = time, value = tonumber(value), distance = distance}
                end
            end
        end
    end
    file:close()
    if lfs.attributes(path, "modification") ~= updated then return {}, {} end

    for _, sample in pairs(legacy) do values[sample.time] = sample.value end
    for time in pairs(values) do times[#times + 1] = time end
    table.sort(times)
    return values, times, header, updated
end

function M.chart(times, values, total)
    local labels, data = {}, {}
    for i, time in ipairs(times) do
        labels[i] = string.format("%q", os.date("%H:%M", time))
        local value = values[time]
        if value and total then value = math.max(0, total - value) end
        data[i] = value and tostring(value) or "null"
    end
    return table.concat(labels, ","), table.concat(data, ",")
end

function M.traffic_chart(device, now)
    local rx, times = M.read(device .. "_rx_bytes", now)
    local tx, tx_times = M.read(device .. "_tx_bytes", now)
    for _, time in ipairs(tx_times) do
        if not rx[time] then times[#times + 1] = time end
    end
    table.sort(times)
    local labels, received = M.chart(times, rx)
    local _, sent = M.chart(times, tx)
    return {time = labels, rx = received, tx = sent}
end

return M
