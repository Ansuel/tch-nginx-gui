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

if session:hasAccess(modalPath) then
  local modal_link = format("class=\"modal-link\" data-toggle=\"modal\" data-remote=\"%s\" data-id=\"nat-alg-helper-modal\"",modalPath)
  local helper_uci_path = "uci.firewall.helper."
  local helper_uci_content = proxy.get(helper_uci_path)
  helper_uci_content = content_helper.convertResultToObject(helper_uci_path,helper_uci_content)
  local enabled_count = 0
  local disabled_count = 0
  for _, v in ipairs (helper_uci_content) do
      if v.intf ~= "loopback" then
          if v.enable == "0" then
              disabled_count = disabled_count + 1
          else
              enabled_count = enabled_count + 1
          end
      end
  end
    ngx.print('\
  <div class="span3">\
      <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
          ');  ngx.print( ui_helper.createCardHeader(T"NAT Helpers", modalPath) ); ngx.print('\
          <div class="content card_bg" data-bg-text="&#xf0eb;">\
          <div class="divtable">\
              ');  if enabled_count ~= 0 then  ngx.print('\
                <span class="simple-desc">\
               <i " class="fas fa-info-circle" aria-hidden="true" href="#">&nbsp</i>\
                ');  
                ngx.print(format( N('<strong %1$s>%2$d Enabled Helper</strong>',
                                    '<strong %1$s>%2$d Enabled Helpers</strong>', enabled_count),
                                    modal_link, enabled_count))
                  ngx.print('\
                </span>\
                ');  
              end
              if disabled_count ~= 0 then  ngx.print('\
                <span class="simple-desc">\
               <i " class="fas fa-info-circle" aria-hidden="true" href="#">&nbsp</i>\
                ');  
                ngx.print(format( N('<strong %1$s>%2$d Disabled Helper</strong>',
                                    '<strong %1$s>%2$d Disabled Helpers</strong>', disabled_count),
                                    modal_link, disabled_count))
                  ngx.print('\
                </span>\
              ');  end  ngx.print('\
           </div>\
           </div>\
      </div>\
  </div>\
');  
end
  ngx.print('\
'); 