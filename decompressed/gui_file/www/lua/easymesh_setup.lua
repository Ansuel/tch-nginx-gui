-- The web worker delegates privileged initialization to the native RPC backend.
local M = {}
function M.can_initialize()
  local ok, values = pcall(require("datamodel").get, "rpc.system.easymesh.initializable")
  return ok and values and values[1] and values[1].value == "1" or false
end
function M.initialize()
  local proxy = require("datamodel")
  local ok, err = proxy.set("rpc.system.easymesh.initialize", "1")
  if ok then ok, err = proxy.apply() end
  if ok then require("easymesh_helper").invalidate_support() end
  return ok, err
end

-- Accept a pre-existing access point without taking ownership of its network.
-- A management client on br-lan is safe only with a physical Ethernet uplink
-- in that bridge and all LAN address-advertising services explicitly disabled.
local function existing_bridge_ready(bridge, uplink)
  if bridge.get("uci.network.interface.@lan.type") ~= "bridge" then return false end
  if bridge.get("uci.dhcp.dhcp.@lan.ignore") ~= "1" then return false end
  for _, option in ipairs({"dhcpv6", "ra", "ndp"}) do
    if bridge.get("uci.dhcp.dhcp.@lan." .. option) ~= "disabled" then return false end
  end
  local members = {}
  for token in (bridge.get("uci.network.interface.@lan.ifname") or ""):gmatch("%S+") do
    local name = string.untaint and string.untaint(token) or token
    members[name] = true
  end
  for token in uplink:gmatch("%S+") do
    local name = string.untaint and string.untaint(token) or token
    if not name:match("^[%w_%-]+$") or not members[name] or
      bridge.get("uci.ethernet.port.@" .. name .. ".wan") ~= "1" or
      require("lfs").attributes("/sys/class/net/br-lan/brif/" .. name, "mode") ~= "directory" then
      return false
    end
  end
  return true
end

function M.set_role(role)
  if role ~= "off" and role ~= "controller" and role ~= "booster" then return nil, "Invalid EasyMesh role." end
  if not require("easymesh_helper").is_supported() then return nil, "Native EasyMesh is unavailable." end
  if role == "booster" then
    local bridge = require("bridgehelper")
    local proto = bridge.get("uci.network.interface.@wan.proto")
    local localIP = (proto == "dhcp" or proto == "static") and
      bridge.get("uci.network.interface.@wan.ifname") == "br-lan"
    local configuredBridge = bridge.isBridged()
    if (not configuredBridge and not localIP) or (proto ~= "bridge" and not localIP) then
      return nil, "Configure Ethernet bridge mode in Broadband and Internet first. DHCP or Static IP on the bridge can retain management access."
    end
    local uplink = bridge.resolveUplinks(bridge.getUplink(true))
    if not uplink then return nil, "The booster requires an Ethernet uplink." end
    for name in uplink:gmatch("%S+") do
      if bridge.isDslInterface(name, "atm") or bridge.isDslInterface(name, "ptm") then
        return nil, "The booster requires an Ethernet uplink."
      end
    end
    if not (localIP and existing_bridge_ready(bridge, uplink)) then
      if not configuredBridge then
        return nil, "The existing bridge must have an Ethernet uplink and disabled LAN DHCP, DHCPv6, RA and NDP services."
      end
      -- Revalidate DHCP/RA suppression through the existing bridge implementation.
      local ok, err = bridge.enter()
      if not ok then return nil, err end
    end
  end
  local proxy = require("datamodel")
  local values = { ["uci.multiap.agent.enabled"] = role == "off" and "0" or "1",
    ["uci.multiap.controller.enabled"] = role == "controller" and "1" or "0" }
  -- Match the native UI's optional conductor flag. Fixed roles must not be
  -- overridden by automatic controller election on firmware which provides it.
  for path, value in pairs({
    ["uci.wifi_conductor.global.multiap_enabled"] = role == "off" and "0" or "1",
    ["uci.multiap.global.@controller_selection.enabled"] = "0",
  }) do
    local ok, state = pcall(proxy.get, path)
    local current = ok and state and state[1] and state[1].value
    if current == "0" or current == "1" then values[path] = value end
  end
  if role ~= "off" then
    local ok, state = pcall(proxy.get, "uci.wireless.wifi-bandsteer.@bs0.state")
    if ok and state and state[1] and state[1].value ~= nil then
      values["uci.wireless.wifi-bandsteer.@bs0.state"] = "0"
    end
  end
  local ok, err = proxy.set(values)
  if not ok then return nil, err end
  return proxy.apply()
end

return M
