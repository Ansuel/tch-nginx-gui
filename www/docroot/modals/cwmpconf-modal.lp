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
}

local conreqauth_select = {
      { "0", T'None'},
      { "1", T'Basic'},
      { "2", T'Digest'},
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

local mapvalid = {
      cwmp_url                    = gVSLIR,
      cwmp_acs_user               = gVSLIR,
      cwmp_acs_pass               = gVP(gVSLIR),
      cwmp_state                  = post_helper.validateBoolean,
	  cwmp_periodic_enable		  = post_helper.validateBoolean,
      cwmp_periodic               = post_helper.getValidateNumberInRange(10, 300000),
      connectionrequest_auth      = post_helper.getValidateInEnumSelect(conreqauth_select),
      connectionrequest_user      = gRV(validateConnReqNone, gVSLIR),
      connectionrequest_pass      = gRV(validateConnReqNone, gVP(gVSLIR)),
}

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
end

local content, helpmsg = post_helper.handleQuery(mapParams, mapvalid)

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
              ngx.print(
                ui_helper.createMessages(message_helper.popMessages()),
                ui_helper.createSwitch(T"Enabled", "cwmp_state", content["cwmp_state"]),
                ui_helper.createInputText(T"ACS URL", "cwmp_url", content["cwmp_url"],{},helpmsg["cwmp_url"]),
                ui_helper.createInputText(T"ACS Username", "cwmp_acs_user", content["cwmp_acs_user"],{},helpmsg["cwmp_acs_user"]),
                ui_helper.createInputPassword(T"ACS Password", "cwmp_acs_pass", content["cwmp_acs_pass"],{},helpmsg["cwmp_acs_pass"]),
				ui_helper.createSwitch(T"Periodic Inform", "cwmp_periodic_enable", content["cwmp_periodic_enable"]),
                ui_helper.createInputText(T"Periodic Interval", "cwmp_periodic", content["cwmp_periodic"],numbersOnly,helpmsg["cwmp_periodic"]),
                ui_helper.createInputSelect(T"Connection Request Auth", "connectionrequest_auth", conreqauth_select, content["connectionrequest_auth"],{select={class="monitor-changes"}}),
                ui_helper.createInputText(T"Connection Request Username", "connectionrequest_user", content["connectionrequest_user"],conreqauthclass,helpmsg["connectionrequest_user"]),
                ui_helper.createInputPassword(T"Connection Request Password", "connectionrequest_pass", content["connectionrequest_pass"],conreqauthclass,helpmsg["connectionrequest_pass"])
              )
              ngx.print('\
        </fieldset>\
    </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 