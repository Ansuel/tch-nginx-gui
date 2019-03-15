
<%
-- Enable localization
gettext.textdomain('webui-wizard')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local wizard_helper = require("wizard")
local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local gVIES = post_helper.getValidateInEnumSelect
local gVIPIL = post_helper.getValidationIfPropInList
local vPSK = post_helper.validatePSK
local format = string.format

local path_ap_data = "uci.wireless.wifi-ap.@ap1."
local path_ap_security = "rpc.wireless.ap.@ap1.security."
local supported_modes_data  = proxy.get(path_ap_security .. "supported_modes")
local supported_modes = format("%s", supported_modes_data and supported_modes_data[1] and supported_modes_data[1].value or "")
local secmodes = {}
local secmodes_matched = {
  ["none"] = T"None",
  ["wpa2-psk"] = T"WPA2-PSK",
  ["wpa-wpa2-psk"] =  T"WPA+WPA2 PSK",
}

for mode in supported_modes:gmatch("[^%s]+") do
  if secmodes_matched[mode] then
    secmodes[#secmodes+1] = { mode, secmodes_matched[mode] }
  end
end

local mapParams = {
  security_5G = path_ap_data .. "security_mode",
  wpa_psk_5G = path_ap_data .. "wpa_psk_key",
}

local mapValid = {
  security_5G = gVIES(secmodes),
  wpa_psk_5G = gVIPIL(vPSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"}),
}

local content, helpmsg = wizard_helper.handleQuery(mapParams, mapValid)
%>
<div class='wizard-card'>
    <fieldset>
      <%="<legend>" .. T"Step 6 of 8" .. "</legend>"%>
      <%='<h4>' .. T"Router Security" .. '</h4>'%>
      <%
        local html = {}
        local info_attr = {
            alert = {
                class = "alert-info"
            },
         }
        html[#html+1] = ui_helper.createAlertBlock(T"A <b>WiFi 5GHz</b> Security Key is already set-up with your Router, however you can change that key here if desired. You can also change the security type below. To connect to the Router via WiFi you will need to enter the Security Key into your device.", info_attr)
        html[#html+1] = ui_helper.createMessages(message_helper.popMessages())
        -- Select the security mode to use
        local secattributes = {
            select = {
                class = "monitor-changes"
            }
        }
        html[#html+1] = ui_helper.createInputSelect(T"Security Key Type:", "security_5G", secmodes, content["security_5G"], secattributes)
        local pskclass = {
            group = {
                class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk",
            },
        }
        html[#html+1] = ui_helper.createInputText(T"Security Key(Minimum of 8 characters):", "wpa_psk_5G", content["wpa_psk_5G"], pskclass, helpmsg["wpa_psk_5G"])
        ngx.print(html)
      %>
    </fieldset>
</div>
<div class='wizard-confirm'>
    <fieldset>
      <%
        local html = {}
        html[#html+1] = ui_helper.createLabel(T"Security Key Type: ", secmodes_matched[format("%s",content["security_5G"])])
        html[#html+1] = ui_helper.createLabel(T"Security Key: ", content["wpa_psk_5G"])
        ngx.print(html)
      %>
    </fieldset>
</div>
