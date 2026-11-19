--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")

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
	html[#html + 1] = '<span id="traffic_interface"></span>'
	html[#html + 1] = '<span id="traffic_unavailable" class="hide">' .. T"Unavailable" .. '</span>'
	html[#html + 1] = '<div style="float:right;">' .. T"Polling every 10 seconds" .. '</div>'
	html[#html + 1] = '</div>'

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
var trafficSample = {};\
var InfoGraphCardRefresh = function() {\
    var label = document.getElementById("traffic_interface");\
    if (!label) return;\
    var query = "&interface=" + encodeURIComponent(trafficSample.interface || "") +\
        "&oldrx=" + (trafficSample.rx_traffic || "") + "&oldtx=" + (trafficSample.tx_traffic || "") +\
        "&oldtime=" + (trafficSample.sample_time || "");\
    return $.ajax({\
        url: "/ajax/traffic_graph.lua?source=wan&auto_update=true" + query,\
        type: "POST", data: [tch.elementCSRFtoken()], dataType: "json", timeout: 8000,\
        success: function(data) {\
            if (document.getElementById("traffic_interface") !== label || !data) return;\
            var device = data.valid === true ? data.interface : undefined;\
            label.textContent = device || "";\
            $("#traffic_unavailable").toggleClass("hide", !!device);\
            if (device !== trafficSample.interface) {\
                wanRxdatasets.length = wanTxdatasets.length = timelabel.length = 0;\
                InfoWANChart.update();\
            }\
            trafficSample = device ? data : {};\
            if (!device || typeof data.rx_bytes_per_second !== "number" || typeof data.tx_bytes_per_second !== "number" ||\
                !isFinite(data.rx_bytes_per_second) || !isFinite(data.tx_bytes_per_second)) return;\
            var date = new Date();\
            timelabel.push(date.getHours() + ":" + date.getMinutes() + ":" + date.getSeconds());\
            wanRxdatasets.push((data.rx_bytes_per_second * 8).toFixed(0));\
            wanTxdatasets.push((data.tx_bytes_per_second * 8).toFixed(0));\
            if (wanTxdatasets.length > 60) {\
                wanTxdatasets.shift();\
                wanRxdatasets.shift();\
                timelabel.shift();\
            }\
            InfoWANChart.update();\
        }\
    });\
};\
$(document).ready(function () {\
  new modgui.createAjaxUpdateCard("graphtab",null,"InfoGraphCardInterval",10000,InfoGraphCardRefresh);\
})\
</script>\
'); 
