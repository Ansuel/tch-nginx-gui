--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")

local  format = string.format

local interface = proxy.get("rpc.network.interface.@wan.ifname")
local wan = proxy.get("rpc.network.interface.@wan.up") and proxy.get("rpc.network.interface.@wan.up")[1].value or nil

local graph_interface = interface and interface[1].value or "br-lan"

if graph_interface:match("wan") then
	local real_interface = proxy.get(format("uci.network.device.@%s.ifname",graph_interface))
	if real_interface then
		graph_interface = real_interface[1].value or "br-lan"
	end
end

if interface and ( wan == "1" ) then
	local int_rx = format("/sys/class/net/%s/statistics/rx_bytes",graph_interface)
	local int_tx = format("/sys/class/net/%s/statistics/tx_bytes",graph_interface)
	
	local file = io.open(int_rx,"r")
	local rx_traffic = file:read()
	file:close()
	file = io.open(int_tx,"r")
	local tx_traffic = file:read()
	file:close()

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
	html[#html + 1] = '<div id="canvas_container" style="height:400px;margin-right:20px;"><canvas id="WANChart"></canvas>'
	html[#html + 1] = '<div style="float:right;">' .. T"Polling every 10 seconds" .. '</div>'
	html[#html + 1] = '</div>'
	html[#html + 1] = '<div id="rx_traffic_complete" class="hide" data-bind="text: rx_traffic_complete">' .. rx_traffic .. '</div>'
	html[#html + 1] = '<div id="tx_traffic_complete" class="hide" data-bind="text: tx_traffic_complete">' .. tx_traffic .. '</div>'

	ngx.print(html)
ngx.print('\
	  </fieldset>\
	  </form>\
	  </div>\
    </div>\
  </div>\
</div>\
<script>\
var interval = 10000;\
function checkGraphWidth() {\
	if ( $(document).width() > 855 )\
	$("#canvas_container").width($(document).width()/2-60);\
else\
	$("#canvas_container").width($(document).width()-80);\
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
var wan_ctx = document.getElementById("WANChart").getContext("2d");\
var wanRxdatasets = [];\
var wanTxdatasets = [];\
var timelabel = [];\
var WANChart = new Chart(wan_ctx, {\
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
var InfoGraphCardInterval;\
$(document).ready(function () {\
\
	var element = document.getElementById("graphtab");\
	if (!element) return ;\
\
	var InfoGraphCardBinding = { \
		rx_traffic_complete: ko.observable(),\
		tx_traffic_complete: ko.observable(),\
	};\
	function InfoGraphCardRefresh() {\
		var tx_traffic_complete = document.getElementById("tx_traffic_complete");\
		var rx_traffic_complete = document.getElementById("rx_traffic_complete");\
		if (tx_traffic_complete) {\
			var tx_traffic_old = tx_traffic_complete.textContent;\
			var rx_traffic_old = rx_traffic_complete.textContent;\
			var interface = "'); ngx.print(graph_interface); ngx.print('";\
			$.post("/ajax/traffic_graph.lua?interface=" + interface + \
				"&oldrx=" + rx_traffic_old + "&oldtx=" + tx_traffic_old +"&auto_update=true" ,\
				[tch.elementCSRFtoken()], function(data) {\
					var rx_traffic = data.rx_traffic-data.old_rx_traffic;\
					var tx_traffic = data.tx_traffic-data.old_tx_traffic;\
					InfoGraphCardBinding.rx_traffic_complete(data.rx_traffic);\
					InfoGraphCardBinding.tx_traffic_complete(data.tx_traffic);\
					var date = new Date();\
					var old_time = Date.parse("01 Jan 1970 "+Array.from(timelabel).pop()+" GMT");\
					timelabel.push(date.getHours()+":"+date.getMinutes()+":"+date.getSeconds());\
					var time = Date.parse("01 Jan 1970 "+Array.from(timelabel).pop()+" GMT");\
					var time_diff = (time-old_time > 0) ? ((time-old_time)/1000) : 1;\
					wanRxdatasets.push(((rx_traffic*8)/time_diff).toFixed(0));\
					wanTxdatasets.push(((tx_traffic*8)/time_diff).toFixed(0));\
					if (wanTxdatasets.length > 60) {\
						wanTxdatasets.shift();\
						wanRxdatasets.shift();\
						timelabel.shift();\
					}\
					WANChart.update();\
			}, "json");\
		};\
	};\
\
	InfoGraphCardRefresh();\
\
	if (!ko.dataFor(element))\
		ko.applyBindings(InfoGraphCardBinding, element);\
	InfoGraphCardInterval = setInterval(InfoGraphCardRefresh, interval);\
	KoRequest.push(InfoGraphCardInterval);\
})\
</script>\
'); 

end
