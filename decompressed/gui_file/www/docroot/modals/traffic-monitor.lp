--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")								  
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local string, ngx, os = string, ngx, os
local tonumber = tonumber
local format, match = string.format, string.match
local traffic_data_file = "/var/state/traffic_data_file"

local quantenna_wifi = proxy.get("uci.env.var.qtn_eth_mac")
quantenna_wifi = ((quantenna_wifi and quantenna_wifi[1].value~="") and true or false)
local getargs = ngx.req.get_uri_args()
local getiface = getargs.iface

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
local ipaddr = proxy.get("rpc.network.interface.@wwan.ipaddr")[1].value
if ipaddr:len() ~= 0 then
  wan_intf = "wwan"
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


local wantx = b2m(s2n(content_wan.tx_bytes))
local wanrx = b2m(s2n(content_wan.rx_bytes))
local lantx = b2m(s2n(content_lan.tx_bytes))
local lanrx = b2m(s2n(content_lan.rx_bytes))

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
		wifitx = wifitx + ( s2n(content_wifi.tx_bytes) or 0 )
		wifirx = wifirx + ( s2n(content_wifi.rx_bytes) or 0 )
	end 
end
wifitx = b2m(wifitx)
wifirx = b2m(wifirx)

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
  wanrx = wanrx+content_result[1]*4096
  wantx = wantx+content_result[3]*4096
  lanrx = lanrx+content_result[5]*4096
  lantx = lantx+content_result[7]*4096
  wifirx = wifirx+content_result[9]*4096
  wifitx = wifitx+content_result[11]*4096
end

local dst = os.date("*t", os.time()).isdst or false

local wantotal = format("%.3f", wantx + wanrx)
local lantotal = format("%.3f", lantx + lanrx)
local wifitotal = format("%.3f", wifitx + wifirx)

local function getTrafficData(dtype, name)
    local nline = 1
    local data = {}
	local datatime = {}
    filename = string.format("/tmp/trafficmon/%s_%s", name, dtype)
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
    return table.concat(data) , table.concat(datatime) 
end

local wanTx, wanRx, lanTx, lanRx, wifiTx, wifiRx
proxy.set("rpc.system.lock.datadir", "/tmp/trafficmon/")
proxy.apply()

local interface = proxy.get("rpc.network.interface.@wan.ifname")
local wan = proxy.get("rpc.network.interface.@wan.up") and proxy.get("rpc.network.interface.@wan.up")[1].value or nil

local graph_interface = interface and interface[1].value or "br-lan"

if graph_interface:match("wan") then
	local real_interface = proxy.get(format("uci.network.device.@%s.ifname",graph_interface))
	if real_interface then
		graph_interface = real_interface[1].value or "br-lan"
	end
end

_, wanTx, wanTxTime = pcall(getTrafficData, "tx_bytes", graph_interface)
_, wanRx, wanRxTime = pcall(getTrafficData, "rx_bytes", graph_interface)
_, lanTx, lanTxTime = pcall(getTrafficData, "tx_bytes", "br-lan")
_, lanRx, lanTxTime = pcall(getTrafficData, "rx_bytes", "br-lan")
_, wifiTx, wifiTxTime = pcall(getTrafficData, "tx_bytes", curiface)
_, wifiRx, wifiRxTime = pcall(getTrafficData, "rx_bytes", curiface)
proxy.set("rpc.system.lock.free", "0")
proxy.apply()

ngx.print(ui_helper.createHeader(T"Traffic Monitor", false, true) ); ngx.print('\
<div class="modal-body update no-save">\
');
if ngx.ctx.session:hasAccess("/modals/hostmap-modal.lp") then
    local tabs = {
        {
            desc = T"Devices List",
            target = "modals/device-modal.lp",
        },
        {
            desc = T"Devices Map",
            target = "modals/hostmap-modal.lp",
        },
		{
            desc = T"WiFi Nurse",
            target = "modals/wifi-nurse-modal.lp",
        },
		{
            desc = T"Traffic Monitor",
			active = "active",
            target = "modals/traffic-monitor.lp",
        },
    }
    ngx.print(ui_helper.createModalTabs(tabs))
end
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/traffic-monitor.lp">\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      local html = {}
	  local attributes = {
			label = { class = "control-label" } ,
			span = { class = "span1 text-right" } ,
			}
	  local info_box = {
          alert = {
		  	class = "alert alert-info",
		  }
        }
	  html[#html+1] = '<div class="span3">'
	  html[#html+1] = "<fieldset><legend>" .. T"Internet Traffic" .. "</legend>"
	  html[#html+1] = ui_helper.createLabel(T"Total Mixed (in MB)", wantotal , attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Send (in MB)", wantx, attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Receive (in MB)", wanrx, attributes)
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "</div>"
	  html[#html+1] = '<div class="span3">'
	  html[#html+1] = "<fieldset><legend>" .. T"Ethernet Network Traffic" .. "</legend>"
	  html[#html+1] = ui_helper.createLabel(T"Total Mixed (in MB)", lantotal , attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Send (in MB)", lantx, attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Receive (in MB)", lanrx, attributes)
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "</div>"
	  html[#html+1] = '<div>'
	  html[#html+1] = "<fieldset><legend>" .. T"Wi-Fi Network Traffic" .. "</legend>"
	  html[#html+1] = ui_helper.createLabel(T"Total Mixed (in MB)",  wifitotal , attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Send (in MB)", wifitx, attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Receive (in MB)", wifirx, attributes)
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "</div>"
	  html[#html+1] = '<div>'
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
	  html[#html+1] = "<fieldset><legend>" .. T"WAN Graph" .. "</legend>"
	  html[#html+1] = '<div style="height:400px"><canvas id="WANChart"></canvas></div>'
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "<fieldset><legend>" .. T"LAN Graph" .. "</legend>"
	  html[#html+1] = '<div style="height:400px"><canvas id="LANChart"></canvas></div>'
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "&nbsp"
	  html[#html+1] = "<fieldset>"
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
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "</div>"
	  ngx.print(html)
	  
	  ngx.print('\
  </form>\
 </div>\
\
	<script language ="javascript">\
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
    sizes = ["Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"],\
    i = Math.floor(Math.log(bytes) / Math.log(k));\
   return (bytes / Math.pow(k, i)) > 0 ? parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i] : "0";\
}\
var TrafficChartOption = {\
		maintainAspectRatio: false,\
        legend: {display: false},\
        scales: {\
		yAxes: [{ticks: {\
				callback: function(value) { \
					return formatBytes(value,2) \
				},}}]},\
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
    data: {labels: ['); ngx.print(wanTxTime); ngx.print('],\
	"datasets":[{"data":['); ngx.print(wanTx); ngx.print('],\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		},\
		{"data":['); ngx.print(wanRx); ngx.print('],\
			"pointBackgroundColor": "#f58368",\
			"backgroundColor": "#f5836850",\
    }]},\
    options: TrafficChartOption \
});\
var lan_ctx = document.getElementById("LANChart").getContext("2d");\
var LANChart = new Chart(lan_ctx, {\
    type: "line",\
    data: {labels: ['); ngx.print(lanTxTime); ngx.print('],\
		"datasets":[{"data":['); ngx.print(lanTx); ngx.print('],\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		},\
		{"data":['); ngx.print(lanRx); ngx.print('],\
			"pointBackgroundColor": "#f58368",\
			"backgroundColor": "#f5836850",\
    }]},\
    options: TrafficChartOption, \
});\
var wifi_ctx = document.getElementById("WiFiChart").getContext("2d");\
var WiFiChart = new Chart(wifi_ctx, {\
    type: "line",\
    data: {labels: ['); ngx.print(wifiTxTime); ngx.print('],\
		"datasets":[{"data":['); ngx.print(wifiTx); ngx.print('],\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		},\
		{"data":['); ngx.print(wifiRx); ngx.print('],\
			"	pointBackgroundColor": "#f58368",\
				"backgroundColor": "#f5836850",\
		}]},\
    options: TrafficChartOption, \
});\
	</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 
