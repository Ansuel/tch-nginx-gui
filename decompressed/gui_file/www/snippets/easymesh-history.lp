--pretranslated: do not change this file
local content = {}
-- a failing source must not make the whole section disappear
pcall(function()
    require("web.content_helper").addListContent(content, {
        events = "uci.fastweb.topology_events.@topology_events.back_up_events.",
    })
end)
local json = require("dkjson")
local escape = require("web.web").html_escape
local events = {}
for _, value in ipairs(content.events or {}) do
    if string.untaint then value = string.untaint(value) end
    if type(value) == "string" and #value <= 30000 then
        local event = json.decode(value)
        if type(event) == "table" and type(event.time) == "string" and type(event.topology_msg) == "string" then
            events[#events + 1] = {time = event.time, message = event.topology_msg}
        end
    end
end

if #events == 0 then
    local loaded, recorded = pcall(function() return require("topology_history").read() end)
    if not loaded or type(recorded) ~= "table" then recorded = {} end
    local labels = {
        joined = T"Connected",
        left = T"Disconnected",
        changed = T"Backhaul changed",
    }
    local function link(device)
        if type(device) ~= "table" then return "—" end
        local kind, parent = tostring(device.link or ""), tostring(device.parent or "")
        if parent == "" then return kind ~= "" and kind or "—" end
        if kind == "" then return parent end
        return kind .. " (" .. parent .. ")"
    end
    for index = #recorded, 1, -1 do
        local event = recorded[index]
        local label = type(event) == "table" and labels[event.kind]
        if label and type(event.time) == "number" and type(event.address) == "string" then
            local message = event.address .. " · " .. label
            if event.kind == "changed" then
                message = message .. " · " .. link(event.before) .. " → " .. link(event.after)
            end
            events[#events + 1] = {time = os.date("%Y-%m-%d %H:%M:%S", event.time), message = message}
        end
    end
end

ngx.print('<details><summary>', T"EasyMesh topology history", '</summary>')
if #events == 0 then
    ngx.print('<p class="muted">', T"No topology changes recorded.", '</p>')
else
    ngx.print('<table class="table table-striped">',
        '<thead><tr><th>', T"Time", '</th><th>', T"Event", '</th></tr></thead><tbody>')
    for _, event in ipairs(events) do
        ngx.print('<tr><td>', escape(event.time), '</td><td>', escape(event.message), '</td></tr>')
    end
    ngx.print('</tbody></table>')
end
ngx.print('</details>')
