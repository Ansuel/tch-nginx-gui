local require = require
local ipairs = ipairs
local unpack = unpack
local setmetatable = setmetatable
local tostring = tostring

local os = require 'os' -- easier to unit test like this

local M = {}

local ucihelper = require 'transformer.mapper.ucihelper'
local ubus = require('transformer.mapper.ubus').connect()
local nwcommon = require 'transformer.mapper.nwcommon'

local netmask2mask = nwcommon.netmask2mask

local network_interface = {config="network", sectionname="interface"}

local function load_network_interfaces()
  local intfs = {}
  ucihelper.foreach_on_uci(network_interface, function(intf)
    intfs[intf['.name']] = intf
  end)
  return intfs
end

local UbusInterfaceData = {}
UbusInterfaceData.__index = UbusInterfaceData

local function newUbusInterfaceData()
  return setmetatable({}, UbusInterfaceData)
end
M.UbusInterfaceData = newUbusInterfaceData

local function load_ubus_data()
  local intfs = ubus:call("network.interface", "dump", {})
  for _, intf in ipairs(intfs.interface) do
    intfs[intf.interface] = intf
  end
  return intfs
end

function UbusInterfaceData:load()
  local data = self._ubus_data
  if not data then
    data = load_ubus_data()
    self._ubus_data = data
  end
  return data
end

local function load_ubus_mobile_data()
  local data = ubus:call("mobiled.network", "sessions", {})
  if data then
    data.interface = {}
    data.sessions = data.sessions or {}
    for _, session in ipairs(data.sessions) do
      if session.session_state=='connected' and session.interface then
        data.interface[session.interface] = session
      end
    end
  else
    data = {
      sessions = {},
      interface = {}
    }
  end
  return data
end

function UbusInterfaceData:load_mobile()
  local data = self._ubus_mobile_data
  if not data then
    data = load_ubus_mobile_data()
    self._ubus_mobile_data = data
  end
  return data
end

function UbusInterfaceData:get(ifname)
  local data = self:load()
  return data[ifname]
end


-- this is the default info used for missing secondary interfaces
local default_intf = {
  proto = 'static',
  ipaddr = '0.0.0.0', -- disabled!
}

-- map proto to address mode
local proto_addr_mode = {
  static = {'ipv4', 'static'},
  dhcp = {'ipv4', 'dynamic'},
  pppoe = {'ipv4', 'dynamic'},
  pppoa = {'ipv4', 'dynamic'},
  dhcpv6 = {'ipv6', 'dynamic'},
  ['6rd'] = {'ipv6', 'dynamic'},
  mobiled = {'mobiled', 'dynamic'}
}
local unknown_proto = {"unknown", "unknown"}

local function getAddrModeForProto(proto)
  return unpack(proto_addr_mode[proto] or unknown_proto)
end

local function get_ipv4_address_for_interface(ifname, ubus_data)
  local intf = ubus_data:get(ifname)
  local addresses = intf and intf['ipv4-address'] or {}
  local addr = addresses[1]
  if addr then
    return addr.address, netmask2mask(addr.mask)
  end
end

local function get_normal_ipv4_address(ifname, intf, mode, ubus_data)
  local addr = {
    ifname = ifname,
    proto = intf.proto,
    disabled_info = intf.disabled_info,
  }
  if mode == "static" then
    addr.ipaddr = intf.ipaddr or '0.0.0.0'
    addr.netmask = intf.netmask
  elseif mode == "dynamic" then
    -- get the correct ip address (if available)
    local ip, mask = get_ipv4_address_for_interface(ifname, ubus_data)
    addr.ipaddr = ip
    addr.netmask = mask
  end
  return addr
end

local function get_mobile_ipv4_address(ifname, ubus_data)
  local sessions = ubus_data:load_mobile()
  local addr = {
    ifname = ifname,
    mobile = true,
    ipaddr = "",
    netmask = "",
    proto = "",
  }
  local session = sessions.interface[ifname] --the active session for the interface
  if session then
    if session.proto=="static" then
      addr.ipaddr = session.static.ipv4_addr
      addr.netmask = session.static.ipv4_subnet
      addr.proto = "static"
    elseif session.proto=="dhcp" then
      addr.proto = "dhcp"
      addr.ipaddr, addr.netmask = get_ipv4_address_for_interface(ifname.."_4", ubus_data)
    elseif session.proto:match("^ppp") then
      addr.proto = session.proto
      addr.ipaddr, addr.netmask = get_ipv4_address_for_interface(ifname.."_ppp", ubus_data)
    elseif session.proto=="router" then
      addr.proto = "static"
      if type(session.router) == "table" then
        addr.ipaddr = session.router.ipv4_addr
      end
    end
  end
  return addr
end

local function add_ipv4_address_entry(ifname, intf, ipv4, ubus_data)
  local addr
  local ver, mode = getAddrModeForProto(intf.proto)
  if ver=='ipv4' then
    addr = get_normal_ipv4_address(ifname, intf, mode, ubus_data)
  elseif ver=='mobiled' then
    addr = get_mobile_ipv4_address(ifname, ubus_data)
  end
  ipv4[#ipv4+1] = addr
end

local function isLoopback(intf)
  local ipv4 = intf and intf['ipv4-address']
  ipv4 = ipv4 and ipv4[1]
  return ipv4 and ipv4.address=='127.0.0.1'
end

local function add_ipv6_link_local(ifname, main_intf, ipv6, ubus_data)
  local intf = ubus_data:get(ifname)
  local addr = {
    ifname = ifname,
  }
  if isLoopback(intf) then
    addr.ipaddr = "::1"
    addr.proto = "wellknown"
  else
    addr.proto = "local"
    addr.ipaddr = "" -- will be filled in in mapping
    addr.l3_device = intf and intf.l3_device
  end
  if main_intf.proto == 'mobiled' then
    addr.mobile = true
  end
  ipv6[#ipv6+1] = addr
end

local ipv6_addr_fields = {"ipv6-address", "ipv6-prefix-assignment"}
local function getIPv6Address(ubus_data, ifname)
  local intf = ubus_data:get(ifname)
  if intf then
    for _, field in ipairs(ipv6_addr_fields) do
      local addr_list = intf[field]
      if addr_list then
        local addr = addr_list[1]
        if addr then
          return addr, intf.l3_device
        end
      end
    end
  end
end

local function get_ipv6_address_for_interface(addr, ifname, ubus_data)
  local addr_info, l3_device
  addr_info, l3_device = getIPv6Address(ubus_data, ifname)
  local addr_found = addr_info~=nil
  if addr_info then
    local now = os.time()
    addr.ipaddr = addr_info.address
    if addr_info.preferred then
      addr.preferred = now + addr_info.preferred
    end
    if addr_info.valid then
      addr.valid = now + addr_info.valid
    end
  end
  addr.l3_device = l3_device
  return addr_found
end

local function get_normal_ipv6_address(ifname, intf, ubus_data)
  local addr= {
    ifname = ifname,
    disabled_info = intf.disabled_info,
    proto = intf.proto,
  }
  get_ipv6_address_for_interface(addr, ifname, ubus_data)
  return addr
end

local function get_mobiled_ipv6_address(ifname, ubus_data)
  local sessions = ubus_data:load_mobile()
  local addr = {
    ifname = ifname,
    mobile = true,
    ipaddr = "",
  }
  local session = sessions.interface[ifname] --the active session for the interface
  local addr_found = true
  if session then
    if session.proto=="static" then
      addr.proto = "static"
      addr_found = get_ipv6_address_for_interface(addr, ifname, ubus_data)
    elseif session.proto=="dhcp" then
      addr.proto = "dhcp"
      addr_found = get_ipv6_address_for_interface(addr, ifname.."_6", ubus_data)
    elseif session.proto=="router" then
      addr.proto = "static"
      if type(session.router) == "table" and session.router.ipv6_addr then
        addr = session.router.ipv6_addr
      end
    elseif session.proto:match("^ppp") then
      addr.proto = session.proto
      addr_found = get_ipv6_address_for_interface(addr, ifname.."_ppp", ubus_data)
    end
  end
  if addr_found then
    return addr
  end
end

local function add_ipv6_address_entry(ifname, intf, ipv6, ubus_data)
  local ver = getAddrModeForProto(intf.proto)
  local addr
  if ver=="ipv6" then
    addr = get_normal_ipv6_address(ifname, intf, ubus_data)
  elseif ver == "mobiled" then
    addr = get_mobiled_ipv6_address(ifname, ubus_data)
  end
  ipv6[#ipv6+1] = addr
end

local function mobile_profile_id_for_interface(ifname, ubus_data)
  local sessions = ubus_data:load_mobile()
  for _, session in ipairs(sessions.sessions) do
    if session.interface == ifname then
      return tostring(session.profile)
    end
  end
end

local function load_mobile_profile(profile_id)
  local profile
  ucihelper.foreach_on_uci({config='mobiled', sectionname='profile'}, function(s)
    if s.id == profile_id then
      profile = s
      return false
    end
  end)
  return profile
end

local function get_mobile_pdptype(ifname, ubus_data)
  local profile_id = mobile_profile_id_for_interface(ifname, ubus_data)
  local profile = load_mobile_profile(profile_id)
  if profile then
    return profile.pdptype or 'ipv4v6'
  end
  return 'ipv4v6'
end

local function is_ip_enabled(ifname, intf, ubus_data)
  local v4
  local v6
  if intf.proto == 'mobiled' then
    local pdptype = get_mobile_pdptype(ifname, ubus_data)
    v4 = (pdptype=='ipv4') or (pdptype=='ipv4v6')
    v6 = (pdptype=='ipv6') or (pdptype=='ipv4v6')
  else
    v4 = true
    v6 = intf.ipv6~="0"
  end
  return v4, v6
end

function M.getAddrList(ifnames)
  local ipv4 = {}
  local ipv6 = {}
  local intfs = load_network_interfaces()
  local ubus_data = newUbusInterfaceData()
  local main_ifname = ifnames[1]

  local main_intf = intfs[main_ifname]
  if not main_intf then
    -- the main interface does not exist, so there is no
    -- IP address list.
    return ipv4, ipv6
  end

  local ipv4_enabled, ipv6_enabled = is_ip_enabled(main_ifname, main_intf, ubus_data)
  if ipv6_enabled then
    add_ipv6_link_local(main_ifname, main_intf, ipv6, ubus_data)
  end

  for _, ifname in ipairs(ifnames) do
    local intf = intfs[ifname] or default_intf
    if ipv4_enabled then
      add_ipv4_address_entry(ifname, intf, ipv4, ubus_data)
    end
    if ipv6_enabled then
      add_ipv6_address_entry(ifname, intf, ipv6, ubus_data)
    end
  end

  return ipv4, ipv6
end

return M
