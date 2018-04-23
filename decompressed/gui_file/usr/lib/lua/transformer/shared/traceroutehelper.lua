local M = {}
local io, string = io, string
local open = io.open
local logger = require("transformer.logger")
local uci = require("transformer.mapper.ucihelper")
local config = "traceroute"
local match, sub = string.match, string.sub
local pairs, ipairs, tonumber, tostring = pairs, ipairs, tonumber, tostring
local remove, error = os.remove, error
local helper = require("transformer.mapper.nwcommon")
local ubus = require("ubus").connect()
local transactions = {}
local clearusers={}
local traceroute_results = {}
local traceroute_totaltime = {}
local traceroute_ipaddr_used = {}
local uci_binding={}

local function transaction_set(binding, pvalue, commitapply)
  uci.set_on_uci(binding, pvalue, commitapply)
  transactions[binding.config] = true
end

function M.clear_traceroute_results(user)
  remove("/tmp/traceroute_"..user)
  remove("/tmp/trace_"..user)
  traceroute_results[user] = nil
  traceroute_totaltime[user] = 0
  traceroute_ipaddr_used[user] = ""
end

function M.parseLine(line)
  local lasthost, lastip, times
  for attempt in line:gmatch("[^*]*%*") do
    local host, ip, time = match(attempt, "%S+%s+(%S+)%s+%((%S+)%)%s+(%d+%.%d+)%s+ms")
    if (host) then
      lasthost = host
      lastip = ip
    else
      time = match(attempt, "(%d+%.%d+)%s+ms")
    end
    time = time or "0"
    if (times) then
      times = times .. "," .. time
    else
      times = time
    end
  end
  return lasthost, lastip, times
end

function M.read_trace_results(user, file)
  local results={}
  local fh, msg = open(file, "r")
  if not fh then
    -- no results present
    logger:debug("traceroute results not found: " .. msg)
    return results, 0
  end

  local totaltime = tonumber(fh:read())
  local ipaddr_used
  if user ~= "diagping" and user ~= "webui" then
    ipaddr_used = fh:read()
  end

  for line in fh:lines() do
    local errCode = "0"
    local lasthost, lastip, times
    line = string.gsub(line, "(%S%sms)", "%1*")

    if user == "diagping" or user == "webui" then
      --handling * in table instead of blank line in traceroute std output
      if line:match("(%d+%s+)%*") then
        lasthost, lastip, times = "*", "*", "*"
        errCode = "*"
      else
        lasthost, lastip, times = M.parseLine(line)
      end
    else
      lasthost, lastip, times = match(line, "(%S+)%s+(%S+)%s+(%S+)")
    end

    if (lasthost and lastip) then
      if times ~= "*" then
        times = times and sub(times, 1, 20)
      end
      -- If the reverse DNS lookup failed, clear out Hostname
      if (lasthost == lastip) and lasthost ~= "*" then
        lasthost = ""
      end
      results[#results+1] = { lasthost, lastip, times, errCode }
    end
  end
  fh:close()
  if user ~= "diagping" and user ~= "webui" then
    -- cache results
    traceroute_results[user], traceroute_totaltime[user], traceroute_ipaddr_used[user] = results, totaltime, ipaddr_used
  end
  return results, totaltime, ipaddr_used
end

function M.read_traceroute_results(user, name)
  if user == "diagping" or user == "webui" then
   return M.read_trace_results(user, "/tmp/trace_".. user)
-- if traceroute_results is not empty, we have cached results
  elseif (traceroute_results[user]) then
    return traceroute_results[user], traceroute_totaltime[user]
  end
  return M.read_trace_results(user, "/tmp/traceroute_".. user)
end

function M.startup(user, binding)
  uci_binding[user] = binding
  -- check if /etc/config/traceroute exists, if not create it
  local f = open("/etc/config/traceroute")
  if not f then
    f = open("/etc/config/traceroute", "w")
    if not f then
      error("could not create /etc/config/traceroute")
    end
    f:write("config  user '".. user .."'\n")
    f:close()
    uci.set_on_uci(uci_binding[user]["NumberOfTries"], 3)
    uci.set_on_uci(uci_binding[user]["Timeout"], 5000)
    uci.set_on_uci(uci_binding[user]["DataBlockSize"], 38)
    uci.set_on_uci(uci_binding[user]["DSCP"], 0)
    uci.set_on_uci(uci_binding[user]["MaxHopCount"], 30)
    if user == "webui" then
      uci.set_on_uci(uci_binding[user]["ipType"], "ipv4")
    end
    else
    local value = uci.get_from_uci({config = "traceroute", sectionname = user})
    if value == '' then
      uci.set_on_uci({config = "traceroute", sectionname = user},"user")
      -- Populate defaults
      uci.set_on_uci(uci_binding[user]["NumberOfTries"], 3)
      uci.set_on_uci(uci_binding[user]["Timeout"], 5000)
      uci.set_on_uci(uci_binding[user]["DataBlockSize"], 38)
      uci.set_on_uci(uci_binding[user]["DSCP"], 0)
      uci.set_on_uci(uci_binding[user]["MaxHopCount"], 30)
      if user == "webui" then
        uci.set_on_uci(uci_binding[user]["ipType"], "ipv4")
      end
    end
  end
  uci.set_on_uci(uci_binding[user]["DiagnosticsState"], "None")
  uci.commit({config = "traceroute"})
  return user
end

function M.uci_traceroute_get(user, pname)
  local value

  if uci_binding[user] == nil then
     uci_binding[user]= {
          DiagnosticsState = { config = config, sectionname = user, option = "state" },
          Interface = { config = config, sectionname = user, option = "interface" },
          Host = { config = config, sectionname = user, option = "host" },
          NumberOfTries = { config = config, sectionname = user, option = "tries" },
          Timeout = { config = config, sectionname = user, option = "timeout" },
          DataBlockSize = { config = config, sectionname = user, option = "size" },
          DSCP = { config = config, sectionname = user, option = "dscp" },
          MaxHopCount = { config = config, sectionname = user, option = "hopcount" },
        }
  end

  if uci_binding[user][pname] then
    value = uci.get_from_uci(uci_binding[user][pname])

    -- Internally, we need to distinguish between Requested and InProgress; IGD does not
    if pname == "DiagnosticsState" and value == "InProgress" then
      value = "Requested"
    end
  elseif (pname == "ResponseTime") then
    local _, time = M.read_traceroute_results(user)
    value = (time and tostring(time)) or "0"
  else
    return nil, "invalid parameter"
  end
  return value
end

function M.uci_traceroute_set(user, pname, pvalue, commitapply)
  if pname == "DiagnosticsState" then
    if pvalue ~= "Requested" and pvalue ~= "Canceled" then
      return nil, "invalid value"
    elseif pvalue == "Requested" and user == "device2" then
      local interface = M.uci_traceroute_get(user, "Interface")
      if interface == "" then
        local defaultRoute = helper.loadRoutes(true)
        if defaultRoute then
          local info = ubus:call("network.interface", "dump", {})
          for _, intf in ipairs(info.interface or {}) do
            if intf.l3_device == defaultRoute then
              interface = intf.interface
              break
            end
          end
        end
      end
    end
    clearusers[user] = true
    if pvalue == "Canceled" then
      transaction_set(uci_binding[user]["DiagnosticsState"], "None", commitapply)
    else
      transaction_set(uci_binding[user]["DiagnosticsState"], pvalue, commitapply)
    end
  elseif (pname == "ResponseTime") then
    return nil, "invalid parameter"
  else
    local state = uci.get_from_uci(uci_binding[user]["DiagnosticsState"])
    if (state ~= "Requested") and (state ~= "None") then
      transaction_set(uci_binding[user]["DiagnosticsState"], "None", commitapply)
    end
    transaction_set(uci_binding[user][pname], pvalue, commitapply)
  end
end

function M.uci_traceroute_commit()
  for cl_user,_ in pairs(clearusers) do
    M.clear_traceroute_results(cl_user)
  end
  clearusers={}
  for conf in pairs(transactions) do
    local binding = {config = conf}
    uci.commit(binding)
  end
  transactions = {}
end

function M.uci_traceroute_revert()
  clearusers={}
  for conf in pairs(transactions) do
    local binding = {config = conf}
    uci.revert(binding)
  end
  transactions = {}
end

return M
