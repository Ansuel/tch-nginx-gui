--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format

local SpaceBand = {
	band1 = "",
	band2 = "",
	band3 = "",
	band4 = "",
	band5 = "",
	band6 = "",
	band7 = "",
	band8 = "",
}

for index=1,8 do
	if index==1 then
		local us1start = tonumber(proxy.get("rpc.xdslctl.Us1BandInitial")[1].value)
		for i=0,us1start-2 do
			SpaceBand["band1"] = SpaceBand["band1"] .. "NaN" .. ", "
		end
	elseif index==2 then
		local us1end = tonumber(proxy.get("rpc.xdslctl.Us1BandFinal")[1].value)
		local ds1start = tonumber(proxy.get("rpc.xdslctl.Ds1BandInitial")[1].value)
		for i=0,ds1start-us1end-2 do
			SpaceBand["band2"] = SpaceBand["band2"] .. "NaN" .. ", "
		end
	elseif index==3 then
		local ds1end = tonumber(proxy.get("rpc.xdslctl.Ds1BandFinal")[1].value)
		local us2start = tonumber(proxy.get("rpc.xdslctl.Us2BandInitial")[1].value)
		for i=0,us2start-ds1end-2 do
			SpaceBand["band3"] = SpaceBand["band3"] .. "NaN" .. ", "
		end
	elseif index==4 then
		local us2end = tonumber(proxy.get("rpc.xdslctl.Us2BandFinal")[1].value)
		local ds2start = tonumber(proxy.get("rpc.xdslctl.Ds2BandInitial")[1].value)
		for i=0,ds2start-us2end-2 do
			SpaceBand["band4"] = SpaceBand["band4"] .. "NaN" .. ", "
		end
	elseif index==5 then
		local ds2end = tonumber(proxy.get("rpc.xdslctl.Ds2BandFinal")[1].value)
		local us3start = tonumber(proxy.get("rpc.xdslctl.Us3BandInitial")[1].value)
		for i=0,us3start-ds2end-2 do
			SpaceBand["band5"] = SpaceBand["band5"] .. "NaN" .. ", "
		end
	elseif index==6 then
		local us3end = tonumber(proxy.get("rpc.xdslctl.Us3BandFinal")[1].value)
		local us4start = tonumber(proxy.get("rpc.xdslctl.Us4BandInitial")[1].value)
		for i=0,us4start-us3end-2 do
			SpaceBand["band6"] = SpaceBand["band6"] .. "NaN" .. ", "
		end
	elseif index==7 then
		local us4end = tonumber(proxy.get("rpc.xdslctl.Us4BandFinal")[1].value)
		local ds3start = tonumber(proxy.get("rpc.xdslctl.Ds3BandInitial")[1].value)
		for i=0,ds3start-us4end-2 do
			SpaceBand["band7"] = SpaceBand["band7"] .. "NaN" .. ", "
		end
	elseif index==8 then
		local ds3end = tonumber(proxy.get("rpc.xdslctl.Ds3BandFinal")[1].value)
		local ds4start = tonumber(proxy.get("rpc.xdslctl.Ds4BandInitial")[1].value)
		for i=0,ds4start-ds3end-2 do
			SpaceBand["band8"] = SpaceBand["band8"] .. "NaN" .. ", "
		end
	end
end

local function xdslctlget(request)
	local data = ""
	
	data = data .. SpaceBand["band1"]
	
	data = data .. proxy.get("rpc.xdslctl." .. request .. "Us1")[1].value
	
	data = data .. SpaceBand["band2"]
	
	data = data .. proxy.get("rpc.xdslctl." .. request .. "Ds1")[1].value
	
	data = data .. SpaceBand["band3"]
	
	data = data .. proxy.get("rpc.xdslctl." .. request .. "Us2")[1].value
	
	data = data .. SpaceBand["band4"]
	
	data = data .. proxy.get("rpc.xdslctl." .. request .. "Ds2")[1].value
	
	data = data .. SpaceBand["band5"]
	
	data = data .. proxy.get("rpc.xdslctl." .. request .. "Us3")[1].value
	
	data = data .. SpaceBand["band6"]
	
	data = data .. proxy.get("rpc.xdslctl." .. request .. "Us4")[1].value
	
	data = data .. SpaceBand["band7"]
	
	data = data .. proxy.get("rpc.xdslctl." .. request .. "Ds3")[1].value
	
	data = data .. SpaceBand["band8"]
	
	data = data .. proxy.get("rpc.xdslctl." .. request .. "Ds4")[1].value
	
	return data
end

local scanband = proxy.get("rpc.xdslctl.HlogScanBand")

if scanband then
	scanband = scanband[1].value
else
	scanband = "0"
end

local Hlog, HlogLegend, Bits, BitsLegend, QLN, QLNLegend, SNR, SNRLegend 

local profile = proxy.get("sys.class.xdsl.@line0.ProfileName")

_, Hlog = pcall(xdslctlget, "Hlog")
_, Bits = pcall(xdslctlget, "Bits")
_, QLN = pcall(xdslctlget, "QLN")
_, SNR = pcall(xdslctlget, "SNR")

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
var labelLegend = [ 0 ];\
var pointBackgroundColor = [];\
var backgroundColor = [];\
var hlog_ctx = document.getElementById("HlogChart").getContext("2d");\
	var HlogChart = new Chart(hlog_ctx, {\
    type: "line",\
    data: {labels: labelLegend,\
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
var qln_ctx = document.getElementById("QLNChart").getContext("2d");\
	var QLNChart = new Chart(qln_ctx, {\
    type: "line",\
    data: {labels: labelLegend,\
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
var snr_ctx = document.getElementById("SNRChart").getContext("2d");\
	var SNRChart = new Chart(snr_ctx, {\
    type: "line",\
    data: {labels: labelLegend,\
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
var bits_ctx = document.getElementById("BitsChart").getContext("2d");\
	var BitsChart = new Chart(bits_ctx, {\
    type: "bar",\
    data: {labels: labelLegend,\
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
var SNRlen = SNRChart.data.datasets[0].data.length;\
var BitsLen = BitsChart.data.datasets[0].data.length;\
setTimeout(function(){\
	for (i = 0; i < SNRlen; i++) {\
		if '); ngx.print(BandPlanCondition); ngx.print('  {\
			pointBackgroundColor.push("#90cd8a");\
		} else {\
			pointBackgroundColor.push("#f58368");\
		}\
	}\
	HlogChart.update();\
	QLNChart.update();\
	SNRChart.update();\
    for (i = 0; i < BitsLen; i++) {\
		if '); ngx.print(BandPlanCondition); ngx.print('  {\
			backgroundColor.push("#90cd8a");\
		} else {\
			backgroundColor.push("#f58368");\
		}\
	}\
	BitsChart.update();\
}, 500);\
</script>\
'); 