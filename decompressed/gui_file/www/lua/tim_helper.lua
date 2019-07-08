--NG-70591 GUI : Unable to configure infinite lease time (-1) from GUI but data model allows
local intl = require("web.intl")
local function log_gettext_error(msg)
  ngx.log(ngx.NOTICE, msg)
end
local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext
local N = gettext.ngettext
local floor ,match = math.floor,string.match
local untaint_mt = require("web.taint").untaint_mt
local post_helper = require("web.post_helper")
local bit = require("bit")
local proxy = require("datamodel")
local function setlanguage()
  gettext.language(ngx.header['Content-Language'])
end

gettext.textdomain('webui-core')

local M = {}

--- Following the Wifi certifications we need to check if the pin with 8 digits and the last digit is the
-- the checksum of the others
-- @param #number the PIN code value
local function validatePin8(pin)
    if pin then
        local accum = 0
        accum = accum + 3*(floor(pin/10000000)%10)
        accum = accum + (floor(pin/1000000)%10)
        accum = accum + 3*(floor(pin/100000)%10)
        accum = accum + (floor(pin/10000)%10)
        accum = accum + 3*(floor(pin/1000)%10)
        accum = accum + (floor(pin/100)%10)
        accum = accum + 3*(floor(pin/10)%10)
        accum = accum + (pin%10)
        if 0 == (accum % 10) then
            return true
        end
    end
    return nil, T"Invalid Pin."
end

--- valide WPS pin code. Must be 4-8 digits (can have a space or - in the middle)
-- @param #string value the PIN code that was entered
function M.validateWPSPIN(value)
    local errmsg = T"PIN code must be composed of 4 or 8 digits with potentially a dash or space in the middle."
    if value == nil or #value == 0 then
        -- empty pin code just means that we don't want to set one
        return true
    end

    local pin4 = value:match("^(%d%d%d%d)$")
    local pin8_1, pin8_2 = value:match("^(%d%d%d%d)[%-%s]?(%d%d%d%d)$")

    if pin4 then
        return true
    end
    if pin8_1 and pin8_2 then
        local pin8 = tonumber(pin8_1..pin8_2)
        return validatePin8(pin8)
    end
    return nil, errmsg
end

--- check for WEP keys
-- 5,10,13 and 26 characters are allowed for the WEP key
-- 5 and 13 can contain ASCII characters
-- 10 and 26 can only contain Hexadecimal values
-- @param #string value the WEP key
-- @return #boolean, #string
function M.validateWEP(value)
    if value == nil or (#value ~= 5 and #value ~= 10 and #value ~= 13 and #value ~= 26) then
        return nil, T"Invalid length, a WEP key must be 5, 10, 13 or 26 characters long, length of 10 and 26 can only contain the letters A to F or digits"
    end

    if (#value == 10 or #value == 26) and (not value:match("^[%x]+$")) then
        return nil, T"A WEP key of length 10 or 26 can only contain the letters A to F or digits"
    end
    return true
end

--Checks ipaddress with TIM ZTE dongle ipaddress
function M.isWWANIP(value)
  local intf = "wwan"
  if value and value:match("192.168.0.") then
    return true, intf
  end
  return false
end

--Checks all interfaces that the ipaddress with netmask will not run in any other IP range
function M.isIPinOtherRange(ipAdd, ipNet, all_intfs, curintf)

	local ipvalue = post_helper.validateStringIsIP(ipAdd) and post_helper.ipv42num(ipAdd)
	local ipnetmask = post_helper.validateStringIsIP(ipNet) and post_helper.ipv42num(ipNet)
	local ip = post_helper.ipv42num(ipAdd)

	local ipnetwork, ipmaxvalue
		if ipvalue and ipnetmask then
		  ipnetwork = bit.band(ipvalue, ipnetmask)
		  ipmaxvalue = bit.bor(ipnetwork, bit.bnot(ipnetmask))
		end

	for _,intf in pairs(all_intfs) do
		if intf.paramindex ~= curintf then
			local ipaddr = proxy.get("uci.network.interface.@" .. intf.paramindex .. ".ipaddr")[1].value
			local mask = proxy.get("uci.network.interface.@" .. intf.paramindex .. ".netmask")[1].value
			local baseip = post_helper.validateStringIsIP(ipaddr) and post_helper.ipv42num(ipaddr)
			local netmask = post_helper.validateStringIsIP(mask) and post_helper.ipv42num(mask)

			local network, ipmax
			if baseip and netmask then
			  network = bit.band(baseip, netmask)
			  ipmax = bit.bor(network, bit.bnot(netmask))
			end

			if network and ipmax then
				if ip >= network and ip <= ipmax then
					return true, intf.paramindex
				end
                                if ipnetwork and ipmaxvalue then
				if ipnetwork <= network and network <= ipmaxvalue then
					return true, intf.paramindex
				end
                                end
			end
		end
	end
end

function M.ethtrans()
setlanguage()
  return {
    eth_infinit = T"infinite"
  }
end

-- Return a function that can be used to validate if the input is a whole number
-- @function [parent=#post_helper] getValidateWholeNumber
-- @param #number value
-- @return #boolean, #string
local function getValidateWholeNumber(value)
  local helptext = T"Input must be a whole number."
  --Check to see if the given string is a whole number
  if not (value and value:match("^%d+$")) then
    return nil, helptext
  end
  return true
end

---
-- @function [parent=#post_helper] validateStringIsLeaseTime
-- @param value
-- @return #boolean, #string
function M.validateStringIsLeaseTime(value)
    if not value then
        return nil, T"Invalid value."
    end
    local leasetime_pattern = "^(%d+)([wdhms])$"
    local leaseTime = setmetatable({
        s = 2147483647,
        m = 35791394,
        h = 596523,
        d = 24855,
        w = 3551,
    }, untaint_mt)
    local number, precision = value:match(leasetime_pattern)
    number = number and tonumber(number)
    if not number or number < 1 then
        return nil, T"Invalid value; enter a number greater than 0, followed by 's' for seconds or 'm' for minutes or 'h' for hours or 'd' for days or 'w' for weeks. No spaces."
    end
    if (((precision == "s") and (number < 120)) or
        ((precision == "m") and (number < 2))) then
        return nil, T"The minimum leasetime must be 120 seconds or 2 minutes."
    elseif leaseTime[precision] and number > leaseTime[precision] then
        return nil, T"The Maximum leasetime must be 3551 weeks or 24855 days or 596523 hours or 35791394 minutes or 2147483647 seconds."
    end
    return true
end

---
-- @function [parent=#post_helper] validateRegExpire
-- @param value
-- @param min
-- @param max
-- --@return #boolean, #string
function M.validateRegExpire (value)
    local num = tonumber (value)
    if num and num >= 60 and num <= 600000 and getValidateWholeNumber(value) then
        return true
    end
    return nil, T"Expire Time is invalid. It should be a whole number, between 60 and 600000."
end

function M.getValidateNumberInRange(min, max)                                                   
    local helptext = T"Input must be a number"                                              
    if min and max then                                                                                                                                    
        helptext = string.format(T"Input must be a number between %d and %d included", min, max)
    elseif not min and not max then                                                      
        helptext = T"Input must be a number"                                             
    elseif not min then                                                                          
        helptext = string.format(T"Input must be a number smaller than %d included", max)
    elseif not max then                                                                                  
        helptext = string.format(T"Input must be a number greater than %d included", min)
    end                                                                         
                                                                
    return function(value)                                  
        local num = tonumber(value)                             
        local isNotNumber = string.find(value, "[^%d]+")
        if isNotNumber then                
            return nil, helptext          
        end                           
        if not num then                       
            return nil, helptext           
        end                                                                               
        if min and num < min then                            
            return nil, helptext 
        end                                                                                  
        if max and num > max then                                                              
            return nil, helptext              
        end                    
        return true                
    end                                  
end                               

return M
