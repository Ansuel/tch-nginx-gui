<%
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local format = string.format
local type = type
local post_content = {}

local mapValid = {
    NumberOfRepetitions = post_helper.getValidateNumberInRange(0, 10),
    DataBlockSize = post_helper.getValidateNumberInRange(0, 1000),
    ipAddress = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
}
local mapValidTrace = {
    MaxHopCount = post_helper.getValidateNumberInRange(1,64),
    MaxSize = post_helper.getValidateNumberInRange(1,65535),
    DataBlockSizeT = post_helper.validatePositiveNum,
    Timeout = post_helper.validatePositiveNum,
    Tries = post_helper.validatePositiveNum,
    ipAddressTrace = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
}

local function restartTest(data)
    local success,msg = false, {}
    if type(data) == "table"  then
        success, msg = content_helper.validateObject(data, mapValid)
        if success then
            success = proxy.set({
                ["uci.ipping.@diagping.NumberOfRepetitions"] = data["NumberOfRepetitions"],
                ["uci.ipping.@diagping.Host"]= data["ipAddress"],
                ["uci.ipping.@diagping.DataBlockSize"]= data["DataBlockSize"],
                ["uci.ipping.@diagping.Interface"]= "",
                ["uci.ipping.@diagping.DiagnosticsState"]= "Requested",
            })
            if success then
                proxy.apply()
            end
        end
    end
    return success, msg
end

local function restartTestTrace(data)
    local success,msg = false, {}
    if type(data) == "table"  then
        success, msg = content_helper.validateObject(data, mapValidTrace)
        if success then
            success = proxy.set({
                ["uci.traceroute.@diagping.Host"]= data["ipAddressTrace"],
                ["uci.traceroute.@diagping.MaxHopCount"]= data["MaxHopCount"],
                ["uci.traceroute.@diagping.Timeout"]= data["Timeout"],
                ["uci.traceroute.@diagping.DataBlockSize"]= data["MaxSize"],
                ["uci.traceroute.@diagping.NumberOfTries"]= data["Tries"],
                ["uci.traceroute.@diagping.DiagnosticsState"]= "Requested",
            })
            if success then
                proxy.apply()
            end
        end
    end
    return success, msg
end

if(not proxy.get("uci.ipping.@diagping.DiagnosticsState")) then
    proxy.add("uci.ipping.","diagping")
end

if(not proxy.get("uci.traceroute.@diagping.DiagnosticsState")) then
    proxy.add("uci.traceroute.","diagping")
end

local helpmsg = {}
local gsuccess = true
-- This code will be triggered by get and post of the button
if ngx.var.request_method == "POST" then
    local pingState = proxy.get("uci.ipping.@diagping.DiagnosticsState")
    local traceState = proxy.get("uci.traceroute.@diagping.DiagnosticsState")
    local success
    gsuccess = true
    post_content = ngx.req.get_post_args()
    if post_content["action"] == "PING" then
    -- This Condition Check will protect from multiple Ping_Request error
      if pingState[1].value ~= "Requested" then
        gsuccess, helpmsg = restartTest(post_content)
        session:store("diag_ping_action", "TRUE")
      end
    elseif post_content["action"] == "PINGSTOP" then
        success = proxy.set("uci.ipping.@diagping.DiagnosticsState", "None")
        if success then
            proxy.apply();
        end
    elseif post_content["action"] == "TRACE" then
    -- This Condition Check will protect from multiple Trace_Route error
        if traceState[1].value ~= "Requested" then
          gsuccess, helpmsg = restartTestTrace(post_content)
          session:store("diag_trace_action", "TRUE")
        end
    elseif post_content["action"] == "TRACESTOP" then
        success = proxy.set("uci.traceroute.@diagping.DiagnosticsState", "Canceled")
        if success then
            proxy.apply();
        end
    end
end

local cping = {
    ipping_state = "uci.ipping.@diagping.DiagnosticsState",
    ipping_minresptime = "uci.ipping.@diagping.MinimumResponseTime",
    ipping_maxresptime = "uci.ipping.@diagping.MaximumResponseTime",
    ipping_avgresptime = "uci.ipping.@diagping.AverageResponseTime",
    ipping_SuccessCount = "uci.ipping.@diagping.SuccessCount",
    ipping_FailureCount = "uci.ipping.@diagping.FailureCount",
    ipping_Repetitions = "uci.ipping.@diagping.NumberOfRepetitions",
    ipping_ipAddress = "uci.ipping.@diagping.Host",
    ipping_Size = "uci.ipping.@diagping.DataBlockSize",
    ipping_noEntries = "uci.ipping.@diagping.TraceNumberOfEntries",
}

local ctracert = {
    tracert_state = "uci.traceroute.@diagping.DiagnosticsState",
    tracert_ipAddress = "uci.traceroute.@diagping.Host",
    tracert_dscp = "uci.traceroute.@diagping.DSCP",
    tracert_hopcount = "uci.traceroute.@diagping.MaxHopCount",
    tracert_size = "uci.traceroute.@diagping.DataBlockSize",
    tracert_timeout = "uci.traceroute.@diagping.Timeout",
    tracert_tries = "uci.traceroute.@diagping.NumberOfTries",
}

local rh_columns = {
    {
        header = T"Hostname",
        name = "hophost",
        param = "HopHost",
        type = "text",
        attr = { input = { class="span2" } },
    },
    {
        header = T"Error code",
        name = "hoperrorcode",
        param = "HopErrorCode",
        type = "text",
        attr = { input = { class="span1"} },
    },
    {
        header = T"RTT1 (ms)",
        name = "hoprtttimes",
        param = "HopRTTimes",
        type = "text",
        attr = { input = { class="span1"} },
    },
    {
        header = T"RTT2 (ms)",
        name = "hoprtttimes",
        param = "HopRTTimes2",
        type = "text",
        attr = { input = { class="span1"} },
    },
    {
        header = T"RTT3 (ms)",
        name = "hoprtttimes",
        param = "HopRTTimes3",
        type = "text",
        attr = { input = { class="span1"} },
    },
}

local rh_options = {
    tableid = "routehops",
    basepath = "uci.traceroute.@diagping.RouteHops.@.",
    canEdit = false,
    canAdd = false,
    canDelete = false,
    sorted = function(a, b)
        return tonumber(a.paramindex) < tonumber(b.paramindex)
    end
}
local rh_filter = function(data)
    if data["HopRTTimes"] ~= "*" then
      data["HopRTTimes"],data["HopRTTimes2"],data["HopRTTimes3"] = string.match(data["HopRTTimes"],"([%d]+),([%d]+),([%d]+)")
    else
      data["HopRTTimes"],data["HopRTTimes2"],data["HopRTTimes3"] = "*", "*", "*"
    end
    if data["HopHost"] == "" then
      data["HopHost"] = data["HopHostAddress"]
    end
    return true
end

local rh_data, rh_helpmsg = post_helper.handleTableQuery(rh_columns, rh_options, rh_filter)

-- Get the content
content_helper.getExactContent(cping)
content_helper.getExactContent(ctracert)

cping.ipping_ipAddress = post_content["ipAddress"] or cping.ipping_ipAddress
cping.ipping_Repetitions = post_content["NumberOfRepetitions"] or cping.ipping_Repetitions
cping.ipping_Size = post_content["DataBlockSize"] or cping.ipping_Size

ctracert.tracert_ipAddress = post_content["ipAddressTrace"] or ctracert.tracert_ipAddress
ctracert.tracert_hopcount = post_content["MaxHopCount"] or ctracert.tracert_hopcount
ctracert.tracert_size = post_content["MaxSize"] or ctracert.tracert_size

local refresh = 2

--This code will stop the refresh when all results are available
if(cping.ipping_state ~= "Requested" and ctracert.tracert_state ~= "Requested") or not gsuccess then
    refresh = nil
end

ngx.print(ui_helper.createHeader(T"Diagnostics Ping&Trace", true, false, refresh)) %>

<div class="modal-body no-save update">
<%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-diagnostics.lp")
%>

<form class="form-horizontal" method="post" action="modals/diagnostics-ping-modal.lp">
<fieldset id="diagnostics-ping-tab">
    <legend><%= T"Ping Statistics" %></legend>

    <div class="control-group">
        <label class="control-label"></label>
        <div class="controls">
        <% if(cping.ipping_state ~= "Requested") then %>
            <div id="send-config_PING" class="btn" data-name="action" data-value="PING"><%= T"Send Ping Request" %></div>
        <% else%>
            <div id="stop-config_PING" class="btn"data-name="action" data-value="PINGSTOP"><%= T"Stop Ping Request" %></div>
        <% end%>
        </div>
    </div>

    <%
    local ping_trace_columns = {
    {
        header = T"Bytes",
        name = "Bytes",
        param = "Bytes",
        type = "text",
        attr = { input = { class="span2" } },
    },
    {
        header = T"IP",
        name = "IP",
        param = "IP",
        type = "text",
        attr = { input = { class="span2" } },
    },
    {
        header = T"Seq",
        name = "Seq",
        param = "Seq",
        type = "text",
        attr = { input = { class="span1"} },
    },
    {
        header = T"TTL",
        name = "TTL",
        param = "TTL",
        type = "text",
        attr = { input = { class="span1"} },
    },
    {
        header = T"Time",
        name = "Time",
        param = "Time",
        type = "text",
        attr = { input = { class="span1"} },
    },
}
    local ping_trace_options = {
      tableid = "pingtrace",
      basepath = "uci.ipping.@diagping.Trace.@.",
      canEdit = false,
      canAdd = false,
      canDelete = false,
      sorted = function(a, b)
        return tonumber(a.paramindex) < tonumber(b.paramindex)
     end
}
    local ping_trace_filter = function(data)
      if data["Seq"]  then
        data["Seq"] = string.match(data["Seq"],"([%d]+)")
      end
      if data["Seq"] == "" then
        data["Seq"] = data["SeqAddress"]
      end
    return true
    end

    local ping_trace_data, ping_trace_helpmsg = {},nil
    local attributes = { span = { class = "span8" } }
    local advanced = { span = { class = "span8" }, group = { class = "advanced hide" } }
    local pattern_hopcount = {
      input = {
              ["data-for"] = "TRACE",
              pattern= "[0-9]{1,2}",
              maxlength = "2",
      }
    }
    local attrPing = {input = { ["data-for"] = "PING"}}
    local attrTrace = {input = { ["data-for"] = "TRACE"}}
    local explanationPing = ""
    local statusIconPing = ""
    local ippingSuccessCount = ""
    local ippingFailureCount = ""
    local explanationTrace = ""
    local statusIconTrace = ""

    local statusPingTest = cping.ipping_state
    local statusTracertTest = proxy.get("uci.traceroute.@diagping.DiagnosticsState")

    if ngx.var.request_method == "POST" and gsuccess then
        ippingSuccessCount = cping.ipping_SuccessCount
        ippingFaliureCount = cping.ipping_FailureCount
        if statusPingTest and session:retrieve("diag_ping_action") =="TRUE" then
            if statusPingTest == "Complete" then
               if #ping_trace_data == 0 then
                    ping_trace_data = content_helper.loadTableData(ping_trace_options.basepath, ping_trace_columns)
                end
                if cping.ipping_Repetitions == cping.ipping_SuccessCount then
                    statusIconPing = "<i class=\"icon-ok icon-large green\"></i> "
                    explanationPing = T"Success"
                elseif cping.ipping_Repetitions == cping.ipping_FailureCount then
                    statusIconPing = "<i class=\"icon-ban-circle icon-large red\"></i>"
                    explanationPing = T"Failed"
                else
                    statusIconPing = "<i class=\"icon-ban-circle icon-large red\"></i>"
                    explanationPing = T"Not all ping request have been answered"
                end
            elseif statusPingTest == "Requested" then
                statusIconPing = "<i class=\"icon-asterisk icon-large blue\"></i> "
                explanationPing = T"Ongoing"
            elseif statusPingTest ~= "None" then
                statusIconPing = "<i class=\"icon-ban-circle icon-large red\"></i>"
                explanationPing = T"Failed"
            else
               statusIconPing = "<i class=\"icon-ban-circle icon-large red\"></i>"
               explanationPing = T"Not Connected"
            end
        end

        if statusTracertTest and session:retrieve("diag_trace_action") =="TRUE" then
            statusTracertTest = statusTracertTest[1].value
            if statusTracertTest == "Complete" then
                --when complete, update the routehops table
                if #rh_data == 0 then
                    rh_data = content_helper.loadTableData(rh_options.basepath, rh_columns)
                end
                statusIconTrace = "<i class=\"icon-ok icon-large green\"></i> "
                explanationTrace = T"Finished"
            elseif statusTracertTest == "Requested" then
                statusIconTrace = "<i class=\"icon-asterisk icon-large blue\"></i> "
                explanationTrace = T"Ongoing"
            elseif statusTracertTest ~= "None" then
                statusIconTrace = "<i class=\"icon-ban-circle icon-large red\"></i>"
                explanationTrace = T"Failed"
            else
                statusIconTrace = "<i class=\"icon-ban-circle icon-large red\"></i>"
                explanationTrace = T"Not Connected"
           end
        end
    end

local ping_trace_data, ping_trace_helpmsg = post_helper.handleTableQuery(ping_trace_columns, ping_trace_options,ping_trace_filter)
   ngx.print(
        ui_helper.createLabel(T"Status:", format("%s %s", statusIconPing, explanationPing), attributes),
        ui_helper.createLabel(T"Success Count:", cping.ipping_noEntries),
        ui_helper.createLabel(T"Failure Count:", cping.ipping_FailureCount),
        ui_helper.createInputText(T"Hostname:","ipAddress", cping.ipping_ipAddress, attrPing, helpmsg["ipAddress"]),
        ui_helper.createInputText(T"Number of pings:","NumberOfRepetitions", cping.ipping_Repetitions, attrPing, helpmsg["NumberOfRepetitions"]),
        ui_helper.createInputText(T"Size (bytes):","DataBlockSize", cping.ipping_Size, attrPing, helpmsg["DataBlockSize"]),
        ui_helper.createLabel(T"Min Resp Time:", format("%s ms", cping.ipping_minresptime)),
        ui_helper.createLabel(T"Max Resp Time:", format("%s ms", cping.ipping_maxresptime)),
        ui_helper.createLabel(T"Avg Resp Time:", format("%s ms", cping.ipping_avgresptime)),
        ui_helper.createTable(ping_trace_columns, ping_trace_data, ping_trace_options, ping_trace_attributes, ping_trace_helpmsg)

    )
    %>
</fieldset>

<fieldset id="diagnostics-tracert-tab">
        <legend><%= T"Trace Route" %></legend>

        <div class="control-group">
        <label class="control-label"></label>
        <div class="controls">
        <% if(ctracert.tracert_state ~= "Requested" ) then %>
            <div id="send-config_TRACE" class="btn" data-name="action" data-value="TRACE"><%= T"Trace Route" %></div>
        <% else%>
            <div id="stop-config_TRACE" class="btn" data-name="action" data-value="TRACESTOP"><%= T"Stop Trace Route" %></div>
        <% end%>
        </div>
    </div>

    <div style="max-width:880px;overflow-x:auto;">
    <%
    ngx.print(
        ui_helper.createLabel(T"Status:", format("%s %s", statusIconTrace, explanationTrace), attributes),
        ui_helper.createInputText(T"Hostname:","ipAddressTrace", ctracert.tracert_ipAddress, attrTrace, helpmsg["ipAddressTrace"]),
        -- ui_helper.createInputText(T"Timeout:","Timeout", ctracert.tracert_timeout, attrTrace, helpmsg["Timeout"]),
        ui_helper.createInputText(T"Max Hop Count:","MaxHopCount", ctracert.tracert_hopcount, pattern_hopcount, helpmsg["MaxHopCount"]),
        ui_helper.createInputText(T"Size (bytes):","MaxSize", ctracert.tracert_size, attrTrace, helpmsg["MaxSize"]),
        -- ui_helper.createInputText(T"Tries:","Tries", ctracert.tracert_tries, attrTrace, helpmsg["Tries"]),
        ui_helper.createTable(rh_columns, rh_data, rh_options, rh_attributes, rh_helpmsg)
    )
    %>
    </div>
</fieldset>
</form>
</div>
<%if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action =="TRACE" or ngx.req.get_post_args().action =="TRACESTOP") then%>
  <script>
    var tablePos = $("#routehops").position();
    $(".modal-body").scrollTop(tablePos.top);
  </script>
<%end%>
<div class="modal-footer">
    <div id="modal-no-change">
        <div class="btn btn-primary btn-large" data-dismiss="modal"><%= T"Close" %></div>
    </div>
</div>
