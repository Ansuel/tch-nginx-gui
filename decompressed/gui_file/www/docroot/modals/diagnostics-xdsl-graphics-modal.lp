--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format

local function xdslctlget(dtype,request)
	local scanband = proxy.get("rpc.xdslctl." .. request .. "ScanBand")
	local data = ""
	local label = ""
	if dtype == "value" then
	
		local us1start = tonumber(proxy.get("rpc.xdslctl.Us1BandInitial")[1].value)
		for i=0,us1start-2 do
			data = data .. "NaN" .. ", "
		end
		
		data = data .. proxy.get("rpc.xdslctl." .. request .. "Us1")[1].value
		
		local us1end = tonumber(proxy.get("rpc.xdslctl.Us1BandFinal")[1].value)
		local ds1start = tonumber(proxy.get("rpc.xdslctl.Ds1BandInitial")[1].value)
		for i=0,ds1start-us1end-2 do
			data = data .. "NaN" .. ", "
		end
		
		data = data .. proxy.get("rpc.xdslctl." .. request .. "Ds1")[1].value
		
		local ds1end = tonumber(proxy.get("rpc.xdslctl.Ds1BandFinal")[1].value)
		local us2start = tonumber(proxy.get("rpc.xdslctl.Us2BandInitial")[1].value)
		for i=0,us2start-ds1end-2 do
			data = data .. "NaN" .. ", "
		end
		
		data = data .. proxy.get("rpc.xdslctl." .. request .. "Us2")[1].value
		
		local us2end = tonumber(proxy.get("rpc.xdslctl.Us2BandFinal")[1].value)
		local ds2start = tonumber(proxy.get("rpc.xdslctl.Ds2BandInitial")[1].value)
		for i=0,ds2start-us2end-2 do
			data = data .. "NaN" .. ", "
		end
		
		data = data .. proxy.get("rpc.xdslctl." .. request .. "Ds2")[1].value
		
		local ds2end = tonumber(proxy.get("rpc.xdslctl.Ds2BandFinal")[1].value)
		local us3start = tonumber(proxy.get("rpc.xdslctl.Us3BandInitial")[1].value)
		for i=0,us3start-ds2end-2 do
			data = data .. "NaN" .. ", "
		end
		
		data = data .. proxy.get("rpc.xdslctl." .. request .. "Us3")[1].value
		
		local us3end = tonumber(proxy.get("rpc.xdslctl.Us3BandFinal")[1].value)
		local us4start = tonumber(proxy.get("rpc.xdslctl.Us4BandInitial")[1].value)
		for i=0,us4start-us3end-2 do
			data = data .. "NaN" .. ", "
		end
		
		data = data .. proxy.get("rpc.xdslctl." .. request .. "Us4")[1].value
		
		local us4end = tonumber(proxy.get("rpc.xdslctl.Us4BandFinal")[1].value)
		local ds3start = tonumber(proxy.get("rpc.xdslctl.Ds3BandInitial")[1].value)
		for i=0,ds3start-us4end-2 do
			data = data .. "NaN" .. ", "
		end
		
		data = data .. proxy.get("rpc.xdslctl." .. request .. "Ds3")[1].value
		
		local ds3end = tonumber(proxy.get("rpc.xdslctl.Ds3BandFinal")[1].value)
		local ds4start = tonumber(proxy.get("rpc.xdslctl.Ds4BandInitial")[1].value)
		for i=0,ds4start-ds3end-2 do
			data = data .. "NaN" .. ", "
		end
		
		data = data .. proxy.get("rpc.xdslctl." .. request .. "Ds4")[1].value
		
		return data
	else
		if scanband then
			for n=1,tonumber(scanband[1].value) do
				label = label .. n .. ", "
			end
			return label
		else
			return "0"
		end
	end
end

local Hlog, HlogLegend, Bits, BitsLegend, QLN, QLNLegend, SNR, SNRLegend 

local profile = proxy.get("sys.class.xdsl.@line0.ProfileName")

_, Hlog = pcall(xdslctlget, "value","Hlog")
_, HlogLegend = pcall(xdslctlget, "legend","Hlog")
_, Bits = pcall(xdslctlget, "value","Bits")
_, BitsLegend = pcall(xdslctlget, "legend","Bits")
_, QLN = pcall(xdslctlget, "value","QLN")
_, QLNLegend = pcall(xdslctlget, "legend","QLN")
_, SNR = pcall(xdslctlget, "value","SNR")
_, SNRLegend = pcall(xdslctlget, "legend","SNR")

local UsBandNumber = proxy.get("rpc.xdslctl.UsBandNumber")

local BandPlanCondition

if UsBandNumber then

	local function getUsBandPlan(n,dtype) 
		if dtype == "Initial" then
			local UsInitial = proxy.get(format("rpc.xdslctl.Us%dBandInitial",n))[1].value
			return UsInitial
		else
			local UsFinal = proxy.get(format("rpc.xdslctl.Us%dBandFinal",n))[1].value
			return UsFinal
		end
	end
	
	BandPlanCondition = "( " 
	
	for i=1,tonumber(UsBandNumber[1].value) do
		local UsInitial, UsFinal
		_, UsInitial = pcall(getUsBandPlan,i,"Initial")
		_, UsFinal = pcall(getUsBandPlan,i,"Final")
		if not ( tostring(i) == UsBandNumber[1].value ) then
			BandPlanCondition = BandPlanCondition .. "(" .. tonumber(UsInitial)-2 .. " < i && i < " .. tonumber(UsFinal) .. ") || "
		else
			BandPlanCondition = BandPlanCondition .. "(" .. tonumber(UsInitial)-2 .. " < i && i < " .. tonumber(UsFinal) .. ")"
		end
	end
	
	BandPlanCondition = BandPlanCondition .. " )"
end

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
		  	ngx.print('<div style="height: 400px;width:8500px;">')
		  ngx.print('\
		    <canvas id="BitsChart"></canvas>\
		  </div>\
		</div>\
    </fieldset>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
var hlog_ctx = document.getElementById("HlogChart").getContext("2d");\
	var pointBackgroundColor = [];\
	var HlogChart = new Chart(hlog_ctx, {\
    type: "line",\
    data: {labels:['); ngx.print(HlogLegend); ngx.print('],\
	"datasets":[{"data":['); ngx.print(Hlog); ngx.print('],\
	"pointBackgroundColor": pointBackgroundColor,\
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
    for (i = 0; i < HlogChart.data.datasets[0].data.length; i++) {\
    if '); ngx.print(BandPlanCondition); ngx.print('  {\
        pointBackgroundColor.push("#90cd8a");\
    } else {\
        pointBackgroundColor.push("#f58368");\
    }\
}\
HlogChart.update();\
var qln_ctx = document.getElementById("QLNChart").getContext("2d");\
	var pointBackgroundColor = [];\
	var QLNChart = new Chart(qln_ctx, {\
    type: "line",\
    data: {labels:['); ngx.print(QLNLegend); ngx.print('],\
	"datasets":[{"data":['); ngx.print(QLN); ngx.print('],\
	"pointBackgroundColor": pointBackgroundColor,\
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
    for (i = 0; i < QLNChart.data.datasets[0].data.length; i++) {\
    if '); ngx.print(BandPlanCondition); ngx.print('  {\
        pointBackgroundColor.push("#90cd8a");\
    } else {\
        pointBackgroundColor.push("#f58368");\
    }\
}\
QLNChart.update();\
var snr_ctx = document.getElementById("SNRChart").getContext("2d");\
	var pointBackgroundColor = [];\
	var SNRChart = new Chart(snr_ctx, {\
    type: "line",\
    data: {labels:['); ngx.print(SNRLegend); ngx.print('],\
	"datasets":[{"data":['); ngx.print(SNR); ngx.print('],\
	"pointBackgroundColor": pointBackgroundColor,\
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
    for (i = 0; i < SNRChart.data.datasets[0].data.length; i++) {\
    if '); ngx.print(BandPlanCondition); ngx.print('  {\
        pointBackgroundColor.push("#90cd8a");\
    } else {\
        pointBackgroundColor.push("#f58368");\
    }\
}\
SNRChart.update();\
var bits_ctx = document.getElementById("BitsChart").getContext("2d");\
	var backgroundColor = [];\
	var BitsChart = new Chart(bits_ctx, {\
    type: "bar",\
    data: {labels:['); ngx.print(BitsLegend); ngx.print('],\
	"datasets":[{"data":['); ngx.print(Bits); ngx.print('],\
	"backgroundColor": backgroundColor,\
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
    for (i = 0; i < BitsChart.data.datasets[0].data.length; i++) {\
    if '); ngx.print(BandPlanCondition); ngx.print('  {\
        backgroundColor.push("#90cd8a");\
    } else {\
        backgroundColor.push("#f58368");\
    }\
}\
BitsChart.update();\
</script>\
'); 