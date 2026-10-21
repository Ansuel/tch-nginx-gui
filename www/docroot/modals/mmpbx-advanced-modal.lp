<%
-- Enable localization
gettext.textdomain('webui-voice')

local ngx = ngx
local ui_helper = require("web.ui_helper")
local uimessage_helper = require("web.uimessage_helper")
local string = string

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

-- =======================================================
-- 1. DUAL READ/WRITE ENGINE (TRANSFORMER + UCI)
-- =======================================================

-- Mixed read function: Tries Transformer first, fallback to UCI
local function sys_get(xfer_path, uci_path, default)
    -- Try Transformer (safer for GUI permissions)
    local f = io.popen("transformer-cli get " .. xfer_path .. " 2>/dev/null")
    if f then
        local res = f:read("*all")
        f:close()
        local val = res:match("=%s*(.*)")
        if val then 
            val = val:gsub("[\r\n]+", "")
            if val ~= "" and not val:find("tainted") and not val:find("ERROR") then return val end
        end
    end
    
    -- Fallback to native UCI for hidden parameters
    f = io.popen("/sbin/uci -q get " .. uci_path .. " 2>/dev/null")
    if f then
        local val = f:read("*l") 
        f:close()
        if val and val ~= "" and not val:find("tainted") then return val end
    end
    
    return default
end

-- Simultaneous write function (writes to both datamodels)
local function sys_set(xfer_path, uci_path, val)
    if val ~= nil and val ~= "" then
        local clean_val = tostring(val):gsub("[\"$&|;`]", "") 
        os.execute('/sbin/uci set ' .. uci_path .. '="' .. clean_val .. '" 2>/dev/null')
        os.execute('transformer-cli set ' .. xfer_path .. ' "' .. clean_val .. '" >/dev/null 2>&1')
    end
end

-- =======================================================
-- 2. SAVE MANAGEMENT (POST)
-- =======================================================
if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
    local args = ngx.req.get_post_args()
    
    local string_untaint = string.untaint or function(x) return x end
    local function get_val(v, is_switch)
        if type(v) == "table" then v = v[#v] end
        if v == nil then return "" end
        local ok, clean = pcall(string_untaint, v)
        v = tostring(ok and clean or v)
        if is_switch then return (v == "1" or v == "true" or v == "on") and "1" or "0" end
        return v
    end

    -- Network, STUN, IPv6
    sys_set("uci.mmpbxrvsipnet.sip_net.nat_keepalive_method", "mmpbxrvsipnet.sip_net.nat_keepalive_method", get_val(args.nat_keepalive_method))
    sys_set("uci.mmpbxrvsipnet.sip_net.nat_keepalive_interval", "mmpbxrvsipnet.sip_net.nat_keepalive_interval", get_val(args.nat_keepalive_interval))
    sys_set("uci.mmpbxrvsipnet.sip_net.reg_expire_T_before", "mmpbxrvsipnet.sip_net.reg_expire_T_before", get_val(args.reg_expire_T_before))
    sys_set("uci.mmpbxrvsipnet.sip_net.stun_enabled", "mmpbxrvsipnet.sip_net.stun_enabled", get_val(args.stun_enabled, true))
    sys_set("uci.mmpbxrvsipnet.sip_net.stun_server", "mmpbxrvsipnet.sip_net.stun_server", get_val(args.stun_server))
    sys_set("uci.mmpbxrvsipnet.sip_net.stun_port", "mmpbxrvsipnet.sip_net.stun_port", get_val(args.stun_port))
    sys_set("uci.mmpbxrvsipnet.sip_net.dtmf_relay", "mmpbxrvsipnet.sip_net.dtmf_relay", get_val(args.dtmf_relay))
    sys_set("uci.mmpbxrvsipnet.sip_net.user_agent", "mmpbxrvsipnet.sip_net.user_agent", get_val(args.user_agent))
    sys_set("uci.mmpbxrvsipnet.sip_net.sip_over_ipv6", "mmpbxrvsipnet.sip_net.sip_over_ipv6", get_val(args.ipv6_voip, true))

    -- Call Features & Timers
    sys_set("uci.mmpbx.service.@service_acr_3.activated", "mmpbx.service_acr_3.activated", get_val(args.acr_active, true))
    sys_set("uci.mmpbx.service.@service_dnd_3.activated", "mmpbx.service_dnd_3.activated", get_val(args.dnd_active, true))
    sys_set("uci.mmpbx.service.@CALL_WAITING.activated", "mmpbx.CALL_WAITING.activated", get_val(args.call_waiting, true))
    sys_set("uci.mmpbx.TRANSFER.activated", "mmpbx.TRANSFER.activated", get_val(args.call_transfer, true))
    sys_set("uci.mmpbx.service.@service_clir_3.activated", "mmpbx.service_clir_3.activated", get_val(args.clir_active, true))
    sys_set("uci.mmpbx.service.@service_cfu_3.activated", "mmpbx.service_cfu_3.activated", get_val(args.cfu_active, true))
    sys_set("uci.mmpbx.service.@service_cfnr_3.activated", "mmpbx.service_cfnr_3.activated", get_val(args.cfnr_active, true))
    sys_set("uci.mmpbx.service.@service_cfnr_3.timeout", "mmpbx.service_cfnr_3.timeout", get_val(args.cfnr_timeout))
    sys_set("uci.mmpbx.mmpbx.@global.no_answer_timeout", "mmpbx.global.no_answer_timeout", get_val(args.no_answer_timeout))
    sys_set("uci.mmpbx.scc_generic.inter_digit_timer", "mmpbx.scc_generic.inter_digit_timer", get_val(args.inter_digit_timer))
    sys_set("uci.mmpbx.mmpbx.@global.dial_timeout", "mmpbx.global.dial_timeout", get_val(args.dial_timeout))
    sys_set("uci.mmpbx.scc_generic.eon", "mmpbx.scc_generic.eon", get_val(args.eon_key))
    sys_set("uci.mmpbx.areacode_translation_1.show", "mmpbx.areacode_translation_1.show", get_val(args.ac_active, true))
    sys_set("uci.mmpbx.areacode_translation_1.areacode", "mmpbx.areacode_translation_1.areacode", get_val(args.ac_prefix))

    -- SOS Auto-Dial (Warmline)
    sys_set("uci.mmpbx.service.@WARMLINE_0.activated", "mmpbx.WARMLINE_0.activated", get_val(args.wl0_active, true))
    sys_set("uci.mmpbx.service.@WARMLINE_0.timeout", "mmpbx.WARMLINE_0.timeout", get_val(args.wl0_timeout))
    sys_set("uci.mmpbx.service.@WARMLINE_0.destination", "mmpbx.WARMLINE_0.destination", get_val(args.wl0_number))
    sys_set("uci.mmpbx.service.@WARMLINE_1.activated", "mmpbx.WARMLINE_1.activated", get_val(args.wl1_active, true))
    sys_set("uci.mmpbx.service.@WARMLINE_1.timeout", "mmpbx.WARMLINE_1.timeout", get_val(args.wl1_timeout))
    sys_set("uci.mmpbx.service.@WARMLINE_1.destination", "mmpbx.WARMLINE_1.destination", get_val(args.wl1_number))

    -- Hardware & DSP
    local jb_val = get_val(args.jb_adaptive, true) == "1" and "0" or "1"
    sys_set("uci.mmpbxbrcmcountry.global_provision.voice_jitter_buff_fixed", "mmpbxbrcmcountry.global_provision.voice_jitter_buff_fixed", jb_val)
    local t38_val = get_val(args.t38_enable, true) == "1" and "t38" or "transparent"
    sys_set("uci.mmpbxbrcmfxsdev.global.fax_transport", "mmpbxbrcmfxsdev.global.fax_transport", t38_val)
    sys_set("uci.mmpbxbrcmfxsdev.fxs_dev_0.echo_cancellation", "mmpbxbrcmfxsdev.fxs_dev_0.echo_cancellation", get_val(args.fxs0_echo, true))
    sys_set("uci.mmpbxbrcmfxsdev.fxs_dev_1.echo_cancellation", "mmpbxbrcmfxsdev.fxs_dev_1.echo_cancellation", get_val(args.fxs1_echo, true))
    sys_set("uci.mmpbxbrcmcountry.global_provision.rx_gain_fxs", "mmpbxbrcmcountry.global_provision.rx_gain_fxs", get_val(args.master_rx))
    sys_set("uci.mmpbxbrcmcountry.global_provision.tx_gain_fxs", "mmpbxbrcmcountry.global_provision.tx_gain_fxs", get_val(args.master_tx))
    sys_set("uci.mmpbxbrcmcountry.global_provision.ring_voltage", "mmpbxbrcmcountry.global_provision.ring_voltage", get_val(args.ring_voltage))
    sys_set("uci.mmpbxbrcmcountry.global_provision.powerring_frequency", "mmpbxbrcmcountry.global_provision.powerring_frequency", get_val(args.ring_frequency))

    os.execute("/sbin/uci commit mmpbx; /sbin/uci commit mmpbxrvsipnet; /sbin/uci commit mmpbxbrcmfxsdev; /sbin/uci commit mmpbxbrcmcountry")
    os.execute("/etc/init.d/mmpbx restart >/dev/null 2>&1 || /etc/init.d/transformer reload >/dev/null 2>&1 &")
    
    uimessage_helper.pushMessage(T"Changes saved successfully", "success")
end

-- =======================================================
-- 3. DATA READING 
-- =======================================================

local adv_method = sys_get("uci.mmpbxrvsipnet.sip_net.nat_keepalive_method", "mmpbxrvsipnet.sip_net.nat_keepalive_method", "options")
local adv_interval = sys_get("uci.mmpbxrvsipnet.sip_net.nat_keepalive_interval", "mmpbxrvsipnet.sip_net.nat_keepalive_interval", "20")
local adv_timer = sys_get("uci.mmpbxrvsipnet.sip_net.reg_expire_T_before", "mmpbxrvsipnet.sip_net.reg_expire_T_before", "540")
local adv_stun_en = sys_get("uci.mmpbxrvsipnet.sip_net.stun_enabled", "mmpbxrvsipnet.sip_net.stun_enabled", "0")
local adv_stun_srv = sys_get("uci.mmpbxrvsipnet.sip_net.stun_server", "mmpbxrvsipnet.sip_net.stun_server", "")
local adv_stun_port = sys_get("uci.mmpbxrvsipnet.sip_net.stun_port", "mmpbxrvsipnet.sip_net.stun_port", "3478")
local adv_dtmf = sys_get("uci.mmpbxrvsipnet.sip_net.dtmf_relay", "mmpbxrvsipnet.sip_net.dtmf_relay", "rfc2833")
local adv_user_agent = sys_get("uci.mmpbxrvsipnet.sip_net.user_agent", "mmpbxrvsipnet.sip_net.user_agent", "")
local ipv6_voip = sys_get("uci.mmpbxrvsipnet.sip_net.sip_over_ipv6", "mmpbxrvsipnet.sip_net.sip_over_ipv6", "0")

local acr_active = sys_get("uci.mmpbx.service.@service_acr_3.activated", "mmpbx.service_acr_3.activated", "0")
local dnd_active = sys_get("uci.mmpbx.service.@service_dnd_3.activated", "mmpbx.service_dnd_3.activated", "0")
local call_waiting = sys_get("uci.mmpbx.service.@CALL_WAITING.activated", "mmpbx.CALL_WAITING.activated", "0")
local call_transfer = sys_get("uci.mmpbx.TRANSFER.activated", "mmpbx.TRANSFER.activated", "0")
local clir_active = sys_get("uci.mmpbx.service.@service_clir_3.activated", "mmpbx.service_clir_3.activated", "0")
local cfu_active = sys_get("uci.mmpbx.service.@service_cfu_3.activated", "mmpbx.service_cfu_3.activated", "0")
local cfnr_active = sys_get("uci.mmpbx.service.@service_cfnr_3.activated", "mmpbx.service_cfnr_3.activated", "0")
local cfnr_timeout = sys_get("uci.mmpbx.service.@service_cfnr_3.timeout", "mmpbx.service_cfnr_3.timeout", "60")
local no_answer_timeout = sys_get("uci.mmpbx.mmpbx.@global.no_answer_timeout", "mmpbx.global.no_answer_timeout", "1200")
local inter_digit_timer = sys_get("uci.mmpbx.scc_generic.inter_digit_timer", "mmpbx.scc_generic.inter_digit_timer", "3000")
local dial_timeout = sys_get("uci.mmpbx.mmpbx.@global.dial_timeout", "mmpbx.global.dial_timeout", "20")
local eon_key = sys_get("uci.mmpbx.scc_generic.eon", "mmpbx.scc_generic.eon", "#")
local ac_active = sys_get("uci.mmpbx.areacode_translation_1.show", "mmpbx.areacode_translation_1.show", "0")
local ac_prefix = sys_get("uci.mmpbx.areacode_translation_1.areacode", "mmpbx.areacode_translation_1.areacode", "")

local wl0_active = sys_get("uci.mmpbx.service.@WARMLINE_0.activated", "mmpbx.WARMLINE_0.activated", "0")
local wl0_timeout = sys_get("uci.mmpbx.service.@WARMLINE_0.timeout", "mmpbx.WARMLINE_0.timeout", "10")
local wl0_number = sys_get("uci.mmpbx.service.@WARMLINE_0.destination", "mmpbx.WARMLINE_0.destination", "")
local wl1_active = sys_get("uci.mmpbx.service.@WARMLINE_1.activated", "mmpbx.WARMLINE_1.activated", "0")
local wl1_timeout = sys_get("uci.mmpbx.service.@WARMLINE_1.timeout", "mmpbx.WARMLINE_1.timeout", "10")
local wl1_number = sys_get("uci.mmpbx.service.@WARMLINE_1.destination", "mmpbx.WARMLINE_1.destination", "")

local jb_adaptive = sys_get("uci.mmpbxbrcmcountry.global_provision.voice_jitter_buff_fixed", "mmpbxbrcmcountry.global_provision.voice_jitter_buff_fixed", "0") == "0" and "1" or "0"
local t38_enable = sys_get("uci.mmpbxbrcmfxsdev.global.fax_transport", "mmpbxbrcmfxsdev.global.fax_transport", "t38") == "t38" and "1" or "0"
local fxs0_echo = sys_get("uci.mmpbxbrcmfxsdev.fxs_dev_0.echo_cancellation", "mmpbxbrcmfxsdev.fxs_dev_0.echo_cancellation", "1")
local fxs1_echo = sys_get("uci.mmpbxbrcmfxsdev.fxs_dev_1.echo_cancellation", "mmpbxbrcmfxsdev.fxs_dev_1.echo_cancellation", "1")
local master_rx = sys_get("uci.mmpbxbrcmcountry.global_provision.rx_gain_fxs", "mmpbxbrcmcountry.global_provision.rx_gain_fxs", "0")
local master_tx = sys_get("uci.mmpbxbrcmcountry.global_provision.tx_gain_fxs", "mmpbxbrcmcountry.global_provision.tx_gain_fxs", "0")
local ring_voltage = sys_get("uci.mmpbxbrcmcountry.global_provision.ring_voltage", "mmpbxbrcmcountry.global_provision.ring_voltage", "50")
local ring_frequency = sys_get("uci.mmpbxbrcmcountry.global_provision.powerring_frequency", "mmpbxbrcmcountry.global_provision.powerring_frequency", "20")
%>

<%= ui_helper.createHeader(T"VoIP Advanced Control Panel", true, true) %>

<div class="modal-body update">
    <%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-voice.lp")
    %>
    <form class="form-horizontal" method="post" action="<%= uri %>">
        <%=ui_helper.createMessages(uimessage_helper.popMessages())%>
        
        <fieldset>
            <legend><%= T"Network, NAT & Protocol" %></legend>
            <%
            local attr_adv = {input = { class = "span2"}, select = { class = "span2"}}
            local keepalive_options = { {"", T"Disabled"}, {"options", T"OPTIONS"}, {"register", T"REGISTER"} }
            local dtmf_options = { {"rfc2833", "RFC2833"}, {"inband", "In-Band"}, {"sip_info", "SIP INFO"} }
            
            ngx.print(
                ui_helper.createSwitch(T"Enable IPv6 for VoIP", "ipv6_voip", ipv6_voip),
                ui_helper.createInputSelect(T"Keep-Alive Method", "nat_keepalive_method", keepalive_options, adv_method, attr_adv),
                ui_helper.createInputText(T"Keep-Alive Interval (s)", "nat_keepalive_interval", adv_interval, attr_adv),
                ui_helper.createInputText(T"Reg Expire Before (s)", "reg_expire_T_before", adv_timer, attr_adv),
                ui_helper.createSwitch(T"Enable STUN", "stun_enabled", adv_stun_en),
                ui_helper.createInputText(T"STUN Server", "stun_server", adv_stun_srv, {input = {class = "span4"}}),
                ui_helper.createInputText(T"STUN Port", "stun_port", adv_stun_port, attr_adv),
                ui_helper.createInputSelect(T"DTMF Relay Mode", "dtmf_relay", dtmf_options, adv_dtmf, attr_adv),
                ui_helper.createInputText(T"User Agent Spoofing", "user_agent", adv_user_agent, {input = {class = "span4"}})
            )
            %>
        </fieldset>

        <fieldset>
            <legend><%= T"Call Features & Dialing Rules" %></legend>
            <%
            ngx.print(
                ui_helper.createSwitch(T"Reject Anonymous Calls (ACR)", "acr_active", acr_active),
                ui_helper.createSwitch(T"Do Not Disturb (DND)", "dnd_active", dnd_active),
                ui_helper.createSwitch(T"Call Waiting (Beep)", "call_waiting", call_waiting),
                ui_helper.createSwitch(T"Call Transfer (R-Key)", "call_transfer", call_transfer),
                ui_helper.createSwitch(T"Hide My Number (CLIR)", "clir_active", clir_active),
                ui_helper.createSwitch(T"Forward ALL Calls (CFU)", "cfu_active", cfu_active),
                ui_helper.createSwitch(T"Forward on No Reply (CFNR)", "cfnr_active", cfnr_active),
                ui_helper.createInputText(T"No Reply Timeout (s)", "cfnr_timeout", cfnr_timeout, attr_adv),
                ui_helper.createInputText(T"Global Ringing Timeout (s)", "no_answer_timeout", no_answer_timeout, attr_adv),
                ui_helper.createInputText(T"Dialing Pause Timer (ms)", "inter_digit_timer", inter_digit_timer, attr_adv),
                ui_helper.createInputText(T"Dial Timeout/Off-Hook (s)", "dial_timeout", dial_timeout, attr_adv),
                ui_helper.createInputText(T"End Of Number Key", "eon_key", eon_key, attr_adv),
                ui_helper.createSwitch(T"Enable Auto-Prefix (Local Calls)", "ac_active", ac_active),
                ui_helper.createInputText(T"Local Area Code prefix", "ac_prefix", ac_prefix, attr_adv)
            )
            %>
        </fieldset>

        <fieldset>
            <legend><%= T"SOS Auto-Dial (Warmline)" %></legend>
            <%
            ngx.print(
                ui_helper.createSwitch(T"Enable SOS Auto-Dial (Phone 1)", "wl0_active", wl0_active),
                ui_helper.createInputText(T"Off-Hook Timeout (s)", "wl0_timeout", wl0_timeout, attr_adv),
                ui_helper.createInputText(T"SOS Number to Call", "wl0_number", wl0_number, attr_adv),
                ui_helper.createSwitch(T"Enable SOS Auto-Dial (Phone 2)", "wl1_active", wl1_active),
                ui_helper.createInputText(T"Off-Hook Timeout (s)", "wl1_timeout", wl1_timeout, attr_adv),
                ui_helper.createInputText(T"SOS Number to Call", "wl1_number", wl1_number, attr_adv)
            )
            %>
        </fieldset>

        <fieldset>
            <legend><%= T"Media, Echo & Hardware (FXS Ports)" %></legend>
            <%
            ngx.print(
                ui_helper.createSwitch(T"Adaptive Jitter Buffer (4G Stability)", "jb_adaptive", jb_adaptive),
                ui_helper.createSwitch(T"T.38 Fax Pass-Through", "t38_enable", t38_enable),
                ui_helper.createSwitch(T"Echo Cancellation (Phone 1)", "fxs0_echo", fxs0_echo),
                ui_helper.createSwitch(T"Echo Cancellation (Phone 2)", "fxs1_echo", fxs1_echo),
                ui_helper.createInputText(T"Global Ear Volume Gain (RX dB)", "master_rx", master_rx, attr_adv),
                ui_helper.createInputText(T"Global Mic Volume Gain (TX dB)", "master_tx", master_tx, attr_adv),
                ui_helper.createInputText(T"Ring Voltage (V) - Default 50", "ring_voltage", ring_voltage, attr_adv),
                ui_helper.createInputText(T"Ring Frequency (Hz) - Default 20", "ring_frequency", ring_frequency, attr_adv)
            )
            %>
        </fieldset>
    </form>
</div>

<%= ui_helper.createFooter() %>