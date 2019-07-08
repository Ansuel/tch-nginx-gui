
local require = require
local sort = table.sort
local dm = require("datamodel")

local function reverse(list)
  local first = 1
  local last = #list
  while first<last do
    list[first], list[last] = list[last], list[first]
    first = first+1
    last = last-1
  end
end

local function get_raw_logdata()
  local logdata = dm.get("sys.log.devicelog")
  logdata = logdata[1].value
  return logdata
end

local function filter_logdata(rawlog, current_process, all_processes)
  local logs = {}
  local process_included = {}
  all_processes = all_processes or {}
  local pattern = "([^%s]+%s+%d+ %d+:%d+:%d+) [^%s]+ ([^%s]+) ([^%s]+): ([^\n]+)"

  for date, facility, process, message in rawlog:gmatch(pattern) do
    local process_name = string.gsub(process, "%[%d+%]$", "")
    if process_name == "" then
        process_name = "others"
    end
    if not current_process or process_name == current_process then
      logs[#logs+1] = { date, facility, process, message }
    end
    if not process_included[process_name] then
      all_processes[#all_processes+1] = { process_name, process_name }
      process_included[process_name] = true
    end
  end
  return logs, all_processes
end

local MAX_ORDER=2^32
local function process_compare(lhs, rhs)
  local l_order = lhs._order or MAX_ORDER
  local r_order = rhs._order or MAX_ORDER
  if l_order == r_order then
    return lhs[1] < rhs[1]
  else
    return l_order < r_order
  end
end

local function collect_initial_processeses(process_entry, ...)
  local processes = {}
  for order, entry in ipairs{process_entry, ...} do
    entry._order = order
    processes[#processes+1] = entry
  end
  return processes
end

local function load_logs(current_process, process_entry, ...)
  local initial_processes = collect_initial_processeses(process_entry, ...)
  local rawlog = get_raw_logdata()
  local logs, processes = filter_logdata(rawlog, current_process, initial_processes)
  reverse(logs)
  sort(processes, process_compare)
  return logs, processes
end

return {
  load = load_logs
}
