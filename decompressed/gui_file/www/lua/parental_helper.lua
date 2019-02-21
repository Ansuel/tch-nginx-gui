local M = {}
-- Localization
gettext.textdomain('webui-core')

--local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local wifitod_path = "rpc.wifitod."
local accesscontroltod_path = "uci.tod.host."
local format = string.format
local uinetwork = require("web.uinetwork_helper")
local string = string
local tonumber = tonumber
local r_hosts_ac
local ngx = ngx
local vQTN = post_helper.validateQTN
local gAV = post_helper.getAndValidation

local function setlanguage()
    gettext.language(ngx.header['Content-Language'])
end

local function hosts_ac_ip2mac(t)
  if not t then return nil end
  for k,v in pairs(t) do
      local mac = string.match(k, "%[%s*([%x:]+)%s*%]")
      if mac then
         t[k] = mac
      end
  end
  return t
end

local function revert_kv(t)
  local nt = {}
  if type(t) ~= "table" then return nt end
  for k,v in pairs(t) do
      nt[v] = k
  end
  return nt
end

function M.get_hosts_ac()
  -- convert auto-complete table from IP to MAC
  return hosts_ac_ip2mac(uinetwork.getAutocompleteHostsListIPv4())
end

local function validateTime(value, object, key)
    local timepattern = "^(%d+):(%d+)$"
    local time = { string.match(value, timepattern) }
    if #time == 2 then
       if object["start_time"] == object["stop_time"] then
          return nil, T"Start and Stop time cannot be the same"
       end
       local hour = tonumber(time[1])
       local min = tonumber(time[2])
       if hour < 0 or hour > 23 then
          return nil, T"Invalid hour, must be between 0 and 23"
       end
       if min < 0 or min > 59 then
          return nil, T"Invalid minutes, must be between 0 and 59"
       end
       if key == "stop_time" then
          local start = string.gsub(string.untaint(object["start_time"]),":","")
          local stop = string.gsub(string.untaint(object["stop_time"]),":","")
          if tonumber(start) > tonumber(stop) then
             return nil, T"The time range is incorrect"
          end
       end
       return true
    else
       return nil, T"Invalid time (must be hh:mm)"
    end
end

local gVIC = post_helper.getValidateInCheckboxgroup
local gVIES = post_helper.getValidateInEnumSelect
local vSIM = post_helper.validateStringIsMAC
local vB = post_helper.validateBoolean

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

local function getWeekDays(value, object, key)
    local getValidateWeekDays = gVIC(theWeekdays())
    local ok, msg = getValidateWeekDays(value, object, key)

    if not ok then
        return ok, msg
    end
    local canary
    local canaryvalue = ""
    for k,v in ipairs(object[key]) do
        if v == canaryvalue then
            canary = k
        end
    end
    if canary then
        table.remove(object[key], canary)
    end
    return true
end

local function tod_sort_func(a, b)
  return a["id"] < b["id"]
end

function M.mac_to_hostname(mac)
  local hostname = ""
  if not mac then return hostname end
  local dev_detail_info = r_hosts_ac[mac]
  if dev_detail_info then
     hostname = string.match(dev_detail_info, "(%S+)%s+%(") or "Unknown-"..mac
  else
     hostname = "Unknown-"..mac
  end
  return hostname
end

-- since tod_default.type is "mac", the "id" will be MAC, we try to convert it
-- to friendly name, otherwise, add "Unknown-" prefix.
local function tod_mac_to_hostname(tod_data)
  if type(tod_data) ~= "table" then
     return
  end
  for _,v in ipairs(tod_data) do
      -- index is '2' due to in tod_columns, the one header = "Hostname" is 2.
      v[2] = M.mac_to_hostname(string.untaint(v[2]))
  end
end

function M.getTod()
  setlanguage()

  local todmodes = {
    { "allow", T"Allow" },
    { "block", T"Block" },
  }

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
        header = T"Hostname",
        name = "id",
        param = "id",
        type = "text",
        readonly = true,
        attr = { input = { class="span3" } },
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
        header = T"Mode",
        name = "mode",
        param = "mode",
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
        attr = { input = { class="span1" } },
    }, --[6]
    {   -- NOTE: don't foget update M.getTod() when change position
        header = "", --T"ToD",
        legend = T"Time of day access control",
        name = "timeofday",
        --param = "enabled",
        type = "aggregate",
        synthesis = nil, --tod_aggregate,
        subcolumns = {
            {
                header = T"Enabled",
                name = "enabled",
                param = "enabled",
                type = "switch",
                default = "1",
                attr = {switch = { class="inline" } },
            },
            {   -- NOTE: don't foget update M.getTod() when change position
                header = T"MAC address",
                name = "id",
                param = "id",
                type = "text",
                attr = { input = { class="span2", maxlength="17"}, autocomplete=M.get_hosts_ac() },
            },
            {
                header = T"Mode",
                name = "mode",
                param = "mode",
                type = "select",
                values = todmodes,
                default = "allow",
                attr = { select = { class="span2" } },
            },
            {
                header = T"Start Time",
                name = "start_time",
                param = "start_time",
                type = "text",
                default = "00:00",
                attr = { input = { class="span2", id="starttime", style="cursor:pointer;" } },
            },
            {
                header = T"Stop Time",
                name = "stop_time",
                param = "stop_time",
                type = "text",
                default = "23:59",
                attr = { input = { class="span2", id="stoptime", style="cursor:pointer;" } },
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

  local tod_valid = {
    ["mode"]        = gVIES(todmodes),
    ["start_time"]  = validateTime,
    ["stop_time"]   = validateTime,
    ["weekdays"]    = getWeekDays,
    ["enabled"]     = vB,
    ["id"]          = gAV(vSIM,vQTN)
  }

  local tod_default = {
    ["type"] = "mac",
  }

  local host_ac = M.get_hosts_ac()
  -- hot-update hostname autocomplete list when refresh page each time
  tod_columns[7].subcolumns[2].attr.autocomplete = host_ac
--[[
example:
  r_hosts_ac = {
                 ["00:13:46:e7:4a:a4"] = "BJNGDRND00757 (10.0.0.78) [00:13:46:e7:4a:a4]",
                 ["d4:be:d9:92:99:51"] = "10.0.0.202 [d4:be:d9:92:99:51]",
               }
--]]
  r_hosts_ac = revert_kv(host_ac)

  return {
    columns = tod_columns,
    valid   = tod_valid,
    default = tod_default,
    sort_func = tod_sort_func,
    mac_to_hostname = tod_mac_to_hostname,
  }
end
function M.getTodwifi()
  setlanguage()

  local wifi_list = {
	{"",T"All"},
  }
  
  for i,v in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
	local radio = string.match(v.path, "rpc%.wireless%.ap%.@([^%.]+)%.")
	local ssid = proxy.get("rpc.wireless.ap.@"..radio..".ssid") and proxy.get("rpc.wireless.ap.@"..radio..".ssid")[1].value
	local name = proxy.get("rpc.wireless.ssid.@"..ssid..".ssid") and proxy.get("rpc.wireless.ssid.@"..ssid..".ssid")[1].value
	wifi_list[#wifi_list+1] = { radio , name }
  end
  
  local wifimodes = {
    { "on", T"On" },
    { "off", T"Off" },
  }

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
        header = T"Access Point",
        name = "ap",
        param = "ap",
        type = "text",
		readonly = true,
        attr = { input = { class="span3" } },
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
        header = T"AP State",
        name = "mode",
        param = "mode",
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
        attr = { input = { class="span1" } },
    }, --[6]
    {   -- NOTE: don't foget update M.getTod() when change position
        header = "", --T"ToD",
        legend = T"Time of day wireless control",
        name = "timeofday",
        --param = "enabled",
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
            --[[{   -- NOTE: don't foget update M.getTod() when change position
                header = T"Hostname",
                name = "id",
                param = "id",
                type = "text",
                attr = { input = { class="span2", maxlength="17"}, autocomplete=M.get_hosts_ac() },
            },--]]
			{
				header = T"Access Point",
				name = "ap",
				param = "ap",
				type = "select",
                values = wifi_list,
				attr = { input = { class="span2" } },
			}, --[2]
            {
                header = T"AP State",
                name = "mode",
                param = "mode",
                type = "select",
                values = wifimodes,
                default = "on",
                attr = { select = { class="span2" } },
            },
            {
                header = T"Start Time",
                name = "start_time",
                param = "start_time",
                type = "text",
                default = "00:00",
                attr = { input = { class="span2", id="starttime", style="cursor:pointer;" } },
            },
            {
                header = T"Stop Time",
                name = "stop_time",
                param = "stop_time",
                type = "text",
                default = "23:59",
                attr = { input = { class="span2", id="stoptime", style="cursor:pointer;" } },
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

  local tod_valid = {
    ["mode"]        = gVIES(wifimodes),
    ["start_time"]  = validateTime,
    ["stop_time"]   = validateTime,
    ["weekdays"]    = getWeekDays,
    ["enabled"]     = vB,
    --["id"]          = vSIM,
  }

--[[  local tod_default = {
    --["type"] = "mac",
  }]]--


  return {
    columns = tod_columns,
    valid   = tod_valid,
    days    = theWeekdays(),
    --default = tod_default,
    --sort_func = tod_sort_func,
  }
end

-- function that can be used to compare and find whether the rule is duplicate or overlap
-- @param #oldTODRules have the rules list of existing tod
-- @param #newTODRule have the new rule which is going to be add in tod
-- @return #boolean or nil+error message if the rule is duplicate or overlap
function M.compareTodRule(oldTODRules, newTODRule)
  local newStart, newEnd, newDay
  local oldStart, oldEnd, oldDay
  local overlap
  local currentEditIndex = tonumber(ngx.req.get_post_args().index)
  for _,newrule in ipairs(newTODRule) do
    newStart = newrule.start_time
    newEnd = newrule.stop_time
    newDay = newrule.weekdays
    for oldIndex,oldrule in ipairs(oldTODRules) do
      oldStart = oldrule.start_time
      oldEnd = oldrule.stop_time
      oldDay = oldrule.weekdays
      local duplicate = false
      for _,oldWeekDay in ipairs(oldDay) do
        for _,newWeekDay in ipairs(newDay) do
          if oldWeekDay == newWeekDay then
            duplicate = true
          else
            if (oldWeekDay == "All" and newWeekDay == "All") or (oldWeekDay == "All" and #newWeekDay > 0) or (newWeekDay == "All" and #oldWeekDay > 0) then
              duplicate = true
            end
            break
          end
        end
      end
      if duplicate == true and oldIndex ~= currentEditIndex then
        if(newStart == oldStart and newEnd == oldEnd) then
          return nil, T"Duplicate contents are not allowed"
        else
          -- Determine whether two time ranges overlap, considering the existing schedule time is "03:00~07:00"
          -- cond A: (start and end within range): schedule request examples 1)04:00~05:00 2)03:00~05:00 3)04:00~07:00
          if (newStart >= oldStart and newEnd <= oldEnd) then
            overlap = true
            break
          -- cond B: (start out of range): schedule request examples 1)02:00~05:00 2)01:00~03:00 3)02:00~07:00
          elseif (newStart <= oldStart and newEnd >= oldStart and newEnd <= oldEnd) then
            overlap = true
            break
          -- cond C: (end out of range): schedule request examples 1)02:00~08:00 2)03:00~09:00 3)01:00~07:00
          elseif (newStart <= oldStart and newEnd >= oldEnd) then
            overlap = true
            break
          -- cond D: (start and end out of range): schedule request examples 1)04:00~09:00 2)03:00~10:00 3)07:00~09:00
          elseif (newStart >= oldStart and newStart <= oldEnd and newEnd >= oldEnd) then
            overlap = true
            break
          end
        end
      end
    end
    if overlap then
      return nil, T"Overlap contents are not allowed"
    end
  end
  return true
end

-- function to retrieve existing wifitod rules list
-- @return wifitod rules list
function M.getWifiTodRuleLists()
  local wifiToDRules = proxy.get("rpc.wifitod.")
  local wifiTodRuleList = content_helper.convertResultToObject("rpc.wifitod.", wifiToDRules)
  local oldTodRules = {}
  for _, rule in pairs(wifiTodRuleList) do
    oldTodRules[#oldTodRules + 1] = {}
    oldTodRules[#oldTodRules].rule_name = rule.name
    oldTodRules[#oldTodRules].start_time = rule.start_time
    oldTodRules[#oldTodRules].stop_time = rule.stop_time
    oldTodRules[#oldTodRules].enable = rule.mode
    oldTodRules[#oldTodRules].index = rule.paramindex
    oldTodRules[#oldTodRules].weekdays = {}
    local weekdaysPath = format("rpc.wifitod.%s.weekdays.",rule.paramindex)
    local daysList = proxy.get(weekdaysPath)
    daysList = content_helper.convertResultToObject(weekdaysPath, daysList)
    --The DUT will block/allow all the time if none of the days are selected
    if (#daysList == 2) then
      oldTodRules[#oldTodRules].weekdays[#oldTodRules[#oldTodRules].weekdays+1] = "All"
    else
      for _, day in pairs(daysList) do
        if day.value ~= "" then
          oldTodRules[#oldTodRules].weekdays[#oldTodRules[#oldTodRules].weekdays+1] = day.value
        end
      end
    end
  end
  return oldTodRules
end

-- function to retrieve existing access control tod rules list
-- @param #mac_id have the mac name of new tod rule request
-- @return access control tod rules list
function M.getAccessControlTodRuleLists(mac_id)
   local rulePath = content_helper.convertResultToObject(accesscontroltod_path, proxy.get(accesscontroltod_path))
   local oldTodRules = {}
   for _,rule in pairs(rulePath) do
     oldTodRules[#oldTodRules + 1] = {}
     oldTodRules[#oldTodRules].rule_name = rule.name
     oldTodRules[#oldTodRules].start_time = rule.start_time
     oldTodRules[#oldTodRules].stop_time = rule.stop_time
     oldTodRules[#oldTodRules].enable = rule.mode
     oldTodRules[#oldTodRules].index = rule.paramindex
     oldTodRules[#oldTodRules].weekdays = {}
     if (rule["id"] == mac_id) then
       local weekdaysPath = format("uci.tod.host.%s.weekdays.",rule.paramindex)
       local daysList = content_helper.convertResultToObject(weekdaysPath, proxy.get(weekdaysPath))
       --The DUT will block/allow all the time if none of the days are selected
       if (#daysList == 2) then
         oldTodRules[#oldTodRules].weekdays[#oldTodRules[#oldTodRules].weekdays+1] = "All"
       else
         for _,day in pairs(daysList) do
           if day.value ~= "" then
             oldTodRules[#oldTodRules].weekdays[#oldTodRules[#oldTodRules].weekdays+1] = day.value
           end
         end
       end
     end
   end
   return oldTodRules
end

-- function that can be used to validate tod rule
-- @param #value have the value of corresponding key
-- @param #object have the POST data
-- @param #key validation key name
-- @param #todRequest have the string value of request tod rule
-- @return #boolean or nil+error message
function M.validateTodRule(value, object, key, todRequest)
  local oldTODRules
  if todRequest == "Wireless" then
    oldTODRules = M.getWifiTodRuleLists(object["id"])
  elseif todRequest == "AccessControl" then
    oldTODRules = M.getAccessControlTodRuleLists(object["id"])
  else
    return nil, T"Function input param is missing"
  end
  -- adding first access control tod rule so, validation is not required
  if #oldTODRules == 0 then
    return true
  end
  local newTODRule = {}
  newTODRule[#newTODRule + 1] = {}
  newTODRule[#newTODRule].rule_name = object["name"]
  newTODRule[#newTODRule].start_time = object["start_time"]
  newTODRule[#newTODRule].stop_time = object["stop_time"]
  newTODRule[#newTODRule].enable = object["mode"]
  newTODRule[#newTODRule].index = object["paramindex"]
  newTODRule[#newTODRule].weekdays = {}
  --The DUT will block/allow all the time if none of the days are selected
  if (#value == 2) then
    newTODRule[#newTODRule].weekdays[#newTODRule[#newTODRule].weekdays+1] = "All"
  else
    -- index start with 3 because userdata is reserved index 1 and 2
    for index = 3, #value do
      newTODRule[#newTODRule].weekdays[#newTODRule[#newTODRule].weekdays+1] = value[index]
    end
  end
  return M.compareTodRule(oldTODRules, newTODRule)
end

-- function that can be used to get the current day(Ex: Mon, Tue) and current time(HH:MM)
-- @return #string current day and current time
function M.getCurrentDayAndTime()
  local currDate = os.date("%a %H:%M")
  return currDate:match("(%S+)%s(%S+)")
end

return M
