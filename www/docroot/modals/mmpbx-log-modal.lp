<%
-- Enable localization
gettext.textdomain('webui-voice')

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local string = string
local format, gsub, gmatch = string.format, string.gsub, string.gmatch

-- This code will be triggered by post of the button
local post_content
if ngx.var.request_method == "POST" then
    post_content = ngx.req.get_post_args()
    if post_content["operation"] == "RESET" then
        proxy.set("rpc.mmpbx.calllog.clear", "true")
    end
end

local calllog_columns = {
    {
        header = T"Time",
        name = "DateTime",
    },
    {
        header = T"Call Type",
        name = "CallType",
    },
    {
        header = T"Local Number",
        name = "LocalNumber",
    },
    {
        header = T"Remote Number",
        name = "RemoteNumber",
    },
    {
        header = T"Duration",
        name = "Duration",
    },
    {
        header = T"Port",
        name = "DeviceName",
    },
}

local calllog_options = {
    tableid = "calllog",
    canApply = false,
    canEdit = false,
    canAdd = false,
    canDelete = false,
}

-- Identify log table column number
local lcns = {
    ["DateTime"] = 1,
    ["CallType"] = 2,
    ["LocalNumber"] = 3,
    ["RemoteNumber"] = 4,
    ["Duration"] = 5,
    ["DeviceName"] = 6,
}

local incoming_success_str = T"Incoming Successful"
local incoming_missed_str = T"Incoming Missed"
local outgoing_success_str = T"Outgoing Successful"
local outgoing_failed_str = T"Outgoing Failed"

local stats_columns = {
  {
    header = T"Device Name",
    name = "deviceName",
  },
  {
    header = incoming_success_str,
    name = "incoming_success",
  },
  {
    header = incoming_missed_str,
    name = "incoming_missed",
  },
  {
    header = outgoing_success_str,
    name = "outgoing_success",
  },
  {
    header = outgoing_failed_str,
    name = "outgoing_failed",
  },
}

local stats_options = {
    tableid = "stats",
    canApply = false,
    canEdit = false,
    canAdd = false,
    canDelete = false,
}

-- Identify stats table column number
local scns = {
    ["incoming_success"] = 2,
    ["incoming_missed"] = 3,
    ["outgoing_success"] = 4,
    ["outgoing_failed"] = 5,
}

local modf = math.modf
local function updateDuration (time)
    local days = modf(time /86400)
    local hours = modf(time / 3600)-(days * 24)
    local minutes = modf(time /60) - (days * 1440) - (hours * 60)
    local seconds = time - (minutes * 60) - (hours * 3600) - (days * 86400)
    if days == 0 then
        return format("%02d:%02d:%02ds", hours, minutes, seconds)
    else
        return format("%ddays,%02d:%02d:%02ds", days, hours, minutes, seconds)
    end
end

local dev_config = {
    ["fxs"] = "mmpbxbrcmfxsdev",
    ["dect"] = "mmpbxbrcmdectdev",
    ["sipdev"] = "mmpbxrvsipdev",
}

local function getDeviceFriendlyNames()
    local devpattern = "([^%._@]+_dev_%d+)"
    local results, dev = nil, ""
    local mapTable, stats_data, index = {}, {}, {}
    for _,v in pairs(dev_config) do
        results = proxy.get("uci." .. v .. ".device.")
        if results then
            for _,vv in ipairs(results) do
                if vv.param == "user_friendly_name" then
                    dev = vv.path:match(devpattern)
                    mapTable[dev] = vv.value
                    local data = {}
                    data[#data+1] = dev
                    for k=1,4 do
                        data[#data+1] = 0
                    end
                    stats_data[#stats_data+1] = data
                    index[dev] = #stats_data
                end
            end
        end
    end
    return setmetatable(mapTable, untaint_mt), stats_data, setmetatable(index, untaint_mt)
end

local mapTable, stats_data, index = getDeviceFriendlyNames()

local basepath = "rpc.mmpbx.calllog.info."
local logTable = content_helper.convertResultToObject(basepath .. "@", proxy.get(basepath))
table.sort(logTable, function(a,b)
    if tonumber(a.paramindex) < tonumber(b.paramindex) then
        return false
    else
        return true
    end
end)
local calllog_data = {}

local total = {
    [1] = T"Total",
    [2] = 0,
    [3] = 0,
    [4] = 0,
    [5] = 0,
}

local time_t = {}
local function convert2Sec(value)
    value = string.untaint(value)
    time_t.year, time_t.month, time_t.day, time_t.hour, time_t.min, time_t.sec = value:match("(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
    if time_t.year then
        return os.time(time_t)
    end
    return 0
end

for k,v in ipairs(logTable) do
    local data = {}
    data[lcns.LocalNumber] = v.Localparty
    data[lcns.RemoteNumber] = v.Remoteparty
    data[lcns.DateTime] = v.startTime
    data[lcns.Duration] = v.connectedTime
    if v.connectedTime ~= "0" then
        local connectedTime = convert2Sec(v.connectedTime)
        if v.endTime ~= '0' then
            local endTime = convert2Sec(v.endTime)
            data[lcns.Duration] = updateDuration(endTime - connectedTime)
        else
            data[lcns.Duration] = updateDuration(os.time() - connectedTime)
        end
    end
    data[lcns.DeviceName] = gsub(v.deviceName, "([^%,]+)", mapTable)
    for deviceName in gmatch(v.deviceName,"([^%,]+)") do
        local stats = stats_data[index[deviceName]]
        if v.Direction == "2" then
            if v.connectedTime == "0" then
                data[lcns.CallType] = outgoing_failed_str
                if stats then
                    stats[scns["outgoing_failed"]] = stats[scns["outgoing_failed"]] + 1
                    total[scns["outgoing_failed"]] = total[scns["outgoing_failed"]] + 1
                end
            else
                data[lcns.CallType] = outgoing_success_str
                if stats then
                    stats[scns["outgoing_success"]] = stats[scns["outgoing_success"]] + 1
                    total[scns["outgoing_success"]] = total[scns["outgoing_success"]] + 1
                end
            end
        else
            if v.connectedTime == "0" then
                data[lcns.CallType] = incoming_missed_str
                if stats then
                    stats[scns["incoming_missed"]] = stats[scns["incoming_missed"]] + 1
                    total[scns["incoming_missed"]] = total[scns["incoming_missed"]] + 1
                end
            else
                data[lcns.CallType] = incoming_success_str
                if stats then
                    stats[scns["incoming_success"]] = stats[scns["incoming_success"]] + 1
                    total[scns["incoming_success"]] = total[scns["incoming_success"]] + 1
                end
            end
        end
    end
    if v.deviceName == "" then
	data[lcns.DeviceName] = "-"
        local reason = v.terminationReason
        if reason == "NO_DEVICE_MAPPED"  or reason == "NO_DEVICE_AVAILABLE" then
	    data[lcns.CallType] = incoming_missed_str
	end
	if reason == "CALL_FORWARDING_UNCONDITIONAL" or reason == "CALL_FORWARDING_ON_BUSY_SUBSCRIBER" then
            data[lcns.CallType] = incoming_success_str
	end
	if reason == "DO_NOT_DISTURB" then
            data[lcns.CallType] = incoming_missed_str
	end
    end
    calllog_data[k] = data
end

local order = {
    f = 1,
    d = 2,
    s = 3,
}

table.sort(stats_data, function(a,b)
    local order_a = order[a[1]:sub(1,1)]
    local order_b = order[b[1]:sub(1,1)]
    if order_a < order_b or (order_a == order_b and a[1] < b[1]) then
        return true
    else
        return false
    end
end)

for _,v in pairs(stats_data) do
    v[1] = mapTable[v[1]] or v[1]
end

stats_data[#stats_data + 1] = total

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
            <legend><%= T"Call Log" %></legend>
            <%= ui_helper.createTable(calllog_columns, calllog_data, calllog_options) %>
        </fieldset>
        <fieldset>
            <center>
                <%= ui_helper.createSimpleButton(T"Clear call logs", "icon-bolt", clear_call_log)%>
            </center>
        <fieldset>
            <legend><%= T"Call Statistics" %></legend>
            <%= ui_helper.createTable(stats_columns, stats_data, stats_options) %>
        </fieldset>
        </fiedset>
   </form>
</div>
<%= ui_helper.createFooter() %>

