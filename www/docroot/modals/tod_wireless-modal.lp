--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local match, format = string.match, string.format
local parental_helper = require("parental_helper")
local tod = parental_helper.getTodwifi()
local tod_columns, tod_default, tod_valid = tod.columns, tod.default, tod.valid

local tod_options = {
    tableid     = "tod",
    basepath    = "rpc.wifitod.",
    createMsg   = T"Add New Rule",
    canAdd      = true,
    canDelete   = true,
    canApply    = true,
    canEdit     = true,
}

local function validateTime(value, object, key)
    local timepattern = "^(%d+):(%d+)$"
    local time = { match(value, timepattern) }
    if #time == 2 then
       local hour = tonumber(time[1])
       local min = tonumber(time[2])
       if hour < 0 or hour > 23 then
          return nil, T"Invalid hour, must be between 0 and 23"
       end
       if min < 0 or min > 59 then
          return nil, T"Invalid minutes, must be between 0 and 59"
       end
       return true
    else
       return nil, T"Invalid time (must be hh:mm)"
    end
end

-- function that can be used to validate weekday
-- @param #value have the value of corresponding key
-- @param #object have the POST data
-- @param #key validation key name
-- @return #boolean or nil+error message
local function validateWeekday(value, object, key)
   local retVal, errorMsg = parental_helper.validateTodRule(value, object, key, "Wireless")
   if not retVal then
     message_helper.pushMessage(format("%s",errorMsg), "error")
   end
   return retVal
end

tod_valid["start_time"] = validateTime
tod_valid["stop_time"] = validateTime
tod_valid["weekdays"] = validateWeekday

local tod_data, tod_helpmsg = post_helper.handleTableQuery(tod_columns, tod_options, nil, tod_default, tod_valid)
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Time of Day") ); ngx.print('\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages()) ); ngx.print('\
\
<div class="modal-body update">\
\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-wireless.lp")
  ngx.print('\
\
  <form class="form-horizontal" method="post" action="/modals/tod_wireless-modal.lp">\
    <legend>');  ngx.print( T"Time of day wireless control" ); ngx.print('</legend>\
    ');  ngx.print(
      ui_helper.createTable(tod_columns, tod_data, tod_options, nil, tod_helpmsg)
    ); ngx.print('\
    ');  if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action == "TABLE-NEW" or ngx.req.get_post_args().action == "TABLE-EDIT") then  ngx.print('\
      <script type="text/javascript">\
        var warning = \'<div class="control-group"><div style="padding-top: 12px;" class="controls"><span class="alert">\'\
                      +\'');  ngx.print( T"The Gateway will block/allow all the time if none of the days are selected" ); ngx.print('</span></div></div>\';\
        $(\'#stoptime\').parent().parent().after(warning);\
      </script>\
    ');  end  ngx.print('\
  </form>\
</div>\
\
<script type="text/javascript">\
    $(function () {\
        var opt = {\
            theme: \'android-ics light\',\
            display: \'bubble\',\
            mode: \'scroller\',\
            headerText: false,\
            timeFormat: \'HH:ii\',\
            stepMinute: 15\
        };\
        $("#starttime").mobiscroll().time(opt);\
        $("#stoptime").mobiscroll().time(opt);\
    });\
</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 