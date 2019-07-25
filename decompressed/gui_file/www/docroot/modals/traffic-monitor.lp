--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local string, ngx, os = string, ngx, os
local tonumber = tonumber
local format, concat = string.format, table.concat
local traffic_data_file = "/var/state/traffic_data_file"

local section_selected

local quantenna_wifi = proxy.get("uci.env.var.qtn_eth_mac")
quantenna_wifi = ((quantenna_wifi and quantenna_wifi[1].value~="") and true or false)
local getargs = ngx.req.get_uri_args()
local getiface = getargs.iface

local sfp = require("transformer.shared.sfp").readSFPFlag()
local eth4lanwanmode = proxy.get("uci.ethernet.globals.eth4lanwanmode")
local lan_list = {
	{iface = "br-lan", name = T"Lan Bridge"},
	{iface = "eth0", name = T"Port 1"}, 
	{iface = "eth1", name = T"Port 2"}, 
	{iface = "eth2", name = T"Port 3"}, 
}

local lan_intf = "br-lan"
local lan_name = T"Lan Bridge"

if sfp == 1 then
	if eth4lanwanmode and eth4lanwanmode[1].value == "1" then
		lan_list[#lan_list+1] = { iface = "eth3", name = T"Port 4"}
	end
else
	local ethname = proxy.get("sys.eth.port.@eth3.status")
	if ethname and ethname[1].value then
		lan_list[#lan_list+1] = { iface = "eth3", name = T"Port 4"}
	end	
end

for _,v in pairs(lan_list) do
	if v.iface == getiface then
		lan_intf = v.iface
		lan_name = v.name
		section_selected = "lan"
	end
end

local curiface = "wl0"
local curssid = ""

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
			section_selected = "wifi"
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

local wan_intf ="wan"
local ipaddr = proxy.get("rpc.network.interface.@wwan.ipaddr")
if ipaddr then
	ipaddr = ipaddr[1].value
	if ipaddr:len() ~= 0 then
		wan_intf = "wwan"
	end
end

local content_wan = {
  tx_bytes = "rpc.network.interface.@" .. wan_intf .. ".tx_bytes",
  rx_bytes = "rpc.network.interface.@" .. wan_intf .. ".rx_bytes",
  ifname = "uci.network.interface.@" .. wan_intf .. ".ifname",
}
content_helper.getExactContent(content_wan)

local content_lan = {
  tx_bytes = "rpc.network.interface.@lan.tx_bytes",
  rx_bytes = "rpc.network.interface.@lan.rx_bytes",
  ifname = "uci.network.interface.@lan.ifname",
}
content_helper.getExactContent(content_lan)

local function s2n(str)
  if str == nil or str == "" then
    return 0
  else
    return tonumber(str)
  end
end

local function b2m(number)
  return format("%.3f", number / 1048576)
end

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


local wantx = s2n(content_wan.tx_bytes)
local wanrx = s2n(content_wan.rx_bytes)
local lantx = s2n(content_lan.tx_bytes)
local lanrx = s2n(content_lan.rx_bytes)

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

local content_result = getFile(traffic_data_file)
if content_result then
  if s2n(content_result[2]) > s2n(wanrx)  then
     content_result[1] = content_result[1]+1
  end
  if s2n(content_result[4]) > s2n(wantx)  then
     content_result[3] = content_result[3]+1
  end
  if s2n(content_result[6]) > s2n(lanrx)  then
     content_result[5] = content_result[5]+1
  end
  if s2n(content_result[8]) > s2n(lantx)  then
     content_result[7] = content_result[7]+1
  end
  if s2n(content_result[10]) > s2n(wifirx)  then
     content_result[9] = content_result[9]+1
  end
  if s2n(content_result[12]) > s2n(wifitx)  then
     content_result[11] = content_result[11]+1
  end
  wanrx  = wanrx+content_result[1]
  wantx  = wantx+content_result[3]
  lanrx  = lanrx+content_result[5]
  lantx  = lantx+content_result[7]
  wifirx = wifirx+content_result[9]
  wifitx = wifitx+content_result[11]
end

local wantotal = wantx + wanrx
local lantotal = lantx + lanrx
local wifitotal = wifitx + wifirx

local function getTrafficData(dtype, name)
    local nline = 1
    local data = {}
	local datatime = {}
    filename = format("/tmp/trafficmon/%s_%s", name, dtype)
    f = io.open(filename, "r")
    if f then
        for line in f:lines() do
            if (nline < 2 ) then
                nline = nline + 1 --skip first line
            elseif (nline == 2) then
				nline = nline +1
				data[#data+1] = line:match(".*%s"):gsub("%s+", "") or "NaN"
				datatime[#datatime+1] = '"'
				datatime[#datatime+1] = line:match("%s.*"):gsub("%s+","") or "NaN"
				datatime[#datatime+1] = '"'
            else
				data[#data+1] = ","
				data[#data+1] = line:match(".*%s"):gsub("%s+", "") or "NaN"
				datatime[#datatime+1] = ","
				datatime[#datatime+1] = '"'
				datatime[#datatime+1] = line:match("%s.*"):gsub("%s+","") or "NaN"
				datatime[#datatime+1] = '"'
            end
        end
        f:close()
    end
	
	local ret = {
		data = concat(data),
		time = concat(datatime),
	}
	
    return ret
end

proxy.set("rpc.system.lock.datadir", "/tmp/trafficmon/")
proxy.apply()

local interface = proxy.get("rpc.network.interface.@wan.ifname")
local wan = proxy.get("rpc.network.interface.@wan.up") 
wan = wan and wan[1].value or nil

local graph_interface = interface and interface[1].value or "br-lan"

if graph_interface:match("wan") then
	local real_interface = proxy.get(format("uci.network.device.@%s.ifname",graph_interface))
	if real_interface then
		graph_interface = real_interface[1].value or "br-lan"
	end
end

local traffic = {}

local TrafficIntf = {
	wan = graph_interface,
	lan = lan_intf,
	wifi = curiface,
}

for Intf, IntfName in pairs (TrafficIntf) do
	traffic[Intf] = {}
	for _,TrafficType in pairs({"rx","tx"}) do
		traffic[Intf][TrafficType] = getTrafficData(TrafficType.."_bytes",IntfName)
	end
end

proxy.set("rpc.system.lock.free", "0")
proxy.apply()

ngx.print(ui_helper.createHeader(T"Traffic Monitor", false, true) ); ngx.print('\
<div class="modal-body update no-save">\
');
	local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-device.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/traffic-monitor.lp">\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      local html = {}
	  local attributes = {
			label = { class = "control-label" } ,
			span = { class = "text-right traffic_data" } ,
			}
	  local info_box = {
          alert = {
		  	class = "alert alert-info",
		  }
        }
		
	  local traffic_section = {
		{
			desc = T"Internet Traffic",
			total = wantotal,
			tx = wantx,
			rx = wanrx
		},
		{
			desc = T"Ethernet Network Traffic",
			total = lantotal,
			tx = lantx,
			rx = lanrx
		},
		{
			desc = T"Wi-Fi Network Traffic",
			total = wifitotal,
			tx = wifitx,
			rx = wifirx
		}
	  }
	  
	  html[#html+1] = '<div class="row" style="margin-left:0px;flex-wrap: wrap;">'
	  for i in pairs(traffic_section) do
		html[#html+1] = '<div class="span3" style="flex:1;">'
	    html[#html+1] =   "<fieldset><legend>" .. traffic_section[i].desc .. "</legend>"
	    html[#html+1] =     ui_helper.createLabel(T"Total Mixed", traffic_section[i].total , attributes)
	    html[#html+1] =     ui_helper.createLabel(T"Total Send", traffic_section[i].tx, attributes)
	    html[#html+1] =     ui_helper.createLabel(T"Total Receive", traffic_section[i].rx, attributes)
	    html[#html+1] =   "</fieldset>"
	    html[#html+1] = "</div>"
	  end
	  html[#html+1] = '</div>'
	  
	  html[#html+1] = "<fieldset><legend>" .. T"Graph" .. "</legend>"
	  html[#html+1] = ui_helper.createAlertBlock(T"The time displayed on the graph is the modem time.", info_box)
	  html[#html+1] =	'<table>'
	  html[#html+1] =	'<tr>'
	  html[#html+1] =		'<td style="background-color:#90cd8a" >&nbsp;&nbsp;&nbsp;&nbsp;</td>'
	  html[#html+1] =		'<td nowrap style="padding-right: 20px;padding-left: 10px;">'
	  html[#html+1] =		T"Sent chart line"
	  html[#html+1] =		'<input type="checkbox" id="sent" name="sent" checked style="margin-left:10px;"></td>'
	  html[#html+1] =		'<td style="background-color:#f58368">&nbsp;&nbsp;&nbsp;&nbsp;</td>'
	  html[#html+1] =		'<td nowrap style="padding-right: 20px;padding-left: 10px;">'
	  html[#html+1] =		T"Received chart line"
	  html[#html+1] =		'<input type="checkbox" id="received" name="received" checked style="margin-left:10px;"></td>'
	  html[#html+1] =	'</tr>'
	  html[#html+1] =	'</table>'
	  html[#html+1] = "</fieldset>"
	  
	  -- Traffic Graph
	  
	  html[#html+1] = "<fieldset><legend>" .. T"WAN Graph" .. "</legend>"
	  html[#html+1] = '<div style="height:400px"><canvas id="WANChart"></canvas></div>'
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = '<fieldset id="LANSection"><legend>' .. T"LAN Graph" .. "</legend>"
	  html[#html+1] = '<ul class="nav nav-tabs">'
      for _,v in ipairs(lan_list) do
          local active = ""
          if v.iface == lan_intf then
              active = "active"
          end
          local url = "modals/traffic-monitor.lp?iface=" .. v.iface
          html[#html+1] = format('<li class="%s"><a id ="%s" href="#" data-remote="%s">%s</a></li>', active, v.iface , url, v.name)
      end
      html[#html+1] =  "</ul>"
	  html[#html+1] = '<div style="height:400px"><canvas id="LANChart"></canvas></div>'
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "&nbsp"
	  html[#html+1] = '<fieldset id="WifiSection">'
      html[#html+1] = '<ul class="nav nav-tabs">'
      for i,v in ipairs(wls) do
          local active = ""
          if v.iface == curiface or ( quantenna_wifi and v.iface == "wl1" and curiface == "eth5" ) then
              active = "active"
          end
          local url = "modals/traffic-monitor.lp?iface=" .. v.iface
          html[#html+1] = format('<li class="%s"><a id ="%s" href="#" data-remote="%s">%s</a></li>', active, v.iface , url, v.ssid)
      end
      html[#html+1] =  "</ul>"
	  html[#html+1] =  '<div style="height:400px"><canvas id="WiFiChart"></canvas></div>'
	  html[#html+1] = "</fieldset>"
	  ngx.print(html)
	  
	  ngx.print('\
  </form>\
 </div>\
\
<script language ="javascript">\
')
if section_selected == "wifi" then
	ngx.print('$("#WifiSection")[0].scrollIntoView();');
elseif section_selected == "lan" then
	ngx.print('$("#LANSection")[0].scrollIntoView();');
end
ngx.print('\
\
$("#sent").on("click", function() {\
    if(this.checked) {\
    LANChart.data.datasets[0].hidden=false;\
	WANChart.data.datasets[0].hidden=false;\
	WiFiChart.data.datasets[0].hidden=false;\
	LANChart.update();\
	WANChart.update();\
	WiFiChart.update();\
		} else {\
    LANChart.data.datasets[0].hidden=true;\
	WANChart.data.datasets[0].hidden=true;\
	WiFiChart.data.datasets[0].hidden=true;\
	LANChart.update();\
	WANChart.update();\
	WiFiChart.update();\
}});\
$("#received").on("click", function() {\
    if(this.checked) {\
    LANChart.data.datasets[1].hidden=false;\
	WANChart.data.datasets[1].hidden=false;\
	WiFiChart.data.datasets[1].hidden=false;\
	LANChart.update();\
	WANChart.update();\
	WiFiChart.update();\
		} else {\
    LANChart.data.datasets[1].hidden=true;\
	WANChart.data.datasets[1].hidden=true;\
	WiFiChart.data.datasets[1].hidden=true;\
	LANChart.update();\
	WANChart.update();\
	WiFiChart.update();\
}});\
function formatBytes(bytes,decimals) {\
   if(bytes == 0) return "0 Bytes";\
	var k = 1024,\
    dm = decimals || 2,\
    sizes = ["Bytes", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"],\
    i = Math.floor(Math.log(bytes) / Math.log(k));\
   return (bytes / Math.pow(k, i)) > 0 ? parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + ( i > -1 ? sizes[i] : "bits") : null;\
};\
$(".traffic_data").each(function() {\
	$(this).text(formatBytes($(this).text(),2));\
});\
var TrafficChartOption = {\
		maintainAspectRatio: false,\
        legend: {display: false},\
        scales: {\
		yAxes: [{ticks: {\
				callback: function(value) { \
					return formatBytes(value,2)},\
				beginAtZero: true}}]},\
		tooltips: {\
                enabled: true,\
                mode: "single",\
                callbacks: {\
                    label: function(tooltipItems, data) { \
                        return formatBytes(tooltipItems.yLabel , 2);},\
					title: function(tooltipItems, data) {\
						return;}}},\
		spanGaps:true,\
		legend: {display: false},};\
var wan_ctx = document.getElementById("WANChart").getContext("2d");\
var WANChart = new Chart(wan_ctx, {\
    type: "line",\
    data: {labels: ['); ngx.print(traffic.wan.tx.time); ngx.print('],\
	"datasets":[{"data":['); ngx.print(traffic.wan.tx.data); ngx.print('],\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		},\
		{"data":['); ngx.print(traffic.wan.rx.data); ngx.print('],\
			"pointBackgroundColor": "#f58368",\
			"backgroundColor": "#f5836850",\
    }]},\
    options: TrafficChartOption \
});\
var lan_ctx = document.getElementById("LANChart").getContext("2d");\
var LANChart = new Chart(lan_ctx, {\
    type: "line",\
    data: {labels: ['); ngx.print(traffic.lan.tx.time); ngx.print('],\
		"datasets":[{"data":['); ngx.print(traffic.lan.tx.data); ngx.print('],\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		},\
		{"data":['); ngx.print(traffic.lan.rx.data); ngx.print('],\
			"pointBackgroundColor": "#f58368",\
			"backgroundColor": "#f5836850",\
    }]},\
    options: TrafficChartOption, \
});\
var wifi_ctx = document.getElementById("WiFiChart").getContext("2d");\
var WiFiChart = new Chart(wifi_ctx, {\
    type: "line",\
    data: {labels: ['); ngx.print(traffic.wifi.tx.time); ngx.print('],\
		"datasets":[{"data":['); ngx.print(traffic.wifi.tx.data); ngx.print('],\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		},\
		{"data":['); ngx.print(traffic.wifi.rx.data); ngx.print('],\
			"	pointBackgroundColor": "#f58368",\
				"backgroundColor": "#f5836850",\
		}]},\
    options: TrafficChartOption, \
});\
</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 
