--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local bridge = require("bridgehelper")

local mode_options = {{"bridge", T"No Connection"},{"dhcp", T"DHCP"},{"static", T"Static IP"},{"pppoe", T"PPPoE"}}
local content = {wan_proto = bridge.get("uci.network.interface.@wan.proto")}

if ngx.var.request_method == "POST" then
    local posted = ngx.req.get_post_args()
    if posted.action == "SAVE" and posted.wan_proto ~= nil then
        if post_helper.getValidateInEnumSelect(mode_options)(posted.wan_proto) then
            local ok, err = bridge.setLocalProtocol(posted.wan_proto)
            if ok then ok, err = proxy.apply() end
            if not ok then message_helper.pushMessage(err or T"Error while applying changes", "error") end
        else
            message_helper.pushMessage(T"Invalid input", "error")
        end
        content.wan_proto = bridge.get("uci.network.interface.@wan.proto")
    end
end

  ngx.print('\
\
<fieldset>\
');
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"Bridged connection" ); ngx.print('</legend>\
\
');
    local html = {}
    local bridge_info = {
        alert = {
            class = "alert-info"
        }
    }

    html[#html + 1] = ui_helper.createAlertBlock(T"Select if you want to establish a connection on the bridged interface", bridge_info)
    html[#html + 1] = ui_helper.createAlertBlock(T"The selected WAN interface is kept fixed while bridge mode is active. WanSensing is restored to its previous state when you switch to a routed mode.", bridge_info)
    local mode_attributes = {
        radio = {
            class = "inline"
        }
    }
    html[#html+1] = ui_helper.createInputRadio(T"Mode", "wan_proto", mode_options, content["wan_proto"], mode_attributes)

    ngx.print(html)
  ngx.print('\
\
</fieldset>');
