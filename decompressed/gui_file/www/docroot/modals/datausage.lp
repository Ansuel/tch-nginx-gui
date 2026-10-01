--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local tinsert, untaint = table.insert, string.untaint

local function string_ends_with(String, End)
  return End == '' or string.sub(String, -string.len(End)) == End
end

local function get_wan_interfaces()
  local firewall_zone = proxy.get("uci.firewall.zone.")
  local firewall_zones = content_helper.convertResultToObject("uci.firewall.zone.", firewall_zone)
  local ifnames = {}
  for _, zone in ipairs(firewall_zones) do
    if zone.wan == "1" then
      local interfaces = content_helper.convertResultToObject("uci.firewall.zone.@" .. zone.name .. ".network.", firewall_zone)
      for _, interface in pairs(interfaces) do
        local ifname = untaint(interface.value)
        if not string_ends_with(ifname, "6") and not string_ends_with(ifname, "_4") then
          local interface_data = proxy.get("uci.network.interface.@" .. ifname .. ".")
          if interface_data then
            table.insert(ifnames, {ifname, ifname})
          end
        end
      end
    end
  end
  return ifnames
end

local function add_datausage_interface(interface)
local setTable = {}
  local path = string.format("uci.datausage.interface.@%s.", interface)
  local ifname = proxy.get(path .. "interface")
  if not ifname or ifname[1].value ~= interface then
    if not ifname then
      proxy.add("uci.datausage.interface.", interface)
      setTable[path .. "enabled"] = 0
      setTable[path .. "usage_cycle_reset_day"] = 1
    end
    setTable[path .. "interface"] = interface
    proxy.set(setTable)
    proxy.apply()
  end
end

local function sms_sending_supported()
  local content = proxy.get("rpc.mobiled.device.")
  local mobile_devices = content_helper.convertResultToObject("rpc.mobiled.device.", content)
  for _, device in ipairs(mobile_devices) do
    if string.untaint(device["capabilities.sms_sending"]) == "true" then
      return true
    end
  end
  return false
end

local function add_sms_notification(sms_message, interface)
  local setTable = {}
  local path = string.format("uci.datausage_notifier.action.@send_sms_%s.", interface)
  local notifier = proxy.get(path)
  if not notifier then
    if proxy.add("uci.datausage_notifier.action.", "send_sms_" .. interface) then
      setTable[path .. "handler"] = "sms"
      local index = proxy.add(path .. "events.")
      if index then
        setTable[path .. "events.@" .. index .. ".value"] = "limit_reached"
      end
      index = proxy.add(path .. "events.")
      if index then
        setTable[path .. "events.@" .. index .. ".value"] = "threshold_reached"
      end
      index = proxy.add(path .. "interfaces.")
      if index then
        setTable[path .. "interfaces.@" .. index .. ".value"] = interface
      end
      setTable[path .. "enabled"] = "0"
      setTable[path .. "message"] = sms_message
      proxy.set(setTable)
      proxy.apply()
    end
  end
end

local function validate_data_limit(value)
  if value == "" then
    return true
  end
  return post_helper.getValidateNumberInRange(1, 1024)(value)
end

local function validate_reset_day(value)
  if value == "" then
    return true
  end
  return post_helper.getValidateNumberInRange(1, 28)(value)
end

local page = {
  wan_interfaces = get_wan_interfaces(),
  sms_message = T"You have reached your data usage limit"
}

local args
if ngx.req.get_method() == "GET" then
  args = ngx.req.get_uri_args()
elseif ngx.req.get_method() == "POST" then
  args = ngx.req.get_post_args()
end

local interfaces = untaint(args["selected_interface"])

local validate_interface = post_helper.getValidateInEnumSelect(page.wan_interfaces)

if interfaces and validate_interface(interfaces) then
  proxy.set("rpc.datausage_notifier.web_selected_interface", interfaces)
else
  interfaces = untaint(proxy.get("rpc.datausage_notifier.web_selected_interface")[1].value)
end
page.datausage_interface = interfaces

local function get_datausage_section(interface)
  add_datausage_interface(interface)

  local datausage_units = {
    { "MB", T'MB'},
    { "GB", T'GB'}
  }

  local mapParams = {
    datausage_cycle_reset_day = "uci.datausage.interface.@" .. interface .. ".usage_cycle_reset_day",
    datausage_monitor_enabled = "uci.datausage.interface.@" .. interface .. ".enabled",
    datausage_limit_enabled = "uci.datausage.interface.@" .. interface .. ".usage_limit_enabled",
    datausage_threshold_enabled = "uci.datausage.interface.@" .. interface .. ".usage_threshold_enabled",
    datausage_limit_unit = "uci.datausage.interface.@" .. interface .. ".usage_limit_unit",
    datausage_threshold_unit = "uci.datausage.interface.@" .. interface .. ".usage_threshold_unit",
    datausage_limit = "uci.datausage.interface.@" .. interface .. ".usage_limit",
    datausage_threshold = "uci.datausage.interface.@" .. interface .. ".usage_threshold"

  }
  local mapValid = {
    datausage_cycle_reset_day = validate_reset_day,
    datausage_monitor_enabled = post_helper.validateBoolean,
    datausage_limit_enabled = post_helper.validateBoolean,
    datausage_threshold_enabled = post_helper.validateBoolean,
    datausage_limit_unit = post_helper.getValidateInEnumSelect(datausage_units),
    datausage_threshold_unit = post_helper.getValidateInEnumSelect(datausage_units),
    datausage_limit = validate_data_limit,
    datausage_threshold = validate_data_limit

  }

  local helpmsg
  page.content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
  setmetatable(page.content, { __index = function() return "" end })

  if page.content["datausage_monitor_enabled"] == "" then
    page.content["datausage_monitor_enabled"] = '1'
  end

  if page.content["datausage_limit_unit"] == "" then
    page.content["datausage_limit_unit"] = 'GB'
  end

  if page.content["datausage_threshold_unit"] == "" then
    page.content["datausage_threshold_unit"] = 'GB'
  end

  if page.content["datausage_limit"] == "" then
    page.content["datausage_limit"] = '1'
  end

  if page.content["datausage_threshold"] == "" then
    page.content["datausage_threshold"] = '1'
  end

  local html = {}
  tinsert(html, "<fieldset><legend>" .. T"Monitoring" .. "</legend>")
  tinsert(html, ui_helper.createMessages(message_helper.popMessages()))
  local interface_class = {
    select = {
      class="no-save"
    }
  }
  tinsert(html, ui_helper.createInputSelect(T"Network Interface", "selected_interface", page.wan_interfaces, page.datausage_interface, interface_class))

  tinsert(html, ui_helper.createSwitch(T"Data Usage Monitoring", "datausage_monitor_enabled", page.content["datausage_monitor_enabled"]))
  tinsert(html, '<div data-bind="visible: dataUsageEnabled() == true">')

  tinsert(html, '<table id="datausage"><tr><th></th><th>' .. T"Uplink" .. '</th><td rowspan="3" style="background-repeat: no-repeat;" class="datausage_image"></td><th>' .. T"Downlink" .. '</th></tr>')
  tinsert(html, '<tr><td class="control-label datausage_header" style="width:60px;">' .. T"Current" .. '</td><td data-bind="text: txBitRate" class="datausage"></td><td data-bind="text: rxBitRate" class="datausage"></td></tr>')
  tinsert(html, '<tr><td class="control-label datausage_header" style="width:60px;">' .. T"Total" .. '</td><td data-bind="text: txVolumeTotal" class="datausage"></td><td data-bind="text: rxVolumeTotal" class="datausage"></td></tr></table>')
  tinsert(html, '<div class="control-group"><label class="control-label">' .. T"Total Volume" .. ': </label><div class="controls"><span class= "span2 simple-desc" data-bind="text: volumeTotal"></span></div></div>')
  tinsert(html, "<legend>" .. T"Limits" .. "</legend>")
  local datausage_cycle_reset_day_settings = {
    input = {
      style = "width:30px;text-align: center;"
    }
  }
  tinsert(html, ui_helper.createInputText(T"Monthly Reset Day" .. ":", "datausage_cycle_reset_day", page.content["datausage_cycle_reset_day"], datausage_cycle_reset_day_settings, helpmsg["datausage_cycle_reset_day"]))
  tinsert(html, ui_helper.createSwitch(T"Enable Warning", "datausage_threshold_enabled", page.content["datausage_threshold_enabled"]))
  tinsert(html, '<div data-bind="visible: dataUsageThresholdEnabled() == true">')
  local limit_settings = {
    group = {
      class = "float-left"
    },
    controls = {
      style = "width:95px;"
    },
    input = {
      style = "width:80px;text-align: right;"
    }
  }
  tinsert(html, ui_helper.createInputText(T"Data Usage Warning" .. ":", "datausage_threshold", page.content["datausage_threshold"], limit_settings, helpmsg["datausage_threshold"]))
  limit_settings = {
    label = {
      class = "hidden"
    },
    select = {
      style = "width:55px;"
    }
  }
  tinsert(html, ui_helper.createInputSelect(T"", "datausage_threshold_unit", datausage_units, page.content["datausage_threshold_unit"], limit_settings))
  local datausage_threshold_reached = {
    alert = {
      class = "alert-warning hide",
      id = "datausage-threshold-reached-msg"
    }
  }
  tinsert(html, ui_helper.createAlertBlock(T"Data usage threshold reached", datausage_threshold_reached))
  tinsert(html, '</div>')

  tinsert(html, ui_helper.createSwitch(T"Enable Limit", "datausage_limit_enabled", page.content["datausage_limit_enabled"]))
  tinsert(html, '<div data-bind="visible: dataUsageLimitEnabled() == true">')
  limit_settings = {
    group = {
      class = "float-left"
    },
    controls = {
      style = "width:95px;"
    },
    input = {
      style = "width:80px;text-align: right;"
    }
  }
  tinsert(html, ui_helper.createInputText(T"Data Usage Limit" .. ":", "datausage_limit", page.content["datausage_limit"], limit_settings, helpmsg["datausage_limit"]))
  limit_settings = {
    label = {
      class = "hidden"
    },
    select = {
      style = "width:55px;"
    }
  }
  tinsert(html, ui_helper.createInputSelect(T"", "datausage_limit_unit", datausage_units, page.content["datausage_limit_unit"], limit_settings))
  local datausage_limit_reached = {
    alert = {
      class = "alert-error hide",
      id = "datausage-limit-reached-msg"
    }
  }
  tinsert(html, ui_helper.createAlertBlock(T"Data usage limit reached", datausage_limit_reached))
  tinsert(html, '</div>')

  if sms_sending_supported() then
    add_sms_notification(page.sms_message, page.datausage_interface)
    local mapParams = {}
    local mapValid = {}
    local path = string.format("uci.datausage_notifier.action.@send_sms_%s.", page.datausage_interface)
    mapParams["sms_notification_enabled"] = path .. "enabled"
    mapValid["sms_notification_enabled"] = post_helper.validateBoolean
    local content = post_helper.handleQuery(mapParams, mapValid)
    setmetatable(content, { __index = function() return "" end })

    tinsert(html, ui_helper.createSwitch(T"SMS Notification", "sms_notification_enabled", content["sms_notification_enabled"]))

    local table_columns = {
      {
        header = T"Number",
        name = "number",
        param = "value",
        type = "text",
        unique = true,
        attr = { input = { class="span2", maxlength="127" } }
      }
    }
    local table_options = {
      tableid = "sms_numbers_" .. page.datausage_interface,
      basepath = path .. "numbers.@.",
      canAdd = true,
      canDelete = true,
      createMsg = T"Add number"
    }
    local number_valid = {
      ["number"] = post_helper.getValidateStringLengthInRange(1, 20)
    }
    local table_data, table_helpmsg = post_helper.handleTableQuery(table_columns, table_options, nil, nil, number_valid)
    table.insert(html, ui_helper.createTable(table_columns, table_data, table_options, nil, table_helpmsg))
  end

  local button_class = {
    button = {
      class = "custom-handler"
    }
  }
  button_class.button.id = "btn-reset-datausage"
  tinsert(html, ui_helper.createButton(T"Reset Data Usage", T"Reset", "icon-refresh", button_class))
  tinsert(html, '<div class="alert alert-info">' .. T"* Data usage is only an approximation. For actual usage, please refer to your network operator" .. '</div>')
  tinsert(html, '</div></fieldset>')
  ngx.print(html)
end
  ngx.print('\
\
<style>\
  .uneven {\
    background-color: #eee;\
  }\
  .selectable {\
    cursor: pointer;\
    cursor: hand;\
  }\
  .selectable:hover {\
    background-color: #aaa;\
  }\
  .currentplmn {\
    background-color: #5d215d;\
    color: #fff;\
  }\
  #scanresults {\
    margin-bottom: 15px;\
  }\
  .scanresult {\
    border-bottom: 1px solid #aaa;\
    line-height: 30px;\
  }\
  .scanresult-title {\
    font-weight: bold;\
    border-bottom: 2px solid #888;\
  }\
  .img-center {\
    margin: 0 auto;\
    display: block;\
  }\
  .waiting-msg {\
    color: #777;\
  }\
  .float-left {\
    float: left;\
    margin-right: 5px;\
  }\
  .datausage_image {\
    background: url("img/datausage-updown.png");\
    height: 128px;\
    width:128px;\
  }\
  .datausage, .datausage_header {\
    font-size:28px;\
    width:165px;\
    margin-top:50px;\
    color:#3a87ad;\
    text-align:center;\
  }\
  .datausage_header {\
    margin: 0;\
    padding-top: 15px !important;\
    width: 80px !important;\
    font-size: 20px;\
  }\
  #datausage th {\
    font-size: 20px;\
  }\
  .help-inline {\
    min-width: 350px;\
  }\
</style>\
\
');  ngx.print( ui_helper.createHeader(T"Data Usage", false, true) ); ngx.print('\
<div class="modal-body update" id="datausage-body">\
  <form class="form-horizontal" method="post" action="modals/datausage.lp">\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    get_datausage_section(page.datausage_interface)
      ngx.print('\
  </form>\
</div>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
\
<script>\
  var id = window.setTimeout(function() {}, 0);\
  while (id--) {\
    window.clearTimeout(id);\
  }\
\
  ko.cleanNode(document.getElementById(\'datausage-body\'));\
\
  function getDataUsage() {\
    dataUsageModal.getDataUsage();\
  }\
\
  function get_data_volume(val) {\
    if(val > 1024*1024*1024) {\
      val /= 1024*1024*1024;\
      val = val.toFixed(1);\
      return val + " GB";\
    } else if(val > 1024*1024) {\
      val /= 1024*1024;\
      val = val.toFixed(1);\
      return val + " MB";\
    } else if(val > 1024) {\
      val /= 1024;\
      val = val.toFixed(1);\
      return val + " KB";\
    }\
    return val + " B"\
  }\
\
  var DataUsageModal = function () {\
    var self = this;\
    this.dataUsageLimitEnabled = ko.observable(false);\
    this.dataUsageThresholdEnabled = ko.observable(false);\
    this.dataUsageEnabled = ko.observable(false);\
    this.txBytes = ko.observable(0);\
    this.rxBytes = ko.observable(0);\
    this.txBitRate = ko.computed(function() {\
      return get_bitrate(this.txBytes());\
    }, this);\
    this.rxBitRate = ko.computed(function() {\
      return get_bitrate(this.rxBytes());\
    }, this);\
    this.txBytesTotal = ko.observable(0);\
    this.rxBytesTotal = ko.observable(0);\
    this.txVolumeTotal = ko.computed(function() {\
      return get_data_volume(this.txBytesTotal());\
    }, this);\
    this.rxVolumeTotal = ko.computed(function() {\
      return get_data_volume(this.rxBytesTotal());\
    }, this);\
    this.bytesTotal = ko.computed(function() {\
      return parseInt(this.txBytesTotal()) + parseInt(this.rxBytesTotal());\
    }, this);\
    this.volumeTotal = ko.computed(function() {\
      return get_data_volume(this.bytesTotal());\
    }, this);\
    this.getDataUsage = function() {\
      var params = [ { name: \'action\', value: "get" },\
        { name: \'interface\', value: "');  ngx.print( page.datausage_interface or "" ); ngx.print('" },\
						tch.elementCSRFtoken() ];\
      $.post("/ajax/datausage.lua?auto_update=true", params, function(datausage) {\
        self.txBytes(datausage.tx_bytes_average || 0);\
        self.rxBytes(datausage.rx_bytes_average || 0);\
        self.txBytesTotal(datausage.tx_bytes_total || 0);\
        self.rxBytesTotal(datausage.rx_bytes_total || 0);\
        if(datausage.usage_limit_reached == "true") {\
          $(\'#datausage-limit-reached-msg\').removeClass(\'hide\');\
        } else {\
          $(\'#datausage-limit-reached-msg\').addClass(\'hide\');\
        }\
        if(datausage.usage_threshold_reached == "true") {\
          $(\'#datausage-threshold-reached-msg\').removeClass(\'hide\');\
        } else {\
          $(\'#datausage-threshold-reached-msg\').addClass(\'hide\');\
        }\
      }, "json");\
    }\
    this.resetDataUsage = function() {\
      var params = [{ name: "action", value: "reset"},\
        { name: \'interface\', value: "');  ngx.print( page.datausage_interface or "" ); ngx.print('" },\
						tch.elementCSRFtoken()];\
      $.post("/ajax/datausage.lua", params, function(data) {}, \'json\');\
    };\
    $("#btn-reset-datausage").click(function() {\
      self.resetDataUsage();\
    });\
    this.startDatausageMonitor = function() {\
      if(self.dataUsageTimer == undefined) {\
        getDataUsage();\
        self.dataUsageTimer = setInterval(getDataUsage, (3*1000));\
      }\
    };\
    this.stopDatausageMonitor = function() {\
      if(self.dataUsageTimer) {\
        clearInterval(self.dataUsageTimer);\
        self.dataUsageTimer = undefined;\
      }\
    };\
  };\
\
  var dataUsageModal = new DataUsageModal();\
  ko.applyBindings(dataUsageModal, document.getElementById(\'datausage-body\'));\
  if($("#datausage_limit_enabled").val() == \'1\') {\
    dataUsageModal.dataUsageLimitEnabled(true);\
  }\
\
  if($("#datausage_threshold_enabled").val() == \'1\') {\
    dataUsageModal.dataUsageThresholdEnabled(true);\
  }\
\
  if($("#datausage_monitor_enabled").val() == \'1\') {\
    dataUsageModal.dataUsageEnabled(true);\
    dataUsageModal.startDatausageMonitor();\
  }\
\
  $("#datausage_limit_enabled").change(function() {\
    if($(this).val() == \'1\') {\
      dataUsageModal.dataUsageLimitEnabled(true);\
    } else {\
      dataUsageModal.dataUsageLimitEnabled(false);\
    }\
  });\
\
  $("#datausage_threshold_enabled").change(function() {\
    if($(this).val() == \'1\') {\
      dataUsageModal.dataUsageThresholdEnabled(true);\
    } else {\
      dataUsageModal.dataUsageThresholdEnabled(false);\
    }\
  });\
\
  $("#datausage_monitor_enabled").change(function() {\
    if($(this).val() == \'1\') {\
      dataUsageModal.dataUsageEnabled(true);\
      dataUsageModal.startDatausageMonitor();\
    } else {\
      dataUsageModal.dataUsageEnabled(false);\
      dataUsageModal.stopDatausageMonitor();\
    }\
  });\
\
  $("#selected_interface").change(function() {\
    tch.loadModal("/modals/datausage.lp?selected_interface=" + encodeURIComponent($(this).val()));\
  });\
</script>\
'); 