local require = require

local M = {}

local nwcommon = require 'transformer.mapper.nwcommon'
local uciHelper = require 'transformer.mapper.ucihelper'
local activedevice = require 'transformer.shared.models.igd.activedevice'
local xtmconnection = require 'transformer.shared.models.igd.xtmconnection'

local split_key = nwcommon.split_key
local foreach_on_uci = uciHelper.foreach_on_uci
local xdsl_binding = { config = "xdsl", sectionname = "xdsl" }
local xtm_binding = { config = "xtm"}
local WANDeviceNames

-- If the devname is the first instance in xdsl config file, then add the keys formed without any modification.
-- Else append "devname" to the key formed.
local function addKeys(keys, devname, atmKey)
  if WANDeviceNames[1] == devname then
    keys[#keys+1] = atmKey
  else
    keys[#keys+1] = atmKey .. "|" .. devname
  end
end

local function loadAtmDevices(keys, devname, parentkey)
  local key2sectionname = {}
  xtm_binding.sectionname = "atmdevice"
  foreach_on_uci(xtm_binding, function(s)
    local _key = s._key
    if _key then
      _key = parentkey .. "|" .. _key
      keys[#keys+1] = _key
      key2sectionname[_key] = s[".name"]
    else
      local atmKey = "ATM|" .. s[".name"]
      addKeys(keys, devname, atmKey)
    end
  end)
  return key2sectionname
end

local function loadPtmDevices(keys, devname)
  local devs = {}
  local ptmKey
  xtm_binding.sectionname = "ptmdevice"
  foreach_on_uci(xtm_binding, function(s)
    local dev = s['.name']
    ptmKey = "ETH|"..dev
    addKeys(keys, devname, ptmKey)
    devs[dev] = true
  end)
  -- add placeholders
  xtm_binding.sectionname = "ptmdevice_placeholder"
  foreach_on_uci(xtm_binding, function(s)
    local name = s['.name']
    local dev = s.uciname or name:match("^(.*)_placeholder$")
    if dev and not devs[dev] then
      ptmKey = "ETH|"..dev
      addKeys(keys, devname, ptmKey)
      devs[dev] = true
    end
  end)
end

-- Load the "XDSL" config and store the dsl names
local function loadDslConfig()
  local devs = {}
  foreach_on_uci(xdsl_binding, function(s)
    devs[#devs+1] = s['.name']
  end)
  return devs
end

function M.entries(parentkey)
  local WANConnectionDevices = {}
  local devtype, devname = split_key(parentkey)
  local key2sectionname

  --Load the devnames from xdsl config file
  if not WANDeviceNames then
    WANDeviceNames = loadDslConfig()
  end

  if devtype == "ETH" or devtype == "MOB" then
    WANConnectionDevices[#WANConnectionDevices + 1] = parentkey
  elseif devtype == "DSL" then
    key2sectionname = loadAtmDevices(WANConnectionDevices, devname, parentkey)
    loadPtmDevices(WANConnectionDevices, devname)
    WANConnectionDevices = xtmconnection.loadStatic_keys(WANConnectionDevices)
  elseif devtype == "ACTIVE" then
    local intfs = activedevice.getActiveInterfaces(devname)
    for _, intf in ipairs(intfs) do
      WANConnectionDevices[#WANConnectionDevices+1] = "ACTIVE|"..intf
    end
  end
  return WANConnectionDevices, key2sectionname
end

return M
