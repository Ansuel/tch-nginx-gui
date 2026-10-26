--pretranslated: do not change this file
 

local tinsert, format = table.insert, string.format

gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local proxy = require("datamodel")
local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local params = utils.get_params()

local function wait_for_completion(base_path, return_json, filename)
	local state_path = base_path .. "state"
	local info_path = base_path .. "info"
	local sleep_time = 0.250
	local max_time = 5
	local total_time = 0
	local content
	repeat
		ngx.sleep(sleep_time)
		total_time = total_time + sleep_time

		content = { state = state_path, info = info_path }
		content_helper.getExactContent(content)
	until (total_time >= max_time or content.state ~= "Requested")
	if filename then
		os.remove(filename)
	end
	if content.state ~= "Complete" then
		if content.state == "Requested" then
			ngx.log(ngx.ERR, "Timeout on ", base_path)
		else
			ngx.log(ngx.ERR, format('Error on %s (state="%s", info="%s")',
			base_path, content.state, content.info or ""))
		end
		if return_json then
			ngx.print('{ "error":"10" }')
			ngx.exit(ngx.OK)
		else
			ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
		end
	end
end

local function export_data(export_type)
	if export_type ~= "csv" and export_type ~= "json" then
		return
	end

	local export_rpc_path = "rpc.ltedoctor.export."

	local content = {
		export_state = export_rpc_path .. "state",
		export_location = export_rpc_path .. "location",
		export_filename = export_rpc_path .. "filename",
	}

	-- Get transformer content
	content_helper.getExactContent(content)

	if content.export_state ~= "Requested" then
		-- start new export request
		local uptime = content_helper.readfile("/proc/uptime", "number", math.floor)
		content.export_filename = format("ltedoctor-data-export.%d.%s", uptime, export_type)

		proxy.set({ [export_rpc_path .. "filename"] = content.export_filename })
		proxy.set({ [export_rpc_path .. "state"] = "Requested" })
	end

	-- wait for completion; does not return on error or timeout
	wait_for_completion(export_rpc_path)

	-- return exported data
	ngx.header.content_disposition = format("attachment; filename=data.%s", export_type)
	ngx.header.content_type = "application/octet-stream"
	ngx.header.set_cookie = "fileDownload=true; Path=/" -- the JS download code requires this cookie
	local export_path = string.untaint(content.export_location .. content.export_filename)
	local f = io.open(export_path, "r")
	if f then
		ngx.print(f:read("*all"))
		f:close()
	end

	-- cleanup (reset state and remove export file)
	proxy.set({ [export_rpc_path .. "filename"] = "" })

	-- and we're done
	ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" then
	local action = ngx.req.get_post_args().action
	if action == "export_data" then
		return export_data(ngx.req.get_post_args().export_type)
	end
end

local ltedoctor_sections = {
	{
		title = T"Status",
		id = "status",
		params = {
			{
				name = "nas_state",
				desc = T"Network Status",
				translations = {
					registered = utils.nas_state_map["registered"],
					not_registered = utils.nas_state_map["not_registered"],
					not_registered_searching = utils.nas_state_map["not_registered_searching"],
					registration_denied = utils.nas_state_map["registration_denied"]
				}
			},
			{
				name = "service_state",
				desc = T"Service Status",
				translations = {
					no_service = utils.nas_state_map["no_service"],
					limited_regional_service = utils.service_state_map["limited_regional_service"],
					limited_service = utils.service_state_map["limited_service"],
					normal_service = utils.service_state_map["normal_service"],
					sleeping = utils.service_state_map["sleeping"]
				}
			}
		}
	},
	{
		title = T"Signal Quality",
		id = "signal_quality",
		params = {
			{ name = "rssi", desc = T"RSSI", unit = "dBm" },
			{ name = "rsrp", desc = T"RSRP", unit = "dBm" },
			{ name = "rsrq", desc = T"RSRQ", unit = "dB" },
			{ name = "snr", desc = T"SNR", unit = "dB" },
			{ name = "sinr", desc = T"SINR", unit = "dB" },
			{ name = "cinr", desc = T"CINR", unit = "dB" },
			{ name = "path_loss", desc = T"Path Loss", unit = "dB" },
			{ name = "tx_power", desc = T"TX Power", unit = "dBm" },
			{ name = "ecio", desc = T"ECIO", unit = "dB" },
			{ name = "rscp", desc = T"RSCP", unit = "dBm" }
		}
	},
	{
		title = T"Operator Info",
		id = "operator_info",
		params = {
			{ name = "network_desc", desc = T"Operator" },
			{ name = "mcc", desc = T"MCC" },
			{ name = "mnc", desc = T"MNC" }
		}
	},
	{
		title = T"Cell Info",
		id = "cell_info",
		params = {
			{ name = "cell_id", desc = T"Cell ID" },
			{ name = "phy_cell_id", desc = T"Physical Cell ID" },
			{
				name = "radio_interface",
				desc = T"Access Technology",
				translations = {
					no_service = utils.radio_interface_map["no_service"],
					lte = utils.radio_interface_map["lte"],
					umts = utils.radio_interface_map["umts"],
					gsm = utils.radio_interface_map["gsm"],
					cdma = utils.radio_interface_map["cdma"],
				}
			},
			{ name = "radio_bearer_type", desc = T"Radio Bearer" },
			{ name = "tracking_area_code", desc = T"Tracking Area Code" },
			{
				name = "rrc_state",
				desc = T"RRC State",
				translations = {
					idle = utils.rrc_state_map["idle"],
					connected = utils.rrc_state_map["connected"]
				}
			},
			{ name = "dl_earfcn", desc = T"Downlink EARFCN" },
			{ name = "dl_arfcn", desc = T"Downlink ARFCN" },
			{ name = "dl_uarfcn", desc = T"Downlink UARFCN" },
			{ name = "ul_earfcn", desc = T"Uplink EARFCN" },
			{ name = "ul_arfcn", desc = T"Uplink ARFCN" },
			{ name = "ul_uarfcn", desc = T"Uplink UARFCN" },
			{ name = "lte_band", desc = T"Active Band" },
			{ name = "lte_dl_freq", desc = T"Downlink Frequency", unit = "MHz" },
			{ name = "lte_ul_freq", desc = T"Uplink Frequency", unit = "MHz" },
			{ name = "lte_ul_bandwidth", desc = T"Uplink Bandwidth", unit = "MHz" },
			{ name = "lte_dl_bandwidth", desc = T"Downlink Bandwidth", unit = "MHz" }
		}
	}
}

local ltedoctor_optional_sections = {
	additional_carriers = {
		title = T"Carrier Aggregation",
		id = 'additional_carrier',
		class = 'additional_carrier',
		params = {
			{ name = "rssi", desc = T"RSSI", unit = "dBm" },
			{ name = "rsrp", desc = T"RSRP", unit = "dBm" },
			{ name = "rsrq", desc = T"RSRQ", unit = "dB" },
			{ name = "sinr", desc = T"SINR", unit = "dB" },
			{ name = "phy_cell_id", desc = T"Physical Cell ID"},
			{ name = "lte_band", desc = T"Active Band" },
			{ name = "dl_earfcn", desc = T"Downlink EARFCN" }
		}
	}
}

local no_signal = {
	alert = {
		class = "alert-info",
		style = "margin-top: 10px;"
	}
}

local alarm_translations = {
	network_registered = T"Network Registered",
	network_deregistered = T"Network Deregistered",
	session_connected = T"Session Connected",
	session_disconnected = T"Session Disconnected",
	sim_initialized = T"SIM Ready",
	ifup = T"Interface Up",
	ifdown = T"Interface Down",
	session_activate = T"Session Activated",
	session_deactivate = T"Session Deactivated",
	ecgi_changed = T"Cell Changed",
	cgi_changed = T"Cell Changed",
	radio_interface_changed = T"Radio Interface Changed",
	tracking_area_code_changed = T"Tracking Area Code Changed",
	location_area_code_changed = T"Location Area Code Changed",
	device_disconnected = "Device Disconnected"
}

local alarm_info_translations = {
	radio_interface = { desc = T"New Radio Interface" .. ":", values = utils.radio_interface_map },
	tracking_area_code = { desc = T"New TAC" .. ":" },
	location_area_code = { desc = T"New LAC" .. ":" },
	reject_cause = { desc = T"Reject Cause" },
	ecgi = { desc = T"New ECGI" .. ":" },
	cgi = { desc = T"New CGI" .. ":" },
	session = { desc = T"Session" }
}

local alarm_info_session_translations = {
	internal_ims_pdn = T"Voice",
	internet = T"Internet"
}

local alarm_info_ip_translations = {
	ipv4 = T"IPv4",
	ipv6 = T"IPv6"
}

local alarm_importance_select = {
	{ desc = T"Critical", option = "critical" },
	{ desc = T"Major", option = "major" },
	{ desc = T"Minor", option = "minor" },
	{ desc = T"Info", option = "info" },
	{ desc = T"Success", option = "success" },
	{ desc = T"All", option = "all" }
}

local mobiled = {
	num_devices = "rpc.mobiled.DeviceNumberOfEntries"
}
content_helper.getExactContent(mobiled)

local function get_device_data(dev_idx)
	local rpc_path = format("rpc.mobiled.device.@%d.", dev_idx)
	local device = {
		rpc_path = rpc_path
	}

	device.info = utils.getContent(rpc_path .. "info.")
	if not device.info then return nil end

	if not device.info.model then device.info.model = T"Unknown" end

	return device
end

local selected_device

mobiled.devices = {}
mobiled.num_devices = tonumber(mobiled.num_devices)
if mobiled.num_devices and mobiled.num_devices >= 1 then
	for dev_idx=1,mobiled.num_devices do
		mobiled.devices[dev_idx] = get_device_data(dev_idx)
	end

	local getargs = ngx.req.get_uri_args()
	local current_dev_desc = getargs.dev_desc
	local current_dev_idx = tonumber(getargs.dev_idx) or 1
	selected_device = mobiled.devices[current_dev_idx]
	if selected_device and current_dev_desc then
		-- Device got unplugged with the GUI open
		if current_dev_desc ~= selected_device.info.dev_desc then
			current_dev_idx = 1
			selected_device = mobiled.devices[current_dev_idx]
		end
	end
end

  ngx.print('\
\
<link href="/css/mobiled.css" rel="stylesheet">\
<script language="javascript" type="text/javascript" src="js/flot-min.js"></script>\
\
');  ngx.print( ui_helper.createHeader(params.modal_title, true, true, nil)); ngx.print('\
<div class="modal-body update no-save" id="lte-doctor-body" style="min-height: 50px; min-width: 300px;">\
	<form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
		');  
			local lp = require("web.lp")
			lp.setpath("/www/snippets/")
			lp.include("tabs-mobiled.lp")
			if not mobiled.num_devices or mobiled.num_devices == 0 then
				ngx.print(ui_helper.createAlertBlock(utils.string_map["no_device"]))
				ngx.print("</form></div>")
				ngx.print(ui_helper.createFooter())
				ngx.exit(ngx.HTTP_OK)
			end
		  ngx.print('\
		<div class=\'row-fluid\'>\
		');  
			local html = {}
			tinsert(html, '<div class="span2">')
			tinsert(html, format('<ul class="nav nav-list" id="active_devices"><li class="nav-header">%s</li>', T"Active Devices"))
			for _, device in pairs(mobiled.devices) do
				local active = ""
				if device.info.dev_idx == selected_device.info.dev_idx then
					active = "active"
				end
				local url = "modals/lte-doctor.lp?dev_idx=" .. device.info.dev_idx .. "&dev_desc=" .. device.info.dev_desc
				tinsert(html, format('<li class="%s"><a href="#" data-remote="%s">%s</a></li>', active, url, device.info.model))
			end
			tinsert(html, '</div>')
			ngx.print(html)
		  ngx.print('\
			<div class="span10" id="plot-container">\
				<select id="plot-period">\
					');  
						local timeEntries = proxy.getPN("rpc.ltedoctor.alarms.", true)
						html = {}
						local selectEntries = {}
						for _, entry in pairs(timeEntries) do
							local name = string.match(entry.path, "rpc%.ltedoctor%.alarms%.@([^%.]+)%.")
							local time_entry_info = {
								period_seconds = entry.path .. 'period_seconds'
							}
							content_helper.getExactContent(time_entry_info)
							local period_seconds = tonumber(time_entry_info.period_seconds)
							if period_seconds then
								tinsert(selectEntries, { name = name, period_seconds = period_seconds })
							end
							local function sort_by_period(a, b)
								return a.period_seconds < b.period_seconds
							end
							table.sort(selectEntries, sort_by_period)
						end
						for _, entry in pairs(selectEntries) do
							if entry == "last_five_minutes" then
								tinsert(html, format('<option value="%s" selected="selected">%s</option>', entry.name, utils.time_period_map[entry.name]))
							else
								tinsert(html, format('<option value="%s">%s</option>', entry.name, utils.time_period_map[entry.name]))
							end
						end
						ngx.print(html)
					  ngx.print('\
				</select>\
				<div id="plot-container-inner">\
					<div id="signal-strength-indicator">\
						<div class="bar bar1"></div>\
						<div class="bar bar2"></div>\
						<div class="bar bar3"></div>\
						<div class="bar bar4"></div>\
						<div class="bar bar5"></div>\
					</div>\
					<div id="waiting" class="loading"></div>\
					<div data-bind="visible: showPlot">\
						<div id="plot-tooltip"></div>\
						<div id="plot" style="height: 300px; width: 100%; clear:both;"></div>\
						<div id="plot-legend"></div>\
					</div>\
					<div data-bind="visible: showPlotWarning" style="clear: both;">\
						');  ngx.print( ui_helper.createAlertBlock(T"No signal quality history available for the selected period", no_signal) ); ngx.print('\
					</div>\
				</div>\
			</div>\
		</div>\
		<div class=\'row-fluid loading-hidden\' style=\'visibility: hidden;\'>\
			<div class="span2"></div>\
			<div id="parameters-container" class="span10" >\
				<div id="lte-doctor-values" class="hidden"></div>\
			</div>\
		</div>\
		<div class="advanced hide">\
			<div id="stats-container" class=\'row-fluid loading-hidden\' data-bind="visible: sessionStats().length > 0" style=\'visibility: hidden;\'>\
				<div class="span2"></div>\
				<div class="span10">\
					<fieldset><legend>');  ngx.print( T"Statistics" ); ngx.print('</legend>\
						<h4 class="sigval-title">');  ngx.print(T"Network"); ngx.print('</h4>\
						');  
							local big_label_class = {
								span = {
									style = "margin-left: 10px;"
								},
								label = {
									style = "width: 250px;"
								}
							}
							html = {}
							big_label_class.span["data-bind"] = "text: networkStats().deregistered"
							tinsert(html, ui_helper.createLabel(T"Network Deregistrations" .. ":", "0", big_label_class))
							big_label_class.span["data-bind"] = "text: networkStats().cgi_changed"
							tinsert(html, ui_helper.createLabel(T"Cell Global ID Changes" .. ":", "0", big_label_class))
							big_label_class.span["data-bind"] = "text: networkStats().ecgi_changed"
							tinsert(html, ui_helper.createLabel(T"EUTRA Cell Global ID Changes" .. ":", "0", big_label_class))
							big_label_class.span["data-bind"] = "text: networkStats().location_area_code_changed"
							tinsert(html, ui_helper.createLabel(T"Location Area Code Changes" .. ":", "0", big_label_class))
							big_label_class.span["data-bind"] = "text: networkStats().tracking_area_code_changed"
							tinsert(html, ui_helper.createLabel(T"Tracking Area Code Changes" .. ":", "0", big_label_class))
							big_label_class.span["data-bind"] = "text: networkStats().radio_interface_changed"
							tinsert(html, ui_helper.createLabel(T"Radio Interface Changes" .. ":", "0", big_label_class))
							ngx.print(html)
						  ngx.print('\
						<div data-bind="foreach: sessionStats">\
							<h4 class="sigval-title" data-bind="text: $parent.getSessionTitle(name)"></h4>\
							<div class="control-group">\
								<label style="width: 250px;" class="control-label">');  ngx.print(T"Disconnected" .. ":"); ngx.print('</label>\
								<div class="controls">\
									<span class="span2 simple-desc" style="margin-left: 10px;" data-bind="text: disconnected"></span>\
								</div>\
							</div>\
							<div class="control-group">\
								<label style="width: 250px;" class="control-label">');  ngx.print(T"Deactivated" .. ":"); ngx.print('</label>\
								<div class="controls">\
									<span class="span2 simple-desc" style="margin-left: 10px;" data-bind="text: deactivated"></span>\
								</div>\
							</div>\
						</div>\
					</fieldset>\
				</div>\
			</div>\
			<div class=\'row-fluid loading-hidden\' style=\'visibility: hidden;\'>\
				<div class="span2"></div>\
				<div class="span10">\
					<fieldset id="alarms-container"><legend>');  ngx.print( T"Events" ); ngx.print('</legend>\
						<input id="search" placeholder="');  ngx.print( T"Search" .. "…" ); ngx.print('" type="search" data-bind="value: query, valueUpdate: \'keyup\'" autocomplete="off">\
						<select data-bind="options: alarmImportanceSelect, optionsText: \'desc\', optionsValue: \'option\', value: selectedImportance, event:{ change: $root.alarmImportanceChanged}"></select>\
						<div id="export_data_csv_btn" class="btn export custom-handler"><i class="icon-download-alt"></i>  ');  ngx.print(T"csv"); ngx.print('</div>\
						<div id="export_data_json_btn" class="btn export custom-handler"><i class="icon-download-alt"></i>  ');  ngx.print(T"json"); ngx.print('</div>\
						<div data-bind="visible: alarms().length > 0">\
							<table class="table" id="ltedoctor_events">\
								<thead class="ltedoctor_events_head">\
									<tr><th>');  ngx.print(T"Date"); ngx.print('</th><th>');  ngx.print(T"Event"); ngx.print('</th><th>');  ngx.print(T"Info"); ngx.print('</th></tr>\
								</thead>\
								<tbody data-bind="foreach: alarms">\
									<tr data-bind=" css: $root.getImportanceStyle(importance)">\
										<td data-bind="text: when" style="border-top:0;"></td>\
										<td data-bind="text: event" style="border-top:0;"></td>\
										<td data-bind="text: info" style="border-top:0;"></td>\
									</tr>\
								</tbody>\
							</table>\
						</div>\
						');  
							local exporting_alert = {
								alert = {
									class = "alert-info hide",
									id = "exporting-msg",
									style = "margin-top: 10px;"
								}
							}
							local exporting_fail = {
								alert = {
									class = "alert-error hide",
									id = "export-failed-msg",
									style = "margin-top: 10px;"
								}
							}
							html = {}
							tinsert(html, ui_helper.createAlertBlock(T"Exporting configuration, please wait...", exporting_alert))
							tinsert(html, ui_helper.createAlertBlock(T"Exporting failed; please try again.", exporting_fail))
							ngx.print(html)
						  ngx.print('\
						<div data-bind="visible: alarms().length == 0">\
							');  ngx.print( ui_helper.createAlertBlock(T"No events for the selected period", no_signal) ); ngx.print('\
						</div>\
					</fieldset>\
				</div>\
			</div>\
		</div>\
	</form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
<script>\
	function dynamicSort(property) {\
		var sortOrder = 1;\
		if(property[0] === "-") {\
			sortOrder = -1;\
			property = property.substr(1);\
		}\
		return function (a,b) {\
			var result = (a[property] < b[property]) ? -1 : (a[property] > b[property]) ? 1 : 0;\
			return result * sortOrder;\
		};\
	}\
\
	var LteDoctor = function () {\
		this.requests = {\
			stats : {},\
			alarms : {},\
			current : {},\
			history : {}\
		};\
		this.sessionStats = ko.observableArray([]);\
		this.networkStats = ko.observableArray([]);\
		this.showPlot = ko.observable(true);\
		this.showPlotWarning = ko.observable(false);\
		this.selectedImportance = ko.observable(\'all\');\
		this.availableImportanceSelect = ko.observableArray([]);\
		this.observables = {};\
		this.query = ko.observable(\'\');\
		this.alarmsData = [];\
		this.alarms = ko.observableArray([]);\
		this.refreshRate = 6;\
		this.plotMinValue = -150;\
		this.alarmImportanceSelect = ');  ngx.print( json.encode(alarm_importance_select) ); ngx.print(';\
		this.alarmTranslations = ');  ngx.print( json.encode(alarm_translations) ); ngx.print(';\
		this.alarmInfoIPTranslations = ');  ngx.print( json.encode(alarm_info_ip_translations) ); ngx.print(';\
		this.alarmInfoTranslations = ');  ngx.print( json.encode(alarm_info_translations) ); ngx.print(';\
		this.alarmInfoSessionTranslations = ');  ngx.print( json.encode(alarm_info_session_translations) ); ngx.print(';\
		this.sections = ');  ngx.print( json.encode(ltedoctor_sections) ); ngx.print(';\
		this.optionalSections = ');  ngx.print( json.encode(ltedoctor_optional_sections) ); ngx.print(';\
		this.alarmImportanceChanged = function() {\
			this.search($("#search").val());\
		};\
		this.getSessionTitle = function(name) {\
			if(this.alarmInfoSessionTranslations[name] !== undefined) {\
				return this.alarmInfoSessionTranslations[name] + " " + "');  ngx.print(T"Session"); ngx.print('";\
			}\
			return name + " " + "');  ngx.print(T"Session"); ngx.print('";\
		};\
		this.getAlarmInfo = function(data) {\
			var message = [];\
			if(data.session != "") {\
				var session = this.alarmInfoSessionTranslations[data.session];\
				if(session === undefined) {\
					session = data.session;\
				}\
				message.push(session + " " + this.alarmInfoTranslations.session.desc);\
			}\
			if(data.ip_type == "ipv4" || data.ip_type == "ipv6") {\
				message.push("(" + this.alarmInfoIPTranslations[data.ip_type] + ")");\
			}\
			var props = ["reject_cause", "cgi", "ecgi", "radio_interface", "location_area_code", "tracking_area_code"];\
			for (var i = 0; i < props.length; i++) {\
				var prop = props[i];\
				if(data[prop] !== undefined && data[prop] != "" && this.alarmInfoTranslations[prop] !== undefined) {\
					if(!this.alarmInfoTranslations[prop].values) {\
						message.push(this.alarmInfoTranslations[prop].desc + " " + data[prop]);\
					} else {\
						if(this.alarmInfoTranslations[prop].values[data[prop]]) {\
							message.push(this.alarmInfoTranslations[prop].desc + " " + this.alarmInfoTranslations[prop].values[data[prop]]);\
						}\
					}\
				}\
			}\
			return message.join(" ");\
		};\
		this.getAlarmTranslation = function(alarm) {\
			var translation = this.alarmTranslations[alarm];\
			if (translation === undefined) {\
				return alarm;\
			}\
			return translation;\
		};\
		this.getImportanceStyle = function(importance) {\
			if(importance == "success") {\
				return "alert alert-success";\
			} else if(importance == "minor") {\
				return "alert alert-notice";\
			} else if(importance == "major") {\
				return "alert alert-warning";\
			} else if(importance == "critical") {\
				return "alert alert-error";\
			}\
			return "alert alert-info";\
		};\
		this.search = function(value) {\
			lteDoctor.alarms.removeAll();\
			for (var i = 0; i < lteDoctor.alarmsData.length; i++) {\
				var alarm = lteDoctor.alarmsData[i];\
				if((value == "" ||\
				value === undefined ||\
				alarm.event.toLowerCase().indexOf(value.toLowerCase()) >= 0 ||\
				alarm.when.toLowerCase().indexOf(value.toLowerCase()) >= 0 ||\
				alarm.info.toLowerCase().indexOf(value.toLowerCase()) >= 0) &&\
				(lteDoctor.selectedImportance() == alarm.importance || lteDoctor.selectedImportance() == "all")) {\
					lteDoctor.alarms.push(alarm);\
				}\
			}\
		};\
		this.plotData = {\
			rssi : {\
				label: "RSSI (dBm)",\
				color: "#07a9f0",\
				data: []\
			},\
			rsrq : {\
				label: "RSRQ (dB)",\
				color: "#8904B1",\
				data: []\
			},\
			rsrp : {\
				label: "RSRP (dBm)",\
				color: "#4C0B5F",\
				data: []\
			},\
			rscp : {\
				label: "RSCP (dBm)",\
				color: "#7FFF00",\
				data: []\
			}\
		};\
		this.period_seconds = 0;\
		this.removeOldPlotData = function(uptime) {\
			var i;\
			for (var key in this.plotData) {\
				i = this.plotData[key].data.length;\
				while (i--) {\
					if(parseInt(this.plotData[key].data[i].uptime) < uptime) {\
						this.plotData[key].data.splice(i, 1);\
					}\
				}\
			}\
		};\
		this.removeOldAlarms = function(uptime) {\
			var i = this.alarmsData.length;\
			while (i--) {\
				if(parseInt(this.alarmsData[i].uptime) < uptime) {\
					this.alarmsData.splice(i, 1);\
				}\
			}\
		};\
		this.getData = function(period) {\
			var params = [{ name: "data_period", value: period },\
						  { name : "dev_idx", value : ');  ngx.print( selected_device.info.dev_idx ); ngx.print(' },\
						  { name: "request_data", value: JSON.stringify(this.requests) },\
						  tch.elementCSRFtoken()];\
\
			var self = this;\
			$.post("/ajax/radioparameters.lua", params, function(data) {\
				if (data !== null && typeof data === \'object\') {\
					if(data.data_period != $(\'#plot-period\').val()) {\
						return;\
					}\
					var starting_uptime;\
					if(data.alarms !== undefined) {\
						starting_uptime = parseInt(data.alarms.starting_uptime);\
						if (!isNaN(starting_uptime)) {\
							self.removeOldAlarms(starting_uptime);\
						}\
						if(data.alarms.data !== undefined) {\
							data.alarms.data.sort(dynamicSort("uptime"));\
							for (var i = 0; i < data.alarms.data.length; i++) {\
								var alarm = data.alarms.data[i];\
								var event = { when : alarm.when, event : self.getAlarmTranslation(alarm.type), info : self.getAlarmInfo(alarm), importance : alarm.importance, uptime : parseInt(alarm.uptime) };\
								self.alarmsData.unshift(event);\
							}\
						}\
					}\
					self.search($("#search").val());\
\
					if(data.history !== undefined) {\
						var period_seconds = parseInt(data.history.period_seconds);\
						if (!isNaN(period_seconds)) {\
							self.period_seconds = period_seconds;\
						}\
						starting_uptime = parseInt(data.history.starting_uptime);\
						if (!isNaN(starting_uptime)) {\
							self.removeOldPlotData(starting_uptime);\
						}\
						for (var i = 0; i < data.history.data.length; i++) {\
							var line = data.history.data[i];\
							for (var key in self.plotData) {\
								var val = line[key];\
								if(val !== "") {\
									self.plotData[key].data.push({uptime: parseInt(line.uptime), value: val});\
								}\
							}\
						}\
					}\
\
					if(data.current !== undefined) {\
						self.updateParameters(data.current);\
					}\
\
					if(data.stats !== undefined) {\
						self.updateStats(data.stats);\
					}\
\
					var fullRefresh = false;\
					if (self.requests.history.last_uptime == undefined) {\
						fullRefresh = true;\
					}\
\
					if(data.history !== undefined) {\
						var uptime = parseInt(data.history.current_uptime);\
						if (!isNaN(uptime)) {\
							self.requests.history.last_uptime = uptime;\
						}\
					}\
					if(data.alarms !== undefined) {\
						var uptime = parseInt(data.alarms.current_uptime);\
						if (!isNaN(uptime)) {\
							self.requests.alarms.last_uptime = uptime;\
						}\
					}\
\
					var plotData = self.getPlotData();\
\
					if (plotData.length > 0) {\
						if (fullRefresh) {\
							var axes = self.plot.getAxes();\
							var ticks = [];\
							var suffix;\
							var divider;\
							if (self.period_seconds <= 300) {\
								suffix = "s";\
								divider = 1;\
							} else if (self.period_seconds <= 3600) {\
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
							for (var i = 0; i < self.period_seconds; i += increment*divider) {\
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
							self.plot.setData(plotData);\
							self.plot.setupGrid();\
							self.plot.draw();\
							self.plot.zoomOut();\
						} else {\
							self.plot.setData(plotData);\
							self.plot.draw();\
						}\
						self.showPlot(true);\
						self.showPlotWarning(false);\
					} else {\
						self.showPlot(false);\
						self.showPlotWarning(true);\
					}\
					$(".loading").hide();\
					$("#lte-doctor-body .loading-hidden").css("visibility", "");\
				}\
				self.timer = setTimeout(function () { self.refreshParameters(); }, self.refreshRate*1000);\
			}, "json");\
		};\
		this.getPlotData = function() {\
			var plotData = [];\
			for (var key in this.plotData) {\
				var res = [];\
				var length = this.plotData[key].data.length;\
				if (length) {\
					this.plotData[key].data.sort(dynamicSort("uptime"));\
					for (var i = 0; i < length; i++) {\
						res.push([this.period_seconds - (this.requests.history.last_uptime - this.plotData[key].data[i].uptime), this.plotData[key].data[i].value]);\
					}\
					plotData.push({ data : res, label : this.plotData[key].label, color : this.plotData[key].color });\
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
		this.getTranslation = function(param, value) {\
			for(var i = 0; i < this.sections.length; i++) {\
				var section = this.sections[i];\
				for (var k in section.params) {\
					var p = section.params[k];\
					if (p.name == param && typeof p.translations != \'undefined\') {\
						return p.translations[value];\
					}\
				}\
			}\
		};\
		this.updateStats = function(data) {\
			if(data.sessions !== undefined) {\
				this.sessionStats.removeAll();\
				for (var i = 0; i < data.sessions.length; i++) {\
					var session = data.sessions[i];\
					this.sessionStats.push(session);\
				}\
			}\
			if(data.network !== undefined) {\
				this.networkStats(data.network);\
			}\
		};\
		this.updateParameters = function(data) {\
			$(\'#lte-doctor-values\').removeClass(\'hidden\');\
\
			for (var key in data) {\
				if(key == "bars") {\
					this.setBars(data[key]);\
				} else if (typeof this.observables[key] != \'undefined\') {\
					var translation = this.getTranslation(key, data[key]);\
					if (translation !== undefined) {\
						this.observables[key](translation);\
					} else {\
						this.observables[key](data[key]);\
					}\
				}\
			}\
\
			var self = this;\
			if(data.additional_carriers !== undefined && data.additional_carriers.length > 0) {\
				var section = self.optionalSections.additional_carriers;\
				$.each(data.additional_carriers, function(key, carrier) {\
					if($(\'#\' + section.id + key).length == 0) {\
						var html = \'<div id="\' + section.id + key + \'" class="additional_carrier">\';\
						html += \'<h4 class="sigval-title">\' + section.title + \'</h4>\';\
						for (var k in section.params) {\
							var param = section.params[k];\
							var name = \'carrier\' + key + \'_\' + param.name;\
							self.observables[name] = ko.observable("");\
							var bind = name;\
							if (param.unit !== undefined) {\
								self.observables[name + \'_full\'] = function(param, unit) {\
									return self.observables[param]() + " " + unit;\
								};\
								bind += "_full(\'"+name+ "\',\'"+param.unit+"\')";\
							}\
							html += \'<div data-bind="visible: observables.\' + name + \'().length > 0" class="control-group">\';\
							html += \'<label class="control-label">\' + param.desc + \'</label>\';\
							html += \'<div class="controls">\';\
							html += \'<span class="simple-desc span5" data-bind="text: observables.\' + bind + \'"></span>\';\
							html += \'</div></div>\';\
						}\
						html += \'</div>\';\
						$( ".span6" ).last().append(html);\
						var elem = document.getElementById(\'lte-doctor-values\');\
						ko.cleanNode(elem);\
						ko.applyBindings(self, elem);\
					}\
					for (var val in carrier) {\
						var name = \'carrier\' + key + \'_\' + val;\
						if (typeof self.observables[name] != \'undefined\') {\
							self.observables[name](carrier[val]);\
						}\
					}\
				});\
			} else {\
				$(\'.additional_carrier\').remove();\
			}\
		};\
		this.shouldBeVisible = function(name) {\
			var self = this;\
			var visible = false;\
			$.each(this.sections, function(key, section) {\
				if(section.id == name) {\
					for (var k in section.params) {\
						var params = section.params[k];\
						if(self.observables[params.name]() != "") {\
							visible = true;\
							return;\
						}\
					}\
				}\
			});\
			return visible;\
		};\
		this.refresh = function() {\
			$("#lte-doctor-body .loading-hidden").css("visibility", "hidden");\
			$(".loading").show();\
			clearTimeout(this.timer);\
			delete this.requests.history.last_uptime;\
			delete this.requests.alarms.last_uptime;\
			for (var key in this.plotData) {\
				this.plotData[key].data = [];\
			}\
			this.refreshParameters();\
			this.alarmsData = [];\
		};\
		this.refreshParameters = function() {\
			this.getData($(\'#plot-period\').val());\
		};\
		this.addPanArrow = function(dir, right, top, offset, placeholder) {\
			var self = this;\
			$("<img class=\'navbutton\' src=\'/img/arrow-" + dir + ".gif\' style=\'right:" + right + "px;top:" + top + "px\'>")\
			.appendTo(placeholder)\
			.click(function (e) {\
				e.preventDefault();\
				self.plot.pan(offset);\
			});\
		};\
		this.addZoomArrow = function(dir, right, top, placeholder) {\
			var self = this;\
			$("<img class=\'navbutton\' src=\'/img/arrow-" + dir + ".gif\' style=\'right:" + right + "px;top:" + top + "px\'>")\
			.appendTo(placeholder)\
			.click(function (e) {\
				e.preventDefault();\
				if (dir == "up") {\
					self.plot.zoom(100);\
				} else if (dir == "down") {\
					self.plot.zoomOut();\
				}\
			});\
		};\
		this.init = function() {\
			var self = this;\
			for (var i = 0; i < self.alarmImportanceSelect.length; i++) {\
				var importance = self.alarmImportanceSelect[i];\
				self.availableImportanceSelect().push(importance);\
			}\
			var html = \'<div class="span6">\';\
			var split = Math.floor(this.sections.length/2);\
			$.each(this.sections, function(key, section) {\
					html += \'<div id="\' + section.id + \'" data-bind="visible: shouldBeVisible(\\\'\'+ section.id + \'\\\')">\';\
					html += \'<h4 class="sigval-title">\' + section.title + \'</h4>\';\
					for (var k in section.params) {\
						var param = section.params[k];\
						self.observables[param.name] = ko.observable("");\
						var bind = param.name;\
						if (param.unit !== undefined) {\
							self.observables[param.name + \'_full\'] = function(param, unit) {\
								return self.observables[param]() + " " + unit;\
							};\
							bind += "_full(\'"+param.name+ "\',\'"+param.unit+"\')";\
						}\
						html += \'<div data-bind="visible: observables.\' + param.name + \'().length > 0" class="control-group">\';\
						html += \'<label class="control-label">\' + param.desc + \'</label>\';\
						html += \'<div class="controls">\';\
						html += \'<span class="simple-desc span5" data-bind="text: observables.\' + bind + \'"></span>\';\
						html += \'</div></div>\';\
					}\
					html += \'</div>\';\
					if (key % split == 0 && key != 0) {\
						html += \'</div><div class="span6">\';\
					}\
			});\
			$(\'#lte-doctor-values\').append(html);\
\
			var placeholder = $("#plot");\
			this.plot = $.plot(placeholder, this.getPlotData(), {\
				series: {\
					shadowSize: 0,\
					lines: {\
						show: true\
					},\
					points: {\
						show: false\
					}\
				},\
				legend: {\
					noColumns: 0,\
					container: $("#plot-legend")\
				},\
				grid: { hoverable: true, clickable: false },\
				yaxis: {\
					min: this.plotMinValue,\
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
					var y = item.datapoint[1].toFixed(2);\
					$("#plot-tooltip").html(y).css({top: item.pageY+5, left: item.pageX+5}).show();\
				} else {\
					$("#plot-tooltip").hide();\
				}\
			});\
\
			// Zooming with more than 100 doesn\'t seem to work\
			this.plot.zoom(100);\
			this.plot.zoom(100);\
			this.plot.zoom(100);\
			this.plot.pan({ left: 600 });\
			this.addPanArrow("left", 55, 60, { left: -100 }, placeholder);\
			this.addPanArrow("right", 25, 60, { left: 100 }, placeholder);\
			this.addZoomArrow("up", 40, 45, placeholder);\
			this.addZoomArrow("down", 40, 75, placeholder);\
\
			$(\'#plot-period\').on(\'change\', function() {\
				self.refresh();\
			});\
\
			$(".export").click(function() {\
				var export_type = "csv";\
				if (this.id == "export_data_json_btn") {\
					export_type = "json";\
				}\
				$.fileDownload($(".modal form").attr("action"), {\
					httpMethod: "POST",\
					data: new Array({ name : "action", value : "export_data" },\
									{ name : "export_type", value : export_type },\
									{ name : "dev_idx", value : ');  ngx.print( selected_device.info.dev_idx ); ngx.print(' },\
									{ name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") }),\
					prepareCallback: function() {\
						$("#export-failed-msg").addClass("hide");\
						var exporting_msg = $("#exporting-msg");\
						exporting_msg.removeClass("hide");\
						exporting_msg[0].scrollIntoView();\
					},\
					successCallback: function() {\
						$("#exporting-msg").addClass("hide");\
					},\
					failCallback: function() {\
						var export_failed_msg = $("#export-failed-msg");\
						export_failed_msg.removeClass("hide");\
						export_failed_msg[0].scrollIntoView();\
						$("#exporting-msg").addClass("hide");\
					}\
				});\
				return false;\
			});\
\
			this.query.subscribe(this.search);\
			ko.applyBindings(this, document.getElementById(\'lte-doctor-values\'));\
			ko.applyBindings(this, document.getElementById(\'alarms-container\'));\
			ko.applyBindings(this, document.getElementById(\'stats-container\'));\
			ko.applyBindings(this, document.getElementById(\'plot-container\'));\
			this.refresh();\
		};\
	};\
\
	var id = window.setTimeout(function() {}, 0);\
	while (id--) {\
		window.clearTimeout(id);\
	}\
\
	var lteDoctor = new LteDoctor();\
	lteDoctor.init();\
</script>\
'); 