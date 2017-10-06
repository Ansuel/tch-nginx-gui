<%
-- Enable localization
gettext.textdomain('webui-voice')

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local post_helper = require("web.post_helper")
local untaint = string.untaint


-- This code will be triggered by post of the button
local post_content
if ngx.var.request_method == "POST" then
    post_content = ngx.req.get_post_args()
    if post_content["operation"] == "RESET" then
        proxy.set("rpc.mmpbx.callstatistics.clear", "true")
    end
end

local historical_statistics_columns = {
    {
        header = T"Profile",
        name = "DirectoryNumber",
        param = "DirectoryNumber",
    },
    {
        header = T"Remoteparty",
        name = "Remote",
        param = "Remote",
    },
    {
        header = T"ReceiveInterarrivalJitter",
        name = "ReceiveInterarrivalJitter",
        param = "ReceiveInterarrivalJitter",
    },
    {
        header = T"FarEndInterarrivalJitter",
        name = "FarEndInterarrivalJitter",
        param = "FarEndInterarrivalJitter",
    },
    {
        header = T"RoundTripDelay",
        name = "RoundTripDelay",
        param = "RoundTripDelay",
    },
}

local profile = {}


local historical_statistics_options = {
    basepath = "rpc.mmpbx.callstatistics.historical.",
    tableid = "historicalstatistics",
    canApply = false,
    canEdit = false,
    canAdd = false,
    canDelete = false,
}

local statistics_filter = function(data)
    if data["RoundTripDelay"] == "0" and data["ReceiveInterarrivalJitter"] == "0" and data["FarEndInterarrivalJitter"] == "0" then
        return false
    end
    return true
end


local historical_statistics_data,historical_statistics_helpmsg = post_helper.handleTableQuery(historical_statistics_columns, historical_statistics_options, statistics_filter, nil, nil)

-- clear call log button
local clear_call_log = {
    controls = {
      class = "clear_call_log"
    },
    button = {
      ["data-name"] = "operation",
      ["data-value"] = "RESET"
    }
}

local ongoing_statistics_columns = {
    {
        header = T"URI",
        name = "URI",
        param = "LineName",
    },
    {
        header = T"ReceiveInterarrivalJitter",
        name = "ReceiveInterarrivalJitter",
        param = "ReceiveInterarrivalJitter",
    },
    {
        header = T"FarEndInterarrivalJitter",
        name = "FarEndInterarrivalJitter",
        param = "FarEndInterarrivalJitter",
    },
    {
        header = T"RoundTripDelay",
        name = "RoundTripDelay",
        param = "RoundTripDelay",
    },
}

local ongoing_statistics_options = {
    basepath = "rpc.mmpbx.callstatistics.ongoing.",
    tableid = "historicalstatistics",
    canApply = false,
    canEdit = false,
    canAdd = false,
    canDelete = false,
}

local ongoing_statistics_data,ongoing_statistics_helpmsg = post_helper.handleTableQuery(ongoing_statistics_columns, ongoing_statistics_options, nil, nil, nil)

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end
%>

<%= ui_helper.createHeader(T"Telephony", false, true) %>
<div class="modal-body update">
  <%
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal" method="post" action="<%= uri %>">
        <fieldset>
            <legend><%= T"Historical Statistics" %></legend>
            <%= ui_helper.createTable(historical_statistics_columns, historical_statistics_data, historical_statistics_options) %>
        </fieldset>
        <fieldset>
            <center>
                <%= ui_helper.createSimpleButton(T"Clear historical logs", "icon-bolt", clear_call_log)%>
            </center>
        </fiedset>
        <fieldset>
            <legend><%= T"Ongoing Statistics" %></legend>
            <%= ui_helper.createTable(ongoing_statistics_columns, ongoing_statistics_data, ongoing_statistics_options) %>
        </fieldset>
   </form>
</div>
<%= ui_helper.createFooter() %>

