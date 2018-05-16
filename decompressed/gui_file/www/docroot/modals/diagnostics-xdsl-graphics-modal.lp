--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format

local function xdslctlget(request,bandtype)
  local data=""
  local space={}
  
  if bandtype == "Us" then
    if proxy.get("rpc.xdslctl." .. request .. "Us1") then
    	data = data .. proxy.get("rpc.xdslctl." .. request .. "Us1")[1].value
    end
	
	if proxy.get("rpc.xdslctl." .. request .. "Us2") then
	  Ds1Band = tonumber(proxy.get("rpc.xdslctl.Ds1ScannedBand")[1].value)
	  space={}
	  for i=0,Ds1Band do
	  	space[#space+1] = "NaN,"
	  end
	  data = data .. table.concat(space) .. proxy.get("rpc.xdslctl." .. request .. "Us2")[1].value
    end
	
	if proxy.get("rpc.xdslctl." .. request .. "Us3") then
	  Ds2Band = tonumber(proxy.get("rpc.xdslctl.Ds2ScannedBand")[1].value)
	  space={}
	  for i=0,Ds2Band do
	  	space[#space+1] = "NaN,"
	  end
      data = data .. table.concat(space) .. proxy.get("rpc.xdslctl." .. request .. "Us3")[1].value
    end
	
	 if proxy.get("rpc.xdslctl." .. request .. "Us4") then
    	data = data .. proxy.get("rpc.xdslctl." .. request .. "Us4")[1].value
    end
  else
    if proxy.get("rpc.xdslctl." .. request .. "Ds1") then
	  Us1Band = tonumber(proxy.get("rpc.xdslctl.Us1ScannedBand")[1].value)
	  space={}
	  for i=0,Us1Band do
	  	space[#space+1] = "NaN,"
	  end
    	data = data .. table.concat(space) .. proxy.get("rpc.xdslctl." .. request .. "Ds1")[1].value
    end
    
    if proxy.get("rpc.xdslctl." .. request .. "Ds2") then
	  Us2Band = tonumber(proxy.get("rpc.xdslctl.Us2ScannedBand")[1].value)
	  space={}
	  for i=0,Us2Band do
	  	space[#space+1] = "NaN,"
	  end
    	data = data .. table.concat(space) .. proxy.get("rpc.xdslctl." .. request .. "Ds2")[1].value
    end
    
    if proxy.get("rpc.xdslctl." .. request .. "Ds3") then
	  Us3Band = tonumber(proxy.get("rpc.xdslctl.Us3ScannedBand")[1].value)
	  Us4Band = tonumber(proxy.get("rpc.xdslctl.Us4ScannedBand")[1].value)
	  space={}
	  for i=0,(Us3Band+Us4Band) do
	  	space[#space+1] = "NaN,"
	  end
    	data = data .. table.concat(space) .. proxy.get("rpc.xdslctl." .. request .. "Ds3")[1].value
    end
    
    if proxy.get("rpc.xdslctl." .. request .. "Ds4") then
    	data = data .. proxy.get("rpc.xdslctl." .. request .. "Ds4")[1].value
    end
  end
  
  if data == "" then
  	return "0"
  end
  
  return data
end

local scanband = proxy.get("rpc.xdslctl.HlogScanBand")

if scanband then
	scanband = scanband[1].value
else
	scanband = "0"
end

local profile = proxy.get("sys.class.xdsl.@line0.ProfileName")

local _, HlogUs = pcall(xdslctlget, "Hlog","Us")
local _, BitsUs = pcall(xdslctlget, "Bits","Us")
local _, QLNUs = pcall(xdslctlget, "QLN","Us")
local _, SNRUs = pcall(xdslctlget, "SNR","Us")
local _, HlogDs = pcall(xdslctlget, "Hlog","Ds")
local _, BitsDs = pcall(xdslctlget, "Bits","Ds")
local _, QLNDs = pcall(xdslctlget, "QLN","Ds")
local _, SNRDs = pcall(xdslctlget, "SNR","Ds")

local UsBandNumber = proxy.get("rpc.xdslctl.UsBandNumber")

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Diagnostics DSL", false, true))   ngx.print('\
\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-diagnostics.lp")
  ngx.print('\
\
    ');  
        -- dummy form so that refresh button knows which page to reload, keep it
      ngx.print('\
    <form class="form-horizontal" method="post" action="modals/diagnostics-xdsl-graphics-modal.lp">\
    </form>\
\
	<fieldset>\
      <legend>');  ngx.print( T"DSL Hlog" ); ngx.print('</legend>\
		<div style="overflow-x:auto;max-width:1130px;">')
		  	ngx.print('<div style="height: 400px;width:1130px;">')
		  ngx.print('\
		    <canvas id="HlogChart"></canvas>\
		  </div>\
		</div>\
    </fieldset>\
	<fieldset>\
      <legend>');  ngx.print( T"DSL QLN" ); ngx.print('</legend>\
	    <div style="overflow-x:auto;max-width:1130px;">')
		  	ngx.print('<div style="height: 400px;width:1130px;">')
		  ngx.print('\
		    <canvas id="QLNChart"></canvas>\
		  </div>\
		</div>\
    </fieldset>\
	<fieldset>\
      <legend>');  ngx.print( T"DSL SNR" ); ngx.print('</legend>\
	    <div style="overflow-x:auto;max-width:1130px;">')
		  	ngx.print('<div style="height: 400px;width:1130px;">')
		  ngx.print('\
		    <canvas id="SNRChart"></canvas>\
		  </div>\
		</div>\
    </fieldset>\
	<fieldset>\
      <legend>');  ngx.print( T"DSL Bits" ); ngx.print('</legend>\
		<div style="overflow-x:auto;max-width:1130px;">')
		  	ngx.print('<div style="height: 400px;width:1130px;">')
		  ngx.print('\
		    <canvas id="BitsChart"></canvas>\
		  </div>\
		</div>\
    </fieldset>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
var labelLegend = [ 0 ];\
var hlog_ctx = document.getElementById("HlogChart").getContext("2d");\
	var HlogChart = new Chart(hlog_ctx, {\
    type: "line",\
    data: {labels: labelLegend,\
	"datasets":[{"data":['); ngx.print(HlogUs); ngx.print('],\
	"pointBackgroundColor": "#90cd8a",\
	"lineTension":0.1,\
	"pointBorderWidth":"0.6",\
	"pointRadius":"0.6",\
    },\
	{"data":['); ngx.print(HlogDs); ngx.print('],\
	"pointBackgroundColor": "#f58368",\
	"lineTension":0.1,\
	"pointBorderWidth":"0.6",\
	"pointRadius":"0.6",\
    }]},\
    options: {\
		maintainAspectRatio: false,\
        scales: {\
            yAxes: [{\
                ticks: {\
                    beginAtZero:true,\
                }\
            }]\
        },\
		spanGaps:true,\
		showLines:false,\
		pointStyle:"cross",\
		legend: {display: false},\
		animation: {\
            duration: 0,\
        },\
        hover: {\
            animationDuration: 0,\
        },\
        responsiveAnimationDuration: 0,\
    }\
});\
var qln_ctx = document.getElementById("QLNChart").getContext("2d");\
	var QLNChart = new Chart(qln_ctx, {\
    type: "line",\
    data: {labels: labelLegend,\
	"datasets":[{"data":['); ngx.print(QLNUs); ngx.print('],\
	"pointBackgroundColor": "#90cd8a",\
	"lineTension":0.1,\
	"pointBorderWidth":"0.6",\
	"pointRadius":"0.6",\
    },{"data":['); ngx.print(QLNDs); ngx.print('],\
	"pointBackgroundColor": "#f58368",\
	"lineTension":0.1,\
	"pointBorderWidth":"0.6",\
	"pointRadius":"0.6",\
    }]},\
    options: {\
		maintainAspectRatio: false,\
        scales: {\
            yAxes: [{\
                ticks: {\
                    beginAtZero:false,\
                }\
            }]\
        },\
		spanGaps:true,\
		showLines:false,\
		pointStyle:"cross",\
		legend: {display: false},\
		animation: {\
            duration: 0,\
        },\
        hover: {\
            animationDuration: 0,\
        },\
        responsiveAnimationDuration: 0,\
    }\
});\
var snr_ctx = document.getElementById("SNRChart").getContext("2d");\
	var SNRChart = new Chart(snr_ctx, {\
    type: "line",\
    data: {labels: labelLegend,\
	"datasets":[{"data":['); ngx.print(SNRUs); ngx.print('],\
	"pointBackgroundColor": "#90cd8a",\
	"lineTension":0.1,\
	"pointBorderWidth":"0.6",\
	"pointRadius":"0.6",\
    },\
	{"data":['); ngx.print(SNRDs); ngx.print('],\
	"pointBackgroundColor": "#f58368",\
	"lineTension":0.1,\
	"pointBorderWidth":"0.6",\
	"pointRadius":"0.6",\
    }]},\
    options: {\
		maintainAspectRatio: false,\
        scales: {\
            yAxes: [{\
                ticks: {\
                    beginAtZero:true,\
                }\
            }]\
        },\
		spanGaps:true,\
		showLines:false,\
		pointStyle:"cross",\
		legend: {display: false},\
		animation: {\
            duration: 0,\
        },\
        hover: {\
            animationDuration: 0,\
        },\
        responsiveAnimationDuration: 0,\
    }\
});\
var bits_ctx = document.getElementById("BitsChart").getContext("2d");\
        var BitsChart = new Chart(bits_ctx, {\
    type: "line",\
    data: {labels: labelLegend,\
        "datasets":[{"data":['); ngx.print(BitsUs); ngx.print('],\
        "pointBackgroundColor": "#90cd8a",\
        "backgroundColor": "#90cd8a",\
        "lineTension":0.1,\
        "pointBorderWidth":"0.6",\
        "pointRadius":"0.6",\
        "fill":"start",\
    },\
	{"data":['); ngx.print(BitsDs); ngx.print('],\
        "pointBackgroundColor": "#f58368",\
        "backgroundColor": "#f58368",\
        "lineTension":0.1,\
        "pointBorderWidth":"0.1",\
        "pointRadius":"0.1",\
        "fill":"start",\
    }]},\
    options: {\
                maintainAspectRatio: false,\
        scales: {\
            yAxes: [{\
                ticks: {\
                    beginAtZero:true,\
                }\
            }]\
        },\
                spanGaps:false,\
                showLines:true,\
                pointStyle:"cross",\
                legend: {display: false},\
                animation: {\
            duration: 0,\
        },\
        hover: {\
            animationDuration: 0,\
        },\
        responsiveAnimationDuration: 0,\
    }\
});\
var scanband = '); ngx.print(tonumber(scanband)+1); ngx.print('\
setTimeout(function(){\
	for (i = 1; i < scanband; i++) { \
		labelLegend.push(i);\
	};\
	HlogChart.update();\
	QLNChart.update();\
	SNRChart.update();\
	BitsChart.update();\
}, 250);\
</script>\
'); 