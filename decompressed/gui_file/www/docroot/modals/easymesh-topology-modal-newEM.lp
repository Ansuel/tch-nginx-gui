--pretranslated: do not change this file
local mesh = require("easymesh_helper")
if not mesh.is_supported() or not mesh.use_new_layout() then
  local ui = require("web.ui_helper")
  gettext.textdomain('webui-core')
  ngx.print(ui.createHeader(T"EasyMesh", false, true))
  ngx.print(ui.createAlert({class = "alert-warning"}, T"EasyMesh is not supported on this device."))
  ngx.print(ui.createFooter())
  return
end

-- Localization
gettext.textdomain('webui-core')
local table, string = table, string
local untaint, match, upper, gsub, lower = string.untaint, string.match, string.upper, string.gsub, string.lower
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local format = string.format
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local lp = require("web.lp")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "ExtenderPage", "extenderConfig")
local variantHelperWireless = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local html_escape = require("web.web").html_escape

--To check whether multiAP is enabled or not
local multiap_enabled = false
if post_helper.getVariantValue(variantHelperWireless, "multiAP") then
  local multiap_state = {
    agent = "uci.multiap.agent.enabled",
    controller = "uci.multiap.controller.enabled"
  }
  content_helper.getExactContent(multiap_state)
  multiap_enabled = multiap_state.agent == "1" and multiap_state.controller == "1"
end

local isExtender = post_helper.getVariantValue(variantHelper, "ShowTopologyWithoutHostManager")

local devices = {
  type = "gateway",
  name = untaint(proxy.get("uci.system.system.@system[0].hostname")[1].value),
  -- bssid2g = string.upper(untaint(proxy.get("sys.class.net.@wl0.address")[1].value)),
  -- bssid5g = string.upper(untaint(proxy.get("sys.class.net.@wl1.address")[1].value)),
  hostNumber = 0,
  extenderNumber = 0
}
local gatewayInfo = {
  agentMac = "uci.multiap.agent.macaddress",
  controllerMac = "uci.multiap.controller.macaddress",
  serial = "uci.env.var.serial"
}
content_helper.getExactContent(gatewayInfo)
local devices_columns = {
  {
    --[1]
    param = "FriendlyName",
    type = "text"
  },
  {
    --[2]
    param = "Speed",
    type = "text"
  },
  {
    --[3]
    param = "IPv4",
    type = "text"
  },
  {
    --[4]
    param = "State",
    type = "text"
  },
  {
    --[5]
    param = "InterfaceType",
    type = "text"
  },
  {
    --[6]
    param = "L2Interface",
    type = "text"
  },
  {
    --[7]
    param = "L3Interface",
    type = "text"
  },
  {
    --[8]
    param = "MACAddress",
    type = "text"
  },
  {
    --[9]
    param = "Radio",
    type = "text"
  }
}
local hosts, indexes = content_helper.loadTableData("sys.hosts.host.", devices_columns)
local hosts_MAC = {}
for k, v in ipairs(hosts) do
  if v[8] and v[8] ~= "" then
    hosts_MAC[upper(untaint(v[8]))] = v
  end
end
local function agentWirelessStandard(device)
  local radioPath = device.macAddr and format("rpc.multiap.device.@%s.radio.", device.macAddr) or ""
  local radioData = content_helper.convertResultToObject(radioPath, proxy.get(radioPath))
  if device.connectionType and device.connectionType ~= "" then
    local wirelessRadio = match(device.connectionType, "WiFi%p5") == "WiFi-5" and "radio_5G" or match(device.connectionType, "WiFi%p2") == "WiFi-2" and "radio_2G" or ""
    for _, value in pairs(radioData) do
      if value.freq == wirelessRadio then
        return value.cap
      end
    end
  end
end

local function hostParams(staList, station, param)
  local rssiHostValue = ""
  local supportedStandard = T"NA"
  local freqUsed = ""
  for _, val in pairs(staList) do
    if val.mac == station then
      local radioMac = string.match(param, "%@(.-)%.")
      freqUsed = (radioMac and val.assoc_agent_mac) and proxy.get(format("rpc.multiap.device.@%s.radio.@%s.freq", val.assoc_agent_mac, radioMac)) or T"NA"
      freqUsed = freqUsed ~= T"NA" and freqUsed[1].value
      rssiHostValue = val.rssi and untaint(val.rssi)
      supportedStandard = val.supported_standard and untaint(val.supported_standard)
    end
  end
  return freqUsed, rssiHostValue, supportedStandard
end

-- Display Ethernet Connected devices
    local ethPath = "rpc.multiap.eth."
    if isExtender then
    ethPath = "sys.hosts.host."
    end
    local ethMac = content_helper.convertResultToObject(ethPath, proxy.get(ethPath))
    for _, e in pairs(ethMac) do
        local mac = e.MacAddress and upper(untaint(e.MacAddress))
        if isExtender then
          mac = e.MACAddress and upper(untaint(e.MACAddress))
        end
        local host = hosts_MAC[mac]
        if host and host[5] == "ethernet" then
          if not isExtender or isExtender and host[4] == "1" then
            local linkRate = tonumber(host[2]) and host[2] / 1000
            devices[#devices + 1] = {
                type = "host",
                name = untaint(host[1]),
                speed = linkRate,
                connectionType = "Ethernet",
                ipAddress = untaint(host[3]),
                hostMacAddr = untaint(host[8])
            }
            devices.hostNumber = devices.hostNumber + 1
            hosts_MAC[mac] = nil
          end
        end
    end

local agents = {}
-- For dynamic sizing of SVG based on the connected number of clients
local topologyHeight = 0
local topologyWidth = 0
local deviceCount = {
  agent = "rpc.multiap.ExtenderNumberOfEntries",
  agentStatus = "rpc.multiap.X_000E50_AgentStatus",
  controllerStatus = "rpc.multiap.X_000E50_ControllerStatus"
}
content_helper.getExactContent(deviceCount)

deviceCount.agent = tonumber(deviceCount.agent) or 0

local path = "rpc.multiap.device."
local data = content_helper.convertResultToObject(path, proxy.get(path))
local multiapData = data
local staList = content_helper.convertResultToObject("rpc.multiap.sta.",proxy.get("rpc.multiap.sta."))
for k, v in ipairs(data) do
  if v.al_mac ~= "" then
    local agent = {
      type = "extender",
      name = v.serial_number and v.serial_number ~= "" and untaint(v.serial_number) or T"UnknownName",
      productClass = v.productclass and untaint(v.productclass),
      parentAccessPoint = v.parent and untaint(v.parent),
      connectionType = v.backhaul_interface_type and untaint(v.backhaul_interface_type) or "",
      LEDColor = "",
      hostNumber = 0,
      extenderNumber = 0,
      macAddr = untaint(v.al_mac),
      ipAddress = v.ip_address and untaint(v.ip_address) or "",
      status = v.status and untaint(v.status) or "",
      rssi = v.rssi and v.rssi ~= "" and tonumber(v.rssi) or T"NA",
      wirelessStandard = "",
      macList = v.local_interfaces and untaint(v.local_interfaces) or "",
      eth_clients = v.eth_clients and untaint(v.eth_clients) or ""
    }

    agent.wirelessStandard = agentWirelessStandard(agent) or T"NA"

    if deviceCount.agent and tonumber(deviceCount.agent) > 0 then
      for param, value in pairs(v) do
        if match(param, "^%S+.sta_list$") then
          if value ~= "" then
            for station in string.gmatch(value, '([^%s]+)') do
              local host = hosts_MAC[tostring(untaint(upper(station)))]
              local freqUsed, rssiHostValue, supportedStandard = hostParams(staList, station, param)
              local nameVal, ipAddressVal
              if post_helper.getVariantValue(variantHelper, "ShowTopologyWithoutHostManager") then
                nameVal = station
                ipAddressVal = station
              else
                nameVal = host and untaint(host[1]) or T"UnknownName"
                ipAddressVal = host and host[3] ~= "" and untaint(host[3]) or T"No IPAddress"
              end
              if rssiHostValue and rssiHostValue ~= "" and tonumber(rssiHostValue) ~= 0 then
                agent[#agent + 1] = {
                  type = "host",
                  name = nameVal,
                  ipAddress = ipAddressVal,
                  hostMacAddr = host and host[8] ~= "" and untaint(host[8]) or T"NA",
                  rssi = rssiHostValue and rssiHostValue ~= "" and tonumber(rssiHostValue) or T"NA",
                  connectionType = "wireless",
                  radio = freqUsed,
                  wirelessStandard = supportedStandard
                }
                agent.hostNumber = agent.hostNumber + 1
              end
            end
          end
        end
      end
    end
    agents[#agents + 1] = agent
  end
end

local function listToTree(t)
  local tree = {}
  while (next(t)) do
    local parent = {}
    local key = {}
    for k, v in pairs(t) do
      if v.parentAccessPoint and v.parentAccessPoint ~= "" then
        parent[v.parentAccessPoint] = true
      end
      if v.macAddr and v.macAddr ~= "" then
        key[v.macAddr] = k
      end
    end
    for k, v in pairs(t) do
      if not (v.macAddr and parent[v.macAddr]) then
        -- v is leaf node
        local k_p = v.parentAccessPoint and key[v.parentAccessPoint]
        if k_p then
          -- v 's parent is in table
          t[k_p][#t[k_p] + 1] = v
          t[k_p].extenderNumber = t[k_p].extenderNumber + 1
        else
          -- v 's parent is root node
          tree[#tree + 1] = v
        end
        t[k] = nil
      end
    end
  end
  return tree
end

local agentsTree = listToTree(agents)

for k, v in ipairs(agentsTree) do
  devices[#devices + 1] = v
  devices.extenderNumber = devices.extenderNumber + 1
end
local APPath = "uci.wireless.wifi-ap."
local APData = content_helper.convertResultToObject(APPath, proxy.get(APPath))
local apList = {}
local webIntfPath = proxy.get("uci.web.network.") or {}
local webInterfaces = {}

for i,v in ipairs(webIntfPath) do
  if v.path:match("^%S+.intf.") then
    webInterfaces[#webInterfaces + 1] = v
  end
end

for _, intf in ipairs(webInterfaces) do
  for _, value in ipairs(APData) do
    if value.iface == intf.value then
      apList[#apList + 1] = string.gsub(value.paramindex, "@", "")
    end
  end
end

local function checkMACinMAP(mac)
  for _, v in pairs(multiapData) do
    for _, w in pairs(v) do
      if w:match(mac) then
        return true
      end
    end
  end
  return false
end

for _, ap in pairs(apList) do
  local staPath = "rpc.wireless.ap.@" .. ap .. ".station."
  local stations = content_helper.convertResultToObject(staPath, proxy.get(staPath))
  for _, s in ipairs(stations) do
    local foundinMAP = checkMACinMAP(string.gsub(s.paramindex, "@", ""))
    if s.state and s.state ~= "" and s.state ~= "Disconnected" and s.state ~= "Authenticated" and s.paramindex and s.rssi and s.rssi ~= "" and s.rssi ~= "0" and not foundinMAP then
      local mac = gsub(s.paramindex, "@", "")
      mac = mac and upper(mac) or ""
      local host = hosts_MAC[mac]
      local ssidid = proxy.get(format("rpc.wireless.ap.@%s.ssid",ap))
      ssidid = ssidid and ssidid[1].value
      local ssidinfo = proxy.get(format("rpc.wireless.ssid.@%s.radio",ssidid))
      if post_helper.getVariantValue(variantHelper, "ShowTopologyWithoutHostManager") then
        devices[#devices + 1] = {
          type = "host",
          name = lower(mac),
          ipAddress = mac ~= "" and lower(mac) or mac,
          hostMacAddr = mac ~= "" and lower(mac) or mac,
          rssi = s.rssi and s.rssi ~= "" and tonumber(s.rssi) or T"NA",
          connectionType = "",
          wirelessStandard = s.capabilities and s.capabilities ~= "" and untaint(s.capabilities) or T"NA",
          radio = ssidinfo and ssidinfo[1] and ssidinfo[1].value or ""
        }
        devices.hostNumber = devices.hostNumber + 1
        hosts_MAC[mac] = nil
      else
        if host and host[4] == "1" then
          devices[#devices + 1] = {
            type = "host",
            name = host[1] and untaint(host[1]) or T"UnknownName",
            ipAddress = host[3] and untaint(host[3]) or T"No IPAddress",
            hostMacAddr = host[8] and untaint(host[8]) or "",
            rssi = s.rssi and s.rssi ~= "" and tonumber(s.rssi) or T"NA",
            connectionType = host[5] and untaint(host[5]) or "",
            wirelessStandard = s.capabilities and s.capabilities ~= "" and untaint(s.capabilities) or T"NA",
            radio = untaint(host[9])
          }
          devices.hostNumber = devices.hostNumber + 1
          hosts_MAC[mac] = nil
        end
      end
    end
  end
end

local html = {}
if ngx.var.request_method == "POST" then
  local postArgs = ngx.req.get_post_args()
  local validation = "error"
  if postArgs.action == "SAVE" then
    ngx.header.content_type = "application/json"
    local macs = postArgs.macList
    local friendlyName = tostring(untaint(postArgs.user_friendly_name))
    local success, errormsg = post_helper.validateStringIsDomainName(friendlyName)
    local setName = false
    if success then
      if macs ~= "" then
        local index = ""
        for _, dev in ipairs(indexes) do
          local macPath = proxy.get("sys.hosts.host."..dev.paramindex..".MACAddress")
          for mac in string.gmatch(macs, '([^,]+)') do
            if untaint(macPath) and untaint(macPath[1].value) == mac then
              setName = true
              break
            end
          end
          if setName then
            setName = false
            index = tostring(dev.paramindex)
            if index ~= "" then
              proxy.set("sys.hosts.host."..index..".FriendlyName", friendlyName)
              proxy.apply()
              validation = "success"
            end
          end
        end
      end
    else
      validation = "nameInvalid"
    end
    ngx.print('{"serverValidation":"'..validation..'"}')
    ngx.exit(ngx.HTTP_OK)
  end
end

local icons = {
  gateway = "gateway_icon.png",
  host = "wifi_all.png",
  extenderBlue = "ext.png",
  extenderStatusRed = "booster_status_red.png",
  extenderStatusOrange = "booster_status_orange.png",
  extenderStatusGreen = "booster_status_green.png",
  ethernet = "ethernet.png"
}
if isExtender then
  icons["gateway"] = "extender.png"
end
local owaExtender = false
if post_helper.getVariantValue(variantHelper, "ExtenderImage") then
  icons["gateway"] = "gateway.png"
end

local link = {
  gateway = "modals/easy-mesh-configuration.lp",
  host = "modals/wifi-devices-info.lp",
}
local level = { ["threshold_weak"]=-90, ["threshold_avg"]=-75, ["threshold_good"]=-60, ["threshold_excel"]=-50 }
local thresholdPath = "uci.web.wireless."
local thresholdData = content_helper.convertResultToObject(thresholdPath, proxy.get(thresholdPath))
for _, data in pairs(thresholdData) do
  for option, value in pairs(data) do
    if option ~= "@paramindex" then
      level[option] = tonumber(value)
    end
  end
end

local sysPath = "sys.hosts.host."
local devicesList = content_helper.convertResultToObject(sysPath, proxy.get(sysPath))
local lenX, lenY = 120, 0
local associatedDevices = 0
local heightChange = false
local function SVG(device)
  local height = 0
  local wifiGeneration = ""
  local radio_tech = ""
  local signalStrength = device.connectionType == "Unknown" and "" or "wirelessGrey.png"
  local onboard_status = ""
  local hostName = ""
  local divId = device.macAddr or device.hostMacAddr or ""
  local hostIndex = ""
  local lineColor = "grey"
  local onb_display = "hide"
  local signal_display = "hide"
  local setFriendlyName = false
  divId = divId:gsub(':', '')
  if device.type == "extender" then
    if post_helper.getVariantValue(variantHelper, "ExtenderImage") then
      if device.productClass == "OWA0131" or device.productClass == "OWA3111" then
        icons["extenderBlue"] ="extender.png"
        owaExtender = true
      else
        icons["extenderBlue"] ="ext.png"
      end
    elseif device.productClass == "OWA0131" or device.productClass == "OWA3111" or device.productClass == "Accesspoint" then
      icons["extenderBlue"] ="extender_icon.png"
      owaExtender = true
    end
    icon = device.LEDColor and icons[device.type .. device.LEDColor] or icons["extenderBlue"]
    if device.status == "Onboarding success" then
      onboard_status = icons["ethernet"]
      lineColor = "green"
      signal_display = "show"
      if device.connectionType == "Unknown" then
        onboard_status = icons["extenderStatusGreen"]
        signal_display = "hide"
      end
      onb_display = device.connectionType == "Ethernet" and "show" or (device.connectionType == "Unknown" and "show" or "hide")
    elseif device.status == "Onboarding" then
      onboard_status = icons["extenderStatusOrange"]
      onb_display = "show"
    elseif device.status == "Onboarding failed" then
      onboard_status = icons["extenderStatusRed"]
      onb_display = "show"
    end
    for _, dev in ipairs(devicesList) do
      for mac in string.gmatch(device.macList, '([^,]+)') do
        if dev.MACAddress and dev.MACAddress == mac then
          setFriendlyName = true
          break
        end
      end
      if setFriendlyName then
        setFriendlyName = false
        hostIndex = dev.paramindex
        break
      end
    if (upper(device.parentAccessPoint)) == gatewayInfo.agentMac or (upper(device.parentAccessPoint)) == gatewayInfo.controllerMac then
      lenX = 130
    end
  end
  hostName = proxy.get(sysPath .. hostIndex .. ".FriendlyName")
  hostName = hostName and hostName[1].value or T"UnknownName"
  end
  if device.type ~= "gateway" and device.connectionType ~= "ethernet" and device.connectionType ~= "Ethernet" then
    if device.type == "host" then
      radio_tech = device.radio == "radio_2G" and "2.4GHz" or device.radio == "radio_5G" and "5GHz" or ""
    elseif device.type == "extender" then
      radio_tech = device.connectionType == "WiFi-2.4G" and "2.4GHz" or match(device.connectionType, "WiFi%p5G") == "WiFi-5G" and "5GHz" or T"NA"
    end
    if (device.type == "extender" and device.status == "Onboarding success") or device.type == "host" then
      if type(device.rssi) == "number" then
        if device.rssi >= level["threshold_excel"] then
          signalStrength = "wirelessGreen.png"
          lineColor = "green"
        elseif device.rssi < level["threshold_excel"] and device.rssi >= level["threshold_good"] then
          lineColor = "yellow"
          signalStrength = "wirelessYellow.png"
        elseif device.rssi < level["threshold_good"] and device.rssi >= level["threshold_avg"] then
          signalStrength = "wirelessOrange.png"
          lineColor = "orange"
        elseif device.rssi < level["threshold_avg"] and device.rssi >= level["threshold_weak"] then
          signalStrength = "wirelessRed.png"
          lineColor = "red"
        end
      end
    end
    --To match wirelessStandard with ax, ac, n and display generation as 6, 5, 4 accordingly
    wifiGeneration = match(device.wirelessStandard, "ax") == "ax" and "6" or match(device.wirelessStandard, "ac") == "ac" and "5" or match(device.wirelessStandard, "n") == "n" and "4" or T"NA"
  end
  if heightChange == true then
    local lineX = lenX
    local lineY = lenY-30
    local lineHeight = 100
    -- lineX and lineY are the lengths required for drawing backtracing lines for the height extended by current element
    height = 100
    if device.type == "extender" then
      lineHeight = 140
    else
      lenY = lenY-40
    end
    -- Below loop is to iterate the all backtracing lines
    while(lineX >= 340)
    -- lenX is compared with 340 which is the initial position of SVG elements start, basically it is first element start point
    do
      lineX = lineX - 220
      html[#html + 1] = (format([[
                <svg x=%s y=%s height="210" width="500" style="overflow:visible!important">
                <line x1="0" y1="0" x2="0" y2=%s style="stroke:grey;stroke-width:2;stroke-dasharray: 12 8" /></svg>
      ]], lineX, lineY, lineHeight))
    end
  end
  local tooltipName, ipAddressval, background, editableHostName, staIpAddress, staName, breakTag, inputType, hiddenField, hideRadioTech, hideWifiGeneration, hideCircle
  if post_helper.getVariantValue(variantHelper, "ShowTopologyWithoutHostManager") then
    hostName = device.name and device.name ~= "" and device.name or T"Unknown"
    ipAddressval = device.macAddr and device.macAddr ~= "" and device.macAddr or T"No MAC Address"
    background = "background-color: white"
    editableHostName = "readonly"
    staIpAddress = ""
    staName = ""
    breakTag = ""
    inputType = "text"
    hiddenField = "hide"
    hideRadioTech = radio_tech and radio_tech == T"NA" and "hide" or ""
    hideWifiGeneration = wifiGeneration and wifiGeneration == T"NA" and "hide" or ""
    hideCircle = device.status == "Onboarding success" and wifiGeneration and wifiGeneration ~= T"NA" and "show" or "hide"
  else
    hostName = hostName
    ipAddressval = device.ipAddress and device.ipAddress ~= "" and device.ipAddress or T"No IPAddress"
    background = ""
    editableHostName = device.type == "extender" and device.status and device.status ~= "Onboarding success" and "disabled" or ""
    staIpAddress = device.ipAddress and device.ipAddress ~= "" and device.ipAddress or T"No IPAddress"
    staName = device.name and device.name ~= "" and device.name or T"UnknownName"
    breakTag = "</br>"
    inputType = "text"
    hiddenField = "save-cancel"
    hideRadioTech = ""
    hideWifiGeneration = ""
    hideCircle = signal_display
  end
  hostName = html_escape(hostName)
  tooltipName = hostName
  if staName and staName ~= "" then
    staName = html_escape(staName)
  end
  device.rssi = device.rssi ~= T"NA" and (tostring(device.rssi).."dBm") or device.rssi
  if device.type == "extender" and device.connectionType ~= "Ethernet" then
    tooltipName = html_escape(hostName)
    html[#html + 1] = (format([[
                <svg x=%s y=%s height="210" width="500" style="overflow:visible!important">
                <line x1="0" y1=%s x2="0" y2=%s style="stroke:grey;stroke-width:2;stroke-dasharray: 12 8" />
                <line x1="0" y1="100" x2=%s y2="100" style="stroke:%s;stroke-width:4;stroke-dasharray: 10 5" />
                <foreignObject x="0" y="23%%" width="25%%" height="60">
                  <div class="%s device"> <img class="devicepicture signal_strength_icon tooltip-on" data-placement="left" data-original-title="%s" width="35%%" style="margin-left:5em; margin-top: 0.55em" src="/img/%s" alt="" onerror="this.onerror=null" />
                  <span class="%s" style="margin-left:5em">%s</span>
                  </div>
                </foreignObject>
                <foreignObject x=%s y=%s width="17%%" height="45%%" class="nav">
                  <a href="#%s" data-remote="modals/easymesh-devices-info-modal-newEM.lp"> <img src="/img/%s"/ style="width:%s;"></a>
                </foreignObject>
                <foreignobject x="120" y="0" width="20%%" height="25%%">
                  <p id="%s-error" class="hide" style="color:red">Invalid Input</p>
                </foreignobject>
                <foreignObject x=%s y="28" width="35%%" height="30" style="overflow:visible!important">
                  <div class="easymesh_popover">
                    <input class="user_friendly_name tooltip-on" id="%s-ext-name" maxlength="40" type="%s" data-mac="%s" data-html="true" data-placement = "left" data-original-title = "%s</br>%s" data-ip="%s" data-value="%s" style="width:150px;font-weight:bold;border:none;margin-left:4.5em;text-align:center;padding-left:7%%;background-color:#ffffff !important;%s" value="%s" %s>
                  </div>
                </foreignObject>
	        <foreignObject x="200" y="30" height="20%%" class="%s" id="%s-save-width">
                  <div id="%s-save" class="name_save btn btn-table-modify btn-mini" data-value="%s" style="width:20%%">
                    <i class="icon-ok"></i><br>
                  </div>
                </foreignObject>
	       <foreignObject x="225" y="30" height="20%%" class="%s" id="%s-cancel-width">
                  <div id="%s-cancel"class="name_cancel btn btn-table-modify btn-mini" data-value="%s" style="width:20%%">
                    <i class="icon-remove"></i><br>
                  </div>
                </foreignObject>
                <circle class="%s" cx="24%%" cy="34%%" r="10" fill="black" />
                <text class="%s" x="24%%" y="36%%" text-anchor="middle" font-weight="bold" fill="white">%s
                </text>
                <foreignObject x="105" y="70" width="5%%" height="30">
                    <div class=%s><img src="img/%s"/></div>
                </foreignObject>
                <circle cx=%s cy=%s r="10" stroke="black" stroke-width="2" fill="white" />
                <text x=%s y=%s text-anchor="middle" font-weight="bold" fill="black">%s</text>
              </svg>]], lenX, lenY, heightChange and -30 or 0, height, owaExtender and 160 or 130, lineColor, signal_display, device.rssi, signalStrength, hideRadioTech, radio_tech, owaExtender and 164 or 130, owaExtender and 55 or 63, device.macAddr, icon and icon or "", owaExtender and "50px" or "100px", divId, owaExtender and 42 or 25, divId, inputType, device.macList, tooltipName, ipAddressval, ipAddressval, divId, background, hostName, editableHostName, hiddenField, divId, divId, divId, hiddenField, divId, divId, divId, hideCircle, hideWifiGeneration, wifiGeneration, onb_display, onboard_status, owaExtender and 205 or 200, owaExtender and 68 or 73, owaExtender and 205 or 200, owaExtender and 73.5 or 78.5, device.extenderNumber + device.hostNumber or "0"))
  elseif device.type == "extender" and device.connectionType == "Ethernet" then
      tooltipName = html_escape(hostName)
      html[#html + 1] = (format([[
                  <svg x=%s y=%s height="210" width="500" style="overflow:visible!important">
                <line x1="0" y1=%s x2="0" y2=%s style="stroke:grey;stroke-width:2;stroke-dasharray: 12 8" />
                  <line x1="0" y1="100" x2=%s y2="100" style="stroke:%s;stroke-width:4;" />
                  <foreignObject x=%s y=%s width="17%%" height="45%%" class="nav">
                    <a href="#%s" data-remote="modals/easymesh-devices-info-modal-newEM.lp"> <img src="/img/%s"/ style="width:%s;"></a>
                  </foreignObject>
                  <foreignobject x="120" y="0" width="20%%" height="25%%">
                    <p id="%s-error" class="hide" style="color:red">Invalid Input</p>
                  </foreignobject>
                  <foreignObject x=%s y="25" width="35%%" height="30%%" style="overflow:visible!important">
                  <div class="easymesh_popover">
                    <input class="user_friendly_name tooltip-on" id="%s-ext-name"  maxlength="40" type="%s" data-mac="%s" data-placement = "left" data-html="true" data-original-title = "%s</br>%s" data-ip="%s" data-value="%s" style="width:150px;font-weight:bold;border:none;margin-left:4.5em;text-align:center;padding-left:7%%;margin-top: 0.25em;background-color:#ffffff !important;%s" value="%s" %s>
                  </div>
                  </foreignObject>
                  <foreignObject x="200" y="30" height="20%%" class="%s" id="%s-save-width">
                    <div id="%s-save" class="name_save btn btn-table-modify btn-mini" data-value="%s" style="width:20%%">
                      <i class="icon-ok"></i><br>
                    </div>
                  </foreignObject>
                  <foreignObject x="225" y="30" height="20%%" class="%s" id="%s-cancel-width">
                    <div id="%s-cancel" class="name_cancel btn btn-table-modify btn-mini" data-value="%s" style="width:20%%">
                      <i class="icon-remove"></i><br>
                  </div>
                  </foreignObject>
                  <foreignObject x="105" y="70" width="5%%" height="30">
                    <div class=%s><img id="onb" src="img/%s"/></div>
                  </foreignObject>
                  <circle cx=%s cy=%s r="10" stroke="black" stroke-width="2" fill="white" />
                <text x=%s y=%s text-anchor="middle" font-weight="bold" fill="black">%s<text>
                </svg>]], lenX, lenY, heightChange and -30 or 0, height, owaExtender and 160 or 130, lineColor, owaExtender and 164 or 130, owaExtender and 55 or 63, device.macAddr, icon and icon or "", owaExtender and "50px" or "100px", divId, owaExtender and 42 or 25, divId, inputType, device.macList, tooltipName, ipAddressval, ipAddressval, divId, background, hostName, editableHostName, hiddenField, divId, divId, divId, hiddenField, divId, divId, divId, onb_display, onboard_status, owaExtender and 205 or 200, owaExtender and 68 or 73, owaExtender and 205 or 200, owaExtender and 73.5 or 78.5, device.extenderNumber + device.hostNumber or "0"))
  elseif device.type == "host" and device.connectionType == "Ethernet" then
	local lineColor = "green"
      html[#html + 1] = (format([[
                  <svg x=%s y=%s height="210" width="500" style="overflow:visible!important">
                  <line x1="0" y1="0" x2="0" y2=%s style="stroke:grey;stroke-width:2;" />
                  <line x1="0" y1="100" x2=%s y2="100" style="stroke:%s;stroke-width:4;" />
                  <foreignObject x=%s y="80" width="25%%" height="20%%" style="overflow:visible!important">
                  <div class="easymesh_popover nav">
                    <text class="host_name tooltip-on" data-placement = "top" data-html="true" data-original-title = "%s%s%s" style="font-weight:bold;text-overflow:ellipsis;word-break: break-word;display:block;width:126%%;overflow:hidden;white-space:nowrap;">
                      <a href="#%s" data-remote="modals/easymesh-devices-info-modal-newEM.lp">%s</a>
                    </text>
                  </div>
                  </foreignObject>
                  <foreignObject x="20" y="23%%" width="25%%" height="25%%">
                    <div class="device"> <img tooltip-on" data-placement="left" data-original-title="%s" width="35%%" style="margin-left:3.85em; margin-top: 0.5em;" src="/img/%s" alt="" onerror="this.onerror=null" />
                    <span style="margin-left:3.85em">%s</span>
                    </div>
          </svg>]], lenX, lenY, height, owaExtender and 160 or 130, lineColor, owaExtender and 174 or 140, staName or "", breakTag, staIpAddress or "" , device.hostMacAddr or "", device.name and device.name ~= "" and device.name or T"UnknownName", device.rssi or "", icons["ethernet"] or "", radio_tech or "", wifiGeneration or ""))
  elseif device.type == "host" then
      if staName and staName ~= "" then
        staName = html_escape(staName)
      end
      html[#html + 1] = (format([[
                  <svg x=%s y=%s height="210" width="500" style="overflow:visible!important">
                  <line x1="0" y1="0" x2="0" y2=%s style="stroke:grey;stroke-width:2;stroke-dasharray: 12 8" />
                  <line x1="0" y1="100" x2=%s y2="100" style="stroke:%s;stroke-width:4;stroke-dasharray: 10 5" />
                  <foreignObject x=%s y="80" width="25%%" height="20%%" style="overflow:visible!important">
                  <div class="easymesh_popover nav">
                    <text class="host_name tooltip-on" data-placement = "top" data-html="true" data-original-title = "%s%s%s" style="font-weight:bold;text-overflow:ellipsis;word-break: break-word;display:block;width:126%%;overflow:hidden;white-space:nowrap;">
                      <a href="#%s" data-remote="modals/easymesh-devices-info-modal-newEM.lp">%s</a>
                    </text>
                  </div>
                  </foreignObject>
                  <foreignObject x="20" y="23%%" width="25%%" height="25%%">
                    <div class="device"> <img class="devicepicture signal_strength_icon tooltip-on" data-placement="left" data-original-title="%s" width="35%%" style="margin-left:3.85em; margin-top: 0.5em;" src="/img/%s" alt="" onerror="this.onerror=null" />
                    <span style="margin-left:3.85em">%s</span>
                    </div>
                  </foreignObject>
                  <circle cx="25%%" cy="32%%" r="10" fill="black" />
                  <text x="25%%" y="34%%" text-anchor="middle" font-weight="bold" fill="white">%s</text>
          </svg>]], lenX, lenY, height, owaExtender and 160 or 130, lineColor, owaExtender and 174 or 140, staName, breakTag, staIpAddress, device.hostMacAddr, device.name and device.name ~= "" and device.name or T"UnknownName", device.rssi, signalStrength, radio_tech, wifiGeneration))
  end
end

local function SVGFor(devices)
  table.sort(devices, function(a,b) return tostring(a.type) < tostring(b.type) end)
  for index, value in ipairs(devices) do
    if devices.type == "gateway" then
      associatedDevices = devices.extenderNumber + devices.hostNumber
    end
    if value and value ~= "" and value.type == "extender" then
      if value.eth_clients ~= "" then
        for mac in value.eth_clients:gmatch('([^,]+)') do
	  local host = hosts_MAC[string.upper(mac)]
	  local eth_device = {}
	  eth_device.macAddr = mac
	  eth_device.type = "host"
	  eth_device.status = "Onboarding success"
	  eth_device.connectionType = "Ethernet"
          eth_device.name = (host and host[1]) and host[1] or mac
	  eth_device.hostMacAddr = mac
          eth_device.ipAddress = (host and host[3]) and host[3] or T"No IPAddress"

	  value[#value+1] = eth_device
	  value.hostNumber = value.hostNumber + 1
        end
      end
      SVG(value)
      if value.extenderNumber == 0 then
        if value.hostNumber == 1 or value.hostNumber > 1 then
          height = 0
          heightChange = false
          lenX = lenX+220
          if lenX > topologyWidth then topologyWidth = lenX end
          SVGFor(value)
          lenX = lenX-220
        else
          heightChange = true
          lenY = lenY+140
          if lenY > topologyHeight then topologyHeight = lenY end
        end
      elseif value.extenderNumber ~= 0 then
        height = 0
        lenX = lenX+220
        heightChange = false
        if lenX > topologyWidth then topologyWidth = lenX end
        SVGFor(value)
        lenX = lenX-220
      end
    elseif value and value ~= "" and value.type == "host" then
      SVG(value)
      lenY = lenY+140
      heightChange = true
      if lenY > topologyHeight then topologyHeight = lenY end
    end
  end
end

local tod_rule = false
for k,v in ipairs(proxy.getPN("uci.tod.timer.", true)) do
  local key = match(v.path, "%@%l+(%w+)")
  local ssid = proxy.get("uci.tod.ap.@ap"..key..".ssid") and proxy.get("uci.tod.ap.@ap"..key..".ssid")[1].value
  if ssid == "all" and proxy.get("uci.tod.action.@action"..key..".enabled")[1].value == "0" then
    tod_rule = true
  end
end

lp.setpath("/www/snippets/")
ngx.print(ui_helper.createHeader(T"EasyMesh Info", false, true))
  ngx.print('\
<form class="form-horizontal" method="post" action="/modals/easymesh-topology-modal-newEM.lp">\
  <div class="modal-body update">\
    ');  lp.include("tabs-easyMesh.lp")  ngx.print('\
      ');  if multiap_enabled and tod_rule then
        local tod_warning = {
          alert = {
            class = "alert-warning monitor-default-show"
          }
        }
        ngx.print(ui_helper.createAlertBlock(T"The Wi-Fi Schedule is currently enabled and your Wi-Fi connection will turn off as specified.", tod_warning))
      end
      local easymesh_ready = {
        alert = {
          class = "alert-warning monitor-default-show"
        }
      }
      local changeSuccess = {
        alert = {
          class = "alert alert-success hide",
          id = "success-msg"
        }
      }
      local changeFail = {
        alert = {
          class = "alert alert-error hide",
          id = "error-msg"
        }
      }
      ngx.print(ui_helper.createAlertBlock(T"Changes saved successfully", changeSuccess))
      ngx.print(ui_helper.createAlertBlock(T"Some parameters failed validation", changeFail))
      if not post_helper.getVariantValue(variantHelper, "ShowTopologyWithoutHostManager") and deviceCount.agentStatus and deviceCount.agentStatus ~= ""  and deviceCount.controllerStatus and deviceCount.controllerStatus ~= "" then
        if deviceCount.controllerStatus ~= "[7/7] local agent onboarding success" or deviceCount.agentStatus ~= "[6/6] onboarding success" then
          ngx.print(ui_helper.createAlertBlock(T"EasyMesh onboarding yet to complete, please refresh.", easymesh_ready))
        end
      end  ngx.print('\
      <div class="row" style="padding-left:10%">\
       <div id="boosterstatus">\
         <svg id="topo_view" style="overflow:visible !important" height= ');  ngx.print(topologyHeight); ngx.print(' width= ');  ngx.print(topologyWidth); ngx.print(' >\
            ');  SVGFor(devices)
            local deviceName = ""
            if post_helper.getVariantValue(variantHelper, "showLabel") then
                deviceName = T"<strong>Gateway</strong>"
            else
                deviceName = gatewayInfo.serial
            end
            html[#html+1] = format([[
                                <foreignObject x=20 y=50 height="100" width="95" style="overflow:visible!important">
                                <div>%s<img src="/img/%s" style="max-width:85%% !important"/></div>
                                </foreignObject>
                                <circle cx="85" cy="80" r="10" stroke="black" stroke-width="2" fill="white" />
                                <text x="85" y="85" text-anchor="middle" font-weight="bold" fill="black">%s</text>
                                ]], deviceName, icons["gateway"], associatedDevices)
            ngx.print(html)  ngx.print('\
         </svg>\
      </div>\
    </div>\
  </div>\
  <script>\
    var height_total = ');  ngx.print(tonumber(topologyHeight)); ngx.print(' > 0 ? ');  ngx.print(tonumber(topologyHeight)); ngx.print(' : 150;\
    var width_total = ');  ngx.print(tonumber(topologyWidth)); ngx.print('  > 0 ? ');  ngx.print(tonumber(topologyWidth)); ngx.print('+275 : 400;\
    $("#topo_view").attr("height", height_total);\
    $("#topo_view").attr("width", width_total);\
    $(".save-cancel").width(0);\
    $(".name_save, .name_cancel").hide();\
    var friendly_name_id = "";\
    var stored_value = "";\
    $(".user_friendly_name").click(function(){\
      friendly_name_id =  $(this).attr(\'data-value\');\
      $(\'#\'+friendly_name_id+\'-ext-name\').width(90);\
      $(\'#\'+friendly_name_id+\'-save-width\').add(\'#\'+friendly_name_id+\'-cancel-width\').width(\'10%\');\
      $(\'#\'+friendly_name_id+\'-save\').add(\'#\'+friendly_name_id+\'-cancel\').show();\
      $(\'#\'+friendly_name_id+\'-ip-addr\').removeClass("show").addClass("hide");\
      stored_value = $(\'#\'+friendly_name_id+\'-ext-name\').val();\
      $(\'#\'+friendly_name_id+\'-ext-name\').attr("data-input-val",stored_value)\
    });\
    var name_change = ""\
    var stored_value_attr = ""\
    $(".name_cancel").click(function(){\
      friendly_name_id =  $(this).attr(\'data-value\');\
      $(\'#\'+friendly_name_id+\'-ext-name\').css(\'border\',\'none\');\
      $(\'#\'+friendly_name_id+\'-error\').removeClass("show").addClass("hide")\
      $(\'#\'+friendly_name_id+\'-save-width\').add(\'#\'+friendly_name_id+\'-cancel-width\').width(0);\
      $(\'#\'+friendly_name_id+\'-ext-name\').width(150);\
      name_change =  $(this).attr(\'data-value\');\
      $(\'#\'+name_change+\'-save\').add(\'#\'+name_change+\'-cancel\').hide();\
      stored_value_attr = $(\'#\'+friendly_name_id+\'-ext-name\').attr(\'data-input-val\')\
      $(\'#\'+friendly_name_id+\'-ext-name\').val(stored_value_attr);\
    });\
    $(".name_save").click(function(){\
      friendly_name_id =  $(this).attr(\'data-value\');\
      name_change =  $(this).attr(\'data-value\');\
      $(\'#\'+friendly_name_id+\'-save-width\').add(\'#\'+friendly_name_id+\'-cancel-width\').width(0);\
      $(\'#\'+friendly_name_id+\'-ext-name\').width(150);\
      $(\'#\'+name_change+\'-save\').add(\'#\'+name_change+\'-cancel\').hide();\
      var params = [];\
      var serialPostValue = $(\'#\'+name_change+\'-ext-name\').val();\
      var ipAddr = $(\'#\'+name_change+\'-ext-name\').attr(\'data-ip\');\
      var macList = $(\'#\'+name_change+\'-ext-name\').attr(\'data-mac\');\
      params.push({\
          name : "action",\
          value: "SAVE"\
       },\
       {\
          name: "ipAddr",\
          value: ipAddr\
       },\
       {\
          name: "macList",\
          value: macList\
       },\
       {\
          name : "user_friendly_name",\
          value : serialPostValue\
       }, tch.elementCSRFtoken());\
      var target = "/modals/easymesh-topology-modal-newEM.lp";\
      $.post(target, params, function(response) {\
        $("#success-msg, #error-msg").removeClass("show").addClass("hide")\
        if (response.serverValidation == "success") {\
          $(\'#\'+friendly_name_id+\'-error\').removeClass("show").addClass("hide");\
          $(\'#\'+friendly_name_id+\'-ext-name\').css(\'border\',\'none\');\
          $("#success-msg").removeClass("hide").addClass("show");\
          $(\'#\'+friendly_name_id+\'-ext-name\').attr("data-original-title", params[3].value+"</br>"+params[1].value)\
        }\
        else if (response.serverValidation == "nameInvalid") {\
          $(\'#\'+friendly_name_id+\'-ext-name\').width(90);\
          $(\'#\'+friendly_name_id+\'-cancel-width\').add(\'#\'+friendly_name_id+\'-save-width\').width(\'10%\');\
          $(\'#\'+name_change+\'-save\').add(\'#\'+name_change+\'-cancel\').show();\
          $(\'#\'+friendly_name_id+\'-ext-name\').css(\'border\', \'1px solid red\');\
          $("#error-msg").removeClass("hide").addClass("show")\
          $(\'#\'+friendly_name_id+\'-error\').removeClass("hide").addClass("show")\
        }\
        else {\
          $("#error-msg").removeClass("hide").addClass("show")\
        }\
      });\
    });\
    if ($("#Topology").parent().hasClass("active")) {\
      if (typeof(controller_status) != \'undefined\' || typeof(agent_status) != \'undefined\') {\
        clearInterval(controller_status);\
        clearInterval(agent_status);\
      }\
    }\
  </script>\
</form>\
');  ngx.print(format([[
                <div class="modal-footer">
                  <div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">%s</div>
                </div>
              ]], T"Close"))   ngx.print('\
');
