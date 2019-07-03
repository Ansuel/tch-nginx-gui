--pretranslated: do not change this file
 
-- Localization
-- NG-105177 [Workaround] TI [GUI] - Some of the tabs throws Internal server error
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local logdownload_helper = require("logdownload_helper")
local type, setmetatable, random = type, setmetatable, math.random
local table, ipairs, istainted, format = table, ipairs, string.istainted, string.format
local session = ngx.ctx.session

local logdata = proxy.get("sys.log.devicelog")
logdata = logdata[1].value

local log_columns = {
    {
        header = T"Date",
        name = "date",
        param = "date",
        type = "text",
        attr = { input = {  class="span1" } },
    },
    {
        header = T"Facility",
        name = "facility",
        param = "facility",
        type = "text",
        attr = { input = { class="span1" } },
    },
    {
        header = T"Process",
        name = "process",
        param = "process",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Message",
        name = "message",
        param = "message",
        type = "text",
        attr = { select = { class="span6" } },
    },
}

local log_options = {
    tableid = "logviewer",
    basepath = "sys.log.",
    canAdd = false,
    canEdit = false,
    canDelete = false,
}

local getargs = ngx.req.get_uri_args()
local current_process = getargs["process"]
if current_process == "" then
    current_process = nil
end

local log_array = {}
local processes_list = {}
local pattern = "([^%s]+%s+%d+ %d+:%d+:%d+) [^%s]+ ([^%s]+) ([^%s]+): ([^\n]+)"

logdata:gsub(pattern, function(date, facility, process, message)
    local p = string.match(process, "[^%[]+")
    if not current_process or p == current_process then
        log_array[#log_array+1] = { date, facility, process, message }
    end
    if p then
        processes_list[p] = true
    end
end)

-- Reverse table to show most recent first
local size = #log_array
local t = {}
for i,v in ipairs(log_array) do
    t[size-i] = v
end
log_array = t

local processes_select = {}
for k in pairs(processes_list) do
    processes_select[#processes_select+1] = { k, k }
end

table.sort(processes_select, function(a,b)
    return a[1] < b[1]
end)

table.insert(processes_select, 1, {"", T"Everything"})

if ngx.req.get_method() == "POST" then
    -- now process non-file POSTs
    local action = ngx.req.get_post_args().action
    if action == "export_log" then
        return logdownload_helper.export_log("logread")
    end
end

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Management", false, true, 5))   ngx.print('\
\
<div class="modal-body update no-save">\
\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-management.lp")
  ngx.print('\
\
<form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
');


      local filterclass = {
        span = {
          style = "float:left;",
        },
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
      local html = {}
      html[#html + 1] = "<table><tr><td>"
      html[#html + 1] = ui_helper.createInputSelect(T"Filter", "process", processes_select, current_process or "", filterclass)
      html[#html + 1] = "</td><td>&nbsp;&nbsp;</td><td>"
	  html[#html + 1] = format('<div id="Export" class="btn export-conntracklog custom-handler" style="margin-bottom:8px;"><i class="icon-download-alt"></i> %s</div>', T"Export All")
      html[#html + 1] = "</td></tr></table>"
      ngx.print(html)
      ngx.print(ui_helper.createAlertBlock(T"Exporting log, please wait ...", exporting_alert))
      ngx.print(ui_helper.createAlertBlock(T"Exporting failed; please try again.", exporting_fail))
      ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
<fieldset>\
\
');  
ngx.print(ui_helper.createTable(log_columns, log_array, log_options, nil, nil))
  ngx.print('\
\
</fieldset>\
</form>\
</div>\
')
if session:getrole() == "engineer" then
	ngx.print('\
	</div>\
	')
end
ngx.print('<div class="modal-footer">\
    <div id="modal-no-change">\
        <div class="btn btn-primary btn-large" data-dismiss="modal">');  ngx.print( T"Close" ); ngx.print('</div>\
    </div>\
</div>\
<script type="text/javascript">\
    var target = $(".modal form").attr("action");\
\
    $(".export-conntracklog").on("click", function() {\
      $.fileDownload(target, {\
        httpMethod: "POST",\
        data: new Array({ name : "action", value : "export_log" },\
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
    $(\'select[name="process"]\').on("change", function() {\
        var process = $(this).val();\
        tch.loadModal("/modals/logviewer-modal.lp?process=" + process);\
    });\
</script>\
'); 