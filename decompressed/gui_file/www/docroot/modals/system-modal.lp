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

local gOV = post_helper.getOptionalValidation

local gui_skin_option = {
      { "blue", T'Blue'},
      { "violet", T'Violet'},
      { "green", T'Green'},
	  { "TIM" , T'Enhanced Tim'},
	  { "Fritz", T'Fritz!Box'},
	  { "dark-white", T'Dark/White (Fritz Based)'},
	  { "dark-midnight", T'Dark/Midnight (Fritz Based)'},
	  { "dark-red", T'Red Dark'},
}

local gui_skin_firstpage_page = {
	{ "stats", T"Stats" },
	{ "cards", T"Cards" },
	{ "telstra", T"Telstra" },
}

local gui_skin_Params = {
  gui_skin = "uci.env.var.gui_skin",
  gui_skin_firstpage = "uci.env.var.firstpage",
  gui_randomcolor = "uci.env.var.randomcolor",
}

local gui_skin_valid = {
  gui_skin = post_helper.getValidateInEnumSelect(gui_skin_option),
  gui_skin_firstpage = post_helper.getValidateInEnumSelect(gui_skin_firstpage_page),
  gui_randomcolor = post_helper.validateBoolean,
}

local gui_skin_content, helpmsg = post_helper.handleQuery(gui_skin_Params, gui_skin_valid)

local fwversion_override_Params = { fwversion_override = "uci.versioncusto.override.fwversion_override", }

local fwversion_override_valid = { fwversion_override = gOV(post_helper.validateNonEmptyString), }

local fwversion_override_content, fwversion_override_helpmsg = post_helper.handleQuery(fwversion_override_Params, fwversion_override_valid)

local env = {
  factory = "uci.env.rip.factory_id",
  serial = "uci.env.rip.serial",
  activebank = "sys.banktable.activebank",
  passivebank = "sys.banktable.passivebank",
  activeversion = "sys.banktable.activeversion",
  passiveversion = "sys.banktable.passiveversion",
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
      if v.param == "name" and string.untaint(v.value) == "SSH_wan" then
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
    ssh_wan_new = string.untaint(vars["ssh_wan"])
    ssh_lan_new = string.untaint(vars["ssh_lan"])
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

local bank_check_Params = { bank_check = "uci.env.var.bank_check" }

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
    return resetreboot("rpc.system.switchover", "1")
  end
  if action == "system_trasnfer_bank_1" then
    return resetreboot("rpc.system.transfer_bank1", "1")
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
  <legend>');  ngx.print( T"Bank Info" ); ngx.print('</legend>\
    ');  
	  local basic = {
        span = {
          class = "span8"
        },
      }
      local html = {}
      html[#html + 1] = ui_helper.createLabel(T"Active Bank", env["activebank"] , basic)
	  html[#html + 1] = ui_helper.createLabel(T"Active Version", env["activeversion"] , basic)
	  html[#html + 1] = ui_helper.createLabel(T"Passive Bank", env["passivebank"] , basic)
	  if env["passiveversion"] == "Unknown" 
		then
		html[#html + 1] = ui_helper.createLabel(T"Passive Version", T"Firmware not present in this bank" , basic)
	  else
		html[#html + 1] = ui_helper.createLabel(T"Passive Version", env["passiveversion"] , basic)
	  end
      ngx.print(html)
      ngx.print('\
</fieldset>\
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
      local transfer_bank1 = {
        group = {
          class = "wait-for-reboot"
        },
        button = {
          id = "btn-system-transfer-bank1",
          class = "custom-handler"
        }
      }
	  local info_box = {
        alert = {
			class = "alert alert-info",
		}
      }
      local html = {}
      html[#html + 1] = ui_helper.createButton(T"LAN Upgrade", T"BOOTP", "icon-exchange", bootp)
      html[#html + 1] = ui_helper.createAlertBlock(T"Entering BOOTP, please wait...", bootp_alert)
	  html[#html + 1] = ui_helper.createButton(T"SwitchBank", T"Switchover", "icon-exchange", switchover)
      html[#html + 1] = ui_helper.createAlertBlock(T"Switching bank, please wait...", switchover_alert)
	  if env["activebank"] == "bank_2"
		then
		html[#html + 1] = ui_helper.createAlertBlock(T"This will transfer your configuration and firmware to the bank_1 and it will erase bank_2", info_box)
		html[#html + 1] = ui_helper.createButton(T"Transfer to", T"Bank 1", "icon-exchange", transfer_bank1)
		html[#html + 1] = ui_helper.createAlertBlock(T"Transfering bank, please wait...", transfer_bank1_alert)
	  end
	  html[#html + 1] = ui_helper.createAlertBlock(T"This switch disable the check to force the firmware to be on bank_1", info_box)
	  html[#html + 1] = ui_helper.createSwitch(T"Bank Check", "bank_check", bank_check_content["bank_check"])
      ngx.print(html)
      ngx.print('\
</fieldset>');
if not ( fwversion_override_content["fwversion_override"] == "" ) then
	ngx.print('\
	<fieldset>\
	<legend>');  ngx.print( T"Version Spoof" ); ngx.print('</legend>\
		');
		local info_box = {
			alert = {
				class = "alert alert-info",
			}
		}
		local html = {}
		html[#html + 1] = ui_helper.createAlertBlock(T"If a newer version is present in the acs server, cwmpd will try to upgrade the modem and will not send any info. This breaks some remote app like MyTIMFisso. Change the version here to fake it.", info_box)
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
	  html[#html + 1] = ui_helper.createAlertBlock(T"This control the type of config exported and the type of config can be imported.", info_box)
	  html[#html + 1] = ui_helper.createSwitch(T"Export PlainText", "export_plaintext", config_content["export_plaintext"])
	  html[#html + 1] = ui_helper.createSwitch(T"Export UnSigned", "export_unsigned", config_content["export_unsigned"])
	  html[#html + 1] = ui_helper.createSwitch(T"Import PlainText", "import_plaintext", config_content["import_plaintext"])
	  html[#html + 1] = ui_helper.createSwitch(T"Import UnSigned", "import_unsigned", config_content["import_unsigned"])
	  html[#html + 1] = ui_helper.createAlertBlock(T"This check if the config file is provided from the same firmware versione.", info_box)
	  html[#html + 1] = ui_helper.createSwitch(T"Import Restricted", "import_restricted", config_content["import_restricted"])
      ngx.print(html)
      ngx.print('\
</fieldset>\
	<fieldset>\
	<legend>');  ngx.print( T"Gui Skin" ); ngx.print('</legend>\
		');  
		local html = {}
		html[#html + 1] = ui_helper.createInputSelect(T"Gui Skin", "gui_skin", gui_skin_option, gui_skin_content["gui_skin"])
		html[#html + 1] = ui_helper.createInputSelect(T"Gui FirstPage", "gui_skin_firstpage", gui_skin_firstpage_page, gui_skin_content["gui_skin_firstpage"])
		html[#html + 1] = ui_helper.createSwitch(T"Random Color", "gui_randomcolor", gui_skin_content["gui_randomcolor"])
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
     if (confirm("');  ngx.print(T"This will put your gateway into LAN Upgrade"); ngx.print('")){\
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
