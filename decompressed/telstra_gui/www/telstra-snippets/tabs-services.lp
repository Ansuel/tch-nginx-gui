--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  

gettext.textdomain('webui-telstra')

local ipairs, string = ipairs, string
local items = {
    {"dyndns.lp", T"Dynamic DNS"},
    {"portforwarding.lp", T"Port Forwarding"},
    {"remoteaccess.lp", T"Remote Web Access"},
    {"traffic.lp?iface=wl0", T"Traffic Monitor"},
}
local html = {}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?iface=wl0"
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