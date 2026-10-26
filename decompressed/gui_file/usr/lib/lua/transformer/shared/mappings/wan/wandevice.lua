local require = require

local M = {}

local uci_helper = require 'transformer.mapper.ucihelper'
local activedevice = require 'transformer.shared.models.igd.activedevice'

local mobiled_binding = { config = "network", sectionname = "interface" }
local foreach_on_uci = uci_helper.foreach_on_uci

local function addDevice(devices, devType, devName)
  devices[#devices+1] = {
    type = devType,
    name = devName,
  }
end

local xdsl_binding = { config = "xdsl", sectionname = "xdsl" }
local function appendDSLDevices(devices)
  foreach_on_uci(xdsl_binding, function(s)
    addDevice(devices, "DSL", s[".name"])
  end)
end

local xtm_section = {
  ATM = "atmdevice",
  PTM = "ptmdevice",
}
local function xtmSection(xtmType)
  local section = xtm_section[xtmType]
  if not section then
    xtmType = "ATM"
    section = xtm_section[xtmType]
  end
  return section, xtmType
end

local xtm_binding = {config = "xtm"}
local function appendXtmDevices(devices, xtmType)
  xtm_binding.sectionname, xtmType = xtmSection(xtmType)
  foreach_on_uci(xtm_binding, function(s)
    addDevice(devices, xtmType, s[".name"])
  end)
end

local ethernet_binding = { config = "ethernet", sectionname = "port" }
local function appendEthernetDevices(devices)
  foreach_on_uci(ethernet_binding, function(s)
    if s['wan'] == '1' then
      addDevice(devices, "ETH", s[".name"])
    end
  end)
end

local gponl3_binding = { config = "gponl3", sectionname = "interface" }
local function appendGPONDevices(devices)
  local veip = {}
  local deviceFound = false
  foreach_on_uci(gponl3_binding, function(s)
    -- iterate over all Ethernet ports and check the 'wan' option
    if s.l3dev and not veip[s.l3dev] then
      for _, dev in ipairs(devices) do
        if dev.type == "ETH" and dev.name == s.l3dev then
          deviceFound = true
          break
        end
      end
      if not deviceFound then
        veip[s.l3dev] = true
        addDevice(devices, "ETH", s.l3dev)
      end
    end
  end)
end

local function appendMobileDevices(devices)
  foreach_on_uci(mobiled_binding, function(s)
    if s.proto == "mobiled" then
      addDevice(devices, "MOB", s[".name"])
    end
  end)
end

local function appendACTIVEDevices(devices)
  for _, intf in pairs(activedevice.getActiveDevices()) do
    addDevice(devices, "ACTIVE", intf)
  end
end

function M.listDevices()
  local devices = {}
  appendXtmDevices(devices, "ATM")
  appendXtmDevices(devices, "PTM")
  appendEthernetDevices(devices)
  appendGPONDevices(devices)
  appendMobileDevices(devices)
  return devices
end

function M.entries()
  local WANDevices = {}
  -- DSL Entries
  foreach_on_uci(xdsl_binding, function(s)
    WANDevices[#WANDevices + 1] = "DSL|" .. s['.name']
  end)
  -- Ethernet Entries
  foreach_on_uci(ethernet_binding, function(s)
    if s['wan'] == '1' then
      WANDevices[#WANDevices + 1] = "ETH|" .. s['.name']
    end
  end)
  -- GPON Entries
  local veip = {}
  local deviceFound = false
  foreach_on_uci(gponl3_binding, function(s)
    -- iterate over all Ethernet ports and check the 'wan' option
    if s.l3dev and not veip[s.l3dev] then
      local gponDevice = "ETH|" .. s.l3dev
      for _, dev in ipairs(WANDevices) do
        if dev == gponDevice then
          deviceFound = true
          break
        end
      end
      if not deviceFound then
        veip[s.l3dev] = true
        WANDevices[#WANDevices + 1] = gponDevice
      end
    end
  end)
  -- Mobiled Entries
  foreach_on_uci(mobiled_binding, function(s)
    if s.proto == "mobiled" then
        WANDevices[#WANDevices + 1] = "MOB|" .. s['.name']
    end
  end)
  -- WANConfig Entries
  for _, intf in pairs(activedevice.getActiveDevices()) do
    WANDevices[#WANDevices+1] = "ACTIVE|" ..intf
  end
  return WANDevices
end

return M
