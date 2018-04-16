local M = {}
local match = string.match
local popen = io.popen

local uci = require('uci')

local runtime={}
local cursor



--- Initializes the library with a wansensing context (uci/ubus/logger)
-- No library calls can be made before this function has completed successfully
-- @param wansensingruntime The wansening context
function M.init(wansensingruntime)
   for rt_key, rt_value in pairs(wansensingruntime) do
      runtime[rt_key] = rt_value
   end
   cursor = runtime.uci.cursor()
end

--- Helper function to check that the arguments that are passed to dnsget / ping do not contain special characters that make
-- the call turn into an exploit
-- @param str The string to check
-- @return true if the string does not contain an apparent exploit, false otherwise
local function check_for_exploit(str)
    if str then
        -- try to make sure the string is not an exploit in disguise
        -- it is about to be concatenated to a command so ...
        return match(str,"^[^<>%s%*%(%)%|&;~!?\\$]+$") and not (match(str,"^-") or match(str,"-$"))
    else
        return false
    end
end

--- Compare an address to a table / array of addresses,
-- @param addresses A table /array of addresses to check against
-- @param expectedaddress The address to check
-- @return true if expectedaddress matches one of the addresses, false otherwise
local function compare_address(addresses,expectedaddress)
    if addresses and type(addresses) == 'table' then
        for _,address in ipairs(addresses)
        do
            if address == expectedaddress then
                return true
            end
        end
    end
    return false
end

--- Check that the given address matches a valid v4/v6 address notation
-- @param address The address string to check
-- @param v6 true if the address is supposed to be a v6 address, false otherwise
-- @return true if address string is valid, false otherwise
local function check_address(address,v6)
    if v6 then
        return match(address,"^[a-f0-9:]+$")
    else
        return match(address,"^%d+%.%d+%.%d+%.%d+$")
    end
end

--- Helper function that performs the actual dnsget
-- it is pcalled by dns_lookup
-- @param query The fqdn to resolve
-- @param server The nameserver of sending dns request to
-- @param v6 Whether dns query type is IPv6. 1:ipv6 , 0:ipv4.
-- @param attempts:num - number of attempt to resovle a query.
-- @param timeout:sec  - initial query timeout .
-- @return resolvedhostnamer The resolved hostname for query or nil if not resolved
-- @return resolvedaddressesv4 Table/array of resolved ipv4 addresses for query
-- @return resolvedaddressesv6 Table/array of resolved ipv6 addresses for query
local function run_dnsget(query,server,v6,attempts,timeout)
    if check_for_exploit(query) then
        if type(attempts) ~= 'number' then
            attempts=1
        end

        if type(timeout) ~= 'number' then
            timeout=1
        end

        local cmd
        if server ~= nil then
            cmd='dnsget -n ' .. server
        else
            cmd='dnsget'
        end
        if v6 then
            cmd=cmd .. ' -t AAAA'
        else
            cmd=cmd .. ' -t A'
        end
        cmd=cmd .. ' -o timeout:' ..timeout.. ' -o attempts:' ..attempts.. ' ' .. query .. ' 2>/dev/null'

        runtime.logger:notice("run_dnsget::trigger dns query by " .. cmd)
        local pipe = popen(cmd,'r')
        if pipe then
            local resolvedhostname,resolvedaddressesv4,resolvedaddressesv6,addr,addr6
            for line in pipe:lines() do
                resolvedhostname = match(line,"([^%s]+)%.%s")
                if resolvedhostname then
                    if v6 == nil then
                        addr=match(line,"%s+(%d+%.%d+%.%d+%.%d+)")
                        if addr then
                            if not resolvedaddressesv4 then
                                resolvedaddressesv4 = {}
                            end
                            resolvedaddressesv4[#resolvedaddressesv4+1] = addr
                        end
                    else
                        addr6=match(line,"%s+([a-f0-9]*:[a-f0-9:]*:[a-f0-9]*)")
                        if addr6 then
                            if not resolvedaddressesv6 then
                                resolvedaddressesv6 = {}
                            end
                            resolvedaddressesv6[#resolvedaddressesv6+1] = addr6
                        end
                    end
                end
            end
            pipe:close()

            if resolvedhostname and (resolvedaddressesv4 or resolvedaddressesv6) then
                return resolvedhostname,resolvedaddressesv4,resolvedaddressesv6
            else
                return nil -- unresolved , not an error
            end
        else
            error("Failed to run dnsget")
        end
    else
        error("Invalid query '" .. tostring(query) .. "'")
    end
end

--- performs a dns lookup for the given query / fqdn
-- @param query The fqdn to resolve
-- @param server The nameserver of sending dns request to
-- @param v6 Whether dns query type is IPv6. 1:ipv6 , 0:ipv4.
-- @param attempts:num  Number of attempt to resovle a query.
-- @param timeout:sec   Initial query timeout .
-- @return status true if no errors occurred, false otherwise
-- @return resolvedhostname_or_error        if status = true, the resolved hostname for query,
--                                          if status = false the error message
-- @return resolvedaddressesv4 Table/array of resolved ipv4 addresses for query
-- @return resolvedaddressesv6 Table/array of resolved ipv6 addresses for query
function M.dns_lookup(query,server,v6,attempts,timeout)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end

    local status,resolvedhostname_or_error,resolvedaddressesv4,resolvedaddressesv6 = pcall(run_dnsget,query,server,v6,attempts,timeout)
    return status,resolvedhostname_or_error,resolvedaddressesv4,resolvedaddressesv6
end

--- Performs a dns lookup and compares the resolved hostname and addressesses to expectedhostname and expectedaddress/spoofedaddress
-- @param query The dns query /fqdn to resolve
-- @param attempts The max number of dns query attemts that are performed before dns_check fails
-- @param expectedhostname The expected hostname that will be resolved
-- @param expectedaddress The expected address that will be resolved. May be set to nil (do not check).
-- @param spoofedaddress The expected address that will be resolved in case of dns spoofing (wan interface down). May be set to nil (do not check).
-- @param v6 true if the addresses to check are ipv6 addresses, false if the addresses are v4 addresses. May be set ot nil (ipv4).
--
-- @return status true if no errors occurred, false otherwise
-- @return hostname_or_error        if status = true, true if resolved hostname matches expectedhostname, false otherwise
--                                  if status = false, the error message
-- @return addressresolved true if resolved addresses contain expectedaddress, false otherwise
-- @return spoofedaddressresolved true if resolved addresses contain spoofedaddress, false otherwise.
function M.dns_check(query,server,expectedhostname,expectedaddress,expectedspoofedaddress,v6,attempts,timeout)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end
    if  expectedhostname == nil and expectedaddress == nil and expectedspoofedaddress == nil then
        return false,"Please specify at least one parameter to be resolved"
    end
    if (expectedaddress and not check_address(expectedaddress,v6)) or (expectedspoofedaddress and not check_address(expectedspoofedaddress,v6)) then
         return false,"Wrong format for expected address or expected spoofed address"
    end

    if attempts and type(attempts) ~= 'number' then
        return false,"Wrong format for attempts"
    end

    if timeout and type(timeout) ~= 'number' then
        return false,"Wrong format for timeout"
    end

    local status,hostname_or_error,addressesv4,addressesv6 = M.dns_lookup(query,server,v6,attempts,timeout)
    if not status then
        return status,hostname_or_error
    end

    if hostname_or_error then
        local hostnameresult = (hostname_or_error == expectedhostname)

        local addresses = addressesv4
        if v6 then
            addresses = addressesv6
        end

        if expectedaddress and compare_address(addresses,expectedaddress) then
            return true,hostnameresult,true,false
        elseif expectedspoofedaddress and compare_address(addresses,expectedspoofedaddress) then
            return true,hostnameresult,false,true
        else
            return true,hostnameresult,false,false
        end
    end

    return true,false,false,false -- did not resolve

end

--- Helper function that performs the actual ping
-- is pcalled from ping
-- @param address The address / fqdn to ping to
-- @param source The source interface or address to use. May be set to nil (no specific interface/addr to use).
-- @param count The number of echo requests to send. May be set to nil (count = 1).
-- @param v6 If true, ping is executed over ipv6, if false over ipv4. May be set to nil (ipv4).
-- @return successes_or_error The number of successfull pings
-- @return failures The number of failed pings
local function run_ping(address,source,count,v6)
    if not address or not check_for_exploit(address) or (source and not check_for_exploit(source)) then
        error("Invalid parameters, address = '" .. tostring(address) .. "', source = '" .. tostring(source) .. "'")
    end
    local cmd = 'ping'
    if v6 then
        cmd = 'ping -6'
    end
    if type(count) ~= 'number' then
        count = 1
    end
    cmd = cmd .. ' ' .. address .. ' -c ' .. count
    if source and type(source) == 'string' then
        cmd = cmd .. ' -I ' .. source
    end
    cmd = cmd .. ' 2>/dev/null'
    local pipe = popen(cmd,'r')
    if pipe then
        for line in pipe:lines() do
            local transmitted,received = match(line,"(%d+) packets transmitted, (%d+) packets received")
            if transmitted and received then
                pipe:close()
                return tonumber(received),tonumber(transmitted)-tonumber(received)
            end
        end
        pipe:close()
        error('Ping command generated an error ' .. tostring(cmd))
    else
        error('Failed to launch ping command ' .. tostring(cmd))
    end
end

--- Performs a ping with the specified source address/interface and count
-- @param address The address / fqdn to ping to
-- @param source The source interface or address to use. May be set to nil (no specific interface/addr to use).
-- @param count The number of echo requests to send. May be set to nil (count = 1).
-- @param v6 If true, ping is executed over ipv6, if false over ipv4. May be set to nil (ipv4).
-- @return status true if no errors occurred, false otherwise
-- @return successes_or_error        if status = true, the number of successfull pings
--                                   if status = false, the error message
-- @return failures the number of failed pings
function M.ping(address,source,count,v6)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end

    local status,successes_or_error,failures = pcall(run_ping,address,source,count,v6)
    return status,successes_or_error,failures
end

--- Performs a ping with the specified source address/interface and count
-- returns true if the number of failures is lower than the specified value
-- @param address The address / fqdn to ping to
-- @param source The source interface or address to use. May be set to nil (no specific interface/addr to use).
-- @param count The number of echo requests to send. May be set to nil (count = 1).
-- @param max_failures The maximum number of failed pings that can occurr before the test fails
-- @param v6 If true, ping is executed over ipv6, if false over ipv4. May be set to nil (ipv4).
-- @return status true if no errors occurred, false otherwise
-- @return successes_or_error        if status = true, true if the number of failed pings is lower than max_failures, false otherwise
--                                   if status = false, the error message
function M.ping_check(address,source,count,max_failures,v6)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end
    --  Deletes an interface in the uci network configuration
    -- does not bring the interface down prior to deleting
    -- this has to be handled by the library user
    -- @param intf The name of the interface to delete
    -- @return status true if successful, false otherwise
    -- @return err the errormessage if status = false

    if not max_failures then
        max_failures = 0
    end

    local status,successes_or_error,failures = M.ping(address,source,count,v6)
    if not status then
        return status,successes_or_error
    end
    if tonumber(failures)>tonumber(max_failures) then
        return true,false
    else
        return true,true
    end
end

--- Helper function that performs the actual arping
-- is pcalled from arping
-- @param address The address / fqdn to arping to
-- @param src_intf The source interface to use, may be set to nil (eth0 will be used).
-- @param src_address The source address to use, may be set to nil (routing table will select best source).
-- @param count The number of arping requests to send.
-- @param broadcast Sent only broadcasts on MAC level, if not set the utility will switch to unicast once a reply is received.
-- @return successes The number of successfull arpings
-- @return failures The number of failed pings
local function run_arping(address,src_intf,src_address,count,broadcast)
   if not address or not check_for_exploit(address) or (src_intf and not check_for_exploit(src_intf)) or (src_address and not check_for_exploit(src_address)) then
      error("Invalid parameters, address = '" .. tostring(address) .. "', src_intf = '" .. tostring(src_intf) .. "', src_address = '" .. tostring(src_address) .. "'")
   end

   if not count then
      count = 1
   end

   --compose the command
   local cmd = 'arping '
   if broadcast then
      cmd = cmd .. '-b '
   end
   if src_intf and type(src_intf) == 'string' then
      cmd = cmd .. '-I ' .. src_intf .. ' '
   end
   if src_address and type(src_address) == 'string' then
      cmd = cmd .. '-s ' .. src_address .. ' '
   end

   if count and type(count) == 'number' then
      cmd = cmd .. '-c ' .. count .. ' '
   end

   cmd = cmd .. address .. ' 2>/dev/null'
   local pipe = popen(cmd,'r')
   if pipe then
      local transmitted, received
      for line in pipe:lines() do
         if not transmitted then
            transmitted = match(line,"^Sent (%d+)")
         end
         if not received then
            received = match(line,"^Received (%d+)")
         end
         if transmitted and received then
            pipe:close()
            return tonumber(received),tonumber(transmitted)-tonumber(received)
         end
       end
       pipe:close()
       error( tostring(cmd) .. ' failed')
    else
       error( tostring(cmd) .. ' can not be launched')
    end
end

-- @param address The address / fqdn to arping to
-- @param src_intf The source interface to use, may be set to nil (eth0 will be used).
-- @param src_address The source address to use, may be set to nil (routing table will select best source).
-- @param count The number of arping requests to send, may be set to nil (count = 1).
-- @param broadcast Sent only broadcasts on MAC level, if not set the utility will switch to unicast once a reply is received.
-- @return status true if no errors occurred, false otherwise
-- @return successes_or_error if status = true, the number of successfull arp pings
--                            if status = false, the error message
-- @return failures the number of failed pings
function M.arping(address,src_intf,src_address,count,broadcast)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end
    if count and tonumber(count) == nil then
        return false,"Parameter '" .. tostring(count) .. "' is not a number"
    end

    local status,successes_or_error,failures = pcall(run_arping,address,src_intf,src_address,count,broadcast)
    return status,successes_or_error,failures
end

--- Helper function that performs the actual test for reachability
-- is pcalled from is_reachable
-- @param address The IPv4 or IPv6 address to search as a reachable neighbour
-- @param src_intf The source interface to use, may be set to nil
-- @return boolean for success or string on error
local function run_is_reachable(address,src_intf)
   if not address or not check_for_exploit(address) or (src_intf and not check_for_exploit(src_intf)) then
      error("Invalid parameters, address = '" .. tostring(address) .. "', src_intf = '" .. tostring(src_intf) .. "'")
   end

   --compose the command
   local cmd = 'ip neigh show '
   cmd = cmd ..' to '..address
   if src_intf then -- restricts to specified interface
      cmd = cmd..' dev '..src_intf
   end
   cmd =  cmd .. ' 2>/dev/null'
   local pipe = popen(cmd,'r')
   if pipe then
      for line in pipe:lines() do
         -- can we find the address in the one line of the result?
         -- and does the last part contain REACHABLE?
         if string.find(line,address,1,false) and string.find(line," REACHABLE$") then
            pipe:close()
            return true
         end
       end
       pipe:close()
       return false -- ip was not found in 'ip neigh ...' result
    else
       error( tostring(cmd) .. ' can not be launched')
    end
end

-- @param address The address (v4 or v6)  to test as a reachable neighbour
-- @param src_intf The source interface to use, may be set to nil.
-- @return status true if no errors occurred, false otherwise
-- @return succes_or_error  if status = true, the success of fail bool result
--                          if status = false, the error message
function M.is_reachable(address,src_intf)
    if not runtime then
        return false,"Library was not properly initialized"
    end
    local status,success_or_error = pcall(run_is_reachable,address,src_intf)
    return status,success_or_error
end

--- Helper function that does the actual deleting of the interface
-- It is pcalled by delete_interface
-- @param intf The name of the interface to delete
local function run_delete(intf)
    local config='network'
    if not intf then
        error("intf must be filled in")
    end
    cursor:load(config)
    cursor:delete(config,intf)
    cursor:commit(config)
end

--- Deletes an interface in the uci network configuration
-- does not bring the interface down prior to deleting
-- this has to be handled by the library user
-- @param intf The name of the interface to delete
-- @return status true if successful, false otherwise
-- @return err the errormessage if status = false
function M.delete_interface(intf)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end

    local status,err = pcall(run_delete,intf)
    return status,err
end

--- Helper function that performs the actual copying of the interface
-- It is pcalled by copy_interface
-- @param src The name of the src interface to copy from
-- @param dst The name of the dst interface to copy to
-- @param own_cursor The uci cursor used to perform operations.
--   If the caller does not pass its own cursor, then the default cursor in this helper file is used.
--   If the caller passes its own cursor, then the passed cursor is used. In this case, there is no uci commit operation performed by this function. Because we expect the caller will do the commit operation by itself.
local function run_copy(src,dst,own_cursor)
    local cursor_used = cursor
    local commit_needed = true
    if own_cursor ~= nil then
        cursor_used = own_cursor
        commit_needed = false
    end
    if not src or not dst then
        error("src or dst not filled in")
    end
    local config='network'
    cursor_used:load(config)
    local src_attribs
    local interfaces_found = cursor_used:foreach(config,'interface',function(s)
        if s['.name']==src then
            src_attribs = s
            return false -- exit from loop
        end
    end)
    if interfaces_found and src_attribs and type(src_attribs)=='table' then
        cursor_used:set(config,dst,'interface')
        for k,v in pairs(src_attribs)
        do
            if k and v and not string.match(k,"^%.") then
                cursor_used:set(config,dst,k,v)
            end
        end

        if commit_needed then
            cursor_used:commit(config)
        end
    else
        error('Failed to find source interface or its attributes')
    end
end

--- Copies an existing interface in the uci network configuration
-- does not bring the interface down prior to copying
-- this has to be handled by the library user
-- @param src The name of the src interface to copy from
-- @param dst The name of the dst interface to copy to
-- @return status true if successful, false otherwise
-- @return err the errormessage if status = false
function M.copy_interface(src,dst)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end

    local status,err = pcall(run_copy,src,dst)
    return status,err
end

--- Copies an existing interface in the uci network configuration
--- User's own cursor is provided, does NOT use the cursor in this helper file
-- does not bring the interface down prior to copying
-- this has to be handled by the library user
-- @param own_cursor The user's own cursor
-- @param src The name of the src interface to copy from
-- @param dst The name of the dst interface to copy to
-- @return status true if successful, false otherwise
-- @return err the errormessage if status = false
function M.copy_interface_cursor_provided(src,dst,own_cursor)
    if not runtime or not own_cursor then
        return false,"Library was not properly initialized"
    end

    local status,err = pcall(run_copy,src,dst,own_cursor)
    return status,err
end

--- Given the type of L2, the event received and the name of the ETH wan interface, returns whether the current L2 went
-- down or not
-- @param l2type
-- @param event
-- @param ethintf the netdev interface used as wan
-- @return {boolean} whether the current L2 went down or not
M.checkIfCurrentL2WentDown = function(l2type, event, ethintf)
    local intfdown = 'network_device_' .. ethintf .. '_down'
    if event == 'xdsl_0' and (l2type == "ADSL" or l2type == "VDSL") then
        -- xDSL interface is down and we were over xDSL
        return true
    elseif event == intfdown and l2type == "ETH" then
        -- ETH interface is down and we were over ETH
        return true
    end
    return false
end

--- Given an event and the name of the ETH wan interface, returns whether any L2 interface went up (based on event)
-- @param event
-- @param ethintf the netdev interface used as wan
-- @return {boolean} whether an L2 interface went up
M.checkIfAnyL2WentUp = function(event, ethintf)
    if event == 'xdsl_5' or event == 'network_device_' .. ethintf .. '_up' then
        return true
    end
    return false
end

--- Checks if the 3G backup is in the enabled state.
-- Assumes that if not set, it is disabled
M.checkIf3GBackupIsEnabled = function()
    local config = "mobiledongle"

    cursor:load(config)
    local enabled = cursor:get(config, "config", "enabled")
    return enabled == "1"
end

--- Checks if an interface given by name is up
-- @param intf the interface name (netifd interface)
-- @return {boolean} whether the given interface is up or not
M.checkIfInterfaceIsUp = function(intf)
    local conn = runtime.ubus
    local status

    status = conn:call("network.interface." .. intf, "status", { })
    if status and status.up then
        return true
    end
    return false
end

--- Checks if the interface is up and has IP address
-- @param intf the interface name
-- @param ipv6
--          true  -> check for IPv6 address
--          false or nil -> check for IPv4 address
-- @return {boolean} whether the interface has IP address or not
M.checkIfInterfaceHasIP = function(intf, ipv6)
    local conn = runtime.ubus
    local status

    if M.checkIfInterfaceIsUp(intf) then
        status = conn:call("network.interface." .. intf, "status", { })
        local ipv4address = #status["ipv4-address"] > 0 and status["ipv4-address"][1].address
        local ipv6address = #status["ipv6-address"] > 0 and status["ipv6-address"][1].address

        if ipv6 then
            return ipv6address
        else
            return ipv4address
        end
    end
    return false
end

--- Checks if a GPON interface given by name is up
-- @return {boolean} whether the given interface is up or not
M.checkIfGPONInterfaceIsUp = function()
    local conn = runtime.ubus
    local state

    state = conn:call("gpon.omciport", "state", { })
    if state and state.statuscode then
        return state.statuscode == 1
    end
    return false
end

--- Helper function that performs the actual Link State check
-- it is pcalled by l2HasCarrier
-- @param l2intf the interface name (netdevice interface name)
-- @return {up/down} the linkstate
local function run_checkLinkState(intf)
   local f = io.open('/sys/class/net/' .. intf .. '/carrier')
   local linkstate
   if f then
      local state = f:read(1)
      if state == '1' then
         linkstate = 'up'
      elseif state == '0' then
         linkstate = 'down'
      end
      f:close()
   end

   -- Some wansensing scripts are checking for carrier on interfaces that
   -- are administratively set to down (e.g. "ifconfig <ifname> down").
   -- The standard Linux interface for reporting carrier status returns an
   -- error in this case. To allow these existing scripts to work without
   -- changes, we fall back to a Broadcom specific implementation that
   -- reads the link state directly from the PHY.
   if not linkstate then
      local pipe = popen('ethctl ' .. intf .. ' media-type 2>&1', 'r')
      if pipe then
         for line in pipe:lines() do
            if not linkstate then
               linkstate = match(line, "^Link is%s+([^%s]+)$")
            end
         end
         pipe:close()
      end
   end

   return linkstate or 'down'
end

--- Checks if a l2 device has carrier
-- @param l2intf the interface name (netdevice interface name)
-- @return {boolean} whether the given interface has carrier or not
M.l2HasCarrier = function(l2intf)
    local status, carrier = pcall(run_checkLinkState,l2intf)
	local eth4_mode = uci.cursor():get("ethernet", "eth4", "wan")
    if status and ( carrier == 'up' ) and ( eth4_mode == '1' ) then
       return true
    else
       return false
    end
end

function M.set_state(uci, param, value)
   if type(param) ~= "string" or type(value) ~= "string" then
      error("both param and value parameter should be of type string")
   end

   local config = "wansensing"
   local x = uci.cursor(UCI_CONFIG, "/var/state")

   x:load(config)
   x:revert("wansensing", "state", param)
   x:set("wansensing", "state", param, value)
   x:save("wansensing")
end

--- Format neighbor event name
-- @param l2intf the interface name (netdevice interface name)
-- @param add true for add event, false for delete
-- @param neighbor IP address of the neighbor
-- @return {string} neighbor event name
function M.formatNetworkNeighborEventName(l2intf,add,ipaddr)
   local evtype = (add and "_add_") or "_delete_"
   return  "network_neigh_" .. l2intf:gsub("[^%a%d_]",'_') .. evtype .. tostring(ipaddr)
end

--- Configure XTM driver prioritization of pure TCP ACK streams
-- @param prio_inc {unsigned integer} priority increment to be applied on pure TCP ACK streams (0 will disable this mechanism)
-- @param prio_max {unsigned integer} maximum priority a stream could get through this mechanism (0 will disable this mechanism)
-- @param count {unsigned integer} number of consecutive pure TCP ACK packets after which stream priority will be incremented (0 will disable this mechanism)
-- @return {boolean} true if sysctl values were successfully updated
function M.configureTcpAckPrioritization(prio_inc, prio_max, count)
    local names = { "prio_inc", "prio_max", "count" }
    local values = { prio_inc, prio_max, count }
    local changed = { }
    local path = "/etc/sysctl-tch.conf"
    local update = false
    local i, j, k, l
    local f = io.open(path, "r")
    local t = { }

    if f then
        for l in f:lines() do
            for i in pairs(values) do
                j,k = string.find(l, "%s*net%.core%.blog_xtm_tcpack_" .. names[i] .. "%s*=%s*")
                if j == 1 then
                    if changed[i] ~= nil then
                        changed[i] = true
                        l = nil
                    elseif tonumber(string.sub(l, k + 1)) ~= values[i] then
                        changed[i] = true
                        l = string.sub(l, j, k) .. tostring(values[i])
                    else
                        changed[i] = false
                    end
                    break
                end
            end

            if l ~= nil then
                table.insert(t, l)
            end
        end

        f:close()
    end

    for i in pairs(values) do
        if changed[i] == nil then
            table.insert(t, "net.core.blog_xtm_tcpack_" .. names[i] .. "=" .. tostring(values[i]))
            update = true
        elseif changed[i] then
            update = true
        end
    end

    if not update then
        return true
    end

    f = io.open(path, "w")
    if f == nil then
        return false
    end

    for i,l in ipairs(t) do
        f:write(l .. "\n")
    end
    f:close()

    return os.execute("sysctl -p " .. path .. " >/dev/null") == 0
end


--- Get the next hop on an interface
-- If there is a default route, its next hop will be returned.
-- Otherwise, first route that has a valid next hop will be used.
-- @param ifstatus table containing the interface status or the interface name
-- @return nexthop or nil
function M.getNextHop(intf)
   local ret = nil
   local ifstatus=nil
   if intf == nil then
      error("intf argument cannot be nil")
   elseif type(intf) == "string" then
      local conn = runtime.ubus
      ifstatus = conn:call("network.interface." .. intf, "status", { })
      if not ifstatus then
         runtime.logger:notice("nextHop("..intf..") not found")
      elseif not ifstatus.up then
         runtime.logger:warning("nextHop("..intf..") down")
      end
   elseif type(intf) == "table" then
      ifstatus=intf
   end
   if ifstatus and ifstatus.up then
      for _, route in pairs(ifstatus.route) do
         if (route.nexthop and route.nexthop ~= "0.0.0.0") then
            if (route.mask == 0) then
               return route.nexthop
            elseif (ret == nil) then
               ret = route.nexthop
            end
         end
      end
    end
    return ret
end

--- test connectivity via arping to a ipv4address from an interface
-- @param name  unique name to use as a handle for logging
-- @param intf  openwrt interface name to send the request from
-- @param ipv4address target to arping
-- @param interval a table with test intervals (on failure next value is used to wait)
-- @param fail_evt  a string with name of the event to emit on failure
-- @return a monitor object with stop and start method or nil
function M.create_ipv4_neighbour_monitor(name, intf, ipv4address,interval_table, fail_evt)
   local conn = runtime.ubus
   local repeatedcheck = runtime.repeatedcheck
   if (name == nil) then
      error("create_ipv4_neighbour_monitor(..)  arg name cannot be nil")
   end
   if (intf == nil) then
      error("create)ipv4_neighbour_monitor(..)  arg intf cannot be nil")
   end
   if (ipv4address == nil) then
      error("create_ipv4_neighbour_monitor(..)  arg ipv4address cannot be nil")
   end
   if (type(interval_table) ~= "table") then
      error("create_ipv4_neighbour_monitor("..name..","..intf.. "..) arg interval_table must be a table (not "..type(interval_table)..")")
   end
   if (fail_evt == nil or type(fail_evt) ~= "string") then
      error("create_ipv4_neighbour_monitor("..name..","..intf.. ",..) fail_evt has to be a string")
   end
   if type(runtime.event_cb) ~= "function" then
      error("create_ipv4_neighbour_monitor: missing runtime.event_cb function")
   end
   runtime.logger:debug("create_ipv4_neighbour_monitor("..intf..",{"..table.concat(interval_table,", ").."},"..fail_evt..")")
   local function check() -- lambda for repeated check
      local ifstatus = conn:call("network.interface." .. intf, "status", { })
      if ifstatus and ifstatus.up then
         local device = ifstatus.device
         -- ipv4address remains available in the closure of this lambda
         local status,successes_or_error,failures = M.arping(ipv4address,device,nil,1,1)
         if status and type(successes_or_error) == "number" and failures == 0 then
            runtime.logger:notice("ipv4_neighbour_monitor '"..name.."' arping via "..intf.."("..device..") to "..ipv4address.." was successful")
            return true
         end
         if type(successes_or_error) == "string" then
            runtime.logger:error("ipv4_neighbour_monitor '"..name.."' arping via "..intf.." returned "..successes_or_error)
         end
         runtime.logger:warning("ipv4_neighbour_monitor '"..name.."' arping via "..intf.."("..device..") to "..ipv4address.." failed")
         return false
      else
         runtime.logger:notice("ipv4_neighbour_monitor '"..name.."' fails, since interface "..intf.." is down")
         return false
      end
   end
   local function gaveUp() -- lambda for repeated check
      runtime.logger:debug("ipv4_neighbour_monitor '"..name.."' emits "..fail_evt)
      runtime.event_cb(fail_evt)
   end
   local monitor=repeatedcheck.RepeatedCheck(interval_table,check,gaveUp)
   if not monitor then
      runtime.logger:error("create_ipv4_neighbour_monitor "..name.." failed")
      return nil
   end
   runtime.logger:debug("create_ipv4_neighbour_monitor "..name.." successful")
   return monitor
end

--- Helper function that performs the actual flush of conntrack
-- it is pcalled by flushConntrack
-- @param ipaddr the ip address to pass to conntrack to flush all related connections. Accepts both IPv4 and IPv6
-- @return boolean for success or string on error
local function run_flush_conntrack(ipaddr)
   if not ipaddr then
      error("run_flush_conntrack(...)  arg ipaddr cannot be nil")
   end
   -- Only valid formatted IPv4 or IPv6 addresses are accepted.
   if not ( check_address(ipaddr, false) or check_address(ipaddr, true) ) then
      error("run_flush_conntrack(...)  arg ipaddr is not a valid IP address")
   end

   local file = io.open("/proc/net/nf_conntrack", "w")
   if file then
      file:write(ipaddr)
      file:close()
   else
      error("unable to open /proc/net/nf_conntrack")
   end
   return true
end

--- Removes all connections from conntrack which are making use of the specified IP address
-- @param address The IP address to flush conntrack with. Accepts both v4 and v6 addresses
-- @return status true if no errors occurred, false otherwise
-- @return err the errormessage if status = false
function M.flushConntrack(address)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end

    local status,err = pcall(run_flush_conntrack,address)
    return status,err
end

--- Fire a timed event which sends out 'event_name' event every 'timeout_sec' secs, repeated 'count' times
-- @param event_name: The name of the event to be sent
-- @param timeout_sec: The time interval between two successive timed events
-- @param count: The number of timed events to be sent out
-- @return timer: if succeed, the timer object which has start()/stop() methods. timer.stop() is used to pause the timed event, and timer.start() is used to restart it.
--                if failed, nil
function M.fire_timed_event(event_name, timeout_sec, count)
    if not runtime then
        return nil
    end

    local timer=runtime.timedevent.TimedEvent(event_name,timeout_sec,count)

    timer:start()
    return timer
end

return M
