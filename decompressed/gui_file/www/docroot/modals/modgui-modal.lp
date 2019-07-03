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

  proxy.set("rpc.system.modgui.upgradegui.start", "1")
  proxy.set("rpc.system.modgui.upgradegui.state", "Requested")
  proxy.apply()

  ngx.print('{ "success":"true" }')
  ngx.exit(ngx.HTTP_OK)

end

local function upgradeguistatus()
  local upgradegui_path = "rpc.system.modgui.upgradegui."

  local state = proxy.get(upgradegui_path.."state")[1].value

  ngx.header.content_type = "application/json"
  if state == "In Progress" then
  local log = proxy.get(upgradegui_path.."log")[1].value
  local log_prog = proxy.get(upgradegui_path.."log_prog")[1].value
	ngx.print(format('{ "state":"%s","log_msg":"%s","log_prog":"%s" }',state,log,log_prog))
  elseif state == "Extracting" then
  local log = proxy.get(upgradegui_path.."log")[1].value
  local extract_prog = proxy.get(upgradegui_path.."extract_prog")[1].value
  ngx.print(format('{ "state":"%s","log_msg":"%s","extract_prog":"%s" }',state,log,extract_prog))
  elseif state == "Downloading" then
  local log = proxy.get(upgradegui_path.."log")[1].value
  ngx.print(format('{ "state":"%s","log_msg":"%s" }',state,log))
  else
  ngx.print(format('{ "state":"%s" }',state))
  end

  ngx.exit(ngx.HTTP_OK)
end

local function scriptRequestStatus()
	local upgradegui_path = "rpc.system.modgui.scriptRequest."
	local state = proxy.get(upgradegui_path.."state")[1].value
  local new_ver = proxy.get("uci.modgui.gui.new_ver")

	ngx.header.content_type = "application/json"

  if new_ver and not ( new_ver[1].value == "" ) then
	ngx.print(format('{ "state":"%s","new_version_text":"%s" }',state,new_ver[1].value))
  else
	  ngx.print(format('{ "state":"%s" }',state))
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

if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_uri_args().action
  if action == "upgradeguifile" then
	return upgradeguifile()
  end
  local action = ngx.req.get_post_args().action
  if action == "system_reset_gui" then
	return resetreboot("rpc.system.modgui.utility.resetgui", "1")
  end
  if action == "system_upgrade_gui" then
  proxy.set("rpc.system.modgui.upgradegui.state", "Requested")
  return resetreboot("rpc.system.modgui.upgradegui.start", "1")
  end
  if action == "system_remove_root" then
  	return resetreboot("rpc.system.modgui.utility.removeroot", "1")
  end
  if action == "system_reset_config" then
  	return resetreboot("rpc.system.modgui.utility.resetconfig", "1")
  end
elseif ngx.req.get_method() == "GET" then
  local action = ngx.req.get_uri_args().action
  if action == "upgradeguistatus" then
  return upgradeguistatus()
  elseif action == "scriptRequestStatus" then
  return scriptRequestStatus()
  end
end

local content = {
  gui_version = "uci.modgui.gui.gui_version",
  outdated_ver = "uci.modgui.gui.outdated_ver",
  new_ver = "uci.modgui.gui.new_ver",
  upgradegui_logstep = "rpc.system.modgui.upgradegui.log_step",
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

local telstra_gui = proxy.get("uci.modgui.app.telstra_webui")

if telstra_gui and ( telstra_gui[1].value == "1" ) then
  table.insert(gui_skin_firstpage_page, { "telstra", T"Telstra" })
end

local gui_skin_option = {
	  { "blue", T'Blue'},
	  { "violet", T'Violet'},
	  { "green", T'Green'},
	{ "TIM" , T'Enhanced Tim'},
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
  gui_animation = "uci.modgui.gui.gui_animation"
}

local mapValid = {
  update_branch = post_helper.getValidateInEnumSelect(update_branch_option),
  update_autoupgrade = vB,
  update_autoupgrade_hour = gOV(post_helper.validateNonEmptyString),
  gui_skin = post_helper.getValidateInEnumSelect(gui_skin_option),
  gui_skin_firstpage = post_helper.getValidateInEnumSelect(gui_skin_firstpage_page),
  gui_randomcolor = vB,
  gui_alwaysadvanced = vB,
  gui_animation = vB,
}

local modgui_settings, helpmsg = post_helper.handleQuery(mapParams, mapValid)

ngx.print(ui_helper.createHeader(T"GUI Settings & Utility", false, false))
  local html = {}
	html[#html + 1] = '<fieldset class="modal-body hide" id="upgrade-gui-bar" style="min-height: unset;">'
	html[#html + 1] = '<div class="alert alert-info">'
	html[#html + 1] = '<div><span id="update-text">'..T"Update in progress..."..'</span><span id="extracted_file" class="hide">0</span></div>'
	html[#html + 1] = '  <div id="upgrade-gui-bar" class="progress progress-striped active">'
	  html[#html + 1] = '	<div class="bar bar-warning" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" >'
	  html[#html + 1] = '</div></div></div>'
	html[#html + 1] = '</fieldset>'
  ngx.print(html)
ngx.print('\
<div class="modal-body update">\
');
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
ngx.print('\
  <fieldset>\
	<form class="form-horizontal" method="post" action="modals/modgui-modal.lp">')

	local html = {}
	html[#html + 1] = '<div class="RemoveOnUpgrade">'
	html[#html + 1] = '<legend>'.. T"GUI Skin" ..'</legend>'
	html[#html + 1] = ui_helper.createInputSelect(T"GUI Skin", "gui_skin", gui_skin_option, modgui_settings["gui_skin"])
	html[#html + 1] = ui_helper.createInputSelect(T"GUI First Page", "gui_skin_firstpage", gui_skin_firstpage_page, modgui_settings["gui_skin_firstpage"])
	html[#html + 1] = ui_helper.createSwitch(T"Random Color", "gui_randomcolor", modgui_settings["gui_randomcolor"])
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
		style = "cursor:pointer;background-color:white;"
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
	html[#html + 1] = '</div>'
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

	ngx.print(html)

	local html = {}
	html[#html + 1] = '<div class="RemoveOnUpgrade">'
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

	html[#html + 1] = ui_helper.createAlertBlock(T"Resetting to default gui, please wait...", resetting)
	html[#html + 1] = ui_helper.createAlertBlock(T"Resetting config to default, please wait...", resetting_config)
	html[#html + 1] = ui_helper.createAlertBlock(T"Unrooting and reverting to factory defaults, please wait...", unrooting)
	html[#html + 1] = ui_helper.createAlertBlock(T"Reset the custom GUI settings. No custom firmware file will be removed. All custom GUI functions will still be available.", info_box)
	html[#html + 1] = ui_helper.createButton(T"Restore GUI", T"Restore", "icon-refresh", reset_gui)
	html[#html + 1] = ui_helper.createAlertBlock(T"Reset the router to factory settings and remove the custom firmware files.", info_box)
	html[#html + 1] = ui_helper.createButton(T"Reset to Factory", T"Remove Root", "icon-refresh", remove_root)
	html[#html + 1] = ui_helper.createAlertBlock(T"Reset the router to factory settings and mantain modded GUI.", info_box)
	html[#html + 1] = ui_helper.createButton(T"Reset config to Factory", T"Remove Config", "icon-refresh", remove_config)
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
  var timescroll_opt = {\
            theme: "android-ics light",\
            display: "bubble",\
            mode: "scroller",\
            headerText: false,\
            timeFormat: "hh:ii",\
            stepMinute: 5\
        };\
\
  $("#update_autoupgrade_hour").mobiscroll().time(timescroll_opt);\
  $("#update_autoupgrade_hour").on("change", function() {\
		$("#modal-no-change").fadeOut(300);\
        $("#modal-changes").delay(350).fadeIn(300);\
	}\
  )\
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
	$.post(target,{action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content")}, wait_for_webserver_down,"json");\
	return false;\
  }\
\
  $("#btn-reset-gui").on("click", function() {\
	var heading = "');  ngx.print(T'Restore GUI'); ngx.print('";\
	var processMsg = "');  ngx.print(T'Restoring...'); ngx.print('";\
	confirmationDialogue(\'');  ngx.print(T"Do you want to continue?"); ngx.print('\',heading);\
	var PopUpHeaderText = "."+$(".popUp>.header>.header-title>p").text().split(" ")[0];\
	$(document).on("click", PopUpHeaderText, function() {\
		   tch.removeProgress();\
		   tch.showProgress(processMsg);\
		   return resetreboot($("#resetting-msg"), $("#btn-reset-gui"), "system_reset_gui" );\
	});\
  });\
\
  var schedulReload = false;\
\
  $("#gui_skin").on("change", function() {\
	var theme = $(this).val();\
	if ( theme.indexOf("Fritz") === -1 ) {\
		event.preventDefault();\
		var restyled = theme+"/style.css";\
		freshStyle(restyled);\
	} else {\
		schedulReload = true;\
	}\
  });\
\
  $("#save-config").on("click", function() {\
	if ( schedulReload ) {\
		schedulReload = true;\setTimeout(function() {window.location.reload(!0);},2000);\
	}\
  });\
\
  $("#btn-remove-root").on("click", function() {\
	var heading = "');  ngx.print(T'Remove root'); ngx.print('";\
	var processMsg = "');  ngx.print(T'Resetting...'); ngx.print('";\
	confirmationDialogue(\'');  ngx.print(T"Are you sure you want to remove root from this modem? </br><strong> This could be permanent, so it\\'s not recommended.</strong>"); ngx.print('\',heading);\
	var PopUpHeaderText = "."+$(".popUp>.header>.header-title>p").text().split(" ")[0];\
	$(document).on("click", PopUpHeaderText, function() {\
		 tch.removeProgress();\
		 tch.showProgress(processMsg);\
		 return resetreboot($("#unrooting-msg"), $("#btn-remove-root"), "system_remove_root" );\
	});\
  });\
  $("#btn-remove-config").on("click", function() {\
	var heading = "');  ngx.print(T'Reset config'); ngx.print('";\
	var processMsg = "');  ngx.print(T'Resetting...'); ngx.print('";\
	confirmationDialogue(\'');  ngx.print(T"Are you sure you want to reset config of this modem? </br><strong> This is permanent, save any config before this action.</strong>"); ngx.print('\',heading);\
	var PopUpHeaderText = "."+$(".popUp>.header>.header-title>p").text().split(" ")[0];\
	$(document).on("click", PopUpHeaderText, function() {\
		 tch.removeProgress();\
		 tch.showProgress(processMsg);\
		 return resetreboot($("#config-resetting-msg"), $("#btn-remove-config"), "system_reset_config" );\
	});\
  });\
\
  $(document).on("click", "#cancel", function() {\
	  tch.removeProgress();\
  });\
\
  var max_val = '); ngx.print( content.upgradegui_logstep ); ngx.print('\
  var increment = 100/max_val;\
  var oldlog = "";\
  var upgrfw_refreshTimeOut = 2500;\
  var upgrfw_waitDelay = 100;\
  function wait_for_upgradegui() {\
\
	function waitForShutdown() {\
	  $.ajax({ url: target, data: "action=upgradeguistatus"+"&auto_update=true", timeout: upgrfw_refreshTimeOut, cache: false, dataType: "json" })\
	  .done(function(data, status, xhr) {\
	if ((data.state+"..." != $("#update-text").text()) && (data.state != "Not started")) {\
		$("#update-text").text(data.state+"...");\
	}\
	if (typeof data.log_msg !== "undefined" && oldlog != data.log_msg) {\
	  $("#upgrade-log").append(data.log_msg+"<br>");\
	  oldlog = data.log_msg;\
	  $(".modal-body").animate({ scrollTop: $(document).height() }, 1000);\
	}\
	if (data.state == "Requested") {\
	  $(".bar").css("width", "10%").css("background-color","#4caf50");\
	  window.setTimeout(waitForShutdown, upgrfw_waitDelay);\
	} else if (data.state == "Downloading") {\
	  $(".bar").css("width", "100%").css("background-color","#4caf50");\
	  window.setTimeout(waitForShutdown, upgrfw_waitDelay);\
	} else if (data.state == "Clearing") {\
	  $(".bar").css("width", "100%").css("background-color","#4caf50");\
	  window.setTimeout(waitForShutdown, upgrfw_waitDelay);\
	} else if (data.state == "Extracting") {\
	  var extract_bar_val = isNaN(data.extract_prog)?1:(data.extract_prog/12);\
	  $("#extracted_file").removeClass("hide");\
	  var old_text = $("#extracted_file").text();\
	  if(old_text.replace(/\\+/g, "") == data.extract_prog){\
		$("#extracted_file").text($("#extracted_file").text().replace(/[\\+]{10}/g, ""));\
		$("#extracted_file").append("+");\
	  } else\
		$("#extracted_file").text(data.extract_prog);\
	  $(".bar").css("width", extract_bar_val+"%").css("background-color","").attr("aria-valuenow", extract_bar_val);\
	  window.setTimeout(waitForShutdown, upgrfw_waitDelay);\
	} else if (data.state == "In Progress") {\
	  $("#extracted_file").addClass("hide");\
	  var bar_val = (increment*data.log_prog);\
	  $(".bar").css("width", bar_val+"%").attr("aria-valuenow", bar_val);\
	  window.setTimeout(waitForShutdown, upgrfw_waitDelay);\
	} else if (data.state == "Not started") {\
	  window.setTimeout(waitForShutdown, upgrfw_waitDelay);\
	} else if (data.state == "Finished") {\
		if(!$("#popUp").is(":visible"))\
			tch.showProgress(waitMsg);\
	  window.setTimeout(waitForShutdown, 500);\
	}\
	  })\
	  .fail(function(data) {\
		if(data.status==200 && data.responseText.includes("sign-me-in")){\
			if(!$("#popUp").is(":visible"))\
				tch.showProgress(waitMsg);\
		  window.location.href = "/";\
		} else {\
		  window.setTimeout(waitForShutdown, upgrfw_waitDelay);\
		}\
	})\
	}\
	window.setTimeout(waitForShutdown, upgrfw_waitDelay);\
	return false;\
  }\
\
  function inizialize_ui_for_update() {\
	$("*").off("click");\
	$("html").css("overflow","hidden");\
	$(".modal-footer").hide();\
	$(".btn-close").hide();\
	$("#offline-upgrade-gui-div").addClass("hide");\
	$(".RemoveOnUpgrade").each(function() {$(this).addClass("hide")});\
	$("#upgrade-gui-bar").removeClass("hide");\
	$("#upgrade-log").removeClass("hide");\
	$(".bar").css("width", "2%").attr("aria-valuenow", 2);\
	KoRequest.forEach(function(element) {\
		clearInterval(element);\
	});\
  };\
\
  $("#btn-upgrade-gui").on("click", function() {\
	inizialize_ui_for_update();\
	$.post(target,{action: "system_upgrade_gui", CSRFtoken: $("meta[name=CSRFtoken]").attr("content")},"","json");\
	wait_for_upgradegui();\
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
	}\
\
	var validExtensions = [\'bz2\'];\
	var fileName = $("#file-upgradegui").val();\
\
	var fileNameExt = fileName.substr(fileName.lastIndexOf(".") + 1);\
	if ($.inArray(fileNameExt, validExtensions) == -1){\
		wrongext_msg.removeClass("hide");\
	wrongext_msg[0].scrollIntoView();\
	return false;\
	}\
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
		  inizialize_ui_for_update();\
		  wait_for_upgradegui();\
		} else {\
		  importing_msg.addClass("hide");\
		  $("#upgrade-gui-fail").removeClass("hide");\
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
