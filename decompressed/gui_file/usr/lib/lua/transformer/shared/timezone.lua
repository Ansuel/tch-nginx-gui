local uci_helper = require("transformer.mapper.ucihelper")
local get_from_uci = uci_helper.get_from_uci
local format = string.format
local tonumber = tonumber
local M = {}
local tostring = tostring
local os = os

-- make the input date from user valid
local function isValidDay(month, day)
  local validDay = day
  if tonumber(month)==1 or tonumber(month)==3 or tonumber(month)==5 or tonumber(month)==7 or
     tonumber(month)==8 or tonumber(month)==10 or tonumber(month)==12 then
    if day>31 then
      validDay = day-7
    end
  else
    if tonumber(month)~=2 then
      if day>30 then
        validDay = day-7
      end
    else
      if day>28 then
        validDay = day-7
      end
    end
  end
  return validDay
end

-- calculate the number of day in the month with the POSIX string
local function getDayNeeded(value)
  local curYear = os.date("%Y")
  local curDay
  -- the format of value is like M10.5.0, which means the 10th month(Oct.), the 5th Sun.
  local curMonth, order, day = value:match("M([^.]+).([^.]+).([^.]+)")
  if not (tonumber(order) >= 1 and tonumber(order) <= 5) or not (tonumber(day) >= 0 and tonumber(day) <= 6) then
    return nil, "Invalid value"
  else
    -- we need to know the first day in this month is wday, sothat we can calculate the 5th Sun. is wday
    local wday = os.date("*t", os.time{year=curYear, month=curMonth, day=1}).wday - 1
    -- this month's first day is not Sun. below is the way to calculate the number of day in this month
    if wday~=0 then
      -- find the number of the day in the month
      curDay = 7*tonumber(order)-wday+1+tonumber(day)
      curDay = isValidDay(curMonth, curDay)
    else
      curDay = 7*(tonumber(order)-1)+1+tonumber(day)
      curDay = isValidDay(curMonth, curDay)
    end
    -- the day is earlier than 10, we need to add 0 before it such as 9 -> 09
    if tonumber(curDay)<10 then
      curDay = "0" .. tonumber(curDay)
    end
    return curDay
  end
end

-- Allowed TimeZone Format : <std>offset[<dst>[offset][,start[/time],end[/time]]]
-- Example : CET+1:59CEST-5:0,M3.5.0/24:59:59,M10.5.0/24:59:59
-- Example : CET-1:59CEST5:0,M3.5.0/5:5,M10.5.0/5
-- Time Format : hh:mm:ss(00:00:00)
-- Here in TimeZone Format time part is optional , if time(hh:mm:ss) is present in timeZone format
-- then below function validates whether the time is valid or not
-- Function rebuilds the time value by the format of "00:00:00", if hour, minute, second are less than 10
-- Example : 5:4:56 -> 05:04:56

local function hourFormat(time)
  local t = time
  local _, count = t:gsub(":",":")
  if count > 2 then
    return nil
  end
  -- separate the time value into hour and minute and sec
  local hour, min, sec
  if count == 2 then
    hour, min, sec = time:match("^(%d+):(%d+):(%d+)$")
  elseif count == 1 then
    hour, min = time:match("^(%d+):(%d+)$")
    sec = "00"
  else
    hour = time:match("^(%d+)$")
    min = "00"
    sec = "00"
  end
  -- check hour, minute and second are decimal numbers with specified limits
  -- the hour, minute, second are less than 10, need to add 0 before it such as 9 -> 09
  time = nil
  if hour and min and sec then
    hour = tonumber(hour)
    min  = tonumber(min)
    sec  = tonumber(sec)
    if hour >= 0 and hour <= 23 and min >= 0 and min <= 59 and sec >= 0 and sec <= 59 then
      hour = hour < 10 and "0" .. hour or hour
      min  = min < 10 and "0" .. min or min
      sec  = sec < 10 and "0" .. sec or sec
      -- rebuild the value format into "00:00:00"
      time = hour .. ":" .. min .. ":" .. sec
    end
  end
  return time
end

-- get value of DaylightSavingsStart and DaylightSavingsEnd from user input when setting LocalTimeZoneName which is POSIX format
function M.getStartEndDay(value)
  -- separate the POSIX string into localtimezone daylightstarttime and daylightendtime
  local time = value
  local _, count = time:gsub(",",",")
  if count ~= 2 then
    return nil, "Invalid value"
  else
    local startTime, endTime = value:match("[^,]+,([^,]+),([^,]+)")
    if not(startTime and endTime) then
      return nil, "Invalid value"
    end
    local startHour, endHour = "00:00:00", "00:00:00"
    local startDaylightTime, endDaylightTime
    -- judge if there is hour, minute value followed by the daylightstarttime or daylightendtime
    time = startTime
    _, count = time:gsub("/","/")
    if count > 1 then
      return nil, "Invalid value"
    end
    -- separate the month, day value from hour, minute value
    if count == 1 then
      startTime, startHour = startTime:match("([^/]+)/([^/]+)")
    end
    if not startTime then
      return nil, "Invalid value"
    end
    local startMonth, startOrder, startDay = startTime:match("M([^.]+)%.([^.]+)%.([^.]+)")
    if not (tonumber(startMonth) and tonumber(startOrder) and tonumber(startDay)) or not (tonumber(startMonth) >= 1 and tonumber(startMonth) <= 12) then
      return nil, "Invalid value"
    end
    local curStartYear = os.date("%Y")
    if tonumber(startMonth)<10 then
      startMonth = "0" .. tonumber(startMonth)
    end
    local curStartMonth = startMonth
    local curStartDay = getDayNeeded(startTime)
    if not curStartDay then
      return nil, "Invalid value"
    end
    local curStartTime = curStartYear .. "-" .. curStartMonth .. "-" .. curStartDay
    local curStartHour = hourFormat(startHour)
    if not curStartHour then
      return nil, "Invalid value"
    end
    -- gather the year,month,day,hour,minute,second value
    startDaylightTime = curStartTime .. "T" .. curStartHour .. "Z"
    -- judge if there is hour, minute value followed by the daylightstarttime or daylightendtime
    time = endTime
    _, count = time:gsub("/","/")
    if count > 1 then
      return nil, "Invalid value"
    end
    -- separate the month, day value from hour, minute value
    if count == 1 then
      endTime, endHour = endTime:match("([^/]+)/([^/]+)")
    end
    if not endTime then
      return nil, "Invalid value"
    end
    local endMonth, endOrder, endDay = endTime:match("M([^.]+)%.([^.]+)%.([^.]+)")
    if not(tonumber(endMonth) and tonumber(endOrder) and tonumber(endDay)) then
      return nil, "Invalid value"
    end
    local curEndYear = os.date("%Y")
    if tonumber(endMonth)<10 then
      endMonth = "0" .. tonumber(endMonth)
    end
    local curEndMonth = endMonth
    local curEndDay = getDayNeeded(endTime)
    if not curEndDay then
      return nil, "Invalid value"
    end
    local curEndTime = curEndYear .. "-" .. curEndMonth .. "-" .. curEndDay
    local curEndHour = hourFormat(endHour)
    if not curEndHour then
      return nil, "Invalid value"
    end
    -- gather the year,month,day,hour,minute,second value
    endDaylightTime = curEndTime .. "T" .. curEndHour .. "Z"
    return startDaylightTime, endDaylightTime
  end
end

function M.parse_dateTime(dateTime)
  local p = "(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)"
  local year, month, day, hours, mins, secs = dateTime:match(p)
  return tonumber(year), tonumber(month), tonumber(day), tonumber(hours), tonumber(mins), tonumber(secs)
end

local function calculate_JulianDay(dateTime)
    local my_year, my_month, my_day = M.parse_dateTime(dateTime)
    local Julian = os.date("*t", os.time{year=my_year, month=my_month, day=my_day}).yday - 1
    return Julian
end

local function checkHourMinLimits(time)
  -- the time format contains minutes value such as 2:45
  -- separate the time value into hour and minute
  local hour, min = time:match("(%d+):(%d+)$")
  -- the time format contains only hour value such as 2
  hour = hour or time:match("(%d+)$")
  local limit = false
  -- check hour and minute are decimal numbers with specified limits
  if hour and (tonumber(hour) >= 0 and tonumber(hour) <= 23) then
    limit = true
  end
  if min and not (tonumber(min) >= 0 and tonumber(min) <= 59) then
    limit = false
  end
  return limit
end

-- get the value of localtimezonename to fetch the value of localtimezone and offset time
function M.getLocaltimezoneWithoutSDTDST(value)
  local timeZoneFlag = false
  local timezoneValue, dsttimezoneValue = value:match("^%a+([-+]?%d+:?%d*)%a+([-+]?%d+:?%d*)$")
  if not timezoneValue then
    timezoneValue, dsttimezoneValue = value:match("^%a+([-+]?%d+:?%d*)%a+$")
  end
  if not timezoneValue then
    timezoneValue = value:match("^%a+([-+]?%d+:?%d*)$")
  end
-- Added to accept plain characters with out any numbers(UTC). Enabled the flag to skip checkHourMinLimits
  if not timezoneValue then
    timezoneValue = value:match("^%a+")
    timeZoneFlag = true
  end
  if not timezoneValue then
    return nil, "Invalid value"
  end
  if not timeZoneFlag and not checkHourMinLimits(timezoneValue) then
    return nil, "Invalid value"
  end
  if dsttimezoneValue then
    if not checkHourMinLimits(dsttimezoneValue) then
      return nil, "Invalid value"
    end
  end
  return timezoneValue, dsttimezoneValue
end

-- used for checking if the dst time is exist
local function parseLocaltimezonename(localTimeZoneName_uci)
  local localtimezonename = get_from_uci(localTimeZoneName_uci)
  local localtimezoneValue, timezoneValue, dsttimezoneValue
  local timezoneValuePos = string.find(localtimezonename,",")
  if timezoneValuePos~=nil then
    localtimezoneValue = string.sub(localtimezonename, 1, timezoneValuePos-1)
    timezoneValue, dsttimezoneValue = M.getLocaltimezoneWithoutSDTDST(localtimezoneValue)
  else
    timezoneValue, dsttimezoneValue = M.getLocaltimezoneWithoutSDTDST(localtimezoneValue)
  end
  return timezoneValue, dsttimezoneValue
end

function M.getTZString(localTimeZoneName_uci, localTimeZone_uci, dlsUsed_uci, dlsStart_uci, dlsStop_uci)
  -- etc/TZ is in the form of "<std>offset[<dst>[offset][,start[/time],end[/time]]]
  -- if no daylightsavings used: <std>offset
  --              <std>  will be localTimeZone_uci, form <[+-]hhmm>
  --              offset will be localTimeZone_uci, form [+-]hh:mm
  --                  e.g.:<+0700>07:00
  -- if daylightsavings is used: stdoffsetdst[offset],start[/time],end[/time]
  --              <std>  will be localTimeZone_uci, form <[+-]hhmm>
  --              offset will be localTimeZone_uci * (-1), form [+-]hh:mm
  --              <dst>  will be localTimeZone_uci the value of dsttimezoneValue or (+1)
  --              start  will be the zero-based Julian day of dlsStart_uci
  --              stop   will be the zero-based Julian day of dlsStop_uci
  --                  e.g.:<+0700>07:00<0800>,100/02:00:00,200/03:00:00

  -- construct <std>
  local localtimezone = get_from_uci(localTimeZone_uci)
  local std_sign, std_hours, std_minutes = localtimezone:match("([%+%-]?)(%d+):(%d%d)")
  if std_hours == nil then  -- localtimezone has not been filled in yet
    std_sign = "+"
    std_hours = "00"
    std_minutes = "00"
  end
  std_hours = std_sign..std_hours
  local std_str = format("<%+03d%s>", std_hours, std_minutes)

  -- construct offset
  local offset_hours = tonumber(std_hours) * (-1)
  local offset_str = format("%+03d:%s", offset_hours, std_minutes)

  local tz_info
  local dls_used = get_from_uci(dlsUsed_uci)
  if dls_used == "1" then
    -- construct <dst>
    local dst_hours = tonumber(std_hours) + 1
    local dst_str = format("<%+03d%s>", dst_hours, std_minutes)
    -- if the first part of localtimezonename is looking like "ABC9:30DEF-10:20" which is ending with the time of DST
    local _, dstExist = parseLocaltimezonename(localTimeZoneName_uci)
    -- the dsttimezoneValue is exist not used std_hour+1
    if dstExist~=nil then
      local posDst = string.find(dstExist,":")
      if posDst==nil then
        -- make the time string legal
        dstExist = tostring(dstExist)..":00"
      end
      local dst_sign, dst_hours, dst_minutes = dstExist:match("([%+%-]?)(%d+):(%d%d)")
      if dst_hours == nil then
        dst_sign = "+"
        dst_hours = "00"
        dst_minutes = "00"
      end
      dst_hours = dst_sign..dst_hours
      dst_str = format("<%+03d%s>", dst_hours, dst_minutes)
    end
     -- construct <std>offset<dst>
    local tzname_uci_str = format("%s%s%s", std_str, offset_str, dst_str)
    -- calculate all daylightsavings parameters
    local dlsStart_time = get_from_uci(dlsStart_uci)
    local dlsStop_time = get_from_uci(dlsStop_uci)
    if (dlsStart_time == "") then dlsStart_time = "1970-01-01T00:00:00" end
    if (dlsStop_time == "") then dlsStop_time = "1970-01-01T00:00:00" end
    local _, _, _, dls_start_hour, dls_start_min = M.parse_dateTime(dlsStart_time)
    local _, _, _, dls_stop_hour, dls_stop_min = M.parse_dateTime(dlsStop_time)
    local dlsStart, dlsStop
    dlsStart = calculate_JulianDay(dlsStart_time)
    dlsStop  = calculate_JulianDay(dlsStop_time)
    tz_info = format("%s,%d/%d:%d,%d/%d:%d\n", tzname_uci_str, dlsStart, dls_start_hour, dls_start_min, dlsStop, dls_stop_hour, dls_stop_min)
  else  -- dls is not used
    tz_info = format ("%s%s\n", std_str, offset_str)
  end
  return tz_info
end

return M
