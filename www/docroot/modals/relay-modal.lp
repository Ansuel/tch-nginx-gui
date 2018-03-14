--pretranslated: do not change this file
 
--[[
Version 1.0 DHCP Relay Setup Page

  - Allow direct configuration of DHCP Relay

]]
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local valEnumSel = post_helper.getValidateInEnumSelect
local format, match = string.format, string.match

local function resetreboot(path,value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" then
  local setIPValues = {}
  if ngx.req.get_post_args().uci_relay_status == "0" then
    setIPValues["uci.dhcp.relay.@relay.server_addr"] = ""
    setIPValues["uci.dhcp.relay.@relay.local_addr"] = ""
    setIPValues["uci.dhcp.relay.@relay.interface"] = ""
    proxy.del("uci.dhcp.relaybackup.")
    proxy.add("uci.dhcp.relaybackup.", post_helper.getRandomKey())
    proxy.set(setIPValues)
  else
    proxy.del("uci.dhcp.relaybackup.")
  end
  proxy.apply()
  local action = ngx.req.get_post_args().action
  -- now process non-file POSTs
  if action == "system_reset" then
    return resetreboot("rpc.system.reset", "1")
  elseif action == "system_reboot" then
    return resetreboot("rpc.system.reboot", "GUI")
  end
end

local uci_relay_status = "0"

local relay_Params = {
    uci_relay_server_ip = "uci.dhcp.relay.@relay.server_addr",
    uci_relay_local_ip  = "uci.dhcp.relay.@relay.local_addr",
    uci_relay_interface = "uci.dhcp.relay.@relay.interface"
}

local vSII = post_helper.validateStringIsIP
local aIPV = post_helper.advancedIPValidation
local pIPV = post_helper.isPublicIP
local gAV = post_helper.getAndValidation

--the [value] a valid IPv4 address
--the [value] is not the GW IP address
--the [value] is not the GW WAN IP address
--@return nil+error message
local function validateRelay(value, object, key)
  if vSII(value) then
    local ipaddr = proxy.get("rpc.network.interface.@lan.ipaddr")[1].value
    local wan_ipaddr = proxy.get("rpc.network.interface.@wan.ipaddr")[1].value
    if ipaddr == value then
       return nil, T"Cannot use the gateway IP address."
    end
    if wan_ipaddr == value then
       return nil, T"Cannot use the gateway WAN IP address."
    end
    --Adding localdevicemask in post to find the input is a network or broadcast IPv4 address in advancedIPValidation
    object["localdevmask"] = proxy.get("uci.network.interface.@lan.netmask")[1].value
    return true
  end
end

-- Description Function to get the list of wan interface Paths
-- @function getWanInterfacePath
-- @return table
local function getWanInterfacePath()
  local interfaceList = proxy.getPN("rpc.network.interface.", true)
  local wanIntfPaths = {}
  if interfaceList then
    for _,intf in ipairs(interfaceList) do
      local values = proxy.get(intf.path .. "type")
      if values ~= "" and values[1].value == "wan" then
        wanIntfPaths[#wanIntfPaths + 1] = values[1].path
      end
    end
  end
  return wanIntfPaths
end

local wanIntfPaths = getWanInterfacePath()
local wanData = content_helper.convertResultToObject("rpc.network.interface.", proxy.get(unpack(wanIntfPaths)))

local wanConInfo = {}
for _, data in ipairs(wanData) do
  if data.type == "wan" then
    wanConInfo[#wanConInfo + 1] = {}
    wanConInfo[#wanConInfo].interface = match(data.paramindex, "([%w%_]+)")
  end
end

local WanDetails = {}
for _, data in ipairs(wanConInfo) do
  if data.interface ~= "wan6" then
    WanDetails[#WanDetails + 1] = {
      data and data.interface,
      data and data.interface,
    }
  end
end

local relay_valid = {
  uci_relay_server_ip = gAV(validateRelay, aIPV),
  uci_relay_local_ip  = gAV(validateRelay, pIPV),
  uci_relay_interface = valEnumSel(WanDetails),
}

local function getRelayBackUpValues()
  local getBackUpValues = content_helper.convertResultToObject("uci.dhcp.relaybackup.", proxy.get("uci.dhcp.relaybackup."))
  if getBackUpValues and next(getBackUpValues) then
    for _, v in pairs(getBackUpValues) do
      relay_Params["uci_relay_server_ip"] = format("uci.dhcp.relaybackup.%s.server_addr", v.paramindex)
      relay_Params["uci_relay_local_ip"]  = format("uci.dhcp.relaybackup.%s.local_addr", v.paramindex)
      relay_Params["uci_relay_interface"] = format("uci.dhcp.relaybackup.%s.interface", v.paramindex)
    end
  end
end

if (ngx.req.get_method() == "POST" and  ngx.req.get_post_args().uci_relay_status == "0") then
  getRelayBackUpValues()
end

if proxy.get("uci.dhcp.relay.@relay.server_addr")[1].value == "" and proxy.get("uci.dhcp.relay.@relay.local_addr")[1].value == "" then
  getRelayBackUpValues()
end

local relay_Values, helpmsg = post_helper.handleQuery(relay_Params, relay_valid)
if proxy.get("uci.dhcp.relay.@relay.server_addr")[1].value ~= "" and proxy.get("uci.dhcp.relay.@relay.local_addr")[1].value ~= "" then
  uci_relay_status = "1"
end
local title = T"DHCP Relay Setup"
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(title, false, false))   ngx.print('\
<div class="modal-body update">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/relay-modal.lp">\
<fieldset>\
  <legend>');  ngx.print( T"DHCP Relay" ); ngx.print('</legend>\
       ');  
         local html = {}
         html[#html + 1] = ui_helper.createSwitch(T"Status", "uci_relay_status", uci_relay_status)
         html[#html + 1] = ui_helper.createInputText(T"Server IP", "uci_relay_server_ip", relay_Values["uci_relay_server_ip"], nil, helpmsg["uci_relay_server_ip"])
         html[#html + 1] = ui_helper.createInputText(T"Local IP", "uci_relay_local_ip", relay_Values["uci_relay_local_ip"], nil, helpmsg["uci_relay_local_ip"])
         html[#html + 1] = ui_helper.createInputSelect(T"Interface", "uci_relay_interface", WanDetails, relay_Values["uci_relay_interface"])
         ngx.print(html)
         ngx.print('\
\
</fieldset>\
<fieldset>\
  <legend>');  ngx.print( T"Quick Links" ); ngx.print('</legend>\
       ');  
        local wait_for_reboot = {
          group = {
            class = "wait-for-reboot"
          },
          button = {
            id = "btn-system-reboot",
            class = "custom-handler"
          }
        }

        local wait_for_reset = {
          group = {
            class = "wait-for-reset"
          },
          button = {
            id = "btn-system-reset",
            class = "custom-handler"
          }
        }
        local rebooting = {
        alert = {
          class = "alert hide",
          id = "rebooting-msg"
        }
      }
        local resetting = {
        alert = {
          class = "alert hide",
          id = "resetting-msg"
        }
      }
        local html = {}
        html[#html + 1] = ui_helper.createAlertBlock(T"Restarting, please wait...", rebooting)
        html[#html + 1] = ui_helper.createButton(T"Restart Device", T"Restart", "icon-refresh", wait_for_reboot)
        html[#html + 1] = ui_helper.createAlertBlock(T"Resetting to factory defaults, please wait...", resetting)
        html[#html + 1] = ui_helper.createButton(T"Factory Defaults", T"Reset", "icon-bolt", wait_for_reset)
        ngx.print(html)

         ngx.print('\
\
</fieldset>\
\
</form>\
</div>\
<script>\
(function() {\
  var refreshTimeOut = 5000;\
  var refreshDelay = 3000;\
  var target = $(".modal form").attr("action");\
\
  function wait_for_webserver_running() {\
    $.ajax({ url: target, timeout: refreshTimeOut, data: { check: "1"} })\
    .done(function(data) {\
      window.location.href = "/";\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
\
  function wait_for_webserver_down() {\
    $.ajax({ url: target, timeout: refreshTimeOut, data: { check: "1"}  })\
    .done(function() {\
      window.setTimeout(wait_for_webserver_down, refreshDelay);\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
  function resetreboot(msg, msg_dst, action) {\
    msg_dst.after(msg);\
    msg.removeClass("hide");\
    msg[0].scrollIntoView();\
    $.post(\
      target,\
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      wait_for_webserver_down,\
      "json"\
    );\
    return false;\
  }\
\
   $("#btn-system-reboot").click(function() {\
    return resetreboot($("#rebooting-msg"), $(this), "system_reboot");\
  });\
\
\
$("#btn-system-reset").click(function() {\
    return resetreboot($("#resetting-msg"), $(this), "system_reset");\
  });\
\
}());\
</script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 