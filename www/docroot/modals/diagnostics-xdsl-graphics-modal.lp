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
		file = io.open("/tmp/".. request .. "Param","r")
		if file then
			for l in file:lines() do
				data = data .. l
			end
			io.close()
			return data
		else
			return "0"
		end
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