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

local posix = require("tch.posix")
local bit = require("bit")

local AF_INET = posix.AF_INET
local AF_INET6 = posix.AF_INET6
local inet_pton = posix.inet_pton
local match, format = string.match, string.format
local tonumber, type = tonumber, type
local max = math.max
local min = math.min

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

--- Check if the given address is a valid IP address.
-- @tparam string ip The IP address to test.
-- @treturn string "IPv4" if `ip` is a valid IPv4 address or "IPv6" if
--   `ip` is a valid IPv6 address.
-- @error Error message.
function M.isValidIP(ip)
  if M.isValidIPv4(ip) then
    return "IPv4"
  end
  if M.isValidIPv6(ip) then
    return "IPv6"
  end
  return nil, "not a valid IP address (v4 nor v6)"
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

--- Convert a number of bits to a number representing the netmask
-- In particular it will check that the input netmask falls in the range of 1 to 32
-- @tnumber num the subnet value as number
-- @treturn number representing the netmask or nil
function M.netmaskToNumber(num)
  if num and 1 <= num and num <= 32 then
    return (2^num-1)*(2^(32-num))
  end
end

return M
