--pretranslated: do not change this file
 ngx.print('<div class="container">\
    <div class="row">\
        <div class="menubar">\
\
');  
    gettext.textdomain('webui-telstra')

    local format = string.format
    local untaint_mt = require("web.taint").untaint_mt
    local setmetatable = setmetatable
    local items = {
        {"/telstra-gui.lp", "home", T"HOME",
         setmetatable({ ["/telstra-gui.lp"] = true }, untaint_mt) },
        {"/telstra-modals/broadband.lp", "broadband", T"BROADBAND",
         setmetatable({ ["/telstra-modals/broadband.lp"] = true }, untaint_mt) },
        {"/telstra-modals/wifi.lp?radio=2.4", "wifi", T"WI-FI",
         setmetatable({ ["/telstra-modals/wifi.lp"] = true, ["/telstra-modals/wifiguest.lp"] = true }, untaint_mt) },
        {"/telstra-modals/contentsharing.lp", "contentsharing", T"CONTENT SHARING",
         setmetatable({ ["/telstra-modals/contentsharing.lp"] = true }, untaint_mt) },
        {"/telstra-modals/tod.lp", "tod", T"PARENTAL CONTROL",
         setmetatable({ ["/telstra-modals/tod.lp"] = true }, untaint_mt) },
        {"/telstra-modals/dyndns.lp", "dyndns", T"SERVICES",
         setmetatable({ ["/telstra-modals/dyndns.lp"] = true, ["/telstra-modals/portforwarding.lp"] = true, ["/telstra-modals/remoteaccess.lp"] = true, ["/telstra-modals/traffic.lp"] = true }, untaint_mt) },
        {"/telstra-modals/user.lp", "admin", T"USER SETTINGS",
         setmetatable({ ["/telstra-modals/user.lp"] = true }, untaint_mt)},
        {"/cards.lp", "gateway", T"ADVANCED", { }}
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