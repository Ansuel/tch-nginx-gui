--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local ngx = ngx
local session = ngx.ctx.session
local modalPath = "/modals/nat-alg-helper-modal.lp"

local hasAccess = session:hasAccess(modalPath)
local modal_link = hasAccess and format("class=\"modal-link\" data-toggle=\"modal\" data-remote=\"%s\" data-id=\"nat-alg-helper-modal\"", modalPath) or ""
local cardModalPath = hasAccess and modalPath or nil

local test_modern = proxy.getPN("uci.firewall_helpers.helper.", true)
local is_modern = (test_modern and #test_modern > 0)
local helper_uci_path = is_modern and "uci.firewall_helpers.helper." or "uci.firewall.helper."
local helper_uci_content = proxy.get(helper_uci_path)
helper_uci_content = content_helper.convertResultToObject(helper_uci_path, helper_uci_content)

local enabled_count = 0
local disabled_count = 0
local active_helpers = {}

if helper_uci_content and #helper_uci_content > 0 then
    for _, v in ipairs(helper_uci_content) do
        if is_modern or v.intf ~= "loopback" then
            if v.enable == "0" then
                disabled_count = disabled_count + 1
            else
                enabled_count = enabled_count + 1
                local hname = v.name or v.helper
                if hname and hname ~= "" then
                    active_helpers[#active_helpers + 1] = hname:lower()
                end
            end
        end
    end
else
    -- Fallback for firmwares (e.g. DGA4132/FW2.3.4) where helpers are stored as zone options in firewall config
    local pcall = pcall
    pcall(function()
        local uci = require("uci").cursor()
        local seen = {}
        uci:foreach("firewall", "zone", function(z)
            if z['.name'] ~= "loopback" and z.helper then
                local hlist = type(z.helper) == "table" and z.helper or { z.helper }
                for _, h in ipairs(hlist) do
                    if not seen[h] then
                        seen[h] = true
                        active_helpers[#active_helpers + 1] = h:lower()
                    end
                end
            end
        end)
        uci:unload("firewall")
    end)
    table.sort(active_helpers)
    enabled_count = #active_helpers
end

  ngx.print('\
<div class="span3">\
    <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
        ');  ngx.print( ui_helper.createCardHeader(T"NAT Helpers", cardModalPath) ); ngx.print('\
        <div class="content card_bg" data-bg-text="&#xf0eb;">\
        <div class="divtable">\
            ');  if enabled_count ~= 0 then  ngx.print('\
              <span class="simple-desc">\
             <i class="fas fa-info-circle" aria-hidden="true">&nbsp;</i>\
              ');  
              ngx.print(format( N('<strong %1$s>%2$d Enabled Helper</strong>',
                                  '<strong %1$s>%2$d Enabled Helpers</strong>', enabled_count),
                                  modal_link, enabled_count))
                ngx.print('\
              </span>\
              ');  
              if #active_helpers > 0 then
                  ngx.print('<p class="subinfos">' .. table.concat(active_helpers, ", ") .. '</p>')
              end
            end
            if disabled_count ~= 0 then  ngx.print('\
              <span class="simple-desc">\
             <i class="fas fa-info-circle" aria-hidden="true">&nbsp;</i>\
              ');  
              ngx.print(format( N('<strong %1$s>%2$d Disabled Helper</strong>',
                                  '<strong %1$s>%2$d Disabled Helpers</strong>', disabled_count),
                                  modal_link, disabled_count))
                ngx.print('\
              </span>\
            ');  end
            if enabled_count == 0 and disabled_count == 0 then  ngx.print('\
              <span class="simple-desc">\
             <i class="fas fa-info-circle" aria-hidden="true">&nbsp;</i>\
              ');  
              ngx.print(format('<strong %s>%s</strong>', modal_link, T"No NAT Helpers found"))
                ngx.print('\
              </span>\
            ');  end  ngx.print('\
         </div>\
         </div>\
    </div>\
</div>\
'); 