--pretranslated: do not change this file
 ngx.print('<div class="container" style="width:830px">\
    <div class="row">\
        <div class="menubar">\
\
');  
    gettext.textdomain('webui-telstra')

    local format = string.format
    local untaint_mt = require("web.taint").untaint_mt
    local setmetatable = setmetatable
    local items = {
        {"/telstra-helpfiles/help_home.lp", "home", T"HOME",
         setmetatable({ ["/telstra-helpfiles/help_home.lp"] = true }, untaint_mt) },
        {"/telstra-helpfiles/help_broadband.lp", "broadband", T"BROADBAND",
         setmetatable({ ["/telstra-helpfiles/help_broadband.lp"] = true }, untaint_mt) },
        {"/telstra-helpfiles/help_wifi.lp", "wifi", T"WI-FI",
         setmetatable({ ["/telstra-helpfiles/help_wifi.lp"] = true, ["/telstra-helpfiles/help_wifiguest.lp"] = true }, untaint_mt) },
        {"/telstra-helpfiles/help_contentsharing.lp", "contentsharing", T"CONTENT SHARING",
         setmetatable({ ["/telstra-helpfiles/help_contentsharing.lp"] = true }, untaint_mt) },
        {"/telstra-helpfiles/help_tod.lp", "tod", T"PARENTAL CONTROL",
         setmetatable({ ["/telstra-helpfiles/help_tod.lp"] = true }, untaint_mt) },
        {"/telstra-helpfiles/help_services.lp", "dyndns", T"SERVICES",
         setmetatable({ ["/telstra-helpfiles/help_services.lp"] = true, ["/telstra-helpfiles/help_dyndns.lp"] = true, ["/telstra-helpfiles/help_portforwarding.lp"] = true, ["/telstra-helpfiles/help_remoteaccess.lp"] = true, ["/telstra-helpfiles/help_traffic.lp"] = true }, untaint_mt) },
        {"/telstra-helpfiles/help_usersetting.lp", "admin", T"USER SETTINGS",
         setmetatable({ ["/telstra-helpfiles/help_usersetting.lp"] = true }, untaint_mt) },
    }
    local html = {}
    local uri = ngx.var.uri

    for _,v in ipairs(items) do
        local selected = ""
        if v[4][uri] then
            selected = "selected"
        end

        html[#html+1] = format('<div class="menu-item"><a href="%s" target="_self"><div class="menu-icon %s %s"></div><div class="menu-text">%s</div></a></div>', v[1], v[2], selected, v[3])
    end
    ngx.print(html)
  ngx.print('\
        </div>\
    </div>\
</div>\
'); 