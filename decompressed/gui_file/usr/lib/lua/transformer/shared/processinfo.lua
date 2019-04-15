local M = {}
local io, math = io, math
local floor = math.floor
local open = io.open
local tostring = tostring
local process = require("tch.process")

-- Calculates CPU usage since boot from the /proc/stat file. This value is a ratio of the non-idle time to the total usage in "USER_HZ".
-- @function M.getCPUUsage
-- @return #string, returns the CPU usage value as a percentage of the total usage.
function M.getCPUUsage()
  local user, nice, sys, idle, ioWait, irq, softIrq, steal, guest, guestNice
  local data = open("/proc/stat")
  if data then
    local firstLine = data:read("*l")
    user, nice, sys, idle, ioWait, irq, softIrq, steal, guest, guestNice = firstLine:match("^cpu%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)")
    data:close()
  end
  if not user then
    return "0"
  end
  local cpuIdle = ioWait + idle
  local cpuNonIdle = user + nice + sys + irq + softIrq + steal + guest + guestNice
  local total = cpuIdle + cpuNonIdle
  local cpuUsage = floor(((total - cpuIdle)/total)*100)
  return tostring(cpuUsage)
end

-- Calculates Current cpu usage using top command. The value is addition of usr, sys and nice vlaues.
-- @funciton M.getCurrentCPUUsage
-- @return #string, returns the current CPU usage value.
function M.getCurrentCPUUsage()
  local cpuUsage
  local getData = process.popen("top", {"-b", "-n1"})
  local usr,sys,nic
  for line in getData:lines() do
    usr, sys, nic = line:match("^CPU:%s*(%d+)%%%s*u.*%s*(%d+)%%%s*s.*%s*(%d+)%%%s*n.*")
    if usr then
      cpuUsage = tonumber(usr) + tonumber(sys) + tonumber(nic)
      break
    end
  end
  getData:close()
  return tostring(cpuUsage) or "0"
end

return M
