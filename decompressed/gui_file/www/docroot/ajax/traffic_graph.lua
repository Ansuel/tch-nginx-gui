local json = require("dkjson")
local netrate = require("netrate")
local ngx = ngx
local function traffic(args)
    local data = {valid = false}
    local sample, reason, interface
    local previous_interface = args.interface
    if args.source == "wan" then
        sample, reason, interface = require("internethelper").sampleWanTraffic()
        if string.untaint and previous_interface and type(previous_interface) ~= "table" then
            previous_interface = string.untaint(previous_interface)
        end
    else
        sample, reason = netrate.sample(previous_interface)
    end
    if sample then
        local rate
        if interface and interface ~= previous_interface then
            reason = "interface_changed"
        else
            rate, reason = netrate.rate({rx = args.oldrx, tx = args.oldtx, time = args.oldtime}, sample)
        end
        data = {
            valid = true,
            interface = interface,
            old_rx_traffic = args.oldrx or "1000",
            old_tx_traffic = args.oldtx or "1000",
            rx_traffic = string.format("%.0f", sample.rx),
            tx_traffic = string.format("%.0f", sample.tx),
            sample_time = sample.time,
            rx_bytes_per_second = rate and rate.rx,
            tx_bytes_per_second = rate and rate.tx,
        }
    end
    data.reason = reason
    if args.source == "wan" and args.resources == "1" then
        local resources = require("resource_usage")
        local memory = resources.memory()
        data.cpu = resources.cpu()
        data.ram_percent = memory and (memory.used * 100 / memory.total)
    end
    return data
end

local data = {valid = false}
if ngx.req.get_method() == "POST" then
    local args = ngx.req.get_uri_args()
    if args.source == "wan" and args.resources == "history" then
        data = require("resource_usage").history(ngx.time(), tonumber(args.after))
    else
        data = traffic(args)
    end
end

ngx.header["Content-Type"] = "application/json"
ngx.header["Cache-Control"] = "no-store"
local buffer = {}
if json.encode(data, {indent = false, buffer = buffer}) then
    ngx.say(buffer)
else
    ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)
