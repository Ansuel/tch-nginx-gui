--pretranslated: do not change this file

gettext.textdomain('webui-voice')
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local uimessage_helper = require("web.uimessage_helper")
local untaint = string.untaint
local function validate_text(value)
    value = untaint(value)
    if type(value) == "string" and #value <= 128 and not value:find("[%c]") then return true end
    return nil, T"Invalid value"
end
local function validate_phone(value)
    value = untaint(value)
    if type(value) == "string" and #value <= 64 and not value:find("[^%d+*#]") then return true end
    return nil, T"Invalid phone number"
end
local fields = {
    { name = "nat_keepalive_method", label = T"Keep-Alive Method", path = "uci.mmpbxrvsipnet.network.@sip_net.nat_keepalive_method", kind = "select", validate = nil, options = {{"", T"Disabled"}, {"options", T"options"}, {"register", T"register"}} },
    { name = "nat_keepalive_interval", label = T"Keep-Alive Interval (s)", path = "uci.mmpbxrvsipnet.network.@sip_net.nat_keepalive_interval", kind = "number", validate = post_helper.getValidateNumberInRange(1, 86400), options = nil },
    { name = "reg_expire_T_before", label = T"Reg Expire Before (s)", path = "uci.mmpbxrvsipnet.network.@sip_net.reg_expire_T_before", kind = "number", validate = post_helper.getValidateNumberInRange(0, 86400), options = nil },
    { name = "stun_enabled", label = T"Enable STUN", path = "uci.mmpbxrvsipnet.network.@sip_net.stun_enabled", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "stun_server", label = T"STUN Server", path = "uci.mmpbxrvsipnet.network.@sip_net.stun_server", kind = "text", validate = post_helper.getOptionalValidation(post_helper.getOrValidation(post_helper.validateStringIsIP, post_helper.validateStringIsDomainName)), options = nil },
    { name = "stun_port", label = T"STUN Port", path = "uci.mmpbxrvsipnet.network.@sip_net.stun_port", kind = "number", validate = post_helper.getValidateNumberInRange(1, 65535), options = nil },
    { name = "dtmf_relay", label = T"DTMF Relay Mode", path = "uci.mmpbxrvsipnet.network.@sip_net.dtmf_relay", kind = "select", validate = nil, options = {{"rfc2833", T"rfc2833"}, {"inband", T"inband"}, {"sip_info", T"sip_info"}} },
    { name = "user_agent", label = T"User Agent", path = "uci.mmpbxrvsipnet.network.@sip_net.user_agent", kind = "text", validate = validate_text, options = nil },
    { name = "ipv6_voip", label = T"Enable IPv6 for VoIP", path = "uci.mmpbxrvsipnet.network.@sip_net.sip_over_ipv6", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "acr_active", label = T"Reject Anonymous Calls (ACR)", path = "uci.mmpbx.service.@service_acr_3.activated", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "dnd_active", label = T"Do Not Disturb (DND)", path = "uci.mmpbx.service.@service_dnd_3.activated", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "call_waiting", label = T"Call Waiting", path = "uci.mmpbx.service.@CALL_WAITING.activated", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "call_transfer", label = T"Call Transfer", path = "uci.mmpbx.service.@TRANSFER.activated", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "clir_active", label = T"Hide My Number (CLIR)", path = "uci.mmpbx.service.@service_clir_3.activated", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "cfu_active", label = T"Forward All Calls (CFU)", path = "uci.mmpbx.service.@service_cfu_3.activated", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "cfnr_active", label = T"Forward on No Reply (CFNR)", path = "uci.mmpbx.service.@service_cfnr_3.activated", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "cfnr_timeout", label = T"No Reply Timeout (s)", path = "uci.mmpbx.service.@service_cfnr_3.timeout", kind = "number", validate = post_helper.getValidateNumberInRange(1, 3600), options = nil },
    { name = "no_answer_timeout", label = T"Global Ringing Timeout (s)", path = "uci.mmpbx.mmpbx.@global.no_answer_timeout", kind = "number", validate = post_helper.getValidateNumberInRange(1, 3600), options = nil },
    { name = "inter_digit_timer", label = T"Dialing Pause Timer (ms)", path = "uci.mmpbx.scc.@scc_generic.inter_digit_timer", kind = "number", validate = post_helper.getValidateNumberInRange(1, 60000), options = nil },
    { name = "dial_timeout", label = T"Dial Timeout (s)", path = "uci.mmpbx.mmpbx.@global.dial_timeout", kind = "number", validate = post_helper.getValidateNumberInRange(1, 3600), options = nil },
    { name = "eon_key", label = T"End Of Number Key", path = "uci.mmpbx.scc.@scc_generic.eon", kind = "select", validate = nil, options = {{"#", T"#"}, {"*", T"*"}, {"", T"Disabled"}} },
    { name = "ac_active", label = T"Enable Auto-Prefix", path = "uci.mmpbx.areacode_translation.@areacode_translation_1.show", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "ac_prefix", label = T"Local Area Code Prefix", path = "uci.mmpbx.areacode_translation.@areacode_translation_1.areacode", kind = "text", validate = validate_phone, options = nil },
    { name = "wl0_active", label = T"Enable SOS Auto-Dial (Phone 1)", path = "uci.mmpbx.service.@WARMLINE_0.activated", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "wl0_timeout", label = T"Off-Hook Timeout (Phone 1, s)", path = "uci.mmpbx.service.@WARMLINE_0.timeout", kind = "number", validate = post_helper.getValidateNumberInRange(1, 3600), options = nil },
    { name = "wl0_number", label = T"SOS Number (Phone 1)", path = "uci.mmpbx.service.@WARMLINE_0.destination", kind = "text", validate = validate_phone, options = nil },
    { name = "wl1_active", label = T"Enable SOS Auto-Dial (Phone 2)", path = "uci.mmpbx.service.@WARMLINE_1.activated", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "wl1_timeout", label = T"Off-Hook Timeout (Phone 2, s)", path = "uci.mmpbx.service.@WARMLINE_1.timeout", kind = "number", validate = post_helper.getValidateNumberInRange(1, 3600), options = nil },
    { name = "wl1_number", label = T"SOS Number (Phone 2)", path = "uci.mmpbx.service.@WARMLINE_1.destination", kind = "text", validate = validate_phone, options = nil },
    { name = "jb_adaptive", label = T"Jitter Buffer", path = "uci.mmpbxbrcmcountry.global_provision.voice_jitter_buff_fixed", kind = "select", validate = nil, options = {{"0", T"Adaptive"}, {"1", T"Fixed"}} },
    { name = "t38_enable", label = T"Fax Transport", path = "uci.mmpbxbrcmfxsdev.global.fax_transport", kind = "select", validate = nil, options = {{"t38", T"t38"}, {"transparent", T"transparent"}} },
    { name = "fxs0_echo", label = T"Echo Cancellation (Phone 1)", path = "uci.mmpbxbrcmfxsdev.device.@fxs_dev_0.echo_cancellation", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "fxs1_echo", label = T"Echo Cancellation (Phone 2)", path = "uci.mmpbxbrcmfxsdev.device.@fxs_dev_1.echo_cancellation", kind = "switch", validate = post_helper.validateBoolean, options = nil },
    { name = "master_rx", label = T"Ear Volume Gain (RX dB)", path = "uci.mmpbxbrcmcountry.global_provision.rx_gain_fxs", kind = "number", validate = post_helper.getValidateNumberInRange(-12, 12), options = nil },
    { name = "master_tx", label = T"Mic Volume Gain (TX dB)", path = "uci.mmpbxbrcmcountry.global_provision.tx_gain_fxs", kind = "number", validate = post_helper.getValidateNumberInRange(-12, 12), options = nil },
    { name = "ring_voltage", label = T"Ring Voltage (V)", path = "uci.mmpbxbrcmcountry.global_provision.ring_voltage", kind = "number", validate = post_helper.getValidateNumberInRange(30, 90), options = nil },
    { name = "ring_frequency", label = T"Ring Frequency (Hz)", path = "uci.mmpbxbrcmcountry.global_provision.powerring_frequency", kind = "number", validate = post_helper.getValidateNumberInRange(15, 60), options = nil },
}
local paths, validators, available = {}, {}, {}
for _, field in ipairs(fields) do
    -- Some firmware images omit services or physical ports. Do not fabricate them.
    local result = proxy.get(field.path)
    if result and result[1] and
       (result[1].value ~= "" or field.kind == "text" or field.name == "nat_keepalive_method" or field.name == "eon_key") then
        available[field.name] = true
        paths[field.name] = field.path
        validators[field.name] = field.validate or post_helper.getValidateInEnumSelect(field.options)
    end
end
local content, helpmsg = {}, {}
if next(paths) then
    content, helpmsg = post_helper.handleQuery(paths, validators)
else
    uimessage_helper.pushMessage(T"Advanced voice settings are unavailable on this firmware", "error")
end
local uri = ngx.var.uri

-- Render the controls exposed by this firmware's datamodel.
ngx.print(ui_helper.createHeader(T"VoIP Advanced Control Panel", true, true))
ngx.print('<div class="modal-body update">')
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("tabs-voice.lp")
ngx.print('<form class="form-horizontal" method="post" action="', uri, '">')
ngx.print(ui_helper.createMessages(uimessage_helper.popMessages()))
ngx.print('<fieldset><legend>', T"Advanced Voice Settings", '</legend>')
for _, field in ipairs(fields) do
    if available[field.name] then
        local value = content[field.name] or ""
        local attr = { input = { class = "span3" }, select = { class = "span3" } }
        if field.kind == "switch" then
            ngx.print(ui_helper.createSwitch(field.label, field.name, value, nil, helpmsg[field.name]))
        elseif field.kind == "select" then
            ngx.print(ui_helper.createInputSelect(field.label, field.name, field.options, value, attr, helpmsg[field.name]))
        else
            ngx.print(ui_helper.createInputText(field.label, field.name, value, attr, helpmsg[field.name]))
        end
    end
end

ngx.print('</fieldset></form></div>')
ngx.print(ui_helper.createFooter())
