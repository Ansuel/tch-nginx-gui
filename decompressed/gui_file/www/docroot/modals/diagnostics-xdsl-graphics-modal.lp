--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

--
--
--	 Custom Gui for Technicolor Modem: utility script and modified gui for the Technicolor Modem
--	 								   interface based on OpenWrt
--
--    Copyright (C) 2018  Christian Marangi <ansuelsmth@gmail.com>
--
--    This file is part of Custom Gui for Technicolor Modem.
--    
--    Custom Gui for Technicolor Modem is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--    
--    Custom Gui for Technicolor Modem is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--    
--    You should have received a copy of the GNU General Public License
--    along with Custom Gui for Technicolor Modem.  If not, see <http://www.gnu.org/licenses/>.
--
--

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")

local band = {
	Ds1Band = tonumber(proxy.get("rpc.xdslctl.Ds1ScannedBand")[1].value) or -1,
	Ds2Band = tonumber(proxy.get("rpc.xdslctl.Ds2ScannedBand")[1].value) or -1,
	Us1Band = tonumber(proxy.get("rpc.xdslctl.Us1ScannedBand")[1].value) or -1,
	Us2Band = tonumber(proxy.get("rpc.xdslctl.Us2ScannedBand")[1].value) or -1,
	Us3Band = tonumber(proxy.get("rpc.xdslctl.Us3ScannedBand")[1].value) or -1,
	Us4Band = tonumber(proxy.get("rpc.xdslctl.Us4ScannedBand")[1].value) or -1,
}

local function xdslctlget(request,bandtype)
  local data={}
  
  if bandtype == "Us" then
  
	local Us1 = proxy.get("rpc.xdslctl." .. request .. "Us1")
    if Us1 then
    	data[#data+1] = Us1[1].value
    end
	
	local Us2 = proxy.get("rpc.xdslctl." .. request .. "Us2")
	if Us2 then
	  for i=1,band.Ds1Band do --Space
	  	data[#data+1] = "NaN,"
	  end
	  data[#data+1] = Us2[1].value
    end
	
	local Us3 = proxy.get("rpc.xdslctl." .. request .. "Us3")
	
	if Us3 then
	  for i=1,band.Ds2Band do --Space
	  	data[#data+1] = "NaN,"
	  end
      data[#data+1] = Us3[1].value
    end
	
	local Us4 = proxy.get("rpc.xdslctl." .. request .. "Us4")
	
	 if Us4 then
    	data[#data+1] = Us4[1].value
    end
  else --Ds
	
	local Ds1 = proxy.get("rpc.xdslctl." .. request .. "Ds1")
	
    if Ds1 then
	  for i=1,band.Us1Band do --Space
	  	data[#data+1] = "NaN,"
	  end
    	data[#data+1] = Ds1[1].value
    end
    
	local Ds2 = proxy.get("rpc.xdslctl." .. request .. "Ds2")
	
    if Ds2 then
	  for i=1,band.Us2Band do --Space
	  	data[#data+1] = "NaN,"
	  end
    	data[#data+1] = Ds2[1].value
    end
    
	local Ds3Split1 = proxy.get("rpc.xdslctl." .. request .. "Ds3Split1")
	
    if Ds3Split1 then
	  for i=1,(band.Us3Band+band.Us4Band) do --Space
	  	data[#data+1] = "NaN,"
	  end
    	data[#data+1] = Ds3Split1[1].value
    end
	
	local Ds3Split2 = proxy.get("rpc.xdslctl." .. request .. "Ds3Split2")
	
    if Ds3Split2 then
    	data[#data+1] = Ds3Split2[1].value
    end
    
	local Ds4 = proxy.get("rpc.xdslctl." .. request .. "Ds4")
	
    if Ds4 then
    	data[#data+1] = Ds4[1].value
    end
  end
  
  if data == "" then
  	return "NaN"
  end
  
  return data
end

local scanband = proxy.get("rpc.xdslctl.HlogScanBand")
if scanband then
	scanband = tonumber(scanband[1].value) or 0
	scanband = scanband +1
else
	scanband = "1"
end

local _, HlogUs = pcall(xdslctlget, "Hlog","Us")
local _, BitsUs = pcall(xdslctlget, "Bits","Us")
local _, QLNUs = pcall(xdslctlget, "QLN","Us")
local _, SNRUs = pcall(xdslctlget, "SNR","Us")
local _, HlogDs = pcall(xdslctlget, "Hlog","Ds")
local _, BitsDs = pcall(xdslctlget, "Bits","Ds")
local _, QLNDs = pcall(xdslctlget, "QLN","Ds")
local _, SNRDs = pcall(xdslctlget, "SNR","Ds")

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
var scanband = '); ngx.print(scanband); ngx.print('\
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