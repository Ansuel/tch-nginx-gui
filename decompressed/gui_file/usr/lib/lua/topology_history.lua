-- Runtime history for firmware that has MultiAP but no stock topologychg.
local M = {}
local path = "/var/run/topologychg.json"
local limit = 100

function M.read()
    local file = io.open(path, "r")
    if not file then return nil end
    local contents = file:read(65536)
    file:close()
    if not contents then return nil end
    local events = require("dkjson").decode(contents)
    return type(events) == "table" and events or nil
end

local function mac(value)
    value = (value or ""):upper():gsub("-", ":")
    if value:match("^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$") then return value end
    return ""
end

function M.snapshot(results, expected)
    local devices = {}
    for _, entry in ipairs(results) do
        local index = (entry.path or ""):match("^rpc%.multiap%.device%.([^%.]+)%.$")
        local param = entry.param
        if index and (param == "al_mac" or param == "parent"
            or param == "backhaul_interface_type" or param == "state") then
            devices[index] = devices[index] or {}
            devices[index][param] = entry.value
        end
    end

    local snapshot = {}
    local count = 0
    for _, device in pairs(devices) do
        local address = mac(device.al_mac)
        if address == "" then return nil end
        count = count + 1
        if device.state ~= "0" then
            local link = (device.backhaul_interface_type or ""):sub(1, 32)
            local lower = link:lower()
            if lower == "eth" or lower == "ethernet" then link = "Ethernet" end
            snapshot[address] = {parent = mac(device.parent), link = link}
        end
    end
    if (expected and count ~= expected) or (#results > 0 and count == 0) then return nil end
    return snapshot
end

function M.record(previous, current, events, now)
    local changes = {}
    for address, device in pairs(current) do
        local before = previous[address]
        if not before then
            changes[#changes + 1] = {kind = "joined", address = address, after = device}
        elseif before.parent ~= device.parent or before.link ~= device.link then
            changes[#changes + 1] = {kind = "changed", address = address, before = before, after = device}
        end
    end
    for address, device in pairs(previous) do
        if not current[address] then
            changes[#changes + 1] = {kind = "left", address = address, before = device}
        end
    end
    if #changes == 0 then return events end

    table.sort(changes, function(a, b) return a.address < b.address end)
    for _, event in ipairs(changes) do event.time = now end
    for index = 1, math.min(#events, limit - #changes) do
        changes[#changes + 1] = events[index]
    end
    while #changes > limit do changes[#changes] = nil end
    return changes
end

function M.write(events)
    local temporary = path .. ".new"
    local contents = require("dkjson").encode(events)
    local file = io.open(temporary, "w")
    if not file then return false end
    local written = file:write(contents)
    local closed = file:close()
    if written and closed and os.rename(temporary, path) then return true end
    os.remove(temporary)
    return false
end

return M
