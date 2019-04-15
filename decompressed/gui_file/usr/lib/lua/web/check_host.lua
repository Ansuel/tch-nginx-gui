
local require = require
local ipairs = ipairs
local format = string.format

local dm = require "datamodel"

local ipAddressParam = {ipaddr = true, ip6addr = true}
local ip6AddressParam = {ipv6uniquelocaladdr = true, ipv6uniqueglobaladdr = true}

local function append_interface_paths(paths)
  local entries = dm.getPN("uci.network.interface.", true)
  local intf
  for _, entry in pairs(entries or {}) do
    intf = entry.path:match("@(%S+)%.")
    paths[#paths + 1] = format('rpc.network.interface.@%s.ipaddr', intf)
    paths[#paths + 1] = format('rpc.network.interface.@%s.ip6addr', intf)
    paths[#paths + 1] = format('rpc.network.interface.@%s.ipv6uniquelocaladdr', intf)
    paths[#paths + 1] = format('rpc.network.interface.@%s.ipv6uniqueglobaladdr', intf)
    paths[#paths + 1] = format('rpc.network.interface.@%s.type', intf)
  end
end

local function append_dnsmasq_paths(paths)
  local entries = dm.getPN("uci.dhcp.dnsmasq.", true)
  for _, entry in ipairs(entries or {}) do
    paths[#paths+1] = entry.path.."hostname."
    paths[#paths+1] = entry.path.."domain"
  end
end

local function append_ddns_domains(paths)
  local reply = dm.get({"rpc.ddns.ActiveServices"}, false)
  local services = reply and reply[1] and reply[1].value or ""
  for service in services:gmatch("(%S+)") do
    paths[#paths+1] = service..".domain"
  end
end

local function validHostDMPaths()
  local paths = {"uci.system.system.@system[0].hostname"}
  append_dnsmasq_paths(paths)
  append_interface_paths(paths)
  append_ddns_domains(paths)
  return paths
end

local function getLanInterfacePaths(info)
  local lanInterfaces = {}
  for _,v in ipairs(info) do
     if v.path:match("^rpc%.network%.interface%.") and v.param == "type" and v.value == "lan" then
       lanInterfaces[v.path] = true
     end
  end
  return lanInterfaces
end

local function normalize_hostname(host)
  -- the common form of hostnames is all lowercase
  return host and host:lower()
end

--- Verify if the given hostname is a valid hostname or IP address for this system
-- @param http_req_host The hostname/IP address that needs to be authenticated
-- @return True if the hostname is valid. Otherwise false
local function hostRefersToUs(host)
  host = normalize_hostname(host)
  local hosts = dm.get(validHostDMPaths(), false) or {}
  local lanInterfacePaths = getLanInterfacePaths(hosts)
  for _, v in ipairs(hosts) do
    if v.path == "uci.system.system.@system[0]." then
       if host == normalize_hostname(v.value) then
          return true
       end
    elseif v.path:match("^uci%.dhcp%.dnsmasq%.@.*%.hostname%.") then
       if v.param == "value" and host == normalize_hostname(v.value) then
         return true
       else
         --When the host is having both hostname and domain value
         for _, val in ipairs(hosts) do
           if val.param == "domain" and val.path:match("^uci%.dhcp%.dnsmasq%.") then
             if host == normalize_hostname(v.value.."."..val.value) then
               return true
             end
           end
         end
       end
    elseif v.path:match("^rpc%.network%.interface%.") then
       if ipAddressParam[v.param] or (ip6AddressParam[v.param] and lanInterfacePaths[v.path]) then
         -- yes, also ip addresss need to be normalize as IPv6 addresses
         -- contain hex digits and (a~=A)
         -- for ip6addr, perhaps an IPv6 list, always get the first one here.
         if v.value ~= "" and host == normalize_hostname(v.value:match("^%S+")) then
           return true
         end
       end
    elseif v.path:match("^uci%.ddns%.service%.") then
      if normalize_hostname(v.value)==host then
        return true
      end
    end
  end
  return false
end

return {
  refersToUs = hostRefersToUs,
}
