local M = {}

local nwcommon = require("transformer.mapper.nwcommon")
local uci_helper = require("transformer.mapper.ucihelper")
local getall_from_uci = uci_helper.getall_from_uci
local foreach_on_uci = uci_helper.foreach_on_uci
local lower = string.lower

-- Open connection to UBUS
local conn = require("transformer.mapper.ubus").connect()
-- UCI cursor used to save redirect dynamic state in /var/state (e.g. dest_ip address for MAC-based redirects)
local cursor = require("uci").cursor(UCI_CONFIG, "/var/state")

-- Save MAC-based port forwardings current dest_ip
-- The save will occur in /var/state/firewall file and it will
-- not be persistent between reboots
function M.set_volatile_destip(binding, dest_ip)
    local config = binding.config
    local section = binding.sectionname
    if config then
      if dest_ip and dest_ip ~= "0.0.0.0" and dest_ip ~= "::" then
        cursor:load(config)
        cursor:revert(config, section)
        cursor:set(config, section, "dest_ip", dest_ip)
        cursor:save(config)
        cursor:unload(config)
      end
    end
end

-- Remove MAC-based port forwardings current dest_ip
-- The save will occur in /var/state/firewall file and it will
-- not be persistent between reboots
function M.remove_volatile_destip(binding)
    local config = binding.config
    local section = binding.sectionname
    if section then
        -- remove current port forwarding dest_ip from /var/state
        cursor:load(config)
        cursor:revert(config, section)
        cursor:unload(config)
    end
end

-- Through adding random code to the suffix of sectionname to keep it unique in the same type
function M.generate_unique_sectionname(binding)
   if not binding or not binding.config or not binding.sectionname then
     return nil, "fw_binding or it's option is nil"
   end

   local start = math.random(0, 0xfffe)
   local id = start
   local uniquename

   repeat
     if id >= 0xFFFF then
       id = 0
     else
       id = id + 1
     end
     if id == start then
       return nil, "Failed to generate an unique name for the new object"
     end

     uniquename = binding.sectionname .. string.format("%04X", id)
     foreach_on_uci(binding, function(s)
       if s['.name'] == uniquename then
         -- Name have existed, find again
         uniquename = nil
         return false
       end
     end)
   until uniquename ~= nil

   return uniquename
end

-- Change IP-based port forwardings of known devices to MAC-based ones
function M.ubus_ipmac_retrieval(binding, param, value)
    local pfw_dest = {}
    local pfw = getall_from_uci(binding)

    --if option "family" is nil, then use default value "ipv4" because only ipv4 address is permitted now
    if not pfw.family then
        pfw.family = "ipv4"
    end
    if pfw.target ~= "SNAT"  then
        if param == "dest_mac" and nwcommon.isMAC(value) then -- IP address should have been removed priviously
            pfw_dest = { mac = lower(value), family = pfw.family }
        elseif param == "dest_ip" and value ~= "" and value ~= "0.0.0.0" and value ~= "::" then
            pfw_dest = { ip = value, family = pfw.family }
        end
    end

    -- perform host lookup
    local pfw_host = {}

    if next(pfw_dest) ~= nil  then

        local devices = conn:call("hostmanager.device", "get", pfw_dest.ip and
								{ [pfw_dest.family .. "-address"] = pfw_dest.ip } or
								{ ["mac-address"] = pfw_dest.mac } )
        if devices ~= nil then
            local index = nil
            local dev

            repeat
              -- iterate devices
              index, dev = next(devices, index)

              if (dev ~= nil and dev[pfw_dest.family] ~= nil) then
                -- find device matching mac or ip address
                local ip, destmac, destip

                if not pfw_dest.ip and dev["mac-address"] == pfw_dest.mac then
                    destmac = pfw_dest.mac
                end

                for _, ip in pairs(dev[pfw_dest.family]) do
                    if pfw_dest.ip and ip["address"] == pfw_dest.ip then
                        -- save MAC address (will be used in redirect rules as dest_mac)
                        destmac = dev["mac-address"]
                    end
                    if ip["redirect-dest"] then
                        -- this address is preferred by host manager,
                        -- save IP address (will be used in redirect rules as dest_ip)
                        destip = ip["address"]
                    end
                    if destmac and destip then
                        -- found what we were looking for
                        pfw_host = { destmac = destmac, destip = destip }
                        break
                    end

                end
              end
           until dev == nil or next(pfw_host)
        end
    end

    return pfw_host
end

return M
