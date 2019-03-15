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
local format, untaint = string.format, string.untaint
local session = ngx.ctx.session
local content_helper = require("web.content_helper")

local uniqueKey = post_helper.getRandomKey()

local mapValid = {
    mmpbx_enabled = post_helper.validateBoolean,
}

local mapParams = {
    mmpbx_enabled = "uci.mmpbx.mmpbx.@global.enabled",
}

local content = post_helper.handleQuery(mapParams, mapValid)

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

-- SIP Networks
local sipnet_columns = {
    {
        header = T"Name",
        name = "user_friendly_name",
        param = "user_friendly_name",
        type = "text",
        unique = true,
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
        default = "5060",
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
        default = "0",
        attr = { input = { class="span1" } },
    },
    {
        header = T"Local Port",
        name = "localPort",
        param = "local_port",
        type = "text",
        unique = true,
        attr = { input = { class="span1" } },
    },
    {
        header = T"Expire Time",
        name = "regExpire",
        param = "reg_expire",
        type = "text",
        default = "3600",
        attr = { input = { class="span1" } },
    }
}

local gOV = post_helper.getOptionalValidation
local gOr = post_helper.getOrValidation

local sipnet_valid = {
    primaryRegistrarPort = post_helper.validateStringIsPort,
    primaryRegistrar = gOr(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
    DomainName = gOV(gOr(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName)),
    realm = gOV(gOr(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName)),
    primaryProxy = gOV(gOr(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName)),
    primaryProxyPort = post_helper.getValidateNumberInRange(0,65535),
    regExpire = post_helper.validateRegExpire,
}

local sipnet_default = {
    interface = "wan",
    cac = "-1",
    transparent_soc_transmission = "0",
    primary_proxy = "",
    secondary_proxy_port = "0",
    secondary_registrar_port = "5060",
    transport_type = "UDP",
    reg_expire = "3600",
    reg_expire_T_before = "1",
    reg_back_off_timeout = "180",
    realm_check = "0",
    --401_407_waiting_time = "0",
    dtmf_relay = "auto",
    dtmf_relay_translation = "0",
    timer_T1 = "500",
    timer_T2 = "4000",
    timer_T4 = "5000",
    timer_B = "32000",
    timer_D = "50000",
    timer_F = "32000",
    timer_J = "32000",
    provisional_timer = "180",
    --remote_hold_tone_enabled = "0",
    --sdp_direction_call_hold = "sendonly",
    --sdp_direction_call_hold_answer = "recvonly",
    uri_clir_format = "standard",
    privacy_handling = "apply",
    rejection_response = "486",
    no_answer_response = "480",
    call_waiting_provisional_response = "182",
    --call_waiting_alert_info = "0",
    call_waiting_reject_response = "486",
    reliable_provisional_response = "supported",
    re_registration_mode = "standard", -- ims
    forking_mode = "default",
    ingress_media_timeout = "1000",
    session_timer = "enabled",
    min_session_expires = "90",
    session_expires = "180",
    fail_behaviour = "stop",
    min_period_proxy_redundancy = "0",
    escape_hash = "1",
    escape_star = "0",
    control_qos_field = "dscp",
    control_qos_value = "ef",
    realtime_qos_field = "dscp",
    realtime_qos_value = "af42",
    --from_anonymous_handling = "withheld",
    --sip_over_ipv6 = "0",
    --include_sip_instance = "0",
    --waiting_time_for_registration_on_400_or_503_response = "300",
    --update_support = "1",
    --use_domain_in_contact = "0",
    --use_domain_in_via = "0",
    --sdp_direction_attribute_media_level_only = "0",
    --stick_to_outbound_proxy = "1",
    --registration_delay = "0",
    --enable_re_register_on_cancel_timeout = "0",
    rport_in_via = "1",
    --optimized_authentication = "0",
    --repeat_ringing_interval = "60",
    --re_register_on_403 = "0",
    --re_register_on_504 = "1",
    --check_ttl_for_dns_record = "0",
    --switch_next_proxy_on_failure_response = "0",
    --dns_query_timeout = "5000",
    switch_back_to_primary_proxy_timer = "0",
    --conference_release_call_after_transfer = "1",
    --disconnect_on_bye_response = "0",
    --dnd_response = "486",
    --hide_userinfo_and_port_in_subscription_request = "0",
    --cancel_invite_timer = "32000",
    --user_agent = "",-- MediaAccess TG789vac v2 Build 17.2.0278-0901
    primary_proxy_port = "0",
    primary_registrar = "",
    primary_registrar_port = "5060"
}

local function onAddVoice(current_section_index,content)

	if not content.primaryProxy or ( untaint(content.primaryProxy) == "" ) then
		proxy.set("uci.mmpbxrvsipnet.network.@"..current_section_index..".primary_proxy",untaint(content.primaryRegistrar))
	end
		
	proxy.add("uci.mmpbx.network.",current_section_index)
	proxy.set("uci.mmpbx.network.@"..current_section_index..".config","mmpbxrvsipnet")

	proxy.get("uci.mmpbx.") --workaround to avoid HTTP 500 error

    local tempindex = proxy.add("uci.mmpbx.dial_plan.@dial_plan_generic.network.")
    proxy.set("uci.mmpbx.dial_plan.@dial_plan_generic.network.@".. tempindex ..".value", current_section_index)

    tempindex = proxy.add("uci.mmpbx.scc.@scc_generic.network.")
    proxy.set("uci.mmpbx.scc.@scc_generic.network.@".. tempindex ..".value", current_section_index)

    tempindex = proxy.add("uci.mmpbx.media_filter.@media_filter_audio_generic.network.")
    proxy.set("uci.mmpbx.media_filter.@media_filter_audio_generic.network.@".. tempindex ..".value", current_section_index)

	for _ , key in pairs(proxy.getPN("uci.mmpbx.audionotification.",true)) do
		tempindex = proxy.add(key.path .."network.")
		proxy.set(key.path .."network.@".. tempindex ..".value", current_section_index)
	end
end

local function onDeleteVoice(current_section_index)

	local function getIndex(path,current_section_index)
		for _ , key in pairs(proxy.getPN(path, true)) do
			if proxy.get(key.path.."value")[1].value == current_section_index then
				return key.path
			end
		end
		return nil
	end

	proxy.del("uci.mmpbx.network.@"..current_section_index..".")

	proxy.del(getIndex("uci.mmpbx.scc.@scc_generic.network.", current_section_index))
	proxy.del(getIndex("uci.mmpbx.dial_plan.@dial_plan_generic.network.", current_section_index))
	proxy.del(getIndex("uci.mmpbx.media_filter.@media_filter_audio_generic.network.", current_section_index))

	for _ , key in pairs(proxy.getPN("uci.mmpbx.audionotification.",true)) do
		proxy.del(getIndex(key.path .."network.", current_section_index))
	end
end

local sipnet_options = {
    tableid = "sipnet",
    basepath = "uci.mmpbxrvsipnet.network.@.",
    sorted = "user_friendly_name", --DO NO ACTIVATE SORTING OR WILL BREAK DELETE
    objectName  = "voice"..uniqueKey,
    addNamedObject = true,
	onAdd = onAddVoice,
    onDelete = onDeleteVoice,
}

local sipnet_data, sipnet_helpmsg = post_helper.handleTableQuery(sipnet_columns, sipnet_options, nil, sipnet_default, sipnet_valid)

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

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