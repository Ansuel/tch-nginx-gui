--pretranslated: do not change this file
 
local istainted = string.istainted

-- Enable localization
gettext.textdomain('webui-contentsharing')

local tinsert = table.insert
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local attributes = { span = { class = "span4" } }
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local get_usb_label = require("usbmap").get_usb_label

local untaint = string.untaint
local format, find, sub, match = string.format, string.find, string.sub, string.match
local vNES = post_helper.validateNonEmptyString

-- Check availability of file, return true if found, else false
local function file_check(file_name)
  local file_found=io.open(file_name, "r")
  if file_found==nil then
    return false
  else
	file_found:close()
    return true
  end
end
if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action =="eject" then
  local path = format("sys.usb.device.%d.", ngx.req.get_post_args().ejectIndex)
  if proxy.set(path .. "unmount", "1") then
    proxy.apply()
    --Let ngx wait until complete USB mount successfully, otherwise the GUI table will display the ejected devices.
    local sec = 0
    repeat
      ngx.sleep(5)
      sec = sec + 5
      local result, errmsg = proxy.get(path)
    until not result or sec >= 60
  else
    message_helper.pushMessage(T"Error while ejecting USB disk", "error")
  end
end
-- Get the content_info
local mapParams = {}
local content_info = {}
local content = {}
local helpmsg = {}

local samba_available = file_check("/etc/init.d/samba")
if samba_available then
    local sambaMapParams = {
        samba_enabled     = "uci.samba.samba.enabled",
        samba_name        = "uci.samba.samba.name",
        samba_workgroup   = "uci.samba.samba.workgroup",
        samba_description = "uci.samba.samba.description",
    }
    for k,v in pairs(sambaMapParams) do
        mapParams[k] = v
    end
    content_info = {
        connecteddevices  = "sys.usb.DeviceNumberOfEntries",
        localdevIP        = "uci.network.interface.@lan.ipaddr",
    }
    content_helper.getExactContent(content_info)
end

local function check_dlna(dtype)
	local available = false
	local binname
	if file_check("/usr/bin/dlnad") then
		binname = "dlnad"
		available = true
	elseif file_check("/usr/sbin/minidlnad") then
		binname = "minidlna"
		available = true
	end
	
	if dtype:match("available") then
		return available
	elseif dtype:match("type") then
		return binname or ""
	end
	
	return ""
end

if check_dlna("available") then
	local type = check_dlna("type")
	local dlnaMapParams = {
		dlna_enabled       = "uci."..type..".config.enabled",
		dlna_friendly_name = "uci."..type..".config.friendly_name",
	}
	for k,v in pairs(dlnaMapParams) do
		mapParams[k] = v
	end
end

mapParams["usb3_enabled"] = "uci.system.config.enable_usb3_support"

local function valid_samba_dlna_string(value)
  local rc, msg = vNES(value)
  if not rc then
    return rc, msg
  end
  if match(value, "[^%w _%-]") then
    return nil, T"Only alphanumeric, space, underscore and dash characters allowed"
  end
  return true
end

local function valid_empty_string(value)
    if #value == 0 then
       return true
    end
    return false
end

local function valid_fail(_, _, param)
  local post_data = ngx.req.get_post_args()
  if post_data[param] then
    return nil
  end
  return true
end

local mapValid = {
	samba_enabled = post_helper.validateBoolean,
	samba_name = valid_empty_string,
	samba_workgroup = valid_empty_string,
	samba_description = valid_empty_string,
	dlna_enabled = post_helper.validateBoolean,
	dlna_friendly_name = valid_empty_string,
	usb3_enabled = post_helper.validateBoolean,
}

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
   post_data = ngx.req.get_post_args()
     if dlna_available and tonumber(post_data["dlna_enabled"]) == 1 then
        mapValid.dlna_friendly_name = valid_samba_dlna_string
     end
     if samba_available and tonumber(post_data["samba_enabled"]) == 1 then
        mapValid.samba_name = valid_samba_dlna_string
        mapValid.samba_workgroup = valid_samba_dlna_string
        mapValid.samba_description = valid_samba_dlna_string
     end
   content, helpmsg = post_helper.handleQuery(mapParams,mapValid)
end

if dlna_available or samba_available then
	content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
end

if ngx.var.request_method == "POST" and ngx.req.get_post_args().action == "SAVE" then
  if ngx.req.get_post_args().cs_flag == "1"  then
    ngx.header.content_type = "application/json"
    ngx.print('{ "success":"true" }')
    ngx.timer.at(0, function()
      proxy.apply()
    end)
    ngx.exit(ngx.HTTP_OK)
  end
end

-- usb Devices

local usbdev_columms = {
  {
     header = T"Port",
     type = "text",
     readonly = true,
  },
  {
     header = T"Product Name",
     type = "text",
     readonly = true,
  },
  {
     header = T"Manufacturer",
     type = "text",
     readonly = true,
  },
  {
     header = T"Power",
     type = "text",
     readonly = true,
  },
  {
     header = T"Version",
     type = "text",
     readonly = true,
  },
  {
     header = T"File System",
     type = "text",
     readonly = true,
  },
  {
     header = T"Total Space",
     type = "text",
     readonly = true,
  },
  {
     header = T"Used Space",
     type = "text",
     readonly = true,
  },
  {
     header = T"Free Space",
     type = "text",
     readonly = true,
  },
  {
     header = T"Volume",
     type = "text",
     readonly = true,
  },
  {
     header = T"Share",
     type = "text",
     readonly = true,
  },
  {
     header = T"Eject",
     type = "text",
     readonly = true,
  },
}

local usbdev_options = {
    tableid = "usbDev",
    basepath = "sys.usb.device.",
    canAdd = false,
    canEdit = false,
    canDelete = false,
}

local usb_disk_number = 0
local usbpart_data = {}

local function getProfileStatus()
  local profileStatus = "Idle"
  local usbdev_data = proxy.get("sys.usb.")
  if not usbdev_data then
    return profileStatus
  end
  local ready = "false"
  local profiling = "false"
  local idle = "false"
  local path_list, partitionCount, mobileIndex = {}, {}, ""
  for _, v in ipairs(usbdev_data) do
    if v.param == "path" and match(v.path,"sys.usb.device.%d+.partition.%d+.$") then
      -- don't show Extended partition
      local profile_status = proxy.get(v.path.."ProfileStatus")
      for i, v in ipairs(profile_status) do
        if profile_status ~= nil and profile_status[i]["value"] ~= nil and profile_status[i]["value"] ~= "" then
          if profile_status[i]["value"] == "Profiling" then
            profiling = "true"
            break
          elseif profile_status[i]["value"] == "Ready" then
            ready = "true"
          elseif profile_status[i]["value"] == "Idle" then
            idle = "true"
          end
        end
      end
      if profiling == "true" then
        break
      end
    end
  end
  if profiling == "true" or idle == "true" and ready == "true" then
    profileStatus = "Profiling"
  elseif idle == "true" and profiling == "false" then
    profileStatus = "Idle"
  elseif ready == "true" and profiling == "false" then
    profileStatus = "Ready"
  end
  return profileStatus
end

local function createUsbPartitionTable()
    local usbdev_data = proxy.get("sys.usb.")
    if not usbdev_data then
        return
    end

    local path_list, partitionCount, mobileIndex = {}, {}, ""
    for _, v in ipairs(usbdev_data) do
      if v.param == "path" and match(v.path,"sys.usb.device.%d+.partition.%d+.$") then
        -- don't show Extended partition
        local filesystem = proxy.get(v.path.."FileSystem")
        if filesystem ~= nil and filesystem[1]["value"] ~= nil and filesystem[1]["value"] ~= "" then
           path_list[#path_list+1] = v.path
           local idx = match(v.path, "sys.usb.device.(%d+).partition.%d+.$")
           partitionCount[idx] = partitionCount[idx] and partitionCount[idx] + 1 or 1
        end
      end
     if v.param == "partitionOfEntries" and v.value == "0" then
        mobileIndex = match(v.path,"sys%.usb%.device%.(%d+)%.")
      end
      -- Device class "08":It will be considered as a Mass storage device if it contains partitions.
      if v.param == "bInterfaceClass" and v.value == "08" and mobileIndex ~= match(v.path, "sys%.usb%.device%.(%d+)")then
        usb_disk_number = usb_disk_number + 1
      end
    end

    -- init the usbpart_data, each usb disk has an additional row for eject button
    -- the total  row  equal to partitions + usb_disk_number
    for i=1, #path_list+usb_disk_number do
      usbpart_data[i]={}
      for j=1,#usbdev_columms,1 do
        usbpart_data[i][j] = " "
      end
    end

    local deviceIndex, port, isduplicatePath, index  = "", 0, {}, 0
    for i=1, #path_list do
      index = index + 1
      local path = match(path_list[i],"(sys.usb.device.%d+.)partition.%d+.$")
      -- accorinding to isduplicatepath[path] to indicated if the eject line and project info had been added
      if not isduplicatePath[path] then
        local pathIndex = match(path, "sys.usb.device.(%d+).")
        -- Create eject button on 12th(last) Column of the table
        usbpart_data[index][12] = ui_helper.createSimpleButton(T"Eject", "icon-eject", {button = {class = "eject", index = pathIndex}})
        index = index + 1
      end
      local params_t =
      {
        [ "path" ..path ]  = 1,
        [ "product" .. path ] = 2,
        [ "manufacturer" .. path ] = 3,
        [ "power" .. path ] = 4,
        [ "version" .. path ] = 5,
        [ "FileSystem" .. path_list[i] ] = 6,
        [ "TotalSpace" .. path_list[i] ] = 7,
        [ "UsedSpace" ..  path_list[i] ] = 8 ,
        [ "AvailableSpace" .. path_list[i] ] = 9,
        [ "Volume".. path_list[i] ] = 10,
        [ "Share".. path_list[i] ] = 11,
      }
      for _, v in ipairs(usbdev_data) do
        if v.param and v.path and params_t[v.param .. v.path] then
          if v.param == "path" then
            if deviceIndex =="" or deviceIndex == match(v.path,"%d+") then
              port=port+1
            else
              port=1
            end
            usbpart_data[index][params_t[v.param .. v.path]] = format("%s-%s",get_usb_label(v.value),port)
            deviceIndex = match(v.path,"%d+")
          else
            --Set the product name on the row of eject button for the USB which contain partitions.
            --The params_t[v.param .. v.path] will return 2 if v.path value is path of product.
            if not isduplicatePath[path] and params_t[v.param .. v.path] == 2 then
               usbpart_data[index-1][params_t[v.param .. v.path]] = v.value
               isduplicatePath[path] = true
            end
            usbpart_data[index][params_t[v.param .. v.path]] = v.value
          end
        end
        usbpart_data[index][4] = "High Power"
      end --endof for usbdev_data
      usbpart_data[index][11] = format("\\\\%s\\%s", content_info.localdevIP,usbpart_data[index][11])
    end   --endof for #path_list
end

createUsbPartitionTable()

function convertReceivedData(content)
	if content["connecteddevices"] then
		if usb_disk_number == 0 then
			content["connecteddevices"] = format(T'<strong>%d</strong> connected devices', usb_disk_number)
		elseif usb_disk_number == 1 then
			content["connecteddevices"] = format(T'<strong>%d</strong> connected device', usb_disk_number)
		else
			content["connecteddevices"] = format(T'<strong>%d</strong> connected devices', usb_disk_number)
		end
	end
end

ajax_helper.handleAjaxQuery({
		connecteddevices = "sys.usb.DeviceNumberOfEntries",
	}, function(content)
		convertReceivedData(content)
	end)

convertReceivedData(content_info)

--local pageRefresh = nil
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Content Sharing", true, true)); ngx.print('\
\
<div class="modal-body update">\
	<form class="form-horizontal" method="post" action="modals/contentsharing-modal.lp">\
		');  
			ngx.print(ui_helper.createMessages(message_helper.popMessages()))
			local html = {}

			local changes = {
				alert = {
					class = "alert alert-success hide",
					id = "success-msg"
				}
			}
			tinsert(html, ui_helper.createAlertBlock(T"Changes saved successfully", changes))
			tinsert(html, "<fieldset><legend>" .. T"General status" .. "</legend>")
			local advanced = {
				group = { class = "advanced hide"},
				span = { class = "span4" }
			}
			local advancedhide = {
				group = { class = "advanced show"},
				span = { class = "span4" }
			}
			local toggle = {
				span = { class = "span4" },
				input = {
					id = "toggle-usb3",
				}
			}
			local warning = {
				span = { class = "span4" },
				alert = {
					class = "alert-warning hide",
					id = "warning-msg"
				},
			}
			local reboot_warning = {
				span = { class = "span4" },
				alert = {
					class = "alert-warning hide",
					id = "reboot-warning-msg"
				},
			}
			local rebooting = {
				alert = {
					class = "alert-warning hide",
					id = "rebooting-msg"
				}
			}
			local flagattr = {
				input = {
					class = "hide",
					id = "cs-flag"
				}
			}

			if samba_available then
				tinsert(html, ui_helper.createSwitch(T"SMB/CIFS Filesharing", "samba_enabled", (content["samba_enabled"] ~= "0" and "1" or "0"), attributes))
				tinsert(html, ui_helper.createLabel(T"SMB/CIFS name: ", content["samba_name"], advancedhide))
				tinsert(html, ui_helper.createInputText(T"SMB/CIFS name: ", "samba_name", content["samba_name"], advanced, helpmsg["samba_name"]))
				tinsert(html, ui_helper.createInputText(T"SMB/CIFS workgroup: ", "samba_workgroup", content["samba_workgroup"], advanced, helpmsg["samba_workgroup"]))
				tinsert(html, ui_helper.createInputText(T"SMB/CIFS description: ", "samba_description", content["samba_description"], advanced, helpmsg["samba_description"]))
			end
			if check_dlna("available") then
				tinsert(html, ui_helper.createSwitch(T"DLNA enabled", "dlna_enabled", content["dlna_enabled"],attributes))
				tinsert(html, ui_helper.createLabel(T"DLNA name: ", content["dlna_friendly_name"], advancedhide))
				tinsert(html, ui_helper.createInputText(T"DLNA name: ", "dlna_friendly_name", content["dlna_friendly_name"], advanced, helpmsg["dlna_friendly_name"]))
				tinsert(html, ui_helper.createLabel(T"Profiler status: ", T(getProfileStatus())))
			end

			tinsert(html, ui_helper.createSwitch(T"USB3.1 enabled", "usb3_enabled", (content["usb3_enabled"] ~= "" and content["usb3_enabled"] or "1"), toggle))
			tinsert(html, ui_helper.createAlertBlock(T"It is recommended to use USB2.0 standard. The use of USB3.1 standard can badly affect the Wi-Fi performance of the 2.4 Ghz band.", warning))
			tinsert(html, ui_helper.createAlertBlock(T"Toggling USB3.1 support will reboot the Gateway", reboot_warning))
			tinsert(html, ui_helper.createAlertBlock(T"Restarting, please wait...", rebooting))
			tinsert(html, ui_helper.createSimpleInputText("cs_flag", "0", flagattr))

			tinsert(html, "</fieldset>")

			if samba_available then
				tinsert(html, "<fieldset><legend>" .. T"Attached Drive Info" .. "</legend>")
				tinsert(html, format("<div><div id=\"connecteddevices\" class=\" simple-desc span3 monitor-changes\" data-ajaxrefresh=\"5\">%s</div>", content_info["connecteddevices"]))
				tinsert(html, ui_helper.createTable(usbdev_columms, usbpart_data, usbdev_options, nil, usbdev_helpmsg))
				tinsert(html, "</fieldset>")
			end
			ngx.print(html)
		  ngx.print('\
	</form>\
</div>\
');  ngx.print(string.format([[
<div class="modal-footer">
  <div id="modal-no-change">
    <div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">%s</div>
  </div>
  <div id="modal-changes" class="hide">
    <div id="cancel-config" class="btn btn-large" data-dismiss="modal">%s</div>
    <div id="save-cs-config" class="btn btn-primary btn-large">%s</div>
  </div>
</div>
]], T"Close", T"Cancel", T"Save")); ngx.print('\
\
<script>\
var refreshTimeOut = 5000;\
var refreshDelay = 3000;\
var target = $(".modal form").attr("action");\
var usb3_support = $("#toggle-usb3").val();\
\
$("#usbDev .eject").on("click", function(){\
  var index = $(this).attr("index");\
  var tparam = [];\
  tparam.push({\
    name: "action",\
    value :"eject"\
  });\
  tparam.push({\
    name:  "ejectIndex",\
    value: index\
  });\
  tparam.push(tch.elementCSRFtoken());\
  tch.loadModal("/modals/contentsharing-modal.lp", tparam, function(){\
     tch.scrollRowIntoView("usbDev", 1);});\
});\
\
$("#toggle-usb3").on("change", function() {\
  if($("#toggle-usb3").val() === "1") {\
    $("#warning-msg").removeClass("hide");\
  } else {\
    $("#warning-msg").addClass("hide");\
  }\
  $("#reboot-warning-msg").removeClass("hide");\
  $("#cs-flag").val("1");\
  if(usb3_support === $("#toggle-usb3").val()) {\
    $("#warning-msg").addClass("hide");\
    $("#reboot-warning-msg").addClass("hide");\
  }\
});\
\
function wait_for_webserver_running() {\
  $.ajax({ url: "/", timeout: refreshTimeOut })\
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
  $.ajax({ url: target, timeout: refreshTimeOut })\
  .done(function() {\
    window.setTimeout(wait_for_webserver_down, refreshDelay);\
  })\
  .fail(function() {\
    window.setTimeout(wait_for_webserver_running, refreshDelay);\
  });\
}\
\
$(document).on("click", "#save-cs-config", function() {\
  var form = $(".modal form");\
  var params = form.serializeArray();\
  if (($("#cs-flag").val() === "1") && (usb3_support !== $("#toggle-usb3").val())) {\
    $("#rebooting-msg").removeClass("hide");\
    $("#warning-msg").addClass("hide");\
    $("#reboot-warning-msg").addClass("hide");\
    $("#success-msg").addClass("hide");\
    tch.showProgress("');  ngx.print(T'Rebooting...'); ngx.print('");\
  }\
  else {\
    $("#success-msg").removeClass("hide");\
  }\
  $(\'#modal-changes\').hide();\
  $(\'#modal-no-change\').show();\
  params.push({\
    name : "action",\
    value : "SAVE"\
  }, {\
    name : "fromModal",\
    value : "YES"\
  }, tch.elementCSRFtoken());\
  var target = form.attr("action");\
  $.post(\
    target,\
    params,\
    wait_for_webserver_down,\
    "json"\
  );\
  return false;\
});\
</script>\
'); 
