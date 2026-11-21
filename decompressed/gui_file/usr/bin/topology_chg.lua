#!/usr/bin/env lua

local stock = "/rom/usr/bin/topology_chg.lua"
local original = io.open(stock, "r")
if original then
    original:close()
    return dofile(stock)
end

local history = require("topology_history")
local proxy = require("datamodel")
local uloop = require("uloop")

local events = history.read()
local previous
local devicePath = "rpc.multiap.device."
local parameters = {"al_mac", "parent", "backhaul_interface_type", "state"}

local function sample()
    local controller = proxy.get("uci.multiap.controller.enabled")
    local enabled = controller and controller[1] and controller[1].value
    if enabled == "0" then previous = nil end
    if enabled ~= "1" then return 60000 end

    local devices = proxy.getPN(devicePath, true)
    if not devices then return end
    local paths = {}
    for _, device in ipairs(devices) do
        if (device.path or ""):match("^rpc%.multiap%.device%.[^%.]+%.$") then
            for _, parameter in ipairs(parameters) do paths[#paths + 1] = device.path .. parameter end
        end
    end
    local results = #paths == 0 and {} or proxy.get(paths, false)
    if not results then return end
    local current = history.snapshot(results, #paths / #parameters)
    if not current then return end
    if not events then
        events = {}
        if not history.write(events) then events = nil; return end
    elseif previous then
        local updated = history.record(previous, current, events, os.time())
        if updated ~= events and not history.write(updated) then return end
        events = updated
    end
    previous = current
end

uloop.init()
local timer
timer = uloop.timer(function()
    -- Transformer can be temporarily unavailable during a firmware reload.
    local ok, delay = pcall(sample)
    timer:set(ok and delay or 15000)
end)
timer:set(1000)
uloop.run()
