--pretranslated: do not change this file
 
--[[
Version 1.0 DHCP Relay Setup Page

  - Aloow direct configuration of the PPP Username and Password LAN IP and subnet and edit the DHCP Relay

]]
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local format,find,sub,untaint = string.format, string.find, string.sub, string.untaint
local floor, ipairs = math.floor, ipairs

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
  local action = ngx.req.get_post_args().action
  -- now process non-file POSTs
  if action == "system_reset" then
    return resetreboot("rpc.system.reset", "1")
  elseif action == "system_reboot" then
    return resetreboot("rpc.system.reboot", "GUI")
  end
end

local relay_Params = {
    uci_username = "uci.network.interface.@wan.username",
    uci_password = "uci.network.interface.@wan.password",
    uci_relay_status = "uci.dhcprelay.config.enabled",
    uci_relay_ip = "uci.dhcprelay.config.serverip",
    uci_lan_ip = "uci.network.interface.@lan.ipaddr",
    uci_lan_mask = "uci.network.interface.@lan.netmask",
}

local gCV = post_helper.getConditionalValidation
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSIP = post_helper.validateStringIsPort
local gVP = post_helper.getValidationPassword
local gOV = post_helper.getOptionalValidation
local aIPV = post_helper.advancedIPValidation
local vIP4N = post_helper.validateIPv4Netmask


local function validateUsername (value, postdata)
  local err,msg = vNES(value)
  if not err then
    return err,msg
  end

  local content_uci = {
    wan_domain = "uci.network.interface.@wan.domain",
  }
  content_helper.getExactContent(content_uci)

  if content_uci["wan_domain"] ~= "" then
    if string.find(value, "@") then
      return nil, T"Invalid username, domain locked"
    end
    postdata["uci_wan_username"] = format('%s@%s', value, content_uci["wan_domain"])
  end
  return true
end

local relay_valid = {
    uci_username = gCV(validateUsername, gOV(validateUsername)),
    uci_password = gCV(gVP(vNES), gVP()),
    uci_relay_status = vB,
    uci_relay_ip = aIPV,
    uci_lan_ip = aIPV,
    uci_lan_mask = vIP4N,
}

local relay_Values, helpmsg = post_helper.handleQuery(relay_Params, relay_valid)
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
  <legend>');  ngx.print( T"PPP" ); ngx.print('</legend>\
\
    ');  
    html = {}
    -- PPP username
    local class_username = {
      input = {
        maxlength= "128",
        class = "span6",
      }
    }
    html[#html + 1] = format("<div class='control-group'><label class='control-label'>%s</label><div class='controls'>",T"Username")
    html[#html + 1] = ui_helper.createSimpleInputText("uci_username", relay_Values["uci_username"], class_username, helpmsg["uci_username"])
    html[#html + 1] = [[</div></div>]]

    -- PPP password
    local class_password = class_username
    html[#html + 1] = ui_helper.createInputPassword(T"Password", "uci_password", relay_Values["uci_password"], class_username, helpmsg["uci_password"])
    ngx.print(html)
      ngx.print('\
\
</fieldset>\
<fieldset>\
  <legend>');  ngx.print( T"LAN" ); ngx.print('</legend>\
       ');  
         local html = {}
         html[#html + 1] = ui_helper.createInputText(T"IP Address", "uci_lan_ip", relay_Values["uci_lan_ip"],{},helpmsg["uci_lan_ip"])
         html[#html + 1] = ui_helper.createInputText(T"Subnet Mask", "uci_lan_mask", relay_Values["uci_lan_mask"], nil, helpmsg["uci_lan_mask"])
         ngx.print(html)

         ngx.print('\
\
</fieldset>\
<fieldset>\
  <legend>');  ngx.print( T"DHCP Relay" ); ngx.print('</legend>\
       ');  
         local html = {}
         html[#html + 1] = ui_helper.createSwitch(T"Enabled", "uci_relay_status", relay_Values["uci_relay_status"])
         html[#html + 1] = ui_helper.createInputText(T"Relay IP", "uci_relay_ip", relay_Values["uci_relay_ip"], nil, helpmsg["uci_relay_ip"])
         local Relay_Warn = {
          alert = {
                  class = "alert-warning"
          },
        }
         html[#html + 1] = ui_helper.createAlertBlock(T"When changing any parameters in this section you will need to reboot the Router to make the changes take effect",  Relay_Warn)

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