---
--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
-- Module L2 Main.
-- Module Specifies the check functions of a wansensing state
-- @module modulename
local M = {}
---
-- List all events with will schedule the check method
--   Support implemented for :
--       a) network interface state changes coded as `network_interface_xxx_yyy` (xxx= OpenWRT interface name, yyy = ifup/ifdown)
--       b) dslevents (xdsl_1(=idle)/xdsl_2/xdsl_3/xdsl_4/xdsl_5(=show time))
--       c) network device state changes coded as 'network_device_xxx_yyy' (xxx = linux netdev, yyy = up/down)
-- @SenseEventSet [parent=#M] #table SenseEventSet
M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wan_ifup', 
    'network_interface_wan_ifdown' ,
}
local xdslctl = require('transformer.shared.xdslctl')
local sfp = require('transformer.shared.sfp')
local wansensing = require('datamodel')
local match = string.match

function M.check(runtime)
	local scripthelpers = runtime.scripth
	local conn = runtime.ubus
	local logger = runtime.logger
	local uci = runtime.uci
	local mode = xdslctl.infoValue("tpstc")
	if not uci then
		return false
	end
	
   local x = uci.cursor()
   local ethernet_mode = x:get("ethernet", "eth4", "wan")
	-- check if wan ethernet port is up
	if scripthelpers.l2HasCarrier("eth4") and not ( ethernet_mode == "0" ) then
				logger:notice("SFP connection: "..sfp.getSfpPhyState())
				if sfp.getSfpPhyState() == "connect" and sfp.getSfpVendName() ~= "" then
					logger:notice("SFP connected")
					return "L3Sense", "SFP"
				else
					logger:notice("Ethernet wan connected")
					return "L3Sense", "ETH"
				end
	else
		-- check if xDSL is up
		--local mode = xdslctl.infoValue("tpstc")
		if mode then
			if match(mode, "ATM") then
			    return "L3Sense", "ADSL"
			elseif match(mode, "PTM") then
			    return "L3Sense", "VDSL"
			end
		end
	end
	--DR Section to check if wwan is enabled and if not enable it (covered config errors) 
   local mobile = x:get("network", "wwan", "auto")
	logger:notice("WAN Sensing Mobile: "..mobile)
    
	if mobile == "0" then 
		 logger:notice("WAN Sensing - Enabling Mobile interface")
		 x:set("network", "wwan", "auto", "1")
		 x:commit("network")
		 conn:call("network.interface.wwan", "up", { })
	end
	return "L2Sense"
end

return M
