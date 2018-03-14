local M = {}

local commitapply = commitapply
local uciHelper = require("transformer.mapper.ucihelper")
local getFromUci = uciHelper.get_from_uci
local getAllFromUci = uciHelper.getall_from_uci
local setOnUci = uciHelper.set_on_uci
local sysBinding = { config="system", sectionname="scheduledreboot" }
local configChanged

local function getUciValue(option, default)
  sysBinding.option = option
  sysBinding.default = default
  return getFromUci(sysBinding)
end

local function setUciValue(option, value)
  sysBinding.option = option
  setOnUci(sysBinding, value, commitapply)
  configChanged = true
end

local function sectionExists()
  sysBinding.option = nil
  local values = getAllFromUci(sysBinding)
  return next(values)
end

local function createScheduledRebootSec()
  sysBinding.option = nil
  setOnUci(sysBinding, "scheduledreboot")
  uciHelper.commit(sysBinding)
end

--- Checks if given time is in this "2016-12-29T10:24:00Z" format, Also validates if the given time is greater than the current time.
-- @function validateTime
-- @param time #string holds the givenTime specified by the user
-- @return boolean true if given time is valid and a future time, else returns nil
local function validateTime(time)
  local date = {}
  date.year, date.month, date.day, date.hour, date.min, date.sec = time:match("(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
  if not date.year then
    return
  end
  -- Converting the given "local time in UTC format" to "epoch value"
  local givenTime = os.time(date)
  -- Get the current time in epoch value
  local curTime = os.time()
  -- Compare both epoch values
  local timeDiff = givenTime - curTime
  -- Return true only if it is future time
  if timeDiff > 0 then
    return true
  end
end

function M.getRebootOptions(option, default)
  return getUciValue(option, default)
end

function M.setRebootOptions(option, value)
  if not sectionExists() then
    createScheduledRebootSec()
  end
  if option == "time" and not validateTime(value) then
    return nil, "Invalid value or format"
  end
  setUciValue(option, value)
  return true
end

function M.uci_system_commit()
  if configChanged then
    uciHelper.commit(sysBinding)
    configChanged = false
  end
end

function M.uci_system_revert()
  if configChanged then
    uciHelper.revert(sysBinding)
    configChanged = false
  end
end

return M
