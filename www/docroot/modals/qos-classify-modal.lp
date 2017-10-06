<%
----------------------------------------------------------------------------------
-- Enable localization
----------------------------------------------------------------------------------
gettext.textdomain('webui-qos')

----------------------------------------------------------------------------------
-- Dependencies
----------------------------------------------------------------------------------
tinsert, smatch, sformat = table.insert, string.match, string.format
remove = table.remove

local proxy             = require("datamodel")
local ui_helper         = require("web.ui_helper")
local post_helper       = require("web.post_helper")
local session = ngx.ctx.session

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

---------------------------------------------------------------------------------
-- handle qos labels
---------------------------------------------------------------------------------

local options_trafficid = {}
for i=1,15,1 do
   local id = tostring(i)
   options_trafficid[#options_trafficid + 1]  = { id, id }
end

local label_columns = {
    { -- add dummy column here.
      -- if paramindex is used as first column, adding label will fail
      -- this column needs to be removed after handle table query
        header  = T"Traffic ID",
        name    = 'dummy',
        param   = uci_param_trafficid,
        type    = "select",
        values  = options_trafficid,
        attr    = { select = { class="span1"} },
    },
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
}

local label_filter = function(data)
    if data["trafficid"] == "" then
        return false
    end
    return true
end

local label_valid = {
    [labelName] = function(value, object, key)
        label_options.objectName = string.format("%s",value)
        object[key] = nil
        return true
    end,
    [trafficidLabelName] = gVIES(options_trafficid),
}
local label_data, label_helpMsg = post_helper.handleTableQuery(label_columns, label_options, label_filter, nil, label_valid)

-- remove dummy column
for _,v in ipairs(label_data) do
    remove(v, 1)
end
remove(label_columns, 1)

----------------------------------------------------------------------------------
-- Function:  Setup mapped label keys to be handled whenever the label is
--            manipulated.
----------------------------------------------------------------------------------
local options_labeltarget = {}

local function initLabelOptions()
    for i,v in ipairs(proxy.getPN(uci_label_path, true)) do
        local label = smatch(v.path, "uci%.qos%.label%.@([^%.]+)%.")
        if label then
            options_labeltarget[#options_labeltarget+1] = { label, label }
        end
    end
end

initLabelOptions()

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
    {"AF11", "AF11"},
    {"AF12", "AF12"},
    {"AF13", "AF13"},
    {"AF21", "AF21"},
    {"AF22", "AF22"},
    {"AF23", "AF23"},
    {"AF31", "AF31"},
    {"AF32", "AF32"},
    {"AF33", "AF33"},
    {"AF41", "AF41"},
    {"AF42", "AF42"},
    {"AF43", "AF43"},
    {"CS1", "CS1"},
    {"CS2", "CS2"},
    {"CS3", "CS3"},
    {"CS4", "CS4"},
    {"CS5", "CS5"},
    {"CS6", "CS6"},
    {"CS7", "CS7"},
    {"EF", "EF"},
}

local classify_columns = {
    {
        header  = T"Label Target",
        name    = labelTargetName,
        param   = uci_param_target,
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
    basepath    = uci_classify_path,
    canEdit     = true,
    canApply    = true,
    canAdd      = true,
    canDelete   = true,
    createMsg   = T"Add New Rule",
    sorted      = "target"
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
    qosClassifyLabelTarget = gVIES(options_labeltarget),
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
    if type(v[8]) == "table" then
        table.concat(v[8], ",")
    end
end

classify_columns[8].type = "select"
%>

<%= ui_helper.createHeader(T"QoS", false, true) %>

<div class="modal-body update">
    <%
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
    %>
    <form class="form-horizontal" method="post" action="modals/qos-classify-modal.lp">
        <fieldset>
            <legend><%= T"QoS Label Table" %></legend>
            <%= ui_helper.createTable(label_columns, label_data, label_options, nil, label_helpMsg) %>
        </fieldset>
        <fieldset>
            <legend><%= T"QoS Classification Table" %></legend>
            <%= ui_helper.createTable(classify_columns, classify_data, classify_options, nil, classify_helpMsg) %>
        </fieldset>
    </form>
</div>

<%= ui_helper.createFooter() %>

<script type="text/javascript">
    // Columns are ZERO indexed (make sure they match up with values above)
    var column_label_target = 0;
    var column_srcip = 1, column_dstip = 2;
    var column_proto = 3;
    var column_port = 4, column_srcport = 5, column_dstport = 6;

    function findControlBox (index, type) {
        return $("tr").last().children("td").eq(index).find(type);
    }

    function disableControlBox (obj) {
        obj.val("").attr ("disabled", "disabled");
    }

    function enableControlBox (obj) {
        obj.val("").removeAttr ("disabled");
    }

    // Retrieve control box information
    var target_obj = findControlBox (column_label_target, "select");
    var proto_obj = findControlBox (column_proto, "select");
    var port_obj = findControlBox (column_port, "input");
    var srcport_obj = findControlBox (column_srcport, "input");
    var dstport_obj = findControlBox (column_dstport, "input");

    function handle_port (proto) {
        if (proto == "tcp" || proto == "udp")
        {
            enableControlBox (port_obj);
            enableControlBox (srcport_obj);
            enableControlBox (dstport_obj);
        }
        else
        {
            disableControlBox (port_obj);
            disableControlBox (srcport_obj);
            disableControlBox (dstport_obj);
        }
    };

    $(document).ready(function () {
        var proto = proto_obj.val();
        handle_port(proto);
    });

    // Value change handler of protocol (*** ADD MORE ITEMS AS SUPPORTED ***)
    proto_obj.change (function() {
        var value = $(this).val();
        handle_port(value);
    });
</script>
