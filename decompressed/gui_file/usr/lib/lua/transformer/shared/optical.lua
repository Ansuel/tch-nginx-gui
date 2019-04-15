local popen, string = io.popen, string
local match, find, floor, len, sub, format = string.match, string.find, math.floor, string.len, string.sub, string.format
local ubus = require("transformer.mapper.ubus").connect()
local upper = string.upper
local lfs = require("lfs")
local open = io.open
local uci = require("transformer.mapper.ucihelper")
local getFromUci = uci.get_from_uci
local forEachOnUci = uci.foreach_on_uci

local log = require('tch.logger')

local M = {}

local boardType

function M.getBoardtype()
  if boardType then
    return boardType
  end
  local bType
  local sfpFlag = getFromUci({config = "env", sectionname = "rip", option = "sfp"})
  if sfpFlag == '1' then
    sfpFlag = true
  else
    sfpFlag = false
  end
  local pspFlag = true
  local ctl = io.open("/bin/pspctl", "r")
  if not ctl then
     pspFlag = false
  else
     ctl:close()
  end
  if pspFlag and sfpFlag then
    bType = "gpon_sfp"
  elseif pspFlag and not sfpFlag then
    bType = "gpon"
  elseif not pspFlag and sfpFlag then
    bType = "sfp"
  else
    bType = "none"
  end
  boardType = bType
  return bType
end

local LevelEntries = {
  TransmitOpticalLevel = "US_TX_Power",
  OpticalSignalLevel = "DS_Rx_RSSI"
}

-- default threshold values for gpon and p2p
local opticalThresholdValues = {
  gpon = {
    LowerOpticalThreshold = "-29000",
    UpperOpticalThreshold = "-7000",
    LowerTransmitPowerThreshold = "-500",
    UpperTransmitPowerThreshold = "6000",
  },
  p2p = {
    LowerOpticalThreshold = "-33000",
    UpperOpticalThreshold = "0",
    LowerTransmitPowerThreshold = "-10000",
    UpperTransmitPowerThreshold = "-2700",
  },
  none = {
    LowerOpticalThreshold = "-127500",
    UpperOpticalThreshold = "-127500",
    LowerTransmitPowerThreshold = "-63500",
    UpperTransmitPowerThreshold = "-63500",
  },
}

function M.getUbusObject()
  local bType = M.getBoardtype()
  local str
  if bType == "sfp" then
    str = "optical"
  elseif bType == "gpon" or bType == "gpon_sfp" then
    str = "gpon"
  end
  return str
end

function M.getTrsvInfo(info, paramName)
  local str = M.getUbusObject()
  if str then
    str = string.format("%s.trsv", str)
  else
    log:error("No ubus call for trsv is provided\n")
    return nil
  end
  local result = ubus:call(str, "get_info", { info = info })
  if result == nil then
    log:error(string.format("Cannot retrieve trsv info %s\n", info))
    return nil
  end
  local data = result[info]
  local key, val = "", ""
  for key, val in pairs (data) do
    key = key:match ("[%S]+")
    if (key == paramName) then
      return val
    end
  end
end

function M.getWanconf(paramName)
  local str = M.getUbusObject()
  if str then
    str = string.format("%s.wanconf", str)
  else
    log:error("No ubus call for wanconf is provided\n")
    return nil
  end
  local result = ubus:call(str, "get", {})
  if result == nil then
    log:error("Cannot retrieve wanconf info\n")
    return nil
  end
  local data = result["WanConf"]
  local key, val = "", ""
  for key, val in pairs (data) do
    if (key == paramName) then
      return val
    end
  end
end

function M.getVendorName()
  local vendName = M.getTrsvInfo("vendor", "Name")
  return vendName or ""
end

--- Get SFP OpticalSignalLevel or TransmitOpticalLevel value
-- @param #string level item "OpticalSignalLevel/TransmitOpticalLevel"
-- @return #string level value
function M.getLevel(param)
  local entry = LevelEntries[param]
  if entry then
    local value = M.getTrsvInfo("status", entry)
    if value and value ~= "" then                                     
      value = tonumber(value)                                                             
      value = value and floor(value * 1000) or 0    
    else                                                                            
      return "0"                                                         
    end
    if param == "OpticalSignalLevel" then
      return value <= -65536 and "-65536" or value >= 65534 and "65534" or tostring(value)
    elseif param == "TransmitOpticalLevel" then
      return value <= -127500 and "-127500" or value >= 0 and "0" or tostring(value)
    end
  end
  return "0"
end

function M.getLinkStatus()
  local value = M.getTrsvInfo("status", "DS_Rx_RSSI")
  local status = "unknown"
  if value and value ~= "" then
    value = tonumber(value)
    if value == -255.00000 then
      status = "unplug"
    elseif value >= -99.00000 and value <= -35.00000 then
      status = "plugin"
    elseif value > -35.00000 then
      status = "linkup"
    end
  end
  return status
end

function M.getThresholdValues(param)
  local wanType = M.getWantype()
  if wanType == "xepon_ae_p2p" then
    return opticalThresholdValues["p2p"][param]
  elseif wanType == "gpon" or wanType == "xepon_ae" then
    return opticalThresholdValues["gpon"][param]
  else
    return opticalThresholdValues["none"][param]
  end
end

function M.getEnable()
  local enable = M.getTrsvInfo("control", "US_TX_Control")
  if enable == "Disabled" then
    enable = "0"
  elseif enable == "Enabled" then
    enable = "1"
  end
  return enable or ""
end

function M.setEnable(value)
  local str = M.getUbusObject()
  if str then
    str = string.format("%s.trsv", str)
  else
    log:error("No ubus call for trsv is provided\n")
    return ""
  end
  local enable = M.getEnable()
  if enable ~= value then
    if value == "1" then
      enable = true
    elseif value == "0" then
      enable = false
    end
    ubus:call(str, "set_ustx", { enable = enable })
    local boardtype = M.getBoardtype()
    if boardtype == "sfp" then
      if not enable then
        ubus:send("sfp", {status = "tx_disable"})
      else
        ubus:send("sfp", {status = "tx_enable"})
      end
    end
  end
end

function M.getGponstate()
  local ctl = popen("gponctl getstate")
  local output = ctl:read("*a")
  ctl:close()
  local status = "LowerLayerDown"
  if output and output ~= "" then
      if match(output, "%(O5%)") then
        status = "Up"
      elseif match(output, "%(O1%)") then
        status = "Dormant"
      end
  end
  return status
end

function M.getWantype()
  local wanType = "unknown"
  local RdpaWanType = M.getWanconf("WAN Type")
  if RdpaWanType then
    if RdpaWanType == "GBE" then
      local wanOEMac = M.getWanconf("WAN EMAC")
      if wanOEMac then
        if wanOEMac == "EPONMAC" then
          wanType = "xepon_ae"
        else
          wanType = "gbe"
        end
      end
    elseif RdpaWanType == "AE" or RdpaWanType == "ETH_WAN" then
      wanType = "gbe"
    elseif RdpaWanType == "XGS" or  RdpaWanType == "XGPON1" or RdpaWanType == "GPON" then
      wanType = "gpon"
    elseif RdpaWanType == "SFP_GPON" then
      wanType = "xepon_ae"
    elseif RdpaWanType == "SFP_P2P" then
      wanType = "xepon_ae_p2p"
    end
  end
  return wanType
end

local ethernetBinding = { config = "ethernet", sectionname = "port" }

--- Function to retrieve Ethwan interface
-- @return #string wan interface
function M.getWanInterface()
  local wanInterface
  forEachOnUci(ethernetBinding, function(s)
    if s.wan == "1" then
      wanInterface = s[".name"]
      return false
    end
  end)
  return wanInterface
end

function M.getP2pState()
  local ubusData = ubus:call("network.interface.wan", "status", {}) or {}
  local up = ubusData["up"]
  if up == true then
    return "up"
  end
  return "LowerLayerDown"
end

--- Get GPON status
-- @return #string gpon status
function M.getSfpState()
  local status = "LowerLayerDown"
  local output = M.getSFPInfo("state")
  if output ~= "" then
      if match(output, "%(O5%)") then
        status = "Up"
      elseif match(output, "%(O1%)") then
        status = "Dormant"
      end
  end
  return status
end

--- Get SFP status
-- @return #string SFP status
function M.getStatus()
  local status = "Unknown"
  local phyState = M.getLinkStatus()
  if match(phyState, "unplug") then
    return "NotPresent"
  elseif match(phyState, "plugin") then
    local enable = M.getEnable()
    if enable == "0" then
      return "Down"
    end
    return "Dormant"
  elseif match(phyState, "linkup") then
    local enable = M.getEnable()
    if enable == "0" then
      return "Down"
    end
    local wanType = M.getWantype()
    if wanType == "xepon_ae" then
      return M.getSfpState()
    elseif wanType == "xepon_ae_p2p" then
      return M.getP2pState()
    else --GPON XGPON XGS
      return M.getGponstate()
    end
  end
  return status
end

--- Calls sfp_get.sh with the given option and returns the output
-- @param #string option value is as following
-- allstats             : All SFP stats
-- state                : ONU state
-- optical_info         : SFP optical info
-- bytes_sent           : SFP sent bytes
-- bytes_rec            : SFP received bytes
-- packets_sent         : SFP sent packets
-- packets_rec          : SFP received packets
-- errors_sent          : SFP sent errors
-- errors_rec           : SFP received errors
-- discardpackets_sent  : SFP sent discard  packets
-- discardpackets_rec   : SFP received discard packets
function M.getSFPInfo(option)
  local PhyState = M.getLinkStatus()
  if PhyState == "linkup" then
     local cmd = popen("sfp_get.sh --" .. option)
     local output = cmd:read("*a")
     cmd:close()
     return output or ""
  else
     return ""
  end
end

local statsEntries = {
  BytesSent = "bytes_sent",
  BytesReceived = "bytes_rec",
  PacketsSent = "packets_sent",
  PacketsReceived = "packets_rec",
  ErrorsSent = "errors_sent",
  ErrorsReceived = "errors_rec",
  DiscardPacketsSent = "discardpackets_sent",
  DiscardPacketsReceived = "discardpackets_rec",
}

local function getStatsMatch(output, param)
  local value = match(output, param..":%s+(.-)%c")
  return value or "0"
end

--- Get GPON separate statistics information
-- @param #string statistics item as following
--   BytesSent
--   BytesReceived
--   PacketsSent
--   PacketsReceived
--   ErrorsSent
--   ErrorsReceived
--   DiscardPacketsSent
--   DiscardPacketsReceived
-- @return #string statistics information
function M.getPonAeStats(param)
  local output = M.getSFPInfo(statsEntries[param])
  if output == "" then
    return "0"
  end
  return getStatsMatch(output, param)
end

local intfStatsEntries = {
  BytesSent = "tx_bytes",
  BytesReceived = "rx_bytes",
  PacketsSent = "tx_packets",
  PacketsReceived = "rx_packets",
  ErrorsSent = "tx_errors",
  ErrorsReceived = "rx_errors",
  DiscardPacketsSent = "tx_dropped",
  DiscardPacketsReceived = "rx_dropped",
}

function M.getIntfstats(intf, param)
  local gponPath = string.format("/sys/class/net/%s/statistics/", intf)
  param = intfStatsEntries[param]
  local value
  if lfs.attributes(gponPath, "mode") == "directory" then
    local statsFile = gponPath .. param
    local fd = open(statsFile, "r")
    if fd then
      value = fd:read("*all")
      if value then
        value = value:match("(.-)%c")
      end
      fd:close()
    end
  end
  return value or "0"
end

function M.getGponstats(param)
  return M.getIntfstats("gpondef", param)
end

function M.getP2pStats(param)
  local intf = M.getWanInterface()
  return M.getIntfstats(intf, param)
end

--- Get All GPON statistics information
-- @return #table includes tr181 statistics information
function M.getPonAeAllStats()
  local StatsValues = {}
  local output = M.getSFPInfo("allstats")
  for param in pairs(statsEntries) do
    if output == "" then
      StatsValues[param] = "0"
    else
      StatsValues[param] = getStatsMatch(output, param)
    end
  end
  return StatsValues
end

function M.getGponAllStats()
  local StatsValues = {}
  for param in pairs(intfStatsEntries) do
    StatsValues[param] = M.getIntfstats("gpondef", param)
  end
  return StatsValues
end

function M.getP2pAllStats()
  local intf = M.getWanInterface()
  local StatsValues = {}
  for param in pairs(intfStatsEntries) do
    StatsValues[param] = M.getIntfstats(intf, param)
  end
  return StatsValues
end

--- Get SFP separate statistics information
-- @param #string statistics item as following
--   BytesSent
--   BytesReceived
--   PacketsSent
--   PacketsReceived
--   ErrorsSent
--   ErrorsReceived
--   DiscardPacketsSent
--   DiscardPacketsReceived
-- @return #string statistics information
function M.getStats(param)
  local wanType = M.getWantype()
  if wanType == "xepon_ae" then
    return M.getPonAeStats(param)
  elseif wanType == "xepon_ae_p2p" then
    return M.getP2pStats(param)
  elseif wanType == "gpon" then
    return M.getGponstats(param)
  end
  return "0"
end

--- Get All SFP statistics information
-- @return #table includes tr181 statistics information
function M.getAllStats()
  local wanType = M.getWantype()
  if wanType == "xepon_ae" then
    return M.getPonAeAllStats()
  elseif wanType == "xepon_ae_p2p" then
    return getP2pAllStats()
  elseif wanType == "gpon" then
    return M.getGponAllStats()
  end
  return "0"
end

function M.getCrossbarStatus()
  local ctl = popen("cat /proc/ethernet/crossbar_status")
  local output = ctl:read("*a")
  ctl:close()
  return output
end

function M.getPortStatus(port)
  local link = ""
  local ctl = popen("ethctl eth4 media-type port " .. port .. " 2>&1")
  local output = ctl:read("*a")
  ctl:close()
  if output then
    if match(output, "Link is up") then
      link = "Up"
    else
      link = "Down"
    end
  end
  return link
end

function M.getGPHY4LinkStatus()
  return M.getPortStatus(10)
end

function M.getSfpLinkStatus()
  return M.getPortStatus(9)
end

function M.getWanType()
  local status = M.getCrossbarStatus()
  local wanType = ""
  if status then
    if match(status, "WAN Port is connected to: AE") then
      wanType = "SFP"
    elseif match(status, "WAN Port is connected to: GPHY4") then
      wanType = "GPHY4"
    end
  end
  return wanType
end

function M.getGPHY4Mode()
  local status = M.getCrossbarStatus()
  local mode = ""
  if status then
    if match(status, "Switch Port %d is connected to: GPHY4") then
      mode = "Lan"
    else
      mode = "Wan"
    end
  end
  return mode
end

-- Reset all stats
function M.resetStatsGponSFP()
  os.execute("sfp_get.sh --counter_reset")
end

return M
