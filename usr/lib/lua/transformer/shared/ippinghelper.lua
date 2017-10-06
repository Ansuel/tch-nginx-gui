local M = {}
local open = io.open
local logger = require("transformer.logger")
local uci = require("transformer.mapper.ucihelper")
local match = string.match
local pairs, remove = pairs, os.remove
local helper = require("transformer.mapper.nwcommon")

local ping_name_to_index = {
  SuccessCount = 1,
  FailureCount = 2,
  MinimumResponseTime = 3,
  AverageResponseTime = 4,
  MaximumResponseTime = 5,
  IPAddressUsed = 6,
}
local ping_data = {}
local transactions = {}
local clearusers={}
local ipping_pid = 0
local uci_binding={}

local function transaction_set(binding, pvalue, commitapply)
  uci.set_on_uci(binding, pvalue, commitapply)
  transactions[binding.config] = true
end

function M.clear_ping_results(user)
    remove("/tmp/ipping_".. user)
    remove("/tmp/ping_".. user)
    ping_data[user] = {}
end

function M.read_ping_results(user, name)
  if(name ~= nil) then
    local idx = ping_name_to_index[name]

    -- return cached result
      if ping_data[user] then
        if ping_data[user][idx] then
          return ping_data[user][idx]
        end
      end
    local my_data ={}
    -- check if ipping command is still running
    if ipping_pid ~= 0 then return "0" end

    -- read results from ipping
    local fh, msg = open("/tmp/ipping_".. user)
    if not fh then
      -- no results present
      logger:debug("ping results not found: " .. msg)
      return "0"
    end

    for line in fh:lines() do
      my_data[#my_data + 1] = line
    end
   fh:close()
   ping_data[user]=my_data
   return my_data[idx]
  else
    return nil
  end
end

function M.read_ping_trace_results(user)
    if user ~= "diagping" then
       return nil, "Ping traces valid only for Diagping"
    end
    local fh, msg = open("/tmp/ping_".. user)
    if not fh then
      logger:debug("ping results not found: " .. msg)
      return nil, msg
    end
    local results ={}
    for line in fh:lines() do
       local bytes,ip,seq,ttl,time = match(line, "(%d+) bytes from (%S+)%: seq=(%d+) ttl=(%d+) time=(%d*.%d*) ms")
       if bytes == nil then
	  bytes,ip,seq,ttl = match(line, "(%d+) bytes from (%S+)%: seq=(%d+) ttl=(%d+)")
	  time = "0"
       end
      if bytes then
        results[#results + 1] = {Bytes = bytes, IP = ip, Seq = seq, TTL = ttl, Time = time }
      end
    end
    fh:close()
    return results
end

function M.startup(user, binding)
  uci_binding[user] = binding
  -- check if /etc/config/ipping exists, if not create it
  local f = open("/etc/config/ipping")
  if not f then
    f = open("/etc/config/ipping", "w")
    if not f then
      error("could not create /etc/config/ipping")
    end
    f:write("config user '".. user .."'\n")
    f:close()
    uci.set_on_uci(uci_binding[user]["NumberOfRepetitions"], 3)
    uci.set_on_uci(uci_binding[user]["Timeout"], 10000)
    uci.set_on_uci(uci_binding[user]["DataBlockSize"], 56)
    uci.set_on_uci(uci_binding[user]["DSCP"], 0) 
  else
    local value = uci.get_from_uci({config = "ipping", sectionname = user})
    if value == '' then
      uci.set_on_uci({ config = "ipping", sectionname = user},"user")
      uci.set_on_uci(uci_binding[user]["NumberOfRepetitions"], 3)
      uci.set_on_uci(uci_binding[user]["Timeout"], 10000)
      uci.set_on_uci(uci_binding[user]["DataBlockSize"], 56)
      uci.set_on_uci(uci_binding[user]["DSCP"], 0)
    end
  end
  uci.set_on_uci(uci_binding[user]["DiagnosticsState"], "None")
  uci.commit({ config = "ipping"})
  return user
end

function M.uci_ipping_get(user, pname)
  local value
  local config = "ipping"

  if uci_binding[user] == nil then 
     uci_binding[user] = {
       DiagnosticsState = { config = config, sectionname = user, option = "state" },
       Interface = { config = config, sectionname = user, option = "interface" },
       Host = { config = config, sectionname = user, option = "host" },
       NumberOfRepetitions = { config = config, sectionname = user, option = "count" },
       Timeout = { config = config, sectionname = user, option = "timeout" },
       DataBlockSize = { config = config, sectionname = user, option = "size" },
       DSCP = { config = config, sectionname = user, option = "dscp" },
     }
  end
  if uci_binding[user][pname] then
    value = uci.get_from_uci(uci_binding[user][pname])

    -- Internally, we need to distinguish between Requested and InProgress; IGD does not
    if pname == "DiagnosticsState" and value == "InProgress" then
      value = "Requested"
    end
  else
    value = M.read_ping_results(user,pname)
  end
  return value
end

function M.uci_ipping_set(user, pname, pvalue, commitapply)
  if pname == "DiagnosticsState" then
    if pvalue ~= "Requested" and pvalue ~= "None" then
      return nil, "invalid value"
    end
    clearusers[user] = true
    transaction_set(uci_binding[user]["DiagnosticsState"], pvalue, commitapply)
    transaction_set(uci_binding[user][pname], pvalue, commitapply)
  else
    local state = uci.get_from_uci(uci_binding[user]["DiagnosticsState"])
    if (state ~= "Requested" and  state ~= "None") then
      transaction_set(uci_binding[user]["DiagnosticsState"], "None", commitapply)
    end
    transaction_set(uci_binding[user][pname], pvalue, commitapply)
  end
end

function M.uci_ipping_commit()
  for cl_user in pairs(clearusers) do
    M.clear_ping_results(cl_user)
  end
  clearusers={}
  for config in pairs(transactions) do
    local binding = {config = config}
    uci.commit(binding)
  end
  transactions = {}
end

function M.uci_ipping_revert()
  clearusers={}
  for config in pairs(transactions) do
    local binding = {config = config}
    uci.revert(binding)
  end
  transactions = {}
end

return M
