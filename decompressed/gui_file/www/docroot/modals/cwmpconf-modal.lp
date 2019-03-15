--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local format = string.format

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local gVP = post_helper.getValidationPassword
local gRV = post_helper.getOrValidation
local gVSLIR = post_helper.getValidateStringLengthInRange(1,255)
local gAV = post_helper.getAndValidation
local gVNIR = post_helper.getValidateNumberInRange
local gVWN   = post_helper.getValidateWholeNumber

local mapParams = {
      cwmp_url              = "uci.cwmpd.cwmpd_config.acs_url",
      cwmp_state            = "uci.cwmpd.cwmpd_config.state",
	  cwmp_periodic_enable  = "uci.cwmpd.cwmpd_config.periodicinform_enable",
      cwmp_periodic         = "uci.cwmpd.cwmpd_config.periodicinform_interval",
      connectionrequest_auth= "uci.cwmpd.cwmpd_config.connectionrequest_auth",
      cwmp_acs_user         = "uci.cwmpd.cwmpd_config.acs_user",
      cwmp_acs_pass         = "uci.cwmpd.cwmpd_config.acs_pass",
      connectionrequest_user= "uci.cwmpd.cwmpd_config.connectionrequest_username",
      connectionrequest_pass= "uci.cwmpd.cwmpd_config.connectionrequest_password",
      --[[ Note: if you add parameter connectionrequest_port, please change deny_cwmp.ext_ports
         in /etc/config/upnpd at the same time, for details please check NG-78919.
        connectionrequest_port = "uci.cwmpd.cwmpd_config.connectionrequest_port",
      ]]
      ip_preference         = "uci.cwmpd.cwmpd_config.ip_preference"
}

local conreqauth_select = {
      { "0", T'None'},
      { "1", T'Basic'},
      { "2", T'Digest'}
}

local ip_preference_select = {
      { "v4_only", T'IPv4 Only'},
      { "v6_only", T'IPv6 Only'},
      { "prefer_v4", T'Prefer IPv4'},
      { "prefer_v6", T'Prefer IPv6'}
}

-- function that can be used to validate connectionrequest user/pass for auth mode selected as None
-- @param #value have the value of corresponding key
-- @param #object have the POST data
-- @return #boolean or nil
local function validateConnReqNone(value, object)
   if object["connectionrequest_auth"] == "0" then
      return true
   end
   return nil
end
-- validate the user name and Url
local function validateUserUrl(value, object)
   if object.cwmp_state ~= "1" then
      return false
   else
      return gVSLIR(value)
   end
end
-- validate the password
local function validatePass(value, object, key)
   if object.cwmp_state ~= "1" then
      return false
   else
      return gVP(gVSLIR)(value, object, key)
   end
end

local mapvalid = {
      cwmp_url                    = validateUserUrl,
      cwmp_acs_user               = validateUserUrl,
      cwmp_acs_pass               = validatePass,
      cwmp_state                  = post_helper.validateBoolean,
	  cwmp_periodic_enable		  = post_helper.validateBoolean,
      cwmp_periodic               = gAV(gVWN, gVNIR(10, 300000)),
      connectionrequest_auth      = post_helper.getValidateInEnumSelect(conreqauth_select),
      connectionrequest_user      = gRV(validateConnReqNone, gVSLIR),
      connectionrequest_pass      = gRV(validateConnReqNone, gVP(gVSLIR)),
      ip_preference               = post_helper.getValidateInEnumSelect(ip_preference_select)
}
local post_url = proxy.get(mapParams["cwmp_url"])[1].value
local post_user = proxy.get(mapParams["cwmp_acs_user"])[1].value
local post_pass = proxy.get(mapParams["cwmp_acs_pass"])[1].value

local content, helpmsg = post_helper.handleQuery(mapParams, mapvalid)
local conreqauthclass = {
   group = {
      class ="monitor-connectionrequest_auth monitor-1 monitor-2",
   }
}

if ngx.var.request_method == "POST" then
   local post_content = ngx.req.get_post_args()
   if post_content["action"] == "SAVE" and post_content["connectionrequest_auth"] == "0" then
      mapParams.connectionrequest_user = nil
      mapParams.connectionrequest_pass = nil
   end
   if post_content["cwmp_state"] == "0" then
      proxy.set({["uci.cwmpd.cwmpd_config.acs_url"] = post_url,
                 ["uci.cwmpd.cwmpd_config.acs_user"] = post_user,
                 ["uci.cwmpd.cwmpd_config.acs_pass"] = post_pass })
      proxy.apply()
   end
end

  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"CWMP Settings", false, true) ); ngx.print('\
<div class="modal-body update">\
    <form class="form-horizontal" method="post" action="modals/cwmpconf-modal.lp">\
        <fieldset>\
            ');  local numbersOnly = {
                  input = {
                      pattern = "[0-9]{2,6}",
                      maxlength = "6",
                  }
              }
              ngx.print(ui_helper.createMessages(message_helper.popMessages()))
              local html = {}
              local switch_class_enable = {
                input = {
                  class = "monitor-changes",
                }
              }
              html[#html + 1] = ui_helper.createSwitch(T"Enabled", "cwmp_state", content["cwmp_state"],switch_class_enable)
              local cwmpinput = {
                group = {
                  class ="monitor-cwmp_state monitor-1",
                },
                input = {
                  maxlength= "255",
                  class = "span2",
                },
                span = {                                                       
                  class = "span4"  
                } 
              }
              if content["cwmp_state"] == "0" then
                 html[#html+1] = ui_helper.createInputText(T"ACS URL", "cwmp_url", post_url, cwmpinput, helpmsg["cwmp_url"])
                 html[#html+1] = ui_helper.createInputText(T"ACS Username", "cwmp_acs_user", post_user, cwmpinput, helpmsg["cwmp_acs_user"])
                 html[#html+1] = ui_helper.createInputPassword(T"ACS Password", "cwmp_acs_pass", post_pass, cwmpinput, helpmsg["cwmp_acs_pass"])
              else
                 html[#html+1] = ui_helper.createInputText(T"ACS URL", "cwmp_url", content["cwmp_url"], cwmpinput, helpmsg["cwmp_url"])
                 html[#html+1] = ui_helper.createInputText(T"ACS Username", "cwmp_acs_user", content["cwmp_acs_user"], cwmpinput, helpmsg["cwmp_acs_user"])
                 html[#html+1] = ui_helper.createInputPassword(T"ACS Password", "cwmp_acs_pass", content["cwmp_acs_pass"], cwmpinput, helpmsg["cwmp_acs_pass"])
              end
			  html[#html + 1] = ui_helper.createSwitch(T"Periodic Inform", "cwmp_periodic_enable", content["cwmp_periodic_enable"])
              html[#html+1] = ui_helper.createInputText(T"Periodic Interval", "cwmp_periodic", content["cwmp_periodic"], numbersOnly, helpmsg["cwmp_periodic"])
              html[#html+1] = ui_helper.createInputSelect(T"Connection Request Auth", "connectionrequest_auth", conreqauth_select, content["connectionrequest_auth"], {select={class="monitor-changes"}})
              html[#html+1] = ui_helper.createInputText(T"Connection Request Username", "connectionrequest_user", content["connectionrequest_user"], conreqauthclass, helpmsg["connectionrequest_user"])
              html[#html+1] = ui_helper.createInputPassword(T"Connection Request Password", "connectionrequest_pass", content["connectionrequest_pass"], conreqauthclass, helpmsg["connectionrequest_pass"])
              html[#html+1] = ui_helper.createInputSelect(T"IPv4/IPv6", "ip_preference", ip_preference_select, content["ip_preference"])
              ngx.print(html)
              ngx.print('\
        </fieldset>\
    </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 
