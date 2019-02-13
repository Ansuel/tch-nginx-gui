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
local session = ngx.ctx.session

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

  local log = proxy.get(upgradegui_path.."log")[1].value
  local log_prog = proxy.get(upgradegui_path.."log_prog")[1].value
  local state = proxy.get(upgradegui_path.."state")[1].value

  ngx.header.content_type = "application/json"
  if state == "In Progress" then
    ngx.print(format('{ "log_msg":"%s" , "state":"In Progress", "log_prog":%s }',log,log_prog))
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
	return resetreboot("rpc.system.modgui.upgradegui.start", "1")
  end
  if action == "system_remove_root" then
	return resetreboot("rpc.system.modgui.utility.removeroot", "1")
  end
elseif ngx.req.get_method() == "GET" then
  local action = ngx.req.get_uri_args().action
  if action == "upgradeguistatus" then
	return upgradeguistatus()
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
      { "dev", T'Dev'},
}

local update_hour_option = {}

for i=0,23 do
	update_hour_option[#update_hour_option+1] = { tostring(i) , tostring(i) .. ":00"}
end

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
	  { "dark-white", T'Dark/White (Fritz!Box Based)'},
	  { "dark-midnight", T'Dark/Midnight (Fritz!Box Based)'},
	  { "dark-red", T'Red Dark'},
}

local mapParams = {
  update_branch = "uci.modgui.gui.update_branch",
  update_autoupgrade = "uci.modgui.gui.autoupgrade",
  update_autoupgrade_hour = "uci.modgui.gui.autoupgrade_hour",
  gui_skin = "uci.modgui.gui.gui_skin",
  gui_skin_firstpage = "uci.modgui.gui.firstpage",
  gui_randomcolor = "uci.modgui.gui.randomcolor",
}

local mapValid = {
  update_branch = post_helper.getValidateInEnumSelect(update_branch_option),
  update_autoupgrade = vB,
  update_autoupgrade_hour = post_helper.getValidateInEnumSelect(update_hour_option),
  gui_skin = post_helper.getValidateInEnumSelect(gui_skin_option),
  gui_skin_firstpage = post_helper.getValidateInEnumSelect(gui_skin_firstpage_page),
  gui_randomcolor = post_helper.validateBoolean,
}

local modgui_settings, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"GUI Settings & Utility", false, false))   
	local html = {}
	  html[#html + 1] = '<div class="alert alert-info hide" id="upgrade-gui-bar">'
	  html[#html + 1] = T"Update in progress..."
	  html[#html + 1] = '  <div id="upgrade-gui-bar" class="progress progress-striped active">'
      html[#html + 1] = '    <div class="bar bar-warning" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" >'
      html[#html + 1] = '</div></div></div>'
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
	  html[#html + 1] = '<span id="GUI-upgrade-option">'
	  html[#html + 1] = ui_helper.createAlertBlock(T"Update the GUI to the latest version available", info_box)
	  html[#html + 1] = ui_helper.createInputSelect(T"Update Branch", "update_branch", update_branch_option, modgui_settings["update_branch"])

      html[#html + 1] = ui_helper.createSwitch(T"GUI Auto Update", "update_autoupgrade", modgui_settings["update_autoupgrade"])
      html[#html + 1] = ui_helper.createInputSelect(T"Update Hours", "update_autoupgrade_hour", update_hour_option, modgui_settings["update_autoupgrade_hour"])
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
      html[#html + 1] = '<input type="file" name="upgradefile" id="file-upgradegui">&nbsp;'
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
	  local confirming_msg_remove_root = {
	   alert = {
	   	class = "alert hide",
	   	id = "confirming-msg-remove-root"
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
	  
	  
	  html[#html + 1] = ui_helper.createAlertBlock(T"Reset the custom GUI settings. No custom firmware file will be removed. All custom GUI functions will still be available.", info_box)
	  html[#html + 1] = ui_helper.createButton(T"Restore GUI", T"Restore", "icon-refresh", reset_gui)
	  html[#html + 1] = ui_helper.createAlertBlock(T"Reset the router to factory settings and remove the custom firmware files.", info_box)
	  html[#html + 1] = ui_helper.createButton(T"Reset to Factory", T"Remove Root", "icon-refresh", remove_root)
	  html[#html + 1] = string.format('<div class="control-group controls">')
	  html[#html + 1] = ui_helper.createAlertBlock(T"Are you sure you want to remove root from this modem? </br><strong> This could be permanent, so it's not recommended.</strong>", confirming_msg_remove_root)
	  html[#html + 1] = string.format([[
	  <div id="remove-root-changes" class="hide">
		<div id="remove-root-confirm" class="btn btn-primary" data-dismiss="modal">%s</div>
			<div id="remove-root-cancel" class="btn">%s</div>
		</div>
	  </div>
	  ]], T"Confirm", T"Cancel")
	  html[#html + 1] = '</div>'
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
  $("#btn-reset-gui").on("click", function() {\
    tch.showProgress("'); ngx.print('Resetting...'); ngx.print('");\
    return resetreboot($("#resetting-msg"), $(this), "system_reset_gui");\
  });\
\
  $("#btn-remove-root").on("click", function() {\
    $("#confirming-msg-remove-root").removeClass("hide");\
	$("#remove-root-changes").removeClass("hide");\
  });\
\
  $("#remove-root-confirm").on("click", function() {\
  	$("#confirming-msg-remove-root").addClass("hide");\
  	$("#remove-root-changes").addClass("hide");\
  	tch.showProgress("'); ngx.print( T'Resetting...' ); ngx.print('");\
  	return resetreboot($("#resetting-msg"), $(this), "system_remove_root");\
  });\
\
  $("#remove-root-cancel").on("click", function() {\
  	$("#confirming-msg-remove-root").addClass("hide");\
  	$("#remove-root-changes").addClass("hide");\
  });\
\
  $(document).on("click", "#cancel", function() {\
      tch.removeProgress();\
  });\
\
  var bar_val = 2;\
  var max_val = '); ngx.print( content.upgradegui_logstep ); ngx.print('\
  var increment = 100/max_val;\
  function wait_for_upgradegui() {\
\
	var oldlog = "";\
    var upgrfw_refreshTimeOut = 100;\
    var upgrfw_refreshDelay = 100;\
    function waitForShutdown() {\
      $.ajax({ url: target, data: "action=upgradeguistatus", timeout: upgrfw_refreshTimeOut, dataType: "json" })\
      .done(function(data) {\
		if (data.state == "Requested") {\
		  window.setTimeout(waitForShutdown, upgrfw_refreshDelay);\
		} else if (data.state == "In Progress") {\
		  if (oldlog != data.log_msg) {\
			bar_val = (increment*data.log_prog)+2;\
			$(".bar").css("width", bar_val+"%").attr("aria-valuenow", bar_val);\
			$("#upgrade-log").append(data.log_msg+"<br>");}\
		  oldlog = data.log_msg;\
          window.setTimeout(waitForShutdown, upgrfw_refreshDelay);\
        } else if (data.state == "Finished") {\
		  console.log(wait_for_webserver_running);\
		}\
      })\
      .fail(wait_for_webserver_running)\
    }\
    window.setTimeout(waitForShutdown, upgrfw_refreshDelay);\
    return false;\
  }\
\
  $("#btn-upgrade-gui").on("click", function() {\
    $(".modal-backdrop").css("pointer-events", "none");\
	$(".container").css("pointer-events", "none");\
	$(".modal").css("pointer-events", "none");\
	$("#offline-upgrade-gui-div").addClass("hide");\
	$(".RemoveOnUpgrade").each(function() {$(this).addClass("hide")});\
	$("#upgrade-gui-bar").removeClass("hide");\
	$("#upgrade-log").removeClass("hide");\
	$(".bar").css("width", bar_val+"%").attr("aria-valuenow", bar_val);\
    resetreboot($("#updating-msg"), $(this), "system_upgrade_gui");\
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
    $.fileUpload($("#form-import-gui"), {\
      params: { CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      completeCallback: function(form, response) {\
        if (response.success) {\
		  $(".modal-backdrop").css("pointer-events", "none");\
		  $(".container").css("pointer-events", "none");\
		  $(".modal").css("pointer-events", "none");\
		  importing_msg.addClass("hide");\
		  $("#offline-upgrade-gui-div").addClass("hide");\
		  $(".RemoveOnUpgrade").each(function() {$(this).addClass("hide")});\
		  $("#upgrade-gui-bar").removeClass("hide");\
		  $("#upgrade-log").removeClass("hide");\
		  $(".bar").css("width", bar_val+"%").attr("aria-valuenow", bar_val);\
          wait_for_upgradegui();\
        }\
        else {\
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
