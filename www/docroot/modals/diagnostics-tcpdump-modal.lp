--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local lfs = require("lfs")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local format, untaint, gmatch = string.format, string.untaint, string.gmatch
local open = io.open
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local session = ngx.ctx.session
local post_content = {}

local path_tcpdump = format("rpc.system.tcpdump.")

local function validateCount(value, object, key)
  local max = 16000
  local result = proxy.get("rpc.system.tcpdump.refcount")
  if result and result[1].value then
    max = 2*tonumber(untaint(result[1].value))
  end
  return post_helper.getValidateNumberInRange(1, tonumber(max))(value, object, key)
end

local tcpdumpValid = {
  interface = vNES,
  type = vNES,
  count = validateCount,
}

local tcpdump_intfs = {
}

local tcpdump_acc = {
  { "1", "Enabled" },
  { "0", "Disabled" },
}

local tcpdump_types = {
  { "pcap", T"PCAP" },
  { "log", T"LOG" },
 }

--[[
"None",       => { start }
  -- Requested
"Requested",  => { Stop }
  -- Complete
"Complete",   => { start, Download }
  -- Requested
"Error",      => { Start }
  -- Requested
--]]
local function tcpdump_download()
  local tcpdump_info = {
    state = path_tcpdump .. "state",
    file = path_tcpdump .. "file",
    type = path_tcpdump.. "type",
  }
  content_helper.getExactContent(tcpdump_info)

  if tcpdump_info.state == "Complete" then
    ngx.header.content_disposition = "attachment; filename=" .. (string.match(untaint(tcpdump_info.file), ".+/([^/]*%.%w+)$"))
    ngx.header.content_type = "application/octet-stream"
    ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JS download code requires this cookie

    local file = open(untaint(tcpdump_info.file), "r")
    -- buffer read for large file
    if file then
      local data
      while true do
        data = file:read(1024)
        if nil == data then
          break
        end
        ngx.print(data)
        ngx.flush(true)
      end
    end
    file:close()

    ngx.exit(ngx.HTTP_OK)
  end
end


local function restartTest(data)
  local success,msg = false, {}
  if type(data) == "table"  then
    success, msg = content_helper.validateObject(data, tcpdumpValid)
    if success then
        success = proxy.set({
                    ["rpc.system.tcpdump.interface"] = data["interface"],
                    ["rpc.system.tcpdump.type"] = data["type"],
                    ["rpc.system.tcpdump.count"] = data["count"],
                  }) and proxy.set({
                    ["rpc.system.tcpdump.state"] = "Requested",
                  })
        if success then
            proxy.apply()
        end
    end
  end
  return success, msg
end

local helpmsg = {}
local gsuccess = true
if ngx.var.request_method == "POST" then
  local tcpdumpState = proxy.get("rpc.system.tcpdump.state")
  local success
  gsuccess = true
  post_content = ngx.req.get_post_args()
  local action = post_content["action"]
  if action == "START" then
    if tcpdumpState and tcpdumpState[1].value ~= "Requested" then
      gsuccess, helpmsg = restartTest(post_content)
      session:store("diag_tcpdump_action", "TRUE")
    end
  elseif action == "STOP" then
    if tcpdumpState and tcpdumpState[1].value == "Requested" then
      success = proxy.set(path_tcpdump .. "state", "Complete")
      if success then
        proxy.apply();
      end
    end
  elseif action == "CLEAN" then
    if tcpdumpState and tcpdumpState[1].value == "Complete" then
      success = proxy.set(path_tcpdump .. "state", "None")
      if success then
        proxy.apply();
      end
    end
  elseif action == "tcpdump_download" then
    return tcpdump_download()
  end
end

local tcpdump_data = {
  state = path_tcpdump .. "state",
  type = path_tcpdump.. "type",
  count = path_tcpdump .. "count",
  refcount = path_tcpdump .. "refcount",
  interface = path_tcpdump.. "interface",
  file = path_tcpdump .. "file",
  intflist = path_tcpdump .. "intflist",
}


content_helper.getExactContent(tcpdump_data)
s = untaint(tcpdump_data.intflist)
for w in gmatch(s, "%S+") do
  tcpdump_intfs[#tcpdump_intfs+1] = {w, w}
end

tcpdump_data.count = post_content["count"] or tcpdump_data.count
tcpdump_data.interface = post_content["interface"] or tcpdump_data.interface
tcpdump_data.type = post_content["type"] or tcpdump_data.type

local refresh = 2
--This code will stop the refresh when all results are available
if tcpdump_data.state ~= "Requested" or not gsuccess then
  refresh = nil
end
ngx.print(ui_helper.createHeader(T"Diagnostics tcpdump", false, false, refresh))
  ngx.print('\
<div class="modal-body no-save update">\
');  
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-diagnostics.lp")
  ngx.print('\
<fieldset>\
<form class="form-horizontal" method="post" action="modals/diagnostics-tcpdump-modal.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"tcpdump" ); ngx.print('</legend>\
\
<div class="control-group">\
<label class="control-label"></label>\
  <div class="controls">\
    ');  ngx.print(ui_helper.createAlertBlock(T"1. Max Packet Number Recommened is dynamic and not accurate value (assume to use half of free memory).<br/>2. Acceleration disabled during tcpdump on platforms which supports flow cache!<br/>3. 'Download' invalid if nothing captured.<br/>4. 'Clean' captured file to reduce memory consumption."))   ngx.print('\
    ');  if(tcpdump_data.state == "Requested") then   ngx.print('\
      <div id="stop-tcpdump" class="btn" data-name="action" data-value="STOP">');  ngx.print( T"Stop" ); ngx.print('</div>\
    ');  elseif(tcpdump_data.state == "None" or tcpdump_data.state == "Complete" or tcpdump_data.state == "Error") then   ngx.print('\
      <div id="start-tcpdump" class="btn" data-name="action" data-value="START">');  ngx.print( T"Start" ); ngx.print('</div>\
      ');  if(tcpdump_data.state == "Complete") then   ngx.print('\
        <div id="clean-tcpdump" class="btn" data-name="action" data-value="CLEAN">');  ngx.print( T"Clean" ); ngx.print('</div>\
      ');  end  ngx.print('\
    ');  end  ngx.print('\
  </div>\
</div>\
');  
  local tcpdump_download = {
    button = {
      class = "tcpdump-download custom-handler"
    }
  }
  local downloading_alert = {
    alert = {
      class = "alert-info hide",
      id = "downloading-msg"
    }
  }
  local downloading_fail = {
    alert = {
      class = "alert-error hide",
      id = "download-failed-msg"
    }
  }
  local attrText = {input = { ["data-for"] = "START"}}
  local attrSelect = {select = { ["data-for"] = "START"}}
  local attributes = { span = { class = "span8" } }
  local statusText = ""
  local statusIcon = ""
  local testState = tcpdump_data.state

  if ngx.var.request_method == "POST" and gsuccess then
    if testState and session:retrieve("diag_tcpdump_action") =="TRUE" then
      if testState == "Complete" then
        statusIcon = "<i class=\"icon-ok icon-large green\"></i> "
        statusText = T"Success"
        elseif testState == "Requested" then
          statusIcon = "<i class=\"icon-asterisk icon-large blue\"></i> "
          statusText = T"Ongoing"
        elseif testState ~= "None" then
          statusIcon = "<i class=\"icon-ban-circle icon-large red\"></i>"
          statusText = T"Failed"
        else
          statusIcon = "<i class=\"icon-ban-circle icon-large red\"></i>"
          statusText = T"Not Requested"
        end
    end
  end

  html = {}
  if(tcpdump_data.state == "Complete") then
    local size = lfs.attributes (untaint(tcpdump_data.file), "size")
    if size ~= 0 then
      html[#html + 1] = ui_helper.createButton(T"", T"Download", "icon-download-alt", tcpdump_download)
      html[#html + 1] = ui_helper.createAlertBlock(T"Downloading tcpdump file, please wait...", downloading_alert)
      html[#html + 1] = ui_helper.createAlertBlock(T"Download failed; please try again.", downloading_fail)
    end
  end
  html[#html + 1] = ui_helper.createLabel(T"Status:", format("%s %s", statusIcon, statusText), attributes)
  html[#html + 1] = ui_helper.createLabel(T"Max Packet Number Recommended:", tcpdump_data.refcount, attributes)
  html[#html + 1] = ui_helper.createInputText(T"Packet Number:","count", tcpdump_data.count, attrText, helpmsg["count"])
  html[#html + 1] = ui_helper.createInputSelect(T"Interface:", "interface", tcpdump_intfs, tcpdump_data.interface, attrSelect, helpmsg["interface"])
  html[#html + 1] = ui_helper.createInputSelect(T"Log Type:", "type", tcpdump_types, tcpdump_data.type, attrSelect, helpmsg["type"])
  ngx.print(html)

  -- tcpdump log content
  if(tcpdump_data.state == "Complete" and tcpdump_data.type == "log") then
    local f = open(untaint(tcpdump_data.file), "r")
    if f then
      ngx.print(ui_helper.createLabel(T"Tcpdump Log:", ""))
      ngx.print("<div class='control-group'><label class='control-label'></label><div class='controls'>")
      ngx.print("<span id='' class='span9 simple-desc'>")
      for line in f:lines() do
        ngx.print("<i>>  " .. line .. "</i><br/>")
      end
      ngx.print("</span></div></div>")
      f:close()
    end
  end
  ngx.print('\
</fieldset>\
</form>\
</div>\
<script>\
(function() {\
  var target = $(".modal form").attr("action");\
\
  $(".tcpdump-download").click(function() {\
    $.fileDownload(target, {\
      httpMethod: "POST",\
      data: new Array({ name : "action", value : "tcpdump_download" },\
                      { name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") }),\
      prepareCallback: function() {\
        $("#download-failed-msg").addClass("hide");\
        var downloading_msg = $("#downloading-msg");\
        downloading_msg.removeClass("hide");\
        downloading_msg[0].scrollIntoView();\
      },\
      successCallback: function() {\
       $("#downloading-msg").addClass("hide");\
      },\
      failCallback: function() {\
        var download_failed_msg = $("#download-failed-msg");\
        download_failed_msg.removeClass("hide");\
        download_failed_msg[0].scrollIntoView();\
        $("#downloading-msg").addClass("hide");\
      }\
    });\
    return false;\
  });\
}());\
</script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 