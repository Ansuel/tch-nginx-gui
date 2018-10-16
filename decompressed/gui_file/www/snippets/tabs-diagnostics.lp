--pretranslated: do not change this file
ngx.print('<ul class="nav nav-tabs">\
\
');
gettext.textdomain('webui-core')
local content_helper = require("web.content_helper")
local ipairs, string, table = ipairs, string, table

local lfs = require("lfs")
local items = {
    {"diagnostics-xdsl-modal.lp", T"xDSL"},
    {"diagnostics-xdsl-graphics-modal.lp", T"xDSL Graphics"},
    {"diagnostics-ping-modal.lp", T"Ping & Traceroute"},
    {"diagnostics-connection-modal.lp", T"Connection"},
    {"diagnostics-network-modal.lp", T"Network"},
    {"diagnostics-igmpproxy-modal.lp", T"Igmpproxy"},
    {"port-mirror-modal.lp", T"Port Mirror"},
    {"diagnostics-tcpdump-modal.lp", T"Tcpdump"},
}
local xdsl_exist = false

if lfs.attributes("/etc/config/xdsl", "mode") == "file" then
    local dsl_data = {
        dsl_status = "sys.class.xdsl.@line0.Enable",
    }
    content_helper.getExactContent(dsl_data)
    if ( dsl_data["dsl_status"] == "1") then
        xdsl_exist = true
    end
end

local tabs = {}
local session = ngx.ctx.session

for _,v in pairs(items) do
    if session:hasAccess("/modals/" .. v[1])  and (v[1] ~= "diagnostics-xdsl-modal.lp"  or  xdsl_exist )
            and	(v[1] ~= "diagnostics-xdsl-graphics-modal.lp"  or  xdsl_exist ) then
        tabs[#tabs+1] = v
    end
end

local html = {}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

for _,v in ipairs(tabs) do
    local active = ""
    if uri == ("/modals/" .. v[1]) then
        active = "active"
    end

    html[#html+1] = string.format('<li class="%s"><a id ="%s" href="#" data-remote="/modals/%s">%s</a></li>', active, v[2], v[1], v[2])
end
ngx.print(html)

ngx.print('</ul>');