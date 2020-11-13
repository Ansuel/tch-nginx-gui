--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")

-- Process POST query
local post_helper = require("web.post_helper")

mode_options = {{"bridge", T"No Connection"},{"dhcp", T"DHCP"},{"static", T"Static IP"},{"pppoe", T"PPPoE"}}

local mapParams = {
    wan_proto = "uci.network.interface.@wan.proto",
    wan_ifname = "uci.network.interface.@wan.ifname"
}

local mapValid = {
	wan_proto = post_helper.getValidateInEnumSelect(mode_options)
}

local content = post_helper.handleQuery(mapParams,mapValid)

if ngx.var.request_method == "POST" then
    content = ngx.req.get_post_args()
    if content["action"]=="SAVE" then
        if content["wan_proto"] ~= "bridge" then
            proxy.set("uci.network.interface.@wan.ifname" , "br-lan")
            proxy.apply()
        end
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
