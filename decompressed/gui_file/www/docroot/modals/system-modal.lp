--pretranslated: do not change this file
 
-- Enable localization
-- NG-92911 SSH Enable for LAN/WAN is not working for Engineer User
gettext.textdomain('webui-core')

local ngx, string = ngx, string
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local format, match = string.format, string.match
local untaint = string.untaint 

local gOV = post_helper.getOptionalValidation

local spoof_mode_enum = {
	{ "disabled" , T"Comunicate real version to cwmp"},
	{ "enabled" , T"Comunicate latest stable version set from rootscript to cwmp"},
	{ "manual" , T"Set the version to comunicate to cwmp manually"},
}

local function validateVersionSpoofMode(value, object, key)

	local valid, msg = post_helper.getValidateInEnumSelect(spoof_mode_enum)

	if valid then
		local version_path="uci.versioncusto.override.fwversion_override"
		local version_real=proxy.get(version_path.."_real")[1].value
		local version_latest=proxy.get(version_path.."_latest")[1].value
		if value == "disabled" then
			proxy.set(version_path, version_real)
		elseif value == "enabled" then
			proxy.set(version_path,version_latest)
		end
		proxy.apply()
	end
	
	return valid, msg
end

local fwversion_override_Params = { 
	fwversion_override = "uci.versioncusto.override.fwversion_override", 
	version_spoof_mode = "uci.modgui.var.version_spoof_mode",
}

local fwversion_override_valid = { 
	fwversion_override = gOV(post_helper.validateNonEmptyString),
	version_spoof_mode = validateVersionSpoofMode,
}

local fwversion_override_content, fwversion_override_helpmsg = post_helper.handleQuery(fwversion_override_Params, fwversion_override_valid)

local env = {
  factory = "uci.env.rip.factory_id",
  serial = "uci.env.rip.serial",
  fwversion_latest = "uci.versioncusto.override.fwversion_override_latest",
  fwversion_real = "uci.versioncusto.override.fwversion_override_real",
}
content_helper.getExactContent(env)

-- Check availability of file, return true if found, else false
local function file_check(file_name)
  local file_found=io.open(file_name, "rb")
  if file_found==nil then
    return false
  else
    return true
  end
end

local serial_num = format("%s%s",env.factory,env.serial)
local syslog_present, syslog_filter_sw = "0", "0"

-- SSH Access
local ssh_lan, ssh_wan = "0", "0"    -- assume disabled
local ssh_lan_index, ssh_wan_index = "-1", "-1"
local enable = 0
local ssh_wan_new, ssh_lan_new

-- local function to handle setting firewall rule
-- parameter target will have a value of DROP or ACCEPT for SSH-wan entry
local function set_firewall(target)
   -- go through rules to find SSH-wan anonymous section name
   local rules = proxy.get("uci.firewall.rule.")
   for _,v in ipairs(rules) do
      if v.param == "name" and untaint(v.value) == "SSH_wan" then
         proxy.set(v.path.."target", target)
         return
      end
   end
end


local dbpath = "uci.dropbear.dropbear."
local dbvalues = proxy.get(dbpath)
local data = content_helper.convertResultToObject(dbpath, dbvalues)

for _,v in pairs(data) do
  if v.Interface == "lan" then
    ssh_lan = v.enable
    ssh_lan_index = v.paramindex
  elseif v.Interface == "wan" then
    ssh_wan = v.enable
    ssh_wan_index = v.paramindex
  end
end
	
local Syslog = proxy.get("uci.system.system.@system[0].log_ip","uci.system.system.@system[0].log_filter_ip")
if Syslog[1].value ~= "" or Syslog[2].value ~= "" then
  syslog_present = "1"
  if Syslog[2].value ~= "" then
    syslog_filter_sw = "1"
  end
end

if ngx.var.request_method == "POST" then
  local vars = ngx.req.get_post_args()
  if vars["action"] == "SAVE" then
    -- SSH Access
    ssh_wan_new = untaint(vars["ssh_wan"])
    ssh_lan_new = untaint(vars["ssh_lan"])
    local db_path = "uci.dropbear.dropbear.@dropbear["

    -- set lan
    if ssh_lan_new ~= ssh_lan then
       ssh_lan = ssh_lan_new
       proxy.set(dbpath..ssh_lan_index.. ".enable", ssh_lan)
       -- Log  that someone has changed SSH access
       ngx.log(ngx.ALERT, "Local Setting of SSH on lan to "..ssh_lan)
    end

    -- set wan
    if ssh_wan_new ~= ssh_wan then
       ssh_wan = ssh_wan_new
       proxy.set(dbpath..ssh_wan_index.. ".enable", ssh_wan)
       if ssh_wan == "1" then
          set_firewall("ACCEPT")
       else
          set_firewall("DROP")
       end
       -- Log  that someone has changed SSH access
       ngx.log(ngx.ALERT, "Local Setting of SSH on wan to "..ssh_wan)
    end

    syslog_present = vars["syslog_present"]
    syslog_filter_sw = vars["syslog_filter_sw"]
    proxy.set("uci.system.system.@system[0].log_ip","")
    proxy.set("uci.system.system.@system[0].log_filter_ip","")
    proxy.apply()
  end
end



---[[
-- Syslog filters
local filter_columns = {
  {
    header = T"Filter",
    name = "filter_string",
    param = "value",
    type = "text",
  }
}

local function validateFilter(value, object, key)
    return true
end

local filter_valid = {
  filter_string = validateFilter
}

local filter_options = {
  tableid = "syslog_filters",
  basepath = "uci.system.system.@system[0].log_filter.@.",
  createMsg = T"Add new Syslog Filter",
  minEntries = 1,
  maxEntries = 10,
}


local filter_data, filter_helpmsg = post_helper.handleTableQuery(filter_columns, filter_options, nil, nil, filter_valid)

--]]



local syslog_Params = {
  syslog_filter_ip = "uci.system.system.@system[0].log_filter_ip",
  syslog_port = "uci.system.system.@system[0].log_port",
  syslog_ip = "uci.system.system.@system[0].log_ip",
}

local gVIPIL = post_helper.getValidationIfPropInList
local vSII = post_helper.validateStringIsIP
local vB = post_helper.validateBoolean
local vSIPR = post_helper.validateStringIsPortRange
local gOV = post_helper.getOptionalValidation
local vNES = post_helper.validateNonEmptyString

local function valid_comma_string(value)
  local rc, msg = vNES(value)
  if not rc then
    return rc, msg
  end
  if string.match(value, "[^%w,]") then
    return nil, T"Only alphanumeric characters, commas (,), full spots(.), underscores(_) and hiphens(-) are allowed, no spaces"
  end
    return true
end

local syslog_valid = {
  syslog_present = vB,
  syslog_filter_sw = vB,
  syslog_ip = gVIPIL(gVIPIL(gOV(vSII), "syslog_filter_sw", {"0"}), "syslog_present", {"1"}),
  syslog_filter_ip = gVIPIL(gVIPIL(gOV(vSII), "syslog_filter_sw", {"1"}), "syslog_present", {"1"}),
  syslog_port = gVIPIL(vSIPR, "syslog_present", {"1"}),
}
local syslog_Params, helpmsg = post_helper.handleQuery(syslog_Params, syslog_valid)

local telnet_available = file_check("/bin/busybox_telnet")
local telnet_content

if telnet_available then
	local telnet_Params = { telnet_enable = "uci.telnet.general.enable" }	
	
	local telnet_valid = { telnet_enable = vB }
	
	telnet_content, helpmsg = post_helper.handleQuery(telnet_Params, telnet_valid)
end

local bank_check_Params = { bank_check = "uci.modgui.var.bank_check" }

local bank_check_valid = { bank_check = vB }

local bank_check_content, helpmsg = post_helper.handleQuery(bank_check_Params, bank_check_valid)

local config_Params = {
  export_plaintext = "uci.system.config.export_plaintext",
  import_plaintext = "uci.system.config.import_plaintext",
  import_unsigned = "uci.system.config.import_unsigned",
  export_unsigned = "uci.system.config.export_unsigned",
  import_restricted = "uci.system.config.import_restricted",
}

local config_valid = {
  export_plaintext = vB,
  import_plaintext = vB,
  import_unsigned = vB,
  export_unsigned = vB,
  import_restricted = vB,
}

local config_content, helpmsg = post_helper.handleQuery(config_Params, config_valid)

local function wait_for_completion(base_path)
  local state_path = base_path .. "state"
  local sleep_time = 0.250
  local max_time = 7
  local total_time = 0
  local content
  repeat
    ngx.sleep(sleep_time)
    total_time = total_time + sleep_time

    content = { state = state_path }
    content_helper.getExactContent(content)

    if content.state ~= "Requested" then
      break
    end
  until (total_time >= max_time)
end

local function resetreboot(path)
  proxy.set(path, "1")
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

-- Handle fwupgrade/configimport/configexport specific GET/POSTs.
if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_post_args().action
  if action == "system_bootp" then
    return resetreboot("sys.bootp.enable")
  end
  if action == "system_switchover" then
    return resetreboot("rpc.system.switchover")
  end
  if action == "system_trasnfer_bank_1" then
    return resetreboot("rpc.system.modgui.utility.transfer_bank1")
  end
  if action == "system_copy_bank" then
    return resetreboot("rpc.system.modgui.utility.copy_bank")
  end
  if action == "debug_report" then
	
	local debuglog_path = "rpc.system.modgui.debuglog."
	
	proxy.set(debuglog_path.."start","1")
	proxy.apply()
	
	wait_for_completion(debuglog_path)
  
	local content = {
		filename = debuglog_path.."filename",
	}
	
	-- Get transformer content
	content_helper.getExactContent(content)
	
	-- return exported data
      local fname = untaint(content.filename)
      ngx.log(1, "ciao")
      ngx.log(1, fname:match("([^/]+)$"))
	if fname ~= "" then
		ngx.header.content_disposition = "attachment; filename="..fname:match("([^/]+)$")
		ngx.header.content_type = "application/octet-stream"
		ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JS download code requires this cookie
		local f = io.open(fname, "r")
		ngx.print(f:read("*all"))
		f:close()
		
		-- and we're done
		ngx.exit(ngx.HTTP_OK)
	else
		ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
	end
  end
end

local title = T"System Extras"

  ngx.print('\
');  ngx.print(ui_helper.createHeader(title, false, false))   ngx.print('\
<div class="modal-body update">\
'); 
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/system-modal.lp">\
<fieldset>\
  <legend>');  ngx.print( T"Advanced Reboot" ); ngx.print('</legend>\
    ');
      local bootp_alert = {
        alert = {
          class = "alert-info hide",
          id = "bootp-msg"
        }
      }
      local bootp = {
        group = {
          class = "wait-for-reboot"
        },
        button = {
          id = "btn-system-bootp",
          class = "custom-handler"
        }
      }
	  local switchover_alert = {
        alert = {
          class = "alert-info hide",
          id = "switchover-msg"
        }
      }
      local switchover = {
        group = {
          class = "wait-for-reboot"
        },
        button = {
          id = "btn-system-switchover",
          class = "custom-handler"
        }
      }
	  local transfer_bank1_alert = {
        alert = {
          class = "alert-info hide",
          id = "transfer-bank1-msg"
        }
      }
	  local copy_bank_alert = {
        alert = {
          class = "alert-info hide",
          id = "copy-bank-msg"
        }
      }
      local transfer_bank1 = {
        group = {
          class = "wait-for-reboot"
        },
        button = {
          id = "btn-system-transfer-bank1",
          class = "custom-handler"
        }
      }
	  local copy_bank = {
        group = {
          class = "wait-for-reboot"
        },
        button = {
          id = "btn-system-copy-bank",
          class = "custom-handler"
        }
      }
	  local info_box = {
        alert = {
			class = "alert alert-info",
		}
      }
	  local warn_box = {
        alert = {
			class = "alert",
		}
      }
      local html = {}
      html[#html + 1] = ui_helper.createButton(T"LAN Update", T"BOOTP", "icon-exchange", bootp)
      html[#html + 1] = ui_helper.createAlertBlock(T"Entering BOOTP, please wait...", bootp_alert)
	  html[#html + 1] = ui_helper.createButton(T"SwitchBank", T"Switchover", "icon-exchange", switchover)
      html[#html + 1] = ui_helper.createAlertBlock(T"Switching bank, please wait...", switchover_alert)
	  if env["activebank"] == "bank_2"
		then
		html[#html + 1] = ui_helper.createAlertBlock(T"This will transfer your configuration and firmware to bank_1 and it will erase bank_2", warn_box)
		html[#html + 1] = ui_helper.createButton(T"Transfer to", T"Bank 1", "icon-exchange", transfer_bank1)
		html[#html + 1] = ui_helper.createAlertBlock(T"Transfering bank, please wait...", transfer_bank1_alert)
	  end
	  html[#html + 1] = ui_helper.createAlertBlock(T"Clone the content of the running bank to the inactive one. Warning: this will delete all data and configuration settings on the inactive bank!", warn_box)
	  html[#html + 1] = ui_helper.createButton(T"Clone bank", T"Clone", "icon-exchange", copy_bank)
	  html[#html + 1] = ui_helper.createAlertBlock(T"Cloning bank, please wait...", copy_bank_alert)
	  html[#html + 1] = ui_helper.createAlertBlock(T"Force the device to always use “Bank_1” as the main bank.", info_box)
	  html[#html + 1] = ui_helper.createSwitch(T"Bank Check", "bank_check", bank_check_content["bank_check"])
      ngx.print(html)
      ngx.print('\
</fieldset>');
if not ( fwversion_override_content["fwversion_override"] == "" ) then
	ngx.print('\
	<fieldset>\
	<legend>');  ngx.print( T"Spoof Settings" ); ngx.print('</legend>\
		');
		local html = {}
		local info_box = {
			alert = {
				class = "alert alert-info",
			}
		}
		local long_input = {
			select = {
				class = "span5",
			}
		}
		html[#html + 1] = ui_helper.createAlertBlock(T"Disable override of Version Spoof at every GUI update. This is also usefull to permit cwmp to autoupdate the modem", info_box)
		html[#html + 1] = ui_helper.createInputSelect(T"Spoof Version Mode", "version_spoof_mode", spoof_mode_enum ,fwversion_override_content["version_spoof_mode"],long_input)
		html[#html + 1] = ui_helper.createAlertBlock(T"Input the latest stock firmware version in this field to spoof it. This is necessary because if a newer version of the firmware is available on the ACS server, CWMPD will try to update the device and break remote monitoring from the “MyTIM” mobile app.", info_box)
		html[#html + 1] = ui_helper.createInputText(T"Version Set", "fwversion_override", fwversion_override_content["fwversion_override"], nil , fwversion_override_helpmsg["fwversion_override"])
		ngx.print(html)
		ngx.print('\
	</fieldset>');
end
ngx.print('\
<fieldset>\
  <legend>');  ngx.print( T"Config creation option" ); ngx.print('</legend>\
    ');
	  local info_box = {
        alert = {
			class = "alert alert-info",
		}
      }
      local html = {}
	  html[#html + 1] = ui_helper.createAlertBlock(T"Enable what type of configuration you want to import and export.", info_box)
	  html[#html + 1] = ui_helper.createSwitch(T"Export PlainText", "export_plaintext", config_content["export_plaintext"])
	  html[#html + 1] = ui_helper.createSwitch(T"Export UnSigned", "export_unsigned", config_content["export_unsigned"])
	  html[#html + 1] = ui_helper.createSwitch(T"Import PlainText", "import_plaintext", config_content["import_plaintext"])
	  html[#html + 1] = ui_helper.createSwitch(T"Import UnSigned", "import_unsigned", config_content["import_unsigned"])
	  html[#html + 1] = ui_helper.createAlertBlock(T"An imported configuration file will only be applied if its firmware version matches the currently installed one.’", info_box)
	  html[#html + 1] = ui_helper.createSwitch(T"Import Restricted", "import_restricted", config_content["import_restricted"])
      ngx.print(html)
      ngx.print('\
</fieldset>\
<fieldset>\
  <legend>');  ngx.print( T"Debug Report" ); ngx.print('</legend>\
    ');  
	  local generate_debug_report = {
        button = {
          id = "btn-system-debug-report",
          class = "custom-handler"
        }
      }
      local html = {}
		html[#html + 1] = ui_helper.createButton(T"Debug Zip", T"Generate", "icon-exchange", generate_debug_report)
      ngx.print(html)
      ngx.print('\
</fieldset>\
<fieldset>\
  <legend>');  ngx.print( T"SSH Access" ); ngx.print('</legend>\
    ');  
      local html = {}
      html[#html + 1] = ui_helper.createSwitch(T"LAN", "ssh_lan", ssh_lan)
      html[#html + 1] = ui_helper.createSwitch(T"WAN", "ssh_wan", ssh_wan)
      ngx.print(html)
      ngx.print('\
</fieldset>\
');
if telnet_content then
	ngx.print('\
	<fieldset>\
	<legend>');  ngx.print( T"Telnet Access" ); ngx.print('</legend>\
		');  
		local html = {}
		html[#html + 1] = ui_helper.createSwitch(T"LAN", "telnet_enable", telnet_content["telnet_enable"], basic)
		ngx.print(html)
		ngx.print('\
	</fieldset>');
end
ngx.print('\
<fieldset>\
  <legend>');  ngx.print( T"System Log" ); ngx.print('</legend>\
    ');  
      local html = {}
      local switch_class_enable = {
        input = {
          class = "monitor-changes",
        }
      }
      html[#html + 1] = ui_helper.createSwitch(T"Enable Syslog", "syslog_present", syslog_present, switch_class_enable)
      local switch_class_filter = {
        group = {
          class ="monitor-syslog_present monitor-1",
        },
        input = {
          class = "monitor-changes",
        }
      }
      local Sysloginput = {
        group = {
          class ="monitor-syslog_present monitor-1",
        },
        input = {
          maxlength= "15",
          class = "span2",
        },
      }
      local Sysloginputip_fltr = {
        group = {
          class ="monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1",
        },
        input = {
          maxlength= "15",
          class = "span2",
        },
      }
      local Sysloginputip_fltr_fltr = {
        group = {
          class ="monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1",
        },
        input = {
          maxlength= "50",
          class = "span5",
         },
      }
      html[#html+1] = [[<div class="monitor-syslog_filter_sw monitor-0 monitor-hide-syslog_filter_sw">]]
      html[#html+1] = ui_helper.createInputText(T"IP", "syslog_ip", syslog_Params["syslog_ip"], Sysloginput, helpmsg["syslog_ip"])
      html[#html+1] = [[</div>]]
      html[#html+1] = ui_helper.createInputText(T"Filter IP", "syslog_filter_ip", syslog_Params["syslog_filter_ip"], Sysloginputip_fltr, helpmsg["syslog_filter_ip"])
      html[#html+1] = ui_helper.createSwitch(T"Enable Filter", "syslog_filter_sw", syslog_filter_sw, switch_class_filter)
      local filter_warning = {
        alert = {
          class = "alert-info monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1"
        },
      }
      html[#html + 1] = ui_helper.createAlertBlock(T"Every filter is a regular expression string; Start with '!' to invert selection", filter_warning)
      html[#html + 1] = format('<div class="control-group"><label class="control-label monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1">%s</label><div class="controls">', T"Syslog filters")
      html[#html+1] = ui_helper.createTable(filter_columns, filter_data, filter_options, Sysloginputip_fltr_fltr, filter_helpmsg)
      html[#html + 1] = '</div></div>'
      html[#html+1] = ui_helper.createInputText(T"Port", "syslog_port", syslog_Params["syslog_port"], Sysloginput, helpmsg["syslog_port"])
      ngx.print(html)
      ngx.print('\
</fieldset></form>\
</div>\
<script>\
(function() {\
  var refreshTimeOut = 5000;\
  var refreshDelay = 3000;\
  var target = $(".modal form").attr("action");\
\
  function wait_for_webserver_running() {\
    $.ajax({ url: "/", timeout: refreshTimeOut, data: { check: "1"} })\
    .done(function(data) {\
      document.open("text/html");\
      document.write(data);\
      document.close();\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
\
  function wait_for_webserver_down() {\
    $.ajax({ url: target, timeout: refreshTimeOut, data: { check: "1"}  })\
    .done(function() {\
      window.setTimeout(wait_for_webserver_down, refreshDelay);\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
\
  function resetreboot(msg, msg_dst, action) {\
    msg_dst.after(msg);\
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
\
  $("#btn-system-bootp").on("click", function() {\
     if (confirm("');  ngx.print(T"This will put your gateway into LAN Update"); ngx.print('")){\
       tch.showProgress(\'');  ngx.print(T"Rebooting..."); ngx.print('\');\
       return resetreboot($("#bootp-msg"), $(this), "system_bootp");\
     }\
  });\
\
  $("#btn-system-switchover").on("click", function() {\
     if (confirm("');  ngx.print(T"This will switch the active bank with the passive one"); ngx.print('")){\
       tch.showProgress(\'');  ngx.print(T"Rebooting..."); ngx.print('\');\
       return resetreboot($("#switchover-msg"), $(this), "system_switchover");\
     }\
  });\
\
  $("#btn-system-transfer-bank1").on("click", function() {\
     if (confirm("');  ngx.print(T"This will transfer the active firmware and config to the bank 1"); ngx.print('")){\
       tch.showProgress(\'');  ngx.print(T"Rebooting..."); ngx.print('\');\
       return resetreboot($("#transfer-bank1-msg"), $(this), "system_trasnfer_bank_1");\
     }\
  });\
\
$("#btn-system-copy-bank").on("click", function() {\
     if (confirm("');  ngx.print(T"This will clone the running bank firmware. The process will continue in the background but this could take a while. Continue?"); ngx.print('")){\
       tch.showProgress(\'');  ngx.print(T"Cloning started in background..."); ngx.print('\');\
       resetreboot($("#copy-bank-msg"), $(this), "system_copy_bank");\
	   setTimeout(function(){location.reload();}, 4000);\
     }\
  });\
  $("#btn-system-debug-report").on("click", function() {\
    $.fileDownload(target, {\
      httpMethod: "POST",\
      data: new Array({ name : "action", value : "debug_report" },\
                      { name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") }),\
      prepareCallback: function() {\
		tch.showProgress(\'');  ngx.print(T"Generating report in background..."); ngx.print('\');\
      },\
      successCallback: function() {\
		location.reload();\
      }\
    });\
    return false;\
  });\
  var fwversion_latest = "'); ngx.print(env.fwversion_latest); ngx.print('";\
  var fwversion_real = "'); ngx.print(env.fwversion_real); ngx.print('";\
  $("#version_spoof_mode").on("change", function() {\
	if ( $(this).val() == "manual" ) {\
	  $("#fwversion_override").prop("disabled", false);\
	} else {\
	  if ( $(this).val() == "enabled" ) {\
		$("#fwversion_override").val(fwversion_latest);\
	  } else if ( $(this).val() == "disabled" ) {\
		$("#fwversion_override").val(fwversion_real);\
	  }\
	  $("#fwversion_override").prop("disabled", true);\
	}\
  });\
  if ( $("#version_spoof_mode").val() == "manual" ) {\
    $("#fwversion_override").prop("disabled", false);\
  } else {\
    $("#fwversion_override").prop("disabled", true);\
  }\
  $("[name=syslog_present]").on("change", function(){\
    $("[name=syslog_ip]").val("");\
    $("[name=syslog_filter_ip]").val("");\
  });\
\
  $("#btn-serial").on("click", function(){\
    $("[name=syslog_prefix]").val("');  ngx.print(serial_num); ngx.print('");\
    $("#modal-no-change").slideUp();\
    $("#modal-changes").slideDown();\
  });\
\
  $("[name=syslog_filter_sw]").on("change", function(){\
     if ($( this ).val() == "0"){\
       $("[name=syslog_ip]").val($("[name=syslog_filter_ip]").val());\
       $("[name=syslog_filter_ip]").val("");\
       $("[name=syslog_filter]").val("daemon");\
     }\
     else{\
       $("[name=syslog_filter_ip]").val($("[name=syslog_ip]").val());\
       $("[name=syslog_ip]").val("");\
       $("[name=syslog_filter]").val("daemon");\
     }\
  });\
}());\
</script>\
');  ngx.print(ui_helper.createFooter());   ngx.print('\
'); 
