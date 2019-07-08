local cfg = require("transformer.shared.ConfigCommon")
local proxy = require("datamodel")
local uci_helper = require("transformer.mapper.ucihelper")
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
  local rotate
  if tonumber(index) < 1 then
    name = "logread"
  else
    local result = proxy.get("uci.cwmpd.cwmpd_config.datamodel")
    local datamodel = result and result[1].value
    if datamodel ~= "Device" then
      datamodel = "InternetGatewayDevice"
    end

    --check if persistentlog enabled
    local persistenlog_enabled = false
    local log_binding = {config="system", sectionname="log"}
    uci_helper.foreach_on_uci(log_binding, function(s)
       if s.path and s.size and s.rotate then
         persistenlog_enabled = true
         return
       end
    end)
    if persistenlog_enabled then
      result = proxy.get(format("%s.DeviceInfo.VendorLogFile.%s.Name", datamodel, index),
                         format("%s.DeviceInfo.VendorLogFile.%s.X_000E50_Rotate", datamodel, index))
      name = result and result[1].value
      rotate = result and result[2].value
      rotate = rotate and tonumber(rotate)
    else
      result = proxy.get(format("%s.DeviceInfo.VendorLogFile.%s.Name", datamodel, index))
      name = result and result[1].value
    end
  end
  if not name then
    errmsg("Invalid index number!")
    return 1
  end
  if name == "filter_file" then
    name = uci_helper.get_from_uci({config="system", sectionname="@system[0]", option="log_filter_file", default="/var/log/filt_msg", extended=true})
  elseif name == "logread" then
      name = uci_helper.get_from_uci({config="system", sectionname="@system[0]", option="log_file", default="logread", extended=true})
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
    if persistenlog_enabled and rotate >= 1 then
      execute("cat `ls -r " .. name .."*` > " .. location .. filename)
    else
      execute("ln -fs " .. name .. " " .. location .. filename)
    end
  end
  return 0
end

os.exit(main(...) or 0)
