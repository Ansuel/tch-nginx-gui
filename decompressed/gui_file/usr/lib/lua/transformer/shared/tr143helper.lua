local M = {}
local pairs = pairs

local uci = require 'transformer.mapper.ucihelper'
local common = require 'transformer.mapper.nwcommon'
local split_key = common.split_key
local network = require("transformer.shared.common.network")
local wanconn = require 'transformer.shared.wanconnection'
local transactions = {}
local resolve, tokey
local tr143binding = { config = "tr143" }
local init_state = false

local paramMap = {
  X_0876FF_PeriodOfFullLoading = "PeriodOfFullLoading",
  X_0876FF_TotalBytesReceivedUnderFullLoading = "TotalBytesReceivedUnderFullLoading",
  X_0876FF_TestBytesReceivedUnderFullLoading = "TestBytesReceivedUnderFullLoading",
  X_0876FF_TestBytesSentUnderFullLoading = "TestBytesSentUnderFullLoading",
}

local function isLanInterface(value)
  local lanInterfaces = network.getLanInterfaces()
  for intf in pairs(lanInterfaces) do
        if value == intf then
            return true
        end
   end
   return false
end

local function resolveInterface(user, value)
    local path = ""
    if user == "device2" then
        path = resolve("Device.IP.Interface.{i}.", value)
    else
        if isLanInterface(value) then
            path = resolve('InternetGatewayDevice.LANDevice.{i}.LANHostConfigManagement.IPInterface.{i}.', value)
        else
            local key, status = wanconn.get_connection_key(value)
            if key and status then
                if status.proto == "pppoe" or status.proto == "pppoa" then
                    path = resolve("InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANPPPConnection.{i}.", key)
                else
                    path = resolve("InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANIPConnection.{i}.", key)
                end
            end
        end
    end
    return path or ""
end

local function setInterface(user, param, value)
-- Interface is displayed in IGD/Device2 as path, but stored as UCI/UBUS interface in UCI, so convert it first
-- -- allow empty value
-- -- Convert path to key; this is always the UCI/UBUS interface name, like wan, lan, ...
   if user == "device2" then
     local rc
     rc, value = pcall(tokey, value, "Device.IP.Interface.{i}.")
     if not rc then
        return nil, "invalid value"
     end
   else
     value = tokey(value,
      "InternetGatewayDevice.LANDevice.{i}.LANHostConfigManagement.IPInterface.{i}.",
      "InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANIPConnection.{i}.",
      "InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANPPPConnection.{i}.")
     if value and value:match("|") then
       -- Interface name can be first or second part of the WANDevice.WANConnectionDevice.WANIP/WANPPP key.
       -- If wansensing is in use and activedevice section is configured in wanconfig, then the first part
       -- of WANDevice.WANConnectionDevice.WANIP/WANPPP key is "ACTIVE" and the second part is the Interface name.
       -- In all other cases, Interface name is the first part of the WANDevice.WANConnectionDevice.WANIP/WANPPP key.
       local intfName, devName = split_key(value)
       if intfName == "ACTIVE" then
         value = devName
       else
         value = intfName
       end
     end
   end
   return value
end

function M.tr143_get(config, user, pname)
  local value = ""

  if pname == "UploadTransports" or pname == "DownloadTransports" then
    return "HTTP,FTP"
  end

  tr143binding.sectionname = config
  if pname == "X_0876FF_ConcurrentSession" or pname == "X_000E50_ConcurrentSession" then
    local diagOptions = uci.getall_from_uci(tr143binding)
    if config == "DownloadDiagnostics" then
      if diagOptions and diagOptions.NumberOfConnections and diagOptions.DownloadDiagnosticMaxConnections and diagOptions.NumberOfConnections <= diagOptions.DownloadDiagnosticMaxConnections then
        return diagOptions.NumberOfConnections
      end
      return "0"
    end
    if config == "UploadDiagnostics" then
      if diagOptions and diagOptions.NumberOfConnections and diagOptions.UploadDiagnosticsMaxConnections and diagOptions.NumberOfConnections <= diagOptions.UploadDiagnosticsMaxConnections then
        return diagOptions.NumberOfConnections
      end
      return "0"
    end
  end
  if pname == "X_0876FF_Throughput" then
    local diagOptions = uci.getall_from_uci(tr143binding) or {}
    if diagOptions.PeriodOfFullLoading and diagOptions.PeriodOfFullLoading ~= "0" and diagOptions.TotalBytesReceivedUnderFullLoading then
      return tostring(8 * (tonumber(diagOptions.TotalBytesReceivedUnderFullLoading)/tonumber(diagOptions.PeriodOfFullLoading)))
    end
    return "0"
  end

  if pname == "DiagnosticsState" then
    tr143binding.option = pname
    local state = uci.get_from_uci(tr143binding)
    if user == "igd" and state == "Error_Other" then
      return "Error_InitConnectionFailed"
    end
    return state
  end

  tr143binding.option = paramMap[pname] or pname
  value = uci.get_from_uci(tr143binding)
  if pname == "Interface" and value ~= "" then
    value = resolveInterface(user, value)
  end
  return value or ""
end

function M.tr143_set(config, user, pname, pvalue, commitapply)
  if pname == "Interface" and pvalue ~= "" then
    pvalue = setInterface(user, pname, pvalue)
    if not pvalue then
      return nil, "Invalid value"
    end
  end
  if pname == "UploadURL" or pname == "DownloadURL" then
    if not string.find(pvalue, "^http://") and not string.find(pvalue, "^ftp://") then
      return nil, "Invalid value"
    end
  end

  tr143binding.sectionname = config
  if pname == "NumberOfConnections" then
    if config == "UploadDiagnostics" then
      tr143binding.option = "UploadDiagnosticsMaxConnections"
    else
      tr143binding.option = "DownloadDiagnosticMaxConnections"
    end
    local max = uci.get_from_uci(tr143binding)
    if tonumber(pvalue) > tonumber(max) then
      return nil, "Invalid value"
    end
  end
  if pname == "DiagnosticsState" then
    if pvalue ~= "Requested" then
      return nil, "invalid value"
    else
      tr143binding.option = "State"
      uci.set_on_uci(tr143binding, "Idle", commitapply)
    end
  end
  tr143binding.option = pname
  uci.set_on_uci(tr143binding, pvalue, commitapply)
  transactions[tr143binding.config] = true
end

function M.tr143_commit()
  local binding = {}
  for config in pairs(transactions) do
      binding.config = config
      uci.commit(binding)
  end
  transactions = {}
end

function M.tr143_revert()
  local binding = {}
  for config in pairs(transactions) do
      binding.config = config
      uci.revert(binding)
  end
  transactions = {}
end

function M.startup(_resolve, _tokey)
  local execute = require("modgui").execute
  resolve, tokey = _resolve, _tokey
  if init_state == false then
      --initialize the tr143 default configuration
      execute("cp /etc/tr143.default /etc/config/tr143")
      init_state = true
  end
end

return M
