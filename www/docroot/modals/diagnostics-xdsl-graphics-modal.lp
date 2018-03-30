--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")

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
		  if profile and ( profile[1].value == "BrcmPriv1") then
		  	ngx.print('<div style="height: 400px;width:2260px;">')
		  else
		  	ngx.print('<div style="height: 400px;width:1130px;">')
		  end
		  ngx.print('\
		    <canvas id="HlogChart"></canvas>\
		  </div>\
		</div>\
    </fieldset>\
	<fieldset>\
      <legend>');  ngx.print( T"DSL QLN" ); ngx.print('</legend>\
	    <div style="overflow-x:auto;max-width:1130px;">')
		  if profile and ( profile[1].value == "BrcmPriv1") then
		  	ngx.print('<div style="height: 400px;width:2260px;">')
		  else
		  	ngx.print('<div style="height: 400px;width:1130px;">')
		  end
		  ngx.print('\
		    <canvas id="QLNChart"></canvas>\
		  </div>\
		</div>\
    </fieldset>\
	<fieldset>\
      <legend>');  ngx.print( T"DSL SNR" ); ngx.print('</legend>\
	    <div style="overflow-x:auto;max-width:1130px;">')
		  if profile and ( profile[1].value == "BrcmPriv1") then
		  	ngx.print('<div style="height: 400px;width:2260px;">')
		  else
		  	ngx.print('<div style="height: 400px;width:1130px;">')
		  end
		  ngx.print('\
		    <canvas id="SNRChart"></canvas>\
		  </div>\
		</div>\
    </fieldset>\
	<fieldset>\
      <legend>');  ngx.print( T"DSL Bits" ); ngx.print('</legend>\
		<div style="overflow-x:auto;max-width:1130px;">')
		  if profile and ( profile[1].value == "BrcmPriv1") then
		  	ngx.print('<div style="height: 400px;width:16096px;">')
		  else
		  	ngx.print('<div style="height: 400px;width:8048px;">')
		  end
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
    if ( (7 < i && i < 32) || \
	(871 < i && i < 1205) || \
	(1972 < i && i < 3203) ) {\
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
    if ( (7 < i && i < 32) || \
	(871 < i && i < 1205) || \
	(1972 < i && i < 3203) ) {\
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
    if ( (7 < i && i < 32) || \
	(871 < i && i < 1205) || \
	(1972 < i && i < 3203) ) {\
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
    if ( (7 < i && i < 32) || \
	(871 < i && i < 1205) || \
	(1972 < i && i < 3203) ) {\
        backgroundColor.push("#90cd8a");\
    } else {\
        backgroundColor.push("#f58368");\
    }\
}\
BitsChart.update();\
</script>\
'); 