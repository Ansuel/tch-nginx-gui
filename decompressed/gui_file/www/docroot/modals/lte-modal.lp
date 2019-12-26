--pretranslated: do not change this file
 
local string, table, pairs = string, table, pairs
local ngx, tostring, tonumber, ipairs, setmetatable, tinsert = ngx, tostring, tonumber, ipairs, setmetatable, table.insert

-- Enable localization
-- NG-90744 TI-GUI : WWAN interface automatically enables itself when we disable
gettext.textdomain('webui-mobiled')

local proxy = require("datamodel")
local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local untaint_mt = require("web.taint").untaint_mt
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")

local getargs = ngx.req.get_uri_args()
local current_imei = getargs.imei

if ngx.req.get_method() == "POST"  then
	local args = ngx.req.get_post_args()
	local action = string.untaint(args["action"])
	if string.match(action, "^delete_uci_device_") then
		local paramindex = string.match(action, "^delete_uci_device_(.*)$")
		proxy.del("uci.mobiled.device." .. paramindex .. ".")
		proxy.apply()
		current_imei = nil
	end
end

local function imei_in_list(imei, devices)
	for _, device in pairs(devices) do
		if device.info.imei == imei then
			return true
		end
	end
	return false
end

local function get_by_imei(imei, devices)
	if imei then
		for _, device in pairs(devices) do
			if device.info.imei == imei then
				return device
			end
		end
	end
	return devices[1]
end

local function validate_in_enum_or_empty(enum)
	local choices = setmetatable({}, untaint_mt)

	-- store that as a dictionnary, will make it simpler
	for _,v in ipairs(enum) do
		choices[v[1]] = true
	end

	return function(value)
		if value == "" then return true end
		return choices[value], T"Invalid value"
	end
end

local function validate_bands(value)
	if value == "" or string.match(value, "^[%d ]+$") then
		return true
	end
	return nil
end

local function get_profile_select(device)
	local names = {}
	local authentications = {}

	if device and device.active then
		local info = {
			reuse_profiles = device.uci_path .. "reuse_profiles"
		}
		content_helper.getExactContent(info)
		if info and info.reuse_profiles == "1" then
			local profiles = content_helper.getMatchedContent(device.rpc_path .. "profile.")
			for _, profile in ipairs(profiles) do
				tinsert(names, { "device:" .. string.untaint(profile.id), string.untaint(profile.name) })
				authentications["device:" .. string.untaint(profile.id)] = string.untaint(profile.authentication)
			end
			return names, authentications
		end
	end

	local profiles = content_helper.getMatchedContent("uci.mobiled.profile.")
	for _, profile in ipairs(profiles) do
		tinsert(names, { string.untaint(profile.id), string.untaint(profile.name) })
		authentications[string.untaint(profile.id)] = string.untaint(profile.authentication)
	end

	return names, authentications
end

local function get_device_data(dev_idx)
	local rpc_path = string.format("rpc.mobiled.device.@%d.", dev_idx)
	local device = {
		active = true,
		rpc_path = rpc_path,
		uci_path = utils.get_uci_device_path()
	}

	device.capabilities = utils.getContent(rpc_path .. "capabilities.")
	if not device.capabilities then return nil end
	device.capabilities.max_data_sessions = tonumber(device.capabilities.max_data_sessions) or 0

	-- Convert the supported_auth_types field from a space-separated string of supported
	-- auth types to a table with a key that maps to true for each supported auth type.
	if device.capabilities.supported_auth_types then
		local supported_auth_types = {}
		for supported_auth_type in device.capabilities.supported_auth_types:gmatch("%S+") do
			supported_auth_types[supported_auth_type] = true
		end
		device.capabilities.supported_auth_types = supported_auth_types
	end

	device.radio_preferences = {}
	local num_radio_preferences = tonumber(utils.getContent(rpc_path)["RadioPreferenceNumberOfEntries"])
	if num_radio_preferences and num_radio_preferences > 0 then
		for i=1, num_radio_preferences do
			local radio_preference = utils.getContent(string.format("%sradio_preference.@%d.", rpc_path, i))
			if not radio_preference then return nil end
			table.insert(device.radio_preferences, radio_preference)
		end
	end

	device.info = utils.getContent(rpc_path .. "info.")
	if not device.info then return nil end

	device.status = utils.getContent(rpc_path .. "display_status")
	if not device.status then return nil end

	if not device.info.model or device.info.model == "" then device.info.model = T"Unknown" end

	return device
end

local function get_platform_data()
	local platform = {
		capabilities = {},
		info = {}
	}
	local antennaControls = tonumber(utils.getContent("rpc.mobiled.platform.capabilities.")["AntennaControlNumberOfEntries"])
	if antennaControls and antennaControls > 0 then
		platform.capabilities.antenna_controls = { utils.getContent("rpc.mobiled.platform.capabilities.antenna_control.@1.") }
	end
	antennaControls = tonumber(utils.getContent("rpc.mobiled.platform.info.")["AntennaControlNumberOfEntries"])
	if antennaControls and antennaControls > 0 then
		platform.info.antenna_controls = { utils.getContent("rpc.mobiled.platform.info.antenna_control.@1.") }
	end
	return platform
end

local function get_lte_band_selection_section(page, html)
	if page and page.mapParams["lte_bands"] then
		tinsert(html, '<div class="control-group"><label class="control-label">' .. T"Allowed LTE Bands" .. ':</label><div class="controls">')
		tinsert(html, '<select data-placeholder="'..T'Choose A Band'..'" class="span3" id="lte_bands_pref" multiple>')
		tinsert(html, '<option value=""></option>')
		for _, v in pairs(page.lte_band_select) do
			if utils.isTableValue(page.lte_band_selected, v[1]) then
				tinsert(html, '<option selected value="' .. v[1] .. '">' .. v[1] .. '</option>')
			else
				tinsert(html, '<option value="' .. v[1] .. '">' .. v[1] .. '</option>')
			end
		end
		tinsert(html, '</select></div></div>')
		tinsert(html, '<input type="text" name="lte_bands" style="display: none;"/>')
	end
end

local function get_radio_selection_section(page, html)
	if page then
		if utils.Len(page.radio_select) > 1 then
			tinsert(html, ui_helper.createInputSelect(T"Access Technology" .. ":", "radio_pref", page.radio_select, page.content["radio_pref"]))
		elseif utils.Len(page.radio_select) == 1 then
			local _, v = next(page.radio_select)
			local val = {}
			val["data-radio_pref"] = tostring(v[1])
			val["id"] = "radio_pref"
			tinsert(html, ui_helper.createLabel(T"Radio Type" .. ":", tostring(v[2]), { span = val }))
		end
	end
end

local function get_antenna_selection_section(page, html)
	if page.platform.capabilities.antenna_controls and page.platform.info.antenna_controls then
		local advanced = {
			group = {
				class = "advanced hide"
			},
			span = {
				class = "span5"
			}
		}
		tinsert(html, ui_helper.createInputSelect(T"Antenna Selection"..':', "selected_antenna", page.antenna_select, page.content["selected_antenna"], advanced))
		if page.content["selected_antenna"] == "auto" then
			if page.platform and page.platform.info then
				local val = {}
				val["id"] = "current_antenna"
				tinsert(html, ui_helper.createLabel(T"Selected Antenna" .. ":", utils.antenna_map[page.platform.info.antenna_controls[1].current_antenna], { group = { class = "advanced hide" }, span = val }))
			end
		end
	end
end

local function get_network_interface_section(page, html)
	local interfaces_columns = {
		{
			header = T"Interface",
			name = "paramindex",
			param = "paramindex",
			type = "label",
			readonly = true,
			attr = { input = { class="span2" } },
		},
		{
			header = T"Linked Profile",
			name = "profile",
			param = "profile",
			type = "select",
			values = page.profiles_select,
			attr = { select = { class="span2" } }
		},
		{
			header = T"Connect",
			name = "auto",
			param = "auto",
			type = "switch",
			default = "1",
			attr = { switch = { ["data-placement"] = "right" }}
		}
	}

	local interfaces_options = {
		tableid = "lte_interfaces",
		basepath = "uci.network.interface.@.",
		canAdd = false,
		canDelete = false
	}

	if proxy.get("uci.wansensing.global.enable")[1].value == "1" then
		interfaces_options.canEdit = false
	end

	local function interfaces_filter(data)
		if page.device then
			if data.proto ~= "mobiled" then return false end
			local session_id = tonumber(data.session_id)
			if not session_id or session_id > (page.device.capabilities.max_data_sessions-1) then return false end
			return true
		end
		return false
	end

	local interfaces_data, interfaces_helpmsg = post_helper.handleTableQuery(interfaces_columns, interfaces_options, interfaces_filter, nil, {})
	for _, intf in pairs(interfaces_data) do
		if string.format("%s", intf[3]) == "" then
			intf[3] = "1"
		end
	end

	if utils.Len(interfaces_data) > 0 then
		local authentication_warning = {
			alert = {
				id = "profile_auth_warning",
				class = "alert-warning",
				style = "display: none;"
			}
		}
		if page.device.capabilities.supported_auth_types then
			for _, interface_data in pairs(interfaces_data) do
				local authentication = page.profile_authentications[string.untaint(interface_data[2])]
				if not authentication or not page.device.capabilities.supported_auth_types[authentication] then
					authentication_warning.alert.style = nil
					break
				end
			end
		end
		tinsert(html, "<fieldset><legend>" .. T"Interfaces" .. "</legend>")
		tinsert(html, ui_helper.createAlertBlock(T"The device does not support the authentication of the selected profile.", authentication_warning))
		tinsert(html, ui_helper.createTable(interfaces_columns, interfaces_data, interfaces_options, nil, interfaces_helpmsg))
		tinsert(html, "</fieldset>")
	end
end

local function get_device_info_section(page, html)
	local advanced = {
		group = {
			class = "advanced hide"
		},
		span = {
			class = "span5"
		}
	}
	local section = {}
	if page.device.info.imei ~= "" then
		tinsert(section, ui_helper.createLabel(T"IMEI" .. ":", page.device.info.imei))
	end
	-- Advanced parameters
	if  page.device.info.manufacturer ~= "" then
		tinsert(section, ui_helper.createLabel(T"Manufacturer" .. ":", page.device.info.manufacturer, advanced))
	end
	if page.device.info.model ~= "" then
		tinsert(section, ui_helper.createLabel(T"Model" .. ":", page.device.info.model, advanced))
	end
	if page.device.info.software_version ~= "" then
		tinsert(section, ui_helper.createLabel(T"Firmware Version" .. ":", page.device.info.software_version, advanced))
	end
	if page.device.info.hardware_version ~= "" then
		tinsert(section, ui_helper.createLabel(T"Hardware Version" .. ":", page.device.info.hardware_version, advanced))
	end
	if page.device.info.temperature ~= "" then
		tinsert(section, ui_helper.createLabel(T"Temperature" .. ":", page.device.info.temperature.." ".."°C", advanced))
	end
	if page.device.info.power_mode ~= "" then
		tinsert(section, ui_helper.createLabel(T"Power Mode" .. ":", utils.power_mode_map[page.device.info.power_mode], advanced))
	end

	if utils.Len(section) > 0 then
		tinsert(html, "<fieldset><legend>" .. T"Device Information" .. "</legend>")
		tinsert(html, section)
		tinsert(html, "</fieldset>")
	end
end

local function get_session_info_section(page, html)
	for i = 1, page.device.capabilities.max_data_sessions do
		local section = {}
		local sessionInfo = utils.getContent(page.device.rpc_path .. "network.sessions.@" .. i .. ".")
		if sessionInfo.session_state ~= "" then
			tinsert(section, ui_helper.createLabel(T"Status" .. ":", utils.session_state_map[sessionInfo.session_state]))
		end
		if sessionInfo.ipv4_addr ~= "" then
			tinsert(section, ui_helper.createLabel(T"IPv4 Address" .. ":", sessionInfo.ipv4_addr))
		end
		if sessionInfo.ipv4_dns1 ~= "" then
			tinsert(section, ui_helper.createLabel(T"IPv4 Primary DNS" .. ":", sessionInfo.ipv4_dns1))
		end
		if sessionInfo.ipv4_dns2 ~= "" then
			tinsert(section, ui_helper.createLabel(T"IPv4 Secondary DNS" .. ":", sessionInfo.ipv4_dns2))
		end
		if sessionInfo.ipv6_addr ~= "" then
			tinsert(section, ui_helper.createLabel(T"IPv6 Address" .. ":", sessionInfo.ipv6_addr))
		end
		if sessionInfo.duration ~= "" then
			tinsert(section, ui_helper.createLabel(T"Session Duration" .. ":", sessionInfo.duration..' '..T"seconds"))
		end
		if sessionInfo.tx_bytes ~= "" then
			tinsert(section, ui_helper.createLabel(T"Tx Bytes" .. ":", sessionInfo.tx_bytes))
		end
		if sessionInfo.rx_bytes ~= "" then
			tinsert(section, ui_helper.createLabel(T"Rx Bytes" .. ":", sessionInfo.rx_bytes))
		end
		if sessionInfo.tx_packets ~= "" then
			tinsert(section, ui_helper.createLabel(T"Tx Packets" .. ":", sessionInfo.tx_packets))
		end
		if sessionInfo.rx_packets ~= "" then
			tinsert(section, ui_helper.createLabel(T"Rx Packets" .. ":", sessionInfo.rx_packets))
		end
		if sessionInfo.tx_packets_error ~= "" then
			tinsert(section, ui_helper.createLabel(T"Tx Packet Errors" .. ":", sessionInfo.tx_packets_error))
		end
		if sessionInfo.rx_packets_error ~= "" then
			tinsert(section, ui_helper.createLabel(T"Rx Packet Errors" .. ":", sessionInfo.rx_packets_error))
		end

		if utils.Len(section) > 0 then
			if sessionInfo.profile ~= "" then
				if sessionInfo.interface ~= "" then
					tinsert(html, '<fieldset class="profileinfo"><legend>' .. T'Interface' .. ' ' .. sessionInfo.interface .. '</legend>')
				elseif sessionInfo.apn ~= "" then
					tinsert(html, '<fieldset class="profileinfo"><legend>' .. T'PDN' .. ' ' .. sessionInfo.apn .. '</legend>')
				else
					tinsert(html, '<fieldset class="profileinfo"><legend>' .. T'PDN' .. '</legend>')
				end
				tinsert(html, section)
				tinsert(html, "</fieldset>")
			end
		end
	end
end

local function add_uci_devices(devices)
	local path = 'uci.mobiled.device.'
	local num_uci_devices = 0
	local uci_device_data = content_helper.convertResultToObject(path, proxy.get(path))
	for _, device in pairs(uci_device_data) do
		if not imei_in_list(device.imei, devices) then
			local uci_device = {
				active = false,
				paramindex = device.paramindex,
				uci_path = path .. device.paramindex .. '.',
				capabilities = {},
				radio_preferences = {},
				info = {
					model = string.untaint(device.model),
					imei = string.untaint(device.imei)
				},
				settings = {
					mcc = string.untaint(device.mcc),
					mnc = string.untaint(device.mnc),
					enabled = string.untaint(device.enabled),
					roaming = string.untaint(device.roaming),
					radio_pref = string.untaint(device.radio_pref),
					reuse_profiles = string.untaint(device.reuse_profiles),
					network_selection = string.untaint(device.network_selection)
				}
			}
			if uci_device.info.mcc == "" then uci_device.info.mcc = nil end
			if uci_device.info.mnc == "" then uci_device.info.mnc = nil end
			if not uci_device.info.model or uci_device.info.model == "" then uci_device.info.model = T"Unknown" end
			if not uci_device.settings.roaming or uci_device.settings.roaming == "" then uci_device.settings.roaming = "international" end
			if not uci_device.settings.reuse_profiles or uci_device.settings.reuse_profiles == "" then uci_device.settings.reuse_profiles = "0" end
			if not uci_device.settings.network_selection or uci_device.settings.network_selection == "" then uci_device.settings.network_selection = "auto" end
			table.insert(devices, uci_device)
			num_uci_devices = num_uci_devices + 1
		end
	end
	return num_uci_devices
end

local function get_page(platform, device)
	local p = {
		mapParams = {},
		mapValid = {
			reuse_profiles = post_helper.validateBoolean,
			interface_enabled = post_helper.validateBoolean
		},
		device = device,
		platform = platform,
		network_select = {
			{ "auto", utils.network_selection_map["auto"] },
			{ "manual", utils.network_selection_map["manual"] }
		},
		roaming_select = {
			{ "none", utils.roaming_map["none"] },
			{ "national", utils.roaming_map["national"] },
			{ "international", utils.roaming_map["international"] }
		},
		radio_select = {},
		lte_band_select = {},
		lte_band_selected = {}
	}

	p.profiles_select, p.profile_authentications = get_profile_select(device)

	if type(device) == "table" and device.active then
		p.mapParams["interface_enabled"] = device.uci_path .. "enabled"
		p.mapParams["reuse_profiles"] = device.uci_path .. "reuse_profiles"

		p.mapParams["roaming"] = device.uci_path .. "roaming"
		p.mapValid["roaming"] = validate_in_enum_or_empty(p.roaming_select)

		for _, radio_preference in ipairs(device.radio_preferences) do
			if utils.radio_preference_map[radio_preference.name] ~= "" then
				tinsert(p.radio_select, { radio_preference.radios, utils.radio_preference_map[radio_preference.name] })
			end
		end

		for band in device.capabilities.supported_bands_lte:gmatch("%S+") do
			tinsert(p.lte_band_select, { band, band })
		end

		if string.match(device.capabilities.band_selection_support, "lte") then
			p.mapParams["lte_bands"] = device.uci_path .. "lte_bands"
			p.mapValid["lte_bands"] = validate_bands
		end

		if device.capabilities.manual_plmn_selection == "true" then
			p.mapParams["network_selection"] = device.uci_path .. "network_selection"
			p.mapValid["network_selection"] = post_helper.getValidateInEnumSelect(p.network_select)
		end

		if utils.Len(p.radio_select) > 1 then
			p.mapParams["radio_pref"] = device.uci_path .. "radio_pref"
			p.mapValid["radio_pref"] = post_helper.getValidateInEnumSelect(p.radio_select)
		end
	end

	if type(platform) == "table" then
		if platform.capabilities.antenna_controls then
			p.antenna_select = {}
			for k, v in pairs(utils.antenna_map) do
				table.insert(p.antenna_select, {k, v})
			end
			p.mapParams["selected_antenna"] = "uci.mobiled.platform.antenna"
			p.mapValid["selected_antenna"] = validate_in_enum_or_empty(p.antenna_select)
		end
	end

	p.content, p.helpmsg = post_helper.handleQuery(p.mapParams, p.mapValid)
	setmetatable(p.content, { __index = function() return "" end })

	for band in p.content["lte_bands"]:gmatch("%w+") do
		tinsert(p.lte_band_selected, band)
	end

	return p
end

local mobiled = {
	num_devices = "rpc.mobiled.DeviceNumberOfEntries"
}
content_helper.getExactContent(mobiled)

mobiled.devices = {}
mobiled.num_devices = tonumber(mobiled.num_devices)
if mobiled.num_devices and mobiled.num_devices >= 1 then
	for dev_idx=1,mobiled.num_devices do
		mobiled.devices[dev_idx] = get_device_data(dev_idx)
	end
end
mobiled.num_uci_devices = add_uci_devices(mobiled.devices)
local page = get_page(get_platform_data(), get_by_imei(current_imei, mobiled.devices))

  ngx.print('\
\
<link href="/css/chosen.css" rel="stylesheet">\
<script language="javascript" type="text/javascript" src="js/chosen-min.js"></script>\
\
<style>\
	.uneven {\
		background-color: #eee;\
	}\
	.selectable {\
		cursor: pointer;\
		cursor: hand;\
	}\
	.selectable:hover {\
		background-color: #aaa;\
	}\
	.currentplmn {\
		background-color: #5d215d;\
		color: #fff;\
	}\
	#scanresults {\
		margin-bottom: 15px;\
	}\
	.scanresult {\
		border-bottom: 1px solid #aaa;\
		line-height: 30px;\
	}\
	.scanresult-title {\
		font-weight: bold;\
		border-bottom: 2px solid #888;\
	}\
	.img-center {\
		margin: 0 auto;\
		display: block;\
	}\
	.waiting-msg {\
		color: #777;\
	}\
	.float-left {\
		float: left;\
		margin-right: 5px;\
	}\
	.help-inline {\
		min-width: 350px;\
	}\
</style>\
\
');  
	local params = utils.get_params()
	ngx.print(ui_helper.createHeader(params.modal_title, true, true, nil))
  ngx.print('\
\
<div class="modal-body update" id="lte-body">\
	<form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
		');  
			local lp = require("web.lp")
			lp.setpath("/www/snippets/")
			lp.include("tabs-mobiled.lp")

			if not page or not page.device then
				ngx.print(ui_helper.createAlertBlock(utils.string_map["no_device"]))
				ngx.print("</form></div>")
				ngx.print(ui_helper.createFooter())
				message_helper.popMessages()
				ngx.exit(ngx.HTTP_OK)
			end

			local html = {}
			local advanced = {
				group = {
					class = "advanced hide"
				},
				span = {
					class = "span5"
				}
			}
			tinsert(html, '<div class="span2">')
			if mobiled.num_devices >= 1 then
				tinsert(html, string.format('<ul class="nav nav-list" id="active_devices"><li class="nav-header">%s</li>', T"Active Devices"))
				for _, device in pairs(mobiled.devices) do
					if device.active then
						local active = ""
						if device.info.imei == page.device.info.imei then
							active = "active"
						end
						local url = "modals/lte-modal.lp?imei=" .. device.info.imei
						tinsert(html, string.format('<li class="%s"><a href="#" data-remote="%s">%s</a></li>', active, url, device.info.model or device.info.imei))
					end
				end
				tinsert(html, '</ul>')
			end
			if mobiled.num_uci_devices >= 1 then
				tinsert(html, string.format('<ul class="nav nav-list" id="inactive_devices"><li class="nav-header">%s</li>', T"Inactive Devices"))
				for _, device in pairs(mobiled.devices) do
					if not device.active then
						local active = ""
						if device.info.imei == page.device.info.imei then
							active = "active"
						end
						local url = "modals/lte-modal.lp?imei=" .. device.info.imei
						tinsert(html, string.format('<li class="%s"><a href="#" data-remote="%s">%s</a></li>', active, url, device.info.model or device.info.imei))
					end
				end
				tinsert(html, '</ul>')
			end
			tinsert(html, '</div>')
			tinsert(html, '<div class="span8">')

			if not page.device.active then
				local warning = {
					alert = {
						class = "alert-info"
					}
				}
				tinsert(html, ui_helper.createAlertBlock(T"Editing not possible for inactive devices", warning))
				tinsert(html, ui_helper.createSwitch(T"Enabled" .. ":", "interface_enabled", page.device.settings.enabled, { switch = { class = "disabled" }}))
				tinsert(html, ui_helper.createLabel(T"Radio Type" .. ":", utils.radio_preference_map[page.device.settings.radio_pref]))
				tinsert(html, ui_helper.createSwitch(T"Use Device Profiles" .. ":", "reuse_profiles", page.device.settings.reuse_profiles, { switch = { class = "disabled" }}))
				tinsert(html, ui_helper.createLabel(T"Allow Roaming" .. ":", utils.roaming_map[page.device.settings.roaming]))
				tinsert(html, ui_helper.createLabel(T"Network Selection" .. ":", utils.network_selection_map[page.device.settings.network_selection]))
				if page.device.settings.network_selection == "manual" and page.device.settings.mcc and page.device.settings.mnc then
					tinsert(html, ui_helper.createLabel(T"MCC" .. ":", page.device.settings.mcc))
					tinsert(html, ui_helper.createLabel(T"MNC" .. ":", page.device.settings.mnc))
				end
				local remove_uci_device_class = {
					button = {
						["data-name"] = "action",
						["data-value"] = "delete_uci_device_" .. page.device.paramindex
					}
				}
				tinsert(html, ui_helper.createButton(T"Remove Settings" .. ":", "", "icon-trash", remove_uci_device_class))
				tinsert(html, "</div></form></div>")
				tinsert(html, ui_helper.createFooter())
				ngx.print(html)
				message_helper.popMessages()
				ngx.exit(ngx.HTTP_OK)
			end

			tinsert(html, "<fieldset><legend>" .. T"Device Status And Settings" .. "</legend>")
			tinsert(html, ui_helper.createMessages(message_helper.popMessages()))

			tinsert(html, ui_helper.createSwitch(T"Enabled" .. ":", "interface_enabled", page.content["interface_enabled"]))
			tinsert(html, ui_helper.createSwitch(T"Use Device Profiles" .. ":", "reuse_profiles", page.content["reuse_profiles"]))
			tinsert(html, ui_helper.createInputSelect(T"Allow Roaming" .. ":", "roaming", page.roaming_select, page.content["roaming"]))

			if utils.mobiled_state_map[page.device.status.display_status] ~= "" then
				tinsert(html, ui_helper.createLabel(T"Device Status" .. ":", utils.mobiled_state_map[page.device.status.display_status]))
			end

			get_radio_selection_section(page, html)
			get_lte_band_selection_section(page, html)

			if page.device.capabilities.manual_plmn_selection == "true" then
				tinsert(html, ui_helper.createInputSelect(T"Network Selection"..':', "network_selection", page.network_select, page.content["network_selection"], advanced))
			end

			get_antenna_selection_section(page, html)

			tinsert(html, "</fieldset>")

			ngx.print(html)
			  ngx.print('\
			<fieldset class="advanced hide">\
				<legend>');  ngx.print( T"Network Scan" ); ngx.print('</legend>\
				<div data-bind="visible: scanInProgress() != true">\
					<button data-bind="click: startNetworkScan" id="startscan" type="button" class="btn btn-default btn-lg advanced hide">\
						<span class="glyphicon glyphicon-eye-open"></span>');  ngx.print( T"Scan Networks" ); ngx.print('\
					</button>\
				</div>\
				<h4 data-bind="text: scanMessage" class="text-center waiting-msg"></h4>\
				<div data-bind="visible: scanInProgress">\
					<img class="img-center" src="img/networkscan-loader.gif"></img>\
				</div>\
				<div class="row-fluid" data-bind="visible: scanDuration() == 0 && scanResults().length > 0">\
					<div class="span12" >\
						<h4 class="waiting-msg">');  ngx.print( T"Previous network scan results" ); ngx.print('</h4>\
					</div>\
				</div>\
				<div data-bind="visible: scanResults().length > 0">\
					<div class="row-fluid scanresult-title hidden-phone">\
						<div class="span2">');  ngx.print( T"Description" ); ngx.print('</div>\
						<div class="span1">');  ngx.print( T"MCC" ); ngx.print('</div>\
						<div class="span1">');  ngx.print( T"MNC" ); ngx.print('</div>\
						<div class="span1">');  ngx.print( T"Preferred" ); ngx.print('</div>\
						<div class="span1">');  ngx.print( T"Forbidden" ); ngx.print('</div>\
						<div class="span1">');  ngx.print( T"In use" ); ngx.print('</div>\
						<div class="span2">');  ngx.print( T"Radio Technology" ); ngx.print('</div>\
						<div class="span3"></div>\
					</div>\
					<div id="scanresults">\
						<div data-bind="foreach: scanResults">\
							<div class="row-fluid scanresult" data-bind="css: { \'uneven\': ($index() % 2), \'selectable\': lteModal.manualPlmnSelection(), \'currentplmn\': lteModal.currentMnc() == $data.mnc && lteModal.currentMcc() == $data.mcc}, click: $parent.selectPlmn">\
								<div class="span2" data-bind="text: description"></div>\
								<div class="span1" data-bind="text: mcc"></div>\
								<div class="span1" data-bind="text: mnc"></div>\
								<div class="span1" data-bind="text: $parent.yesNoVal(preferred)"></div>\
								<div class="span1" data-bind="text: $parent.yesNoVal(forbidden)"></div>\
								<div class="span1" data-bind="text: $parent.yesNoVal(used)"></div>\
								<div class="span2" data-bind="text: radio_interface"></div>\
								<div class="span3"></div>\
							</div>\
						</div>\
						<div class="row-fluid" data-bind="visible: scanDuration() > 0">\
							<div class="span12" >\
								<span>');  ngx.print( T"Scan completed after" ); ngx.print('</span>\
								<span data-bind="text: scanDuration"></span>\
								<span>');  ngx.print( T"seconds" ); ngx.print('</span>\
							</div>\
						</div>\
					</div>\
				</div>\
			</fieldset>\
			');  
			html = {}
			get_network_interface_section(page, html)
			get_session_info_section(page, html)
			get_device_info_section(page, html)
			tinsert(html, '</div>')
			ngx.print(html)
		  ngx.print('\
	</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
	var id = window.setTimeout(function() {}, 0);\
	while (id--) {\
		window.clearTimeout(id);\
	}\
\
	ko.cleanNode(document.getElementById(\'lte-body\'));\
\
	function sortResults(obj, prop, asc) {\
		obj = obj.sort(function(a, b) {\
			if (asc) return (a[prop] > b[prop]) ? 1 : ((a[prop] < b[prop]) ? -1 : 0);\
			else return (b[prop] > a[prop]) ? 1 : ((b[prop] < a[prop]) ? -1 : 0);\
		});\
		return obj;\
	}\
\
	function updateBandPref() {\
		var bandStr = "";\
		$("#lte_bands_pref > option:selected").each(function() {\
			if(bandStr != "") {\
				bandStr += \' \';\
			}\
			bandStr += $(this).val();\
		});\
		$("input[name=\'lte_bands\']").val(bandStr);\
	}\
\
	function getScanStatus() {\
		$.post("/ajax/networkscan.lua", [ tch.elementCSRFtoken() ], function(data) {\
			if(data.scanning == "false" || data.error != undefined) {\
				lteModal.scanDuration(parseInt(data.duration));\
				lteModal.getScanResults();\
			} else {\
				// Let\'s check again in 10 seconds if the scan completed\
				setTimeout(getScanStatus, (10*1000));\
			}\
		}, "json");\
	}\
\
	var LteModal = function () {\
		var self = this;\
		this.currentMnc = ko.observable(0);\
		this.currentMcc = ko.observable(0);\
		this.manualPlmnSelection = ko.observable(false);\
		this.scanDuration = ko.observable(0);\
		this.scanMessage = ko.observable("");\
		this.scanInProgress = ko.observable(false);\
		this.scanResults = ko.observableArray([]);\
		this.startNetworkScan = function() {\
			self.scanResults([]);\
			self.scanInProgress(true);\
			var scanStatus = setTimeout(getScanStatus, (10*1000));\
			var params = [ { name: \'action\', value: "scan" }, tch.elementCSRFtoken() ];\
			self.scanMessage("');  ngx.print( T"Scanning for networks, please wait. This can take a few minutes..." ); ngx.print('");\
			$.post("/ajax/networkscan.lua", params, function(data) {\
				if(data.scanning == "false" || data.error != undefined) {\
					self.scanInProgress(false);\
					clearTimeout(scanStatus);\
				}\
			}, "json");\
		};\
		this.resumeNetworkScan = function() {\
			var params = [ tch.elementCSRFtoken() ];\
			$.post("/ajax/networkscan.lua", params, function(data) {\
				if(data.scanning == "true") {\
					self.scanInProgress(true);\
					setTimeout(getScanStatus, (10*1000));\
					self.scanMessage("');  ngx.print( T"Scanning for networks, please wait. This can take a few minutes..." ); ngx.print('");\
				}\
			}, "json");\
		};\
		this.yesNoVal = function(val) {\
			if(val == "1" || val == "true") {\
				return "');  ngx.print( T"Yes" ); ngx.print('";\
			}\
			return "');  ngx.print( T"No" ); ngx.print('";\
		};\
		this.selectPlmn = function() {\
			if(self.manualPlmnSelection() == true) {\
				if(self.currentMnc() != this.mnc || self.currentMcc() != this.mcc) {\
					self.currentMnc(this.mnc);\
					self.currentMcc(this.mcc);\
					var params = [  { name: \'action\', value: "selectplmn" },\
									{ name: \'mcc\', value: this.mcc },\
									{ name: \'mnc\', value: this.mnc },\
									tch.elementCSRFtoken() ];\
					$.post("/ajax/networkscan.lua", params);\
				}\
			}\
		};\
		this.getScanResults = function() {\
			// Get any previous scan results\
			var params = [ { name: \'action\', value: "getscanresults" }, tch.elementCSRFtoken() ];\
			$.post("/ajax/networkscan.lua", params, function(data) {\
				self.scanMessage("");\
				self.scanInProgress(false);\
				data = sortResults(data, "radio_interface", false);\
				if(data.length == 0) {\
					self.scanMessage("');  ngx.print( T"No network scan results" ); ngx.print('");\
				}\
				self.scanResults(data);\
			}, "json");\
		}\
	};\
\
	$("select[name=\'radio_pref\']").change(function() {\
		if(/\\blte\\b/.test($(this).val())) {\
			$(\'#lte_bands_pref\').parent().parent().show();\
			updateBandPref();\
		} else {\
			$(\'#lte_bands_pref\').parent().parent().hide();\
		}\
	});\
\
	$("#lte_bands_pref").change(function() {\
		updateBandPref();\
	});\
\
	$(\'#lte_bands_pref\').chosen({allow_single_deselect:true});\
\
	if(!/\\blte\\b/.test($("select[name=\'radio_pref\']").val()) && !/\\blte\\b/.test($(\'#radio_pref\').attr("data-radio_pref"))) {\
		$(\'#lte_bands_pref\').parent().parent().hide();\
	}\
\
	updateBandPref();\
\
	var lteModal = new LteModal();\
	ko.applyBindings(lteModal, document.getElementById(\'lte-body\'));\
\
	if($("select[name=\'network_selection\']").val() == \'manual\') {\
		lteModal.manualPlmnSelection(true);\
		var params = [ { name: \'action\', value: "getcurrentplmn" }, tch.elementCSRFtoken() ];\
		$.post("/ajax/networkscan.lua", params, function(data) {\
			lteModal.currentMnc(data.mnc);\
			lteModal.currentMcc(data.mcc);\
			lteModal.getScanResults();\
		}, "json");\
	} else {\
		lteModal.getScanResults();\
	}\
\
	$("select[name=\'network_selection\']").change(function() {\
		if($(this).val() == \'manual\') {\
			lteModal.manualPlmnSelection(true);\
			var params = [ { name: \'action\', value: "getcurrentplmn" }, tch.elementCSRFtoken() ];\
			$.post("/ajax/networkscan.lua", params, function(data) {\
				lteModal.currentMnc(data.mnc);\
				lteModal.currentMcc(data.mcc);\
			}, "json");\
		} else {\
			lteModal.manualPlmnSelection(false);\
		}\
	});\
\
	$("select[name=\'profile\']").change(function() {\
		var unsupported_profiles = [');  
			if page.device and page.device.capabilities.supported_auth_types then
				local separator = ""
				for profile_id, authentication in pairs(page.profile_authentications) do
					if not page.device.capabilities.supported_auth_types[authentication] then
						ngx.print(string.format('%s"%s"', separator, profile_id))
						separator = ", "
					end
				end
			end
		  ngx.print('];\
		if(unsupported_profiles.indexOf($(this).val()) === -1) {\
			$(\'#profile_auth_warning\').hide();\
		} else {\
			$(\'#profile_auth_warning\').show();\
		}\
	});\
\
	lteModal.resumeNetworkScan();\
</script>\
'); 