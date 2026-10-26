--pretranslated: do not change this file
 
-- Enable localization
-- NG-105177 [Workaround] TI [GUI] - Some of the tabs throws Internal server error
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local format,find,sub = string.format, string.find, string.sub
local floor = math.floor
local table = table
local logdata = ""
local export_rpc_path = "rpc.system.log.conntrack."

if ngx.req.get_method() == "GET" then
    proxy.set("rpc.system.log.conntrack.state", "Requested")
    local f = io.open("/tmp/nf_conntrack", "r")
    if f then
        logdata = f:read("*all")
        f:close()
    end
end

local log_columns = {
    {
        header = T"Proto",
        name = "proto",
        param = "proto",
        type = "text",
        attr = { input = {  class="span1" } },
    },
    {
        header = T"Source Address",
        name = "source address",
        param = "source address",
        type = "text",
        attr = { input = { class="span1" } },
    },
    {
        header = T"Port",
        name = "source port",
        param = "source port",
        type = "text",
        attr = { input = { class="span1" } },
    },
    {
        header = T"Destination Address",
        name  = "destination address",
        param = "destination address",
        type = "text",
        attr = { input = { class="span1" } },
    },
    {
        header = T"Port",
        name  = "destination port",
        param = "destination port",
        type = "text",
        attr = { input = { class="span1" } },
    },
    {
        header = T"State",
        name  = "state",
        param = "state",
        type = "text",
        attr = { input = { class="span1" } },
    },
}

local log_options = {
    tableid = "connections",
    basepath = "sys.log.",
    canAdd = false,
    canEdit = false,
    canDelete = false,
}


local log_array = {}
local pattern = "[^%s]+%s+[^%s]+%s+([%w]+)%s+[^%s]+%s+[^%s]+%s+([^\n]+)"
local tcpPattern = "([^%s]+)%s+src=([%w:.]+)%s+dst=([%w:.]+)%s+sport=(%d+)%s+dport=(%d+).+"
local udpPattern = "src=([%w:.]+)%s+dst=([%w:.+]+)%s+sport=(%d+)%s+dport=(%d+).+(%[%w+%]).+"

local tcp_ignore = {
    ["127.0.0.1"] = true,
}
local udp_ignore = {
    ["127.0.0.1"] = true,
    ["0.0.0.0"] = true,
}
logdata:gsub(pattern, function(proto, subString)
  local srcAddr, srcPort, dstAddr, dstPort, state
  local source, destination
  if proto == "tcp" then
    subString:gsub(tcpPattern,function(state_, srcAddr_, dstAddr_, srcPort_, dstPort_)
      state = state_
      source =  srcAddr_
      sport = srcPort_
      destination = dstAddr_
      dport = dstPort_
    end)
    if source and destination and state and not tcp_ignore[source] then
      log_array[#log_array+1] = {proto, source, sport, destination,  dport, state}
    end
  elseif proto == "udp" then
    subString:gsub(udpPattern,function(srcAddr_, dstAddr_, srcPort_, dstPort_, state_)
      state = state_
      source =  srcAddr_
      sport = srcPort_
      destination = dstAddr_
      dport = dstPort_
    end)
    if source and destination and state and not udp_ignore[source] then
      log_array[#log_array+1] = {proto, source, sport, destination,  dport, state}
    end
  end
end)

-- sort protocol tcp/udp
table.sort(log_array, function(a, b)
   return a[1] < b[1]
end)

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
      ngx.print('{ "error":"10" }')
      ngx.exit(ngx.OK)
    else
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
  end
end

local function export_conntrack_log()
  local export_state = export_rpc_path .. "state"
  -- start the file export
  proxy.set(export_state, "Requested")
  -- wait for completion; does not return on error or timeout
  wait_for_completion(export_rpc_path)
  -- return exported data
  ngx.header.content_disposition = "attachment; filename=connectionlog"
  ngx.header.content_type = "application/octet-stream"
  ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JS download code requires this cookie
  local export_path = ("/tmp/nf_conntrack")
  local f = io.open(export_path, "r")
  ngx.print(f:read("*all"))
  f:close()
  -- cleanup (reset state and remove export file)
  proxy.set(export_state, "None")
  -- and we're done
  ngx.exit(ngx.HTTP_OK)
end

-- Handle fwupgrade/configimport/configexport specific GET/POSTs.
if ngx.req.get_method() == "POST" then
  -- now process non-file POSTs
  local action = ngx.req.get_post_args().action
  if action == "export_conntrack_log" then
    return export_conntrack_log()
  end
end
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Management", false, true))   ngx.print('\
<div class="modal-body update no-save">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-management.lp")
  ngx.print('\
\
<fieldset>\
    <form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
    ');  

ngx.print('<legend>');  ngx.print( T"System Log - Active Connections" ); ngx.print('</legend>\
')
    -- add input filter for user searching
    local filterclass = {
        input = {
            id = "searchInput",
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
    local html = {}
    html[#html + 1] = "<div class='control-group'><label class='control-label'>"..T"Filter".."</label><div class='controls'>"
    html[#html +1] = "<input data-type='search' name='Filter' class='edit-input span3' placeholder='"..T"Search For connections...".."' id='searchInput' type='text'>"
    html[#html +1] = "<div id='Export' class='btn export-conntracklog custom-handler'><i class='icon-download-alt'></i>"..T"Export All".."</div>"
    html[#html +1] ="</div></div>"
    ngx.print(html)
    ngx.print(ui_helper.createAlertBlock(T"Exporting configuration, please wait...", exporting_alert))
    ngx.print( ui_helper.createAlertBlock(T"Exporting failed; please try again.", exporting_fail))
    ngx.print(ui_helper.createTable(log_columns, log_array, log_options, nil, nil))
    -- cleanup the temp file
    proxy.set("rpc.system.log.conntrack.state", "None")
      ngx.print('\
    </form>\
  </fieldset>\
</div>\
</div>\
<script>\
(function() {\
  var target = $(".modal form").attr("action");\
\
  $(".export-conntracklog").on("click", function() {\
    $.fileDownload(target, {\
      httpMethod: "POST",\
      data: new Array({ name : "action", value : "export_conntrack_log" },\
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
$("#searchInput").on("keyup", function () {\
    //split the current value of searchInput\
    var data = this.value.toUpperCase().split(" ");\
    //create a jquery object of the rows\
    var jo = $("#connections").find("tr");\
    if (this.value == "") {\
        jo.show();\
        return;\
    }\
    //hide all the rows\
    jo.hide();\
\
    //Recusively filter the jquery object to get results.\
    jo.filter(function (i, v) {\
        var $t = $(this);\
        for (var d = 0; d < data.length; ++d) {\
            if ($t.text().toUpperCase().indexOf(data[d]) > -1) {\
                return true;\
            }\
        }\
        return false;\
    })\
    //show the rows that match.\
    .show();\
}).trigger("focus", function () {\
    this.value = "";\
    $(this).unbind(\'focus\');\
}).css({\
    "color": "#C0C0C0"\
});\
\
}());\
\
\
</script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 