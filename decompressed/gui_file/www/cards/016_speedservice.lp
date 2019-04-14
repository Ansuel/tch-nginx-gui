--pretranslated: do not change this file
 
local istainted = string.istainted

-- Enable localization
gettext.textdomain('webui-speedservice')

local tinsert = table.insert
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local attributes = { light = { } ,span = { class = "span4" } }
local content_helper = require("web.content_helper")
local format, find, sub, match = string.format, string.find, string.sub, string.match
local session = ngx.ctx.session
local modalPath = nil
local status = nil
if session:hasAccess("/modals/speedservice-modal.lp") then
    modalPath = "/modals/speedservice-modal.lp"
end
local spdsvc_data = {
    enabled = "uci.bcm_spdsvc.global.enabled"
}
content_helper.getExactContent(spdsvc_data)
if spdsvc_data.enabled == '1' then
        local Diagnostics = {
                state = "rpc.X_000E50_SpeedService.DiagnosticsState"
        }
        content_helper.getExactContent(Diagnostics)
        if Diagnostics.state ~= "Requested" then
                status = "light green"
        else
                status = "light red"
        end  ngx.print('\
        <div class="span3">\
                <div class="smallcard">\
                        ');  ngx.print(ui_helper.createCardHeader(T"Speed Test", modalPath, nil, nil) ); ngx.print('\
                         <div class="content">\
                                <div class="');  ngx.print(status); ngx.print('"></div>\
                                <p><strong> ');  ngx.print( Diagnostics.state); ngx.print('</strong></p>\
                         </div>\
                </div>\
        </div>\
\
');  end  ngx.print('\
'); 