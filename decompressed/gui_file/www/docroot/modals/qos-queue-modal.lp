<%
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

-- Shortcuts to validation helpers to make lines shorter
local vNES = post_helper.validateNonEmptyString
local vB = post_helper.validateBoolean
local gVIC = post_helper.getValidateInCheckboxgroup
local gVIES = post_helper.getValidateInEnumSelect
local vPN = post_helper.validatePositiveNum

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
}

local mapValid = {
    wan_queues_enabled = vB,
    wan_queues_policy = gVIES(policy_options),
    wan_queues_default = gVIES(wan_queue_options),
    lan_queues_enabled = vB,
    lan_queues_policy = gVIES(policy_options),
	lan_queues_default = gVIES(lan_queue_options),
}

if not proxy.get(mapParams.wan_queues_enabled) then
	mapParams.wan_queues_enabled = "uci.qos.interface.@wan.enable"
end
	
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

if content.wan_queues_enabled == "" then
    content.wan_queues_enabled = "0"
end
if content.lan_queues_enabled == "" then
    content.lan_queues_enabled = "0"
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

post_data_process(wan_classes_data, content.wan_queues_default)
post_data_process(lan_classes_data, content.lan_queues_default)

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end
%>

<%= ui_helper.createHeader(T"QoS", false, true) %>

<div class="modal-body update">
  <%
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
  %>
  <form class="form-horizontal" method="post" action="<%= uri %>">
  <%=ui_helper.createMessages(uimessage_helper.popMessages())%>
    <fieldset>
      <legend><%= T"QoS Queue Scheduling on Interface WAN" %></legend>
      <%
        ngx.print(ui_helper.createSwitch(T"Enabled", "wan_queues_enabled", content["wan_queues_enabled"]),
            ui_helper.createInputSelect(T"Algorithm", "wan_queues_policy", policy_options, content["wan_queues_policy"]),
            ui_helper.createInputSelect(T"Default Queue", "wan_queues_default", wan_queue_options, content["wan_queues_default"])
        )
      %>
      <legend><%= T"QoS Queue Table on Interface WAN" %></legend>
	  <%=ui_helper.createTable(classes_columns, wan_classes_data, wan_classes_options, nil, wan_classes_helpmsg) %>
    </fieldset>
    <fieldset>
      <legend><%= T"QoS Queue Scheduling on Interface LAN" %></legend>
      <%
        ngx.print(ui_helper.createSwitch(T"Enabled", "lan_queues_enabled", content["lan_queues_enabled"]),
            ui_helper.createInputSelect(T"Algorithm", "lan_queues_policy", policy_options, content["lan_queues_policy"]),
            ui_helper.createInputSelect(T"Default Queue", "lan_queues_default", lan_queue_options, content["lan_queues_default"])
        )
      %>
    </fieldset>
    <fieldset>
      <legend><%= T"QoS Queue Table on Interface LAN" %></legend>
      <%
      --legend = T"QoS Queue Table on Interface WAN"
      --is hardcoded in 'classes_columns',but for LAN edit panel, should be "QoS Queue Table on Interface LAN", change here
      %>
      <% classes_columns[5]["legend"] = T"QoS Queue Table on Interface LAN" %>
      <%=ui_helper.createTable(classes_columns, lan_classes_data, lan_classes_options, nil, lan_classes_helpmsg)%>
    </fieldset>
  </form>
</div>

<%= ui_helper.createFooter() %>
