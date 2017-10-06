local cfg = require("transformer.shared.ConfigCommon")
local proxy = require("datamodel")
local format, tonumber = string.format, tonumber
local open, stderr = io.open, io.stderr
local execute = os.execute

local function errmsg(fmt, ...)
    local msg = format(fmt, ...)
    stderr:write('*error: ', msg, '\n')
    return {msg}
end

-- Parameter list for main:
-- [1]: Config index to be exported
-- [2]: Location the exported file will be saved
-- [3]: Filename the exported file
local function main(...)
  local args = {...}
  if #args < 3 then
    errmsg("Please enter the appropriate parameters!")
    return 1
  end

  local index, location, filename = unpack(args)
  -- Get instance name from index
  local name
  if tonumber(index) < 1 then
    name = "logread"
  else
    local result = proxy.get("uci.cwmpd.cwmpd_config.datamodel")
    local datamodel = result and result[1].value
    if datamodel ~= "Device" then
      datamodel = "InternetGatewayDevice"
    end
    result = proxy.get(format("%s.DeviceInfo.VendorLogFile.%s.Name", datamodel, index))
    name = result and result[1].value
  end
  if not name then
    errmsg("Invalid index number!")
    return 1
  end
  if name == "logread" then
    execute("logread > " .. location .. filename)
  else
    local f = open(name, "r")
    if not f then
      errmsg("Invalid log file name!")
      return 1
    end
    f:close()
    execute("cp " .. name .. " " .. location .. filename)
  end
  return 0
end

os.exit(main(...) or 0)
