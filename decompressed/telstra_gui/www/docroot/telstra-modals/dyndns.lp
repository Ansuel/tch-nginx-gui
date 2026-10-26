--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/telstra-snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
  ngx.print('\
\
');  
-- Localization
gettext.textdomain('webui-telstra')

local table, ipairs, require, ngx, io = table, ipairs, require, ngx, io
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")

local ddns_supported_services = {}

local function generate_ddns_supported_services()
    -- open the supported services file that come with the ddns package
    local f = io.open("/etc/ddns/services", "r")
    if f then
        for line in f:lines() do
            --a service in this file is  indicated as a url between quotes, we want a list with urls and name of service in capitals
            local service = line:match('^%b""')
            if service then
                service = service:gsub('"','')
                local serviceline = { service , service:upper():match('[%a%w]*%.'):gsub('%.','') }
                ddns_supported_services[#ddns_supported_services + 1] = serviceline
            end
        end
        f:close()
    end
end

generate_ddns_supported_services()

-- DMZ / DDNS / UPnP switches Only one handleQuery in a page
local qry_params = {
    ddns_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
    ddns_service_name = "uci.ddns.service.@myddns_ipv4.service_name",
    ddns_domain = "uci.ddns.service.@myddns_ipv4.domain",
    ddns_username = "uci.ddns.service.@myddns_ipv4.username",
    ddns_password = "uci.ddns.service.@myddns_ipv4.password",
}

-- Shortcuts to validation helpers to make lines shorter
local gVICSPIL = post_helper.getValidationIfCheckboxSwitchPropInList
local gVIES = post_helper.getValidateInEnumSelect
local gVCS = post_helper.getValidateCheckboxSwitch()
local vNES = post_helper.validateNonEmptyString
local gVP = post_helper.getValidationPassword

local qry_valid = {
    ddns_enabled = gVCS,
    ddns_service_name = gVICSPIL(gVIES(ddns_supported_services), "ddns_enabled", {"1"}),
    ddns_username = gVICSPIL(vNES, "ddns_enabled", {"1"}),
    ddns_password = gVP(gVICSPIL(vNES, "ddns_enabled", {"1"})),
    ddns_domain = gVICSPIL(vNES, "ddns_enabled", {"1"}),
}

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)
  ngx.print('\
\
<div class="container">\
\
');  lp.include("tabs-services.lp")   ngx.print('\
\
<div class="row">\
<div class="span11">\
\
<form class="form-horizontal" method="post" action="dyndns.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
<fieldset>\
');  
ngx.print(
    ui_helper.createCheckboxSwitch(T"Enabled", "ddns_enabled", qry_data["ddns_enabled"], nil, qry_helpmsg["ddns_enabled"]),
    ui_helper.createInputSelect(T"Service Name", "ddns_service_name", ddns_supported_services, qry_data["ddns_service_name"], nil, qry_helpmsg["ddns_service_name"]),
    ui_helper.createInputText(T"Domain", "ddns_domain", qry_data["ddns_domain"], nil, qry_helpmsg["ddns_domain"]),
    ui_helper.createInputText(T"User Name", "ddns_username", qry_data["ddns_username"], nil, qry_helpmsg["ddns_username"]),
    ui_helper.createInputPassword(T"Password", "ddns_password", qry_data["ddns_password"], nil, qry_helpmsg["ddns_password"])
)
  ngx.print('\
</fieldset>\
</form>\
\
');  
lp.include("save.lp")
  ngx.print('\
\
</div>\
</div>\
</div>\
\
');  
lp.include("footer.lp")
  ngx.print('\
'); 