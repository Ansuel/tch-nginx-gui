-- helper functions to wrap xtmctl utility from broadcom
local popen = io.popen
local execute = os.execute
local match = string.match
local tostring, commitApply = tostring, commitapply
local uciHelper = require("transformer.mapper.ucihelper")
local forEachOnUci = uciHelper.foreach_on_uci
local setOnUci = uciHelper.set_on_uci
local log = require("transformer.logger").new("mapper.xtmctl", 2)

local luabcm = require("luabcm")

local M = {}

-- get status of XtmDevice
-- \param addr [<port_mask.vpi.vci>|<port_mask.ptmpri_mask>]]
-- \returns two values (status,aal_type)
-- status - enabled or disabled for valid addr, otherwise ""
-- aal_type - ATM Adaptation Layer (AAL) currently in use on the PVC

function M.getXtmDeviceStatus(addr)
  local pipe = popen("xtmctl operate conn --show " .. addr)
  if not pipe then
    return ""
  end

  local status = ""
  local aal_type = ""
  for line in pipe:lines() do
    if match(line, "^ATM") or match(line, "^PTM") then
      status = match(line, "enabled") or match(line, "disabled") or ""
      aal_type = match(line, "aal%d")
      break
    end
  end
  pipe:close()
  return status,aal_type
end

-- enable/disable xtm device
-- \param addr [<port_mask.vpi.vci>|<port_mask.ptmpri_mask>]]
-- \param bActive (bool) if true enable else disable
-- \returns true if disable works, otherwise return false
function M.enableXtmDevice(addr, bActive)
  if execute("xtmctl operate conn --state " .. addr .. " " .. (bActive and "enable" or "disable")) ~= 0 then
    log:error("enable/disable XTM Device failed")
    return false
  end
end

-- get bonding status from xtmctl
-- return "1" if it is bonded, otherwise, return "0"
function M.getBondingStatus()
  local status = "0"
  local result = luabcm.getBondingStatus()
  if tostring(result) ~= "-1" then
      status = tostring(result["BondingStatus"])
  end
  return status
end

function M.setNetworkConfig(devname, vpi, vci)
  local flag = false
  local binding = {config = "network"}
  local name, ifname, nwVpi, nwVci
  binding.sectionname = "interface"
  forEachOnUci(binding, function(s)
    name = s['.name'] or ""
    ifname = s.device or s.ifname or ""
    nwVpi = s.vpi or ""
    nwVci = s.vci or ""

    if nwVpi~= "" or  nwVci ~= "" then
      if ifname == devname then
        binding.sectionname = name
        binding.option = "vci"
        setOnUci(binding, vci, commitApply)
        binding.option = "vpi"
        setOnUci(binding, vpi, commitApply)
        flag = true
      end
    end
  end)
  return flag
end

return M
