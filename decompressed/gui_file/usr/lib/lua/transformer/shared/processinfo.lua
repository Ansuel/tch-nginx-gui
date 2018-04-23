local M = {}
local io, math = io, math
local floor = math.floor
local open = io.open
local tostring = tostring

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

return M
