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
local setmetatable = setmetatable

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

local quantenna_wifi = proxy.get("uci.env.var.qtn_eth_mac")
quantenna_wifi = ((quantenna_wifi and quantenna_wifi[1].value~="") and true or false)


local getargs = ngx.req.get_uri_args()
local radio, wl, ap, bspeerwl, bspeerap
if getargs.radio == "5" then
    radio = "radio_5G"
    wl = "wl1"
    ap = "ap1"
else
    radio = "radio_2G"
    ap = "ap0"
    wl = "wl0"
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
--local radius = "uci.wireless.wifi-radius-server.@" .. ap .. "_"

-- UCI parameters list
local mapParams = {
    interface_enabled = radiop .. "state",
    standard = radiop .. "standard",
    channelconf= radiop .. "channel",
    channelwidth = radiop .. "channelwidth",
    ap_enabled = app .. "state",
    ssid = wlp .. "ssid",
    ap_broadcast_ssid = app .. "public",
    security = app .. "security_mode",
    wep_key = app .. "wep_key",
    wpa_psk = app .. "wpa_psk_key",
    wps_enabled = app .. "wps_state",
    wps_pin_enabled = app .. "wps_ap_setup_locked",
    wps_ap_pin_code = app .. "wps_ap_pin",
    acl_mode = app .. "acl_mode",
    wps_button_handler = "uci.button.button.@wps.handler",
--    radius_authent_state = radius .. "auth0.state",
--    radius_authent_ip = radius .. "auth0.ip",
--    radius_authent_port = radius .. "auth0.port",
--    radius_authent_secret = radius .. "auth0.secret",
--    radius_account_state = radius .. "acct0.state",
--    radius_account_ip = radius .. "acct0.ip",
--    radius_account_port = radius .. "acct0.port",
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

-- We're defining the listbox enums here to be able to use them to validate the input

local secmodes
if getargs.radio == "5" then
    -- do NOT show wep in 5G wifi
    secmodes={
        { "none", T"None"},
        { "wpa2-psk", T"WPA2 PSK"},
        { "wpa-wpa2-psk", T"WPA+WPA2 PSK"},
    }
else
    secmodes={
        { "none", T"None"},
        { "wep", T"WEP"},
        { "wpa2-psk", T"WPA2 PSK"},
        { "wpa-wpa2-psk", T"WPA+WPA2 PSK"},
    }
end

-- Listbox that shows the supported Access Control modes
local acl_modes = {
    { "disabled", T"Disabled" },
    { "unlock", T"Blacklist" },
    { "lock", T"Whitelist" },
    { "register", T"Register" },
}

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local gVSL = post_helper.getValidateStringLength
local vB = post_helper.validateBoolean
local gVCS = post_helper.getValidateCheckboxSwitch()
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vSIP = post_helper.validateStringIsPort
local vSIM = post_helper.validateStringIsMAC
local gOV = post_helper.getOptionalValidation
local gCV = post_helper.getConditionalValidation
local gAV = post_helper.getAndValidation
local vPSK = post_helper.validatePSK
local gVSLIR = post_helper.getValidateStringLengthInRange
local vWEP = post_helper.validateWEP
local vPIN = post_helper.validateWPSPIN
--local wpa_list = {"wpa2", "wpa-wpa2"}
--local VIPIL_IP = gVIPIL(vSII, "security", wpa_list)
--local VIPIL_port = gVIPIL(vSIP, "security", wpa_list)


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

local curband = radioData.supported_frequency_bands

local cw_40 = {
    {"20MHz", T"20MHz"},
    {"auto", T"Auto (20/40MHz)"},
}
local cw_80 = {
    {"20MHz", T"20MHz"},
    {"20/40MHz", T"20/40MHz"},
    {"auto", T"Auto (20/40/80MHz)"},
}

cw = setmetatable({
    ["2.4GHz"] = setmetatable({
        bgn = cw_40,
    },untaint_mt),
    ["5GHz"] = setmetatable({
        an = cw_40,
        anac = cw_80,
    }, untaint_mt),
}, untaint_mt)
local channelwidth = cw[curband][radioData.supported_standards]

-- Define different Channel Width contain different Channel
local list5g20 = {
    {"auto", T"Auto"},
    {"36", T"36"},
    {"40", T"40"},
    {"44", T"44"},
    {"48", T"48"},
    {"52", T"52(DFS)"},
    {"56", T"56(DFS)"},
    {"60", T"60(DFS)"},
    {"64", T"64(DFS)"},
    {"100", T"100(DFS)"},
    {"104", T"104(DFS)"},
    {"108", T"108(DFS)"},
    {"112", T"112(DFS)"},
    {"116", T"116(DFS)"},
    {"132", T"132(DFS)"},
    {"136", T"136(DFS)"},
    {"149", T"149"},
    {"153", T"153"},
    {"157", T"157"},
    {"161", T"161"},
}

local list5g40 = {
    {"auto", T"Auto"},
    {"36", T"36"},
    {"44", T"44"},
    {"52", T"52(DFS)"},
    {"60", T"60(DFS)"},
    {"100", T"100(DFS)"},
    {"108", T"108(DFS)"},
    {"132", T"132(DFS)"},
    {"149", T"149"},
    {"157", T"157"},
}

local list5gAuto = {
    {"auto", T"Auto"},
    {"36", T"36"},
    {"52", T"52(DFS)"},
    {"100", T"100(DFS)"},
    {"132", T"132(DFS)"},
    {"149", T"149"},
}

list5g = setmetatable({
    ["20MHz"] = list5g20,
    ["20/40MHz"] = list5g40,
    ["auto"] = list5gAuto,
}, untaint_mt)

local function getValidateChannelConf(value, postdata, key)
  if radioData.supported_frequency_bands == "5GHz" then
      -- if the exist channel is not in the channelwidth which the newest selected, set "auto" to it, if not, keep it not changed
      -- the type of postdata["channelwidth"] is userdata which is not able to compare to string directly
      local gVEIS_CC = gVIES(list5g[postdata["channelwidth"]])
      local err,msg = gVEIS_CC(value)
      if not err then
        postdata["channelconf"] = "auto"
      end
  end
  return true
end

--when radio is changing from "0" to "1", remove postdata["ap_enabled"] as AP enabled is not active yet.
local function vApEnabled (value, postdata, key)
  local err,msg = gVCS(value, postdata, key)
  if not err then
    return err,msg
  end

  local content_radio = {
      state = radiop .. "state",
  }
  content_helper.getExactContent(content_radio)

  if content_radio.state == "0" then
    postdata[key] = nil
  end

  return true
end

--when AP enable is changing from "0" to "1", remove postdata["wps_enabled"] as wps enabled is not active yet.
local function vWpsEnabled (value, postdata, key)
  local err,msg = gVCS(value, postdata, key)
  if not err then
    return err,msg
  end

  local content_wl = {
      radio_state = radiop .. "state",
      ap_state = app .. "state",
  }
  content_helper.getExactContent(content_wl)

  if content_wl.ap_state == "0" or content_wl.radio_state == "0" then
    postdata[key] = nil
  end

  return true
end

--toggle the input as wps_ap_setup_locked = 1 means wps pin method is disabled
local function vApPinEnabled (value, postdata, key)
  local err,msg = gVCS(value, postdata, key)
  if not err then
    return err,msg
  end

  postdata[key] = tostring(1-postdata[key])

  return true
end

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

---
-- Here we're adding logic to make sure that we set the state of the authent and accounting server
-- for radius to 0/1.
-- This is done by checking if we're in EAP mode (wpa2 or wpa-wpa2), and if so, setting the state
-- accordingly (we use the validation chain for that through the use of a condional check)
-- For accounting, we need to additionally check that the IP and port are non empty since they're
-- optional.
--local radius_modes = setmetatable({
--    ["wpa2"] = true,
--    ["wpa-wpa2"] = true
--}, untaint_mt)
--local radiusCond = function(value, object, key)
--    return radius_modes[object["security"]], ""
--end

--local function checkIPandPort(value, object, key)
--    local ip = object["radius_account_ip"]
--    local port = object["radius_account_port"]
--    if istainted(port) and istainted(ip) and ip:len() > 0 and port:len() > 0 then
--        return true
--    end
--    return false, "IP or port is empty"
--end

--local function getReplaceValue(newval)
--    return function(value, object, key)
--        object[key] = newval
--        return true
--    end
--end

-- End of code specific to Radius settings

local mapValid = {
    interface_enabled = gVCS,
    channelconf = getValidateChannelConf,
    channelwidth = gVIES(channelwidth),
    ap_enabled = vApEnabled,
    security = gVIES(secmodes),
    ssid = gVSLIR(1,32),
    wep_key = gVIPIL(vWEP,"security", {"wep"}),
    wpa_psk = gVIPIL(vPSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"}),
    wps_enabled = vWpsEnabled,
    wps_pin_enabled = vApPinEnabled,
    acl_mode = gVIES(acl_modes),
--    radius_authent_ip = VIPIL_IP,
--    radius_account_ip = gOV(VIPIL_IP),
--    radius_authent_secret = gVIPIL(vNES,"security", wpa_list),
--    radius_authent_port = VIPIL_port,
--    radius_account_port = gOV(VIPIL_port),
--    radius_authent_state = gCV(radiusCond, getReplaceValue("1"), getReplaceValue("0")), -- we know that we're enforcing the server ip and port is there
--    radius_account_state = gCV(gAV(radiusCond, checkIPandPort), getReplaceValue("1"), getReplaceValue("0")) -- if no server ip or port, don't set to 1
    wps_button_handler = function(val, object)
      object.wps_button_handler = "wps_button_pressed.sh"
      return true
    end,
    bsid = getValidateBandSteerPeerFields,
    ap_broadcast_ssid = gVCS,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End of parameters saving / loading

-- Support for device PIN code
content["wps_device_pin_code"] = ""

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

-- triggered only on a POST with action set wps_device_pin_code (button next to field should trigger that)
if ngx.req.get_method() == "POST" then
    local args = ngx.req.get_post_args()
    local action = args["action"]
    local pin = args["wps_device_pin_code"]
    if action == "wps_device_pin_code" and content["wps_enabled"] == "1" then
        local res, help = vPIN(pin)
        content["wps_device_pin_code"] = pin

        if res then
            proxy.set("rpc.wireless.ap.@" .. ap .. ".wps.enrollee_pin",pin)
            message_helper.pushMessage(T"Device PIN code entered", "success")
        else
            helpmsg["wps_device_pin_code"] = help
        end
    end
end
-- End of device PIN code support

-- triggered only on a POST with action set wps_pbc
if ngx.req.get_method() == "POST" then
    local args = ngx.req.get_post_args()
    local action = args["action"]
    if action == "wps_pbc" and content["wps_enabled"] == "1" then
        proxy.set("rpc.wireless.wps_button","1")
        message_helper.pushMessage(T"Started WPS PBC mode", "success")
    end
end
-- End of WPS PBC code support

-- AP PIN code - read only
content["wps_ap_pin_code"] = proxy.get(app .. "wps_ap_pin")[1].value

-- Radio data
for k,v in pairs(radioData) do
    -- Not replace the value that already exists
    if not content[k] then
        content[k] = v
    end
end

content["phy_rate"] = content["phy_rate"] or 0

-- Let the Channel and Current channel present the same after save
if content["channelconf"] and content["channelconf"] ~= "auto" then
    content["channel"] = content["channelconf"]
end

-- Mac Address
if quantenna_wifi and wl == "wl1" then
	content["macaddress"] = proxy.get("sys.class.net.@eth5.address")[1].value
else
	content["macaddress"] = proxy.get("sys.class.net.@".. wl ..".address")[1].value
end

local acl_columns = {
    {
        header = T"MAC Address",
        name = "acl_macaddress",
        param = "value",
        type = "text",
        attr = { input = { class = "span2", maxlength = "17" } },
    }
}

local macvalid = {
    acl_macaddress = vSIM,
}

local acl_whitelist_options = {
    tableid = "acl_whitelist",
    basepath = ap .. "acl_accept_list.@.",
    createMsg = T"Add new MAC address",
}
local acl_whitelist_data, acl_whitelist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_whitelist_options, nil, nil, macvalid)

local acl_blacklist_options = {
    tableid = "acl_blacklist",
    basepath = ap .. "acl_deny_list.@.",
    createMsg = T"Add new MAC address",
}
local acl_blacklist_data, acl_blacklist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_blacklist_options, nil, nil, macvalid)

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
\
<fieldset>\
<legend>');  ngx.print( T"Wi-Fi Radio" ); ngx.print('</legend>\
\
');  
html = {}
--Enable/Disable radio

local wl_radio_class = {
    input = {
        class = "monitor-changes"
    }
}

html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enabled", "interface_enabled", content["interface_enabled"], wl_radio_class)
ngx.print(html)
  ngx.print('\
\
<fieldset>\
<legend>');  ngx.print( T"Wi-Fi Channel" ); ngx.print('</legend>\
\
');  
local html = {}

-- Label that shows the MAC address of the Wifi interface
html[#html + 1] = ui_helper.createLabel(T"MAC Address", content["macaddress"])


-- Current speed of the Wifi interface
html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps")

-- Choose which channel to use
local channel_select_class = {
    select = {},
}

--when radio is off, AP shall be off and select shall be greyed out.
if content["interface_enabled"] == "0" then
  channel_select_class["select"]["disabled"] = "1"
end

-- Choose which channel to use

local allowed_channels = { {"auto", T"Auto"} }

if getargs.radio ~= "5" then
  for i in string.gmatch(content["allowed_channels"], "%S+") do
      allowed_channels[#allowed_channels + 1] = {i, i}
  end
else -- wifi 5g need limit the channel by different channelwidth
  allowed_channels = list5g[content["channelwidth"]]
end
html[#html + 1] = ui_helper.createInputSelect(T"Channel", "channelconf", allowed_channels, content["channelconf"], channel_select_class)

-- Show which region is being used
html[#html + 1] = ui_helper.createLabel(T"Region", content["country"], advanced)
html[#html + 1] = ui_helper.createLabel(T"Current Channel", content["channel"])

html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth", channelwidth, content["channelwidth"], channel_select_class)

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
        disabled = "disabled",
    }
}

--when radio is on, ap enabled button is active
if content["interface_enabled"] == "1" then
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

local broadcastclass = {
    group = {
        class = "advanced hide",
    },
    input = {
        class = "monitor-changes"
    }
}

-- Should we broadcast the SSID
html[#html + 1] = ui_helper.createCheckboxSwitch(T"Broadcast SSID", "ap_broadcast_ssid", content["ap_broadcast_ssid"], broadcastclass)

-- Select the security mode to use
local secattributes = {
    select = {
        class = "monitor-changes",
    },
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

--local monitorradius = {
--    class ="monitor-security monitor-wpa monitor-wpa2 monitor-wpa-wpa2",
--}
--local ipclass = {
--    pattern="(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])",
--}
--local serverclass = {
--    group = monitorradius,
--    input = ipclass
--}
--local basicclass = {
--    group = monitorradius,
--}
--html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's IP", "radius_authent_ip", content["radius_authent_ip"], serverclass, helpmsg["radius_authent_ip"])
--html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's port", "radius_authent_port", content["radius_authent_port"],basicclass, helpmsg["radius_authent_port"])
--html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's secret", "radius_authent_secret", content["radius_authent_secret"],basicclass, helpmsg["radius_authent_secret"])
--html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's IP", "radius_account_ip", content["radius_account_ip"], serverclass, helpmsg["radius_account_ip"])
--html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's port", "radius_account_port", content["radius_account_port"],basicclass, helpmsg["radius_account_port"])

local wps_warning = {
    alert = {
        class = "alert-warning monitor-security monitor-wep monitor-wpa-psk monitor-ap_broadcast_ssid monitor-0 monitor-default-show"
    },
}

html[#html + 1] = ui_helper.createAlertBlock(T"WPS is automatically disabled if you choose WEP or WPA-only security or disable broadcast of the SSID", wps_warning)

--when radio is off, AP shall be off and button shall be greyed out.
local default_wps_enabled = "0"
local wps_enable_class = {
    group = {
        class = "monitor-security monitor-none monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-ap_broadcast_ssid monitor-1 monitor-interface_enabled monitor-1 monitor-ap_enabled monitor-1",
    },
    input = {
        class = "monitor-changes",
        disabled = "disabled",
    }
}

--when AP is on, WPS enabled button is active
if default_ap_enabled == "1" then
  default_wps_enabled = content["wps_enabled"]
  wps_enable_class["input"]["disabled"] = nil
end

local wps_class = {
    group = {
        class = "monitor-security monitor-none monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-ap_broadcast_ssid monitor-1 monitor-interface_enabled monitor-1 monitor-ap_enabled monitor-1 monitor-wps_enabled monitor-1"
    }
}

local content_wps = {
    wps_pin_enabled = app .. "wps_ap_setup_locked",
}
content_helper.getExactContent(content_wps)

html[#html + 1] = ui_helper.createCheckboxSwitch(T"WPS", "wps_enabled", default_wps_enabled, wps_enable_class)

html[#html + 1] = ui_helper.createCheckboxSwitch(T"WPS AP PIN Enabled", "wps_pin_enabled", tostring(1-content_wps["wps_pin_enabled"]), wps_class)
html[#html + 1] = ui_helper.createLabel(T"WPS AP PIN Code", content["wps_ap_pin_code"], wps_class)

wps_class["input"] = {
    class="no-save",
    ["data-for"] = "wps_device_pin_code",
}
wps_class["button"] = {
    ["data-name"] = "action",
    ["data-value"] = "wps_device_pin_code",
}
html[#html + 1] = ui_helper.createInputTextWithButton(T"WPS Device PIN Code", "wps_device_pin_code", content["wps_device_pin_code"], T"Set PIN code", "icon-ok-sign" ,wps_class, helpmsg["wps_device_pin_code"])

wps_class["button"] = {
    ["data-name"] = "action",
    ["data-value"] = "wps_pbc",
}
html[#html + 1] = ui_helper.createButton(T"Connect using WPS", T"Start", "icon-refresh", wps_class)

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
\
        </fieldset>\
\
        <fieldset class="advanced hide">\
        <legend>');  ngx.print( T"Access Control List" ); ngx.print('</legend>\
        ');  
        html = {}

local aclmodeclass = {
    select = {
        class = "monitor-changes"
    }
}
html[#html + 1] = ui_helper.createInputSelect(T"ACL mode", "acl_mode", acl_modes, content["acl_mode"], aclmodeclass)

local whitelistclass = {
    group = {
        class = "monitor-acl_mode monitor-lock monitor-register"
    }
}
html[#html + 1] = ui_helper.createTable(acl_columns, acl_whitelist_data, acl_whitelist_options, whitelistclass, acl_whitelist_helpmsg)

local blacklistclass = {
    group = {
        class = "monitor-acl_mode monitor-unlock"
    }
}
html[#html + 1] = ui_helper.createTable(acl_columns, acl_blacklist_data, acl_blacklist_options, blacklistclass, acl_blacklist_helpmsg)

ngx.print(html)
  ngx.print('\
</fieldset>\
\
<fieldset>\
');  
if isguest ~= "1" then
    -----------------------------------------------------------
    -- Detect whether NFC module exists, if exists, show the pop up info
    -----------------------------------------------------------
    local nfc_enabled = proxy.get("rpc.nfc.exists")
    if (nfc_enabled and nfc_enabled[1].value == "true") then 
        local nfc_alert = {
            alert = {
                class = "alert alert-warning"
            },
        }  ngx.print('\
        <legend>');  ngx.print( T"Near Field Communication (NFC)" ); ngx.print('</legend>\
        ');  ngx.print(ui_helper.createAlertBlock(T"Near Field Communication (NFC) allows you to tap an Android smartphone or tablet against the front of your Gateway to automatically configure Wi-Fi credentials on your device, so that you can connect over Wi-Fi. This feature is not supported on Apple iOS devices.<br/><br/><a href=/gateway.lp?openmodal=nfc-modal.lp ><u>Click here</u></a> to configure NFC.", nfc_alert))
    end
end
  ngx.print('\
\
</fieldset>\
\
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
\
');  
lp.include("networkmap.lp")
lp.include("footer.lp")
  ngx.print('\
\
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
\
\
'); 