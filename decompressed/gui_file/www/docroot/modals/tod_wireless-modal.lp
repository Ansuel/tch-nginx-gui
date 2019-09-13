--pretranslated: do not change this file

-- Localization
-- NG-155433 Wireless Control - Rule switches on all APs, also Guest APs
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local parental_helper = require("parental_helper")
local proxy = require("datamodel")

local ngx = ngx
local string, table = string, table
local concat, insert = table.concat, table.insert
local ipairs = ipairs
local tonumber = tonumber
local match, gmatch, format, find, untaint = string.match, string.gmatch, string.format, string.find, string.untaint

local tod = parental_helper.getTodwifi()
local tod_columns = tod.columns
local untaint_mt = require("web.taint").untaint_mt
local session = ngx.ctx.session

local validDays = post_helper.getValidateInEnumSelect(tod.days)
local validateBoolean = post_helper.validateBoolean
local validMode = post_helper.getValidateInEnumSelect({{"on"}, {"off"}})
local optionallyValidate = post_helper.getOptionalValidation

local uniqueKey = post_helper.getRandomKey()

local ap_status_map = setmetatable({
  ["0"] = T"Off",
  ["1"] = T"On",
  ["-1"] = T"Error. Re-set the rule!"
}, untaint_mt)

local ap_list = { }

local tod_timer_path = "uci.tod.timer."
local tod_action_path = "uci.tod.action."
local tod_wifitod_path = "uci.tod.wifitod."
local tod_ap_path = "uci.tod.ap."

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

-- validates days (Mon...Sun)
-- @param #table value have the value of corresponding key
-- @return #boolean or nil+error message
local function validateWeekdays(value)
  if not value then
    return nil, T"Invalid day"
  end
  for i, v in ipairs(value) do
    if not validDays(v) then
      return nil, T"Invalid day"
    end
  end
  return true
end

local function daysOverlap(days1, days2)
  days1 = concat(days1, " ")
  for _, day in ipairs(days2) do
    if find(days1, day) then
      return true
    end
  end
  return nil
end

local function validate_wifitod(postcontent, timer_data)
  local todData = {
    enable      = postcontent.enable,
    mode        = postcontent.mode,
    start_time  = postcontent.start_time,
    stop_time   = postcontent.stop_time,
    weekdays    = postcontent.weekdays,
  }
  local todValidations = {
    enable      = validateBoolean,
    mode        = validMode,
    start_time  = validateTime,
    stop_time   = validateTime,
    weekdays    = optionallyValidate(validateWeekdays), -- weekdays can be empty if user didn't select any day
  }

  local success, errmsg = content_helper.validateObject(todData, todValidations)
  if not success then
    return nil, errmsg
  end

  -- day/time overlap validation
  if postcontent.start_time >= postcontent.stop_time then
    return nil, T"Stop time should be greater then start time."
  end

  return true
end

local tod_options = {
  tableid     = "tod",
  basepath    = "uci.tod.action.",
  createMsg   = T"Add New Rule",
  canAdd      = true,
  canDelete   = true,
  canApply    = true,
  canEdit     = true,
  objectName  = "action"..uniqueKey,
  addNamedObject  = true,
}

local function getWifiTodListFromIndex(index) 

	if not index then
		return nil
	end
	
	local wifi_tod_path = "uci.tod.wifitod"
	
	if proxy.get(format("%s.@wifitod_%s.ap.", wifi_tod_path, index)) then
		return proxy.getPN(format("%s.@wifitod_%s.ap.", wifi_tod_path, index), true)
	end
	
	return nil
end

local function checkApInConfig(apInConfig,apToCheck)
	local ap_list = {}
  
	if not apInConfig then
		return false
	end
  
	for i,v in ipairs(apInConfig) do
		local ap_index = proxy.get(v.path.."value")[1].value
		ap_list[#ap_conf+1] = ap_list:match("(.*)_")
	end
	
	for _, ap in pairs(ap_list) do
		if ap == apToCheck then
			return true
		end
	end
		
	return false
end

local function onAdd(success, content, onModify)

  local index = success:match("action(.+)")
  local setObject = {}
  
  if type(content.weekdays) ~= "table" then
    if content.weekdays == "" then
      content.weekdays = {}
      for _, v in ipairs(tod.days) do
        insert(content.weekdays, v[1])
      end
    else
      content.weekdays = {untaint(content.weekdays)}
    end
  else
    for i, v in ipairs(content.weekdays) do
      content.weekdays[i] = untaint(v)
    end
  end
  
  if content.ap == "" then
	tod_options.errmsg = T"You must select at leat one ap"
	return nil
  end

  local valid, errmsg = validate_wifitod(content, session:retrieve("timer_data"))
  if not valid then
	tod_options.errmsg = errmsg
    return nil
  end
  
  local wifitod_id = "wifitod_"..index
  local tod_wifi_mode
  
  content.mode = content.mode == "on" and "1" or "0"
  
  if onModify then
	local ap_path
	for _,v in pairs(proxy.getPN(tod_wifitod_path.."@"..wifitod_id..".ap.",true)) do
		ap_path = proxy.get(v.path.."value")
		tod_wifi_mode = proxy.get(tod_ap_path.."@"..ap_path[1].value..".state")
		proxy.del(tod_ap_path.."@"..ap_path[1].value)
	end
	
	if tod_wifi_mode and content.mode ~= tod_wifi_mode[1].value then
		local tod_action_activeTimers = format("%s@action%s.activedaytime.",tod_action_path,index)
		for _,v in pairs(proxy.getPN(tod_action_activeTimers,true)) do
			proxy.del(v.path)
		end
	end
	proxy.del(tod_wifitod_path .. "@"..wifitod_id..".")
  end
  
  if not onModify then
    proxy.add(tod_action_path .. "@" .. success .. ".timers.")
    proxy.add(tod_timer_path, "timer"..index)
  end
  proxy.add(tod_wifitod_path, wifitod_id)
 
  for _ , ap in pairs(content.ap) do
	if not ( ap == "" ) then
		proxy.add(tod_wifitod_path .. "@"..wifitod_id..".ap.")
		proxy.add(tod_ap_path, format("%s_%s",ap,index))
	end
  end

  content.weekdays = concat(content.weekdays, ",")

  content.start_time = format("%s:%s", content.weekdays, content.start_time)
  content.stop_time = format("%s:%s", content.weekdays, content.stop_time)

  setObject[format("%s@action%s.timers.@1.value", tod_action_path, index)] = "timer"..index
  setObject[format("%s@action%s.enabled", tod_action_path, index)] = content.enabled
  setObject[format("%s@action%s.script", tod_action_path, index)] = "wifitodscript"
  setObject[format("%s@action%s.object", tod_action_path, index)] = "wifitod."..wifitod_id

  setObject[format("%s@timer%s.start_time", tod_timer_path, index)] = content.start_time
  setObject[format("%s@timer%s.stop_time", tod_timer_path, index)] = content.stop_time
  
  local count = 1
  
  for _ , ap in pairs(content.ap) do
	if not ( ap == "" ) then
		setObject[format("%s@%s.ap.@%s.value", tod_wifitod_path, wifitod_id, count)] = ap.."_"..index
		setObject[format("%s@%s_%s.state", tod_ap_path, ap, index)] = content.mode
		setObject[format("%s@%s_%s.ap", tod_ap_path, ap, index)] = ap
		count = count+1
	end
  end

  local ret = proxy.set(setObject)
  proxy.apply()
  
  return ret
end

local function onModify(index, content)
  local ret = onAdd(index, content, true)
  return ret
end

local function onDelete(success)
  local index = success:match("action(.+)")
  
  if not index then
	tod_options.errmsg = "Error on delete. Remove rule from config file manually."
	return nil
  end
  
  local delObject = {}
  local ret
  
  local wifiTodList = getWifiTodListFromIndex(index)
  
  if wifiTodList then
	for i,v in ipairs(wifiTodList) do
		delObject[#delObject+1] = format("uci.tod.ap.@%s.",proxy.get(v.path.."value")[1].value)
	end
  end

  delObject[#delObject+1] = format("uci.tod.action.@action%s.", index)
  delObject[#delObject+1] = format("uci.tod.timer.@timer%s.", index)
  delObject[#delObject+1] = format("uci.tod.wifitod.@wifitod_%s.", index)
  
  for _ , obj in pairs(delObject) do
	ret = proxy.del(obj) 
  end
  
  return ret
end

if ngx.var.request_method == "POST" then
  local postargs = ngx.req.get_post_args()
  postargs.index = tonumber(postargs.index) or -1
  local current_index = postargs.index
  local allowedIndexes = session:retrieve(tod_options.tableid .. ".allowedindexes") or {}
  current_index = allowedIndexes[current_index] and allowedIndexes[current_index].paramindex or -1

  if postargs.action == "TABLE-NEW" then
    tod_options.editing = -1
  elseif postargs.action == "TABLE-EDIT" then
    tod_options.editing = postargs.index
  elseif postargs.action == "TABLE-ADD" then
    current_index = proxy.add(tod_action_path, tod_options.objectName)
    local success = onAdd(current_index, postargs)
    if not success then
      proxy.del(tod_action_path .. "@" .. tod_options.objectName .. ".")
      tod_options.editing = -1
    end
  elseif postargs.action == "TABLE-MODIFY" then
    local success = onModify(current_index, postargs)
	if not success then
	  tod_options.editing = -1
	end
  elseif postargs.action == "TABLE-DELETE" then
    onDelete(current_index)
  end
end

local action_list = content_helper.convertResultToObject(tod_action_path, proxy.get(tod_action_path))
local timer_list = content_helper.convertResultToObject(tod_timer_path, proxy.get(tod_timer_path))
local wifitod_list = content_helper.convertResultToObject(tod_wifitod_path, proxy.get(tod_wifitod_path))
local ap_list = content_helper.convertResultToObject(tod_ap_path, proxy.get(tod_ap_path))
local timer_data = {}

local function getApSelected(index)
	local wifi_list, wifi_selected = {}, {}
	
	local wifiTodList = getWifiTodListFromIndex(index)
	
	if not wifiTodList then
		return "", {}
	end
	
	for _,v in ipairs(wifiTodList) do
		local ap_index = proxy.get(v.path.."value")[1].value
		local ap = ap_index:match("(.*)_")
		local ssid_get = proxy.get("rpc.wireless.ap.@"..ap..".ssid")
		wifi_selected[#wifi_selected+1] = ap
		if ssid_get then
			local ssid = ssid_get[1].value
			local name = proxy.get("rpc.wireless.ssid.@"..ssid..".ssid")[1].value
			
			local freq = proxy.get("rpc.wireless.ssid.@"..ssid..".radio")
			freq = freq and freq[1].value
			freq = string.match(freq,"radio_5G") and "5GHz" or "2.4GHz"
			
			wifi_list[#wifi_list+1] = untaint(name).." ("..untaint(freq)..")"
			wifi_list[#wifi_list+1] = "<br>"
		end
	end
	
	return table.concat(wifi_list), wifi_selected
end

local tod_data, tod_index = content_helper.loadTableData(tod_options.basepath, tod_columns)

local tablesessionindexes = tod_options.tableid .. ".allowedindexes"
session:store(tablesessionindexes, tod_index)

for i, v in ipairs(tod_data) do
	local index = action_list[i].object:gsub("wifitod.wifitod_","")
	local wifi_list, wifi_selected = getApSelected(index)
	local days, start_time = timer_list[i].start_time:match("^(.-):(.+)$")
	
	local ap_state = "-1"
	local ap_state_get
	
	if wifi_selected[1] then
		ap_state_get = proxy.get(format("%s@%s_%s.state",tod_ap_path , wifi_selected[1],index))
		if ap_state_get then
			ap_state = ap_state_get[1].value
		end
	end
	
	v[1] = v[1] -- status
	v[2] = wifi_list -- ap
	v[3] = start_time -- start_time
	v[4] = timer_list[i].stop_time:match("^.-:(.+)$") -- stop_time
	v[5] = ap_status_map[ap_state] -- apState
	v[6] = {} -- days
	if days then
		for day in gmatch(days, "[^,]+") do
			insert(v[6], untaint(day))
		end
	end
	-- Sub Columns
	v[7] = {
		[1] = v[1], -- status
		[2] = {}, -- ap
		[3] = ap_state == "1" and "on" or "off", -- apState
		[4] = v[3], -- start_time
		[5] = v[4], -- stop_time
		[6] = v[6] -- days
	}

	for _, value in pairs(wifi_selected) do
		insert(v[7][2],untaint(value))
	end
	
	timer_data[i] = {
		start_time = v[3],
		stop_time = v[4],
		days = v[6]
	}
end

session:store("timer_data", timer_data)

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
    ');  ngx.print(ui_helper.createTable(tod_columns, tod_data, tod_options, nil, tod_helpmsg)); ngx.print('\
    ');  if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action == "TABLE-NEW" or ngx.req.get_post_args().action == "TABLE-EDIT") then  ngx.print('\
      <script type="text/javascript">\
        var warning = \'<div class="control-group"><div style="padding-top: 12px;" class="controls"><span class="alert">\'\
                      +"');  ngx.print( T"The Gateway will block/allow all the time if none of the days are selected" ); ngx.print('"+\'</span></div></div>\';\
		var warning_ap = \'<div class="control-group"><div style="padding-top: 12px; padding-bottom: 12px;" class="controls"><span class="alert">\'\
                      +"');  ngx.print( T"The AP can be selected only once, to modify it you need to remove the rule." ); ngx.print('"+\'</span></div></div>\';\
        $("#stoptime").parent().parent().after(warning);\
		$("#ap").parent().parent().after(warning_ap);\
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
            stepMinute: 1\
        };\
        $("#starttime").mobiscroll().time(opt);\
        $("#stoptime").mobiscroll().time(opt);\
		$("#starttime").removeAttr("readonly");\
		$("#stoptime").removeAttr("readonly");\
    });\
    $(".btn-table-add, .btn-table-modify").click(function() {\
        // ui_helper adds dummy hidden checkbox if no checkboxes are checked. we don\'t need that.\
        if ($("form .additional-edit input[name=weekdays]:visible:checked").length > 0) {\
          $("form input[name=weekdays]:hidden").removeAttr("name");\
        } else {\
          // we need one checkbox when no checkboxes are checked.\
          $("form input[name=weekdays]:hidden").removeAttr("name");\
          $("form input[type=checkbox]:hidden:last").attr("name", "weekdays");\
        }\
    });\
</script>\
');  ngx.print( ui_helper.createFooter() );
