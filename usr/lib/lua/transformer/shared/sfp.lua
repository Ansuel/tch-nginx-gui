local open, popen, string = io.open, io.popen, string
local match, find, len, sub, format, floor = string.match, string.find, string.len, string.sub, string.format, math.floor
--local logger = require("transformer.logger")
--logger.init(6, false)
--local logger = logger.new("optical", 6)
local uci = require("transformer.mapper.ucihelper")
local get_from_uci = uci.get_from_uci

local M = {}

--- Retrieves SFP flag
-- @return #number type is SFP flag 0/1
function M.readSFPFlag()
  local sfpFlag = get_from_uci({config = "env", sectionname = "rip", option = "sfp"})
  if sfpFlag == '1' then
    return 1
  end
  return 0
end

function M.getSfpctlFormat(option)
  local ctl = popen("sfpi2cctl -get -format " .. option)
  local output = ctl:read("*a")
  ctl:close()
  return output
end

function M.getSfpStatus()
  local ctl = popen("cat /proc/sfp_status")
  local output = ctl:read("*a")
  ctl:close()
  return output
end

function M.getCrossbarStatus()
  local ctl = popen("cat /proc/crossbar_status")
  local output = ctl:read("*a")
  ctl:close()
  return output
end

function M.getLinkStatus(port)
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
  return M.getLinkStatus(10)
end

function M.getSfpLinkStatus()
  return M.getLinkStatus(9)
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
--- Get SFP phy state
----@return #string PhyState is:
---- "connect" (sfp plugin and fiber connect)
---- "disconnect" (sfp unplugin or fiber disconnect)
function M.getSfpPhyState()
  local PhyState = "disconnect"
  local state = M.getSfpStatus()
  if state and match(state, "link up") then
    PhyState = "connect"
  end
  return PhyState
end

--- Get the SFP type
-- @return #string type is gpon/p2p/none
function M.getSFPType()
  local type = "none"
  local output = M.getSfpctlFormat("vendpn")
  local value = match(output, "%[(.+)%]")
  if value and value ~= "" then
      if find(value, "LTE3415") or find(value, "FDA2000") then
        type = "gpon"
      else
        type = "p2p"
      end
  end
  return type
end

-- Reset all stats
function M.resetStatsGponSFP()
  os.execute("sfp_get.sh --counter_reset")
end

--- Get the SFP Vendor Name
-- @return #string vendorname
function M.getSFPVendorName()
  local vendName = M.getSfpctlFormat("vendname")
  if vendName then
    return vendName:match("%[(.+)%]") or ""
  end
  return ""
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
function M.getGponSFP(option)
  local PhyState = M.getSfpPhyState()
  if PhyState == "connect" then
     local cmd = popen("sfp_get.sh --"..option)
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

local function getGponMatch(output, param)
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
function M.getGponStats(param)
  local output = M.getGponSFP(statsEntries[param])
  return getGponMatch(output, param)
end

--- Get All GPON statistics information
-- @return #table includes tr181 statistics information
function M.getGponAllStats()
  local StatsValues = {}
  local output = M.getGponSFP("allstats")
  for param in pairs(statsEntries) do
    StatsValues[param] = getGponMatch(output, param)
  end
  return StatsValues
end

local levelEntries = {
  TransmitOpticalLevel = { 
    option = "txpwr",
    match = "Txpwr",
  },
  OpticalSignalLevel = {
    option = "rssi",
    match = "Rssi"
  },
}

function M.getTxDis()
  local dis = M.getSfpctlFormat("tx_dis")
  if dis and match(dis, "Tx_Diable on") then
    return "on"
  end
  return "off"
end

--- Get SFP OpticalSignalLevel or TransmitOpticalLevel value
-- @param #string level item "OpticalSignalLevel/TransmitOpticalLevel"
-- @return #string level value
function M.getLevel(param)
  if M.getTxDis() == "on" then
    return "-99.000000"
  end
  local entry = levelEntries[param]
  if entry then
    local output = M.getSfpctlFormat(entry["option"])
    local value = match(output, entry["match"] .. ":(.-)%sdBm")
    return value or "-255.000000"
  else
    return "-255.000000"
  end
end

function M.getTr181Level(param)
  local entry = levelEntries[param]
  if entry then
    local output = M.getSfpctlFormat(entry["option"])
    local value = match(output, entry["match"] .. ":(.-)%sdBm")
    value = value and floor(value * 1000) or 0
    if param == "OpticalSignalLevel" then
      return value <= -65536 and "-65536" or value >= 65534 and "65534" or tostring(value)
    elseif param == "TransmitOpticalLevel" then
      return value <= -127500 and "-127500" or value >= 0 and "0" or tostring(value)
    end
  end
  return "0"
end

function M.getEnable()
  local enable = get_from_uci({config="optical", sectionname="optical", option="enable"})
  if enable == nil or enable == "" then
    enable = "1"
  end
  return enable
end

--- Get SFP Status,OpticalSignalLevel,TransmitOpticalLevel information
-- @return #table includes tr181 Status,OpticalSignalLevel,TransmitOpticalLevel information
function M.getOpticals()
  return {
    Enable = M.getEnable(),
    Status = M.getStatus(),
    OpticalSignalLevel = M.getLevel("OpticalSignalLevel"),
    TransmitOpticalLevel = M.getLevel("TransmitOpticalLevel"),
  }
end

function M.getTr181Opticals()
  return {
    Enable = '1',
    Status = M.getStatus(),
    OpticalSignalLevel = M.getTr181Level("OpticalSignalLevel"),
    TransmitOpticalLevel = M.getTr181Level("TransmitOpticalLevel"),
  }
end

local _convertTable = {
    [0] = "0",
    [1] = "1",
    [2] = "2",
    [3] = "3",
    [4] = "4",
    [5] = "5",
    [6] = "6",
    [7] = "7",
    [8] = "8",
    [9] = "9",
    [10] = "A",
    [11] = "B",
    [12] = "C",
    [13] = "D",
    [14] = "E",
    [15] = "F",
    [16] = "G",
}

local function Convert(dec, x)
    local function fn(num, t)
        if(num < x) then
            table.insert(t, num)
        else
            fn( math.floor(num/x), t)
            table.insert(t, num%x)
        end
    end

    local x_t = {}
    fn(dec, x_t, x)

    return x_t
end 

local function ConvertDec2X(dec, x)
    local x_t = Convert(dec, x)
    local text = ""
    for k, v in ipairs(x_t) do
        text = text.._convertTable[v]
    end 
    return text 
end

function M.checkErrStatus()
  local ctl = popen("sfpi2cctl -get -raw 1 110 1")
  local output = ctl:read("*a")
															  
  ctl:close()
  if match(output, "read raw data failed") then
    return -1
  end
  local hexstr = sub(output, len(output) - 3, len(output) - 2)
  if hexstr then
    local dec = tonumber(hexstr, 16)
    if dec then
      local bin = ConvertDec2X(dec, 2)
      -- check the bit 2
      if bin and len(bin) > 2 then
        if sub(bin, len(bin) - 2, len(bin) - 2) == '1' then
          return 1
        end
      end
    end
  end
  return 0
end

--- Get GPON status
-- @return #string gpon status
function M.getGponLinkStatus()
  local status = "Unknown"
  local output = M.getGponSFP("state")
    if output ~= "" then
      if match(output, "%(O5%)") then
        status = "Up"
      elseif match(output, "%(O1%)") then
        status = "Dormant"
      else
        status = "LowerLayerDown"
      end
  end
  return status
end

--- Get SFP status
-- @return #string SFP status 
function M.getStatus()
  local phyState = M.getSfpStatus()
  local status = "Unknown"
  if match(phyState, "unplug") then
    return "NotPresent"
  elseif match(phyState, "plug in") then
    local err = M.checkErrStatus()
    if err == 1 then
      return "Error"
    elseif err == -1 then
      return "NotPresent"
    end
    local dis = M.getTxDis()
    if dis == "on" then
      return "Down"
    end
    return "Dormant"
  elseif match(phyState, "link up") then
    local dis = M.getTxDis()
    if dis == "on" then
      return "Down"
    end
    local type = M.getSFPType()
    if type == "gpon" then
      return M.getGponLinkStatus()
    elseif type == "p2p" then   -- P2P part need to implement here
      return ""
    end
  end
  return status
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
  local type = M.getSFPType()
  if type == "gpon" then
    return M.getGponStats(param)
  else
    return "0"
  end
end

--- Get All SFP statistics information
-- @return #table includes tr181 statistics information  
function M.getAllStats()
  local type = M.getSFPType()
  if type == "gpon" then
    return M.getGponAllStats()
  else
    return ""
  end
end

return M
