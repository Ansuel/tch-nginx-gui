<%-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")

local ngx = ngx
local string, table = string, table
local concat, insert = table.concat, table.insert
local ipairs = ipairs
local tonumber = tonumber
local match, gmatch, format, find, untaint = string.match, string.gmatch, string.format, string.find, string.untaint
local untaint_mt = require("web.taint").untaint_mt
local session = ngx.ctx.session

local validateTime = post_helper.validateTime
local validateBoolean = post_helper.validateBoolean
local optionallyValidate = post_helper.getOptionalValidation
local getRandomKey = post_helper.getRandomKey
local gVIES = post_helper.getValidateInEnumSelect

local tod_timer_path = "uci.tod.timer."
local tod_action_path = "uci.tod.action."
local tod_voicednd_path = "uci.tod.voicednd."

local profileCount = 0
local profileName = {
  {"All", T"All"},
}
local ringing_status_map = setmetatable({
  ["off"] = T"Off",
  ["on"] = T"On"
}, untaint_mt)

--To get the number of profile and list of profile Number
local profileNumber = proxy.get("rpc.mmpbx.sip_profile.")
profileNumber = content_helper.convertResultToObject("rpc.mmpbx.sip_profile.",profileNumber)
for _,v in pairs(profileNumber) do
  profileCount = profileCount + 1
  local name = string.sub(v.paramindex, 2)
  profileName[#profileName+1]= { name , v.uri }
end

--when timer data is not defined in config, then whole rule will be deleted
for i=1 , profileCount do
  local timer_path = "uci.tod.action.@dnd_profile" ..i..".timers.@1.value"
  local timer_data = content_helper.convertResultToObject(timer_path, proxy.get(timer_path))
  if not next(timer_data) then
    proxy.del("uci.tod.action.@dnd_profile" ..i.. ".")
    proxy.del("uci.tod.voicednd.@profile" ..i..".")
  end
end

-- when the timer in the action section of dnd rule is empty, whole rule will be deleted.
local voice_dnd = content_helper.convertResultToObject(tod_voicednd_path, proxy.get(tod_voicednd_path))
for k, v in pairs (voice_dnd) do
  local index = match(v.paramindex, "^@voicednd(%S+)")
  local dnd_timer = proxy.get(format("uci.tod.action.@action%s.timers.", index))
  if dnd_timer[1].value == "" then
     proxy.del(format("uci.tod.action.@action%s." , index))
     proxy.del(format("uci.tod.voicednd.@voicednd%s.", index))
     proxy.apply()
  end
end

local function theWeekdays()
  return {
    { "Mon", T"Mon." },
    { "Tue", T"Tue." },
    { "Wed", T"Wed." },
    { "Thu", T"Thu." },
    { "Fri", T"Fri." },
    { "Sat", T"Sat." },
    { "Sun", T"Sun." },
  }
end

local function getTodVoiceDnd()
  -- ToD forwarding rules
  local tod_columns = {
    {
        header = T"Status",
        name = "enabled",
        param = "enabled",
        type = "light",
        readonly = true,
        attr = { input = { class="span1" } },
    }, --[1]
    {
        header = T"Number",
        name = "profile",
        param = "profile",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[2]
    {
        header = T"Start Time",
        name = "start_time",
        param = "start_time",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[3]
    {
        header = T"Stop Time",
        name = "stop_time",
        param = "stop_time",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[4]
    {
        header = T"Ringing",
        name = "profile",
        param = "profile",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[5]
    {
        header = T"Day of week",
        name = "weekdays",
        param = "weekdays",
        values = theWeekdays(),
        type = "checkboxgroup",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[6]
 {
        header = "", --T"ToD",
        legend = T"Add a New Ringing Schedule",
        name = "timeofday",
        type = "aggregate",
        synthesis = nil, --tod_aggregate,
        subcolumns = {
            {
                header = T"Enabled",
                name = "enabled",
                param = "enabled",
                type = "switch",
                default = "1",
                attr = { switch= { class="inline" } },
            },
            {
                header = T"Number",
                name = "profile",
                param = "profile",
                type = "select",
                values = profileName,
                default = "All",
                attr = { select = { class="span2" } },
            },
            {
                header = T"Start Time",
                name = "start_time",
                param = "start_time",
                type = "text",
                default = "00:00",
                attr = { input = { class="span2", id="starttime", style="cursor:pointer; background-color:white" } },
            },
            {
                header = T"Stop Time",
                name = "stop_time",
                param = "stop_time",
                type = "text",
                default = "23:59",
                attr = { input = { class="span2", id="stoptime", style="cursor:pointer; background-color:white" } },
            },
            {
                header = T"Day of week",
                name = "weekdays",
                param = "weekdays",
                type = "checkboxgroup",
                values = theWeekdays(),
                attr = { checkbox = { class="inline" } },
            },
        }
    }, --[7]
  }

  return {
    columns = tod_columns,
    days    = theWeekdays(),
  }
end

local tod = getTodVoiceDnd()
local tod_columns = tod.columns
local validDays = post_helper.getValidateInEnumSelect(tod.days)

local rngshdContent = {
  todStatus = "uci.tod.todvoicednd.enabled",
  profileStatus = "uci.tod.todvoicednd.ringing",
}

local rngshdValidation = {
  todStatus = post_helper.validateBoolean,
  profileStatus = post_helper.validateNonEmptyString,
}

-- validates days (Mon...Sun)
-- @param #table value have the value of corresponding key
-- @return #boolean or nil+error message
local function validateWeekdays(value)
  if not value then
    return nil, T"Invalid day"
  end
  for i, v in ipairs(value) do
    if not validDays(v) then
      return nil, T"Invalid day"
    end
  end
  return true
end

local tod_options = {
  tableid     = "tod",
  basepath    = "uci.tod.voicednd.",
  createMsg   = T"Add New Rule",
  canAdd      = true,
  canDelete   = true,
  canApply    = true,
  canEdit     = true,
  objectName  = "action"..getRandomKey(),
  addNamedObject  = true
}

local function daysOverlap(days1, days2)
  days1 = concat(days1, " ")
  for _, day in ipairs(days2) do
    if find(days1, day) then
      return true
    end
  end
  return nil
end

local function validate_voicednd(postcontent, timer_data)
  local todData = {
    enable      = postcontent.enable,
    profile     = postcontent.profile,
    start_time  = postcontent.start_time,
    stop_time   = postcontent.stop_time,
    weekdays    = postcontent.weekdays,
  }
  local todValidations = {
    enable      = validateBoolean,
    profile     = gVIES(profileName),
    start_time  = validateTime,
    stop_time   = validateTime,
    weekdays    = optionallyValidate(validateWeekdays), -- weekdays can be empty if user didn't select any day
  }

  local success, errmsg = content_helper.validateObject(todData, todValidations)
  if not success then
    return nil, errmsg
  end

  -- day/time overlap validation
  if postcontent.start_time >= postcontent.stop_time then
    return nil, T"Start time should be less than Stop time."
  end
  for i, v in ipairs(timer_data) do
    if i ~= postcontent.index then
      if postcontent.profile == v.profile or v.profile == "All" or postcontent.profile == "All" then
        if daysOverlap(postcontent.weekdays, v.days) and -- days overlap
          postcontent.start_time <= v.stop_time and
          postcontent.stop_time >= v.start_time then -- time overlaps
          return nil, T"Overlapping times are not allowed."
        end
      end
    end
  end

  return true
end

local function onAdd(success, content, onModify)
  local index = success:match("action(.+)")
  if onModify then
    index = success:match("voicednd(.+)")
  end
  local setTable = {}

  if type(content.weekdays) ~= "table" then
    if content.weekdays == "" then
      content.weekdays = {}
      for _, v in ipairs(tod.days) do
        insert(content.weekdays, v[1])
      end
    else
      content.weekdays = {untaint(content.weekdays)}
    end
  else
    for i, v in ipairs(content.weekdays) do
      content.weekdays[i] = untaint(v)
    end
  end

  local valid, errmsg = validate_voicednd(content, session:retrieve("timer_data"))
  if not valid then
    tod_options.errmsg = errmsg
    return nil
  end

  if not onModify then
    proxy.add(tod_action_path .. "@" .. success .. ".timers.")
    proxy.add(tod_timer_path, "timer"..index)
    proxy.add(tod_voicednd_path, "voicednd"..index)
    proxy.add(tod_voicednd_path .."@voicednd"..index..".profile.")
  end

  content.weekdays = concat(content.weekdays, ",")

  content.start_time = format("%s:%s", content.weekdays, content.start_time)
  content.stop_time = format("%s:%s", content.weekdays, content.stop_time)

  setTable[format("%s@action%s.timers.@1.value", tod_action_path, index)] = "timer"..index

  setTable[format("%s@action%s.enabled", tod_action_path, index)] = content.enabled
  setTable[format("%s@action%s.script", tod_action_path, index)] = "voicedndscript"
  setTable[format("%s@action%s.object", tod_action_path, index)] = "voicednd.voicednd"..index

  setTable[format("%s@timer%s.start_time", tod_timer_path, index)] = content.start_time
  setTable[format("%s@timer%s.stop_time", tod_timer_path, index)] = content.stop_time
  setTable[format("%s@timer%s.name", tod_timer_path, index)] = "voicednd"

  setTable[format("%s@voicednd%s.profile.@1.value", tod_voicednd_path, index)] = content.profile
  proxy.set(setTable)
  proxy.apply()
  return true
end

local function onModify(index, content)
  proxy.set("uci.tod.todvoicednd.timerandactionmodified", "1")
  onAdd(index, content, true)
  return true
end

local function onDelete(success)
  local index = success:match("voicednd(.+)")
  proxy.set(format("uci.tod.action.@action%s.timers.@1.value", index), "")
  proxy.del(format("uci.tod.timer.@timer%s.", index))
  proxy.apply()
  return true
end

if ngx.var.request_method == "POST" then
  local postargs = ngx.req.get_post_args()
  postargs.index = tonumber(postargs.index) or -1
  local current_index = postargs.index
  local allowedIndexes = session:retrieve(tod_options.tableid .. ".allowedindexes") or {}
  current_index = allowedIndexes[current_index] and allowedIndexes[current_index].paramindex or -1

  if postargs.action == "TABLE-NEW" then
    tod_options.editing = -1
  elseif postargs.action == "TABLE-EDIT" then
    tod_options.editing = postargs.index
  elseif postargs.action == "TABLE-ADD" then
    current_index = proxy.add(tod_action_path, tod_options.objectName)
    local success = onAdd(current_index, postargs)
    if not success then
      proxy.del(tod_action_path .. "@" .. tod_options.objectName .. ".")
      tod_options.editing = -1
    end
  elseif postargs.action == "TABLE-MODIFY" then
    onModify(current_index, postargs)
  elseif postargs.action == "TABLE-DELETE" then
    onDelete(current_index)
  end
end

local ring_data, ring_helpmsg = post_helper.handleQuery(rngshdContent, rngshdValidation)
local tod_data, tod_index = content_helper.loadTableData(tod_options.basepath, tod_columns)

local tablesessionindexes = tod_options.tableid .. ".allowedindexes"
session:store(tablesessionindexes, tod_index)

local action_list = content_helper.convertResultToObject(tod_action_path, proxy.get(tod_action_path))
local timer_list = content_helper.convertResultToObject(tod_timer_path, proxy.get(tod_timer_path))
local voicednd_list = content_helper.convertResultToObject(tod_voicednd_path, proxy.get(tod_voicednd_path))
local ringingStatus = proxy.get("uci.tod.todvoicednd.ringing")[1].value
local timer_data = {}

--To filter out timer section created by ringing schedule rule
local dnd_timer = {}
for i, v in ipairs(timer_list) do
  if timer_list[i].name == "voicednd" then
    dnd_timer[#dnd_timer+1] = timer_list[i]
  end
end

--To filter out action section created by ringing schedule rule
local dnd_action = {}
--To filter out the action sections with no timer
local tod_without_timer = {}
for i, v in ipairs(action_list) do
  if action_list[i].script == "voicedndscript" then
    dnd_action[#dnd_action+1] = action_list[i]
  end
  if action_list[i]["timers.@1.value"] == "" then
    tod_without_timer[#tod_without_timer+1] = i
  end
end

for i = #tod_without_timer, 1, -1 do
  table.remove(tod_data, tod_without_timer[i])
  table.remove(tod_index, tod_without_timer[i])
  table.remove(action_list, tod_without_timer[i])
end

for i, v in ipairs(tod_data) do
  v[1] = dnd_action[i].enabled -- status
  local profile = voicednd_list[i]["profile.@1.value"]
  for _, profileNum in pairs(profileName) do --To get the profile number from profileName table
    if profileNum[1] == profile then
      profile = profileNum[2]
      break
    end
  end
  v[2] = profile  --profilenumber
  local days, start_time = dnd_timer[i].start_time:match("^(.-):(.+)$")
  v[3] = start_time -- start_time
  v[4] = dnd_timer[i].stop_time:match("^.-:(.+)$") -- stop_time
  v[5] = ringing_status_map[ringingStatus] -- ringingState
  v[6] = {} -- days
  for day in gmatch(days, "[^,]+") do
    insert(v[6], untaint(day))
  end
  -- Sub Columns
  v[7] = {
    [1] = v[1], -- status
    [2] = voicednd_list[i]["profile.@1.value"], -- profilename
    [3] = v[3], -- start_time
    [4] = v[4], -- stop_time
    [5] = v[6] -- days
  }
  timer_data[i] = {
    start_time = v[3],
    stop_time = v[4],
    days = v[6],
    profile = voicednd_list[i]["profile.@1.value"]
  }
end

session:store("timer_data", timer_data)

%>

<%=ui_helper.createHeader(T"Time of Day") %>
<%=ui_helper.createMessages(message_helper.popMessages()) %>

<div class="modal-body update">

<%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-tod.lp")
%>

  <form class="form-horizontal" method="post" action="/modals/tod_dnd-modal.lp">
    <legend><%= T"Ringing Schedule" %></legend>
    <%=ui_helper.createSwitch(T"Ringing Schedule", "todStatus", ring_data["todStatus"], nil, ring_helpmsg["todStatus"])%>
    <div id = "parent_switch""><%=ui_helper.createSwitch(T"During this time ringing is", "ringstate_enable", ring_data["profileStatus"]=="on" and '1' or'0', nil, ring_helpmsg["profileStatus"]) %></div>
    <%=ui_helper.createTable(tod_columns, tod_data, tod_options, nil, nil)%>
    <%if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action == "TABLE-NEW" or ngx.req.get_post_args().action == "TABLE-EDIT") then%>
      <script type="text/javascript">
        var warning = '<div class="control-group"><div style="padding-top: 12px;" class="controls"><span class="alert">'
                      +'<%= T"The Gateway will block/allow all the time if none of the days are selected" %></span></div></div>';
        $('#stoptime').parent().parent().after(warning);
      </script>
    <%end%>
    <input type="hidden" name="profileStatus" id="profileStatus" value= "<%=ring_data["profileStatus"] == 'off' and 'off' or 'on'%>">
  </form>
</div>

<script type="text/javascript">

    $(function () {
        var opt = {
            theme: 'android-ics light',
            display: 'bubble',
            mode: 'scroller',
            headerText: false,
            timeFormat: 'HH:ii',
            stepMinute: 15
        };
        $("#starttime").mobiscroll().time(opt);
        $("#stoptime").mobiscroll().time(opt);
    });
    $("#todStatus").val() == 0?$('#tod, #parent_switch, .btn-table-new').hide():$('#tod, #parent_switch, .btn-table-new').show();

    $('.switch').change(function(){
        $("#todStatus").val() == 0?$('#tod, #parent_switch, .btn-table-new').hide():$('#tod, #parent_switch, .btn-table-new').show();
    });
    $(".btn-table-add, .btn-table-modify").click(function() {
        // ui_helper adds dummy hidden checkbox if no checkboxes are checked. we don't need that.
        if ($("form .additional-edit input[name=weekdays]:visible:checked").length > 0) {
          $("form input[name=weekdays]:hidden").removeAttr("name");
        } else {
          // we need one checkbox when no checkboxes are checked.
          $("form input[name=weekdays]:hidden").removeAttr("name");
          $("form input[type=checkbox]:hidden:last").attr("name", "weekdays");
        }
    });

    // boolean value "0/1" is converted into "on/off" for matching uci params.
    $("#ringstate_enable").change(function(){
        $("#profileStatus").val(this.value==0?"off":"on");
    });
</script>
<%= ui_helper.createFooter() %>
