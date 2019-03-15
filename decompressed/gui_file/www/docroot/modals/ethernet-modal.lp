--pretranslated: do not change this file

-- Localization
--NG-????? ResetButton and friendlyName on LAN-Interface Page
--NG-71196 IPv6 Button pppoe realm
--NG-71457
--NG-73647 changes reloads pppoe
--NG-78292 DHCP server disabled after reset
--NG-72728
--NG-68986 a revert been done
--NG-89213 to revert the revert of the generic NG-68986 changes
--NG-83015 IPv6
--NG-96100 Local Network Modal not opened after upstep to 17.1.7745
--NG-96425 TI-[GUI] - Changing SSID name of Guest 5GHz is not coherent in Wireless and Local Network Modal
--NG-100782 [TI] Local Network card accepts LAN IP in Ospiti range when the subnet mask is changed
--NG-102499 Assigning a Network Address/mask already in use shall not be possible
--NG-70591 GUI : Unable to configure infinite lease time (-1) from GUI but data model allows
gettext.textdomain('webui-core')

-- Process POST query
local bit = require("bit")
local proxy = require("datamodel")
local lfs = require("lfs")
local pairs, string ,ipairs, ngx = pairs, string, ipairs, ngx
local session = ngx.ctx.session
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsList()
local tonumber, tostring = tonumber, tostring
local content, helpmsg
local match, format = string.match, string.format
local find, untaint = string.find, string.untaint
local ipv42num = post_helper.ipv42num
local broadcast_ip =post_helper.ipv42num("255.255.255.255")
local timhelper = require("web.tim_helper")

-- Shortcuts to validation helpers to make lines shorter
local aIPV = post_helper.advancedIPValidation
local vB = post_helper.validateBoolean
local vIP4N = post_helper.validateIPv4Netmask
local vQTN = post_helper.validateQTN
local gAV = post_helper.getAndValidation
local gVIC = post_helper.getValidateInCheckboxgroup
local gVIES = post_helper.getValidateInEnumSelect
local vNES = post_helper.validateNonEmptyString

local session = ngx.ctx.session
local tech = false
if session:getrole() == "engineer" then
    tech = true
end

local clear_network_stats = {
    controls = {
      class = "clear_network_stats"
    },
	group = {
       class = "advanced hide"
    },
    button = {
      ["data-name"] = "action",
      ["data-value"] = "RESET"
    }
}
local pIPV = post_helper.isPublicIP

local hosts_mac = {}
for k, v in pairs(hosts_ac) do
    local mac = match(k, "%[(.*)%]")
    hosts_mac[#hosts_mac+1] = {mac, mac}
end

hosts_mac[#hosts_mac+1] = {"custom",T"custom"}

if lfs.attributes("/www/lua/dhcpreset_helper.lua", "mode") == "file" then
   dhcpDefaultExist = require("dhcpreset_helper")
end

local function num2ipv4(ip)
    local ret = bit.band(ip, 255)
    ip = bit.rshift(ip,8)
    for i=1,3 do
        ret = bit.band(ip,255) .. "." .. ret
        ip = bit.rshift(ip,8)
    end
    return ret
end

local getargs = ngx.req.get_uri_args()
local getintf = getargs.intf

local curintf = "lan"
-- Get all the LAN interfaces
local net_intfs_path = "rpc.network.interface."
local all_intfs = content_helper.convertResultToObject(net_intfs_path .. "@.", proxy.get(net_intfs_path))
local wireless_radio = {}
for i,v in ipairs(proxy.getPN("rpc.wireless.ssid.", true)) do
  local radios = match(v.path, "rpc%.wireless%.ssid%.@([^%.]+)%.")
  if radios then
    wireless_radio[radios] = true
  end
end
local lan_intfs = {}
local pppIntf, pppDev
for k,v in ipairs(all_intfs) do
    if v.type == "lan" and (not find(v["ppp.ll_intf"], "wl") or wireless_radio[untaint(v["ppp.ll_intf"])])then
        local radio = "noradio"
        local name = ""
        local w1_exist = proxy.get("rpc.wireless.ssid.@"..v["ppp.ll_dev"]..".ssid")
        if match(v["ppp.ll_dev"], "wl") then
            if w1_exist and proxy.get("rpc.wireless.ssid.@"..v["ppp.ll_dev"]..".ssid")[1].value then
                name = proxy.get("rpc.wireless.ssid.@"..v["ppp.ll_dev"]..".ssid")[1].value
                if match(proxy.get("rpc.wireless.ssid.@"..v["ppp.ll_dev"]..".radio")[1].value, "radio_5G") then
                    radio = "5GHz"
                else
                    radio = "2,4GHz"
                end
            end
        end
        if name ~= "" then
            lan_intfs[#lan_intfs + 1] = {name = name, index = v.paramindex, radio = radio}
        elseif v.name and v.name ~= "" then
            lan_intfs[#lan_intfs + 1] = {name = v.name, index = v.paramindex, radio = radio}
        else
            lan_intfs[#lan_intfs + 1] = {name = v.paramindex, index = v.paramindex, radio = radio}
        end
    end
    if v.paramindex == getintf then
        curintf = v.paramindex
        pppDev = v["ppp.ll_dev"]
        pppIntf = v["ppp.ll_intf"]
    end
end


----------------------------------reset function-------------------------------------
local function restdhcp()
local file = io.open("/rom/etc/uci-defaults/tch_0035-network-lan","r")
io.input(file)
local lanip = ""
local lanmask = ""
local checkup = 0
	while checkup == 0 do
	local line = io.read()
		if line ~= nil and (lanip == "" or lanip == nil) then
			lanip=match(line,"uci set network%."..curintf.."%.ipaddr%=([%d]+%.[%d]+%.[%d]+%.[%d]+)")
		end
		if line ~= nil and (lanmask == "" or lanmask == nil) then
			lanmask=match(line,"uci set network%."..curintf.."%.netmask%=([%d]+%.[%d]+%.[%d]+%.[%d]+)")
		end
		if lanip ~= "" and lanip ~= nil and lanmask ~= "" and lanmask ~= nil  then
			checkup=1
			io.close(file)
		elseif line == nil then
			checkup=2
			io.close(file)
		end
	end
	if checkup == 2 then
	local file2 = io.open("/lib/functions/uci-defaults.sh","r")
	io.input(file2)
		while checkup == 2 do
			local line = io.read()
			if line ~= nil and (lanip == "" or lanip == nil) then
				lanip=match(line,"set network%."..curintf.."%.ipaddr%=%'([%d]+%.[%d]+%.[%d]+%.[%d]+)%'")
			end
			if line ~= nil and (lanmask == "" or lanmask == nil) then
				lanmask=match(line,"set network%."..curintf.."%.netmask%=%'([%d]+%.[%d]+%.[%d]+%.[%d]+)%'")
			end
			if lanip and lanip ~= "" and lanmask and lanmask ~= "" or line == nil then
				checkup=5
				io.close(file2)
			end
		end
	end

	local founddev = 0
	local ipstart = ""
	local ipend = ""
	local ltime = ""
	local dhcpign = ""
	local fp = io.open("/rom/etc/config/dhcp", "r")
	local pattern = format("config dhcp %s",curintf)
	io.input(fp)
		while founddev == 0 do
			local line =io.read()
			if match(line,pattern) then
				while founddev == 0 do
				line =io.read()
					if line ~= nil and (ipstart == "" or ipstart == nil) then
						ipstart= match(line,"option start[%s]+'([%d]+)'")
					end
					if line ~= nil and (ipend == "" or ipend == nil) then
						ipend= match(line,"option limit[%s]+'([%d]+)'")
					end
					if line ~= nil and (ltime == "" or ltime == nil) then
						ltime= match(line,"option leasetime[%s]+'([%w]+)'")
					end
					if line ~= nil and (dhcpign == "" or dhcpign == nil) then
						dhcpign= match(line,"option ignore[%s]+'([%d]+)'")
					end
					if line == nil or match(line, "config dhcp") or ipstart~= nil and ipstart~="" and ipend ~= nil and ipend ~="" and ltime ~= nil and ltime ~="" and dhcpign ~= nil and dhcpign ~="" then
						founddev = 1
					end
				end
			end
			if line == nil then
				founddev = 1

			end
		end
		io.close(fp)
		if dhcpign == nil or dhcpign == "" then
			dhcpign = "0"
		end
	return lanip, lanmask, ipstart, ipend, ltime, dhcpign
end
------------------------------------reset end-----------------------------------------------------------------

local IP6assign = "uci.network.interface.@" .. curintf .. ".ip6assign"

local function setupIpv6TIM(active)
	local envIPv6 = proxy.get("uci.modgui.var.ppp_realm_ipv6")[1].value or nil
    local envIPv4 = proxy.get("uci.modgui.var.ppp_realm_ipv4")[1].value or nil
	local pppuser = "uci.network.interface.@wan.username"
	local wan_voip_path = "uci.network.interface.@wan_voip."
	local wan_path = "uci.network.interface.@wan."
	local function getFromWan(param)
		local value = proxy.get(wan_path..param)
		return value and value[1].value or ""
	end
	if (active == true) then
		proxy.add("uci.network.interface.","wan_voip")
		for _,param in pairs({ "proto" , "username","device","peerdns","password","ifname","macaddr"}) do
			proxy.set(wan_voip_path..param,getFromWan(param))
		end
		proxy.set(wan_voip_path.."metric","1000")
		for i,v in ipairs(proxy.getPN("uci.mmpbxrvsipnet.network.", true)) do
			proxy.set(v.path.."interface", "wan_voip")
		end
		local index = proxy.add("uci.firewall.zone.@wan.network.")
		proxy.set("uci.firewall.zone.@wan.network.".."@".."index.value","wan_voip")
		proxy.set(pppuser, envIPv6)
	else
		for i,v in ipairs(proxy.getPN("uci.firewall.zone.@wan.network.", true)) do
			local value = proxy.get(v.path.."value")
			if value and value[1].value == "wan_voip" then
				proxy.del(v.path)
			end
		end
		for i,v in ipairs(proxy.getPN("uci.mmpbxrvsipnet.network.", true)) do
			proxy.set(v.path.."interface", "wan")
		end
		proxy.set(pppuser, envIPv4)
		proxy.del(wan_voip_path)
	end
end

local mapParam = {
    localIPv6 = "uci.network.interface.@" .. curintf .. ".ipv6"
}
local function validateIPv6(value, object, key)
    local valid, msg = post_helper.validateBoolean(value, object, key)
    if valid and value ~= proxy.get("uci.network.interface.@" .. curintf .. ".ipv6")[1].value then
        local isp = proxy.get("uci.modgui.var.isp")
        local device = proxy.get("uci.network.device.")
        local devifn = content_helper.convertResultToObject("uci.network.device.",device)
        local devindex = {}
        for i,v in ipairs(devifn) do
            devindex[#devindex+1] = v.paramindex
        end
        if value == "0" then
            if isp and ( isp[1].value == "TIM" ) then
                setupIpv6TIM(false)
            end
            proxy.set("uci.network.interface.@wan.ipv6", value)
            proxy.set("uci.network.interface.@wan6.auto", value)
            proxy.apply()
            --for i, v in ipairs(devindex) do
            --    proxy.set("uci.network.device."..v..".ipv6", value)
            --end
            for i,v in pairs(lan_intfs) do
                if curintf ~= v.index then
                    proxy.set("uci.network.interface.@"..v.index..".ipv6", value)
                end
            end
            -- In case we disable IPv6, we must first invalidate the existing prefix so that local devices know not to use IPv6 anymore
            -- Do this here by set the ip6assign pref and only on ipv6 state change
            local ipv6 = proxy.get(mapParam["localIPv6"]) -- get current value in datamodel to know if we're switching state
            if ipv6 and ipv6.value ~= "0" then -- default is enabled so anything non 0 is enabled
                proxy.set(IP6assign, "0") -- the value will be set back to its current value by process_query
                proxy.apply()
                ngx.sleep(3) -- ugly but need to give it the time to complete
            end
        elseif value == "1" then
            if isp and ( isp[1].value == "TIM" ) then
                setupIpv6TIM(true)
            end
            proxy.set("uci.network.interface.@wan.ipv6", value)
            proxy.set("uci.network.interface.@wan6.auto", value)
            --for i, v in ipairs(devindex) do
            --    proxy.set("uci.network.device."..v..".ipv6", value)
            --end
            for i,v in pairs(lan_intfs) do
                if curintf ~= v.index then
                    proxy.set("uci.network.interface.@"..v.index..".ipv6", value)
                end
            end
            proxy.set(IP6assign, "64")
            proxy.apply()
        end
        if isQtnGuestWiFi(pppDev) then
            local ucipath = content_helper.getMatchedContent("uci.network.device.",{ifname = pppIntf})
            if ucipath and #ucipath > 0 then
                proxy.set(ucipath[1].path .. "ipv6", value)
            end
        end
        -- Modify IPv6 at WAN-side accordingly:
        -- this is especially necessary to make sure Neighbor Solicitation (for DAD etc.) messages are sent upon network reload

        proxy.apply()
    end
    return valid, msg
end
--We need to update IPv6 state only when user want to update the IPv6 state alone.
if ngx.var.request_method == "POST" and ngx.req.get_post_args().iPv6StateOnlyChanged == "yes" and curintf == "lan" then
    local validation = {
        localIPv6 = validateIPv6,
    }
    post_helper.handleQuery(mapParam, validation)
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.exit(ngx.HTTP_OK)
end
-- Static leases
local sleases_columns = {
  {
    header = T"Hostname",
    name = "sleases_name",
    param = "name",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"MAC address",
    name = "sleases_mac",
    param = "mac",
    type = "select",
    values = hosts_mac,
    attr = { input = { class="span2", maxlength="17", id= "lease_mac" }, autocomplete=hosts_mac },
    unique = true,
  },
  {
    header = T"IP",
    name = "sleases_ip",
    param = "ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"}, autocomplete=hosts_ac },
    unique = true,
  },
  {
    header = "",
    name = "sleases_owner",
    param = "owner",
    type = "hidden",
    readonly = true,
    attr = { },
  },
}

-- Function to avoid users to enter ReservedStatic name as custom static lease name
local function sleases_name_validation(value)
  if (value:find("^ReservedStatic") ~= nil) then
    return nil, T"Cannot use reserved names as static lease name"
  end
  return true
end

local function sleases_mac_validation(value, object, key)
  local r1, r2 = post_helper.validateStringIsMAC(value)
  if r1 then
    if string.lower(value) == "ff:ff:ff:ff:ff:ff" then
        return nil, T"The requested MAC address can't be the broadcast MAC"
    else
        object[key] = string.lower(value)
    end
  end
  return r1, r2
end

-- Function to check the input IP is in Reserved IP list
local function reserved_ip_validation(value)
    local reservedList = {}
    local reservedIPList = proxy.get("uci.dhcp.host.")
    reservedIPList = content_helper.convertResultToObject("uci.dhcp.host.", reservedIPList)
    if reservedIPList then
        for _,v in pairs(reservedIPList) do
            if v["name"]:find("^ReservedStatic") ~= nil then
                reservedList[#reservedList + 1] = v["ip"]
                if value == v["ip"] then
                    return nil
                end
            end
        end
    end
    return true
end

local function sleases_ip_validation(value, object, key)
    local contentdata = {
      localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
      localdevmask = "uci.network.interface.@" .. curintf .. ".netmask",
    }
    content_helper.getExactContent(contentdata)
    return post_helper.staticLeaseIPValidation(value, contentdata)
end

local sleases_valid = {
    sleases_name = gAV(sleases_name_validation,post_helper.validateStringIsDomainName),
    sleases_mac = gAV(sleases_mac_validation,vQTN),
    sleases_ip = gAV(sleases_ip_validation,vQTN),
}

local sleases_options = {
    tableid = "sleases",
    basepath = "uci.dhcp.host.@.",
    createMsg = T"Add new static lease",
    objectName  = post_helper.getRandomKey(),
    addNamedObject = true,
}


local syshosts_data = proxy.get("sys.hosts.host.")
local sleases_filter = function(data)
    if data['owner'] == "portforward" then
        local path
        if syshosts_data then
            for _, v in pairs(syshosts_data) do
                if v.value == data['mac'] then
                    path = v.path
                    break
                end
            end
            for _, v in pairs(syshosts_data) do
                if v.path == path and v.param == "HostName" then
                    data['name'] = v.value
                    break
                end
            end
        end
        return { canEdit = false, canDelete = false }
    end
    if (data['name']:find("^ReservedStatic") == 1) then
       return false
    end
    return true
end

local sleases_data, sleases_helpmsg = post_helper.handleTableQuery(sleases_columns, sleases_options, sleases_filter, nil, sleases_valid)

local inUseFlag = false
if ngx.var.request_method == "POST" then
  local post_data = ngx.req.get_post_args()
  if ( post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT"  or  post_data.action == "TABLE-ADD") then
    local text_mac_index = tonumber(post_data.index)
    local text_mac
    if  post_data.action == "TABLE-ADD" then
      text_mac = post_data["sleases_mac"]
    else
      text_mac = sleases_data[text_mac_index][2]
    end
    local flag = true
    for _,j in ipairs(hosts_mac) do
      if text_mac == j[1] then
        flag = false
        break
      end
    end
    if flag   then
      sleases_columns[2] = {
        header = T"MAC address",
        name = "sleases_mac",
        param = "mac",
        type = "text",
        attr = { input = { class="span2", maxlength="17", id= "lease_mac", value = text_mac }},
        unique = true,
      }
    end
    if post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-ADD" then
      local slease_ip = post_data.sleases_ip
      local arranged_data = content_helper.convertResultToObject("sys.hosts.host.", syshosts_data)
      if arranged_data then
        for _, v in pairs(arranged_data) do
            if v.DhcpLeaseTime ~= "" and v.IPAddress == slease_ip then
                inUseFlag = true
                break
           end
        end
      end
    end
  end
end

local cur_dhcp_intf = "lan"
local dhcp_intfs_path = "uci.dhcp.dhcp."
local all_dhcp_intfs = content_helper.convertResultToObject(dhcp_intfs_path .. "@.", proxy.get(dhcp_intfs_path))

for k,v in ipairs(all_dhcp_intfs) do
    if v.interface == curintf then
        cur_dhcp_intf = v.paramindex
        break
    end
end

-- If the current interface is "STB", in order to get the DHCP range, name it as "lan"
if cur_dhcp_intf == "STB" then
    cur_dhcp_intf = "lan"
end

local sfp_presence = proxy.get("uci.env.rip.sfp")

local mapParSFP = {}
local mapValSFP = {}

local sfpintf = "sfptag"

if sfp_presence and  (sfp_presence[1].value == "1") then
    --if sfptag interface not found change name to sfp (fastweb naming)
    if not proxy.get("uci.network.interface.@"..sfpintf..".ipaddr")  then
        sfpintf = "sfp"
    end
    mapParSFP.ethsfp = "uci.ethernet.globals.eth4lanwanmode"
    mapValSFP.ethsfp = vB
else
    mapParSFP.eth4_wanmode = "uci.ethernet.port.@eth4.wan"
    mapValSFP.eth4_wanmode = vB
end

local content_sfp, helpmsg = post_helper.handleQuery(mapParSFP, mapValSFP)

-- Standard parameters
local mapParams = {
    domainName = "uci.dhcp.dnsmasq.@dnsmasq.domain",
    dhcpStart = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".start",
    dhcpLimit = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".limit",
    --dhcpv4State = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcpv4",
    dhcpIgnore = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ignore",
    leaseTime = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".leasetime",
    localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
    localdevmask = "uci.network.interface.@" .. curintf .. ".netmask",
    --localIPv6 = "uci.network.interface.@" .. curintf .. ".ipv6",
    eth0 = "uci.ethernet.port.@eth0.enable",
}

if sfp_presence and  (sfp_presence[1].value == "1") then
    mapParams["sfplocalip"] = "uci.network.interface.@"..sfpintf..".ipaddr"
end

local ethports = {
    {"eth0", T"Port" .. " 1"},
}

-- Generic solution for boards without eth1/2/3
local ethport_count = 0
for i = 1, 3 do
    local ethport = "eth" .. i
    local path = "uci.ethernet.port.@" .. ethport .. "."
    local v = proxy.get(path .. "duplex")
    if v ~= nil then
        local portname = T"Port" .. " " .. i + 1
        ethport_count = ethport_count + 1
        table.insert(ethports, {ethport, portname})
        mapParams[ethport] = path .. "enable"
    end
end

local dnsIndex
local dhcp = {}
local baseDHCPOptions = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcp_option."
local dnsRemoved = false

-- Check if there is a custom DNS server, if so, then retrieve its index
-- we'll update the parameters list to include it for retrieval
dhcp.options = proxy.get(baseDHCPOptions)
dnsIndex = #dhcp.options + 1 -- by default index is end of list

for i,v in ipairs(dhcp.options) do
    if v.value:find("^6,") == 1 then
        dnsIndex = tonumber(string.match(v.path, "%.@(%d+)%.$"))
    end
end

local function isNonPublicIPRange(ip)
    if ip >= ipv42num("10.0.0.0") and ip <= ipv42num("10.255.255.255") or
       ip >= ipv42num("172.16.0.0") and ip <= ipv42num("172.31.255.255") or
       ip >= ipv42num("192.168.0.0") and ip <= ipv42num("192.168.255.255") then
      return true
    end
      return nil
end

local function validateDNS(value, object, key)
    -- If there is no value, then we want to delete the dhcp_option if it exists
    -- Otherwise, we want to check the value is an IP
    if value == "" then
        -- if the key does not exist, no harm done
        proxy.del(mapParams[key]:sub(1,-6))
        -- remove the value, there is nothing to set
        object[key] = nil
        dnsRemoved = true
        return true
    else
        local dns = {}
        for ip_Address in string.gmatch(value, '([^,]+)') do
          dns[#dns + 1] = ip_Address
	  local valid, helpmsg_validip = post_helper.validateStringIsIP(ip_Address, object, key)
	  if valid then
             if pIPV(value) then
                return nil, T"Public IP Range should not be used"
             end
	     -- Check for Limited Broadcast IP Address and "0.0.0.0" IP Address
             local ipAddr = ipv42num(ip_Address)
	     if ipAddr == broadcast_ip or ipAddr == 0 then
		return nil, T"Invalid IP Address"
             end
             --if not isNonPublicIPRange(ipAddr) then
             --   return nil, T"Public IP Range should not be used"
             --end
          else
	    return nil, helpmsg_validip
          end
        end
        if #dns > 3 then
            return nil, nil
        end
        object[key] = "6," .. value -- DHCP option for DNS server is option 6
        return true
    end
end

function isQtnGuestWiFi(intf)
    if wireless_radio[untaint(intf)] then
        local radio = proxy.get(format("rpc.wireless.ssid.@%s.radio", intf))
        local isRemote = proxy.get(format("rpc.wireless.radio.@%s.remotely_managed", radio[1].value))
        if isRemote and isRemote[1].value == "1" then
            for _, v in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
                local isGuest = proxy.get(v.path.."ap_isolation")
                if isGuest and isGuest[1].value == "1" then
                    return true
                end
            end
        end
    end
end

local function validateLeaseTime(value, postdata, key)
   if value == '-1' or value == timhelper.ethtrans().eth_infinit then -- included '-1' as a feasible set value as specified in TR 181
      postdata[key] = "infinite" -- included to ensure uci parameter is set as infinite
      return true
   else
      local success, msg = post_helper.validateStringIsLeaseTime(value)
      if success then
         postdata["leaseTime"] = match(untaint(value), "^0*([1-9]%d*[smhdw]?)$")
         return true
      else
         return nil, msg
      end
   end
end
--[[
Function calculateDHCPStartAddress, Calculating DHCPStartaddress using localdeviceip, netmask, newstart and newlimit value. function returns DHCPStartAddress, DHCPEndAddress  and NetworkAddress
]]
local function calculateDHCPStartAddress (baseip, netmask, start, numips)
    local network = bit.band(baseip, netmask)
    local ipmax = bit.bor(network, bit.bnot(netmask)) - 1
    local ipstart = bit.bor(network, bit.band(start, bit.bnot(netmask)))
    local ipend = ipstart+numips-1
    ipstart = num2ipv4(ipstart)
    if ipend > ipmax then
      ipend = ipmax
    end
    ipend = num2ipv4(ipend)
    network = num2ipv4(network)
  return ipstart,ipend,network
end

local function getDHCPData(object)
  -- Check the entered IP is valid IP and convert it to number
  local baseip = post_helper.validateStringIsIP(object["localdevIP"]) and ipv42num(object["localdevIP"])
  local netmask = post_helper.validateStringIsIP(object["localdevmask"]) and ipv42num(object["localdevmask"])
  local dhcpstart = post_helper.validateStringIsIP(object["dhcpStartAddress"]) and ipv42num(object["dhcpStartAddress"])
  local dhcpend = post_helper.validateStringIsIP(object["dhcpEndAddress"]) and ipv42num(object["dhcpEndAddress"])

  return baseip, netmask, dhcpstart, dhcpend
end

local STB_IP = {
  start = "uci.dhcp.dhcp.@STB.start",
  limit = "uci.dhcp.dhcp.@STB.limit"
}
content_helper.getExactContent(STB_IP)

local function calculateSTBRange(object)
  local stbstart = STB_IP.start
  local stblimit = STB_IP.limit
  local baseip, netmask = getDHCPData(object)
  local ipstart,ipend = calculateDHCPStartAddress(baseip,netmask,tonumber(stbstart),tonumber(stblimit))
  ipstart = ipv42num(ipstart)
  ipend = ipv42num(ipend)
  return ipstart, ipend
end

local function STBCheck(object, stbrange)
    if all_dhcp_intfs[1].paramindex == "STB" then
        local ipstart,ipend = calculateSTBRange(object)
        if stbrange >= ipstart and stbrange <= ipend then
            return "nil",T"Lan pool range is overlap with the STB pool range"
        end
    end
end

local function GWIPChanged()
    local post_data = ngx.req.get_post_args()
    local localdevIP = proxy.get("uci.network.interface.@" .. curintf .. ".ipaddr")
    if localdevIP and not ( localdevIP[1].value == post_data["localdevIP"] ) then
        return true
    end
    return false
end

-- Validation is done for the dhcpLimit for the particular subnet
-- If different subnet mask is given other than 255.255.255.0, then the
-- DHCP Range limit has to be calculated from the new subnet and the validation
-- has to be done for the new limit.
local function validateLimit(value, object)
    local dhcpIgnore = proxy.get(mapParams["dhcpIgnore"])
    if GWIPChanged() or ( dhcpIgnore and dhcpIgnore[1].value == "1") then --we bypass validation as the gateway ip has changed
        return true
    end
    if match(value, "^[0-9]*$") then
        local baseip, netmask, dhcpstart, dhcpend = getDHCPData(object)

        local ok,error = STBCheck(object, dhcpend)
        if ok then
            return nil, error
        end

        if not dhcpend then
            return nil, T"DHCP End Address is Invalid"
        end

        if dhcpstart and dhcpstart > dhcpend then
            return nil, T"DHCP Start Address should not be greater than End Address"
        end

        if baseip and netmask and dhcpstart then
            local network = bit.band(baseip, netmask)
            local ipmax = bit.bor(network, bit.bnot(netmask))
            local numips = dhcpend - dhcpstart + 1
            local limit = ipmax - network - 1

            if dhcpend == ipmax then
                return nil, T"Broadcast Address should not be used"
            end

            local validatorNumberInRange = post_helper.getValidateNumberInRange(1,limit)
            local limitvalue =  validatorNumberInRange(numips)
            if not limitvalue or dhcpend <= network or dhcpend >= ipmax then
                return nil, T"DHCP End Address is not valid in Subnet Range"
            end
            return true
        else
            return nil
        end
    else
        return nil, T"DHCP End Address is Invalid"
    end
end

-- Validation is done for the DHCP start Address for the particular subnet
-- For different subnets, validation for dhcpStart Address has to be done
-- from the new DHCP Range with respect to the subnet mask & Network Address
local function validateDHCPStart(value, object)
    local dhcpIgnore = proxy.get(mapParams["dhcpIgnore"])
    if GWIPChanged() or ( dhcpIgnore and dhcpIgnore[1].value == "1") then --we bypass validation as the gateway ip has changed
        return true
    end
    if match(value, "^[0-9]*$") then
        local baseip, netmask, dhcpstart, dhcpend = getDHCPData(object)

        if not dhcpstart then
            return nil, T"DHCP Start Address is Invalid"
        end

        if baseip and netmask and dhcpend then
            local network = bit.band(baseip, netmask)
            local ipmax = bit.bor(network, bit.bnot(netmask))
            local start = dhcpstart - network
            local numips = dhcpend - dhcpstart + 1

            local limit = ipmax - network - 1

            local validatorNumberInRange = post_helper.getValidateNumberInRange(1,limit)

            if dhcpstart == baseip then
                return nil, T"DHCP Start Address should not be Local Device IP Address"
            elseif dhcpstart == network then
                return nil, T"DHCP Start Address should not be a Network Address"
            end

            local val = validatorNumberInRange(start)
            if not val or dhcpstart <= network or dhcpstart >= ipmax then
                return nil, T"DHCP Start Address is not valid in Subnet Range"
            end

            -- Setting the dhcpStart and dhcpLimit from the calculated DHCP Range
            object["dhcpStart"] = tostring(start)
            object["dhcpLimit"] = tostring(numips)

            return true
        else
            return nil
        end
    else
        return nil, T"DHCP Start Address is Invalid"
    end
end

-- This function will validate the Modem IP Address and check for
-- Valid IP Format, Limited Broadcast Address, Public IP Range, Multicast Address Range
local function validateGWIP(value, object, key)
    local val, errmsg = aIPV(value, object, key)
    local post_data = ngx.req.get_post_args()
    if not val then
        return nil, errmsg
    end

    local ip = ipv42num(value)
    --<NG-100782
    if isNonPublicIPRange(ip) then
        local ipvalue = post_helper.validateStringIsIP(value) and ipv42num(value)
        local ipmask = post_data["localdevmask"]
        local ipnetmask = post_helper.validateStringIsIP(ipmask) and ipv42num(ipmask)

        local ipnetwork, ipmaxvalue
        if ipvalue and ipnetmask then
            ipnetwork = bit.band(ipvalue, ipnetmask)
            ipmaxvalue = bit.bor(ipnetwork, bit.bnot(ipnetmask))
        end
        --NG-100782>
        for _,intf in pairs(all_intfs) do
            if intf.paramindex ~= curintf then
                local ipaddr = proxy.get("uci.network.interface.@" .. intf.paramindex .. ".ipaddr")[1].value
                local mask = proxy.get("uci.network.interface.@" .. intf.paramindex .. ".netmask")[1].value
                local baseip = post_helper.validateStringIsIP(ipaddr) and ipv42num(ipaddr)
                local netmask = post_helper.validateStringIsIP(mask) and ipv42num(mask)
                local sfplocalip = proxy.get("uci.network.interface.@"..sfpintf..".ipaddr")

                if sfplocalip and sfplocalip[1].value then
                    sfplocalip = sfplocalip[1].value
                end

                local network, ipmax
                if baseip and netmask then
                    network = bit.band(baseip, netmask)
                    ipmax = bit.bor(network, bit.bnot(netmask))
                end

                if network and ipmax then
                    if ip == sfplocalip then
                        return nil, T"Gateway IP should not be in SFP interface IP Range, change that first"
                    end
                    if ip >= network and ip <= ipmax then
                        if intf.name ~= "" then
                            return nil, T"Gateway IP should not be in " .. intf.name .. T" IP Range"
                        else
                            return nil, T"Gateway IP should not be in " .. intf.paramindex .. T" IP Range"
                        end
                    end
                    --<NG-100782
                    if ipnetwork <= network and network <= ipmaxvalue then
                        if intf.name ~= "" then
                            return nil, T"The IP address is part of the "..intf.name.." IP Range"
                        else
                            return nil, T"The IP address is part of the "..intf.paramindex.." IP Range"
                        end
                    end
                    --NG-100782>
                end
            end
        end
    else
        return nil, T"Public IP Range should not be used"
    end
    return true
end

local function validateSFPIP(value, object, key)
    local val, errmsg = aIPV(value, object, key)
    local post_data = ngx.req.get_post_args()
    if not val then
        return nil, errmsg
    end

    local ip = ipv42num(value)
    --<NG-100782
    if isNonPublicIPRange(ip) then
        local ipvalue = post_helper.validateStringIsIP(value) and ipv42num(value)
        local ipmask = post_data["localdevmask"]
        local ipnetmask = post_helper.validateStringIsIP(ipmask) and ipv42num(ipmask)

        local ipnetwork, ipmaxvalue
        if ipvalue and ipnetmask then
            ipnetwork = bit.band(ipvalue, ipnetmask)
            ipmaxvalue = bit.bor(ipnetwork, bit.bnot(ipnetmask))
        end
        --NG-100782>
        for _,intf in pairs(all_intfs) do
            if intf.paramindex ~= sfpintf then
                local ipaddr = proxy.get("uci.network.interface.@" .. intf.paramindex .. ".ipaddr")[1].value
                local mask = proxy.get("uci.network.interface.@" .. intf.paramindex .. ".netmask")[1].value
                local baseip = post_helper.validateStringIsIP(ipaddr) and ipv42num(ipaddr)
                local netmask = post_helper.validateStringIsIP(mask) and ipv42num(mask)
                local lanip = proxy.get("uci.network.interface.@lan.ipaddr")

                if lanip and lanip[1].value then
                    lanip = lanip[1].value
                end

                local network, ipmax
                if baseip and netmask then
                    network = bit.band(baseip, netmask)
                    ipmax = bit.bor(network, bit.bnot(netmask))
                end

                if network and ipmax then
                    if ip == lanip then
                        return nil, T"SFP IP should not be in Gateway interface IP Range, change that first"
                    end
                    if ip >= network and ip <= ipmax then
                        if intf.name ~= "" then
                            return nil, T"SFP IP should not be in " .. intf.name .. T" IP Range"
                        else
                            return nil, T"SFP IP should not be in " .. intf.paramindex .. T" IP Range"
                        end
                    end
                    --<NG-100782
                    if ipnetwork <= network and network <= ipmaxvalue then
                        if intf.name ~= "" then
                            return nil, T"The IP address is part of the "..intf.name.." IP Range"
                        else
                            return nil, T"The IP address is part of the "..intf.paramindex.." IP Range"
                        end
                    end
                    --NG-100782>
                end
            end
        end
    else
        return nil, T"Public IP Range should not be used"
    end
    return true
end

local function isChecked(key, checked)
    for _,v in ipairs(checked) do
        if v == key then
            return true
        end
    end
    return false
end

local function validateEthports(value, object, key)
    local getValidateEthports = gVIC(ethports)
    local ok, msg = getValidateEthports(value, object, key)

    if not ok then
        return ok, msg
    end

    for k,v in ipairs(ethports) do
        object[v[1]] = nil
        object[v[1]] = isChecked(v[1], value) and "1" or "0"
    end

    return true
end

local function validatedhcpIgnore(value, object, key)
    local valid, msg = post_helper.getOptionalValidation(value, object, key)
    if not valid then
        return nil,  msg
    end

    if object["dhcpIgnore"] == "0" then
        object["dhcpIgnore"] = "1"
    end

    return true
end

local mapValid = {
    domainName = vNES,
    localdevIP = validateGWIP,
    --localIPv6 = validateIPv6,
    dnsServer = validateDNS,
    leaseTime = validateLeaseTime,
    localdevmask = post_helper.getAndValidation(vIP4N,post_helper.validateStringIsIP),
    dhcpStart = validateDHCPStart,
    dhcpLimit = validateLimit,
    --dhcpv4State = gVIES(dhcpv4Stateselect),
    dhcpIgnore = vB,
    eth0 = vB,
    ethports = validateEthports,
}

if sfp_presence and  (sfp_presence[1].value == "1") then
    mapValid["sfplocalip"] = validateSFPIP
end

if curintf == "lan" then
    mapParams.localIPv6 = "uci.network.interface.@" .. curintf .. ".ipv6"
    mapValid.localIPv6 = validateIPv6
end

for i = 1, ethport_count do
    mapValid["eth" .. i] = vB
end

-- This is quite convoluted but I only found this way to get it to work.
-- getExactContent will return an error if we access an unknown instance
-- so we cannot load from uci an option if it does not exist
-- in the end we only add the parameter to the parameters list if:
--    - it exists (get or post)
--    - we're doing a post -> in this case, we add an entry and delete it if validation fails
if (dnsIndex < #dhcp.options +1) or ( (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") ) then
    mapParams["dnsServer"] = baseDHCPOptions .. "@" .. dnsIndex .. ".value"
end
if (dnsIndex == #dhcp.options + 1) and (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") then
    proxy.add(baseDHCPOptions)
end

if ngx.var.request_method == "POST" then
local post_data = ngx.req.get_post_args()
	if post_data["action"] == "RESET" then
	local lanip, lanmask, ipstart, iplimit, ltime, dhcpig = restdhcp()
		proxy.set("uci.network.interface.@"..curintf..".ipaddr",lanip)
		proxy.set("uci.network.interface.@"..curintf..".netmask",lanmask)
		proxy.set("uci.dhcp.dhcp.@"..curintf..".start", ipstart)
		proxy.set("uci.dhcp.dhcp.@"..curintf..".limit", iplimit)
		proxy.set("uci.dhcp.dhcp.@"..curintf..".leasetime", ltime)
		proxy.set("uci.dhcp.dhcp.@"..curintf..".ignore", dhcpig)
		if (dnsIndex < #dhcp.options +1) then
			proxy.set(baseDHCPOptions .. "@" .. dnsIndex .. ".value", "6,"..lanip)
		end
	proxy.apply()
	end
end

content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

if (ngx.var.request_method == "POST")  and not next(helpmsg) then
   local dhcp_options_path = "uci.dhcp.dhcp.@"..cur_dhcp_intf..".dhcp_option."
   local dhcp_options = content_helper.convertResultToObject(dhcp_options_path,proxy.get(dhcp_options_path))
    for _,v in ipairs(dhcp_options) do
      if v.value:match("^3,") then
        proxy.del(dhcp_options_path..v.paramindex..".")
      end
    end
end

if content["dhcpIgnore"] == "" then
    content["dhcpIgnore"] = "0"
end

-- because we do the localdevmask validation in localdevIP validation, we check if local ip starts with error msg "[netmask]".
-- If so move it to localdevmask
if helpmsg["localdevIP"] then
  local msg = match(helpmsg["localdevIP"], '^%[netmask%] (.*)')
  if msg then
    helpmsg["localdevIP"] = nil
    helpmsg["localdevmask"] = msg
  end
end

if helpmsg["dhcpLimit"] then
    local msg = match(helpmsg["dhcpLimit"], '^%[dhcpStart%] (.*)')
    if msg then
        helpmsg["dhcpLimit"] = nil
        helpmsg["dhcpStart"] = msg
    end
end

-- post_helper restores values that have been removed during validation
-- so if you remove the dns server, it will still be displayed on the page (though correctly set in datamodel)
-- this handles this case
if dnsRemoved then
    content["dnsServer"] = ""
end
if content["dnsServer"] == nil then
    local localIP = proxy.get("uci.network.interface.@" .. curintf .. ".ipaddr")[1].value
    content["dnsServer"] = localIP
else
    if content["dnsServer"]:find("^6,") == 1 then
      content["dnsServer"] = (content["dnsServer"] or ""):sub(3) -- the dhcp option will contain "6," at the start
   end
end

if content["localIPv6"] == "" then
    content["localIPv6"] = "0"
end

if content["leaseTime"] == "infinite" then
	content["leaseTime"] = timhelper.ethtrans().eth_infinit
elseif not match(content["leaseTime"],"^0*([1-9]%d*[smhdw])$")then
  content["leaseTime"] = content["leaseTime"] .. "s"
end

local baseip = ipv42num(content["localdevIP"])
local netmask = ipv42num(content["localdevmask"])
local start = tonumber(content["dhcpStart"])
local numips = tonumber(content["dhcpLimit"])
local ipstart,ipend,network, modemIPChangeState

if start and numips and not helpmsg["localdevIP"] and not helpmsg["localdevmask"] and not helpmsg["dhcpStart"] and not helpmsg["dhcpLimit"] then
    ipstart , ipend , network = calculateDHCPStartAddress(baseip,netmask,start,numips)
    session:store("dhcpStartAddr",ipstart)
    session:store("dhcpEndAddr",ipend)
    session:store("networkAddr",network)
elseif ngx.var.request_method == "POST" then
    ipstart = ngx.req.get_post_args().dhcpStartAddress
    ipend = ngx.req.get_post_args().dhcpEndAddress
    network = session:retrieve("networkAddr")
else
    ipstart,ipend,network = "Error","Error","Error"
end

if ngx.var.request_method == "POST" and helpmsg["leaseTime"] then
    content["leaseTime"] = ngx.req.get_post_args().leaseTime
end


if ngx.var.request_method == "POST" then
    local gwIP = session:retrieve("old_ip")
    if curintf == "lan" and content["localdevIP"]~= gwIP and not next(helpmsg) then
        modemIPChangeState = "1"
    end
    session:store("old_ip",(content["localdevIP"]))

    -- Redirect the GUI only if the local GW device IP address is changed for the "lan" interface
    if curintf == "lan" and content["localdevIP"]~= gwIP and not next(helpmsg) then  ngx.print('\
    <script type="text/javascript">\
      window.location="http://');  ngx.print(content["localdevIP"]); ngx.print('";\
    </script>\
    ');  session:logout()
    end
else
    session:store("old_ip",(content["localdevIP"]))
end

local ethports_checked = {}
if type(content) == "table" then
    for _,v in ipairs(ethports) do
        if (content[v[1]] == "1") then
            ethports_checked[#ethports_checked + 1] = v[1]
        end
    end
end

ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Local Network", true, false))   ngx.print('\
\
   <div class="modal-body update">\
     <form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
     ');
-- Do not display the navlist on the list if only 1 lan interface
if #lan_intfs> 1 then
    ngx.print('\
     <div class="span2">\
        <ul class="nav nav-list">\
        ');
    local html = { format('<li class="nav-header">%s</li>', T"LAN Interfaces") }
    for k,v in ipairs(lan_intfs) do
        local prev = ""
        if v.radio ~= prev then
            if v.radio ~= "noradio" then
                html[#html + 1] = format('<li class="nav-header">%s %s</li>', T"Access point", v.radio)
            else
                html[#html + 1] = format('<li class="nav-header">%s</li>', T"Ethernet")
            end

        end
        local active = ""
        if v.index == curintf then
            active = "active"
        end
        local url = "modals/ethernet-modal.lp?intf=" .. v.index
        html[#html+1] = format('<li class="%s"><a id = "%s" href="#" data-remote="%s">%s</a></li>', active, v.index, url, v.name)
    end
    ngx.print(html)
    ngx.print('\
        </ul>\
     </div>\
     <div class="span6">\
        ');
end
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
ngx.print('\
          <fieldset>\
              <legend>');  ngx.print( T"Global Information" ); ngx.print('</legend>\
              ');
local advanced = {
    group = {
        class = "advanced hide"
    }
}
local advanced_network = {
    group = {
        class = "advanced hide"
    }
}
local info_box = {
    alert = {
        class = "alert alert-info",
    }
}

-- Labels that shows the Local Device IP address & network subnet
local html = {}

html[#html + 1] = ui_helper.createInputText(T"Domain Name", "domainName", content["domainName"], {} , helpmsg["domainName"] )
html[#html + 1] = ui_helper.createInputText(T"Modem IP address", "localdevIP", content["localdevIP"],{},helpmsg["localdevIP"])
html[#html + 1] = ui_helper.createInputText(T"Local Network subnet", "localdevmask", content["localdevmask"], advanced, helpmsg["localdevmask"])
html[#html + 1] =ui_helper.createButton(T"Reset to default", T"Reset", "icon-bolt", clear_network_stats)
if curintf == "lan" then
    html[#html + 1] = ui_helper.createSwitch(T"IPv6 state", "localIPv6", content["localIPv6"])
    if curintf == "lan" and tech then
        html[#html + 1] = ui_helper.createCheckboxGroup(T"Ethernet Ports enabled", "ethports", ethports, ethports_checked, {checkbox = { class="inline" }}, nil)
    end
    if sfp_presence and ( sfp_presence[1].value == "1" ) then
        html[#html + 1] = ui_helper.createAlertBlock(T"Switch the WAN port to a normal LAN port", info_box)
        html[#html + 1] = ui_helper.createSwitch(T"WAN-Port LAN Mode", "ethsfp", content_sfp["ethsfp"])
    end
    local IPv6addr = proxy.get("rpc.network.interface.@"..curintf..".ip6addr")[1].value
    if IPv6addr == "" then
        html[#html + 1] = ui_helper.createLabel(T"LAN IPv6", T"IPv6 not assigned", advanced)
    else
        html[#html + 1] = ui_helper.createLabel(T"LAN IPv6", IPv6addr, advanced)
    end
    if sfp_presence and ( sfp_presence[1].value == "1" ) then
        html[#html + 1] = ui_helper.createAlertBlock(T("This is the internal IP of the SFP interface used for fiber connection. " ..
                "This and the local Gateway IP must be different."), info_box)
        html[#html + 1] = ui_helper.createInputText(T"SFP IP address", "sfplocalip", content["sfplocalip"],{},helpmsg["sfplocalip"])
    end
end
ngx.print(html)
ngx.print('\
              <legend>');  ngx.print( T"DHCP Settings" ); ngx.print('</legend>\
              ');
-- Labels that shows DHCP info
local switchDHCP = {
    values = {
        on = "0",
        off = "1"
    }
}
local html = {}
html[#html + 1] = ui_helper.createSwitch(T"DHCP Server", "dhcpIgnore", content["dhcpIgnore"],switchDHCP)
html[#html + 1] = ui_helper.createLabel(T"Network address", network, advanced_network)
html[#html + 1] = ui_helper.createInputText(T"DHCP Start address", "dhcpStartAddress", ipstart, advanced, helpmsg["dhcpStart"])
html[#html + 1] = ui_helper.createInputText(T"DHCP End address", "dhcpEndAddress", ipend, advanced, helpmsg["dhcpLimit"])
html[#html + 1] = ui_helper.createInputText(T"Lease time", "leaseTime", content["leaseTime"], advanced, helpmsg["leaseTime"])
html[#html + 1] = ui_helper.createInputText(T"DNS server", "dnsServer", content["dnsServer"], advanced, helpmsg["dnsServer"])
ngx.print(html)
ngx.print('\
               ');
--[[if dhcpDefaultExist then
   local wait_for_reset = {
       group = {
          class = "advanced hide"
       },
       button = {
          id = "btn-dhcp-reset"
       }
   }
   ngx.print(ui_helper.createButton(T"Restore Default Configuration", T"Reset Configuration", "icon-bolt", wait_for_reset))
end]]
ngx.print('\
              ');
-- Do not display the static lease when the interface is not lan
if curintf == "lan" and modemIPChangeState ~= "1" then
    ngx.print('\
                  <legend>');  ngx.print( T"Static leases" ); ngx.print('</legend>\
                  ');
    local confilictipchange_alert = {
        alert = {
            class = "alert hide",
            id = "confilictipchange-msg"
        }
    }
    ngx.print(
        ui_helper.createAlertBlock(T("The latest added/modified static lease is set to an IP that is already in use," ..
                " please perform a reboot to apply the changes"), confilictipchange_alert),
        ui_helper.createTable(sleases_columns, sleases_data, sleases_options, nil, sleases_helpmsg))
    ngx.print('\
              </fieldset>\
              ');
end
ngx.print('\
          ');
-- Do not display the navlist on the list if only 1 lan interface
if #lan_intfs > 1 then
    ngx.print('\
          </div>\
          ');
end
ngx.print('\
          <input type="hidden" name="isAdvanced" id="isAdvanced" value="0">\
        </form>\
   </div>\
\
<script type=\'text/javascript\'>\
$(function() {\
    var iPv6StateOnlyChanged = 0;\
    $("input, select").on("change", function(){\
       if(this.id == "localIPv6" && iPv6StateOnlyChanged == 0)\
         iPv6StateOnlyChanged = 1;\
       else\
         iPv6StateOnlyChanged = 2;\
    });\
    //Override the save button click event to update the IPv6 state alone.\
    $("#save-config").on("click", function(){\
         if(iPv6StateOnlyChanged == 1){\
          var params = [];\
          params.push({\
            name : "action",\
            value : "SAVE"\
          },\
          {\
            name : "iPv6StateOnlyChanged",\
            value : "yes"\
          },\
          {\
            name : "localIPv6",\
            value : $("#localIPv6").val()\
          }, tch.elementCSRFtoken());\
          var target = $(".modal form").attr("action");\
          tch.showProgress(waitMsg);\
          $.post(target, params, function(response){\
            //The following block of code used to display the success/error message and manage the footer.\
            $(".alert").remove();\
            $("form").prepend(response);\
            $("#modal-changes").attr("style","display:none");\
            $("#modal-no-change").attr("style","display:block");\
            iPv6StateOnlyChanged = 0;\
            tch.removeProgress();\
          });\
          return false;\
         }\
     });\
\
    var currentlanip = "');  ngx.print( content["localdevIP"] ); ngx.print('";\
    $("[name=\'localdevIP\']").on("change", function(){\
	  var NewIp = $(this).val();\
	  var StartDHCP = $("[name=\'dhcpStartAddress\']").val().replace(currentlanip.match(/[0-9]+\.[0-9]+\.[0-9]+\./g),\'\');\
	  var EndDHCP = $("[name=\'dhcpEndAddress\']").val().replace(currentlanip.match(/[0-9]+\.[0-9]+\.[0-9]+\./g),\'\');\
	  var NewIpBase = NewIp.match(/[0-9]+\.[0-9]+\.[0-9]+\./g);\
      if (currentlanip == $("[name=\'dnsServer\']").val()){\
          $("[name=\'dnsServer\']").val(NewIp);\
          currentlanip = NewIp;\
      }\
	  document.getElementById("'); ngx.print( T"Network address" ); ngx.print('").innerHTML = NewIpBase+"0";\
	  $("[name=\'dhcpStartAddress\']").val(NewIpBase+StartDHCP);\
	  $("[name=\'dhcpEndAddress\']").val(NewIpBase+EndDHCP);\
    });\
\
    $("#save-config").on("click", function(){\
      if($("#Hide_Advanced_id").is(":visible"))\
        $("#isAdvanced").val("1");\
      else\
        $("#isAdvanced").val("0");\
    });\
\
});\
$("[name =\'sleases_mac\']").on("change", function () {\
    if ((this.value) == "custom") {\
          $(this).replaceWith($(\'<input/>\',{\'type\':\'text\', \'name\':\'sleases_mac\'}));\
    }\
});\
\
');  if dhcpDefaultExist then   ngx.print('\
$("#btn-dhcp-reset").on("click", function(){\
  ');  for k,v in pairs(dhcpDefaultExist) do   ngx.print('\
    $("#');  ngx.print(k); ngx.print('").val("');  ngx.print(v); ngx.print('");\
  ');  end  ngx.print('\
  $("#localIPv6").prev().removeClass("switcherOn").closest(".switch").removeClass("switchOn");\
  $("#dhcpState").prev().addClass("switcherOn").closest(".switch").addClass("switchOn");\
  $("#modal-changes").show();\
  $("#modal-no-change").hide();\
});\
');  end  ngx.print('\
  ');  if inUseFlag == true then  ngx.print('\
  $("#confilictipchange-msg").show();\
  ');  end   ngx.print('\
</script>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 
