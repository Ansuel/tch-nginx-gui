--pretranslated: do not change this file
 
local tinsert, ngx = table.insert, ngx

-- Enable localization
gettext.textdomain('webui-mobiled')

local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local params = utils.get_params()
  ngx.print('\
\
<link href="/css/mobiled.css" rel="stylesheet">\
<script language="javascript" type="text/javascript" src="js/flot-min.js"></script>\
\
');  ngx.print( ui_helper.createHeader(params.modal_title, false, true, nil)); ngx.print('\
<div class="modal-body update" id="lte-doctor-body">\
	<form class="form-horizontal" method="post" action="modals/lte-doctor.lp">\
		');  
			local lp = require("web.lp")
			lp.setpath("/www/snippets/")
			lp.include("tabs-mobiled.lp")
			local mobiled = {
				num_devices = "rpc.mobiled.DeviceNumberOfEntries"
			}
			content_helper.getExactContent(mobiled)
			mobiled.num_devices = tonumber(mobiled.num_devices)
			if not mobiled.num_devices or mobiled.num_devices == 0 then
				ngx.print(ui_helper.createAlertBlock(utils.string_map["no_device"]))
				ngx.print("</form></div>")
				ngx.print(ui_helper.createFooter())
				ngx.exit(ngx.HTTP_OK)
			end
		  ngx.print('\
		<div class="row-fluid">\
			<div class="span6" id="plot-container">\
				<select id="plot-period" class="no-save">\
					<option value="5m" selected>');  ngx.print( T"Last five minutes" ); ngx.print('</option>\
					<option value="20m">');  ngx.print( T"Last twenty minutes" ); ngx.print('</option>\
					<option value="1h">');  ngx.print( T"Last hour" ); ngx.print('</option>\
				</select>\
				<div id="plot-tooltip"></div>\
				<div id="plot" style="height: 300px;"></div>\
				<div id="plot-legend"></div>\
			</div>\
			<div class="span6">\
				<div id="parameters-container">\
					<div id="signal-strength-indicator">\
						<div class="bar bar1"></div>\
						<div class="bar bar2"></div>\
						<div class="bar bar3"></div>\
						<div class="bar bar4"></div>\
						<div class="bar bar5"></div>\
					</div>\
					<div id="lte-doctor-values" class="hidden">\
						<h4 id="sigval-title">');  ngx.print( T"Most recent values" ); ngx.print('</h4>\
						');  
							local html = {}
							local options = {span = {class = "span5", id = "nas_state-value"}}
							tinsert(html, ui_helper.createLabel(T"Network Status:", "", options))
							options = {span = {class = "span5", id = "service_state-value"}}
							tinsert(html, ui_helper.createLabel(T"Service Status:", "", options))
							options = {span = {class = "span5", id = "description-value"}}
							tinsert(html, ui_helper.createLabel(T"Operator:", "", options))
							options = {span = {class = "span5", id = "mcc-value"}}
							tinsert(html, ui_helper.createLabel(T"MCC:", "", options))
							options = {span = {class = "span5", id = "mnc-value"}}
							tinsert(html, ui_helper.createLabel(T"MNC:", "", options))
							options = {span = {class = "span5", id = "phy_cell_id-value"}}
							tinsert(html, ui_helper.createLabel(T"Physical Cell ID:", "", options))
							options = {span = {class = "span5", id = "cell_id-value"}}
							tinsert(html, ui_helper.createLabel(T"Cell ID:", "", options))
							options = {span = {class = "span5", id = "radio_interface-value"}}
							tinsert(html, ui_helper.createLabel(T"Access Technology:", "", options))
							options = {span = {class = "span5", id = "radio_bearer_type-value"}}
							tinsert(html, ui_helper.createLabel(T"Radio Bearer:", "", options))
							options = {span = {class = "span5", id = "tracking_area_code-value"}}
							tinsert(html, ui_helper.createLabel(T"Tracking Area Code:", "", options))
							options = {span = {class = "span5", id = "rssi-value"}}
							tinsert(html, ui_helper.createLabel(T"RSSI:", "", options))
							options = {span = {class = "span5", id = "rsrq-value"}}
							tinsert(html, ui_helper.createLabel(T"RSRQ:", "", options))
							options = {span = {class = "span5", id = "rsrp-value"}}
							tinsert(html, ui_helper.createLabel(T"RSRP:", "", options))
							options = {span = {class = "span5", id = "snr-value"}}
							tinsert(html, ui_helper.createLabel(T"SNR:", "", options))
							options = {span = {class = "span5", id = "sinr-value"}}
							tinsert(html, ui_helper.createLabel(T"SINR:", "", options))
							options = {span = {class = "span5", id = "cinr-value"}}
							tinsert(html, ui_helper.createLabel(T"CINR:", "", options))
							options = {span = {class = "span5", id = "path_loss-value"}}
							tinsert(html, ui_helper.createLabel(T"Path loss:", "", options))
							options = {span = {class = "span5", id = "tx_power-value"}}
							tinsert(html, ui_helper.createLabel(T"TX Power:", "", options))
							options = {span = {class = "span5", id = "ecio-value"}}
							tinsert(html, ui_helper.createLabel(T"ECIO:", "", options))
							options = {span = {class = "span5", id = "rscp-value"}}
							tinsert(html, ui_helper.createLabel(T"RSCP:", "", options))
							options = {span = {class = "span5", id = "rrc_state-value"}}
							tinsert(html, ui_helper.createLabel(T"RRC State:", "", options))
							options = {span = {class = "span5", id = "dl_earfcn-value"}}
							tinsert(html, ui_helper.createLabel(T"Downlink EARFCN:", "", options))
							options = {span = {class = "span5", id = "dl_arfcn-value"}}
							tinsert(html, ui_helper.createLabel(T"Downlink ARFCN:", "", options))
							options = {span = {class = "span5", id = "dl_uarfcn-value"}}
							tinsert(html, ui_helper.createLabel(T"Downlink UARFCN:", "", options))
							options = {span = {class = "span5", id = "ul_earfcn-value"}}
							tinsert(html, ui_helper.createLabel(T"Uplink EARFCN:", "", options))
							options = {span = {class = "span5", id = "ul_arfcn-value"}}
							tinsert(html, ui_helper.createLabel(T"Uplink ARFCN:", "", options))
							options = {span = {class = "span5", id = "ul_uarfcn-value"}}
							tinsert(html, ui_helper.createLabel(T"Uplink UARFCN:", "", options))
							options = {span = {class = "span5", id = "lte_band-value"}}
							tinsert(html, ui_helper.createLabel(T"Active Band:", "", options))
							options = {span = {class = "span5", id = "lte_dl_freq-value"}}
							tinsert(html, ui_helper.createLabel(T"Downlink Frequency:", "", options))
							options = {span = {class = "span5", id = "lte_ul_freq-value"}}
							tinsert(html, ui_helper.createLabel(T"Uplink Frequency:", "", options))
							options = {span = {class = "span5", id = "lte_ul_bandwidth-value"}}
							tinsert(html, ui_helper.createLabel(T"Uplink Bandwidth:", "", options))
							options = {span = {class = "span5", id = "lte_dl_bandwidth-value"}}
							tinsert(html, ui_helper.createLabel(T"Downlink Bandwidth:", "", options))
							ngx.print(html)
						  ngx.print('\
					</div>\
				</div>\
			</div>\
		</div>\
	</form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
<script>\
	var lteDoctor = new function() {\
		this.refreshRate = 6;\
		this.minValue = -150;\
		this.data = {\
			rssi : {\
				label: "RSSI (dBm)",\
				color:  "#07a9f0",\
				data: []\
			},\
			rsrq : {\
				label: "RSRQ (dB)",\
				color:  "#8904B1",\
				data: []\
			},\
			rsrp : {\
				label: "RSRP (dBm)",\
				color:  "#4C0B5F",\
				data: []\
			},\
                        rscp : {\
				label: "RSCP (dBm)",\
				color: "#7FFF00",\
				data: []\
			}\
		};\
		this.period_seconds = 0;\
		this.removeOldData = function(uptime) {\
			for (var key in this.data) {\
				var i = this.data[key].data.length;\
				while (i--) {\
					if(parseInt(this.data[key].data[i].uptime) < uptime) {\
						this.data[key].data.splice(i, 1);\
					}\
				}\
			}\
		};\
		this.getData = function(period) {\
			var params = [{ name: "data_period", value: period},\
						  tch.elementCSRFtoken()];\
\
			if(this.last_uptime !== undefined) {\
				params.push({ name: "last_uptime", value: this.last_uptime });\
			}\
\
			var self = this;\
			$.post("/ajax/radioparameters.lua", params, function(data) {\
				if (data !== null && typeof data === \'object\') {\
					self.period_seconds = data.period_seconds;\
					var starting_uptime = parseInt(data.starting_uptime);\
					if (!isNaN(starting_uptime)) {\
						self.removeOldData(starting_uptime);\
					}\
					for (var i = 0; i < data.data.length; i++) {\
						var line = data.data[i];\
						for (var key in self.data) {\
							var val = line[key];\
							if(val !== "") {\
								self.data[key].data.push({uptime: line.uptime, value: val});\
							}\
						}\
					}\
					if(data.data.length) {\
						self.updateParameters(data.data[data.data.length-1]);\
					}\
\
					var fullRefresh = false;\
					if(self.last_uptime === undefined) {\
						fullRefresh = true;\
					}\
					self.last_uptime = data.uptime;\
					var plotData = self.getPlotData();\
\
					if(fullRefresh) {\
						var axes = plot.getAxes();\
						var ticks = [];\
						var suffix;\
						var divider;\
						if(self.period_seconds <= 300) {\
							suffix = "s";\
							divider = 1;\
						} else if(self.period_seconds <= 3600) {\
							suffix = "m";\
							divider = 60;\
						} else {\
							suffix = "h";\
							divider = 3600;\
						}\
\
						var length = self.period_seconds/divider;\
						var increment = length/10;\
						var j = 0;\
						for(var i = 0; i < self.period_seconds; i += increment*divider) {\
							if(i === 0) {\
								ticks.push([self.period_seconds, "Now"]);\
							} else {\
								var val = (j*increment) | 0;\
								ticks.push([self.period_seconds-i, "-"+val+suffix]);\
							}\
							j++;\
						}\
\
						axes.xaxis.options.ticks = ticks;\
						axes.xaxis.options.max = self.period_seconds;\
						axes.xaxis.options.zoomRange = [self.refreshRate, self.period_seconds];\
						axes.xaxis.options.panRange = [self.refreshRate, self.period_seconds];\
						// Redraw\
						plot.setData(plotData);\
						plot.setupGrid();\
						plot.draw();\
						plot.zoomOut();\
					} else {\
						plot.setData(plotData);\
						plot.draw();\
					}\
				}\
				self.timer = setTimeout(refreshParameters, (self.refreshRate*1000));\
			}, "json");\
		};\
		this.getPlotData = function() {\
			var plotData = [];\
			for (var key in this.data) {\
				var res = [];\
				var length = this.data[key].data.length;\
				if (length) {\
					for (var i = 0; i < length; i++) {\
						res.push([this.period_seconds - (this.last_uptime - this.data[key].data[i].uptime), this.data[key].data[i].value]);\
					}\
					plotData.push({ data : res, label : this.data[key].label, color : this.data[key].color });\
				}\
			}\
			return plotData;\
		};\
		this.setBars = function(bars) {\
			$(\'#signal-strength-indicator\').children(\'.bar\').each(function (index, item) {\
				if(index < bars) {\
					$(this).addClass(\'bar-active\');\
				} else {\
					$(this).removeClass(\'bar-active\');\
				}\
			});\
		};\
		this.updateParameters = function(data) {\
			for (var key in data) {\
				if(key == "bars") {\
					this.setBars(data[key]);\
				} else {\
					if(data[key] === "") {\
						$("#"+key+"-value").parent().parent().hide();\
					} else {\
						if(key == "radio_interface") {\
							if(data[key] == "no_service") {\
								data[key] = "');  ngx.print( utils.radio_interface_map["no_service"] ); ngx.print('";\
							} else if(data[key] == "lte") {\
								data[key] = "');  ngx.print( utils.radio_interface_map["lte"] ); ngx.print('";\
							} else if(data[key] == "umts") {\
								data[key] = "');  ngx.print( utils.radio_interface_map["umts"] ); ngx.print('";\
							} else if(data[key] == "gsm") {\
								data[key] = "');  ngx.print( utils.radio_interface_map["gsm"] ); ngx.print('";\
							} else if(data[key] == "cdma") {\
								data[key] = "');  ngx.print( utils.radio_interface_map["cdma"] ); ngx.print('";\
							}\
						}\
						if(key == "nas_state") {\
							if(data[key] == "registered") {\
								data[key] = "');  ngx.print( utils.nas_state_map["registered"] ); ngx.print('";\
							} else if(data[key] == "not_registered") {\
								data[key] = "');  ngx.print( utils.nas_state_map["not_registered"] ); ngx.print('";\
							} else if(data[key] == "not_registered_searching") {\
								data[key] = "');  ngx.print( utils.nas_state_map["not_registered_searching"] ); ngx.print('";\
							} else if(data[key] == "registration_denied") {\
								data[key] = "');  ngx.print( utils.nas_state_map["registration_denied"] ); ngx.print('";\
							} \
						}\
						if(key == "rrc_state") {\
							if(data[key] == "idle") {\
								data[key] = "');  ngx.print( utils.rrc_state_map["idle"] ); ngx.print('";\
							} else if(data[key] == "connected") {\
								data[key] = "');  ngx.print( utils.rrc_state_map["connected"] ); ngx.print('";\
							}\
						}\
						if(key == "service_state") {\
							if(data[key] == "no_service") {\
								data[key] = "');  ngx.print( utils.service_state_map["no_service"] ); ngx.print('";\
							} else if(data[key] == "limited_regional_service") {\
								data[key] = "');  ngx.print( utils.service_state_map["limited_regional_service"] ); ngx.print('";\
							} else if(data[key] == "limited_service") {\
								data[key] = "');  ngx.print( utils.service_state_map["limited_service"] ); ngx.print('";\
							} else if(data[key] == "normal_service") {\
								data[key] = "');  ngx.print( utils.service_state_map["normal_service"] ); ngx.print('";\
							} else if(data[key] == "sleeping") {\
								data[key] = "');  ngx.print( utils.service_state_map["sleeping"] ); ngx.print('";\
							}\
						}\
						$(\'#lte-doctor-values\').removeClass(\'hidden\');\
						$("#"+key+"-value").parent().parent().show();\
						if(this.units[key] != undefined) {\
							$("#"+key+"-value").text(data[key]+\' \'+this.units[key]);\
						} else {\
							$("#"+key+"-value").text(data[key]);\
						}\
					}\
				}\
			}\
		};\
		this.units = {\
			rssi: "dBm",\
			rsrp: "dBm",\
			rsrq: "dB",\
			snr:  "dB",\
			sinr:  "dB",\
			cinr:  "dB",\
			path_loss:  "dB",\
			ecio: "dB",\
			rscp: "dBm",\
			tx_power: "dBm",\
			lte_ul_freq: "MHz",\
			lte_dl_freq: "MHz",\
			lte_dl_bandwidth: "MHz",\
			lte_ul_bandwidth: "MHz"\
		};\
		this.refresh = function() {\
			clearTimeout(this.timer);\
			delete this.last_uptime;\
			for (var key in this.data) {\
				this.data[key].data = [];\
			}\
			this.getData($(\'#plot-period\').val());\
		};\
	};\
\
	function refreshParameters() {\
		lteDoctor.getData($(\'#plot-period\').val());\
	}\
\
	var plot;\
\
	var id = window.setTimeout(function() {}, 0);\
	while (id--) {\
		window.clearTimeout(id);\
	}\
\
	function addPanArrow(dir, right, top, offset, placeholder) {\
		$("<img class=\'navbutton\' src=\'/img/arrow-" + dir + ".gif\' style=\'right:" + right + "px;top:" + top + "px\'>")\
		.appendTo(placeholder)\
		.click(function (e) {\
			e.preventDefault();\
			plot.pan(offset);\
		});\
	}\
\
	function addZoomArrow(dir, right, top, placeholder) {\
		$("<img class=\'navbutton\' src=\'/img/arrow-" + dir + ".gif\' style=\'right:" + right + "px;top:" + top + "px\'>")\
		.appendTo(placeholder)\
		.click(function (e) {\
			e.preventDefault();\
			if(dir == "up") {\
				plot.zoom(100);\
			}\
			else if(dir == "down") {\
				plot.zoomOut();\
			}\
		});\
	}\
\
	var placeholder = $("#plot");\
	plot = $.plot(placeholder, lteDoctor.getPlotData(), {\
		series: {\
			shadowSize: 0,\
			lines: {\
				show: true\
			},\
			points: {\
				show: true\
			}\
		},\
		legend: {\
			noColumns: 0,\
			container: $("#plot-legend")\
		},\
		grid: { hoverable: true, clickable: true },\
		yaxis: {\
			min: lteDoctor.minValue,\
			max: 0,\
			zoomRange: false,\
			panRange: false\
		},\
		xaxis: {\
			min: 0\
		},\
		zoom: {\
			interactive: true\
		},\
		pan: {\
			interactive: true\
		}\
	});\
\
	placeholder.bind("plothover", function (event, pos, item) {\
		if (item) {\
			var x = item.datapoint[0].toFixed(2),\
				y = item.datapoint[1].toFixed(2);\
			$("#plot-tooltip").html(y).css({top: item.pageY+5, left: item.pageX+5}).show();\
		} else {\
			$("#plot-tooltip").hide();\
		}\
	});\
\
	$(\'#plot-period\').on(\'change\', function() {\
		lteDoctor.refresh();\
	});\
\
	// Zooming with more than 100 doesn\'t seem to work\
	plot.zoom(100);\
	plot.zoom(100);\
	plot.zoom(100);\
	plot.pan({ left: 600 });\
\
	addPanArrow("left", 55, 60, { left: -100 }, placeholder);\
	addPanArrow("right", 25, 60, { left: 100 }, placeholder);\
	addZoomArrow("up", 40, 45, placeholder);\
	addZoomArrow("down", 40, 75, placeholder);\
\
	lteDoctor.refresh();\
</script>\
'); 