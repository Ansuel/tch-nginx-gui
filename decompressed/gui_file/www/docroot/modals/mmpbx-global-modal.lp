--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-voice')

local tinsert = table.insert
local ngx = ngx
local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local uimessage_helper = require("web.uimessage_helper")
local format = string.format
local session = ngx.ctx.session
local content_helper = require("web.content_helper")
local mapValid = {
    mmpbx_enabled = post_helper.validateBoolean,
}

local mapParams = {
    mmpbx_enabled = "uci.mmpbx.mmpbx.@global.enabled",
}

local voip_password_profile_1 = "uci.mmpbxrvsipnet.profile.@sip_profile_0.password"
local voip_password_profile_2 = "uci.mmpbxrvsipnet.profile.@sip_profile_1.password"
local voip_password_profile_3 = "uci.mmpbxrvsipnet.profile.@sip_profile_2.password"

if proxy.get(voip_password_profile_1) and proxy.get(voip_password_profile_1)[1].value then
	voip_password_profile_1 = proxy.get(voip_password_profile_1)[1].value
else
	voip_password_profile_1 = nil
end

if proxy.get(voip_password_profile_2) and proxy.get(voip_password_profile_2)[1].value then
	voip_password_profile_2 = proxy.get(voip_password_profile_2)[1].value
else
	voip_password_profile_2 = nil
end

if proxy.get(voip_password_profile_3) and proxy.get(voip_password_profile_3)[1].value then
	voip_password_profile_3 = proxy.get(voip_password_profile_3)[1].value
else
	voip_password_profile_3 = nil
end

local variant = proxy.get("uci.env.var.prod_friendly_name")[1].value or ""

-- Retrieving emission state
local emission_content = {
    emission_state = "rpc.mmpbx.dectemission.state",
}
content_helper.getExactContent(emission_content)
emission_state = format("%s", emission_content.emission_state)


local content = post_helper.handleQuery(mapParams, mapValid)
if ngx.req.get_method() == "POST" then
     local args = ngx.req.get_post_args()
     local action = args["action"]
     if action == "emission_on" then
	   proxy.set("rpc.mmpbx.dectemission.state","1")
     end
     if action == "emission_off" then
	   proxy.set("rpc.mmpbx.dectemission.state","0")
     end
     proxy.apply()
end
-- SIP Networks
local sipnet_columns = {
  {
    header = T"Name",
    name = "user_friendly_name",
    param = "user_friendly_name",
    type = "label",
    readonly = true,
    attr = { input = { class="span2" }},
  },
  {
    header = T"Primary Registrar",
    name = "primaryRegistrar",
    param = "primary_registrar",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Domain Name",
    name = "DomainName",
    param = "domain_name",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Realm",
    name = "realm",
    param = "realm",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Primary RegistrarPort",
    name = "primaryRegistrarPort",
    param = "primary_registrar_port",
    type = "text",
    attr = { input = { class="span1" } },
  },
  {
    header = T"Primary Proxy",
    name = "primaryProxy",
    param = "primary_proxy",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Primary ProxyPort",
    name = "primaryProxyPort",
    param = "primary_proxy_port",
    type = "text",
    attr = { input = { class="span1" } },
  },
  {
    header = T"Expire Time",
    name = "regExpire",
    param = "reg_expire",
    type = "text",
    attr = { input = { class="span1" } },
  },
}

local sipnet_valid = {
    primaryRegistrarPort = post_helper.validateStringIsPort,
    primaryRegistrar = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
	DomainName = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
	realm = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
    primaryProxy = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
    primaryProxyPort = post_helper.getValidateNumberInRange(0,65535),
    regExpire = post_helper.validateRegExpire,
}

local sipnet_options = {
    canEdit = true,
    canAdd = false,
    canDelete = false,
    tableid = "sipnet",
    basepath = "uci.mmpbxrvsipnet.network.",
    sorted = "user_friendly_name",
}

local sipnet_data, sipnet_helpmsg = post_helper.handleTableQuery(sipnet_columns, sipnet_options, nil, nil, sipnet_valid)

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end


ngx.print(ui_helper.createHeader(T"Telephony", false, true));
ngx.print('\
<div class="modal-body update">\
  ');
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="');ngx.print(uri); ngx.print('">'); ngx.print(
  ui_helper.createMessages(uimessage_helper.popMessages()));
	local html = {}

	local emission_on_class = {
	  		button = {
	  			["data-name"] = "action",
	  			["data-value"] = "emission_on",
	  		}
 	}
	local emission_off_class = {
		button = {
			["data-name"] = "action",
			["data-value"] = "emission_off",
		}
	}

	html[#html+1] = '<fieldset id="mmpbx-global-tab">'
	html[#html+1] =     '<legend>' .. T"Global Information" .. '</legend>'
	html[#html+1] =     ui_helper.createSwitch(T"Enabled", "mmpbx_enabled", content["mmpbx_enabled"])
	
	if voip_password_profile_1 and not ( voip_password_profile_1 == "") then
		html[#html+1] = 	ui_helper.createLabel(T"Voip Password Profile 1", voip_password_profile_1)
	end
	if voip_password_profile_2 and not ( voip_password_profile_2 == "") then
		html[#html+1] = 	ui_helper.createLabel(T"Voip Password Profile 2", voip_password_profile_2)
	end
	if voip_password_profile_3 and not ( voip_password_profile_3 == "") then
		html[#html+1] = 	ui_helper.createLabel(T"Voip Password Profile 3", voip_password_profile_3)
	end
	html[#html+1] = '</fieldset>'
    if content and content["mmpbx_enabled"] == "1" then
	  if session:hasAccess("/modals/mmpbx-dect-modal.lp") and 
		( variant == "Technicolor TG800vac" ) or ( variant == "Technicolor TG799vac" ) then
	    html[#html+1] = '<fieldset>'
        html[#html+1] = '<legend>' .. T"DECT Emission" .. '</legend>'
	    if emission_state == "0" then
	      html[#html+1] = ui_helper.createButton(T"Emission Mode", T"On", "icon-bolt", emission_on_class)
	    else
          html[#html+1] = ui_helper.createButton(T"Emission Mode", T"Off", "icon-ban-circle icon-large red", emission_off_class)
	    end

        html[#html+1] = '</fieldset>'
      end
      html[#html+1] = '<fieldset>'
      html[#html+1] = '<legend>' .. T"SIP Network" .. '</legend>'
      html[#html+1] =  ui_helper.createTable(sipnet_columns, sipnet_data, sipnet_options, nil, sipnet_helpmsg)
      html[#html+1] = '</fieldset>'
    end
	ngx.print (html)

	ngx.print('\
    </form>\
</div>\
'); ngx.print(
ui_helper.createFooter()
);
if content and content["mmpbx_enabled"] == "0" then
  ngx.print('\
  <style>\
    .disabled{\
       cursor:not-allowed !important;\
       color:#666;\
    }\
  </style>\
  <script>\
    $(".nav li a").addClass("disabled");\
  </script>\
  ');
else
  ngx.print('\
  <script>\
    if($(".nav li a").hasClass("disabled")){\
      $(".nav li a").removeClass("disabled");\
    }\
  </script>\
  ');
end