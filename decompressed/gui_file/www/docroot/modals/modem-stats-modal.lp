--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local history = require("traffic_history")
local now = ngx.time()
local cpu, cpu_times, cpu_total = history.read("stats_cpu", now)
local ram, ram_times, ram_total = history.read("stats_mem", now)
local cpu_labels, cpu_data = history.chart(cpu_times, cpu)
local ram_labels, ram_data = "", ""
if ram_total and ram_total > 0 then
    ram_labels, ram_data = history.chart(ram_times, ram, ram_total)
end

ngx.print(ui_helper.createHeader(T"Modem Stats Graph", false, true) ); ngx.print('\
<div class="modal-body update no-save">\
');
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-management.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/modem-stats-modal.lp">\
    ');  
      local html = {}
	  html[#html+1] = "<fieldset><legend>" .. T"CPU Usage Graph" .. "</legend>"
	  html[#html+1] = '<div style="height:400px"><canvas id="CPUGraph"></canvas></div>'
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "<fieldset><legend>" .. T"RAM Used Graph" .. "</legend>"
	  html[#html+1] = '<div style="height:400px"><canvas id="RAMGraph"></canvas></div>'
	  html[#html+1] = "</fieldset>"
	  ngx.print(html)
	  
	  ngx.print('\
  </form>\
 </div>\
\
	<script language ="javascript">\
function formatBytes(bytes,decimals) {\
   if(bytes == 0) return "0 Bytes";\
	var k = 1024,\
    dm = decimals || 2,\
    sizes = ["KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"],\
    i = Math.floor(Math.log(bytes) / Math.log(k));\
   return (bytes / Math.pow(k, i)) > 0 ? parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i] : "0";\
}\
var HistoryTicks = {autoSkip: false, maxRotation: 0, callback: function(value, index, labels) {\
    var last = labels.length - 1;\
    var stride = Math.max(1, Math.ceil(last / 4));\
    return (last - index) % stride === 0 ? value : null;\
}};\
var cpu_ctx = document.getElementById("CPUGraph").getContext("2d");\
var CPUGraph = new Chart(cpu_ctx, {\
    type: "line",\
    data: {labels: ['); ngx.print(cpu_labels); ngx.print('],\
	"datasets":[{"data":['); ngx.print(cpu_data); ngx.print('],\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		}]},\
    options: {\
		maintainAspectRatio: false,\
        legend: {display: false},\
        scales: {\
		xAxes: [{ticks: HistoryTicks}],\
		yAxes: [{ticks: {\
				callback: function(value) { \
					if (value %1 == 0 ) \
						return value+"%"}, \
				min: 0, \
				max:'); ngx.print(cpu_total or 100); ngx.print(',\
				stepSize: 20,}}]},\
		tooltips: {\
                enabled: true,\
                mode: "single",\
                callbacks: {\
                    title: function(items, data) { return items.length ? data.labels[items[0].index] : ""; },\
                    label: function(tooltipItems, data) { \
                        return tooltipItems.yLabel+"%";}}},\
		spanGaps:false,\
		legend: {display: false},} \
});\
var ram_ctx = document.getElementById("RAMGraph").getContext("2d");\
var RAMGraph = new Chart(ram_ctx, {\
    type: "line",\
    data: {labels: ['); ngx.print(ram_labels); ngx.print('],\
	"datasets":[{"data":['); ngx.print(ram_data); ngx.print('],\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		}]},\
    options: {\
		maintainAspectRatio: false,\
        legend: {display: false},\
        scales: {\
		xAxes: [{ticks: HistoryTicks}],\
		yAxes: [{ticks: {\
				callback: function(value) { \
					return formatBytes(value,2) \
				},\
				min: 0,\
				max:'); ngx.print(ram_total or "undefined"); ngx.print('}}]},\
		tooltips: {\
                enabled: true,\
                mode: "single",\
                callbacks: {\
                    title: function(items, data) { return items.length ? data.labels[items[0].index] : ""; },\
                    label: function(tooltipItems, data) { \
                        return formatBytes(tooltipItems.yLabel , 2);}}},\
		spanGaps:false,\
		legend: {display: false},} \
});\
	</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 
