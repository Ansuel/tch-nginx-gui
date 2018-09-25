--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  

gettext.textdomain('webui-telstra')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")

local ipairs, string = ipairs, string
local items = {
    {"wifi.lp?radio=2.4", T"2.4GHz"},
}
local dev_5g, guest1, guest2,guest1_5g, guest2_5g

--check whether the 5G exists. 
dev_5g=proxy.get("uci.wireless.wifi-device.@radio_5G.")

if dev_5g ~= nil then
    table.insert(items,{ "wifi.lp?radio=5", T"5GHz"})
end

--check whether the guest1 exists. 
guest1=proxy.get("uci.wireless.wifi-iface.@wl0_1.")
if guest1 ~= nil then
    table.insert(items, {"wifiguest.lp?guest=2g_1", T"Guest1"})
end

--check whether the 5G guest1 exists. 
guest1_5g=proxy.get("uci.wireless.wifi-iface.@wl1_1.")
if guest1_5g ~= nil then
    table.insert(items, {"wifiguest.lp?guest=5g_1", T"Guest1_5G"})
end

local html = {}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

for _,v in ipairs(items) do
    local active = ""
    if uri == ("/" .. v[1]) then
        active = "active"
    end

    html[#html+1] = string.format('<li class="%s"><a href="%s" target="_self">%s</a></li>', active, v[1], v[2])
end
ngx.print(html)

  ngx.print('\
\
</ul>\
'); 