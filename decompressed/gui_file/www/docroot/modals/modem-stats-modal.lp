--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")								  
local ui_helper = require("web.ui_helper")
local format, concat = string.format, table.concat

local function getStatsData(dtype)
    local nline = 1
	local total
	local dataline
    local data = {}
	local datatime = {}
    local filename = format("/tmp/trafficmon/stats_%s", dtype)
    f = io.open(filename, "r")
    if f then
        for line in f:lines() do
            if (nline < 2 ) then
                nline = nline + 1 --skip first line
				total = line
            elseif (nline == 2) then
				if dtype:match("mem") then
					dataline = tonumber(total)-tonumber((line:match(".*%s"):gsub("%s+", ""))) or "NaN"
				else
					dataline = line:match(".*%s"):gsub("%s+", "") or "NaN"
				end
				nline = nline +1
				data[#data+1] = dataline
				datatime[#datatime+1] = '"'
				datatime[#datatime+1] = line:match("%s.*"):gsub("%s+","") or "NaN"
				datatime[#datatime+1] = '"'
            else
				if dtype:match("mem") then
					dataline = tonumber(total)-tonumber((line:match(".*%s"):gsub("%s+", ""))) or "NaN"
				else
					dataline = line:match(".*%s"):gsub("%s+", "") or "NaN"
				end
				data[#data+1] = ","
				data[#data+1] = dataline
				datatime[#datatime+1] = ","
				datatime[#datatime+1] = '"'
				datatime[#datatime+1] = line:match("%s.*"):gsub("%s+","") or "NaN"
				datatime[#datatime+1] = '"'
            end
        end
        f:close()
    end
	
	local ret = {
		total = total,
		data = concat(data),
		time = concat(datatime),
	}
	
    return ret
end

proxy.set("rpc.system.lock.datadir", "/tmp/trafficmon/")
proxy.apply()

local stats = {
	cpu = getStatsData("cpu"),
	ram = getStatsData("mem"),
}

proxy.set("rpc.system.lock.free", "0")
proxy.apply()

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
	  html[#html+1] = "<fieldset><legend>" .. T"Mem Used Graph" .. "</legend>"
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
var cpu_ctx = document.getElementById("CPUGraph").getContext("2d");\
var CPUGraph = new Chart(cpu_ctx, {\
    type: "line",\
    data: {labels: ['); ngx.print(stats.cpu.time); ngx.print('],\
	"datasets":[{"data":['); ngx.print(stats.cpu.data); ngx.print('],\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		}]},\
    options: {\
		maintainAspectRatio: false,\
        legend: {display: false},\
        scales: {\
		yAxes: [{ticks: {\
				callback: function(value) { \
					if (value %1 == 0 ) \
						return value+"%"}, \
				min: 0, \
				max:'); ngx.print(stats.cpu.total); ngx.print(',\
				stepSize: 20,}}]},\
		tooltips: {\
                enabled: true,\
                mode: "single",\
                callbacks: {\
                    label: function(tooltipItems, data) { \
                        return tooltipItems.yLabel+"%";},\
					title: function(tooltipItems, data) {\
						return;}}},\
		spanGaps:true,\
		legend: {display: false},} \
});\
var ram_ctx = document.getElementById("RAMGraph").getContext("2d");\
var RAMGraph = new Chart(ram_ctx, {\
    type: "line",\
    data: {labels: ['); ngx.print(stats.ram.time); ngx.print('],\
	"datasets":[{"data":['); ngx.print(stats.ram.data); ngx.print('],\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		}]},\
    options: {\
		maintainAspectRatio: false,\
        legend: {display: false},\
        scales: {\
		yAxes: [{ticks: {\
				callback: function(value) { \
					return formatBytes(value,2) \
				},\
				min: 0,\
				max:'); ngx.print(stats.ram.total); ngx.print('}}]},\
		tooltips: {\
                enabled: true,\
                mode: "single",\
                callbacks: {\
                    label: function(tooltipItems, data) { \
                        return formatBytes(tooltipItems.yLabel , 2);},\
					title: function(tooltipItems, data) {\
						return;}}},\
		spanGaps:true,\
		legend: {display: false},} \
});\
	</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 
