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
local istainted = string.istainted
local untaint_mt = require("web.taint").untaint_mt
local setmetatable, format = setmetatable, string.format

-- Localization
gettext.textdomain('webui-telstra')

-- Process POST query

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local pairs, strmatch, format = pairs, string.match, string.format
local floor = math.floor
local bandsteer_helper = require("bandsteer_helper")
local isBaseIface = bandsteer_helper.isBaseIface
local disableBandSteer = bandsteer_helper.disableBandSteer

local getargs = ngx.req.get_uri_args()
local radio, wl, ap, bspeerwl, bspeerap

if getargs.guest == "2g_1" then
    radio = "radio_2G"
    wl = "wl0_1"
    ap = "ap2"
elseif getargs.guest == "5g_1" then
    radio = "radio_5G"
    wl = "wl1_1"
    ap = "ap3"
end

--To get the bandsteer peer nodes
local piface = "uci.wireless.wifi-iface."
local awls = content_helper.convertResultToObject(piface .. "@.", proxy.get(piface))

local tmpstr = strmatch(wl, ".*(_%d+)")
for i, v in ipairs(awls) do
    if v.paramindex ~= wl then
        if not tmpstr then
            if not strmatch(v.paramindex, ".*(_%d+)") then
                bspeerwl = v.paramindex
            end
        else
            if tmpstr == strmatch(v.paramindex, ".*(_%d+)") then
                bspeerwl = v.paramindex
            end
        end
    end
end

local pap = "uci.wireless.wifi-ap."
if bspeerwl then
    local aap = content_helper.convertResultToObject(pap .. "@.", proxy.get(pap))
    for i, v in ipairs(aap) do
        if bspeerwl and v.iface == bspeerwl then
            bspeerap = v.paramindex
        end
    end
end

local radiop = "uci.wireless.wifi-device.@" .. radio .. "."
local wlp = "uci.wireless.wifi-iface.@" .. wl .. "."
local app = "uci.wireless.wifi-ap.@" .. ap .. "."

-- UCI parameters list
local mapParams = {
    --interface_enabled = wlp .. "state",
    --standard = radio .. "standard",
    --channelconf= radiop .. "channel",
    channelwidth = radiop .. "channelwidth",
    ap_enabled = app .. "state",
    ssid = wlp .. "ssid",
    security = app .. "security_mode",
    wep_key = app .. "wep_key",
    wpa_psk = app .. "wpa_psk_key",
}

if bspeerwl and bspeerap then
    local bandsteerParams = {
        bsid = pap .. "@" .. ap .. ".bandsteer_id",
        bspeerid = pap .. "@" .. bspeerap .. ".bandsteer_id",
    }

    if isBaseIface(wl) then
      local bandsteerAddParams = {
            bspifacessid = piface .. "@" .. bspeerwl .. ".ssid",
            bspeer_security_mode = pap .. "@" .. bspeerap .. ".security_mode",
            bspeer_wpa_psk_key = pap .. "@" .. bspeerap .. ".wpa_psk_key",
        }
        for k,v in pairs(bandsteerAddParams) do
            bandsteerParams[k] = v
        end
    end

    for k,v in pairs(bandsteerParams) do
        mapParams[k] = v
    end
end
local secmodes
if getargs.guest == "2g_1" or getargs.guest == "2g_2" then
    secmodes = {
        { "none", T"None"},
        { "wep", T"WEP"},
        { "wpa2-psk", T"WPA2 PSK"},
        { "wpa-wpa2-psk", T"WPA+WPA2 PSK"},
    }
else
    -- do NOT show wep in 5G wifi
    secmodes = {
        { "none", T"None"},
        { "wpa2-psk", T"WPA2 PSK"},
        { "wpa-wpa2-psk", T"WPA+WPA2 PSK"},
    }
end

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local gVSL = post_helper.getValidateStringLength
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local gVCS = post_helper.getValidateCheckboxSwitch()
local vPSK = post_helper.validatePSK
local gVSLIR = post_helper.getValidateStringLengthInRange
local vWEP = post_helper.validateWEP

local function getValidateBandSteerPeerFields(value, object, key)
    if "table" == type(object.band_steer_supported) then
        if "" ~= object.bsid and "off" ~= object.bsid then
            if object.security == "wep" then
                return nil, T"The Band Steering can not be supported under WEP security mode."
            end

            if isBaseIface(wl) then
                if object.bspeer_security_mode then
                    object.bspeer_security_mode = object.security
                    object.bspeer_wpa_psk_key = object.wpa_psk
                    object.bspifacessid = object.ssid
                end
            end
            return true
        else
            local bsid = bandsteer_helper.getBandSteerId(wl)
            --to check wether the bs obj exist or not
            local bandsteerobj = proxy.get("uci.wireless.wifi-bandsteer.@" .. bsid .. ".")
            if not bandsteerobj then
                return nil, T"Please configure wifi-bandsteer " .. bsid .. " first!"
            else
                if object.security == "wep" then
                    return nil, T"The Band Steering can not be supported under WEP security mode."
                end

                if isBaseIface(wl) then
                    object.bsid = bsid
                    object.bspeerid = bsid

                    if object.bspeer_security_mode then
                        object.bspeer_security_mode = object.security
                        object.bspeer_wpa_psk_key = object.wpa_psk
                        object.bspifacessid = object.ssid
                    end
                end
            end
        end
    elseif object.band_steer_supported then --to disable bandsteer
        return disableBandSteer(object)
    end

    return true
end

local mapValid = {
    --interface_enabled = vB,
    ap_enabled = gVCS,
    security = gVIES(secmodes),
    ssid = gVSLIR(1,32),
    wep_key = gVIPIL(vWEP,"security", {"wep"}),
    wpa_psk = gVIPIL(vPSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"}),
    bsid = getValidateBandSteerPeerFields,
    channelwidth = function(val, object)
      return true
    end,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End of parameters saving / loading

local band_steer_supported = 0
local band_steer_enabled = "0"

if bspeerwl and bspeerap then
    local content_band_steer = {
        band_steer_id = "uci.wireless.wifi-ap.@" .. ap .. ".bandsteer_id",
    }
    content_helper.getExactContent(content_band_steer)

    --To get the content_band_steer value
    if "" ~= content_band_steer.band_steer_id then
        band_steer_supported = 1
        if "off" ~= content_band_steer.band_steer_id then
            band_steer_enabled = "1"
        end
    end
end
-- Radio data
local radioData = {}
local rpath = "rpc.wireless.radio.@" .. radio .. "."
local rdata = proxy.get(rpath)
if rdata ~= nil then
    for i, v in ipairs(rdata) do
        if v.path ~= rpath then
            rdata[i] = nil
        end
    end
end
post_helper.mergeTables(radioData, rdata);

for k,v in pairs(radioData) do
    -- Not replace the value that already exists
    if not content[k] then
        content[k] = v
    end
end

-- If phy_rate is nil we need to set it ot 0 for division
content["phy_rate"] = content["phy_rate"] or 0

-- Mac Address
content["macaddress"] = proxy.get("sys.class.net.@" .. wl .. ".address")[1].value

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

  ngx.print('\
\
<div class="container toplevel">\
    ');  lp.include("tabs-wifi.lp")   ngx.print('\
    <div class="row">\
        <div class="span11">\
\
<form class="form-horizontal" method="post" action="');  ngx.print( uri ); ngx.print('">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
');  
local content_radio = {
  state = radiop .. "state",
}
content_helper.getExactContent(content_radio)
  ngx.print('\
\
<fieldset>\
<legend>');  ngx.print( T"Wi-Fi Radio" ); ngx.print('</legend>\
\
');  
html = {}
-- Switch that shows if the Wifi interface is enabled or not
html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enabled", "interface_enabled", content_radio["state"], { input = { disabled = "disabled" }})
ngx.print(html)
  ngx.print('\
</fieldset>\
\
<fieldset>\
<legend>');  ngx.print( T"Wi-Fi Channel" ); ngx.print('</legend>\
\
');  
local html = {}

-- Label that shows the MAC address of the Wifi interface
html[#html + 1] = ui_helper.createLabel(T"MAC Address", content["macaddress"])

--html[#html + 1] = ui_helper.createLabel(T"Standard", content["standard"])

-- Current speed of the Wifi interface
html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps")

html[#html + 1] = ui_helper.createLabel(T"Current Channel", content["channel"])

html[#html + 1] = ui_helper.createLabel(T"Channel Width", content["channelwidth"])

ngx.print(html)
  ngx.print('\
</fieldset>\
\
<fieldset>\
<legend>');  ngx.print( T"Wi-Fi Network" ); ngx.print('</legend>\
\
');  
html = {}

--when radio is off, AP shall be off and button shall be greyed out.
local default_ap_enabled = "0"
local ap_enable_class = {
    input = {
        class = "monitor-changes",
        disabled = "disabled"
    },
}


--when radio is on, ap enabled button is active
if content_radio["state"] == "1" then
  default_ap_enabled = content["ap_enabled"]
  ap_enable_class["input"]["disabled"] = nil
end

html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enabled", "ap_enabled", default_ap_enabled, ap_enable_class)

-- Show the SSID
local ssidclass = {
    input = {
        pattern= "[!-~][ -~]{0,30}[!-~]",
        maxlength= "32",
        class= "span4",
    }
}

--when AP is off, ssid input for AP shall be greyed out.
if default_ap_enabled == "0" then
  ssidclass["input"]["disabled"] = "disabled"
end

if "1" == band_steer_enabled and not isBaseIface(wl) then
    html[#html + 1] = ui_helper.createLabel(T"Network Name", content["ssid"], ssidclass)
else
    html[#html + 1] = ui_helper.createInputText(T"Network Name", "ssid", content["ssid"], ssidclass, helpmsg["ssid"])
end

-- Select the security mode to use
local secattributes = {
    group = {
        class = "",
    },
    select = {
        class = "monitor-changes"
    }
}

--when radio is off, AP shall be off and select shall be greyed out.
if default_ap_enabled == "0" then
  secattributes["select"]["disabled"] = "1"
end

if "1" == band_steer_enabled and not isBaseIface(wl) then
    html[#html + 1] = ui_helper.createLabel(T"Security Mode", content["security"], secattributes)
else
    html[#html + 1] = ui_helper.createInputSelect(T"Security Mode", "security", secmodes, content["security"], secattributes)

    local security_warning = {
        alert = {
            class = "alert-error monitor-security monitor-none"
        },
    }
    html[#html + 1] = ui_helper.createAlertBlock(T"Security for this Wi-Fi network is disabled, anybody can connect or listen to it", security_warning)
end

local wepclass = {
    group = {
        class ="monitor-security monitor-wep",
    },
    input = {
        class= "span4",
    }
}
local pskclass = {
    group = {
        class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk",
    },
    input = {
        class= "span4",
    }
}

--when AP is off, AP text input shall be greyed out.
if default_ap_enabled == "0" then
  wepclass["input"]["disabled"] = "disabled"
  pskclass["input"]["disabled"] = "disabled"
end

if "1" == band_steer_enabled and not isBaseIface(wl) then
    if "wep" == content["security"] then
        html[#html + 1] = ui_helper.createLabel(T"WEP Key", content["wep_key"], wepclass)
    end

    if "wpa-psk" == content["security"] or "wpa2-psk" == content["security"] or "wpa-wpa2-psk" == content["security"] then
        html[#html + 1] = ui_helper.createLabel(T"Network Key", content["wpa_psk"], pskclass)
    end
else
    html[#html + 1] = ui_helper.createInputText(T"WEP Key", "wep_key", content["wep_key"], wepclass, helpmsg["wep_key"])
    html[#html + 1] = ui_helper.createInputText(T"Network Key", "wpa_psk", content["wpa_psk"], pskclass, helpmsg["wpa_psk"])
end

if 1 == band_steer_supported and "wep" ~= content["security"] then
    local bssecclass = {
        group = {
            class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-none",
        },
    }

    local bs_warning = {
        alert = {
            class = "alert-warning monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-none"
        },
    }
    if isBaseIface(wl) then
        html[#html + 1] = ui_helper.createCheckboxSwitch(T"Band Steering Enabled", "band_steer_supported", band_steer_enabled, bssecclass)
        html[#html + 1] = ui_helper.createAlertBlock(T"The Band Steering actively guides the client to the most suitable Wi-Fi band, by detecting the client's capabilities and monitoring the interfaces.", bs_warning)
    else
        html[#html + 1] = ui_helper.createLabel(T"Band Steering Enabled", band_steer_enabled == "1" and "Yes" or "No", ssidclass)
    end
end
ngx.print(html)
  ngx.print('\
</fieldset>\
</form>\
\
');  
if content_radio["state"] == "1" then
  lp.include("save.lp")
end
  ngx.print('\
\
</div>\
</div>\
</div>\
\
\
');  
lp.include("networkmap.lp")
lp.include("footer.lp")
  ngx.print('\
<script>\
var bschecked = $(\'input[id="band_steer_supported"]\').prop("checked");\
$(document).ready(function() {\
    if (true == bschecked) {\
        $(\'option[value="wep"]\').hide();\
    }\
});\
\
$(\'input[id="band_steer_supported"]\').click(function(){\
    if (true == bschecked) {\
        $(\'option[value="wep"]\').hide();\
    }\
});\
</script>\
'); 