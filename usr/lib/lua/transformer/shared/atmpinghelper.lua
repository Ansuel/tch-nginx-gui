local M = {}

local open = io.open
local ucihelper = require("transformer.mapper.ucihelper")
local get_from_uci = ucihelper.get_from_uci
local set_on_uci = ucihelper.set_on_uci

local binding = { config = "wanatmf5loopback" }

local param_map = {
  DiagnosticsState = "state",
  NumberOfRepetitions = "count",
  Timeout = "timeout"
}

local result_name_to_index = {
  SuccessCount = 1,
  FailureCount = 2,
  MinimumResponseTime = 3,
  MaximumResponseTime = 4,
  AverageResponseTime = 5
}

local result_cache = {}

local function clear_results(interface)
  os.remove("/tmp/atmping_" .. interface)
  result_cache[interface] = {}
end

local function read_results(interface, result_name)
  local idx = result_name_to_index[result_name]
  if not idx then
    return "0"
  end
  -- return cached result if present
  local data = result_cache[interface]
  local value
  if data then
    value = data[idx]
  else
    data = {}
    result_cache[interface] = data
  end
  if not value then
    -- nothing in cache so read results file
    local f = open("/tmp/atmping_" .. interface)
    if f then
      for line in f:lines() do
        data[#data + 1] = line
      end
      f:close()
      value = data[idx]
    end
  end
  return value or "0"
end

function M.startup()
  -- is the config already present?
  local f = open("/etc/config/wanatmf5loopback")
  if not f then
    -- create empty file
    f = open("/etc/config/wanatmf5loopback", "w")
    if not f then
      error("could not create /etc/config/wanatmf5loopback")
    end
  end
  f:close()
  -- for each entry put defaults in place if not there,
  -- reset the state and clear left over results
  local do_commit = false
  local entries = M.entries()
  for _, interface in pairs(entries) do
    binding.sectionname = interface
    binding.option = "state"
    local state = get_from_uci(binding)
    if state == "" then
      binding.option = nil
      -- create new section
      set_on_uci(binding, "wanatmf5loopback")
      -- initialize parameters to defaults
      binding.option = "count"
      set_on_uci(binding, "1")
      binding.option = "timeout"
      set_on_uci(binding, "5000")
      do_commit = true
    end
    if state ~= "None" then
      binding.option = "state"
      set_on_uci(binding, "None")
      do_commit = true
    end
    os.remove("/tmp/atmping_" .. interface)
  end
  if do_commit then
    ucihelper.commit(binding)
  end
end

local atm_binding = { config = "xtm", sectionname = "atmdevice" }
function M.entries()
  local entries = {}
  ucihelper.foreach_on_uci(atm_binding, function(s)
    entries[#entries + 1] = s[".name"]
  end)
  return entries
end

local WANATMF5LoopbackDiagnostics_defaultvalues = {
  Interface = "",
  DiagnosticsState = "None",
  NumberOfRepetitions = "1",
  Timeout = "1",
  SuccessCount = "0",
  FailureCount = "0",
  AverageResponseTime = "0",
  MinimumResponseTime = "0",
  MaximumResponseTime = "0",
}

function M.get(interface, pname)
  if not interface then
    return ""
  end
  local value = ""
  local option = param_map[pname]
  if option then
    binding.sectionname = interface
    binding.option = option
    value = get_from_uci(binding)
    if pname == "DiagnosticsState" and value == "InProgress" then
      value = "Requested"
    end
  else
    value = read_results(interface, pname)
  end
  if value ~= "" then
    return value
  else
    return WANATMF5LoopbackDiagnostics_defaultvalues[pname]
  end
end

local clear = {}
local changed = false

function M.set(interface, pname, pvalue, commitapply, user)
  if not interface then
    return ""
  end
  binding.sectionname = interface
  local option = param_map[pname]
  binding.option = option
  if option == "state" then
    if pvalue ~= "Requested" then
      return nil, "invalid value"
    end
    clear[#clear + 1] = interface
    set_on_uci(binding, pvalue, commitapply)
    binding.option = "user"
    set_on_uci(binding, user or "", commitapply)
    changed = true
  else
    set_on_uci(binding, pvalue, commitapply)
    binding.option = "state"
    local state = get_from_uci(binding)
    if state ~= "Requested" and state ~= "None" then
      -- reset to None
      set_on_uci(binding, "None", commitapply)
    end
    changed = true
  end
end

function M.commit()
  if #clear > 0 then
    for _,interface in pairs(clear) do
      clear_results(interface)
    end
    clear = {}
  end
  if changed then
    ucihelper.commit(binding)
    changed = false
  end
end

function M.revert()
  if #clear > 0 then
    clear = {}
  end
  if changed then
    ucihelper.revert(binding)
    changed = false
  end
end

return M
