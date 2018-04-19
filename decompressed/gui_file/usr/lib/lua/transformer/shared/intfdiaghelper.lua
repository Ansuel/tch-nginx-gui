local M = {}
local open, pairs = io.open, pairs
local logger = require("transformer.logger")
local uci = require("transformer.mapper.ucihelper")
local setOnUci = uci.set_on_uci
local getFromUci = uci.get_from_uci
local configChanged
local intfDiagBinding = { config = "intfdiag" }
local intfData = {}

--- Set a given value to the specified uci config
-- @function transaction_set
-- @param binding corresponding uci config for which the value has to be set
-- @param pvalue holds the new value to be set
-- @param commitapply boolean whether to commit or not
local function transaction_set(binding, pvalue, commitapply)
  setOnUci(binding, pvalue, commitapply)
  configChanged = true
end

--- Check if interface is already present in intfdiag config, else create a new section with interface as sectionname.
-- @function startup
-- @param interface holds the interface name for which the new section has to be created
-- @return interface name
function M.startup(interfaces)
  -- check if /etc/config/intfdiag exists, if not create it
  local f = open("/etc/config/intfdiag", "a")
  f:close()
  local sectionChanged
  for _, interface in pairs(interfaces) do
    intfDiagBinding.sectionname = interface
    local value = getFromUci(intfDiagBinding)
    if value == '' then
      intfDiagBinding.sectionname = interface
      intfDiagBinding.option = nil
      setOnUci(intfDiagBinding, "intfdiag")
      intfDiagBinding.option = "state"
      setOnUci(intfDiagBinding, "None")
      intfDiagBinding.option = "interval"
      setOnUci(intfDiagBinding, 300)
      intfDiagBinding.option = "interface"
      setOnUci(intfDiagBinding, interface)
      sectionChanged = true
    end
  end
  if sectionChanged then
    intfDiagBinding.sectionname = nil
    intfDiagBinding.option = nil
    uci.commit(intfDiagBinding)
  end
  return interfaces
end

--- Set the given value to the corresponding section and option in intfdiag config.
-- @function intfDiagSet
-- @param binding holds the uci config and option for which the value has to be set
-- @param pname Parameter name
-- pvalue new value to be set
-- commitapply boolean whether to commit or not
function M.intfDiagSet(binding, pvalue, commitapply)
  if binding.option == "state" then
    if pvalue ~= "Requested" and pvalue ~= "Canceled" then
      return nil, "invalid value"
    end
    if pvalue == "Canceled" then
      pvalue = "None"
    end
  end
  transaction_set(binding, pvalue, commitapply)
  binding.option = "state"
  local state = getFromUci(binding)
  if state ~= "Requested" and  state ~= "None" then
    transaction_set(binding, "None", commitapply)
  end
end

function M.intfDiagCommit()
  if configChanged then
    intfDiagBinding.sectionname = nil
    intfDiagBinding.option = nil
    uci.commit(intfDiagBinding)
  end
  configChanged = false
end

function M.intfDiagRevert()
  if configChanged then
    intfDiagBinding.sectionname = nil
    intfDiagBinding.option = nil
    uci.revert(intfDiagBinding)
  end
  configChanged = false
end

return M
