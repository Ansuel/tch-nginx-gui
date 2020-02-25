--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local format,find,sub, match, untaint = string.format, string.find, string.sub, string.match, string.untaint
local vB = post_helper.validateBoolean
local gOV = post_helper.getOrValidation
local gAV = post_helper.getAndValidation
local gOV = post_helper.getOptionalValidation

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

    if content.state == "Complete" then
      break
    end
  until (total_time >= max_time)
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

local function sendcmd(cmd)
	proxy.set("rpc.system.modgui.utility.sendcmd", cmd)
	ngx.header.content_type = "application/json"
	ngx.print('{ "success":"true" }')
	ngx.timer.at(0, function()
		proxy.apply()
	end)
	ngx.exit(ngx.HTTP_OK)
end

local function upgradeguifile()

	local update_branch = proxy.get("uci.modgui.gui.update_branch")
	local filename
	if update_branch and ( update_branch[1].value == "dev" ) then
		filename = "GUI_dev.tar.bz2"
	else
		filename = "GUI.tar.bz2"
	end

	local fwupgrade_location = "/tmp/"


	-- flush the web template cache
	lp.flush()

	local dl = untaint(fwupgrade_location) .. filename

	local rcv_ok, rcv_errno, rcv_errmsg = receive_file(dl, 'name="upgradefile"')

	sendcmd("upgradegui_terminate")
end

local function getSupportedModel()
	local friendly_name = proxy.get("uci.env.var.prod_friendly_name")[1].value

	if friendly_name:match("DGA4130") or friendly_name:match("DGA4132") then
		return "DGA"
	elseif friendly_name:match("TG789") or friendly_name:match("TG799") and not friendly_name:match("Xtream") then
		return "TG789"
	elseif friendly_name:match("TG800") or (friendly_name:match("TG789") and friendly_name:match("Xtream")) then
		return "TG800"
	end

	return
end

local function installspecificapp()

	local device = getSupportedModel()

	local fwupgrade_location = "/tmp/"

	-- flush the web template cache
	lp.flush()

	local dl = untaint(fwupgrade_location) .. "upgrade-pack-specific" .. device .. ".tar.bz2"

	local rcv_ok, rcv_errno, rcv_errmsg = receive_file(dl, 'name="specificapp_file"')

	proxy.set("uci.modgui.app.specific_app","1")
	sendcmd("install_specificapp")
end

local function restoreFromSysupgradeBackup()
	-- flush the web template cache
	lp.flush()

	local dl = "/tmp/sysupgrade_backup.tar.gz"

	local rcv_ok, rcv_errno, rcv_errmsg = receive_file(dl, 'name="sysupgrade_backup"')

	--sendcmd("restoreSysupgradeBackup")
	ngx.header.content_type = "application/json"
	ngx.print('{ "success":"true" }')
	ngx.timer.at(0, function()
		proxy.apply()
	end)
	ngx.exit(ngx.HTTP_OK)
end

local function genSysupgradeBackup()

	local hostname = proxy.get("uci.system.system.@system[0].hostname")
	hostname = hostname and hostname[1].value or "Unknown"
	local filename = format("%s-%s.tar.gz",hostname,os.date("%d-%m-%y_%H:%m"))

	proxy.set("rpc.system.modgui.utility.sendcmd", "genSysupgradeBackup_"..filename)
	wait_for_completion("rpc.system.modgui.executeCommand.")
    
    -- return exported data
	if filename ~= "" then
		ngx.header.content_disposition = "attachment; filename="..filename
		ngx.header.content_type = "application/octet-stream"
		ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JS download code requires this cookie
		local f = io.open("/tmp/"..filename, "r")
		if f then 
			ngx.print(f:read("*all"))
			f:close()
			os.remove("/tmp/"..filename)
		
			-- and we're done
			ngx.exit(ngx.HTTP_OK)
		end
	end
	
	ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

if ngx.req.get_method() == "POST" then
	-- now process file POSTs
	local action = ngx.req.get_uri_args().action
	if action == "upgradeguifile" then
		return upgradeguifile()
	end
	if action == "installspecificapp" then
		return installspecificapp()
	end
	if action == "system_restoreBackup" then
		return restoreFromSysupgradeBackup()
	end
	-- now process non-file POSTs
	local action = ngx.req.get_post_args().action
	if action == "system_reset_gui" then
		return sendcmd("resetgui")
	end
	if action == "system_upgrade_gui" then
		return sendcmd("upgradegui_terminate")
	end
	if action == "system_install_specificapp" then
		proxy.set("uci.modgui.app.specific_app","1")
		return sendcmd("install_specificapp")
	end
	if action == "system_remove_root" then
		return sendcmd("removeroot")
	end
	if action == "system_reset_config" then
		return sendcmd("resetconfig")
	end
	if action == "system_reset_cwmp" then
		return sendcmd("resetcwmp")
	end
	if action == "system_genBackup" then
		return genSysupgradeBackup()
	end
	if proxy.get("uci.web.sessionmgr.@default.force_https")[1].value ~= ngx.req.get_post_args().gui_forcehttps then
		local mngr = require("web.sessioncontrol").loadmgr("default")
		mngr.force_https = ngx.req.get_post_args().gui_forcehttps
	end
end

local content = {
	gui_version = "uci.modgui.gui.gui_version",
	outdated_ver = "uci.modgui.gui.outdated_ver",
	new_ver = "uci.modgui.gui.new_ver",
	specific_app = "uci.modgui.app.specific_app",
	telstra_gui = "uci.modgui.app.telstra_webui",
}

content_helper.getExactContent(content)

local update_branch_option = {
	{ "stable", T'Stable'},
	{ "preview", T'Preview'},
	{ "dev", T'Dev'},
}

local gui_skin_firstpage_page = {
	{ "stats", T"Stats" },
	{ "cards", T"Cards" },
}

if content.telstra_gui == "1" then
	table.insert(gui_skin_firstpage_page, { "telstra", T"Telstra" })
end

local gui_skin_option = {
	{ "blue", T'Blue'},
	{ "violet", T'Violet'},
	{ "green", T'Green'},
	{ "TIM" , T'Enhanced Tim'},
	{ "dark-blue-unified", T"Dark Blue Unified UI"},
	{ "Fritz", T'Fritz!Box'},
	{ "dark-white_Fritz", T'Dark/White (Fritz!Box Based)'},
	{ "dark-midnight_Fritz", T'Dark/Midnight (Fritz!Box Based)'},
	{ "dark-red", T'Red Dark'},
}

local mapParams = {
	update_branch = "uci.modgui.gui.update_branch",
	update_autoupgrade = "uci.modgui.gui.autoupgrade",
	update_autoupgrade_hour = "uci.modgui.gui.autoupgrade_hour",
	gui_skin = "uci.modgui.gui.gui_skin",
	gui_skin_firstpage = "uci.modgui.gui.firstpage",
	gui_randomcolor = "uci.modgui.gui.randomcolor",
	gui_alwaysadvanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_forcehttps = "uci.web.sessionmgr.@default.force_https",
	gui_animation = "uci.modgui.gui.gui_animation",
}

local mapValid = {
	update_branch = post_helper.getValidateInEnumSelect(update_branch_option),
	update_autoupgrade = vB,
	update_autoupgrade_hour = gOV(post_helper.validateNonEmptyString),
	gui_skin = post_helper.getValidateInEnumSelect(gui_skin_option),
	gui_skin_firstpage = post_helper.getValidateInEnumSelect(gui_skin_firstpage_page),
	gui_randomcolor = vB,
	gui_alwaysadvanced = vB,
	gui_forcehttps = vB,
	gui_animation = vB,
}

local modgui_settings, helpmsg = post_helper.handleQuery(mapParams, mapValid)

ngx.print(ui_helper.createHeader(T"GUI Settings & Utility", false, false))
ngx.print('\
<div class="modal-body update">\
');
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
ngx.print('\
  <fieldset>\
	<form class="form-horizontal" method="post" action="modals/modgui-modal.lp">')

local html = {}
html[#html + 1] = '<legend>'.. T"GUI Skin" ..'</legend>'
html[#html + 1] = ui_helper.createInputSelect(T"GUI Skin", "gui_skin", gui_skin_option, modgui_settings["gui_skin"])
html[#html + 1] = ui_helper.createInputSelect(T"GUI First Page", "gui_skin_firstpage", gui_skin_firstpage_page, modgui_settings["gui_skin_firstpage"])
html[#html + 1] = ui_helper.createSwitch(T"Random Color", "gui_randomcolor", modgui_settings["gui_randomcolor"])
html[#html + 1] = ui_helper.createSwitch(T"Force HTTPS to access the GUI", "gui_forcehttps", modgui_settings["gui_forcehttps"])
html[#html + 1] = ui_helper.createSwitch(T"Always show advanced options", "gui_alwaysadvanced", modgui_settings["gui_alwaysadvanced"])
html[#html + 1] = ui_helper.createSwitch(T"GUI animations", "gui_animation", modgui_settings["gui_animation"])
ngx.print(html)

local html = {}
html[#html + 1] = '<legend id="GUI_Upgrade_Legend">' .. T"Update GUI" .. '</legend>'
local basic = {
	span = {
		class = "span5"
	},
}
local upgrade_gui = {
	group = {
		class = "wait-for-reset"
	},
	button = {
		id = "btn-upgrade-gui",
		class = "custom-handler"
	}
}
local offline_upgrade_gui = {
	group = {
		class = "wait-for-reset"
	},
	button = {
		id = "btn-offline-upgrade-gui",
		class = "custom-handler"
	}
}
local info_box = {
	alert = {
		class = "alert alert-info",
	}
}
local upgrade = {
	alert = {
		class = "alert hide",
		id = "upgrade-msg"
	}
}
local upload_gui_file = {
	button = {
		class = "import-gui custom-handler",
		id = "btn-import-gui"
	}
}
local upload_gui_fail = {
	alert = {
		class = "alert-error hide",
		id = "upgrade-gui-fail"
	}
}
local upload_gui_alert = {
	alert = {
		class = "alert-info hide",
		id = "upload-gui-alert"
	}
}
local updating = {
	alert = {
		class = "alert hide",
		id = "updating-msg"
	}
}
local autoupgrade = {
	input = {
		class = "monitor-changes",
	}
}
local autoupgrade_mon_1 = {
	group = {
		class ="monitor-update_autoupgrade monitor-1",
	},
	input = {
		class="span2",
		id = "update_autoupgrade_hour",
		style = "cursor:pointer;background-color:white;",
		value="03:00",
	}
}
html[#html + 1] = '<span id="GUI-upgrade-option">'
html[#html + 1] = ui_helper.createAlertBlock(T"Update the GUI to the latest version available", info_box)
html[#html + 1] = ui_helper.createInputSelect(T"Update Branch", "update_branch", update_branch_option, modgui_settings["update_branch"])

html[#html + 1] = ui_helper.createSwitch(T"GUI Auto Update", "update_autoupgrade", modgui_settings["update_autoupgrade"],autoupgrade)
html[#html + 1] = ui_helper.createInputText(T"Update Hours", "update_autoupgrade_hour", modgui_settings["update_autoupgrade_hour"],autoupgrade_mon_1)

if content["outdated_ver"] == "1" then
	html[#html + 1] = ui_helper.createLabel(T"State", T"Update Found", basic)
	html[#html + 1] = ui_helper.createLabel(T"New Version", content["new_ver"], basic)
	html[#html + 1] = ui_helper.createButton(T"Update GUI", T"Update", "icon-refresh", upgrade_gui)
else
	html[#html + 1] = ui_helper.createLabel(T"State", T"No Update found", basic)
	html[#html + 1] = ui_helper.createButton(T"Update GUI", T"Force Update", "icon-refresh", upgrade_gui)
end

html[#html + 1] = '</span>'
html[#html + 1] = '</form><form class="form-horizontal" id="form-import-gui" method="post" action="modals/modgui-modal.lp?action=upgradeguifile" enctype="multipart/form-data">'
html[#html + 1] = '<div id="offline-upgrade-gui-div" class="control-group">'
html[#html + 1] = format('<label class="control-label">%s</label>', T"Offline GUI Update")
html[#html + 1] = '<div class="controls">'
html[#html + 1] = '<input type="file" name="upgradefile" id="file-upgradegui" accept=".bz2">&nbsp;'
html[#html + 1] = ui_helper.createSimpleButton(T"Update", "icon-shield", upload_gui_file)
html[#html + 1] = '</div></div>'
html[#html + 1] = '<div class="alert alert-info hide" id="upgrade-log"></div>'
html[#html + 1] = ui_helper.createAlertBlock(T"Update failed. Please try again.", upload_gui_fail)
html[#html + 1] = ui_helper.createAlertBlock(T"Uploading file. Please wait...", upload_gui_alert)
html[#html + 1] = ui_helper.createAlertBlock(T"Updating file. Please wait...", updating)
html[#html + 1] = '</form>'
ngx.print(html)

if content.specific_app ~= "" then

	local html = {}

	local upload_specific_app = {
		button = {
			class = "import-specificapp custom-handler",
			id = "btn-import-specificapp"
		}
	}

	local upload_specificapp_fail = {
		alert = {
			class = "alert-error hide",
			id = "upgrade-specificapp-fail"
		}
	}
	local upload_specificapp_alert = {
		alert = {
			class = "alert-info hide",
			id = "upload-specificapp-alert"
		}
	}
	local install_specificapp = {
		group = {
			class = "wait-for-reset"
		},
		button = {
			id = "btn-install-specificapp",
			class = "custom-handler"
		}
	}

	html[#html + 1] = '<form class="form-horizontal" id="form-import-specificapp" method="post" action="modals/modgui-modal.lp?action=installspecificapp" enctype="multipart/form-data">'
	html[#html + 1] = '<legend>'.. T"Specific App" ..'</legend>'
	html[#html + 1] = ui_helper.createAlertBlock(T"Specific App are package that adds additional function to the modem, like telnet support or some fix to default package", info_box)
	if content.specific_app == "1" then
		html[#html + 1] = ui_helper.createLabel(T"State", T"Specific App are already Installed", basic)
	else
		html[#html + 1] = ui_helper.createButton(T"Install", T"Install Specific App Online", "icon-refresh", install_specificapp)

		local device = getSupportedModel()

		html[#html + 1] = ui_helper.createAlertBlock(format(T"If you don't have connection, specific app can be downloaded here ( https://raw.githubusercontent.com/Ansuel/gui-dev-build-auto/master/modular/upgrade-pack-specific%s.tar.bz2 ) and installed manually here.", device), info_box)
		html[#html + 1] = '<div class="control-group">'
		html[#html + 1] = format('<label class="control-label">%s</label>', T"Upload Specific App")
		html[#html + 1] = '<div class="controls">'
		html[#html + 1] = '<input type="file" name="specificapp_file" id="file-specificapp" accept=".bz2">&nbsp;'
		html[#html + 1] = ui_helper.createSimpleButton(T"Install", "icon-shield", upload_specific_app)
		html[#html + 1] = ui_helper.createAlertBlock(T"Uploading file. Please wait...", upload_specificapp_alert)
		html[#html + 1] = ui_helper.createAlertBlock(T"Update failed. Please try again.", upload_specificapp_fail)
		html[#html + 1] = '</div></div>'
	end
	html[#html + 1] = '</form>'

	ngx.print(html)

end

local html = {}
html[#html + 1] = '<form  class="form-horizontal">'
html[#html + 1] = '<legend>' .. T"Advanced Reset" .. '</legend>'
local reset_gui = {
	group = {
		class = "wait-for-reset"
	},
	button = {
		id = "btn-reset-gui",
		class = "custom-handler"
	}
}
local remove_root = {
	group = {
		class = "wait-for-reset"
	},
	button = {
		id = "btn-remove-root",
		class = "custom-handler"
	}
}
local remove_config = {
	group = {
		class = "wait-for-reset"
	},
	button = {
		id = "btn-remove-config",
		class = "custom-handler"
	}
}
local reset_cwmp = {
	group = {
		class = "wait-for-reset"
	},
	button = {
		id = "btn-reset-cwmp",
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
		class = "alert alert-range",
	}
}
local resetting = {
	alert = {
		class = "alert hide",
		id = "resetting-msg"
	}
}
local unrooting = {
	alert = {
		class = "alert hide",
		id = "unrooting-msg"
	}
}
local resetting_config = {
	alert = {
		class = "alert hide",
		id = "config-resetting-msg"
	}
}

html[#html + 1] = ui_helper.createButton(T"Force CWMP provisioning", T"Reset CWMP", "icon-refresh", reset_cwmp)

html[#html + 1] = ui_helper.createAlertBlock(T"Reset the modem to the firmware stock GUI. Some config and root SSH access will be preserved. This roll back without a full reset can cause unexpected behaviours or instability", info_box)
html[#html + 1] = ui_helper.createAlertBlock(T"Resetting to default GUI, please wait...", resetting)
html[#html + 1] = ui_helper.createButton(T"Restore GUI", T"Restore", "icon-refresh", reset_gui)

html[#html + 1] = ui_helper.createAlertBlock(T"Reset the router to factory settings and remove the custom firmware files.", info_box)
html[#html + 1] = ui_helper.createAlertBlock(T"Unrooting and reverting to factory defaults, please wait...", unrooting)
html[#html + 1] = ui_helper.createButton(T"Reset to Factory", T"Remove Root", "icon-refresh", remove_root)

html[#html + 1] = ui_helper.createAlertBlock(T"Reset the router to factory settings and mantain modded GUI.", info_box)
html[#html + 1] = ui_helper.createAlertBlock(T"Resetting config to default, please wait...", resetting_config)
html[#html + 1] = ui_helper.createButton(T"Reset config to Factory", T"Remove Config", "icon-refresh", remove_config)
html[#html + 1] = '</form>'
ngx.print(html)

local html = {}

local import_backup = {
	button = {
		class = "import-backup custom-handler",
		id = "btn-import-backup"
	}
}
local upload_backup_alert = {
		alert = {
			class = "alert-info hide",
			id = "upload-backup-alert"
		}
	}
local restore_fail = {
	alert = {
		class = "alert-error hide",
		id = "restore-fail"
	}
}
local gen_backup = {
	button = {
		class = "custom-handler",
		id = "btn-gen-backup"
	}
}

html[#html + 1] = '<form class="form-horizontal" id="form-import-backup" method="post" action="modals/modgui-modal.lp?action=system_restoreBackup" enctype="multipart/form-data">'
html[#html + 1] = '<legend>'.. T"Advanced Restore & Backup" ..'</legend>'

html[#html + 1] = ui_helper.createAlertBlock(T"This will use OpenWRT backup and restore function insteand of the Technicolor function.", info_box)
html[#html + 1] = ui_helper.createButton(T"Backup ZIP", T"Generate", "icon-exchange", gen_backup)
html[#html + 1] = '<div class="control-group">'
html[#html + 1] = format('<label class="control-label">%s</label>', T"Upload Backup")
html[#html + 1] = '<div class="controls">'
html[#html + 1] = '<input type="file" name="sysupgrade_backup" id="file-restore" accept=".gz">&nbsp;'
html[#html + 1] = ui_helper.createSimpleButton(T"Restore", "icon-shield", import_backup)
html[#html + 1] = ui_helper.createAlertBlock(T"Uploading file. Please wait...", upload_backup_alert)
html[#html + 1] = ui_helper.createAlertBlock(T"Upload failed. Please try again.", restore_fail)
html[#html + 1] = '</div></div>'
html[#html + 1] = '</form>'

ngx.print(html)

ngx.print('\
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
  var timescroll_opt = {\
            theme: "android-ics light",\
            display: "bubble",\
            mode: "scroller",\
            headerText: false,\
            timeFormat: "HH:ii",\
            stepMinute: 5\
        };\
\
  $("#update_autoupgrade_hour").mobiscroll().time(timescroll_opt);\
  $("#update_autoupgrade_hour").on("change", function() {\
		$("#modal-no-change").fadeOut(300);\
        $("#modal-changes").delay(350).fadeIn(300);\
	}\
  );\
\
  function wait_for_webserver_running() {\
	$.ajax({ url: "/", timeout: refreshTimeOut })\
	.done(function(data) {\
	  window.location.href = "/";\
	})\
	.fail(function() {\
	  window.setTimeout(wait_for_webserver_running, refreshDelay);\
	});\
  };\
\
  function wait_for_webserver_down() {\
	$.ajax({ url: target, timeout: refreshTimeOut })\
	.done(function() {\
	  window.setTimeout(wait_for_webserver_down, refreshDelay);\
	})\
	.fail(function() {\
	  window.setTimeout(wait_for_webserver_running, refreshDelay);\
	});\
  };\
\
  function resetreboot(msg, msg_dst, action, customCallbackfunc) {\
	msg.removeClass("hide");\
	msg[0].scrollIntoView();\
	msg_dst.replaceWith(msg);\
	var callbackfunc = ( typeof customCallbackfunc === "function" ) && customCallbackfunc || wait_for_webserver_down;\
	if(callbackfunc == wait_for_webserver_down) modgui.clearKoInterval();\
	$.post(target,{action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content")}, callbackfunc,"json");\
	return false;\
  };\
\
  function genericButtonFunction(headingText, processMsgText, ConfirmationDialogueText, resetIDName, btnID, callFunctionName, customCallBack) {\
	var heading = headingText;\
	var processMsg = processMsgText;\
	confirmationDialogue(ConfirmationDialogueText,heading);\
	var PopUpHeaderText = "."+$(".popUp>.header>.header-title>p").text().split(" ")[0];\
	$(document).on("click", PopUpHeaderText, function() {\
		   tch.removeProgress();\
		   tch.showProgress(processMsg);\
		   return resetreboot($(resetIDName), $(btnID), callFunctionName, customCallBack );\
	});\
  };\
\
  $("#btn-reset-gui").on("click", function() { return genericButtonFunction(\
		"');  ngx.print(T'Restore GUI'); ngx.print('",\
		"');  ngx.print(T'Restoring...'); ngx.print('",\
		"');  ngx.print(T'Do you want to continue?'); ngx.print('",\
		"#resetting-msg",\
		"#btn-reset-gui",\
		"system_reset_gui"\
	)}\
  );\
  $("#btn-remove-root").on("click", function() { return genericButtonFunction(\
		"');  ngx.print(T'Remove root'); ngx.print('",\
		"');  ngx.print(T'Resetting...'); ngx.print('",\
		"');  ngx.print(T"Are you sure you want to remove root from this modem? <br/><strong> This could be permanent, so it\\'s not recommended.</strong>"); ngx.print('",\
		"#unrooting-msg",\
		"#btn-remove-root",\
		"system_remove_root"\
	)}\
  );\
  $("#btn-remove-config").on("click", function() { return genericButtonFunction(\
		"');  ngx.print(T'Reset config'); ngx.print('",\
		"');  ngx.print(T'Resetting...'); ngx.print('",\
		"');  ngx.print(T"Are you sure you want to reset config of this modem? <br/><strong> This is permanent, save any config before this action.</strong>"); ngx.print('",\
		"#config-resetting-msg",\
		"#btn-remove-config",\
		"system_reset_config"\
	)}\
  );\
  $("#btn-reset-cwmp").on("click", function() { return genericButtonFunction(\
		"');  ngx.print(T'Reset CWMP'); ngx.print('",\
		"');  ngx.print(T'Resetting...'); ngx.print('",\
		"');  ngx.print(T"Are you sure you want to reset CWMP db of this modem? <br/><strong> This will force the first-time boot provisioning with ACS server that can fail on an already provisioned modem.</strong>"); ngx.print('",\
		"#btn-reset-cwmp",\
		"#btn-reset-cwmp",\
		"system_reset_cwmp",\
		tch.removeProgress\
	)}\
  );\
\
  var schedulReload = false;\
\
  $("#gui_skin").on("change", function() {\
	var theme = $(this).val();\
	if ( theme.indexOf("Fritz") === -1 ) {\
		event.preventDefault();\
		var restyled = theme+"/style.css";\
		modgui.freshStyle(restyled);\
	}\
	if ( theme.indexOf("Fritz") != -1 || theme.indexOf("unified") != -1) {\
		if($(\'#gui_skin_firstpage option[value="cards"]\').is(":selected")) $("#gui_skin_firstpage").val("stats");\
		$(\'#gui_skin_firstpage option[value="cards"]\').attr("disabled","disabled");\
	} else {\
		$(\'#gui_skin_firstpage option[value="cards"]\').removeAttr("disabled");\
	}\
	schedulReload = true;\
  });\
\
  $("#btn-gen-backup").on("click", function() {\
    $.fileDownload(target, {\
      httpMethod: "POST",\
      data: new Array({ name : "action", value : "system_genBackup" },\
                      { name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") }),\
      prepareCallback: function() {\
		tch.showProgress("');  ngx.print(T"Generating backup in background..."); ngx.print('");\
      },\
      successCallback: function() {\
		tch.removeProgress();\
      }\
    });\
    return false;\
  });\
\
  $("#gui_forcehttps,#gui_alwaysadvanced").on("change", function() {\
	schedulReload = true;\
  });\
\
  $("#save-config").on("click", function() {\
	if ( schedulReload ) {\
		schedulReload = true;\setTimeout(function() {window.location.reload(!0);},1000);\
	}\
  });\
\
  $(document).on("click", "#cancel", function() {\
	  tch.removeProgress();\
  });\
\
  $("#btn-upgrade-gui").on("click", function() {\
	modgui.postAction("system_upgrade_gui",1);\
  });\
\
  $(".import-gui").on("click", function() {\
	var nofile_msg = $("#upgrade-gui-fail");\
	var wrongext_msg = $("#upgrade-gui-fail");\
	nofile_msg.addClass("hide");\
	if ($("#file-upgradegui").val() == "") {\
	  nofile_msg.removeClass("hide");\
	  nofile_msg[0].scrollIntoView();\
	  return false;\
	};\
\
	var validExtensions = [\'bz2\'];\
	var fileName = $("#file-upgradegui").val();\
\
	var fileNameExt = fileName.substr(fileName.lastIndexOf(".") + 1);\
	if ($.inArray(fileNameExt, validExtensions) == -1){\
		wrongext_msg.removeClass("hide");\
	wrongext_msg[0].scrollIntoView();\
	return false;\
	};\
	var fileSize = $("#file-upgradegui")[0].files[0].size;\
	var importing_msg = $("#upload-gui-alert");\
	var _this = $(this).parents(".control-group");\
	importing_msg.removeClass("hide");\
	importing_msg[0].scrollIntoView();\
\
	$.fileUpload($("#form-import-gui"), {\
	  params: { CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
	  completeCallback: function(form, response) {\
		if (response.success) {\
		  tch.openModal("/modals/command-log-read-modal.lp");\
		} else {\
		  importing_msg.addClass("hide");\
		  $("#upgrade-gui-fail").removeClass("hide");\
		}\
	  }\
	});\
	return false;\
  });\
\
  $("#btn-install-specificapp").on("click", function() {\
	modgui.postAction("system_install_specificapp",1);\
  });\
\
  $(".import-specificapp").on("click", function() {\
	var nofile_msg = $("#upgrade-specificapp-fail");\
	var wrongext_msg = $("#upgrade-specificapp-fail");\
	nofile_msg.addClass("hide");\
	if ($("#file-specificapp").val() == "") {\
	  nofile_msg.removeClass("hide");\
	  nofile_msg[0].scrollIntoView();\
	  return false;\
	};\
\
	var validExtensions = [\'bz2\'];\
	var fileName = $("#file-specificapp").val();\
\
	var fileNameExt = fileName.substr(fileName.lastIndexOf(".") + 1);\
	if ($.inArray(fileNameExt, validExtensions) == -1){\
		wrongext_msg.removeClass("hide");\
	wrongext_msg[0].scrollIntoView();\
	return false;\
	};\
	var fileSize = $("#file-specificapp")[0].files[0].size;\
	var importing_msg = $("#upload-specificapp-alert");\
	var _this = $(this).parents(".control-group");\
	importing_msg.removeClass("hide");\
	importing_msg[0].scrollIntoView();\
\
	$.fileUpload($("#form-import-specificapp"), {\
	  params: { CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
	  completeCallback: function(form, response) {\
		if (response.success) {\
		  tch.openModal("/modals/command-log-read-modal.lp");\
		} else {\
		  importing_msg.addClass("hide");\
		  $("#upgrade-specificapp-fail").removeClass("hide");\
		}\
	  }\
	});\
	return false;\
  });\
\
$(".import-backup").on("click", function() {\
	var nofile_msg = $("#restore-fail");\
	var wrongext_msg = $("#restore-fail");\
	nofile_msg.addClass("hide");\
	if ($("#file-restore").val() == "") {\
	  nofile_msg.removeClass("hide");\
	  nofile_msg[0].scrollIntoView();\
	  return false;\
	};\
\
	var validExtensions = [\'gz\'];\
	var fileName = $("#file-restore").val();\
\
	var fileNameExt = fileName.substr(fileName.lastIndexOf(".") + 1);\
	if ($.inArray(fileNameExt, validExtensions) == -1){\
		wrongext_msg.removeClass("hide");\
	wrongext_msg[0].scrollIntoView();\
	return false;\
	};\
	var fileSize = $("#file-restore")[0].files[0].size;\
	var importing_msg = $("#upload-backup-alert");\
	var _this = $(this).parents(".control-group");\
	importing_msg.removeClass("hide");\
	importing_msg[0].scrollIntoView();\
\
	$.fileUpload($("#form-import-backup"), {\
	  params: { CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
	  completeCallback: function(form, response) {\
		if (response.success) {\
		  tch.showProgress("Rebooting...");\
		} else {\
		  importing_msg.addClass("hide");\
		  $("#restore-fail").removeClass("hide");\
		}\
	  }\
	});\
	return false;\
  });\
');
if ngx.req.get_uri_args().action and ngx.req.get_uri_args().action == "manualguiupgrade" then
	ngx.print('\
	$("#GUI_Upgrade_Legend")[0].scrollIntoView();\
  ');
end
ngx.print('\
})();\
</script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
');
