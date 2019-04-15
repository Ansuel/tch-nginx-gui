--[[
Copyright (c) 2016-2017 Technicolor Delivery Technologies, SAS

The source code form of this lua-tch component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]


---
-- Common IP address functions.
--
-- @module tch.inet

local require = require
local pcall = pcall
local error = error

local posix = require("tch.posix")
local bit = require("bit")

local AF_INET = posix.AF_INET
local AF_INET6 = posix.AF_INET6
local inet_pton = posix.inet_pton
local inet_ntop = posix.inet_ntop
local match, format = string.match, string.format
local tonumber, type = tonumber, type
local floor = math.floor

local M = {}

--- Check if the given address is a valid IPv4 address.
-- @tparam string ip The IP address string to test.
-- @treturn boolean True if it is a valid IPv4 address.
-- @error Error message.
function M.isValidIPv4(ip)
  local r, err = inet_pton(AF_INET, ip)
  if r then
    return true
  end
  return nil, err
end

--- Check if the given address is a valid IPv6 address.
-- @tparam string ip The IP address string to test.
-- @treturn boolean True if it is a valid IPv6 address.
-- @error Error message.
function M.isValidIPv6(ip)
  local r, err = inet_pton(AF_INET6, ip)
  if r then
    return true
  end
  return nil, err
end

local AddressFamilyToAF_SPEC = {
  IPv4 = AF_INET,
  IPv6 = AF_INET6,
}

local AF_SPECToAddressFamily = {
  [AF_INET] = "IPv4",
  [AF_INET6] = "IPv6"
}

local function ipBinary(ip, family)
  local af
  local bin
  if not family then
    bin = posix.inet_pton(AF_INET, ip)
    if bin then
      af = AF_INET
    else
      bin = posix.inet_pton(AF_INET6, ip)
      if bin then
        af = AF_INET6
      else
        return nil, "not a valid IP address (v4 nor v6)"
      end
    end
  else
    af = AddressFamilyToAF_SPEC[family]
    if not af then
      return nil, "invalid address family, must be IPv4 or IPv6"
    end
    local err
    bin, err = posix.inet_pton(af, ip)
    if not bin then
      return nil, err
    end
  end
  return bin, af
end

--- Check if the given address is a valid IP address.
-- @tparam string ip The IP address to test.
-- @treturn string "IPv4" if `ip` is a valid IPv4 address or "IPv6" if
--   `ip` is a valid IPv6 address.
-- @error Error message.
function M.isValidIP(ip)
  local bin, af = ipBinary(ip)
  if not bin then
    return nil, af
  end
  return AF_SPECToAddressFamily[af]
end

--- Normalize the given IP address to canonical representation
--
-- This is needed especially for IPv6 where there is a lot of freedom
-- in what qualifies as a valid address. eg. "0:0::0" is valid and it is
-- equivalent to "0000::0000". This function will reduce it to it's shortest
-- form "::".
-- @string ip the IP address to mormalize
-- @string[opt] family the address family IPv4 or IPv6. If not specified
--   it is determined automatically
-- @return normalized ip and address family
-- @error Error message
function M.normalizeIP(ip, family)
  local bin, af = ipBinary(ip, family)
  if not bin then
    return nil, af
  end
  return inet_ntop(af, bin), AF_SPECToAddressFamily[af]
end

--- Is the given IP address zero
--
-- An IP address is zero if it consist of only NUL bytes.
-- Depending on the context this either means ANY address or UNASSIGNED.
-- @string ip the ip address to check
-- @string[opt] family the address family, either IPv4 or IPv6. If not specified
--   it is determined automatically.
-- @return true if the ip address is zero
-- @raise error if ip is invalid
function M.ipIsZero(ip, family)
  local bin, af = ipBinary(ip, family)
  if not bin then
    return error(af)
  end
  for i=1,#bin do
    if bin:byte(i)~=0 then
      return false
    end
  end
  return true
end

--- Convert the given hexadecimal IPv4 address string to
-- dotted decimal notation. The string may have leading or
-- trailing whitespace.
-- @tparam string hexip The hexadecimal IPv4 address to be converted.
-- @treturn string The IPv4 address in dotted decimal notation.
-- @error Error message.
function M.hexIPv4ToString(hexip)
  if type(hexip) ~= "string" then
    return nil, "argument not a string"
  end
  local x1, x2, x3, x4 = match(hexip, "^%s*(%x%x)(%x%x)(%x%x)(%x%x)%s*$")
  if not x1 then
    return nil, "string is not a valid IPv4 address in hexadecimal notation"
  end
  x1, x2, x3, x4 = tonumber(x1, 16), tonumber(x2, 16), tonumber(x3, 16), tonumber(x4, 16)
  return format("%d.%d.%d.%d", x1, x2, x3, x4)
end

--- Check whether the given IPv6 address is a valid global unicast address.
-- Global unicast address has the prefix 2000::/3 (see
-- [IANA](https://www.iana.org/assignments/ipv6-unicast-address-assignments/ipv6-unicast-address-assignments.xhtml))
-- @string ipv6addr The IPv6 address to be checked.
-- @treturn boolean True if `ipv6addr` is valid global unicast address.
-- @error Error Message.
function M.isValidGlobalUnicastv6Address(ipv6addr)
  local rc = inet_pton(AF_INET6, ipv6addr)
  if rc then
    -- Check if the three most significant bits of the first byte are 001.
    if bit.band(rc:byte(1), 0xE0) == 0x20 then
      return true
    end
  end
  return nil, "Invalid Global Unicast Address"
end

--- convert ip address string to a number (in host order)
-- @string ip the ip address string eg "192.168.1.1"
-- @treturn number the 32bit integer representation of the ip
-- @error Error Message
function M.ipv4ToNumber(ip)
  if ip then
    local ok, bin, num = pcall(inet_pton, AF_INET, ip)
    if ok and bin then
      return num
    else
      return nil, "invalid input data"
    end
  end
end
local ipv4ToNumber = M.ipv4ToNumber

--- convert a 32bit integer to an IPv4 string representation
-- @number n the number to convert
-- @treturn string the dotted ip address string
-- @error Error Message
function M.numberToIpv4(n)
	local ok, ip = pcall(inet_ntop, AF_INET, n)
	if ok then
		return ip
	end
	return nil, "invalid data"
end
local numberToIpv4 = M.numberToIpv4

--- Check that the given value is a valid IPv4 netmask.
-- In particular it will check that the netmask falls in the
-- range of /8 and /30 (both inclusive) which is what makes
-- sense for DHCP pool configuration.
-- @string value The netmask in dotted decimal notation.
-- @treturn boolean True if it's a valid subnet mask.
-- @treturn number The number of bits in the host part of the subnet mask.
-- @error Error message.
function M.validateIPv4Netmask(value)
  -- A valid subnet mask consists of (in binary) consecutive 1's
  -- followed by consecutive 0's.
  local netmask = ipv4ToNumber(value)
  if not netmask then
    return nil, "String is not an IPv4 address."
  end
  local ones = 0
  local expecting = 0
  for i = 0, 31 do
    local bitmask = bit.lshift(1, i)
    local result = bit.band(netmask, bitmask)
    if result == 0 then
      if expecting ~= 0 then
        return nil, "Invalid subnet."
      end
    else
      if expecting == 0 then
        expecting = 1
      end
      ones = ones + 1
    end
  end
  if (ones < 8) or (ones > 30) then
    return nil, "Invalid subnet."
  end
  return true, 32 - ones
end

--- Calculate the number of effective hosts possible in the network with the given subnet mask.
-- @string subnetmask The subnet mask, in dotted-decimal notation.
-- @treturn number The number of effective hosts possible in the network with the given subnet mask.
-- @error Error message.
function M.getPossibleHostsInIPv4Subnet(subnetmask)
  local valid, host_bits = M.validateIPv4Netmask(subnetmask)
  if not valid then
    return nil, host_bits
  end
  return (2^host_bits) - 2
end

local netmask_bits_to_ip
local netmask_dotted_to_bits

local function netmask_BitsToDotted(nBits)
  if nBits and 1 <= nBits and nBits <= 32 then
    return (2^nBits-1)*(2^(32-nBits))
  end
end

local function fill_netmask_tables()
  if netmask_bits_to_ip then
    return
  end
  netmask_bits_to_ip = {}
  netmask_dotted_to_bits = {}
  for bits=1,32 do
    local ip = netmask_BitsToDotted(bits)
    netmask_bits_to_ip[bits] = ip
    local dotted = inet_ntop(AF_INET, ip)
    netmask_dotted_to_bits[dotted] = bits
  end
end

--- Convert a number of bits to a number representing the netmask
-- In particular it will check that the input netmask falls in the range of 1 to 32
-- @number num the subnet value as number
-- @treturn number representing the netmask or nil
function M.netmaskToNumber(num)
  fill_netmask_tables()
  return netmask_bits_to_ip[num]
end

--- Convert a dotted ip netmask to the number of network bits
-- @string ip the dotted netmask (eg 255.255.255.0)
-- @return number of netmask bits
-- @error if ip is not a proper netmask
function M.mask2netmask(ip)
  fill_netmask_tables()
  local bits = netmask_dotted_to_bits[ip]
  if bits and bits<31 then
    return bits
  end
end

--- broadcast address for the given network
-- @string ip The ip address (eg 192.168.1.1)
-- @number network_bits The number of bits in the network mask (1 to 32)
-- @treturn string The broadcast address (eg 192.168.1.255)
-- @error an error message
function M.ipv4BroadcastAddr(ip, network_bits)
  local n = ipv4ToNumber(ip)
  if not n or network_bits<1 or 32<network_bits then
    return nil, "invalid input data"
  end
  local shift = 2^(32-network_bits)
  return numberToIpv4(floor(n/shift)*shift + (shift-1))
end

return M
