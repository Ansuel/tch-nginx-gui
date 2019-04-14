--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-speedservice')

local ngx = ngx
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local format = string.format
local SpeedService = {
  Direction = "rpc.X_000E50_SpeedService.Direction",
  MaxSteps = "rpc.X_000E50_SpeedService.MaxSteps",
  TCPPort = "rpc.X_000E50_SpeedService.TCPPort",
  DiagnosticsState = "rpc.X_000E50_SpeedService.DiagnosticsState",
  Algorithm = "rpc.X_000E50_SpeedService.Algorithm",
  PacketLength = "rpc.X_000E50_SpeedService.PacketLength",
  LatencyTolerancePercentage = "rpc.X_000E50_SpeedService.LatencyTolerancePercentage",
  AcceptablePercentageLoss = "rpc.X_000E50_SpeedService.AcceptablePercentageLoss",
  StartingBwKbps = "rpc.X_000E50_SpeedService.StartingBwKbps",
  Mode = "rpc.X_000E50_SpeedService.Mode",
  ServerIPAddress = "rpc.X_000E50_SpeedService.ServerIPAddress",
  StepDuration = "rpc.X_000E50_SpeedService.StepDuration",
  ResultCount = "rpc.X_000E50_SpeedService.ResultCount",
}


if ngx.var.request_method == "POST" then
  local post_content, success = ngx.req.get_post_args(), false
  local maxsteps_chk=true
  if post_content.action == "Speed" then
    if post_content["Algorithm"] ~= "RxRate" and post_content["MaxSteps"] < "1" then
        maxsteps_chk = false
    end
    local setTable = {}
    for k,v in pairs(SpeedService) do
      setTable[v] = post_content[k]
    end
    success = proxy.set(setTable)
    if success then
      proxy.set("rpc.X_000E50_SpeedService.DiagnosticsState", "Requested")
    end
  elseif post_content.action == "SpeedStop" then
    success = proxy.set("rpc.X_000E50_SpeedService.DiagnosticsState", "Abort")
  end
  if not maxsteps_chk then
    message_helper.pushMessage(T"MaxSteps should be greater than or equal to 1 when Algorithm is Binary/Ramp/Fast", "error")
  elseif not success then
    message_helper.pushMessage(T"Changes not saved", "error")
  else
    proxy.apply()
  end
end
content_helper.getExactContent(SpeedService)
local speed_data = {}
speed_data = proxy.get("rpc.X_000E50_SpeedService.Result.")
speed_data = content_helper.convertResultToObject("rpc.X_000E50_SpeedService.Result.", speed_data)
local column_data = {}
for i,v in ipairs(speed_data) do
  v.paramindex = nil
  column_data[#column_data + 1] = {}
  for k,data in pairs(v) do
    table.insert(column_data[#column_data],data)
  end
end
local table_columms = {
  {
     header = T"Direction",
     type = "text",
     readonly = true,
     name = "Direction",
  },
  {
     header = T"Loss Packets",
     type = "text",
     readonly = true,
     name = "PacketLoss",
  },
  {
     header = T"Received Time",
     type = "text",
     readonly = true,
     name = "ReceivedTime",
  },
  {
     header = T"PayLoad Rate(Kbps)",
     type = "text",
     readonly = true,
     name = "PayLoadRate",
  },
  {
     header = T"Overhead",
     type = "text",
     readonly = true,
     name = "Overhead",
  },
  {
     header = T"Average Latency",
     type = "text",
     readonly = true,
     name = "AvgLatency",
  },
  {
     header = T"Good put(Kbps)",
     type = "text",
     readonly = true,
     name = "GoodPut",
  },
  {
     header = T"Adjusted Received Rate",
     type = "text",
     readonly = true,
     name = "AdjustReceivedRate",
  },
  {
     header = T"Runtime",
     type = "text",
     readonly = true,
     name = "RunTime",
  },
}
local mode = {
  {"send", T"Send"},
  {"bw", T"BW"}
}
local direction = {
  {"downstream", T"Downstream"},
  {"upstream", T"Upstream"}
}
local algorithm = {
  {"Ramp", T"Ramp"},
  {"Binary", T"Binary"},
  {"Fast", T"Fast"},
  {"RxRate", T"RxRate"}
}

local speed_options = {
 tableid = "speed_data",
 canAdd = false,
 canEdit = false,
 canDelete = false,
}
local attributes,statusIcon = { span = { class = "span8" } }
if SpeedService.DiagnosticsState ~= "Requested"  then
  statusIcon = '<i class="icon-asterisk icon-large blue"></i> '
else
  statusIcon = '<i class="icon-ban-circle icon-large red"></i> '
end
local attrSpeed = {input = { ["data-for"] = "Speed"}}
local attrSpeedSelect = {select = { ["data-for"] = "Speed"}}
  ngx.print('\
');  ngx.print( ui_helper.createHeader(T"Speed Service", false, true)); ngx.print('\
<div class="modal-body no-save update">\
  <form class="form-horizontal" method="post" action="modals/speedservice-modal.lp">\
    ');  ngx.print(ui_helper.createMessages(message_helper.popMessages())); ngx.print('\
    ');  
      local html = {}
      html[#html+1] = "<fieldset id='speedservice-tab'><legend>" .. T"Initiate A Speed Diagnostic" .. "</legend>"
      html[#html+1] = ui_helper.createLabel(T"Status:", format("%s %s", statusIcon, SpeedService.DiagnosticsState), attributes)
      html[#html+1] = ui_helper.createInputSelect(T"Mode:", "Mode",mode,SpeedService.Mode,attrSpeedSelect)
      html[#html+1] = ui_helper.createInputText(T"Server Address:", "ServerIPAddress",SpeedService.ServerIPAddress,attrSpeed)
      html[#html+1] = ui_helper.createInputText(T"Server Port:", "TCPPort", SpeedService.TCPPort,attrSpeed)
      html[#html+1] = ui_helper.createInputSelect(T"Direction:", "Direction" , direction,SpeedService.Direction,attrSpeedSelect)
      html[#html+1] = ui_helper.createInputText(T"Step Duration(ms):", "StepDuration", SpeedService.StepDuration,attrSpeed)
      html[#html+1] = ui_helper.createInputText(T"UDP Payload Length:", "PacketLength", SpeedService.PacketLength,attrSpeed)
      html[#html+1] = ui_helper.createInputText(T"Max (kbps:)", "StartingBwKbps",SpeedService.StartingBwKbps,attrSpeed)
      html[#html+1] = ui_helper.createInputText(T"Result Count", "ResultCount",SpeedService.ResultCount,attrSpeed)
      html[#html+1] = ui_helper.createInputSelect(T"Algorithm:","Algorithm", algorithm,SpeedService.Algorithm,attrSpeedSelect)
      html[#html+1] = "<div id='latencyTolerancePercentage-row'>"
      html[#html+1] = ui_helper.createInputText(T"Latency Tolerance Percentage", "LatencyTolerancePercentage",SpeedService.LatencyTolerancePercentage,attrSpeed)
      html[#html+1] = "</div><div id='maxSteps-row'>"
      html[#html+1] = ui_helper.createInputText(T"Max Steps", "MaxSteps",SpeedService.MaxSteps,attrSpeed)
      html[#html+1] = "</div><div id='acceptablePercentageLoss-row'>"
      html[#html+1] = ui_helper.createInputText(T"Acceptable Percentage Loss", "AcceptablePercentageLoss",SpeedService.AcceptablePercentageLoss,attrSpeed)
      html[#html+1] = "</div>"
      if SpeedService.DiagnosticsState ~= "Requested"  then
        html[#html+1] = "<div class='controls'><div id='send-config_Speed' class='btn' data-name='action' data-value='Speed'>Run Speed Diagnostics</div></div>"
      else
        html[#html+1] = "<div class='controls'><div id='send-config_Speed' class='btn' data-name='action' data-value='SpeedStop'>Stop Speed Diagnostics</div></div>"
      end
      html[#html+1] = "<fieldset><legend>" .. T"Speed Diagonostics Result History" .. "</legend>"
      html[#html+1] = ui_helper.createTable(table_columms, column_data, speed_options)
      html[#html+1] = "</fieldset>"
      ngx.print(html)
      ngx.print('\
  </form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
function show_parameters()\
{\
  if($("#Algorithm").val() == "Binary") {\
      $("#latencyTolerancePercentage-row").show();\
      $("#maxSteps-row").show();\
      $("#acceptablePercentageLoss-row").show();\
  }\
    else if(($("#Algorithm").val() == "Ramp") || ($("#Algorithm").val() == "Fast")) {\
      $("#latencyTolerancePercentage-row").show();\
      $("#maxSteps-row").show();\
      $("#acceptablePercentageLoss-row").hide();\
  }\
    else {\
      $("#latencyTolerancePercentage-row").hide();\
      $("#maxSteps-row").hide();\
      $("#acceptablePercentageLoss-row").hide();\
  }\
}\
(function() {\
  show_parameters();\
  $("#Algorithm").change(show_parameters);\
}());\
</script>\
'); 