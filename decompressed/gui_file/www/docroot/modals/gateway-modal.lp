--pretranslated: do not change this file
 
-- Enable localization
-- NG-56123; NG-62887; NG-48150; NG-69530; NG-85826
--NG-103901 GUI gateway-modal has to modified in fact of generic changes
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local inet = require("tch.inet")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local format,find,sub, match, untaint = string.format, string.find, string.sub, string.match, string.untaint
local floor, ipairs = math.floor, ipairs
local timezone = require("transformer.shared.timezone")
local vB = post_helper.validateBoolean
local gOV = post_helper.getOrValidation
local gAV = post_helper.getAndValidation
local session = ngx.ctx.session

local tech = false
if session:getrole() == "engineer" then
	tech = true
end
local function wait_for_completion(base_path, return_json, filename)
  local state_path = base_path .. "state"
  local info_path = base_path .. "info"
  local sleep_time = 0.250
  local max_time = 5
  local total_time = 0
  local content
  repeat
    ngx.sleep(sleep_time)
    total_time = total_time + sleep_time

    content = { state = state_path, info = info_path }
    content_helper.getExactContent(content)

    if content.state ~= "Requested" then
      break
    end
  until (total_time >= max_time)
  if filename then
    os.remove(filename)
  end
  if content.state ~= "Complete" then
    if content.state == "Requested" then
      ngx.log(ngx.ERR, "Timeout on ", base_path)
    else
      ngx.log(ngx.ERR, format('Error on %s (state="%s", info="%s")',
      base_path, content.state, content.info or ""))
    end
    if return_json then
		if match(content.info, "Buildversion") then
			ngx.print('{ "error":"buildversion" }')
		else
			ngx.print('{ "error":"10" }')
		end
      ngx.exit(ngx.OK)
    else
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
  end
end

local function export_config()
  local export_rpc_path = "rpc.system.config.export."

  local content = {
    export_state = export_rpc_path .. "state",
    export_location = export_rpc_path .. "location",
    export_filename = export_rpc_path .. "filename",
  }

  -- Get transformer content
  content_helper.getExactContent(content)

  if content.export_state ~= "Requested" then
    -- start new export request
    local uptime = content_helper.readfile("/proc/uptime", "number", floor)
    content.export_filename = format("config_export.%d", uptime)

    proxy.set({ [export_rpc_path .. "filename"] = content.export_filename })
    proxy.set({ [export_rpc_path .. "state"] = "Requested" })
  end

  -- wait for completion; does not return on error or timeout
  wait_for_completion(export_rpc_path)

  -- return exported data
  ngx.header.content_disposition = "attachment; filename=config.bin"
  ngx.header.content_type = "application/octet-stream"
  ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JS download code requires this cookie
  local export_path = untaint(content.export_location .. content.export_filename)
  local f = io.open(export_path, "r")
  ngx.print(f:read("*all"))
  f:close()

  -- cleanup (reset state and remove export file)
  proxy.set({ [export_rpc_path .. "filename"] = "" })

  -- and we're done
  ngx.exit(ngx.HTTP_OK)
end

local function receive_file(filename, match)
  function do_receive(outfile, match)
    local upload = require("web.fileupload")
    local form, err = upload.fromstream()
    if not form then
      return false, 1, "failed to create upload ctx: " .. err
    end
    local totalsize = 0
    local file
    local discard = false
    while true do
      local token, data, err = form:read()
      if not token then
        return false, 2, "read failed: " .. err
      end
      if token == "header" then
        if not discard and not file and find(data[2], match, 1, true) then
          file = outfile
        end
        if not discard and not file then
          return false, 3, "failed to start receiving file"
        end
      elseif token == "body" then
        if file then
          totalsize = totalsize + #data
          file:write(data)
        end
      elseif token == "part_end" then
        if file then
          file = nil
          discard = true
        end
      elseif token == "eof" then
        break
      end
    end
    return true
  end

  local file = io.open(filename, "w")
  local result, err_code, err_msg
  if file then
    result, err_code, err_msg = do_receive(file, match)
  else
    file = io.open("/dev/null", "w")
    do_receive(file, match)
    result = false
    err_code = 4
    err_msg = "internal error"
  end

  file:close()

  return result, err_code, err_msg
end

local function import_config()
  local import_rpc_path = "rpc.system.config.import."
  local filename = "importconfig.bin"

  local content = {
    import_state = import_rpc_path .. "state",
    import_location = import_rpc_path .. "location"
  }
  content_helper.getExactContent(content)
  if content.import_state == "Requested" then
    ngx.log(ngx.ERR, "import already in progress")
    ngx.print('{ "error":"0" }')
    ngx.exit(ngx.OK)
  end

  local rcv_ok, rcv_errno, rcv_errmsg = receive_file(untaint(content.import_location) .. filename, 'name="configfile"')

  if not rcv_ok then
    ngx.log(ngx.ERR, rcv_errmsg)
    ngx.print('{ "error":"' .. rcv_errno .. '" }')
    ngx.exit(ngx.OK)
  end

  -- start actual import through rpc
  proxy.set({ [import_rpc_path .. "filename"] = filename })
  proxy.set({ [import_rpc_path .. "state"] = "Requested" })

  -- wait for completion
  wait_for_completion(import_rpc_path, true, filename)
  ngx.print('{ "success":"true" }')
  -- import is completed; reboot by scheduling a timer so
  -- we can still get our response out
  ngx.timer.at(0, function()
    proxy.set({ ["rpc.system.reboot"] = "GUI" })
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

local function upgradefw(upgradetype)
  local fwupgrade_rpc_path = "rpc.system.fwupgrade."
  local filename = "fwupgrade.bin"

  local content = {
    fwupgrade_state = fwupgrade_rpc_path .. "state",
    fwupgrade_location = fwupgrade_rpc_path .. "location"
  }
  content_helper.getExactContent(content)
  if content.fwupgrade_state == "Requested" then
    ngx.log(ngx.ERR, "upgrade already in progress")
    ngx.print('{ "error":"0" }')
    ngx.exit(ngx.OK)
  end

  -- flush the web template cache
  lp.flush()

  local dl = untaint(content.fwupgrade_location) .. filename
  os.execute(string.format("rm -f %s && mkfifo %s", dl, dl))

  -- start actual upgrade through rpc
  -- sysupgrade will create the pipe
  -- separate requests as the order is important
  proxy.set({[fwupgrade_rpc_path .. "filename"] = filename})
  if ( upgradetype == "Reset" ) then
	proxy.set({[fwupgrade_rpc_path .. "upgradetype"] = upgradetype})
  end
  proxy.set({[fwupgrade_rpc_path .. "state"] = "Requested"})


  -- force GC to run to try to prevent lua from taking more memory during
  -- the upgrade action by having it reclaim some unused objects. This won't
  -- shrink the linux memory usage, but it might prevent it from becoming
  -- even bigger.
  collectgarbage()
  collectgarbage()
  local rcv_ok, rcv_errno, rcv_errmsg = receive_file(dl, 'name="upgradefile"')


  ngx.print('{ "success":"true" }')
  ngx.exit(ngx.HTTP_OK)
end

local function upgradefwstatus()
  local fwupgrade_rpc_path = "rpc.system.fwupgrade."

  local state = proxy.get(fwupgrade_rpc_path .. "state")[1].value

  ngx.header.content_type = "application/json"
  if state == "Requested" then
    ngx.print('{ "success":"true" }')
  else
    local content = {}
    local results = proxy.get(fwupgrade_rpc_path)
    for _, result in ipairs(results) do
      content[result.param] = result.value
    end

    os.remove(untaint(content.location .. content.filename))
    ngx.print('{ "success":"false" , "errorcode":"' .. untaint(content.errorcode) .. '" }')
  end

  ngx.exit(ngx.HTTP_OK)
end

local function resetreboot(path, value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

-- Handle fwupgrade/configimport/configexport specific GET/POSTs.
if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_uri_args().action
  -- do not call get_post_args before we know that we don't have a file sent otherwise it will fail
  if action == "import_config" then
    return import_config()
  end
  if action == "upgradefw" then
    return upgradefw("Normal")
  end
  if action == "upgradefw_reset" then
	return upgradefw("Reset")
  end
  -- now process non-file POSTs
  local action = ngx.req.get_post_args().action
  if action == "export_config" then
    return export_config()
  end
  if action == "system_reset" then
    return resetreboot("rpc.system.reset", "1")
  end
  if action == "system_reboot" then
    return resetreboot("rpc.system.reboot", "GUI")
  end
elseif ngx.req.get_method() == "GET" then
  local action = ngx.req.get_uri_args().action
  local content = {
    fwflash_size = "uci.env.var.banksize"
  }
  content_helper.getExactContent(content)

  if action == "upgradefwstatus" then
    return upgradefwstatus()
  end
  if action == "getbanksize" then
    ngx.header.content_type = "application/json"
    ngx.print('{ "success":"true" , "banksize":"' .. untaint(content.fwflash_size) .. '" }')
    ngx.exit(ngx.HTTP_OK)
  end
end

-- Non-configurable data
local content = {
  acs_url = "uci.cwmpd.cwmpd_config.acs_url",
  vendor = "uci.env.var.company_name",
  product_name = "uci.env.var.prod_name",
  friendly_product_name = "uci.env.var.prod_friendly_name",
  software_name = "uci.version.version.@version[0].marketing_name",
  software_version = "uci.version.version.@version[0].marketing_version",
  firmware_version = "uci.env.var.friendly_sw_version_activebank",
  firmware_oid = "uci.version.version.@version[0].oid",
  bootloader_version = "uci.env.var.bootloader_version",
  bootloader_oid = "uci.env.var.bootloader_oid",
  hardware_version = "uci.env.var.hardware_version",
  serial_number = "uci.env.var.serial",
  mac_address = "uci.env.rip.eth_mac",
  dsl_firmware = "sys.class.xdsl.@line0.FirmwareVersion",
  fwversion_prefix = "uci.versioncusto.override.fwversion_prefix",
  fwversion_suffix = "uci.versioncusto.override.fwversion_suffix",
  fwversion_override = "uci.versioncusto.override.fwversion_override_real",
  activebank = "sys.banktable.activebank",
  passivebank = "sys.banktable.passivebank",
  activeversion = "sys.banktable.activeversion",
  passiveversion = "sys.banktable.passiveversion",
  rip_key_B = "rpc.system.rip_key_B",
}

content_helper.getExactContent(content)

if content["friendly_product_name"] and content["friendly_product_name"] == "AGHP" then
	content["friendly_product_name"] = "AGTHP" --Wrong product name by telecom!
end

if not ( content.friendly_product_name == "" ) then
	content.product_name = format("%s ( %s )",content.product_name,content.friendly_product_name)
end


if content["firmware_version"] then
  local version = content["firmware_version"]
  local newversion
  local pos
  pos=find(version, "%-[^%-]*$")
  if pos ~= nil then
     newversion = sub(version, 1, pos-1)
  end
  if content.fwversion_override ~= "" then
    if content.fwversion_override == "override1" then
      pos=find(version, "%-")
      if pos ~= nil then
         newversion = sub(version, 1, pos-1)
      end
    else
      newversion = content.fwversion_override
    end
  end
  if newversion then
     version=newversion
  end
  content["firmware_version"] = content.fwversion_prefix .. version .. content.fwversion_suffix
end
content["uptime"] = content_helper.readfile("/proc/uptime","number",floor)
content["system_time"] = os.date("%F %T", os.time())

-- NTP Servers
local ntp_columns = {
  {
    header = T"Server name",
    name = "ntp_server",
    param = "value",
    type = "text",
  }
}

-- Function to check the NTP server input and throws error if the entry/ip falls between IPv4 loopback range or it is a IPv4 subnet mask.
local function checkNTP(ip)
  if ip and inet.isValidIPv4(untaint(ip)) then
    if post_helper.validateIPv4Netmask(ip) then
      return nil,T"Cannot use IPv4 subnet mask."
    end
    local startLoopback = "127.0.0.0"
    local endLoopback = "127.255.255.255"
    if not (startLoopback <= ip and ip <= endLoopback) then
      return true
    else
      return nil,T"Cannot use loopback IPv4 address range."
    end
  end
end

local function validateNTP(value, object, key)
-- Adding localdevicemask in post to find the input is a network or broadcast IPv4 address in advancedIPValidation
  object["localdevmask"] = proxy.get("uci.network.interface.@lan.netmask")[1].value
  local ntp_servers = session:retrieve("ntp_data")
  if ntp_servers then
    for _,v in pairs(ntp_servers) do
       if (v[1] == value) then
         return nil, T"Duplicate entry is not allowed"
       end
    end
  end

  if post_helper.validateStringIsIP(value) then
    local ipaddr = proxy.get("rpc.network.interface.@lan.ipaddr")[1].value
    local wan_ipaddr = proxy.get("rpc.network.interface.@wan.ipaddr")[1].value
    if ipaddr and ipaddr == value then
       return nil, T"Cannot use the gateway IP address."
    elseif wan_ipaddr and wan_ipaddr == value then
       return nil, T"Cannot use the gateway WAN IP address."
    else
       local IPValidation = gOV(gAV(checkNTP, post_helper.advancedIPValidation), post_helper.validateStringIsIPv6)
       return IPValidation(value, object, key)
    end
  else
    return post_helper.validateStringIsDomainName(value)
  end
end

local ntp_valid = {
  ntp_server = validateNTP
}

local ntp_options = {
  tableid = "ntp_servers",
  basepath = "uci.system.ntp.server.@.",
  createMsg = T"Add new NTP server",
  minEntries = 1,
  maxEntries = 3,
}

if(session:getrole() ~= "engineer") then
   ntp_options.canEdit = false
	ntp_options.canAdd = true
   ntp_options.canDelete = false
end

local ntp_data, ntp_helpmsg = post_helper.handleTableQuery(ntp_columns, ntp_options, nil, nil, ntp_valid)
session:store("ntp_data",ntp_data)

-- Configurable system parameters
local system_params = {
  system_timezone = "uci.system.system.@system[0].timezone",
  system_zonename = "uci.system.system.@system[0].zonename",
  system_network_timezone = "uci.system.system.@system[0].network_timezone",
  system_hostname = "uci.system.system.@system[0].hostname",
}

local system_valid = {
  system_timezone = function(value, object, key)
    local gui_tz = value
    local valid, helpmsg = post_helper.validateNonEmptyString(value)
    if valid then
      local tz_value, zonename_value = string.match(gui_tz,'(.*)_timezone_(.*)')

      --tz_value is the matched result from tz_helper.lua, can not be empty string
      if not tz_value or not zonename_value then
        return valid, helpmsg
      end

      object["system_timezone"] = tz_value
      object["system_zonename"] = zonename_value
    end
    return valid, helpmsg
  end,
  system_zonename = function(value, object,key)
    return true
  end,
  system_network_timezone = function(value, object, key)
    local err,msg = vB(value, object, key)
    if err then
      return err,msg
    end

    if object[key] == "1" then
      object["system_timezone"] = nil
      object["system_zonename"] = nil
    end
    return true
  end,
  system_hostname = function(value)
    if #value == 0 then
       return true
	end
    return false
  end,
}

local cui = {
  upgradefw = "uci.web.uiconfig.@uidefault.upgradefw",
}
content_helper.getExactContent(cui)

local system_data,system_helpmsg = post_helper.handleQuery(system_params, system_valid)

-- Get timezones
local timezones = require("tz_helper")

local function getTimeZoneName(list, isRemote)
  local default_tztable = {
    [true] = "UTC",
    [false] = nil,
  }

  local tz = system_data["system_timezone"]
  local tz_name = system_data["system_zonename"]
  if tz == "" then
    return default_tztable[isRemote]
  end

  if isRemote then
    default_tztable[isRemote] = tz
  end

  if tz_name ~= "" then
    if isRemote then
      return tz_name
    else
      return tz .. "_timezone_" .. tz_name
    end
  end

  for _,v in ipairs(list) do
    local key = string.match(v[1], "^([^_]*)")
    if key == tz then
      if isRemote then
        return v[2]
      else
        return v[1]
      end
    end
  end
  return default_tztable[isRemote]
end

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Modem", true, true))   ngx.print('\
<div class="modal-body update">\
');
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
  <legend>'); ngx.print( T"Global Information" ); ngx.print('</legend>\
    <form class="form-horizontal" method="post" action="modals/gateway-modal.lp">')
      local basic = {
        span = {
          class = "span5"
        },
      }
	  local long_basic = {
        span = {
          class = "span6"
        },
      }
      local advanced = {
        group = {
          class = "advanced hide",
        },
        span = {
          class = "span5"
        },
      }
	  local advancedshow = {
        group = {
          class = "advanced show",
        },
        span = {
          class = "span5"
        },
      }
      local wait_for_reboot = {
        group = {
          class = "wait-for-reboot"
        },
        button = {
          id = "btn-system-reboot",
          class = "custom-handler"
        }
      }
      local rebooting = {
        alert = {
          class = "alert hide",
          id = "rebooting-msg"
        }
      }
      local wait_for_reset = {
        group = {
          class = "wait-for-reset"
        },
        button = {
          id = "btn-system-reset",
          class = "custom-handler"
        }
      }
      local resetting = {
        alert = {
          class = "alert hide",
          id = "resetting-msg"
        }
      }
      local export_config = {
        button = {
          class = "export-config custom-handler"
        }
      }
      local exporting_alert = {
        alert = {
          class = "alert-info hide",
          id = "exporting-msg"
        }
      }
      local exporting_fail = {
        alert = {
          class = "alert-error hide",
          id = "export-failed-msg"
        }
      }
      local import_config = {
        button = {
          class = "import-config custom-handler",
          id = "btn-import"
        }
      }
      local importing_nofile = {
        alert = {
          class = "alert-error hide",
          id = "import-nofile-msg"
        }
      }
      local importing_alert = {
        alert = {
          class = "alert-info hide",
          id = "importing-msg"
        }
      }
      local importing_fail = {
        alert = {
          class = "alert-error hide",
          id = "import-failed-msg"
        }
      }
      local importing_wrong_ext_fail = {
        alert = {
          class = "alert-error hide",
          id = "import-wrong-ext-msg"
        }
      }
      local importing_too_big_fail = {
        alert = {
          class = "alert-error hide",
          id = "import-too-big-msg"
        }
      }
      local upgradefw = {
        button = {
          class = "upgradefw",
          id = "btn-upgrade"
        }
      }
      local upgrading_nofile = {
        alert = {
          class = "alert-error hide",
          id = "upgrade-nofile-msg"
        }
      }
      local upgrading_transfer = {
        alert = {
          class = "alert hide",
          id = "upgrade-transfer-msg"
        }
      }
      local upgrading_busy = {
        alert = {
          class = "alert hide",
          id = "upgrade-busy-msg"
        }
      }
      local upgrading_fail = {
        alert = {
          class = "alert-error hide",
          id = "upgrade-failed-msg"
        }
      }
      local upgrading_wrong_ext_fail = {
        alert = {
          class = "alert-error hide",
          id = "upgrade-wrong-ext-msg"
        }
      }
      local upgrading_too_big_fail = {
        alert = {
          class = "alert-error hide",
          id = "upgrade-too-big-msg"
        }
      }
      local nw_enable_class = {
        input = {
          class = "monitor-changes",
          --disabled = "disabled",
        }
      }
      local default_tz_class = {
        group = {
          class = "monitor-system_network_timezone monitor-1"
        }
      }
      local user_tz_class = {
        group = {
          class = "monitor-system_network_timezone monitor-0"
        }
      }
	  local reset_on_update = {
        input = {
            class = "no-save",
        }
    }

      local html = {}
      html[#html + 1] = ui_helper.createLabel(T"Product Vendor", content["vendor"], basic)
      html[#html + 1] = ui_helper.createLabel(T"Product Name", content["product_name"], basic)
      html[#html + 1] = ui_helper.createLabel(T"Software Version", content["firmware_version"], basic)
	  html[#html + 1] = ui_helper.createLabel(T"Hostname", system_data["system_hostname"], advancedshow )
	  html[#html + 1] = ui_helper.createInputText(T"Hostname", "system_hostname", system_data["system_hostname"], advanced , system_helpmsg["system_hostname"] )
      --html[#html + 1] = ui_helper.createLabel(T"Firmware Version", content["firmware_version"], basic)
	  html[#html + 1] = ui_helper.createLabel(T"Datapump Version", content["dsl_firmware"], basic)
      html[#html + 1] = ui_helper.createLabel(T"Firmware OID", content["firmware_oid"], basic)
      html[#html + 1] = ui_helper.createLabel(T"Bootloader Version", content["bootloader_version"], long_basic)
      html[#html + 1] = ui_helper.createLabel(T"Bootloader OID", content["bootloader_oid"], basic)
      html[#html + 1] = ui_helper.createLabel(T"Hardware Version", content["hardware_version"], basic)
      html[#html + 1] = ui_helper.createLabel(T"Serial Number", content["serial_number"], basic)
      html[#html + 1] = ui_helper.createLabel(T"MAC Address", content["mac_address"], basic)
      html[#html + 1] = ui_helper.createLabel(T"Uptime", post_helper.secondsToTime(content["uptime"]), basic)
      html[#html + 1] = ui_helper.createLabel(T"System Time", content["system_time"], basic)
--      html[#html + 1] = ui_helper.createInputSelect(T"Timezone", "system_timezone", timezones, system_data["system_timezone"], basic)
	if tech then
      html[#html + 1] = ui_helper.createSwitch(T"Network Timezone", "system_network_timezone", system_data["system_network_timezone"], nw_enable_class)
      local currentTZ_remote = getTimeZoneName(timezones, true)
      local currentTZ_gui = getTimeZoneName(timezones, false)
      html[#html + 1] = ui_helper.createLabel(T"Current Timezone", currentTZ_remote, default_tz_class)
      html[#html + 1] = ui_helper.createInputSelect(T"Current Timezone", "system_timezone", timezones, currentTZ_gui, user_tz_class)
	else
	  local netTimez = "On"
	  if system_data["system_network_timezone"] == "0" then
		netTimez = "Off"
	  end		
	  html[#html + 1] = ui_helper.createLabel(T"Network Timezone", netTimez)
      html[#html + 1] = ui_helper.createLabel(T"Current Timezone", system_data["system_zonename"])
      end
      -- NTP servers
      html[#html + 1] = format('<div class="control-group advanced hide"><label class="control-label">%s</label><div class="controls">', T"NTP servers")
      html[#html + 1] = ui_helper.createTable(ntp_columns, ntp_data, ntp_options, nil, ntp_helpmsg)
      html[#html + 1] = '</div></div>'

      html[#html + 1] = ui_helper.createAlertBlock(T"Restarting, please wait...", rebooting)
      html[#html + 1] = ui_helper.createButton(T"Restart Device", T"Restart", "icon-refresh", wait_for_reboot)
      html[#html + 1] = ui_helper.createAlertBlock(T"Resetting to factory defaults, please wait...", resetting)
      html[#html + 1] = ui_helper.createButton(T"Factory Defaults", T"Reset", "icon-bolt", wait_for_reset)
      html[#html + 1] = ui_helper.createButton(T"Export Configuration", T"Export", "icon-download-alt", export_config)
      html[#html + 1] = ui_helper.createAlertBlock(T"Exporting configuration, please wait...", exporting_alert)
      html[#html + 1] = ui_helper.createAlertBlock(T"Exporting failed; please try again.", exporting_fail)
      html[#html + 1] = '</form><form class="form-horizontal" id="form-import" method="post" action="modals/gateway-modal.lp?action=import_config" enctype="multipart/form-data">'
      html[#html + 1] = '<div class="control-group">'
      html[#html + 1] = format('<label class="control-label">%s</label>', T"Import Configuration")
      html[#html + 1] = '<div class="controls">'
      html[#html + 1] = '<input type="file" name="configfile" id="file-import">&nbsp;'
      html[#html + 1] = ui_helper.createSimpleButton(T"Import", "icon-upload-alt", import_config)
      html[#html + 1] = '</div></div>'
      html[#html + 1] = ui_helper.createAlertBlock(T"No file selected.", importing_nofile)
      html[#html + 1] = ui_helper.createAlertBlock(T"Importing configuration, please wait...", importing_alert)
      html[#html + 1] = ui_helper.createAlertBlock(T"Importing failed; please try again.", importing_fail)
      html[#html + 1] = ui_helper.createAlertBlock(T"Importing failed; Invalid file used: expected file with extension bin.  Please use correct file.", importing_wrong_ext_fail)
      html[#html + 1] = ui_helper.createAlertBlock(T"Importing failed; Invalid file used: file too large.  Please use correct.  Please use correct file..", importing_too_big_fail)

	if tech then		 
      if cui.upgradefw == "1" then
        if cui.upgradefw == "1" then
		  html[#html + 1] = ui_helper.createAlertBlock(T"Check this to remove config after firmware update.<br/>This won't remove root.<br/>It is advertised to check this if you are downgrading the firmware.", basic)
		  html[#html + 1] = ui_helper.createInputCheckbox(T"Remove config file with upgrade","remove_conf","0",reset_on_update)
          html[#html + 1] = '</form><form class="form-horizontal" id="form-upgradefw" method="post" enctype="multipart/form-data">'
          html[#html + 1] = '<div class="control-group">'
          html[#html + 1] = format('<label class="control-label">%s</label>', T"Update firmware")
          html[#html + 1] = '<div class="controls">'
          html[#html + 1] = '<input type="file" name="upgradefile" id="file-upgradefw">&nbsp;'
          html[#html + 1] = ui_helper.createSimpleButton(T"Update", "icon-shield", upgradefw)
          html[#html + 1] = '</div></div>'
          html[#html + 1] = ui_helper.createAlertBlock(T"No file selected.", upgrading_nofile)
          html[#html + 1] = ui_helper.createAlertBlock(T"Uploading firmware, please wait...", upgrading_transfer)
          html[#html + 1] = ui_helper.createAlertBlock(T"Firmware update in progress, please wait...", upgrading_busy)
          html[#html + 1] = ui_helper.createAlertBlock("", upgrading_fail)
          html[#html + 1] = ui_helper.createAlertBlock(T"Firmware update failed.  Invalid file used: expected file with extension rbi.  Please use correct firmware.", upgrading_wrong_ext_fail)
          html[#html + 1] = ui_helper.createAlertBlock(T"Firmware update failed.  Invalid file used: file too large.  Please use correct firmware.", upgrading_too_big_fail)
		  html[#html + 1] = '</form>'
		  html[#html + 1] = '<form class="form-horizontal">'
        end
	  end
      html[#html + 1] = ui_helper.createLabel(T"ACS URL", content["acs_url"], basic)
    end  
	ngx.print(html)

    local html = {}
	html[#html + 1] = '<legend>'.. T"Bank Info" ..'</legend>'
    html[#html + 1] = ui_helper.createLabel(T"Active Bank", content["activebank"] , basic)
	html[#html + 1] = ui_helper.createLabel(T"Active Version", content["activeversion"] , long_basic)
	html[#html + 1] = ui_helper.createLabel(T"Passive Bank", content["passivebank"] , basic)
	if content["passiveversion"] == "Unknown" then
		html[#html + 1] = ui_helper.createLabel(T"Passive Version", T"Firmware not present in this bank" , long_basic)
	else
		html[#html + 1] = ui_helper.createLabel(T"Passive Version", content["passiveversion"] , long_basic)
	end
    ngx.print(html)
	
    local html = {}
	html[#html + 1] = '<legend>'.. T"Key Info" ..'</legend>'
    html[#html + 1] = ui_helper.createLabel(T"Config decrypt key", content["rip_key_B"] , basic)

    ngx.print(html)
    ngx.print('\
  </form>\
 </fieldset>\
</div>\
');
ngx.print('\
<script>\
(function() {\
  var refreshTimeOut = 5000;\
  var refreshDelay = 3000;\
  var target = $(".modal form").attr("action");\
\
  function wait_for_webserver_running() {\
    $.ajax({ url: "/", timeout: refreshTimeOut })\
    .done(function(data) {\
      window.location.href = "/";\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
\
  function wait_for_webserver_down() {\
    $.ajax({ url: target, timeout: refreshTimeOut })\
    .done(function() {\
      window.setTimeout(wait_for_webserver_down, refreshDelay);\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
\
  function resetreboot(msg, msg_dst, action) {\
    msg_dst.replaceWith(msg);\
    msg.removeClass("hide");\
    msg[0].scrollIntoView();\
    $.post(\
      target,\
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      wait_for_webserver_down,\
      "json"\
    );\
    return false;\
  }\
  $("#btn-system-reboot").on("click", function() {\
      var heading = "');  ngx.print(T'Restart Device'); ngx.print('";\
      var processMsg = "');  ngx.print(T'Rebooting'); ngx.print('";\
      confirmationDialogue(\'');  ngx.print(T"Do you want to continue?"); ngx.print('\',heading);\
	  var PopUpHeaderText = "."+$(".popUp>.header>.header-title>p").text().split(" ")[0];\
      $(document).on("click", PopUpHeaderText, function() {\
           tch.removeProgress();\
           tch.showProgress(processMsg);\
		   console.log("test");\
           return resetreboot($("#rebooting-msg"), $(this), "system_reboot" );\
	  });\
  });\
\
  $("#btn-system-reset").on("click", function() {\
      var heading = "');  ngx.print(T'Factory Defaults'); ngx.print('";\
      var processMsg = "');  ngx.print(T'Resetting'); ngx.print('";\
      confirmationDialogue(\'');  ngx.print(T"Do you want to continue? "); ngx.print('\',heading);\
	  var PopUpHeaderText = "."+$(".popUp>.header>.header-title>p").text().split(" ")[0];\
      $(document).on("click", PopUpHeaderText, function() {\
          tch.removeProgress();\
          tch.showProgress(processMsg);\
          return resetreboot($("#resetting-msg"), $(this), "system_reset");\
	  });\
  });\
\
  $(document).on("click", "#cancel", function() {\
      tch.removeProgress();\
  });\
\
  $(".export-config").on("click", function() {\
    $.fileDownload(target, {\
      httpMethod: "POST",\
      data: new Array({ name : "action", value : "export_config" },\
                      { name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") }),\
      prepareCallback: function() {\
        $("#export-failed-msg").addClass("hide");\
        var exporting_msg = $("#exporting-msg");\
        exporting_msg.removeClass("hide");\
        exporting_msg[0].scrollIntoView();\
      },\
      successCallback: function() {\
        $("#exporting-msg").addClass("hide");\
      },\
      failCallback: function() {\
        var export_failed_msg = $("#export-failed-msg");\
        export_failed_msg.removeClass("hide");\
        export_failed_msg[0].scrollIntoView();\
        $("#exporting-msg").addClass("hide");\
      }\
    });\
    return false;\
  });\
\
  $(".import-config").on("click", function() {\
    var nofile_msg = $("#import-nofile-msg");\
    var wrongext_msg = $("#import-wrong-ext-msg");\
    var toobig_msg = $("#import-too-big-msg");\
    if ($("#file-import").val() == "") {\
      nofile_msg.removeClass("hide");\
      nofile_msg[0].scrollIntoView();\
      return false;\
    }\
    nofile_msg.addClass("hide");\
\
    var validExtensions = [\'bin\'];\
    var fileName = $("#file-import").val();\
    var fileNameExt = fileName.substr(fileName.lastIndexOf(\'.\') + 1);\
    if ($.inArray(fileNameExt, validExtensions) == -1){\
        wrongext_msg.removeClass("hide");\
	wrongext_msg[0].scrollIntoView();\
	return false;\
    }\
    var fileSize = $("#file-import")[0].files[0].size;\
    if (fileSize > 1048576) {\
        toobig_msg.removeClass("hide");\
	toobig_msg[0].scrollIntoView();\
	return false;\
    }\
\
    var _this = $(this).parents(".control-group");\
    $("#import-failed-msg").addClass("hide");\
    var importing_msg = $("#importing-msg");\
    importing_msg.removeClass("hide");\
    importing_msg[0].scrollIntoView();\
    $.fileUpload($("#form-import"), {\
      params: { CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      completeCallback: function(form, response) {\
        $("#importing-msg").addClass("hide");\
        if (response.success) {\
          var msg = $("#rebooting-msg");\
          var msg_dst = $(_this);\
          msg_dst.after(msg);\
          msg.removeClass("hide");\
          msg[0].scrollIntoView();\
          wait_for_webserver_down();\
        }\
        else {\
          $("#import-failed-msg").removeClass("hide");\
		  if(response.error == "buildversion"){\
		  $("#import-failed-msg").text("'); ngx.print(T'The Backup file you try to load has not been taken from the actual SW-Release, please use correct Backup File'); ngx.print('");\
		  }\
        }\
      }\
    });\
    return false;\
  });\
\
  function wait_for_upgradefw() {\
\
 // Do not use the default values.\
 // On low memory boards sysupgrade use all resources.\
 // Do not request too often an upgradefwstatus.\
 // It takes more than 5 sec to check if sysupgrade is running.\
 // Sysupgrade is running for at least 10 sec.\
\
    var upgrfw_refreshTimeOut = 15000;\
    var upgrfw_refreshDelay = 10000;\
    var msg = $("#upgrade-busy-msg");\
    var msg_dst = $(this);\
    msg_dst.after(msg);\
    msg.removeClass("hide");\
    msg[0].scrollIntoView();\
    function waitForShutdownOrError() {\
      $.ajax({ url: target, data: "action=upgradefwstatus", timeout: upgrfw_refreshTimeOut, dataType: "json" })\
      .done(function(data) {\
        if (data.success == "true") {\
          window.setTimeout(waitForShutdownOrError, upgrfw_refreshDelay);\
        }\
        else {\
          msg.addClass("hide");\
          var failure_msg = $("#upgrade-failed-msg");\
          switch (data.errorcode) {\
          case "1":\
            failure_msg.text("');  ngx.print( T'Firmware update failed.  Insufficient free memory available. Please reboot and try again.' ); ngx.print('");\
            break;\
          case "10":\
          case "255":\
            failure_msg.text("');  ngx.print( T'Firmware update failed; please use the correct firmware.' ); ngx.print('");\
            break;\
          case "15":\
            failure_msg.text("');  ngx.print( T'Firmware update failed; build signed with wrong key' ); ngx.print('");\
            break;\
          default:\
            failure_msg.text("');  ngx.print( T'Firmware update failed.' ); ngx.print('");\
            break;\
          }\
          failure_msg.text(failure_msg.text() + " (');  ngx.print( T'Errorcode: ' ); ngx.print('" + data.errorcode + ")")\
          failure_msg.removeClass("hide");\
          failure_msg[0].scrollIntoView();\
          tch.removeProgress()\
        }\
      })\
      .fail(wait_for_webserver_running)\
    }\
    window.setTimeout(waitForShutdownOrError, upgrfw_refreshDelay);\
    return false;\
  }\
\
  $(".upgradefw").on("click", function() {\
    var nofile_msg = $("#upgrade-nofile-msg");\
    var wrongext_msg = $("#upgrade-wrong-ext-msg");\
    var toobig_msg = $("#upgrade-too-big-msg");\
    if ($("#file-upgradefw").val() == "") {\
      nofile_msg.removeClass("hide");\
      nofile_msg[0].scrollIntoView();\
      return false;\
    }\
    nofile_msg.addClass("hide");\
\
    var validExtensions = [\'rbi\',\'fw\'];\
    var fileName = $("#file-upgradefw").val();\
    var fileNameExt = fileName.substr(fileName.lastIndexOf(\'.\') + 1);\
    if ($.inArray(fileNameExt, validExtensions) == -1){\
        wrongext_msg.removeClass("hide");\
	wrongext_msg[0].scrollIntoView();\
	return false;\
    }\
    wrongext_msg.addClass("hide");\
    var fileSize = $("#file-upgradefw")[0].files[0].size;\
\
    $.ajax({ url: target, data: "action=getbanksize", timeout: refreshTimeOut, dataType: "json" })\
      .done(function(data) {\
          if (data.success == "true") {\
	    var targetBankSize = Number(data.banksize);\
\
	    if (fileSize > targetBankSize) {\
    		toobig_msg.removeClass("hide");\
		toobig_msg[0].scrollIntoView();\
		return false;\
	    }\
	  }\
      })\
    toobig_msg.addClass("hide");\
\
    var _this = $(this).parents(".control-group");\
    $("#upgrade-failed-msg").addClass("hide");\
    var upgrading_msg = $("#upgrade-transfer-msg");\
    upgrading_msg.removeClass("hide");\
    upgrading_msg[0].scrollIntoView();\
    tch.showProgress("');  ngx.print(T'Upgrading...'); ngx.print('");\
	if ($("input[name=\'remove_conf\']").is(":checked")) {\
		$("#form-upgradefw").attr("action", "modals/gateway-modal.lp?action=upgradefw_reset"); } \
	else {\
		$("#form-upgradefw").attr("action", "modals/gateway-modal.lp?action=upgradefw"); }\
    $.fileUpload($("#form-upgradefw"), { \
      params: { CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      completeCallback: function(form, response) {\
        $("#upgrade-transfer-msg").addClass("hide");\
        if (response.success) {\
          wait_for_upgradefw.call(_this);\
        }\
        else {\
          $("#upgrade-failed-msg").removeClass("hide");\
        }\
      }\
    });\
    return false;\
  });\
}());\
</script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
');
