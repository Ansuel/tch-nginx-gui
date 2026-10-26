--pretranslated: do not change this file
----------------------------------------------------------------------------------
-- Enable localization
----------------------------------------------------------------------------------
gettext.textdomain('webui-qos')

----------------------------------------------------------------------------------
-- Dependencies
----------------------------------------------------------------------------------
local tinsert, smatch, sformat = table.insert, string.match, string.format
remove = table.remove
local untaint = string.untaint

local proxy             = require("datamodel")
local ui_helper         = require("web.ui_helper")
local post_helper       = require("web.post_helper")
local session = ngx.ctx.session

local uniqueKey = post_helper.getRandomKey()

----------------------------------------------------------------------------------
-- UCI Paths (Do not add '@', arrays taken care of later)
----------------------------------------------------------------------------------
local uci_qos_prefix        = "uci.qos."
local uci_label_path        = uci_qos_prefix .. "label."
local uci_class_path        = uci_qos_prefix .. "class."
local uci_classify_path     = uci_qos_prefix .. "classify."

----------------------------------------------------------------------------------
-- UCI Parameters
----------------------------------------------------------------------------------
local uci_param_target      = "target"
local uci_param_srchost     = "srchost"
local uci_param_dsthost     = "dsthost"
local uci_param_protocol    = "proto"
local uci_param_ports       = "ports"
local uci_param_srcports    = "srcports"
local uci_param_dstports    = "dstports"
local uci_param_dscp        = "dscp"
local uci_param_trafficid   = "trafficid"

----------------------------------------------------------------------------------
-- Table Parameters (POST messages)
----------------------------------------------------------------------------------
local labelTargetName       = "qosClassifyLabelTarget"
local srcHostName           = "qosClassifySrcHost"
local dstHostName           = "qosClassifyDstHost"
local protocolName          = "qosClassifyProto"
local portsName             = "qosClassifyPorts"
local srcPortsName          = "qosClassifySrcPorts"
local dstPortsName          = "qosClassifyDstPorts"
local dscpClassifyName      = "qosClassifyDSCP"
local labelName             = "qosLabel"
local trafficidLabelName    = "qosLabelTrafficid"

---------------------------------------------------------------------------------
-- Shortcuts to validation helpers to make lines shorter
local gVIES = post_helper.getValidateInEnumSelect
local vSII  = post_helper.validateStringIsIP
local vSIP  = post_helper.validateStringIsPort
local gOV   = post_helper.getOrValidation
local vNES = post_helper.validateNonEmptyString

---------------------------------------------------------------------------------
-- handle qos labels
---------------------------------------------------------------------------------

local options_trafficid = {}
for i=1,15,1 do
   local id = tostring(i)
   options_trafficid[#options_trafficid + 1]  = { id, id }
end

local label_columns = {
    {
        header  = T"Label Name",
        name    = labelName,
        param   = "paramindex",
        type    = "text",
        attr    = { input = { class="span2"} },
    },
    {
        header  = T"Traffic ID",
        name    = trafficidLabelName,
        param   = uci_param_trafficid,
        type    = "select",
        values  = options_trafficid,
        attr    = { select = { class="span1"} },
    },
}

local function onAddLablel(current_section_index,content)
	
	local trafficid = untaint(content[trafficidLabelName])
	local trafficid_path = uci_label_path.."@"..current_section_index.."."..uci_param_trafficid
	
	proxy.add(uci_label_path,current_section_index)
	proxy.set(trafficid_path,trafficid)

end

local label_options = {
    tableid     = "label",
    basepath    = uci_label_path .. "@.",
    canEdit     = false,
    canApply    = true,
    canAdd      = true,
    canDelete   = true,
    createMsg   = T"Add New Label",
    addNamedObject = true,
    sorted      = uci_param_trafficid,
	onAdd = onAddLablel,
}

local label_filter = function(data)
    if data["trafficid"] == "" then
        return false
    end
    return true
end

local label_valid = {
    labelName = vNES,
    trafficidLabelName = gVIES(options_trafficid)
}
local label_data, label_helpMsg = post_helper.handleTableQuery(label_columns, label_options, label_filter, nil, label_valid)

----------------------------------------------------------------------------------
-- Function:  Setup mapped label keys to be handled whenever the label is
--            manipulated.
----------------------------------------------------------------------------------
local options_labeltarget = {}

for i,v in ipairs(proxy.getPN(uci_label_path, true)) do
    local label = smatch(v.path, "uci%.qos%.label%.@([^%.]+)%.")
    if label then
        options_labeltarget[#options_labeltarget+1] = { label, label }
    end
end

local options_proto = {
    {"all", "all"},
    {"tcp", "tcp"},
    {"udp", "udp"},
    {"udplite", "udplite"},
    {"icmp", "icmp"},
    {"esp", "esp"},
    {"ah", "ah"},
    {"sctp", "sctp"},
    {"igmp", "igmp"},
    {"gre", "gre"},
}

local options_dscp = {
    {"", ""},
    {"0x08", "CS1"},--8
    {"0x0A", "AF11"},--10
    {"0x0C", "AF12"},--12
    {"0x0E", "AF13"},--14
    {"0x10", "CS2"},--16
    {"0x12", "AF21"},--18
    {"0x14", "AF22"},--20
    {"0x16", "AF23"},--22
    {"0x18", "CS3"},--24
    {"0x1A", "AF31"},--26
    {"0x1C", "AF32"},--28
    {"0x1E", "AF33"},--30
    {"0x20", "CS4"},--32
    {"0x22", "AF41"},--34
    {"0x24", "AF42"},--36
    {"0x26", "AF43"},--38
    {"0x28", "CS5"},--40
	{"0x2C", "VOICE-ADMIT"},--44
    {"0x2E", "EF"}, --46
    {"0x30", "CS6"},--48
    {"0x38", "CS7"}, ----56
}

local dscp_helper = {}

for _ , value in pairs(options_dscp) do
	dscp_helper[value[1]]=value[2]
end

local classify_columns = {
    {
        header  = T"Label Target",
        name    = "target",
        param   = "target",
        type    = "select",
        values  = options_labeltarget,
        attr    = { select = { class="span2"} },
    },
    {
        header  = T"Source Host/IP",
        name    = srcHostName,
        param   = uci_param_srchost,
        type    = "text",
        attr    = { input = { class="span1"} },
    },
    {
        header  = T"Dest Host/IP",
        name    = dstHostName,
        param   = uci_param_dsthost,
        type    = "text",
        attr    = { input = { class="span1"} },
    },
    {
        header  = T"Protocol",
        name    = protocolName,
        param   = uci_param_protocol,
        default = "tcp",
        type    = "select",
        values  = options_proto,
        attr    = { select = { class="span1" } },
    },
    {
        header  = T"Port(s)",
        name    = portsName,
        param   = uci_param_ports,
        type    = "text",
        attr    = { input = { class="span2"} },
    },
    {
        header  = T"Source Port(s)",
        name    = srcPortsName,
        param   = uci_param_srcports,
        type    = "text",
        attr    = { input = { class="span2"} },
    },
    {
        header  = T"Dest Port(s)",
        name    = dstPortsName,
        param   = uci_param_dstports,
        type    = "text",
        attr    = { input = { class="span2"} },
    },
    {
        header  = T"DSCP",
        name    = dscpClassifyName,
        param   = uci_param_dscp,
        default = "",
        type    = "checkboxgroup",
        values  = options_dscp,
        attr    = { select = { class="span1" } },
    },
}

----------------------------------------------------------------------------------
-- Classify Table Configuration
----------------------------------------------------------------------------------
local classify_options = {
    tableid     = "classify",
    basepath    = uci_classify_path.."@.",
    canEdit     = true,
    canApply    = true,
    canAdd      = true,
    canDelete   = true,
    createMsg   = T"Add New Rule",
    sorted      = "target",
	objectName  = "classify"..uniqueKey,
	addNamedObject  = true,
}

----------------------------------------------------------------------------------
-- Classify Table Configuration
----------------------------------------------------------------------------------

local function validateStringIsPorts(value)
    for port in string.gmatch(value, "([^%,]+)") do
        local ok, msg = vSIP(port)
        if not ok then
            return nil, "The ports should be between 1-65535 and seperated with ','."
        end
    end
    return true
end

local function validateEmptyString(value)
    if value == "" then
        return true
    end
    return nil, "Empty string is allowed."
end


local function getQosClassifyDSCP(value, object, key)
    local getValidateQosClassifyDSCP = gVIES(options_dscp)
    local ok, msg = getValidateQosClassifyDSCP(value, object, key)
    if not ok then
        return ok, msg
    end

    object[key] = {value}
    return true
end

local classify_valid = {
    target = gVIES(options_labeltarget),
    qosClassifyProto = gVIES(options_proto),
	qosClassifyDSCP = getQosClassifyDSCP,
    qosClassifySrcHost = gOV(vSII, validateEmptyString),
    qosClassifyDstHost = gOV(vSII, validateEmptyString),
    qosClassifySrcPorts = gOV(validateStringIsPorts, validateEmptyString),
    qosClassifyDstPorts = gOV(validateStringIsPorts, validateEmptyString),
    qosClassifyPorts = gOV(validateStringIsPorts, validateEmptyString),
}

local function classify_filter(data)
    if data[uci_param_srchost] == "" and data[uci_param_dsthost] == "" and data[uci_param_protocol] == "" and
       data[uci_param_ports] == "" and data[uci_param_srcports] == "" and data[uci_param_dstports] == "" and
       data[uci_param_dscp] == "" then
        return false
    end
    return true
end

----------------------------------------------------------------------------------
-- Populate Table
----------------------------------------------------------------------------------
local classify_data, classify_helpMsg = post_helper.handleTableQuery(classify_columns, classify_options, classify_filter, nil, classify_valid)
-- TODO:This is workaround solution to make GUI show normally.
-- parameter DSCP changed from option to list,type should be changed to checkboxgroup,the GUI didn't show suitably.Need to improve the solution.
for _,v in ipairs(classify_data) do
	--print(v[8])
    if type(v[8]) == "table" then
		local tmp = {}
		for _ , value in pairs(v[8]) do
			if not ( value == "" ) then
				tmp[#tmp+1] = dscp_helper[value]
			end
		end
        v[8] = table.concat(tmp, ",")
    end
end

classify_columns[8].type = "select"

ngx.print( ui_helper.createHeader(T"QoS", false, true) ); ngx.print('\
\
<div class="modal-body update">\
')
        local tabs = {
            {
                desc = T"Queue",
                target = "modals/qos-queue-modal.lp",
            },
            {
                desc = T"Classification",
                target = "modals/qos-classify-modal.lp",
                active = "active",
            },
        }
        ngx.print(ui_helper.createModalTabs(tabs))
    ngx.print('\
    <form class="form-horizontal" method="post" action="modals/qos-classify-modal.lp">\
	')
		local html = {}
		
        html[#html+1] = "<fieldset>"
        html[#html+1] =     "<legend>"..T"QoS Label Table".."</legend>"
        html[#html+1] =     ui_helper.createTable(label_columns, label_data, label_options, nil, label_helpMsg)
        html[#html+1] = "</fieldset>"
        html[#html+1] = "<fieldset>"
        html[#html+1] =	    "<legend>"..T"QoS Classification Table".."</legend>"
        html[#html+1] =     ui_helper.createTable(classify_columns, classify_data, classify_options, nil, classify_helpMsg)
        html[#html+1] = "</fieldset>"
		
		ngx.print(html)
		
		ngx.print('\
    </form>\
</div>\
')
ngx.print( ui_helper.createFooter() )
