
local require = require
local pairs = pairs

local M = {}

local uci_helper = require 'transformer.mapper.ucihelper'
local nwcommon = require 'transformer.mapper.nwcommon'
local ubus = require('transformer.mapper.ubus').connect()

local network = require 'transformer.shared.common.network'

local function lan_interfaces(networkName)
  local nw_interfaces = {} -- e.g. `lan`
  local ll_interfaces = {} -- e.g. `eth0`, `wl0`

  if networkName then -- query a specific network
    nw_interfaces[networkName] = true
    local lowerlayers = nwcommon.get_lower_layers(networkName)
    for _, l in pairs(lowerlayers or {}) do
      ll_interfaces[l] = true
    end
  else
    local laninterfaces = network.getLanInterfaces()

    for interface in pairs(laninterfaces or {}) do
      nw_interfaces[interface] = true
      local lowerlayers = nwcommon.get_lower_layers(interface)
      for _, l in pairs(lowerlayers or {}) do
        ll_interfaces[l] = true
      end
    end
  end

  return nw_interfaces, ll_interfaces
end

local function load_ubus_wireless(ubus_wireless)
  local wireless = ubus_wireless or {}
  if not wireless.ssid then
    wireless.ssid = ubus:call("wireless.ssid", "get", {}) or {}
  end
  if not wireless.radio then
    wireless.radio = ubus:call("wireless.radio", "get", {}) or {}
  end
  return wireless
end

function M.entries(networkName, ubus_wireless)
  local lan = {}
  local other = {}

  local lan_nw_interfaces, lan_ll_devices = lan_interfaces(networkName)

  local wireless = load_ubus_wireless(ubus_wireless)

  for wlanintf, v in pairs(wireless.ssid or {}) do
    local radio = wireless.radio[v.radio]
    local isRemote = radio and radio.remotely_managed == 1
    if isRemote then
      local wl_network = uci_helper.get_from_uci({
        config = "wireless",
        sectionname = wlanintf,
        option = "network",
        extended = true
      })

      if networkName == wl_network then -- belongs to the queried network, e.g. `lan`
        lan[#lan + 1] = wlanintf .. "_remote"
      else
        if not lan_nw_interfaces[wl_network] then -- belongs to a network that is not a LAN network
          other[#other + 1] = wlanintf .. "_remote"
        end
      end
    else
      if lan_ll_devices[wlanintf] then
        lan[#lan + 1] = wlanintf -- integrated and belongs to a LAN network
      else
        other[#other + 1] = wlanintf  -- integrated and does not belong to a LAN network
      end
    end
  end

  return lan, other
end

function M.ssidName(key)
  return key:match("^(.+)_remote$") or key
end


return M
