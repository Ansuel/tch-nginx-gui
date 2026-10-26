--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local table, string = table, string
local tonumber = tonumber
local format = string.format

--Funtion that gets information of a particular wireless station, the parameter received is the MAC address
local stationConf = {}
local getStationData = function(stationMAC)
		stationConf = {}
		local stationPath = format("rpc.wireless.ap.@ap0.station.@%s.", stationMAC)
		stationConf = {
				state = stationPath .. "state",
				flags = stationPath .. "flags",
				capabilities = stationPath .. "capabilities",
				last_rssi = stationPath .. "last_rssi",
				rssi = stationPath .. "rssi",
				av_rssi = stationPath .. "av_rssi",
				rx_bytes = stationPath .. "rx_bytes",
				tx_bytes = stationPath .. "tx_bytes",
				tx_phy_rate = stationPath .. "tx_phy_rate",
				rx_phy_rate = stationPath .. "rx_phy_rate",
		}

		local m_status, m_error = content_helper.getExactContent(stationConf)

		stationConf["radio"] = "2.4Ghz"
		return m_status
end

local getStationData5G = function(stationMAC)
		stationConf = {}
		local stationPath = format("rpc.wireless.ap.@ap1.station.@%s.", stationMAC)
		stationConf = {
			state = stationPath .. "state",
			flags = stationPath .. "flags",
			capabilities = stationPath .. "capabilities",
			last_rssi = stationPath .. "last_rssi",
			rssi = stationPath .. "rssi",
			av_rssi = stationPath .. "av_rssi",
			rx_bytes = stationPath .. "rx_bytes",
			tx_bytes = stationPath .. "tx_bytes",
			tx_phy_rate = stationPath .. "tx_phy_rate",
			rx_phy_rate = stationPath .. "rx_phy_rate",
		}

		local m_status, m_error = content_helper.getExactContent(stationConf)
		stationConf["radio"] = "5Ghz"
		return m_status
end

local hosts = proxy.get("sys.hosts.host.")
local hosts = content_helper.convertResultToObject("sys.hosts.host.",hosts)

local datarows ={}
local index = 1

--Only handle the devices that on "br-lan", others will be filtered out.
for x = 1, #hosts, 1 do
    if hosts[x].L3Interface == "br-lan" then
			local n_status
			--Here the WiFi Nurse info is populated
			if hosts[x].InterfaceType == "wireless" then
				n_status= getStationData(hosts[x].MACAddress)
				if tostring(n_status) == "true" then
					datarows[index]={}
					datarows[index][1] = hosts[x].HostName
					datarows[index][2] = stationConf["capabilities"]
					datarows[index][3] = tostring(tonumber(stationConf["tx_phy_rate"])/1000).." ".."Mbps"
					datarows[index][4] = "5"

					local lastRSSI = tonumber(stationConf["last_rssi"])
					if stationConf["state"] ~= "Disconnected" then
						if lastRSSI > -41 then
							datarows[index][5] = T"Excellent"
							datarows[index][4] = "1"
						else
							if lastRSSI > -55 then
								datarows[index][5] = T"Good"
								datarows[index][4] = "1"
							else
								if lastRSSI > - 71 then
									datarows[index][5] = T"Ok"
									datarows[index][4] = "1"
								else
									if lastRSSI > - 81 then
										datarows[index][5] = T"Satisfactoy"
										datarows[index][4] = "3"
									else
										datarows[index][5] = T"Limited. Expect dropouts."
										datarows[index][4] = "4"
									end
								end
							end
						end
					else
						datarows[index][5] = T"Disconnected"
						datarows[index][4] = "5"
					end

					datarows[index][6] = stationConf["last_rssi"]
					datarows[index][7] = stationConf["av_rssi"]
					datarows[index][8] = stationConf["rssi"]
					datarows[index][9] = format("%.1f KB",tostring(tonumber(stationConf["tx_bytes"])/1000))
					datarows[index][10] = format("%.1f KB",tostring(tonumber(stationConf["rx_bytes"])/1000))
					datarows[index][11] = stationConf["radio"]
					index = index + 1
				end

				n_status= getStationData5G(hosts[x].MACAddress)

				if tostring(n_status) == "true" then
					datarows[index]={}
					datarows[index][1] = hosts[x].HostName
					datarows[index][2] = stationConf["capabilities"]
					datarows[index][3] = tostring(tonumber(stationConf["tx_phy_rate"])/1000).." ".."Mbps"
					datarows[index][4] = "5"

					local lastRSSI = tonumber(stationConf["last_rssi"])
					if stationConf["state"] ~= "Disconnected" then
						if lastRSSI > -41 then
							datarows[index][5] = T"Excellent"
							datarows[index][4] = "1"
						else
							if lastRSSI > -55 then
								datarows[index][5] = T"Good"
								datarows[index][4] = "1"
							else
								if lastRSSI > - 71 then
									datarows[index][5] = T"Ok"
									datarows[index][4] = "1"
								else
									if lastRSSI > - 81 then
										datarows[index][5] = T"Satisfactory"
										datarows[index][4] = "3"
									else
										datarows[index][5] = T"Limited. Expect dropouts."
										datarows[index][4] = "4"
									end
								end
							end
						end
					else
						datarows[index][5] = T"Disconnected"
						datarows[index][4] = "5"
					end

					datarows[index][6] = stationConf["last_rssi"]
					datarows[index][7] = stationConf["av_rssi"]
					datarows[index][8] = stationConf["rssi"]
					datarows[index][9] = format("%.1f KB",tostring(tonumber(stationConf["tx_bytes"])/1000))
					datarows[index][10] = format("%.1f KB",tostring(tonumber(stationConf["rx_bytes"])/1000))
					datarows[index][11] = stationConf["radio"]
					index = index + 1
				end
			end
    end
end

--Column Names
local columns ={}
for i=1, 11 do
    columns[i]={}
end
columns[1]["header"] = T"Name"
columns[2]["header"] = T"Capabilities"
columns[3]["header"] = T"Max Speed"
columns[4]["header"] = T""
columns[4]["type"] = "light"
columns[4]["readonly"] = "true"

columns[5]["header"] = T"Signal Quality"
columns[6]["header"] = T"Last RSSI"
columns[7]["header"] = T"Avg RSSI"
columns[8]["header"] = T"RSSI"
columns[9]["header"] = T"Tx Bytes"
columns[10]["header"] = T"Rx Bytes"
columns[11]["header"] = T"Band"
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"WiFi Nurse", false, true) ); ngx.print('\
\
<div class="modal-body update">');
	local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-device.lp")
	ngx.print('\
  <form class="form-horizontal" method="post" action="modals/wifi-nurse-modal.lp">\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
\
	<legend><b>');  ngx.print( T"WiFi Nurse" ); ngx.print('</b></legend>\
	<fieldset>\
	');  
		local html = {}
		ngx.print(html)
		local options = { tableid = "networkstats", canEdit = false, editing = false, minEntries = 5, maxEntries = 7, createMsg = "Create new", canAdd = false, canDelete = false, newList = true, errmsg = nil}
		table.insert(html, ui_helper.createTable(columns, datarows, options))
		ngx.print(html)
	  ngx.print('\
	  </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 