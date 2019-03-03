--pretranslated: do not change this file
--NG-71199
--NG-73655 Guest SSID name not updated in Local Network card
--NG-78960 Button to activate/deactivate the Wireless shall be also be available on basic Page for all users
--NG-71225 WiFi 2.4 GHZ : Set the standard as 802.11 b/g for radio 2.4GHZ, Channel Width should not change and LED should not glow off in Wireless Card
--NG-85869 reverts NG-85820 [GUI-Workaround] Avoid entering Spaces on SSID-Names, since in 17.1 not needed anymore
--NG-92666 TI-GUI : Query : New Features added
--NG-95384 TI-WiFi 5GHz : Ospiti 5GHz Security mode fails and Main 5GHz has new features
--NG-96425 TI-[GUI] - Changing SSID name of Guest 5GHz is not coherent in Wireless and Local Network Modal
--NG-100744 Custo-GUI: ubus call timeout when changing WiFi state and security settings
--NG-136046 GUI-Wireless- WPS AP PIN code must appear disabled

local istainted = string.istainted
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local untaint = string.untaint
local session = ngx.ctx.session

-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local ajax_helper = require("web.ajax_helper")
local pairs = pairs
local match, format, gsub, next = string.match, string.format, string.gsub, next
local bandsteer_helper = require("bandsteer_helper")
local isBaseIface = bandsteer_helper.isBaseIface
local disableBandSteer = bandsteer_helper.disableBandSteer

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
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
local vSIPV6 = post_helper.validateStringIsIPv6
local gRV = post_helper.getOrValidation
local gVSIIP = gRV(vSII,vSIPV6)
local wpa_list = {"wpa2", "wpa-wpa2"}
local VIPIL_IP = gVIPIL(gVSIIP, "security", wpa_list)
local VIPIL_port = gVIPIL(vSIP, "security", wpa_list)
local vQTN = post_helper.validateQTN

-- Take the input options for a listbox, the value and return the associated text
local listboxToText = function(options, value)
    for i,v in ipairs(options) do
        if v[1] == value then
           return v[2]
        end
    end
    return value
end

local getargs = ngx.req.get_uri_args()
local getradio = getargs.radio
local getiface = getargs.iface
local getWifiAnalyzer = getargs.isWifiAnalyzer

local curradio = "radio_2G"
local curiface = "wl0"
local curap = "ap0"
local isguest = "0"
local isExtRemman = "0" -- AP remotely managed, like a TG233 DANT-5 board in AP mode.
local isIntRemman = "0" -- Quantenna

local stbLimit = false

-- Return the acs data for selected radio to generate Analyzer graph
local function getAcsData(cradio, delay)
  local json = require("dkjson")
  local bsslistData = proxy.get("rpc.wireless.bssid.@" .. cradio .. ".bsslist.")
  --Timeout of 30 secs Delay is introduced to get values from bsslistData when the rescan button is clicked
  if delay then
    local step = 0
    while step <= 10 do
      bsslistData = proxy.get("rpc.wireless.bssid.@" .. cradio .. ".bsslist.")
      if next(bsslistData) then
        break
      end
      ngx.sleep(3)
      step = step + 1
    end
  end
  bsslistData = content_helper.convertResultToObject("rpc.wireless.bssid.@" .. cradio .. ".bsslist.",bsslistData)
  local buffer = {}
  local success = json.encode (bsslistData, { indent = false, buffer = buffer})
  if success then
    ngx.header.content_type = "application/json"
    ngx.print(buffer)
    ngx.exit(ngx.HTTP_OK)
  end
end

if ngx.req.get_method() == "POST" and  ngx.req.get_post_args().action =="rescan" then
   local cradio = ngx.req.get_post_args().curradio
   local rescan_val = format ('rpc.wireless.radio.@%s.acs.rescan', cradio)
   proxy.set(rescan_val, "1")
   getAcsData(cradio, true)
elseif getWifiAnalyzer and getargs.getAcsData then
   getAcsData(getradio)
end

local radios = {}
for i,v in ipairs(proxy.getPN("rpc.wireless.radio.", true)) do
    local radio = match(v.path, "rpc%.wireless%.radio%.@([^%.]+)%.")
    if radio then
        radios[#radios+1] = radio
        if radio == getradio then
            curradio = radio
        end
    end
end
table.sort(radios)

ajax_helper.handleAjaxQuery({
    phy_rate = "rpc.wireless.radio.@" .. curradio .. ".phy_rate",
    channel = "rpc.wireless.radio.@" .. curradio .. ".channel",
    }, function(content)
        content["phy_rate"] = content["phy_rate"] / 1000 .. "Mbps"
    end)

local ap_paths={true}
for i,v in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
  ap_paths[i] = v.path.."ssid"
end

local wl_list = proxy.get(unpack(ap_paths))
local wls = {}
local cur_ssid
for i,v in ipairs(wl_list) do
  local path = "rpc.wireless.ssid.@" .. v.value
  local values = proxy.get(path .. ".radio" , path .. ".ssid",path .. ".stb", path .. ".ap_display_name")
  if values ~= nil then
    wls[#wls+1] = {
            radio = values[1].value,
            ssid = values[2].value,
            iface = v.value,
            stb = values[3].value,
            ap_display_name = values[4].value
        }
    if (v.value == getiface) or (not getiface and v.value == curiface) then
        curiface = v.value
        curap = match(v.path, "rpc%.wireless%.ap%.@([^%.]+)%.")
        isguest = proxy.get(v.path .. "ap_isolation")[1].value
        cur_ssid = values[2].value
    end
 end
end
table.sort(wls, function(a,b)
    if a.radio == b.radio then
        return a.iface < b.iface
    else
        return a.radio < b.radio
    end
end)

if ngx.req.get_method() == "POST"  and  ngx.req.get_post_args().action == "set_reg" then
    local content_acl ={
       state = "rpc.wireless.ap.@"..curap..".acl.state"
    }
    content_helper.getExactContent(content_acl)
    local acl_ap = ngx.req.get_post_args().curap
    local content_acl_state = format('%s',content_acl["state"])
    if content_acl_state ~= "register" then
      local acl_ap_url1 = format ('rpc.wireless.ap.@%s.acl.mode', acl_ap)
      proxy.set(acl_ap_url1, "register" )
      proxy.apply()
      ngx.sleep(10)
    end
   local acl_ap_url = format ('rpc.wireless.ap.@%s.acl.reg', acl_ap)
   proxy.set(acl_ap_url, "1" )
   ngx.print('{ "success":"true" }')
   proxy.apply()
   ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().action == "get_reg_status"  then
    local acl_ap = ngx.req.get_uri_args().curap
    local reg_status = proxy.get("rpc.wireless.ap.@"..acl_ap..".acl.state")[1].value
    ngx.print(reg_status)
    ngx.exit(ngx.HTTP_OK)
end

-- The function can be reused to load the ACL mac list by ajax and normal request
-- Normal request means - Adding, Editing and Deleting the ACL mac address entries by normal POST request
local function loadAclList(aclmode, action)
  local acl_columns = {
   {
    header = T"MAC Address",
    name = "acl_macaddress",
    param = "value",
    type = "text",
    attr = { input = { class = "span2", maxlength = "17" } },
   }
  }
  local function valueInList(inputlist, value)
    if inputlist then
       for _,v in ipairs(inputlist) do
         if v.value ==  value then
           return true
         end
       end
    end
    return false
  end
  local function validateAclMac(value,object,key)
    local retval, errmsg = vSIM(value,object,key)
    if not retval then
       return retval, errmsg
    end
    local path = "uci.wireless.wifi-ap.@" .. curap
    local macdata = proxy.get(path .. ".acl_accept_list.", path .. ".acl_deny_list.")

    if valueInList(macdata, value) then
       return nil, T"Mac address duplicate with either current whitelist or current blacklist"
    end
    return true
  end
  local macvalid = {
    acl_macaddress = gAV(validateAclMac,vQTN)
  }
  local acl_whitelist_options = {
    tableid = "acl_whitelist",
    basepath = format("uci.wireless.wifi-ap.@%s.acl_accept_list.@.",curap),
    createMsg = T"Add new MAC address",
  }
  if aclmode == "register" then
    acl_whitelist_options["tableid"] = "acl_register"
  end
  local acl_whitelist_data, acl_whitelist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_whitelist_options, nil, nil, macvalid)

  local acl_blacklist_options = {
    tableid = "acl_blacklist",
    basepath = format("uci.wireless.wifi-ap.@%s.acl_deny_list.@.",curap),
    createMsg = T"Add new MAC address",
  }
  local acl_blacklist_data, acl_blacklist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_blacklist_options, nil, nil, macvalid)

  local html={}
  local whitelistclass = {
    group = {
      class = "monitor-acl_mode monitor-lock monitor-register",
    }
  }
  if aclmode == "unlock" or aclmode == "disabled" then
    whitelistclass["group"].style = "display:none;"
  end
  if #acl_whitelist_data < 1 and action ~= "POST" then
    whitelistclass["group"].style = "display:none;"
    whitelistclass ["span"] = {id = "Address_list_Whitelistclass"}
    html[#html+1] = ui_helper.createLabel("", T"MAC Address list is empty", whitelistclass, nil)
    acl_columns[1].header=""
  end
  html[#html+1] = ui_helper.createTable(acl_columns, acl_whitelist_data, acl_whitelist_options, whitelistclass, acl_whitelist_helpmsg)
  local blacklistclass = {
    group = {
      class = "monitor-acl_mode monitor-unlock"
    }
  }
  if #acl_blacklist_data < 1 and  action ~= "POST" then
     blacklistclass["group"].style = "display:none;"
     blacklistclass ["span"] = {id = "Address_list_Blacklistclass"}
     html[#html+1] =  ui_helper.createLabel("", T"MAC Address list is empty", blacklistclass, nil)
     acl_columns[1].header=""
  else
    acl_columns[1].header = format("<span style=\"font-weight:normal;\">%s</span>", T"MAC Address")
  end
  if aclmode == "lock" or aclmode == "register" or aclmode == "disabled" then
    blacklistclass["group"].style = "display:none;"
  end
    html[#html+1] = ui_helper.createTable(acl_columns, acl_blacklist_data, acl_blacklist_options, blacklistclass, acl_blacklist_helpmsg)
  return html
end
-- Load the ACL Mac Address list by ajax get request
if getargs.action=="GET_ACL_MAC_LIST" then
  local acl_mode = getargs.acl_mode
  ngx.print(loadAclList(acl_mode, "GET"))
  ngx.exit(ngx.HTTP_OK)
end

local radioData ={}
for i,v in ipairs(radios) do
  local path = "rpc.wireless.radio.@" .. v
  local rdata = proxy.get(path..".supported_frequency_bands" ,
        path .. ".remotely_managed",
        path .. ".supported_standards",
        path .. ".integrated_ap",
        path .. ".phy_rate",
        path .. ".country",
        path .. ".channel")
  if rdata ~= nil then
    radioData[v] = {
      supported_frequency_bands=rdata[1].value,
      remotely_managed=rdata[2].value,
      supported_standards=rdata[3].value,
      integrated_ap=rdata[4].value,
      phy_rate = rdata[5].value,
      country = rdata[6].value,
      channel = rdata[7].value,
    }
  end
end

if radioData[curradio].remotely_managed == "1" and radioData[curradio].integrated_ap ~= "1" then
    isExtRemman = "1"
elseif radioData[curradio].remotely_managed == "1" and radioData[curradio].integrated_ap == "1" then
	isIntRemman = "1"
end

-- We're defining the listbox enums here to be able to use them to validate the input
-- Listbox that shows the supported WiFi standards
local wifi_standard_24GHz = {
      { "bg", T'802.11b/g'},
      { "bgn", T'802.11b/g/n'},
}

local wifi_standard_5GHz = {
    ["an"]= T'802.11a/n',
    ["anac"]= T'802.11a/n/ac',
}

local wifiStandard = {
  standard = "uci.wireless.wifi-device.@radio_5G.standard"
}

local wifi_standard={}
if radioData[curradio].supported_frequency_bands == "5GHz" then
  content_helper.getExactContent(wifiStandard)
  if wifiStandard.standard and wifiStandard.standard ~= "" then
    wifi_standard[1] = {wifiStandard.standard,wifi_standard_5GHz[untaint(wifiStandard.standard)]}
  else
    wifi_standard[1] = {"",""}
  end
else
    wifi_standard = wifi_standard_24GHz
end

local bandsteer_rssi_threshold = {
    {"-10", T"10%"},
    {"-20", T"20%"},
    {"-30", T"30%"},
    {"-40", T"40%"},
    {"-50", T"50%"},
    {"-60", T"60%"},
    {"-70", T"70%"},
    {"-80", T"80%"},
    {"-90", T"90%"},
}
-- Choose Wifi power
local wifipower = {
    {"-3", T"100%"},
    {"-2", T"125%"},
    {"-1", T"160%"},
    {"0", T"200%"},
}

local cw_40 = {
    {"20MHz", T"20MHz"},
    {"auto", T"Auto (20/40MHz)"},
}
local cw_80 = {
    {"20MHz", T"20MHz"},
    {"20/40MHz", T"20/40MHz"},
    {"auto", T"Auto (20/40/80MHz)"},
}

local cw = {
  ["bg"] = "channelwidth20",
  ["bgn"] = "channelwidth40",
  ["an"] = "channelwidth40",
  ["anac"] = "channelwidth80",
}

local cwmaps = {
    ["channelwidth20"] = cw_40,
    ["channelwidth40"] = cw_40,
    ["channelwidth80"] = cw_80,
}

local cddList = {
  {"1", T"Auto"},
  {"on", T"On"},
  {"off", T"Off"}
}

local channelwidth = cwmaps[cw[untaint(radioData[curradio].supported_standards)]]

local supported_modes_data  = proxy.get("rpc.wireless.ap.@" .. curap .. ".security.supported_modes")
local supported_modes = format("%s", supported_modes_data and supported_modes_data[1] and supported_modes_data[1].value or "")
local secmodes = {}
local secmodes_matched = {
     ["none"] = T"None",
     ["wpa2-psk"] = T"WPA2 PSK",
     ["wpa-wpa2-psk"] =  T"WPA+WPA2 PSK",
     ["wpa-wpa2"] =  T"WPA+WPA2",
}
supported_modes:gsub("[^%s]+", function(c)
    if secmodes_matched[c] then
        secmodes[#secmodes+1] = { c, secmodes_matched[c] }
    else
        secmodes[#secmodes+1] = { c, T(string.upper(c)) }
    end
end)
-- remove radius modes if in guest ap page
if isguest == "1" then
    local num = #secmodes
    for i=num, 1, -1 do
        if secmodes[i][1] == "wpa2" or secmodes[i][1] == "wpa-wpa2" then
            table.remove(secmodes, i)
        end
    end
end

-- Listbox that shows the supported Access Control modes
local acl_modes = {
      { "disabled", T"Disabled" },
      { "unlock", T"Blacklist" },
      { "lock", T"Whitelist" },
 }

 if radioData[curradio].remotely_managed ~= "1" then
    acl_modes[#acl_modes+1] = {"register", T"Register"}

 end

local function getValidateChannelWidth(channelWidth)
  return function(value, postdata, key)
    local success, msg = gVIES(channelWidth)
    if success then
      postdata["requested_channel_width"] = postdata[cw[untaint(postdata["standard"])]]
      return true
    else
      return nil, msg
    end
  end
end

local function getValidateExtraSpaces(value)
   if match(value, "^%s+") or match(value, "%s+$") then
      return nil, T"Leading and trailing whitespaces are not allowed."
   end
   return true
end

-- Here we're adding logic to make sure that we set the state of the authent and accounting server
-- for radius to 0/1.
-- This is done by checking if we're in EAP mode (wpa2 or wpa-wpa2), and if so, setting the state
-- accordingly (we use the validation chain for that through the use of a condional check)
-- For accounting, we need to additionally check that the IP and port are non empty since they're
-- optional.
local radius_modes = setmetatable({
        ["wpa2"] = true,
        ["wpa-wpa2"] = true
    }, untaint_mt)
local radiusCond = function(value, object, key)
    return radius_modes[object["security"]], ""
end

local function checkIPandPort(value, object, key)
    local ip = object["radius_account_ip"]
    local port = object["radius_account_port"]
    if istainted(port) and istainted(ip) and #ip > 0 and #port > 0 then
        return true
    end
    return false, "IP or port is empty"
end

local function getReplaceValue(newval)
    return function(value, object, key)
        object[key] = newval
        return true
    end
end
-- End of code specific to Radius settings

-- Bug fix for NG-12032 GUI wireless enable/disable not working properly
-- if the post request is from the small card,
-- we need to set the admin state of the radios other than the current radio
local function getInterfaceEnabled2(value, object, key)
    if not object["fromModal"] then
       object[key] = object["admin_state"]
    else
       object[key] = nil
    end
    return true
end

local piface = "uci.wireless.wifi-iface."
local pathradio = format("rpc.wireless.radio.@%s.", curradio)
local pathiface = format("rpc.wireless.ssid.@%s.", curiface)
local pathap = format("rpc.wireless.ap.@%s.", curap)
local pathradius = format("uci.wireless.wifi-radius-server.@%s_", curap)
local bspeerap = nil
local pap = "uci.wireless.wifi-ap."
local bandsteeriface = bandsteer_helper.getBandSteerPeerIface(curiface)
local aap = content_helper.convertResultToObject(pap .. "@.", proxy.get(pap))
local radius_account = proxy.get(pathradius .. "acct0.")
local radius_authent = proxy.get(pathradius .. "auth0.")
for i,v in ipairs(aap) do
    if bandsteeriface and v.iface == bandsteeriface then
        bspeerap = v.paramindex
    end
end

-- If this AP connects to STB, "engineer" role has full access, other roles only have simple stats
if proxy.get(pathiface .. "stb")[1].value == "1" then
    if ngx.ctx.session:getrole() ~= "engineer" then
        stbLimit = true
    end
end

local bandsteerpathap = bspeerap and format("rpc.wireless.ap.@" .. "%s.", bspeerap) or ""

local function getValidateBandSteerPeerFields(value, object, key)
    local state = object.ap_enabled
    local bandsteer_enabled
    if isguest ~= "1" then
        state  = object.admin_state
    end
    if session:retrieve("bs_check_action") == "TRUE" then
        session:store("bs_check_action", "")
        bandsteer_enabled = proxy.get("uci.wireless.wifi-ap.@ap0.bandsteer_id")[1].value
    else
        bandsteer_enabled = object.band_steer_enabled
    end

    if "bs0" == bandsteer_enabled or bandsteer_enabled == "1" then
        if "table" ~= type(state) and "1" ~= state then --bandsteer enabled, network disabled
            return true
        elseif "" ~= object.bsid and "off" ~= object.bsid then
            if object.security == "wep" then
                return nil, T"The Band Steering can not be supported under WEP security mode."
            end

            if isBaseIface(curiface) then
                if object.bspeer_security_mode then
                    object.bspeer_security_mode = object.security
                    object.bspeer_wpa_psk_key = object.wpa_psk
                    object.bspifacessid = object.ssid
                end
            end
            return true
        else
            local bsid = bandsteer_helper.getBandSteerId(curiface)
            --to check wether the bs obj exist or not
            local bandsteerobj = proxy.get("uci.wireless.wifi-bandsteer.@" .. bsid .. ".")
            if not bandsteerobj then
                return nil, T"Please configure wifi-bandsteer " .. bsid .. " first!"
            else
                if object.security == "wep" then
                    return nil, T"The Band Steering can not be supported under WEP security mode."
                end

                if isBaseIface(curiface) then
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
    elseif object.band_steer_enabled then --to disable bandsteer
        return disableBandSteer(object)
    end

    return true
end

local bandsteerpath = "uci.wireless.wifi-bandsteer."
local bandsteers = content_helper.convertResultToObject(bandsteerpath .. "@.", proxy.get(bandsteerpath))
table.sort(bandsteers, function(a,b)
    return a.paramindex < b.paramindex
end)

local bandsteerindex = "0"
if not bandsteers or 0 == #bandsteers then
    bandsteerindex = "0"
else
    bandsteerindex = bandsteers[#bandsteers].paramindex
end

local param = {
    allowed_channels = pathradio .. "allowed_channels"
}
content_helper.getExactContent(param)
local allowed_channels = { {"auto", T"Auto"} }
for i in string.gmatch(param["allowed_channels"], "%S+") do
    allowed_channels[#allowed_channels + 1] = {i, i}
end

local function validateRadioandAp(value, object, key)
    local valid, msg = post_helper.validateBoolean(value, object, key)
	local acpath = "rpc.wireless.ap."
	local acpoint = proxy.get(acpath)
	local acpointlist = content_helper.convertResultToObject(acpath,acpoint)
	if valid then
		if value == "0" then
			proxy.set(pathap .. "admin_state","0")
		elseif value == "1" then
			proxy.set(pathap .. "admin_state","1")
		end
		proxy.apply()
	end
	return valid, msg
end

local wps_button_mode = {
	{ "wps_button_pressed.sh" , T"WPS Mode" },
	{ "acl_button_pressed" , T"ACL Mode" },
	{ "" , T"Disabled" },
  }

-- Constructing the rpc parameters and validations for post handleQuery
local function getParamsAndValidation()
  local wps_button_handler = setmetatable({
        ["1"] = "wps_button_pressed.sh",
        ["0"] = "acl_button_pressed.sh",
    }, untaint_mt)

  -- rpc parameters list
  local mapParams = {
    ssid = pathiface .. "ssid",
    ap_broadcast_ssid = pathap .. "public",
    security = pathap .. "security.mode",
    wep_key = pathap .. "security.wep_key",
    wpa_psk = pathap .. "security.wpa_psk_passphrase",
    acl_mode = pathap .. "acl.mode",
    wps_button_handler = "uci.button.button.@wps.handler",
    standard = pathradio .. "standard",
    requested_channel = pathradio .. "requested_channel",
    requested_channel_width = pathradio .. "requested_channel_width",
    }
    if isguest=="1" then
        mapParams.ap_enabled = pathap .. "admin_state"
    end

  if isguest ~= "1" then
        mapParams.admin_state = pathradio .. "admin_state"
        mapParams.standard = pathradio .. "standard"
        mapParams.requested_channel = pathradio .. "requested_channel"
        mapParams.requested_channel_width = pathradio .. "requested_channel_width"
        mapParams.wps_enabled = pathap .. "wps.admin_state"
        mapParams.frame_bursting = pathradio .. "frame_bursting"
  -- Bug fix for NG-12032 GUI wireless enable/disable not working properly
    for k, v in pairs(radios) do
      if v~=curradio then
        mapParams["admin_state_" .. v] = "rpc.wireless.radio.@" .. v .. ".admin_state"
      end
    end
	else
		mapParams.ap_enabled = pathap .. "admin_state"
  end

  -- Only include radius configuration in UI if not in guest/hotspot mode or not remotely managed
  -- Only include SGI, CDD, and STBC if not guest/hotspot or not remotely managed

  if isguest ~= "1" and isExtRemman ~= "1" and isIntRemman ~= "1" and not stbLimit then
    if radius_authent then
      mapParams.radius_authent_state = pathradius .. "auth0.state"
      mapParams.radius_authent_ip = pathradius .. "auth0.ip"
      mapParams.radius_authent_port = pathradius .. "auth0.port"
      mapParams.radius_authent_secret = pathradius .. "auth0.secret"
    end
    if radius_account then
      mapParams.radius_account_state = pathradius .. "acct0.state"
      mapParams.radius_account_ip = pathradius .. "acct0.ip"
      mapParams.radius_account_port = pathradius .. "acct0.port"
      mapParams.radius_account_secret = pathradius .. "acct0.secret"
    end
    -- validation check on cdd with default value 'auto' would fail in guest page
    -- just ignore these parameters since they are not shown in guest page
    if isguest ~= "1" then
      mapParams.sgi = pathradio .. "sgi"
      mapParams.cdd = pathradio .. "cdd"
      mapParams.stbc = pathradio .. "stbc"
    end
  end

  if bspeerap then
    local bandsteerParams = {
      bsid = pap .. "@" .. curap .. ".bandsteer_id",
      bspeerid = pap .. "@" .. bspeerap .. ".bandsteer_id",
    }

    if isBaseIface(curiface) then
      if bandsteeriface then
        local bandsteerAddParams = {
          bspifacessid = piface .. "@" .. bandsteeriface .. ".ssid",
          bspeer_security_mode = pap .. "@" .. bspeerap .. ".security_mode",
          bspeer_wpa_psk_key = pap .. "@" .. bspeerap .. ".wpa_psk_key", }
        for k,v in pairs(bandsteerAddParams) do
          bandsteerParams[k] = v
        end
      end
    end

    for k,v in pairs(bandsteerParams) do
      mapParams[k] = v
    end
  end

  local mapValid = {
    interface_enabled = vB,
    standard = gVIES(wifi_standard),
    sgi = gOV(vB),
    cdd = gVIES(cddList),
    stbc = gOV(vB),
    outputpower = gVIES(wifipower), -- if the parameter is not included, it does not matter, this validation function will never be called
    channelwidth20 = getValidateChannelWidth(cw_40),
    channelwidth40 = getValidateChannelWidth(cw_40),
    channelwidth80 = getValidateChannelWidth(cw_80),
    ap_enabled = vB,
    security = gVIES(secmodes),
    ssid = gAV(gVSLIR(1,32),getValidateExtraSpaces),
    wep_key = gVIPIL(vWEP,"security", {"wep"}),
    wpa_psk = gVIPIL(vPSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"}),
    wps_enabled = gOV(vB),
    acl_mode = gVIES(acl_modes),
    radius_authent_ip = VIPIL_IP,
    radius_account_ip = gOV(VIPIL_IP),
    radius_authent_secret = gVIPIL(vNES,"security", wpa_list),
    radius_account_secret = gVIPIL(vNES,"security", wpa_list),
    radius_authent_port = VIPIL_port,
    radius_account_port = gOV(VIPIL_port),
    radius_authent_state = gCV(radiusCond, getReplaceValue("1"), getReplaceValue("0")), -- we know that we're enforcing the server ip and port is there
    radius_account_state = gCV(gAV(radiusCond, checkIPandPort), getReplaceValue("1"), getReplaceValue("0")), -- if no server ip or port, don't set to 1
    wps_button_handler = post_helper.getValidateInEnumSelect(wps_button_mode),
    bsid = getValidateBandSteerPeerFields,
    frame_bursting = vB,
    ap_broadcast_ssid = vB,
    requested_channel = gVIES(allowed_channels),
    admin_state = vB,
    rssi_threshold = gVIES(bandsteer_rssi_threshold),
    rssi_5g_threshold = gVIES(bandsteer_rssi_threshold),
  }

	if isguest ~= "1" then
		mapValid.admin_state = validateRadioandAp
	end
   -- Bug fix for NG-12032 GUI wireless enable/disable not working properly
  for k, v in pairs(radios) do
    if v~=curradio then
      mapValid["admin_state_" .. v] = getInterfaceEnabled2
    end
  end

  return mapParams, mapValid
end

local bandsteerhelpmsg = {}
local content_rssi = {}
local mapParams, mapValid = getParamsAndValidation()
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "bs_check" then
    local postargs = ngx.req.get_post_args()
	if content["ssid"] ~= postargs.ssidName or content["security"] ~= postargs.security or content["wep_key"] ~= postargs.wep_key or content["wpa_psk"] ~= postargs.wpa_psk then
	session:store("bs_check_action", "TRUE")
    proxy.set("uci.wireless.wifi-ap.@ap0.bandsteer_id", "off")
	proxy.set("uci.wireless.wifi-ap.@ap1.bandsteer_id", "off")
	proxy.apply()
	end
	ngx.print('{ "success":"true" }')
	ngx.exit(ngx.HTTP_OK)
end

-- Process POST query
if ngx.req.get_method() == "POST" then
  local tmpbandsteerhelpmsg = {}
  for k,v in pairs(helpmsg) do
    if k == "bsid" then
      tmpbandsteerhelpmsg["content"] = v
      tmpbandsteerhelpmsg["level"] = "error"
    end
  end

  if not next(tmpbandsteerhelpmsg) then
    bandsteerhelpmsg = nil
  else
    bandsteerhelpmsg[1] = tmpbandsteerhelpmsg
  end

  if content["action"] == "SAVE" then
    local retval = false
    local postargs = ngx.req.get_post_args()
    if postargs["rssi_threshold"] ~= nil then
      retval = proxy.set(format('%s@%s.rssi_threshold', bandsteerpath, content["bsid"]), format("%d", postargs["rssi_threshold"]))
    end
    if postargs["rssi_5g_threshold"] ~= nil then
      retval = proxy.set(format('%s@%s.rssi_5g_threshold', bandsteerpath, content["bsid"]), format("%d", postargs["rssi_5g_threshold"]))
    end
    if retval == true then
      proxy.apply()
    end
  end

  -- End of parameters saving / loading

  -- Support for device PIN code
  content["wps_device_pin_code"] = ""

-- triggered only on a POST with action set wps_device_pin_code (button next to field should trigger that)
    if #wls > 1 then
      for _,v in ipairs(wls) do
        if v.iface == curiface then
          v.ssid = content["ssid"]
        end
      end
    end
    local args = ngx.req.get_post_args()
    local action = args["action"]
    local pin = args["wps_device_pin_code"]
    if action == "wps_device_pin_code" and content["wps_enabled"] == "1" and isguest ~= 0 then
        local res, help = vPIN(pin)
        content["wps_device_pin_code"] = pin

        if res then
            proxy.set("rpc.wireless.ap.@" .. curap .. ".wps.enrollee_pin",pin)

        else
            helpmsg["wps_device_pin_code"] = help
        end
    end
  -- End of device PIN code support
  -- triggered only on a POST with action set wps_pbc
    if action == "wps_pbc" and content["wps_enabled"] == "1" and isguest ~= 0 then
        proxy.set("rpc.wireless.wps_button","1")
    end
  -- End of WPS PBC code support
end
  -- AP PIN code and Mac - read only
  -- "rpc.wireless.ssid.@wl0." and "rpc.wireless.ssid.@wl1." returns empty during hostapd reload is in progress,
  -- so introduce delay to hold the save operation until gets valid data from datamodel and also introduce timeout (1 minute max)
  -- to break this loop
  local content_ssid = {
         pathiface .. "mac_address",
         pathiface .. "stb",
         pathiface .. "ap_display_name",
         pathap .. "wps.ap_pin",
         pathap .. "wps.ap_setup_locked"
  }
  local step = 2
  for i=0, 60, step do
     ngx.sleep(step)
     local content_val = proxy.get(unpack(content_ssid))
     if (content_val and #content_val > 0) then
        content["macaddress"] = content_val[1].value
        content["stb"] = content_val[2].value
        content["ap_display_name"] = content_val[3].value
        content["wps_ap_pin_code"] = content_val[4].value
        content["wps_ap_setup_locked"] = content_val[5].value
        break
     end
  end

param = {
    allowed_channels = pathradio .. "allowed_channels"
}
content_helper.getExactContent(param)
allowed_channels = { {"auto", T"Auto"} }
for i in string.gmatch(param["allowed_channels"], "%S+") do
    allowed_channels[#allowed_channels + 1] = {i, i}
end

local radion_data=proxy.get(pathradio)
for _, v in pairs(radion_data) do
    if not content[v.param] then
        content[v.param]=v.value
    end
end

-- Ensure Channel and Current channel are the same value after clicking Save
if content["requested_channel"] ~= nil and content["channel"] ~= nil and content["requested_channel"] ~= "auto" then
    content["channel"] = content["requested_channel"]
end

local band_steer_supported = 0
local bs_peer_network_enable = "0"
local band_steer_enabled = "0"

if "" ~= bandsteerpathap then
    --Need to consider the constraint
    local content_band_steer = {
        band_steer_id = "uci.wireless.wifi-ap.@".. curap .. ".bandsteer_id",
        band_steer_ap_enabled = bandsteerpathap .. "admin_state",
    }
    content_helper.getExactContent(content_band_steer)
    --To get the content_band_steer value
    if "" ~= content_band_steer.band_steer_id then
        band_steer_supported = 1
        if "off" ~= content_band_steer.band_steer_id then
            band_steer_enabled = "1"
        end
    end

    bs_peer_network_enable = content_band_steer.band_steer_ap_enabled

    if "1" == bs_peer_network_enable and 1 == band_steer_supported then
        local bsid = bandsteer_helper.getBandSteerId(curiface)
        content_rssi = {
            rssi_threshold = bandsteerpath .. "@" .. bsid .. ".rssi_threshold",
            rssi_5g_threshold = bandsteerpath .. "@" .. bsid .. ".rssi_5g_threshold"
       }
    end
    content_helper.getExactContent(content_rssi)
end

ngx.print(ui_helper.createHeader(T"Wireless", true, false))   ngx.print('\
\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-wireless.lp")
  ngx.print('\
<form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
');  
-- Do not display the navlist on the list if only 1 SSID
if #wls > 1 then
  ngx.print('\
<div class="span2">\
    <ul class="nav nav-list">\
    ');  
   local html = {}
    local prevradio = ""
    for i,v in ipairs(wls) do
        if v.radio ~= prevradio then
            if radioData[untaint(v.radio)].remotely_managed == "1" and radioData[untaint(v.radio)].integrated_ap ~= "1" then
                html[#html+1] = format('<li class="nav-header">%s %s</li>', T"External access points", radioData[untaint(v.radio)].supported_frequency_bands)
            else
                html[#html+1] = format('<li class="nav-header">%s %s</li>', T"Access points", radioData[untaint(v.radio)].supported_frequency_bands)
            end
            prevradio = v.radio
        end
        local active = ""
        if v.iface == curiface and getWifiAnalyzer == nil then
            active = "active"
        end
        local url = "modals/wireless-modal.lp?radio=" .. v.radio .. "&iface=" .. v.iface
        -- Do not display stb ssid
        if v.ap_display_name ~= nil and v.ap_display_name ~= "" then
            html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, v.ap_display_name)
        elseif v.stb == "1" then
            html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, "IPTV")
        else
            html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, v.ssid)
        end
    end
    -- If wifi analyzer enabled, draw it
    local wifi_analyzer_disable = proxy.get("uci.wireless.wifi.@global.wifi_analyzer_disable")
    if wifi_analyzer_disable and wifi_analyzer_disable[1].value ~= "1" then
      html[#html+1] = string.format('<li class="nav-header">%s</li>', T"Wireless Data")
      local freq = "2.4"
      local isDuplicate = {}
      for i,v in ipairs(wls) do
        if not isDuplicate[v.radio] and (v.radio == "radio_5G" or v.radio == "radio_2G") then
          if v.radio == "radio_5G" then freq = "5" or "2.4" end
          local active = ""
          if getWifiAnalyzer == v.iface then
            active = "active"
            radio = v.radio
          end
          local url = "modals/wireless-modal.lp?radio=" .. v.radio .. "&isWifiAnalyzer=" .. v.iface
          html[#html+1] = format('<li class="%s"><a href="#" data-remote="%s" id ="wifianalyzer_%s">%s %sGHz</a></li>',active, url,freq,T"Analyzer",freq )
          local link_id = "2"
          if freq == "5" then link_id = "5" end
          html[#html + 1] = format([[
             <div><div id = linkconfirming-msg_%s class= "alert hide"> %s </div> ]],
             link_id,T"Warning: starting the Wireless Analyzer will disconnect all wireless clients until the analysis has been completed.")
          html[#html + 1] = format([[
             <div id="linkrescan-changes_%s" class="hide">
             <div id="linkrescan-cancel_%s" class="btn">%s</div>
             <div id="linkrescan-confirm_%s" onclick='$(".modal-backdrop").remove();' class="btn btn-primary" data-toggle="modal", data-remote="%s">%s</div>
             </div></div>
             ]],
             link_id,link_id,T"Cancel",link_id,url,T"Accept")
        end
        isDuplicate[v.radio] = true
      end
    end
    if session:hasAccess("/modals/wireless-client-modal.lp") then
      html[#html+1] = format("<li><a href=\"#\" <a href=\"#\" data-remote=\"modals/wireless-client-modal.lp\" >%s</a></li>", T"Client Monitoring" )
    end
    ngx.print(html)
      ngx.print('\
    </ul>\
</div>\
<div class="span6">\
');  
end

local current_acl_mode = content["acl_mode"]
if getWifiAnalyzer == nil then  ngx.print('\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
if bandsteerhelpmsg then ngx.print(ui_helper.createMessages(bandsteerhelpmsg)) end
  ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"Interface" ); ngx.print('</legend>\
\
');
    local html = {}
    local advanced = {
        group = {
            class = "advanced hide",
        }
    }
	local labelstate = T"Off"
		if content["admin_state"] == "1" then
			labelstate = T"On"
		end
    -- In guest page, do not let the user change the configuration of the wifi radio. Only in main AP
    if isguest == "1" then
        local guest_alert = {
            alert = {
                class = "alert-info"
            },
        }
        -- Display infomation indicating it is a guest SSID
		
        --html[#html + 1] = ui_helper.createAlertBlock(T"This is a guest network. The guest network has no local network access.", guest_alert)
		html[#html + 1] = ui_helper.createLabel(T"Radio", labelstate)

        -- Switch that shows if the Wifi interface is enabled or not
        html[#html + 1] = ui_helper.createLabel(T"Frequency band", content["supported_frequency_bands"])
        -- Label that shows the MAC address of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"MAC address", content["macaddress"])
    if radioData[curradio].supported_frequency_bands == "5GHz" then
      html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, wifiStandard.standard), advanced)
    else
      html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, content["standard"]), advanced)
    end
        -- Current speed of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps", { span = {
            id = "phy_rate",
            ["data-ajaxrefresh"] = "5",
        }})

        html[#html + 1] = ui_helper.createLabel(T"Channel", content["requested_channel"])

        -- Show which region is being used
        html[#html + 1] = ui_helper.createLabel(T"Region", content["country"], advanced)
        html[#html + 1] = ui_helper.createLabel(T"Current channel", content["channel"], { span = {
            id = "channel",
            ["data-ajaxrefresh"] = "10",
        }})

        html[#html + 1] = ui_helper.createLabel(T"Channel width", listboxToText(channelwidth, content["requested_channel_width"]), advanced)
    else
        -- Switch that shows if the Wifi interface is enabled or not
        --[[if not stbLimit then
            html[#html + 1] = ui_helper.createSwitch(T"Enabled", "admin_state", content["admin_state"])
        end]]
		html[#html + 1] = ui_helper.createLabel(T"Radio", labelstate)
        html[#html + 1] = ui_helper.createLabel(T"Frequency band", content["supported_frequency_bands"])
        -- Label that shows the MAC address of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"MAC address", content["macaddress"])

        -- Select the standard to use
        local stdattributes = {
            group = {
                class = "advanced hide",
            },
            select = {
                class = "monitor-changes"
            }
        }
   if radioData[curradio].supported_frequency_bands == "5GHz" then
     html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, wifiStandard.standard), stdattributes)
     stdattributes.select={class = "monitor-changes",style="display:none"}
     html[#html + 1] = ui_helper.createSimpleInputSelect("standard", wifi_standard, wifiStandard.standard,stdattributes)
   else
    if not stbLimit then
        html[#html + 1] = ui_helper.createInputSelect(T"Standard", "standard", wifi_standard, content["standard"], stdattributes)
    else
        html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, content["standard"]), stdattributes)
    end
   end

        -- Current speed of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps", { span = {
            id = "phy_rate",
            ["data-ajaxrefresh"] = "5",
        }})

        -- Choose which channel to use
        if not stbLimit then
            html[#html + 1] = ui_helper.createInputSelect(T"Channel", "requested_channel", allowed_channels, content["requested_channel"])
        end

        -- Show which region is being used
        html[#html + 1] = ui_helper.createLabel(T"Region", content["country"], advanced)
        html[#html + 1] = ui_helper.createLabel(T"Current channel", content["channel"], { span = {
            id = "channel",
            ["data-ajaxrefresh"] = "5",
        }})
        if not stbLimit then
            html[#html + 1] ='<div class ="advanced hide">'
            local cw20attributes  = {
                group = {
                    class ="hide monitor-standard monitor-b monitor-bg",
                },
            }

            html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth20", cw_40, content["requested_channel_width"], cw20attributes)

            local cw40attributes  = {
                group = {
                    class ="hide monitor-standard monitor-bgn monitor-an",
                },

            }

            html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth40", cw_40, content["requested_channel_width"], cw40attributes)

            local cw80attributes  = {
                group = {
                    class ="hide monitor-standard monitor-anac",
                },
            }

            html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth80", cw_80, content["requested_channel_width"], cw80attributes)
            html[#html + 1] = '</div>'

            if isExtRemman ~= "1" and isIntRemman ~= "1" then
                html[#html + 1] = ui_helper.createSwitch(T"Short Guard Interval", "sgi", content["sgi"], advanced)
                html[#html + 1] = ui_helper.createInputSelect(T"Cyclic-Delay Diversity", "cdd", cddList, content["cdd"], advanced)
                html[#html + 1] = ui_helper.createSwitch(T"Space Time Block Code", "stbc", content["stbc"], advanced)
                html[#html + 1] = ui_helper.createSwitch(T"Frame Bursting", "frame_bursting", content["frame_bursting"], advanced)
            end
        end
    end
    ngx.print(html)
  ngx.print('\
</fieldset>\
\
');  
    html = {}

    if not stbLimit then
        html[#html + 1] = "<fieldset>"
    else
        html[#html + 1] = "<fieldset class=\"advanced hide\">"
    end
    html[#html + 1] = "<legend>"
    html[#html + 1] = T"Access Point"
    html[#html + 1] = [[</legend>]]

    -- Show if the AP is enabled
    if isguest == "1" then
		if content["admin_state"] == "0" then
		html[#html + 1] = ui_helper.createAlertBlock(string.format("%s",T"WARNING: If you would like to connect to the GuestSSID, please activate your Main SSID"),SUB_PF_CSS)
		else
		html[#html + 1] = ui_helper.createSwitch(T"Enabled", "ap_enabled", content["ap_enabled"])
		end
	else
		html[#html + 1] = ui_helper.createSwitch(T"Enabled", "admin_state", content["admin_state"])
	end

    if not stbLimit then
        -- Show the SSID
        local ssidclass = {
            input = {
                pattern= "[!-~][ -~]{0,30}[!-~]",
                maxlength= "32",
                class= "span4",
                }
        }

        html[#html + 1] = ui_helper.createInputText(T"Network Name (SSID)", "ssid", content["ssid"], ssidclass, helpmsg["ssid"])

        local broadcastclass = {
            group = {
                class = "advanced hide",
            },
            input = {
                class = "monitor-changes"
            }
        }

        -- Should we broadcast the SSID
        html[#html + 1] = ui_helper.createSwitch(T"Broadcast SSID", "ap_broadcast_ssid", content["ap_broadcast_ssid"], broadcastclass)

        -- Select the security mode to use
        local secattributes = {
            group = {
                class = "",
            },
            select = {
                class = "monitor-changes"
            }
        }

        local security_warning = {
            alert = {
                class = "alert-error monitor-security monitor-none"
            },
        }
        html[#html + 1] = ui_helper.createAlertBlock(T"Security for this wireless network is disabled, anybody can connect or listen to it", security_warning)

        local wep_warning = {
            alert = {
                class = "alert-error monitor-security monitor-wep"
            },
        }
        html[#html + 1] = ui_helper.createAlertBlock(T"WEP is known to be flawed as a wireless security mode, usage of a more secure mode based on WPA2 is recommended.",wep_warning)

        html[#html + 1] = ui_helper.createInputSelect(T"Security Mode", "security", secmodes, content["security"], secattributes)

    local pskclass = {
        group = {
            class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk",
        },
        input = {
            class= "span4",
        }
    }

    local wepclass = {
        group = {
            class ="monitor-security monitor-wep",
        },
        input = {
            class= "span4",
        }
    }

    html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa_psk", content["wpa_psk"], pskclass, helpmsg["wpa_psk"])
    html[#html + 1] = ui_helper.createInputText(T"WEP Key", "wep_key", content["wep_key"], wepclass, helpmsg["wep_key"])

    if ( isguest ~= "1" and isExtRemman  ~= "1" and isIntRemman ~= "1") then
        local monitorradius = {
                class ="monitor-security monitor-wpa monitor-wpa2 monitor-wpa-wpa2",
        }
        local ipclass = {
          pattern="^(((([1]?\\d)?\\d|2[0-4]\\d|25[0-5])\\.){3}(([1]?\\d)?\\d|2[0-4]\\d|25[0-5]))|([\\da-fA-F]{1,4}(\\:[\\da-fA-F]{1,4}){7})|(([\\da-fA-F]{1,4}:){0,5}::([\\da-fA-F]{1,4}:){0,5}[\\da-fA-F]{1,4})$"
        }
        local serverclass = {
            group = monitorradius,
            input = ipclass
        }
        local basicclass = {
            group = monitorradius,
        }
        if "1" == band_steer_enabled and not isBaseIface(curiface) then
            if "wpa" == content["security"] or "wpa2" == content["security"] or "wpa-wpa2" == content["security"] then
                if radius_authent then
                    html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server IP", "radius_authent_ip", content["radius_authent_ip"], serverclass, helpmsg["radius_authent_ip"])
                    html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server port", "radius_authent_port", content["radius_authent_port"],basicclass, helpmsg["radius_authent_port"])
                    html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server secret", "radius_authent_secret", content["radius_authent_secret"],basicclass, helpmsg["radius_authent_secret"])
                end
                if radius_account then
                    html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server IP", "radius_account_ip", content["radius_account_ip"], serverclass, helpmsg["radius_account_ip"])
                    html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server port", "radius_account_port", content["radius_account_port"],basicclass, helpmsg["radius_account_port"])
                    html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server secret", "radius_account_secret", content["radius_account_secret"],basicclass, helpmsg["radius_account_secret"])
                end
            end
        else
            if radius_authent then
                html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server IP", "radius_authent_ip", content["radius_authent_ip"], serverclass, helpmsg["radius_authent_ip"])
                html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server port", "radius_authent_port", content["radius_authent_port"],basicclass, helpmsg["radius_authent_port"])
                html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server secret", "radius_authent_secret", content["radius_authent_secret"],basicclass, helpmsg["radius_authent_secret"])
            end
            if radius_account then
                html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server IP", "radius_account_ip", content["radius_account_ip"], serverclass, helpmsg["radius_account_ip"])
                html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server port", "radius_account_port", content["radius_account_port"],basicclass, helpmsg["radius_account_port"])
                html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server secret", "radius_account_secret", content["radius_account_secret"],basicclass, helpmsg["radius_account_secret"])
            end
    	end
    end

--Don't show wps for Guest

if isguest ~= "1"  then

    local wps_warning = {
        alert = {
            class = "alert-warning monitor-security monitor-wep monitor-wpa-psk monitor-ap_broadcast_ssid monitor-0 monitor-default-show"
        },
    }

    html[#html + 1] = ui_helper.createAlertBlock(T"WPS is automatically disabled if you choose WEP or disable broadcast of the SSID", wps_warning)

    local wps_class = {
        group = {
            class = "monitor-security monitor-none monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-ap_broadcast_ssid monitor-1"
        }
    }
    html[#html + 1] = ui_helper.createSwitch(T"WPS", "wps_enabled", content["wps_enabled"], wps_class)
    if (tonumber(content["wps_ap_setup_locked"]) == 1) then
        content["wps_ap_pin_code"] = T"Disabled"
    end
    --html[#html + 1] = ui_helper.createLabel(T"WPS AP PIN code", content["wps_ap_pin_code"], wps_class)

    wps_class["input"] = {
        class="no-save",
        ["data-for"] = "wps_device_pin_code",
    }
    wps_class["button"] = {
        ["data-name"] = "action",
        ["data-value"] = "wps_device_pin_code",
    }
    html[#html + 1] = ui_helper.createInputTextWithButton(T"WPS Device PIN code", "wps_device_pin_code", content["wps_device_pin_code"], T"Set PIN code", "icon-ok-sign" ,wps_class, helpmsg["wps_device_pin_code"])

    wps_class["button"] = {
        ["data-name"] = "action",
        ["data-value"] = "wps_pbc",
    }
    if radioData[curradio].remotely_managed ~= "1" or radioData[curradio].integrated_ap == "1"  then
     html[#html + 1] = ui_helper.createButton(T"WPS PBC", T"Trigger", "icon-refresh", wps_class)
	 html[#html + 1] = ui_helper.createInputRadio(T"WPS Buttom Mode", "wps_button_handler" , wps_button_mode , content["wps_button_handler"] , nil)
    end
end
   if 1 == band_steer_supported then
        local bssecclass = {
            group = {
                class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-none",
            },
        }

        if isBaseIface(curiface) then
            html[#html + 1] = ui_helper.createAlertBlock(T"Detecting a Wi-Fi client's capabilities and monitoring its interfaces, Band Steering actively guides the client to the more suitable Wi-Fi band.", bssecclass)
            html[#html + 1] = ui_helper.createSwitch(T"Band Steering Enabled", "band_steer_enabled", tostring(band_steer_enabled), bssecclass)
            html[#html + 1] = ui_helper.createAlertBlock(T"Band Steering works only if 2.4 GHz and 5 GHz have the same configuration. By enabling the Band Steering, the 2.4 GHz network settings will be propagated on 5GHz settings", bssecclass)
            html[#html + 1] = ui_helper.createSliderSelect(T"2.4GHz Band Steering Threshold", "rssi_threshold", bandsteer_rssi_threshold, content_rssi["rssi_threshold"], bssecclass)
            html[#html + 1] = ui_helper.createAlertBlock(T"If a wireless device reports this gateway's 2.4GHz signal strength is above this threshold, the gateway will ask the device to test the 5GHz band . Please see 5GHz section for additional parameter.", bssecclass)
        else
            html[#html + 1] = ui_helper.createAlertBlock(T"Detecting a Wi-Fi client's capabilities and monitoring its interfaces, Band Steering actively guides the client to the more suitable Wi-Fi band.", ssidclass)
            html[#html + 1] = ui_helper.createLabel(T"Band Steering Enabled", tostring(band_steer_enabled) == "1" and "On" or "Off", ssidclass)
            html[#html + 1] = ui_helper.createAlertBlock(T"Band Steering works only if 2.4 GHz and 5 GHz have the same configuration. By enabling the Band Steering, the 2.4 GHz network settings will be propagated on 5GHz settings", bssecclass)
            html[#html + 1] = ui_helper.createSliderSelect(T"5GHz Band Steering Threshold", "rssi_5g_threshold", bandsteer_rssi_threshold, content_rssi["rssi_5g_threshold"], ssidclass)
            html[#html + 1] = ui_helper.createAlertBlock(T"Please see 2.4GHz section for initial parameter. If a wireless device tests the 5GHz band and reports the 5GHz signal strength is above this threshold, the gateway will direct the device to switch to the 5GHz band.", bssecclass)
        end
    end
end
    ngx.print(html)
  ngx.print('\
    <input type="hidden" name="radius_authent_state" value="" >\
    <input type="hidden" name="radius_account_state" value="" >\
\
\
</fieldset>\
\
        ');  
        if not stbLimit then
            html = {}
            html[#html + 1] = "<fieldset class=\"advanced hide\">"
            html[#html + 1] = "<legend>"
            html[#html + 1] = T"Access Control List"
            html[#html + 1] = [[</legend>]]
            local aclmodeclass = {
                select = {
                  class = "monitor-changes",
                  id="aclmode"
                }
            }

            local isTableLoaded =  false
            if ngx.req.get_method() == "POST" and  ngx.req.get_post_args().action ~="nil" and string.find(ngx.req.get_post_args().action, "TABLE") ~= nil then
                local tableid = ngx.req.get_post_args().tableid
                if tableid == "acl_whitelist" then
                    content["acl_mode"] = "lock"
                elseif tableid == "acl_blacklist" then
                    content["acl_mode"] = "unlock"
                elseif tableid == "acl_register" then
                    content["acl_mode"] = "register"
                end
                    html[#html + 1] = ui_helper.createInputSelect(T"ACL Mode", "acl_mode", acl_modes, content["acl_mode"], aclmodeclass)
                    html[#html + 1] = loadAclList(content["acl_mode"], "POST")
                    isTableLoaded =  true
            else
              html[#html + 1] = ui_helper.createInputSelect(T"ACL Mode", "acl_mode", acl_modes, content["acl_mode"], aclmodeclass)
              local acl_attribute = {
                label = {
                  class = "monitor-acl_mode monitor-register"
                },
                button = {
                  class = "monitor-acl_mode monitor-register",
                  id = "btn_acl"
                }
              }
                  html[#html + 1] = ui_helper.createButton(T"ACL Reg",T"Register", nil, acl_attribute)
                  html[#html + 1] = "<div id=\"acl_list_div\" class=\"monitor-acl_mode monitor-lock monitor-register monitor-unlock\"><img src=\"/img/loading.gif\"/></div>"
            end
            html[#html + 1] = [[</fieldset>]]
            ngx.print(html)
        end
        ngx.print('\
\
<fieldset>\
');  if content["security"] ~= "wpa-wpa2" and content["security"] ~= "wpa2" then   ngx.print('\
<legend>');  ngx.print( T"QR Code" ); ngx.print('</legend>\
');  ngx.print( format([[
                    <center>
                        <div onclick="$('.modal-backdrop').remove();" class="btn custom-handler" data-remote="modals/wireless-qrcode-modal.lp?iface=%s&ap=%s" data-toggle="modal">
                            %s
                        </div>
                    </center>&nbsp
                 ]], curiface, curap, T"Generate QR code")
); ngx.print('\
');  end  ngx.print('\
</fieldset>\
');  
else
  --wifi analyzer handler
  local uri = ngx.var.uri
  if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
  end
  ngx.print('\
<form id="wifiForm" class="form-horizontal" method="post" action="');  ngx.print(uri); ngx.print('">\
');  if radio == "radio_2G" then   ngx.print('\
\
<div class="span6">\
\
');  else   ngx.print('\
\
<div class="span6" style="margin-left:0;">\
\
');  end   ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"Wifi Analyzer" ); ngx.print('</legend>\
<div style = "display:block;" class = "alert-info hide">');  ngx.print(T"Press Rescan button to view the updated WiFi Network list"); ngx.print('</div></br>\
<div id ="analyzerloader" style="height:100px"><img src = "/img/loading.gif"></img></div>\
<div id = "analyzerGraph" class="hide">\
');  ngx.print( T"The below chart shows the results of the latest scan of your local area from your gateway." ); ngx.print('\
');  if radio == "radio_2G" then   ngx.print('\
<canvas id="wrapper" width="720px" height="400px" style="border:1px solid #c3c3c3;">\
');  else   ngx.print('\
<canvas id="wrapper" width="890px" height="400px" style="border:1px solid #c3c3c3;">\
');  end   ngx.print('\
');  ngx.print( T"Please update your browser to use this page." ); ngx.print('\
</canvas>\
\
');  
    html = {}

    local freq = "2"
    if radio == "radio_5G" then freq = "5" or "2" end
    html[#html + 1] = format([[
      <div id="ReScan_%s" style="width:650px;text-align:right;margin-right:20px;"><div class="btn btn-primary btn-large">%s</div></div>]],
      freq,T"Re-scan")

    html[#html + 1] = format([[
      <div id = confirming-msg_%s class= "alert hide"> %s </div> ]],
      freq,T"Warning: starting the Wireless Analyzer will disconnect all wireless clients until the analysis has been completed.")
    html[#html + 1] = format([[
      <div id="rescan-changes_%s" class="hide">
      <div id="rescan-cancel_%s" class="btn">%s</div>
      <div id="rescan-confirm_%s" class="btn btn-primary" data-dimiss="modal">%s</div></div>]],
      freq,freq,T"Cancel",freq,T"Accept")
    ngx.print(html)
  ngx.print('\
\
\
</div>\
<div id="key" style="width: 700px;"></div>\
<div id ="analyzerloader1" style="height:100px"><img src = "/img/loading.gif"></img></div>\
</fieldset>\
</div>\
</form>\
\
<script language ="javascript">\
\
function get_random_color() {\
  var letters = \'0123456789ABCDEF\'.split(\'\');\
  var color = \'#\';\
  for (var i = 0; i < 6; i++ ) {\
    color += letters[Math.round(Math.random() * 15)];\
  }\
   return color;\
}\
  function get_y_from_sig(max, min, range, sig) {\
    return ((sig-max)/((min-max)/range))+30;\
  }\
  function get_curve_y_from_sig(max, min, range, sig) {\
      var line = 350 - get_y_from_sig(max, min, range, sig);\
      var line = 350 - (line *2);\
    return line;\
  }\
    var maximum= -20;\
    var minimum= -105;\
    var range = 320;\
    var bittarget40 = 10;\
    var bittarget80 = 16;\
    var ctx\
  function initializeAnalyzer() {\
    var c=document.getElementById("wrapper");\
    ctx=c.getContext("2d");\
    ctx.lineStyle="#FF0000";\
\
    //Y Axis\
    ctx.moveTo(30,30);\
    ctx.lineTo(30,350);\
    ctx.stroke();\
\
    //Power Marks\
    //30\
    var line10 = get_y_from_sig(maximum, minimum, range, -10);\
\
    ctx.moveTo(30,line10);\
    ctx.lineTo(25,line10);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("-10",7,line10 + 3);\
\
    var line30 = get_y_from_sig(maximum, minimum, range, -30);\
\
    ctx.moveTo(30,line30);\
    ctx.lineTo(25,line30);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("-30",7,line30 + 3);\
\
    //60\
    var line60 = get_y_from_sig(maximum, minimum, range, -60);\
\
    ctx.moveTo(30,line60);\
    ctx.lineTo(25,line60);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("-60",7,line60 + 3);\
\
     //90\
    var line90 = get_y_from_sig(maximum, minimum, range, -90);\
\
    ctx.moveTo(30,line90);\
    ctx.lineTo(25,line90);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("-90",7,line90 + 3);\
\
    //X Axis\
    ctx.moveTo(30,350);\
    ');  if radio == "radio_2G" then   ngx.print('\
    ctx.lineTo(690,350);\
    ');  else   ngx.print('\
    ctx.lineTo(870,350);\
    ');  end   ngx.print('\
    ctx.stroke();\
    //Titles\
    ctx.font="9px Arial";\
    ctx.fillText("Channel",310,390);\
    ctx.save();\
    ctx.translate(0, 0);\
    //ctx.rotate(Math.PI/2);\
    ctx.textAlign = "center";\
    ctx.fillText("Signal Strength (-dBm)", 60, 25);\
    ctx.restore();\
    ');  if radio == "radio_2G" then   ngx.print('\
    //Channel Marks\
    ctx.moveTo(120,350);\
    ctx.lineTo(120,355);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("1",117,370);\
    ctx.moveTo(320,350);\
    ctx.lineTo(320,355);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("6",317,370);\
    ctx.moveTo(520,350);\
    ctx.lineTo(520,355);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("11",517,370);\
    ');  else  ngx.print('\
    //Channel Marks\
    var chn_diff = 30;\
    var chnl = 0;\
    for (i = 0; i <= 7; i++) {\
         ctx.moveTo(60+(chn_diff*i),350);\
         ctx.lineTo(60+(chn_diff*i),355);\
         ctx.stroke();\
         ctx.font="9px Arial";\
         chnl = 36+(i*4);\
         ctx.fillText(chnl.toString(),60+(chn_diff*i)-4,370);\
    }\
\
    for (i = 10; i <= 27; i++) {\
         ctx.moveTo(60+(chn_diff*i),350);\
         ctx.lineTo(60+(chn_diff*i),355);\
         ctx.stroke();\
         ctx.font="9px Arial";\
         chnl = 60+(i*4);\
         ctx.fillText(chnl.toString(),60+(chn_diff*i)-6,370);\
    }\
\
    ');  end  ngx.print('\
    var color = parseInt("00000F", 16);\
    // analyzer table header\
    $("#key").empty().append(\
      $("<br/>"),\
      $("<div>").addClass("col_ssid").text("');  ngx.print( T'Network Name (SSID)'); ngx.print('"),\
      $("<div>").addClass("col_channel").text("');  ngx.print( T'Channel' ); ngx.print('"),\
      $("<div>").addClass("col_str").text("');  ngx.print( T'40MHz'); ngx.print('"),\
      ');  if radio ~= "radio_2G" then   ngx.print('\
        $("<div>").addClass("col_str").text("');  ngx.print( T'80MHz'); ngx.print('"),\
      ');  end   ngx.print('\
      $("<div>").addClass("col_rssi").text("');  ngx.print( T'Signal Strength (RSSI)'); ngx.print('"),\
      $("<br/>")\
    );\
  }\
  function generateGraph(ssid,channel,rssi,cap){\
    color =  get_random_color();\
    var Mhz = 1;\
    var Str = "";\
    var cap = parseInt(cap,16).toString(2);\
\
    /*if(cap.indexOf("40MHz")!=-1)\
    {\
      Mhz = 2;\
      Str = "*"\
    }\
    */\
    while (cap.length <= 16)\
      {\
       cap = "0"+cap;\
      }\
\
   if (cap.charAt(cap.length-bittarget40) == "1") {\
       Mhz = 2;\
       Str = \'*\';\
    }\
    ');  if radio == "radio_2G" then   ngx.print('\
    //2.4GHz\
    var xcoord = 80+(channel*40);\
    var sig = rssi;\
    if (sig > maximum){sig = maximum }else if (sig < minimum){sig = minimum}\
    ctx.beginPath();\
\
    color =  get_random_color();\
    ctx.strokeStyle = color;\
\
      ctx.moveTo(xcoord-(80*Mhz), 350);\
      ctx.quadraticCurveTo(xcoord, get_curve_y_from_sig(maximum, minimum, range, sig), xcoord+(80*(Mhz)), 350);\
\
    ctx.stroke();\
     ');  else   ngx.print('\
     //5GH\
    var chlist40 = [38,46,54,62,102,110,118,126,134,142]\
    var chlist80 = [42,58,106,122,138]\
    var str40 = ""\
    var str80 = ""\
    for (i = 0; i <= chlist40.length; i++) {\
        if (chlist40[i] == channel){\
          str40 = "*";\
          Mhz = 2;\
        }\
    }\
    for (i = 0; i <= chlist80.length; i++) {\
        if (chlist80[i] == channel){\
          str80 = "*";\
          Mhz = 4;\
        }\
    }\
    var xcoord = 0\
    if  (channel <= 64) {\
       xcoord = 60+((channel-36)*7.5);\
    }else{\
       xcoord = 360+((channel-100)*7.5);\
    }\
\
    var sig = rssi;\
\
    if (sig > maximum){sig = maximum }else if (sig < minimum){sig = minimum}\
        ctx.beginPath();\
        color =  get_random_color();\
        ctx.strokeStyle = color;\
        ctx.moveTo(xcoord-(15*Mhz), 350);\
        ctx.quadraticCurveTo(xcoord, get_curve_y_from_sig(maximum, minimum, range, sig) , xcoord+(15*Mhz), 350);\
        ctx.stroke();\
     ');  end   ngx.print('\
\
     // A new row for analyzer table\
     var row = $("<div>").css("color", color);\
\
     // Append the row\
     $("#key").append(row);\
\
     // Add columns to the new row\
    $(row).append(\
      $("<div>").addClass("col_ssid").text(ssid),\
      $("<div>").addClass("col_channel").text(channel),\
      ');  if radio == "radio_2G" then   ngx.print('\
        $("<div>").addClass("col_str").text(Str),\
      ');  else  ngx.print('\
        $("<div>").addClass("col_str").text(str40),\
        $("<div>").addClass("col_str").text(str80),\
      ');  end  ngx.print('\
      $("<div>").addClass("col_rssi").text(rssi),\
      $("<br/>")\
    );\
  }\
\
  function show_rescanconfirming(freq,show){\
    var msg_id = "confirming-msg_" + freq;\
    var rescan_id = "rescan-changes_" + freq;\
    if (show == 1){\
      $("div[id^= "+ rescan_id +"]").show();\
      $("div[id^= "+ msg_id +"]").show();\
    }\
    else {\
      $("div[id^= "+ rescan_id +"]").hide();\
      $("div[id^= "+ msg_id +"]").hide();\
    }\
  }\
\
  $("div[id^=\'ReScan_\']").on("click", function() {\
    var freq = (this.id).split("_")[1];\
    show_rescanconfirming(freq,1);\
  });\
\
  $("div[id^=\'rescan-confirm_\']").on("click", function() {\
    var freq = (this.id).split("_")[1];\
    show_rescanconfirming(freq,0);\
  });\
\
  $("div[id^=\'rescan-cancel_\']").on("click", function() {\
    var freq = (this.id).split("_")[1];\
    show_rescanconfirming(freq,0);\
  });\
\
    $(document).ready(function(){\
      $("div[id^=\'rescan-confirm_\']").on("click",function(a) {\
        var freq = (this.id).split("_")[1];\
        show_rescanconfirming(freq,0);\
\
        var params = [];\
        params.push({\
          name : "action",\
          value : "rescan"\
        });\
        params.push({\
          name : "curradio",\
          value : "');  ngx.print(radio); ngx.print('"\
        });\
        params.push(tch.elementCSRFtoken());\
        tch.showProgress("');  ngx.print(T"Re-scanning"); ngx.print('...");\
        $.post("/modals/wireless-modal.lp", params, function(acsData){\
          tch.removeProgress();\
          initializeAnalyzer();\
          if ( acsData.length > 0 ) {\
            $.each(acsData, function(i, data){\
              generateGraph(data.ssid,data.channel,data.rssi,data.cap);\
            });\
          }\
        });\
      });\
      initializeAnalyzer();\
      $.get("/modals/wireless-modal.lp?isWifiAnalyzer=');  ngx.print(getWifiAnalyzer); ngx.print('&getAcsData=true&radio=');  ngx.print(radio); ngx.print('",function(acsData){\
         $("#analyzerloader").addClass("hide");\
         $("#analyzerGraph").removeClass("hide");\
         $("#analyzerloader1").addClass("hide");\
         $.each(acsData, function(i, data) {\
           generateGraph(data.ssid,data.channel,data.rssi,data.cap);\
         });\
       });\
    });\
</script>\
\
');  
--End of wifi analyzer
end  ngx.print('\
');  
-- Do not display the navlist on the list if only 1 SSID
if #wls > 1 then
  ngx.print('\
</div>\
');  
end
  ngx.print('\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
');  if not isTableLoaded then   ngx.print('\
    $.get("/modals/wireless-modal.lp?radio=');  ngx.print(curradio); ngx.print('&iface=');  ngx.print(curiface); ngx.print('&action=GET_ACL_MAC_LIST&acl_mode=');  ngx.print(content["acl_mode"]); ngx.print('", function (data){\
        $(\'#acl_list_div\').replaceWith(data);\
    });\
');  end  ngx.print('\
\
function show_linkconfirming(freq,show){\
  var msg_id = "linkconfirming-msg_" + freq;\
  var link_id = "linkrescan-changes_" + freq;\
\
  if (show == 1){\
    $("div[id = "+ link_id +"]").show();\
    $("div[id = "+ msg_id +"]").show();\
  }\
  else{\
    $("div[id = "+ link_id +"]").hide();\
    $("div[id = "+ msg_id +"]").hide();\
  }\
}\
\
$("a[id^=\'wifianalyzer_\']").on("click", function() {\
  var iface = (this.id).split("_")[1];\
  var freq = iface.split(".")[0];\
  show_linkconfirming(freq, 1);\
  return false;\
});\
\
$("div[id^=\'linkrescan-confirm_\']").on("click", function() {\
  var iface = (this.id).split("_")[1];\
  var freq = iface.split(".")[0];\
  show_linkconfirming(freq, 0);\
});\
\
$("div[id^=\'linkrescan-cancel_\']").on("click", function() {\
  var iface = (this.id).split("_")[1];\
  var freq = iface.split(".")[0];\
  show_linkconfirming(freq, 0);\
});\
\
$("#aclmode").on("change", function(){\
var aclmode = $(this).val();\
if(aclmode == "register"){\
    $("#acl_whitelist").attr("id","acl_register");\
}else{\
    $("#acl_register").attr("id","acl_whitelist");\
}\
});\
');  if current_acl_mode ~= content["acl_mode"] then  ngx.print('\
  $(\'#modal-no-change\').hide();\
  $(\'#modal-changes\').show();\
');  end  ngx.print('\
\
function get_status_acl() {\
   $("#btn_acl").attr(\'disabled\', true);\
   setTimeout(function(){\
   $.get("modals/wireless-modal.lp?action=get_reg_status&curap=');  ngx.print(curap); ngx.print('", function(res){\
     if (res != "register"){\
       get_status_acl();\
     }\
     else{\
       $("#btn_acl").removeAttr(\'disabled\', false);\
    }\
    $("#btn_acl").html(res);\
    });	},5000);\
}\
\
$("#btn_acl").on("click", function() {\
   if($("#btn_acl").attr("disabled")!= undefined ) return false;\
   $.post("modals/wireless-modal.lp",{ action: "set_reg", curap: "');  ngx.print(curap); ngx.print('", CSRFtoken: $("meta[name=CSRFtoken]").attr("content")},\
      get_status_acl);\
 });\
\
var bschecked = $(\'input[id="band_steer_enabled"]\').val();\
$(document).ready(function() {\
    if ("1" == bschecked) {\
        $(\'option[value="wep"]\').hide();\
        $(\'option[value="wpa-wpa2"]\').hide();\
        $(\'option[value="wpa2"]\').hide();\
        $(\'option[value="wpa"]\').hide();\
    }\
});\
\
$("#save-config").click(function(){\
	var params = [];\
	params.push({\
	name : "ssidName",\
	value : $("#ssid").val()\
	},{\
	name : "wep_key",\
	value : $("#wep_key").val()\
	},{\
	name : "wpa_psk",\
	value : $("#wpa_psk").val()\
	},{\
	name : "security",\
	value : $("#security").val()\
	},{\
	name : "CSRFtoken",\
	value :$("meta[name=CSRFtoken]").attr("content")\
	},{\
	name : "action",\
	value: "bs_check"\
	});\
	$.post("modals/wireless-modal.lp",params);\
});\
\
$(\'input[id="band_steer_enabled"]\').on("click", function(){\
    if ("1" == bschecked) {\
        $(\'option[value="wep"]\').hide();\
        $(\'option[value="wpa-wpa2"]\').hide();\
        $(\'option[value="wpa2"]\').hide();\
        $(\'option[value="wpa"]\').hide();\
    }\
});\
</script>\
'); 
