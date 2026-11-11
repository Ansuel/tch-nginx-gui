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

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local attributes = { span = { class = "span4" } }
local message_helper = require("web.uimessage_helper")
local lp = require("web.lp")
local ngx = ngx
local table, string = table, string
local tonumber, tostring, untaint = tonumber, tostring, string.untaint
local format, match = string.format, string.match
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "ExtenderPage", "extenderConfig")
local variantHelperWireless = post_helper.getVariant(variant_helper, "Wireless", "wireless")

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

local content = {
    hostname = "uci.system.system.@system[0].hostname",
}
content_helper.getExactContent(content)

local devices_columns = {
  {--[1]
    header = T"",
    name = "interfacetype",
    param = "InterfaceType_img",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[2]
    header = T"Name",
    name = "name",
    param = "FriendlyName",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[3]
    header = T"MAC address",
    name = "macaddress",
    param = "MACAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[4]
    header = T"IPv4 address",
    name = "ipaddress",
    param = "IPv4",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[5]
    header = T"IPv6 address",
    name = "ip6address",
    param = "IPv6",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[6]
    header = T"Connection",
    name = "interfacetype",
    param = "InterfaceType",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
}

local MACcolumnindex = 3
local device_valid = {}
local devices_options = {
  canEdit = false,
  canAdd = false,
  canDelete = false,
  tableid = "easymeshDevices",
  basepath = "sys.hosts.host."
}

--add a device filter to remove the table line in case we have a host connected by FON.
local devices_filter = function(data)
  -- Do not display devices not in the LAN bridge
  if data["FirewallZone"] == "LAN" then
      if data["InterfaceType"] == "wireless" then
          data["InterfaceType_img"] = "<div><img align='middle' src='/img/wifi_all.png'></div>"
          if match(data["L2Interface"], "^wl0") or data["Radio"] == "radio_2G" then
              data["InterfaceType"] = "2.4GHz"
          elseif match(data["L2Interface"], "^wl1") or data["Radio"] == "radio_5G" then
              data["InterfaceType"] = "5GHz"
          end
      else
          data["InterfaceType_img"] = "<div><img width='20' align='middle' src='/img/ethernet.png'></div>"
      end
      return true
  else
      return false
  end
end

local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter, nil, device_valid)

--Remove unwanted columns
if post_helper.getVariantValue(variantHelper, "ShowWiFiDevicesWithoutHostManager") then
  local succ, err
  local index = 1
  succ, err =  table.remove(devices_columns, 1) -- Removed "InterfaceType" Column and column "Name" is moved to index "1".
  if not err then
    succ , err = table.remove(devices_columns, 1) -- Removed "Name" Column and column "MACAddress" moved to index "1".
    MACcolumnindex = 1
  end
  -- Remaining columns "IPv4 address, IPv6 address, WiFi Band" from devices_columns is removed
  while(index <= 3)
  do
    if not err then
      succ, err = table.remove(devices_columns, 2)
    end
    index = index + 1
  end
end

devices_columns[#devices_columns+1] = {--[7]
  header = T"RSSI",
  name = "signalstrength",
  param = "rssi",
  type = "text",
  readonly = true,
  attr = { input = { class="span1" } },
}

devices_columns[#devices_columns+1] = {--[8]
  header = T"Download/Upload Link Rate",
  name = "linkrate",
  param = "phyrate",
  type = "text",
  readonly = true,
  attr = { input = { class="span1" } },
}

devices_columns[#devices_columns+1] = {--[9]
  header = T"Tx/Rx data",
  name = "linkrate",
  param = "BackhaulBytesSent",
  type = "text",
  readonly = true,
  attr = { input = { class="span1" } },
}

devices_columns[#devices_columns+1] = {--[10]
  header = T"Do Not Steer",
  name = "do_not_steer",
  param = "do_not_steer",
  type= "checkboxswitch",
  readonly = false,
  attr = { input = { class="span2" } },
}

local agent_devices_options = {
  canEdit = false,
  canAdd = false,
  canDelete = false,
  tableid = "agentData",
  basepath = "rpc.multiap.device."
}

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in next, orig, nil do
        copy[deepcopy(orig_key)] = deepcopy(orig_value)
      end
    else
      copy = orig
    end
    return copy
end
local agent_devices_columns = deepcopy(devices_columns)
local agent_device_valid = {}
if not post_helper.getVariantValue(variantHelper, "ShowWiFiDevicesWithoutHostManager") then
  table.remove(agent_devices_columns, 2) --To remove name column for agent information table
  table.remove(agent_devices_columns, 9) --To remove do not steer column for agent information table
  agent_devices_columns[2]["param"] = "al_mac"
  agent_devices_columns[3]["param"] = "ip_address"
  agent_devices_columns[5]["param"] = "backhaul_interface_type"
else
  table.remove(agent_devices_columns, 5) --To remove do not steer column for agent information table
  agent_devices_columns[1]["param"] = "al_mac"
  agent_devices_options["tableid"] = "agentDataNoHostmanager"
  devices_options["tableid"] = "hostDataNoHostmanager"
end

local agent_devices_data, agent_devices_helpmsg = post_helper.handleTableQuery(agent_devices_columns, agent_devices_options, nil, nil, agent_device_valid)

local doNotSteerPath = "uci.wee.donotsteer.enabled"
local doNotSteerEnabled = proxy.get(doNotSteerPath)
local showDoNotSteer = post_helper.getVariantValue(variantHelper, "doNotSteer")
doNotSteerEnabled = doNotSteerEnabled and doNotSteerEnabled[1] and doNotSteerEnabled[1].value or "0"
if doNotSteerEnabled ~= "1" or not showDoNotSteer then
  for index, data in pairs(devices_columns) do
    if data.name == "do_not_steer" then
      table.remove(devices_columns, index)
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
local apList = {}
local APPath = "uci.wireless.wifi-ap."
local APData = content_helper.convertResultToObject(APPath, proxy.get(APPath))
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

local steerPath = "uci.wee.donotsteer.donotsteer_list."
local steerMac = content_helper.convertResultToObject(steerPath, proxy.get(steerPath))

local function isChecked(mac)
  local checked = "0"
  for index, paramValue in pairs(steerMac) do
    if paramValue.value ~= "" and mac == paramValue.value then
      checked = "1"
      break
    end
  end
  return checked
end

--Find Mac in mulitap
local multiapData = content_helper.convertResultToObject("rpc.multiap.device.",proxy.get("rpc.multiap.device."))
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


if ngx.var.request_method == "POST" then
  local postArgs = ngx.req.get_post_args()
  if postArgs.action == "doNotSteer" then
    local mac = untaint(postArgs.macAddress)
    local checkBoxValue = untaint(postArgs.checkedOrNot)
    if tonumber(checkBoxValue) == 0 then
      -- Do Not Steer is unchecked , So deleting the mac address from the list
      for index, param in pairs(steerMac) do
        if param.value == mac then
          proxy.del(format(steerPath .."@%s.", index))
          break
        end
      end
    elseif tonumber(checkBoxValue) == 1 then
      -- Do Not Steer is checked , So adding the mac address to the list
      local index, err = proxy.add(steerPath)
      proxy.set({[format(steerPath .."@%s.value", index)] = mac})
    end
    proxy.apply()
  end
end

lp.setpath("/www/snippets/")
ngx.print(ui_helper.createHeader(T"EasyMesh Info", false, true))
  ngx.print('\
<form class="form-horizontal" method="post" action="/modals/easymesh-devices-info-modal-newEM.lp">\
  <div id="modalBody" class="modal-body update">\
    ');  lp.include("tabs-easyMesh.lp")
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))  ngx.print('\
    ');  if (multiap_enabled and tod_rule) then
      local tod_warning = {
        alert = {
          class = "alert-warning monitor-default-show"
        }
      }
      ngx.print(ui_helper.createAlertBlock(T"The Wi-Fi Schedule is currently enabled and your Wi-Fi connection will turn off as specified.", tod_warning))
    end  ngx.print('\
    <div class="container">\
      <div class="row">\
        <div class="span11">\
          <fieldset>\
            ');
	    if not  post_helper.getVariantValue(variantHelper, "ShowWiFiDevicesWithoutHostManager") then
              --For gateway itself
              local html={}
              local internalstanumber = "0"
              local newdevices_data = {}
              for _, ap in pairs(apList) do
                local staPath = "rpc.wireless.ap.@" .. ap .. ".station."
                local staInfo = proxy.get(staPath)
                local staList = content_helper.convertResultToObject(staPath, staInfo)
                if type(staList) == 'table' then
                  for _, sta_v in ipairs(staList) do
                    local foundinMAP = checkMACinMAP(string.gsub(sta_v.paramindex, "@", ""))
                    if sta_v.state ~= "Disconnected" and sta_v.state ~= "Authenticated" and sta_v.rssi and sta_v.rssi ~= "" and tonumber(sta_v.rssi) ~= 0 and not foundinMAP then
                      for i, v in pairs(devices_data) do
                        if sta_v.paramindex == "@" .. v[MACcolumnindex] and #v == 6 then
                          v[#v+1] = sta_v.rssi and sta_v.rssi .. "dBm" or ""
                          v[#v+1] = sta_v.tx_phy_rate and sta_v.rx_phy_rate and post_helper.convertPhyRate(sta_v.tx_phy_rate, false) .. " / " .. post_helper.convertPhyRate(sta_v.rx_phy_rate, false) or ""
                          v[#v+1] = sta_v.tx_bytes and sta_v.rx_bytes and post_helper.convertData(sta_v.tx_bytes) .. " / " .. post_helper.convertData(sta_v.rx_bytes) or ""
                          if doNotSteerEnabled == "1" and showDoNotSteer then
                            v[#v+1] = isChecked(v[MACcolumnindex])
                          end
                          internalstanumber = internalstanumber + 1
                          newdevices_data[#newdevices_data+1]=devices_data[i]
                          break
                        end
                      end
                    end
                  end
                end
              end
              if post_helper.getVariantValue(variantHelper, "showLabel") then
                html[#html+1] = format('<legend>%s<br />'.. T'Connected Devices:'..'%s<br /></legend>', T"Gateway", internalstanumber)
              else
                html[#html+1] = format('<legend>%s<br />'.. T'Connected Devices:'..'%s<br /></legend>', content.hostname, internalstanumber)
              end
              html[#html+1] = ui_helper.createTable(devices_columns, newdevices_data, devices_options, nil, devices_helpmsg)
              ngx.print(html)
            end
            local html={}
            local internal_sta_count = 0
	    local internal_agent_MAC = proxy.get("uci.multiap.agent.macaddress")[1].value or ""
            local MultiAP = content_helper.convertResultToObject("rpc.multiap.device.",proxy.get("rpc.multiap.device."))
            local staList = content_helper.convertResultToObject("rpc.multiap.sta.",proxy.get("rpc.multiap.sta."))
            local devicesList = content_helper.convertResultToObject(devices_options.basepath, proxy.get(devices_options.basepath))
            for _, sta_x in pairs(staList) do
		if sta_x.assoc_agent_mac == string.lower(internal_agent_MAC) then
                   internal_sta_count = internal_sta_count + 1
                 end
            end
            if post_helper.getVariantValue(variantHelper, "ShowWiFiDevicesWithoutHostManager") and #MultiAP == 0 and #staList == 0 then
              local newdevices_data = {}
              html[#html+1] = format('<legend>%s<br />'..T'Connected Devices:'..'%s<br /></legend></span>',content.hostname, internal_sta_count)
              html[#html+1] = ui_helper.createTable(devices_columns, newdevices_data, devices_options, nil, devices_helpmsg)
            elseif MultiAP then
		if post_helper.getVariantValue(variantHelper, "ShowWiFiDevicesWithoutHostManager") and internal_sta_count > 0  then
                  local agent_sta_count = 0
                  local new_internal_devices_data = {}
                  for _, ap in pairs(apList) do
                    local staPath = "rpc.wireless.ap.@" .. ap .. ".station."
                    local staInfo = proxy.get(staPath)
                    local staApList = content_helper.convertResultToObject(staPath, staInfo)
                    if type(staApList) == 'table' then
                      for _, sta_v in ipairs(staApList) do
                        if sta_v.state ~= "Disconnected" and sta_v.state ~= "Authenticated" and sta_v.rssi and sta_v.rssi ~= "" and tonumber(sta_v.rssi) ~= 0 then
                          local internal_devices_data_multiap = {}
                          local counter = 1
                            for _,sta_d in pairs(staList) do
                              if "@"..sta_d.mac == sta_v.paramindex then
                                internal_devices_data_multiap[counter] = {}
                                local internal_tmp = 1
                                internal_devices_data_multiap[counter][internal_tmp] = sta_d.mac
                                internal_devices_data_multiap[counter][internal_tmp+1] = sta_d.rssi and sta_d.rssi ~= "" and sta_d.rssi .. " dBm" or ""
                                internal_devices_data_multiap[counter][internal_tmp+2] = sta_d.dl_mac_rate and sta_d.dl_mac_rate ~= "" and sta_d.ul_mac_rate and sta_d.ul_mac_rate ~= "" and post_helper.convertPhyRate(sta_d.dl_mac_rate, true) .. " / " .. post_helper.convertPhyRate(sta_d.ul_mac_rate, true) or ""
                                internal_devices_data_multiap[counter][internal_tmp+3] = sta_d.txbytes and sta_d.txbytes ~= "" and sta_d.rxbytes and sta_d.rxbytes ~= "" and post_helper.convertData(sta_d.txbytes) .. " / " .. post_helper.convertData(sta_d.rxbytes) or ""
                                if doNotSteerEnabled == "1" and showDoNotSteer then
                                  internal_devices_data_multiap[counter][internal_tmp+4] = isChecked(sta_d.mac)
	                        end
                                new_internal_devices_data[#new_internal_devices_data+1] = internal_devices_data_multiap[counter]
                                counter = counter + 1
                              end
                            end
                        end
                      end
                    end
                  end
                  html[#html+1] = format('<span id=%s><legend>%s<br />'..T'Connected Devices:'..'%s<br /></legend></span>', internal_agent_MAC, content.hostname, internal_sta_count)
                  html[#html+1] = ui_helper.createTable(devices_columns, new_internal_devices_data, devices_options, nil, devices_helpmsg)
              end
              for k, v in ipairs(MultiAP) do
                local agent_MAC = v.al_mac and tostring(string.untaint(v.al_mac)) or ""
                local agent_name = v.serial_number and v.serial_number ~= "" and string.untaint(v.serial_number) or "Unknown_Name"
                local agent_details = {}
                local intfMAC = ""
                if not  post_helper.getVariantValue(variantHelper, "ShowWiFiDevicesWithoutHostManager") then
                  for _, dev in ipairs(devicesList) do
                    for intf in string.gmatch(v.local_interfaces, '([^,]+)') do
                      if dev.MACAddress == intf then
                        intfMAC = intf
                        agent_name = dev.FriendlyName
                        break
                      end
                    end
                  end
                end
                if not post_helper.getVariantValue(variantHelper, "ShowWiFiDevicesWithoutHostManager") then
                  for index, value in ipairs(agent_devices_data) do
                    if value[2] and value[2] == agent_MAC then
                      value[3] = value[3] and value[3] or ""      --IPv4 Address
                      value[4] = value[4] and value[4] or ""      --IPv6Address
                      value[5] = match(value[5], "WiFi%p5G%pL") == "WiFi-5G-L" and "5GHz-Low" or match(value[5], "WiFi%p5G%pH") == "WiFi-5G-H" and "5GHz-High" or match(value[5], "WiFi%p2") == "WiFi-2" and "2.4GHz" or value[5]
                      value[6] = value[5] == "Ethernet" and "NA" or value[5]=="Unknown" and "" or value[6].."dBm"    --RSSI
                      value[7] = value[7] and value[7] ~= "" and post_helper.convertPhyRate(value[7], true).." / "..post_helper.convertPhyRate(value[7], true) or ""     --Download/Upload link rate
                      agent_details[#agent_details+1] = agent_devices_data[index]
                      local bytesReceived = proxy.get(format("rpc.multiap.device.@%s.BackhaulBytesReceived", agent_MAC))
                      bytesReceived = bytesReceived and bytesReceived[1].value and bytesReceived[1].value ~= "" and post_helper.convertData(bytesReceived[1].value) or ""
                      value[8] = value[8] and value[8] ~= "" and post_helper.convertData(value[8]) or ""
                      value[8] = value[8] == "" and bytesReceived == "" and "" or value[8].." / "..bytesReceived     --Tx/Rx Data
                      for _, sta_v in ipairs(staList) do     --To calculate dl_mac_rate and ul_mac_rate of wireless extender
                        if intfMAC == sta_v.mac then
                          value[7] = sta_v.dl_mac_rate and sta_v.dl_mac_rate ~= "" and sta_v.ul_mac_rate and sta_v.ul_mac_rate ~= "" and post_helper.convertPhyRate(sta_v.dl_mac_rate, true) .. " / " .. post_helper.convertPhyRate(sta_v.ul_mac_rate, true)
                        end
                      end
                    end
                  end
                else
                  for index, value in ipairs(agent_devices_data) do
                    if value[1] and value[1] == agent_MAC then
                      value[2] = value[2] ~= "" and value[2].."dBm" or "NA"    --RSSI
                      agent_details[#agent_details+1] = agent_devices_data[index]
                      value[3] = value[3] and value[3] ~= "" and post_helper.convertPhyRate(value[3], true).." / "..post_helper.convertPhyRate(value[3], true) or ""
                      local bytesReceived = proxy.get(format("rpc.multiap.device.@%s.BackhaulBytesReceived", agent_MAC))
                      bytesReceived = bytesReceived and bytesReceived[1].value and bytesReceived[1].value ~= "" and post_helper.convertData(bytesReceived[1].value) or "NA"
                      value[4] = value[4] and value[4] ~= "" and post_helper.convertData(value[4]) or "NA".." / "..bytesReceived     --Tx/Rx Data
                      for _, sta_v in ipairs(staList) do     --To calculate dl_mac_rate and ul_mac_rate of wireless extender
                        if intfMAC == sta_v.mac then
                          value[3] = sta_v.dl_mac_rate and sta_v.dl_mac_rate ~= "" and sta_v.ul_mac_rate and sta_v.ul_mac_rate ~= "" and post_helper.convertPhyRate(sta_v.dl_mac_rate, true) .. " / " .. post_helper.convertPhyRate(sta_v.ul_mac_rate, true)
                        end
                      end
                    end
                  end
                end
                local sta_count = 0
                local newdevices_data = {}
		local devices_data_multiap = {}
		local count = 1
                if agent_MAC ~= "" then
                  for key, value in pairs(v) do
                    if match(key, "^%S+.sta_list$") then
                      if value ~= "" then
                        for sta_i in string.gmatch(value, '([^%s]+)') do
                          for _, sta_v in ipairs(staList) do
			    devices_data_multiap[count] = {}
			    local tmp = 1
                            if sta_v.mac == sta_i then
                              sta_count = sta_count + 1
                              local devicelinkrate = sta_v.dl_mac_rate and sta_v.dl_mac_rate ~= "" and sta_v.ul_mac_rate and sta_v.ul_mac_rate ~= "" and post_helper.convertPhyRate(sta_v.dl_mac_rate, true) .. " / " .. post_helper.convertPhyRate(sta_v.ul_mac_rate, true) or ""
                              local devicesignalstrength = sta_v.rssi and sta_v.rssi ~= "" and sta_v.rssi .. " dBm" or ""
                              local devicetraffic = sta_v.txbytes and sta_v.txbytes ~= "" and sta_v.rxbytes and sta_v.rxbytes ~= "" and post_helper.convertData(sta_v.txbytes) .. " / " .. post_helper.convertData(sta_v.rxbytes) or ""
                              if not post_helper.getVariantValue(variantHelper, "ShowWiFiDevicesWithoutHostManager") then
                                for i, v in pairs(devices_data) do
                                  if sta_v.mac == v[MACcolumnindex] and #v == 6 then
                                    v[#v+1] = devicesignalstrength
                                    v[#v+1] = devicelinkrate
                                    v[#v+1] = devicetraffic
                                    if doNotSteerEnabled == "1" and showDoNotSteer then
                                      v[#v+1] = isChecked(sta_v.mac)
                                    end
                                    if post_helper.getVariantValue(variantHelper, "doNotSteer") and doNotSteerEnabled ~= "1" then
                                      newdevices_data[#newdevices_data+1]={}
                                      for o,p in ipairs(devices_data[i]) do
                                        if o < 10 then
                                          newdevices_data[#newdevices_data][o]=p
                                        end
                                      end
                                    else
                                      newdevices_data[#newdevices_data+1]=devices_data[i]
                                    end
                                  end
                                end
                              else -- When hostmanager does not have the connected device detail values can be retrived from "rpc.mutiap.sta"
				devices_data_multiap[count][tmp] = sta_v.mac
				devices_data_multiap[count][tmp+1] = devicesignalstrength
				devices_data_multiap[count][tmp+2] = devicelinkrate
				devices_data_multiap[count][tmp+3] = devicetraffic
                                if doNotSteerEnabled == "1" and showDoNotSteer then
		                  devices_data_multiap[count][tmp+4] = isChecked(sta_v.mac)
                                end
                                if post_helper.getVariantValue(variantHelper, "doNotSteer") and doNotSteerEnabled ~= "1" then
                                  newdevices_data[#newdevices_data+1]={}
                                  for o,p in ipairs(devices_data_multiap[count]) do
                                    if o < 10 then
                                      newdevices_data[#newdevices_data][o]=p
                                    end
                                  end
                                else
                                  newdevices_data[#newdevices_data+1]=devices_data_multiap[count]
                                end
                                count = count + 1
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
                html[#html+1] = format('<span id=%s-header><legend>%s</legend></span>', agent_MAC, agent_name)
                html[#html+1] = ui_helper.createTable(agent_devices_columns, agent_details, agent_devices_options, nil, agent_devices_helpmsg)
                html[#html+1] = format('<span id=%s-list><legend style="font-size:large;padding-left:10px;">'..T"Connected Devices:"..'%s</legend></span>', agent_MAC, sta_count)
                html[#html+1] = ui_helper.createTable(devices_columns, newdevices_data, devices_options, nil, devices_helpmsg)
              end
            end
            ngx.print(html)
              ngx.print('\
          </fieldset>\
        </div>\
      </div>\
    </div>\
  </div>\
</form>\
');  ngx.print(ui_helper.createFooter()); ngx.print('\
<script>\
    $(\'input[type="checkbox"]\').click(function(){\
      var rowId = $(this).closest(\'tr\').attr(\'id\');\
      var check = $(this).prop(\'checked\')? 1 : 0;\
      var params = [];\
      params.push({\
        name : "action",\
        value: "doNotSteer"\
      },\
      {\
        name: "macAddress",\
        value: rowId\
      },\
      {\
        name : "checkedOrNot",\
        value : check\
      }, tch.elementCSRFtoken());\
      var target = "/modals/easymesh-devices-info-modal-newEM.lp";\
      $.post(target, params, true);\
  });\
\
  var multiap_enabled = ');  ngx.print( multiap_enabled ); ngx.print('\
  var hidedetails = ');  ngx.print( post_helper.getVariantValue(variantHelper, "hideWifiDevice") ); ngx.print('\
  //Removing Horizontal  Scroll bar in Normal View .If any column is added or removed,remove this function if needed.\
  function removeScroll(){\
    var modal_width = $("#modalBody").width();\
    var table_width = $("#easymeshDevices").width();\
      if (table_width<modal_width)\
        $("#modalBody").css("overflow-x","hidden");\
      else\
        $("#modalBody").css("overflow-x","auto");\
  }\
  $(window).resize(function(){\
    removeScroll();\
  });\
  $(document).ready(function () {\
    removeScroll();\
    //Dynamically adding ID to each row with the mac address of the device.\
    $("tbody").find(\'tr\').each(function (key, val) {\
      var cellObj = $(this).find(\'td\');\
      var macAddr = cellObj.eq(2).text();\
      if ($(this).parent().parent().attr(\'id\') == "agentData") {\
        macAddr = cellObj.eq(1).text();\
      } else if ($(this).parent().parent().attr(\'id\') == "agentDataNoHostmanager" || $(this).parent().parent().attr(\'id\') == "hostDataNoHostmanager") {\
        macAddr = cellObj.eq(0).text();\
      }\
      $(this).attr("id", macAddr);\
    });\
   if(multiap_enabled && hidedetails) {\
     for(i=1;i<4;i++) {\
       $("#easymeshDevices").find("th:eq("+i+")").remove();\
       $("#easymeshDevices tbody tr").find("td:eq("+i+")").remove();\
     }\
     $("#easymeshDevices").find("th:eq(2)").remove();\
     $("#easymeshDevices tbody tr").find("td:eq(2)").remove();\
   }\
\
    $(\'input[type="checkbox"]\').change(function(){\
      $(\'#easymeshDevices\').delay(350).fadeIn(300);\
      return false;       // For stoping the POST\
    });\
\
    //Navigation to the the paricular ID(wifi-extender-status.lp) and higlighting it to blue\
    var url = window.location.toString();\
    var macRegex = /[a-fA-F0-9:]{17}|[a-fA-F0-9]{12}$/i;\
    var macID = url.match(macRegex);\
    var elem = document.getElementById(macID);\
    if (elem !== null) {\
      elem.scrollIntoView({ behavior: "smooth", block: "end", inline: "nearest" });\
      elem.classList.add("info");\
    }\
  });\
\
  var query = "easyMeshDevices";\
  if ($("[id=\'" + query + "\']").parent().hasClass("active")) {\
    if (typeof(controller_status) != \'undefined\' || typeof(agent_status) != \'undefined\') {\
      clearInterval(controller_status);\
      clearInterval(agent_status);\
    }\
  }\
</script>\
');
