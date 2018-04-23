local M = {}

local open, remove = io.open, os.remove
local uci = require("transformer.mapper.ucihelper")
local nudBinding = { config = "nud", sectionname = "diag" }
local networkBinding = { config = "network" }
local set_on_uci = uci.set_on_uci
local get_from_uci = uci.get_from_uci
local ubusConnection = require("transformer.mapper.ubus").connect()
local configChanged

-- remove the files that store the ping results
function M.clear_ping_results()
  remove("/tmp/nud")
  remove("/tmp/nud_ping")
end

local valueMap = {
  enable = "0",
  result = "fail",
  rtt = "0",
}

-- set the default values to the options in uci
function setDefault()
  set_on_uci(nudBinding, "nud")
  for param, value in pairs(valueMap) do
    setOnUci(param, value, commitapply)
  end
end

-- create config file if it does not exist
-- create "nud" section if it does not exist
function M.startup()
    local cursor = require("uci").cursor()
    cursor:ensure_config_file("nud")
    cursor:close()
    nudBinding.option = nil
    local value = get_from_uci(nudBinding)
    if value == '' then
      setDefault()
      uci.commit(nudBinding)
    end
end

-- get the 6rd interfaces
-- @return the 6rd interfaces
local function get6RDInterfaces()
  local ipv6rdEntries = {}
  networkBinding.sectionname = "interface"
  uci.foreach_on_uci(networkBinding, function(s)
    if s.proto and s.proto == "6rd" then
      ipv6rdEntries[#ipv6rdEntries + 1] = s[".name"]
    end
  end)
  return ipv6rdEntries
end

-- Fetch the ubus call for the interface specified
-- @param intf interface for which ubus call is fetched
local function getInterfaceStatus(intf)
  return ubusConnection:call("network.interface." .. intf, "status", {})
end

-- Retrieve value from uci
-- @param pname parameter name
function M.uci_nud_get(pname)
  nudBinding.option = pname
  return get_from_uci(nudBinding)
end

-- Set the value in uci
-- @param pname parameter name
-- @param pvalue parameter value
function setOnUci(pname, pvalue, commitapply)
  nudBinding.option = pname
  set_on_uci(nudBinding, pvalue, commitapply)
  configChanged = true
end

-- Set function for the params
-- @param pname parameter name
-- @param pvalue parameter value
function M.uci_nud_set(pname, pvalue, commitapply)
  if pname == "enable" then
    M.clear_ping_results()
    if pvalue == "1" then
      local ipAddr
      local interfaces = get6RDInterfaces()
      for _, intf in ipairs(interfaces) do
        local intfStatus = getInterfaceStatus(intf)
        if intfStatus and not intfStatus.dynamic then
          networkBinding.sectionname = intf
          networkBinding.option = "peeraddr"
          ipAddr = get_from_uci(networkBinding)
        elseif intfStatus and intfStatus["ipv6-address"] and intfStatus["ipv6-address"][1] then
          ipAddr = intfStatus["ipv6-address"][1]["address"] or ""
        end
      end
      if ipAddr then
        nudBinding.option = "host"
        setOnUci("host", ipAddr, commitapply)
      end
    end
  end
  setOnUci(pname, pvalue, commitapply)
end

function M.uci_nud_commit()
  if configChanged then
    uci.commit(nudBinding)
    configChanged = false
  end
end

function M.uci_nud_revert()
  if configChanged then
    uci.revert(nudBinding)
    configChanged = false
  end
end

return M
