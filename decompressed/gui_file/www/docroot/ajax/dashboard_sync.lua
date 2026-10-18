local json = require("dkjson")
local ngx = ngx
local function plain(value)
    if string.untaint then value = string.untaint(value) end
    return type(value) == "string" and value or nil
end
local function reply(status, data)
    ngx.status = status
    ngx.header["Content-Type"] = "application/json"
    ngx.header["Cache-Control"] = "no-store"
    ngx.say(json.encode(data))
    return ngx.exit(ngx.HTTP_OK)
end

local session = ngx.ctx.session
if not session or ngx.req.get_method() ~= "POST" then return reply(403, {}) end
-- The web framework validates CSRF while reading the form body, as it does
-- for the original endpoints. Never create a substitute session here.
local args = ngx.req.get_post_args()
local requested = args and plain(args.modules)
if not requested or #requested > 100 or not requested:match("^[a-z,]+$") then
    return reply(400, {})
end
local modules = {
    gateway = {uri = "/ajax/cpuload.lua"},
    wan = {uri = "/ajax/internet.lua"},
    xdsl = {uri = "/ajax/internet.lua", datatype = "xdsl"},
    devices = {uri = "/ajax/connected_device.lua"},
    ports = {uri = "/ajax/port_status.lua"},
    telephony = {uri = "/ajax/mmpbx_status.lua"},
}
local names, seen = {}, {}
for name in requested:gmatch("[^,]+") do
    if not modules[name] or seen[name] then return reply(400, {}) end
    names[#names + 1], seen[name] = name, true
end
if table.concat(names, ",") ~= requested then return reply(400, {}) end

local requests, authorized, result = {}, {}, {}
local body = ngx.req.get_body_data()
for _, name in ipairs(names) do
    local module = modules[name]
    if session:hasAccess(module.uri) then
        local query = {auto_update = "true", datatype = module.datatype}
        requests[#requests + 1] = {module.uri, {method = ngx.HTTP_POST, args = query,
            body = body, ctx = {session = session}}}
        authorized[#authorized + 1] = name
    else
        result[name] = {status = 403}
    end
end
if #requests > 0 then
    local responses = {ngx.location.capture_multi(requests)}
    for i, name in ipairs(authorized) do
        local response = responses[i]
        local data, position, err
        if response and response.status == 200 then
            data, position, err = json.decode(response.body)
        end
        if response and response.status == 200 and type(data) == "table" and not err and
            not response.body:sub(position):match("%S") then
            result[name] = {status = 200, data = data}
        else
            result[name] = {status = response and response.status or 502,
                responseText = response and response.body or "",
                error = response and response.header and response.header["error-msg"]}
        end
    end
end
return reply(200, {modules = result})
