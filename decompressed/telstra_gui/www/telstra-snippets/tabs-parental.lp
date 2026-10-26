--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  

gettext.textdomain('webui-telstra')

local ipairs, string = ipairs, string
local session = ngx.ctx.session
local items = {
  {"tod.lp", T"Time of Day Access Control"},
  {"urlfilter.lp", T"URL Filter"},
}

local html = {}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
   uri = uri .. "?" .. ngx.var.args
end

for _,v in ipairs(items) do
    local active = ""
    local vuri = "/" .. v[1]
    if session:hasAccess(vuri) then
       if uri == vuri then
           active = "active"
       end

       html[#html+1] = string.format('<li class="%s"><a href="%s" target="_self">%s</a></li>', active, v[1], v[2])
    end
end
ngx.print(html)

  ngx.print('\
\
</ul>\
'); 