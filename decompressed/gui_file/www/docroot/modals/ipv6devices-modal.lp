--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local string, ngx, os = string, ngx, os
local gmatch, match = string.gmatch, string.match
local gOrV = post_helper.getOrValidation
local vSIDN = post_helper.validateStringIsDomainName
local pattern = "^Unknown%-%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$"
local network = require("transformer.shared.common.network")
local untaint = string.untaint
local content_helper = require("web.content_helper")

local function validateUnknownHostname(value)
  return value:match(pattern)
end

-- devices forwarding rules
local devices_columns = {
  {--[1]
    header = T"Status",
    name = "state",
    param = "State",
    type = "light",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[2]
    header = T"Hostname",
    name = "FriendlyName",
    param = "FriendlyName",
    type = "text",
    attr = { input = { class="span3" } },
  },
  {--[3]
    header = T"IPv6 Global Addr",
    name = "ipv6",
    param = "IPv6",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[4]
    header = T"MAC address",
    name = "macaddress",
    param = "MACAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[5]
    header = T"Interface",
    name = "interfacetype",
    param = "L3Interface",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[6]
    header = T"IPv6 Link Local Addr",
    name = "ipv6linklocaladdress",
    param = "ipv6linklocaladdr",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[7]
    header = T"IPv6 Default Gateway",
    name = "ipv6defaultgateway",
    param = "ipv6defaultgateway",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
}

local device_valid = {
  FriendlyName = gOrV(vSIDN, validateUnknownHostname),
}

local devices_options = {
  canEdit = false,
  canAdd = false,
  canDelete = false,
  tableid = "devices",
  basepath = "rpc.hosts.host.",
}

--Construct the device ipv6 global and link local address
local devices_filter = function(data)
  --Display only the IPv6 devices
  if data["IPv6"] == "" then
    return false
  end

  local IPv6Details = {
    IPv6DefaultGW_lan    = "rpc.network.interface.@lan.ipv6uniqueglobaladdr",
  }
  content_helper.getExactContent(IPv6Details)
  data["ipv6defaultgateway"] = IPv6Details.IPv6DefaultGW_lan

  if data["L3Interface"] then
    local mac = untaint(data["MACAddress"])
    local cmd = "ip -6 neigh show | grep "..mac.." | grep fe80 "
    local output =  network.executeCommand(cmd)
    for i in gmatch(output, "%S+") do
      if match(i, "fe80*") then
        data["ipv6linklocaladdr"] = i
        return true
      else
        return false
      end
    end
  end
end

local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter , nil, device_valid)

  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Devices", false, true) ); ngx.print('\
<div class="modal-body update no-save">\
');  
if ngx.ctx.session:hasAccess("/modals/hostmap-modal.lp") then
  local tabs = {
    {
      desc = T"Devices List",
      target = "modals/device-modal.lp",
    },
    {
      desc = T"Devices Map",
      target = "modals/hostmap-modal.lp",
    },
    {
      desc = T"IPv6 Devices List",
      active = "active",
      target = "modals/ipv6devices-modal.lp",
    },
  }
  ngx.print(ui_helper.createModalTabs(tabs))
end
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/ipv6devices-modal.lp">\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
\
    <fieldset>\
      <legend>');  ngx.print( T"Devices" ); ngx.print('</legend>\
      ');  ngx.print( ui_helper.createTable(devices_columns, devices_data, devices_options, nil, devices_helpmsg) ); ngx.print('\
    </fieldset>\
  </form>\
</div>\
\
'); 