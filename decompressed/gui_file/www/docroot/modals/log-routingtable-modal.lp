--pretranslated: do not change this file
 
-- Localization
-- NG-105177 [Workaround] TI [GUI] - Some of the tabs throws Internal server error
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local sub, len = string.sub, string.len
local logdata = proxy.get("sys.log.routingtable")
logdata = logdata[1].value

local log_columns = {
    {
        header = T"Destination",
        name = "destination",
        param = "destination",
        type = "text",
        attr = { input = {  class="span1" } },
    },
    {
        header = T"Gateway",
        name = "gateway",
        param = "gateway",
        type = "text",
        attr = { input = { class="span1" } },
    },
    {
        header = T"Genmask",
        name = "genmask",
        param = "genmask",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Flags",
        name = "flags",
        param = "flags",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Metric",
        name = "metric",
        param = "metric",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Ref",
        name = "ref",
        param = "ref",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Use",
        name = "use",
        param = "use",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Iface",
        name = "iface",
        param = "iface",
        type = "text",
        attr = { select = { class="span1" } },
    },
}

local log_options = {
    tableid = "routingtable",
    basepath = "sys.log.",
    canAdd = false,
    canEdit = false,
    canDelete = false,
}

local log_array = {}
local pattern = "([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)"

local skip_first_line = 1
logdata = sub(logdata, len("Kernel IP routing table") + 1)

logdata:gsub(pattern, function(destination, gateway, genmask, flags, metric, ref, use, iface)
    -- skip the first title line
   if #log_array == 0 and skip_first_line == 1 then
     skip_first_line = 0
   else
     log_array[#log_array+1] = {destination, gateway, genmask, flags, metric, ref, use, iface}
   end
end)


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
<legend>');  ngx.print( T"System Log - Routing Table" ); ngx.print('</legend>\
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
<div class="modal-footer">\
    <div id="modal-no-change">\
        <div class="btn btn-primary btn-large" data-dismiss="modal">');  ngx.print( T"Close" ); ngx.print('</div>\
    </div>\
</div>\
'); 