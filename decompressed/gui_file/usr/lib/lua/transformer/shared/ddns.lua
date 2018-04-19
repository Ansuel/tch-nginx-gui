local M = {}

local open = io.open
local ddnsDir = "/var/run/ddns/"
local logDir = "/var/log/ddns/"
local string = string
local find, lower, match = string.find, string.lower, string.match

local errors = {
  ["fail"]   = "Connection",
  ["nohost"] = "Connection",
  ["401"]    = "Authenticating",
  ["badauth"] = "Authenticating",
  ["ERR Not authenticated"] = "Authenticating",
  ["500"]       = "Authenticating",
  ["notify NG"] = "Authenticating",
  ["200 OK"]  = "Updated",
  ["good"]      = "Updated",
  ["nochg"]     = "Updated",
  ["HTTP Basic: Access denied"] = "Protocol",
  ["No error received from server"] = "Connecting",
  ["Domain's IP updated"] = "Updated",
}

local statusErrorMap = {
  Authenticating = "AUTHENTICATION_ERROR",
  Connection     = "CONNECTION_ERROR",
  Updated        = "NO_ERROR",
  Connecting     = "NO_ERROR",
  Protocol       = "PROTOCOL_ERROR",
  Error          = "MISCONFIGURATION_ERROR",
}

local function readFile(fileName)
  local fd = open(fileName)
  if fd then
    local err = fd:read("*a")
    fd:close()
    return err
  end
  return
end

local function getLogLines(key)
  local logLines = {}
  local log = open(logDir .. key .. ".log")
  if log then
    for line in log:lines() do
      logLines[#logLines+1] = line
    end
    log:close()
  end
  return logLines
end

local function readLog(key)
  local state = "No error received from server"
  local checkIntervalFound = false
  local detectRegisteredIPFound = false
  local updateSuccessful  = false

  local logLines = getLogLines(key)
  -- check the log from the last line to the last ddns start
  for k = #logLines, 1, -1 do
    local line = logLines[k]
    -- ddns starts
    if find(line, "last update:") then
      break
    end
    if find(lower(line), "error") or find(lower(line), "fail") then
      break
    end
    if find(line, "Update successful") or find(line, "Forced update successful") then
      updateSuccessful = true
      break
    end
    if match(line, ".+Waiting %d+ seconds %(Check Interval%)") then
      checkIntervalFound = true
    end
    if find(line, "Detect registered/public IP") then
      detectRegisteredIPFound = true
    end
    if checkIntervalFound and detectRegisteredIPFound then
      -- The registered IP equals to the local IP.
      break
    end
  end
  if updateSuccessful or (checkIntervalFound and detectRegisteredIPFound) then
  -- indicate the domain's IP updated
    state = "Domain's IP updated"
  end
  return state
end

function M.getDdnsInfo(key)
  local err = readFile(ddnsDir .. key .. ".err")
  if err and err:match("nslookup") then
    return "Error", "CONNECTION_ERROR"
  end

  err = readFile(ddnsDir .. key .. ".dat")
  if err then
    for errorMessage, status in pairs(errors) do
      if err:match(errorMessage) then
        return status, statusErrorMap[status]
      end
    end
  end

  local state = readLog(key)
  return errors[state], statusErrorMap[errors[state]]
end

return M
