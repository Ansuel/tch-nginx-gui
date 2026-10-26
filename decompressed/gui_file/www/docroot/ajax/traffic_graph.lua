local json = require("dkjson")
local netrate = require("netrate")
local ngx = ngx
local data = {valid = false}

if ngx.req.get_method() == "POST" then
    local args = ngx.req.get_uri_args()
    local sample, reason = netrate.sample(args.interface)
    if sample then
        local rate
        rate, reason = netrate.rate({rx = args.oldrx, tx = args.oldtx, time = args.oldtime}, sample)
        data = {
            valid = true,
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
