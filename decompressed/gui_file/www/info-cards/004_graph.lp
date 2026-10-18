--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local netrate = require("netrate")

local  format = string.format

local interface = proxy.get("rpc.network.interface.@wan.ifname")
local wan_result = proxy.get("rpc.network.interface.@wan.up")
local wan = wan_result and wan_result[1] and wan_result[1].value

local graph_interface = interface and interface[1] and interface[1].value or "br-lan"

if graph_interface:match("wan") then
	local real_interface = proxy.get(format("uci.network.device.@%s.ifname",graph_interface))
	if real_interface and real_interface[1] then
		graph_interface = real_interface[1].value or "br-lan"
	end
end

local sample = wan == "1" and netrate.sample(graph_interface)
if sample then
    local rx_traffic = format("%.0f", sample.rx)
    local tx_traffic = format("%.0f", sample.tx)

  ngx.print('\
\
<div class="infocard" id="graphtab">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"WAN Traffic", nil, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf1fe;">\
	<div class="divtable">\
	<form class="form-horizontal">\
	<fieldset>');
	
	local html = {}
	html[#html + 1] = '<div id="canvas_container" style="height:400px;margin-right:20px;"><canvas id="InfoWANChart"></canvas>'
	html[#html + 1] = '<div style="float:right;">' .. T"Polling every 10 seconds" .. '</div>'
	html[#html + 1] = '</div>'
	html[#html + 1] = '<div id="rx_traffic_complete" class="hide" data-bind="text: rx_traffic_complete">' .. rx_traffic .. '</div>'
	html[#html + 1] = '<div id="tx_traffic_complete" class="hide" data-bind="text: tx_traffic_complete">' .. tx_traffic .. '</div>'
	html[#html + 1] = '<div id="traffic_sample_time" class="hide" data-bind="text: traffic_sample_time">' .. sample.time .. '</div>'

	ngx.print(html)
ngx.print('\
	  </fieldset>\
	  </form>\
	  </div>\
    </div>\
  </div>\
</div>\
<script>\
function checkGraphWidth() {\
	if ( $(document).width() > 855 ) {\
	$("#canvas_container").width($(document).width()/2-60);\
} else {\
	$("#canvas_container").width($(document).width()-80);}\
}\
checkGraphWidth();\
$(window).bind("resize", checkGraphWidth );\
function formatBit(bit,decimals) {\
   if(bit == 0) return "0 bit";\
	var k = 1000,\
    dm = decimals || 2,\
    sizes = ["bits","Kb", "Mb", "Gb", "Tb", "Pb", "Eb", "Zb", "Yb"],\
    i = Math.floor(Math.log(bit) / Math.log(k));\
   return (bit / Math.pow(k, i)) > 0 ? parseFloat((bit / Math.pow(k, i)).toFixed(dm)) + " " + ( i > -1 ? sizes[i] : "bits") : null;\
}\
var TrafficChartOption = {\
		responsive:true,\
		maintainAspectRatio: false,\
        legend: {display: false},\
        scales: {\
		xAxes: [{\
                display: false\
            }],\
		yAxes: [{ticks: {\
				min: 0,\
				callback: function(value) { \
					return formatBit(value,2) \
				},}}],},\
		tooltips: {\
                enabled: true,\
                mode: "single",\
                callbacks: {\
                    label: function(tooltipItems, data) { \
                        return formatBit(tooltipItems.yLabel, 2);},\
					title: function(tooltipItems, data) {\
						return;}}},\
		spanGaps:true,\
		legend: {display: false},};\
var wan_ctx = document.getElementById("InfoWANChart").getContext("2d");\
var wanRxdatasets = [];\
var wanTxdatasets = [];\
var timelabel = [];\
var InfoWANChart = new Chart(wan_ctx, {\
    type: "line",\
    data: {labels: timelabel,\
	"datasets":[{"data":wanRxdatasets,\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		},\
		{"data":wanTxdatasets,\
			"pointBackgroundColor": "#f58368",\
			"backgroundColor": "#f5836850",\
    }]},\
    options: TrafficChartOption \
});\
var graphRequestPending = false;\
var InfoGraphCardRefresh = function(ElementBinding) {\
        if (document.hidden || graphRequestPending) return;\
		var tx_traffic_complete = document.getElementById("tx_traffic_complete");\
		var rx_traffic_complete = document.getElementById("rx_traffic_complete");\
		var traffic_sample_time = document.getElementById("traffic_sample_time");\
		if (tx_traffic_complete && rx_traffic_complete && traffic_sample_time) {\
			var tx_traffic_old = tx_traffic_complete.textContent;\
			var rx_traffic_old = rx_traffic_complete.textContent;\
			var interface = "'); ngx.print(graph_interface); ngx.print('";\
			graphRequestPending = true;\
			$.ajax({url: "/ajax/traffic_graph.lua?interface=" + encodeURIComponent(interface) + \
				"&oldrx=" + rx_traffic_old + "&oldtx=" + tx_traffic_old + "&oldtime=" + traffic_sample_time.textContent + "&auto_update=true" ,\
				type: "POST", data: [tch.elementCSRFtoken()], dataType: "json", timeout: 8000,\
                success: function(data) {\
					if (document.getElementById("traffic_sample_time") !== traffic_sample_time) return;\
					if (!data || data.valid !== true) return;\
					ElementBinding.rx_traffic_complete(data.rx_traffic);\
					ElementBinding.tx_traffic_complete(data.tx_traffic);\
					ElementBinding.traffic_sample_time(data.sample_time);\
					if (typeof data.rx_bytes_per_second !== "number" || typeof data.tx_bytes_per_second !== "number" ||\
						!isFinite(data.rx_bytes_per_second) || !isFinite(data.tx_bytes_per_second)) return;\
					var date = new Date();\
					timelabel.push(date.getHours()+":"+date.getMinutes()+":"+date.getSeconds());\
					wanRxdatasets.push((data.rx_bytes_per_second*8).toFixed(0));\
					wanTxdatasets.push((data.tx_bytes_per_second*8).toFixed(0));\
					if (wanTxdatasets.length > 60) {\
						wanTxdatasets.shift();\
						wanRxdatasets.shift();\
						timelabel.shift();\
					}\
					InfoWANChart.update();\
			}}).always(function() {\
                    if (document.getElementById("traffic_sample_time") === traffic_sample_time) graphRequestPending = false;\
                });\
		};\
	};\
$(document).ready(function () {\
  new modgui.createAjaxUpdateCard("graphtab",null,"InfoGraphCardInterval",10000,InfoGraphCardRefresh);\
})\
</script>\
'); 

end
