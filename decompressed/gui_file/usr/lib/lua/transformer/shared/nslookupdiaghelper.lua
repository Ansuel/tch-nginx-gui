local M = {}
local open = io.open
local uci = require("transformer.mapper.ucihelper")
local pairs = pairs

local transactions = {}
local clearusers={}
local nslookupdiag_pid = 0
local uci_binding={}


local function transaction_set(binding, pvalue, commitapply)
  uci.set_on_uci(binding, pvalue, commitapply)
  transactions[binding.config] = true
end


function M.clear_nslookupdiag_results(user)
    os.remove("/tmp/nslookupdiag_".. user)
end

function M.read_nslookupdiag_results(user)

  local return_results={}

  -- check if nslookupdiag command is still running
  if nslookupdiag_pid ~= 0 then return "0" end

  -- read results from nslookupdiag
  local fh = open("/tmp/nslookupdiag_".. user)
  if not fh then
    -- no results present
    return "0"
  end
  local SuccessCount = tonumber(fh:read())

  local index = 0
  for line in fh:lines() do
    local results = {line:match("(%S*)%,(%S*)%,(%S*)%,(%S*)%,(%S*)%,(%d*)")}
    return_results[index + 1] = {
      Status = results[1],
      AnswerType = results[2],
      HostNameReturned = results[3],
      IPAddresses = results[4],
      DNSServerIP = results[5],
      ResponseTime = results[6],
    }
    index = index + 1
  end
  fh:close()

  return return_results, SuccessCount
end

function M.startup(user, binding)
  uci_binding[user] = binding
  -- check if /etc/config/nslookupdiag exists, if not create it
  local f = open("/etc/config/nslookupdiag")
  if not f then
    f = open("/etc/config/nslookupdiag", "w")
    if not f then
      error("could not create /etc/config/nslookupdiag")
    end
    f:write("config user '".. user .."'\n")
    f:close()
  uci.set_on_uci(uci_binding[user]["NumberOfRepetitions"], 3)
  uci.set_on_uci(uci_binding[user]["Timeout"], 5000)
  else
    local value = uci.get_from_uci({config = "nslookupdiag", sectionname = user})
    if value == '' then
    uci.set_on_uci({ config = "nslookupdiag", sectionname = user},"user")
    uci.set_on_uci(uci_binding[user]["NumberOfRepetitions"], 3)
    uci.set_on_uci(uci_binding[user]["Timeout"], 5000)
    end
  end
  uci.set_on_uci(uci_binding[user]["DiagnosticsState"], "None")
  uci.commit({ config = "nslookupdiag"})
  return user
end

function M.uci_nslookupdiag_get(user, pname)
  local value
  local config = "nslookupdiag"
  if uci_binding[user] == nil then
     uci_binding[user] = {
        DiagnosticsState = { config = config, sectionname = user, option = "state" },
        Interface = { config = config, sectionname = user, option = "interface" },
        HostName = { config = config, sectionname = user, option = "hostname" },
        DNSServer = { config = config, sectionname = user, option = "dnsserver" },
        NumberOfRepetitions = { config = config, sectionname = user, option = "repetitions" },
        Timeout = { config = config, sectionname = user, option = "timeout" },
     }
  end
  if uci_binding[user][pname] then
    value = uci.get_from_uci(uci_binding[user][pname])
    -- Internally, we need to distinguish between Requested and InProgress; IGD does not
    if pname == "DiagnosticsState" and value == "InProgress" then
      value = "Requested"
    end
  else
    value = M.read_nslookupdiag_results(user,pname)
  end
  return value
end


function M.uci_nslookupdiag_set(user, pname, pvalue, commitapply)
  if pname == "DiagnosticsState" then
    if (pvalue ~= "Requested" and pvalue ~= "None") then
      return nil, "invalid value"
    end
    clearusers[user] = true
    transaction_set(uci_binding[user]["DiagnosticsState"], pvalue, commitapply)
  else
    local state = uci.get_from_uci(uci_binding[user]["DiagnosticsState"])
    if (state ~= "Requested" and  state ~= "None") then
      transaction_set(uci_binding[user]["DiagnosticsState"], "None", commitapply)
    end
    transaction_set(uci_binding[user][pname], pvalue, commitapply)
  end
end

local function endTransaction(action)
  clearusers={}
  for config,_ in pairs(transactions) do
    local binding = {config = config}
    action(binding)
  end
  transactions = {}
end

local function clear_lookup_results()
  for cl_user,_ in pairs(clearusers) do
    M.clear_nslookupdiag_results(cl_user)
  end
end

function M.uci_nslookupdiag_commit()
  clear_lookup_results()
  endTransaction(uci.commit)
end

function M.uci_nslookupdiag_revert()
  endTransaction(uci.revert)
end

return M
