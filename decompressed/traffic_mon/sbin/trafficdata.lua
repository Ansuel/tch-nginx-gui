#! /usr/bin/lua

local uloop = require("uloop")
local content_helper = require("web.content_helper")
local format = string.format
local proxy = require("datamodel")

local traffic_data_file = "/var/state/traffic_data_file"

local function getFile(file_name)
  local fd = io.open(file_name,"r")
  local values = {}
  if fd  then
    for l in fd:lines() do
      values[#values+1] = l
    end
    fd:close()
    return values
  else
    return nil
  end
end

local function calculation(oldtable,file_content)
  local lastnumber = oldtable.lastnumber
  local period = oldtable.period
  if file_content and lastnumber then
    if(tonumber(file_content) < tonumber(lastnumber)) then
      period = period +1
    end
    if tonumber(period) > 256 then
      period = 0
    end
    oldtable = {period,file_content}
  else
    oldtable = {0,file_content}
  end
  return oldtable
end

local function writeFile(file, content)
 local result= getFile(file)
 local fd = io.open(file,"w")
 if fd  then
   if result then
     local wan_rx_data= {
     period = result[1],
     lastnumber = result[2],
     }
     local wan_tx_data= {
     period = result[3],
     lastnumber = result[4],
     }
     local lan_rx_data = {
     period = result[5],
     lastnumber = result[6],
     }
     local lan_tx_data = {
     period = result[7],
     lastnumber = result[8],
     }
     local wifi_rx_data = {
     period = result[9],
     lastnumber = result[10],
     }
     local wifi_tx_data = {
     period = result[11],
     lastnumber = result[12],
     }
    local wan_rx_result = calculation(wan_rx_data,content.wan_rx)
    local wan_tx_result = calculation(wan_tx_data,content.wan_tx)
    local lan_rx_result = calculation(lan_rx_data,content.lan_rx)
    local lan_tx_result = calculation(lan_tx_data,content.lan_tx)
    local wifi_rx_result = calculation(wifi_rx_data,content.wifi_rx)
    local wifi_tx_result = calculation(wifi_tx_data,content.wifi_tx)

     fd:write(tostring(wan_rx_result[1]).."\n")
     fd:write(tostring(wan_rx_result[2]).."\n")

     fd:write(tostring(wan_tx_result[1]).."\n")
     fd:write(tostring(wan_tx_result[2]).."\n")

     fd:write(tostring(lan_rx_result[1]).."\n")
     fd:write(tostring(lan_rx_result[2]).."\n")

     fd:write(tostring(lan_tx_result[1]).."\n")
     fd:write(tostring(lan_tx_result[2]).."\n")

     fd:write(tostring(wifi_rx_result[1]).."\n")
     fd:write(tostring(wifi_rx_result[2]).."\n")

     fd:write(tostring(wifi_tx_result[1]).."\n")
     fd:write(tostring(wifi_tx_result[2]))
     fd:close()
   else
     -- /var/state/traffic_data_file store 12 rows data,When the file has no content, the default is written to 0
     fd:write(string.rep("0\n", 12))
     fd:close()
   end
  end
end

local function s2n(str)
  return tonumber(str) or 0
end

local function b2m(number)
  return format("%.3f", number / 1048576)
end

local quantenna_wifi = proxy.get("uci.env.var.qtn_eth_mac")
quantenna_wifi = ((quantenna_wifi and quantenna_wifi[1].value~="") and true or false)

local function reCalculateContent()

	local content_lan = {
		tx_bytes = "rpc.network.interface.@lan.tx_bytes",
		rx_bytes = "rpc.network.interface.@lan.rx_bytes",
		ifname = "uci.network.interface.@lan.ifname",
	}
	
	content_helper.getExactContent(content_lan)
	
	local lantx = b2m(s2n(content_lan.tx_bytes))
	local lanrx = b2m(s2n(content_lan.rx_bytes))
	
	local wan_intf ="wan"
	local ipaddr = proxy.get("rpc.network.interface.@wwan.ipaddr")
	if ipaddr and ipaddr[1].value:len() ~= 0 then
		wan_intf = "wwan"
	end
	
	local content_wan = {
		tx_bytes = "rpc.network.interface.@" .. wan_intf .. ".tx_bytes",
		rx_bytes = "rpc.network.interface.@" .. wan_intf .. ".rx_bytes",
		ifname = "uci.network.interface.@" .. wan_intf .. ".ifname",
	}
	content_helper.getExactContent(content_wan)
	
	local wantx = b2m(s2n(content_wan.tx_bytes))
	local wanrx = b2m(s2n(content_wan.rx_bytes))
	
	local piface = "uci.wireless.wifi-iface."
	local awls = content_helper.convertResultToObject(piface .. "@.", proxy.get(piface))
	local wls = {}
	for i,v in ipairs(awls) do
			wls[#wls+1] = {
				radio = v.device,
				ssid = v.ssid,
				iface = v.paramindex
			}
			if v.paramindex == getiface then
				curiface = v.paramindex
				if quantenna_wifi and curiface == "wl1" then
					curiface = "eth5"
				end
				curssid = v.ssid
			end
	end
	table.sort(wls, function(a,b)
		if a.radio == b.radio then
			return a.iface < b.iface
		else
			return a.radio < b.radio
		end
	end)
	local wifitx, wifirx = 0, 0
	local content_wifi = {}
	for i,v in ipairs(wls) do
		if proxy.get("sys.class.net.@" .. v.iface .. ".") then
			if quantenna_wifi and v.iface == "wl1" then
				v.iface = "eth5"
			end
			content_wifi["tx_bytes"] = "sys.class.net.@" .. v.iface .. ".statistics.tx_bytes"
			content_wifi["rx_bytes"] = "sys.class.net.@" .. v.iface .. ".statistics.rx_bytes"
			content_helper.getExactContent(content_wifi)
			wifitx = wifitx + s2n(content_wifi.tx_bytes)
			wifirx = wifirx + s2n(content_wifi.rx_bytes)
		end 
	end
	wifitx = b2m(wifitx)
	wifirx = b2m(wifirx)
	
	local content_common = {
	wan_tx = wantx,
	wan_rx = wanrx,
	lan_tx = lantx,
	lan_rx = lanrx,
	wifi_tx = wifitx,
	wifi_rx = wifirx,
	}
	
	return content_common
end

uloop.init()

-- 3 minutes in millisc = 3 * 60 * 1000
local delay_polling_time = 180000‬

local function start_timer()
	uloop.timer(
		function ()
			writeFile(traffic_data_file,reCalculateContent())
			start_timer()
		end
	,delay_polling_time)
end

writeFile(traffic_data_file,reCalculateContent())
start_timer()

uloop.run()
