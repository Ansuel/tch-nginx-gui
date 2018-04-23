<%
-- Enable localization
gettext.textdomain('webui-wizard')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local wizard_helper = require("wizard")
local post_helper = require("web.post_helper")
local gVSLIR = post_helper.getValidateStringLengthInRange
local vB = post_helper.validateBoolean
local format = string.format

local mapParams = {
  ap_enabled = "uci.wireless.wifi-iface.@wl0.state",
  ssid = "uci.wireless.wifi-iface.@wl0.ssid",
}

local mapValid = {
  ap_enabled = vB,
  ssid = gVSLIR(1,32),
}

local content, helpmsg = wizard_helper.handleQuery(mapParams, mapValid)

local bool2on = {
  ["1"] = "On",
  ["0"] = "Off"
}

local bool2enable = {
  ["1"] = "Enabled",
  ["0"] = "Disabled"
}
%>
<div class='wizard-card'>
    <fieldset>
      <%="<legend></legend>"%>
      <%= "<h4>" .. T"WiFi Setup (2.4GHz)" .. "</h4>"%>
      <%
        local html = {}
        local info_attr = {
            alert = {
                class = "alert-info"
            },
         }
        html[#html+1] = ui_helper.createAlertBlock(T"Your modem already has a unique WiFi network set up by default. You can change the broadcast name here if desired, or turn off WiFi completely. You can also hide your WiFi network name from other devices by turning off SSID broadcast.", info_attr)
        html[#html+1] = ui_helper.createMessages(message_helper.popMessages())
        html[#html+1] = ui_helper.createSwitch(T"Wireless 2.4GHz (WiFi):", "ap_enabled", content["ap_enabled"], nil, helpmsg["ap_enabled"])
        html[#html+1] = ui_helper.createInputText(T"SSID Broadcast Name (Max 32 characters):", "ssid", content["ssid"], nil, helpmsg["ssid"])
        ngx.print(html)
      %>
    </fieldset>
</div>
<div class='wizard-confirm'>
    <fieldset>
      <%
        local html = {}
        html[#html+1] = ui_helper.createLabel(T"Wireless 2.4GHz (WiFi): ", bool2on[format("%s",content["ap_enabled"])])
        html[#html+1] = ui_helper.createLabel(T"SSID Broadcast Name: ", content["ssid"])
        ngx.print(html)
      %>
    </fieldset>
</div>
