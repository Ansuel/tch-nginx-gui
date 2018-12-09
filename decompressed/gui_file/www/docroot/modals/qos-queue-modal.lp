--pretranslated: do not change this file

-- Localization
gettext.textdomain('webui-qos')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local uimessage_helper = require("web.uimessage_helper")
local proxy = require("datamodel")
local table, ipairs = table, ipairs
local format, gmatch = string.format, string.gmatch
local concat = table.concat

local uci_classgroup_content = {
    wan_queues = "uci.qos.classgroup.@TO_WAN.classes",
    lan_queues = "uci.qos.classgroup.@TO_LAN.classes",
	wlan_queues = "uci.qos.classgroup.@TO_WLAN.classes",
}

content_helper.getExactContent(uci_classgroup_content)

local function get_queue_data(queues_string)
    local queues = format("%s", queues_string)
    local queue_table, queue_options = {}, {}
    for q in gmatch(queues, "([^%s]+)") do
        queue_table[q] = true
        queue_options[#queue_options+1] = { q, q }
    end
    return queue_table, queue_options
end

local wan_queue_table, wan_queue_options = get_queue_data(uci_classgroup_content.wan_queues)
local lan_queue_table, lan_queue_options = get_queue_data(uci_classgroup_content.lan_queues)
local wlan_queue_table, wlan_queue_options = get_queue_data(uci_classgroup_content.wlan_queues)

-- Shortcuts to validation helpers to make lines shorter
local vNES = post_helper.validateNonEmptyString
local vB = post_helper.validateBoolean
local gVIC = post_helper.getValidateInCheckboxgroup
local gVIES = post_helper.getValidateInEnumSelect
local vPN = post_helper.validatePositiveNum
local gOV = post_helper.getOptionalValidation

local policy_options = {
      {"sp", T"Strict Priority"},
      {"wrr", T"Weighted Round Robin"},
      {"sp_wrr", T"Strict Priority and Weighted Round Robin"},
}

local trafficid_options = {}
for id=0,15,1 do
    trafficid_options[#trafficid_options+1] = { tostring(id), tostring(id) }
end

local mapParams = {
    wan_queues_enabled = "uci.qos.device.@ptm0.enable",
    wan_queues_policy = "uci.qos.classgroup.@TO_WAN.policy",
    wan_queues_default = "uci.qos.classgroup.@TO_WAN.default",
    lan_queues_enabled = "uci.qos.interface.@lan.enable",
    lan_queues_policy = "uci.qos.classgroup.@TO_LAN.policy",
    lan_queues_default = "uci.qos.classgroup.@TO_LAN.default",
	wlan_queues_policy = "uci.qos.classgroup.@TO_WLAN.policy",
    wlan_queues_default = "uci.qos.classgroup.@TO_WLAN.default",
}

local mapValid = {
    wan_queues_enabled = vB,
    wan_queues_policy = gVIES(policy_options),
    wan_queues_default = gVIES(wan_queue_options),
    lan_queues_enabled = vB,
    lan_queues_policy = gVIES(policy_options),
	lan_queues_default = gVIES(lan_queue_options),
	wlan_queues_policy = gVIES(policy_options),
	wlan_queues_default = gVIES(wlan_queue_options),
}

if not proxy.get(mapParams.wan_queues_enabled) then
	mapParams.wan_queues_enabled = "uci.qos.interface.@wan.enable"
end

local ethports = {}
local ethport_count = 0
for index = 0, 5 do
    local ethport = "eth" .. index
	local path = "uci.qos.device.@" .. ethport .. ".enable"
	local portname = T"Port" .. " " .. index+1
	if index == 5 then
		portname = T"Virtual Port" .. " Wifi 5Ghz"
	end
    if proxy.get(path) and not ( index == 4 ) then
        ethport_count = ethport_count + 1
        table.insert(ethports, {ethport, portname})
		mapParams[ethport] = path
    end
end

for i = 0, ethport_count do
    mapValid["eth" .. i] = gOV(vB)
end

local function isChecked(key, checked)
	if string.untaint(checked) == "" then
		return false
	end
	for _,v in ipairs(checked) do
		if v == key then
			return true
		end
	end
    return false
end

local function validateEthports(value, object, key)
    local getValidateEthports = gVIC(ethports)
    local ok, msg = getValidateEthports(value, object, key)

    if not ok then
        return ok, msg
    end

    for k,v in ipairs(ethports) do
        object[v[1]] = nil
        object[v[1]] = isChecked(v[1], value) and "1" or "0"
    end

    return true
end

local wldevices = {}
local wldevice_count = 0
for index = 0, 3 do
    local wldevice = "wl" .. index
	local path = "uci.qos.device.@" .. wldevice .. ".enable"
	local wlname = "uci.wireless.wifi-iface.@"..wldevice..".ssid"
	if index == 2 then
		wldevice = "wlnet_b_24" --cover guest wifi
		path = "uci.qos.interface.@" .. wldevice .. ".enable"
		wlname = "uci.wireless.wifi-iface.@wl0_1.ssid"
	elseif index == 3 then
		wldevice = "wlnet_b_5"
		path = "uci.qos.interface.@" .. wldevice .. ".enable"
		wlname = "uci.wireless.wifi-iface.@wl1_1.ssid"
	end
    if proxy.get(path) then
		wlname = proxy.get(wlname) and proxy.get(wlname)[1].value or wldevice
        wldevice_count = wldevice_count + 1
        table.insert(wldevices, {wldevice, wlname})
		mapParams[wldevice] = path
    end
end

for _ , value in pairs(wldevices) do
    mapValid[value[1]] = gOV(vB)
end

local function validateWlDevice(value, object, key)
    local getValidateWlDevices = gVIC(wldevices)
    local ok, msg = getValidateWlDevices(value, object, key)

    if not ok then
        return ok, msg
    end

    for k,v in ipairs(wldevices) do
        object[v[1]] = nil
        object[v[1]] = isChecked(v[1], value) and "1" or "0"
    end

    return true
end

if not proxy.get(mapParams.lan_queues_enabled) then
	mapParams.lan_queues_enabled = nil
	mapValid.lan_queues_enabled = nil
	mapValid.ethports = validateEthports
end

mapValid.wldevices = validateWlDevice
	
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

for i = 0, wldevice_count do
	if content["wl" .. i] == "" then
		content["wl" .. i] = "1"
	end
end

for i = 0, ethport_count do
    if content["eth" .. i] == "" then
		content["eth" .. i] = "1"
	end
end

if content.wan_queues_enabled == "" then
    content.wan_queues_enabled = "0"
end

-- queue table
local classes_columns = {
  { --1
    header = T"Name",
    name = "class_name",
    param = "paramindex",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  { --2
    header = T"Priority",
    name = "priority",
    param = "priority",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --3
    header = T"Weight",
    name = "weight",
    param = "weight",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --4
    header = T"Traffic ID",
    name = "trafficid",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --5
    header = "",
    legend = T"QoS Queue Table on Interface WAN",
    name = "wan_queues",
    type = "aggregate",
    synthesis = nil, --tod_aggregate,
    subcolumns = {
      {
        header = T"Priority",
        name = "priority",
        param = "priority",
        type = "text",
        attr = { input = { class="span2" } },
      },
      {
        header = T"Weight",
        name = "weight",
        param = "weight",
        type = "text",
        attr = { input = { class="span2" } },
      },
      {
        header = T"Traffic ID",
        name = "trafficid",
        param = "trafficid",
        type = "checkboxgroup",
        values = trafficid_options,
        attr = { checkbox = { class="inline" } },
      },
    },
  }, --[5]
  { --6
    header = T"Default",
    name = "default_queue",
    type = "text",
    readonly = true,
  },
}

local function validateWeight(value)
    if value == "" then
        return true
    end
    return vPN(value)
end

local classes_valid = {
    priority = vPN,
    weight = validateWeight,
    trafficid = gVIC(trafficid_options),
}

local wan_classes_options = {
    tableid = "wan_classes",
    basepath = "uci.qos.class.@.",
    createMsg = T"Add new queue",
    canAdd = false,
    canDelete = false,
    sorted = "paramindex",
}

local function wan_classes_filter(data)
    return wan_queue_table[data["paramindex"]]
end

local wan_classes_data, wan_classes_helpmsg = post_helper.handleTableQuery(classes_columns, wan_classes_options, wan_classes_filter, nil, classes_valid)


local lan_classes_options = {
    tableid = "lan_classes",
    basepath = "uci.qos.class.@.",
    createMsg = T"Add new queue",
    canAdd = false,
    canDelete = false,
    sorted = "paramindex",
}

local function lan_classes_filter(data)
    return lan_queue_table[data["paramindex"]]
end

local lan_classes_data, lan_classes_helpmsg = post_helper.handleTableQuery(classes_columns, lan_classes_options, lan_classes_filter, nil, classes_valid)

local wlan_classes_options = {
    tableid = "wlan_classes",
    basepath = "uci.qos.class.@.",
    createMsg = T"Add new queue",
    canAdd = false,
    canDelete = false,
    sorted = "paramindex",
}

local function wlan_classes_filter(data)
    return wlan_queue_table[data["paramindex"]]
end

local wlan_classes_data, wlan_classes_helpmsg = post_helper.handleTableQuery(classes_columns, wlan_classes_options, wlan_classes_filter, nil, classes_valid)

local function post_data_process(classes_data, queues_default)
    for _,v in ipairs(classes_data) do
        v[4] = concat(v[5][3],",")
        if v[1] == queues_default then
            v[6] = "Yes"
        else
            v[6] = "-"
        end
    end
end

local ethports_checked = {}
if type(content) == "table" then
    for _,v in ipairs(ethports) do
        if (content[v[1]] == "1") then
            ethports_checked[#ethports_checked + 1] = v[1]
        end
    end
end

local wldevices_checked = {}
if type(content) == "table" then
    for _,v in ipairs(wldevices) do
        if (content[v[1]] == "1") then
            wldevices_checked[#wldevices_checked + 1] = v[1]
        end
    end
end

post_data_process(wan_classes_data, content.wan_queues_default)
post_data_process(lan_classes_data, content.lan_queues_default)
post_data_process(wlan_classes_data, content.wlan_queues_default)

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end

ngx.print( ui_helper.createHeader(T"QoS", false, true) ); ngx.print('\
<div class="modal-body update">\
  ')
    local tabs = {
        {
            desc = T"Queue",
            target = "modals/qos-queue-modal.lp",
            active = "active",
        },
        {
            desc = T"Classification",
            target = "modals/qos-classify-modal.lp",
        },
    }
    ngx.print(ui_helper.createModalTabs(tabs))
	
  ngx.print('\
  <form class="form-horizontal" method="post" action="'); ngx.print(uri); ngx.print('">\
  '); ngx.print( ui_helper.createMessages(uimessage_helper.popMessages()) )
	local html = {}
	
    html[#html+1] = "<fieldset>"
    html[#html+1] =   "<legend>" ..  T"QoS Queue Scheduling on Interface WAN".."</legend>"

    html[#html+1] =     ui_helper.createSwitch(T"Enabled", "wan_queues_enabled", content["wan_queues_enabled"])
    html[#html+1] =     ui_helper.createInputSelect(T"Algorithm", "wan_queues_policy", policy_options, content["wan_queues_policy"])
    html[#html+1] =     ui_helper.createInputSelect(T"Default Queue", "wan_queues_default", wan_queue_options, content["wan_queues_default"])

    html[#html+1] =   "<legend>" .. T"QoS Queue Table on Interface WAN" .. "</legend>"
	html[#html+1] =   	ui_helper.createTable(classes_columns, wan_classes_data, wan_classes_options, nil, wan_classes_helpmsg)
    html[#html+1] = "</fieldset>"
	
    html[#html+1] = "<fieldset>"
    html[#html+1] =   "<legend>"..T"QoS Queue Scheduling on Interface LAN".."</legend>"
	
	if content["lan_queues_enabled"] then
		html[#html+1] =     ui_helper.createSwitch(T"Enabled", "lan_queues_enabled", content["lan_queues_enabled"])
	elseif proxy.get("uci.qos.device.@eth0.enable") then
		html[#html + 1] = ui_helper.createCheckboxGroup(T"Qos Port Status", "ethports", ethports, ethports_checked, {checkbox = { class="inline" }}, nil)
	end
    html[#html+1] =     ui_helper.createInputSelect(T"Algorithm", "lan_queues_policy", policy_options, content["lan_queues_policy"])
    html[#html+1] =     ui_helper.createInputSelect(T"Default Queue", "lan_queues_default", lan_queue_options, content["lan_queues_default"])

    html[#html+1] = "</fieldset>"
    html[#html+1] = "<fieldset>"
    html[#html+1] =   "<legend>".. T"QoS Queue Table on Interface LAN".."</legend>"

    --legend = T"QoS Queue Table on Interface WAN"
    --is hardcoded in 'classes_columns',but for LAN edit panel, should be "QoS Queue Table on Interface LAN", change here
    classes_columns[5]["legend"] = T"QoS Queue Table on Interface LAN"
	
    html[#html+1] =   	ui_helper.createTable(classes_columns, lan_classes_data, lan_classes_options, nil, lan_classes_helpmsg)
    html[#html+1] = "</fieldset>"

	html[#html+1] = "<fieldset>"
    html[#html+1] =   "<legend>".. T"QoS Queue Scheduling on Interface WLAN".."</legend>"
	
	html[#html+1] = 	ui_helper.createCheckboxGroup(T"Qos Wireless Status", "wldevices", wldevices, wldevices_checked, {checkbox = { class="inline" }}, nil)
    html[#html+1] =     ui_helper.createInputSelect(T"Algorithm", "wlan_queues_policy", policy_options, content["wlan_queues_policy"])
    html[#html+1] =     ui_helper.createInputSelect(T"Default Queue", "wlan_queues_default", wlan_queue_options, content["wlan_queues_default"])

    html[#html+1] = "</fieldset>"
    html[#html+1] = "<fieldset>"
    html[#html+1] =   "<legend>".. T"QoS Queue Table on Interface WLAN".."</legend>"

    --legend = T"QoS Queue Table on Interface WAN"
    --is hardcoded in 'classes_columns',but for LAN edit panel, should be "QoS Queue Table on Interface LAN", change here
    classes_columns[5]["legend"] = T"QoS Queue Table on Interface WLAN"
	
    html[#html+1] =   	ui_helper.createTable(classes_columns, wlan_classes_data, wlan_classes_options, nil, wlan_classes_helpmsg)
    html[#html+1] = "</fieldset>"
	
	ngx.print(html)
	
	ngx.print('\
  </form>\
</div>\
');

ngx.print( ui_helper.createFooter() )
