local M = {}

local type, require, ipairs = type, require, ipairs
local format = string.format
local ch = require("web.content_helper")
local proxy = require("datamodel")
local ww = require("web.web")
local bit = require("bit")

---
-- @param #string basepath
-- @return #table
function M.getHostsList()
    local basepath = "rpc.hosts.host."
    local data = proxy.get(basepath)
    local result = {}

    if type(data) == "table" then
        result = ch.convertResultToObject(basepath, data)
    end
    return result
end

---
local ipv6_pattern = "%x*:%x*:%x*:%x*:%x*:%x*:%x*:%x*"
local ipv4_pattern = "%d+%.%d+%.%d+%.%d+"
local mac_pattern = "%x*:%x*:%x*:%x*:%x*:%x*"
-- @param skipIPv6LinkLocal [optional] to get only IPv6 address (not link local address)
-- @return 2 tables: 1 IPv4 hosts, 2 IPv6 hosts
function M.getAutocompleteHostsList(skipIPv6LinkLocal)
    local hosts = M.getHostsList()
    local ipv4hosts={}
    local ipv6hosts={}

    for i,v in ipairs(hosts) do
        local name = ww.html_escape(v.FriendlyName)
        local iplist = ww.html_escape(v.IPAddress)
        local macaddr = ww.html_escape(v.MACAddress)
        local friendlyName

        --Get the IPv4 hosts
        for ipv4 in iplist:gmatch(ipv4_pattern) do
            --The rpc.hosts.host will never return empty value for FriendlyName.
            --For example the default value will be Unknown-b4:ef:fa:b7:f5:98 if host name is empty
            if name:match(mac_pattern) then
                friendlyName = ipv4
            else
                friendlyName = name .. " (" .. ipv4 .. ")"
            end
            friendlyName = friendlyName .. " [" .. macaddr .. "]"
            ipv4hosts[friendlyName] = ipv4
        end

        --Get the IPv6 hosts
        for ipv6 in iplist:gmatch(ipv6_pattern) do
            if ipv6 then
                if name:match(mac_pattern) then
                    friendlyName = ipv6
                else
                    friendlyName = name .. "(" .. ipv6 .. ")"
                end
                friendlyName = friendlyName .. " [" .. macaddr .. "]"
                if skipIPv6LinkLocal then
                    if bit.band(ipv6:byte(1), 0xE0) == 0x20 then
                        ipv6hosts[friendlyName] = ipv6
                    end
                else
                    ipv6hosts[friendlyName] = ipv6
                end
            end
        end
    end
    return ipv4hosts, ipv6hosts
end

function M.getAutocompleteHostsListMac()
    local hosts = M.getHostsList()
	local ipv4hostsMac={}
	local ipv6hostsMac={}

    for i,v in ipairs(hosts) do
	    local name = ww.html_escape(v.FriendlyName)
	    local iplist = ww.html_escape(v.IPAddress)
        local macaddr = ww.html_escape(v.MACAddress)
	    local friendlyName

		--Get the IPv4 hosts
        for ipv4 in iplist:gmatch(ipv4_pattern) do
            --The rpc.hosts.host will never return empty value for FriendlyName.
            --For example the default value will be Unknown-b4:ef:fa:b7:f5:98 if host name is empty
            if name:match(mac_pattern) then
                friendlyName = ipv4
            else
                friendlyName = name
            end
            friendlyName = friendlyName .. " [" .. ipv4 .. "]"
            ipv4hosts[friendlyName] = macaddr
        end

        --Get the IPv6 hosts
        for ipv6 in iplist:gmatch(ipv6_pattern) do
            if ipv6 then
                if name:match(mac_pattern) then
                    friendlyName = ipv6
                else
                    friendlyName = name
                end
                friendlyName = friendlyName .. " [" .. ipv6 .. "]"
                if skipIPv6LinkLocal then
                    if bit.band(ipv6:byte(1), 0xE0) == 0x20 then
                        ipv6hosts[friendlyName] = macaddr
                    end
                else
                    ipv6hosts[friendlyName] = macaddr
                end
            end
        end
	end
    return ipv4hostsMac, ipv6hostsMac
end

---
-- @return #table
function M.getAutocompleteHostsListIPv4()
    return (M.getAutocompleteHostsList())
end

return M
