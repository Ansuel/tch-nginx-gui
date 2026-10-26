--pretranslated: do not change this file
gettext.textdomain('webui-mobiled')
local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session
local escape = require("web.web").html_escape
local target
if session:hasAccess("/modals/smartphone-modal.lp") then target = "/modals/smartphone-modal.lp" end
ngx.print('<link href="/css/mobiled.css" rel="stylesheet">')
ngx.print('<div class="span3" id="smartphone-card"><div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">')
ngx.print(ui_helper.createCardHeader(T"Smartphone USB", target))
ngx.print('<div class="content card_bg" data-bg-text="&#xf012;"',
    ' data-connected="', escape(T"Connected"), '"',
    ' data-tether-off="', escape(T"USB tethering disabled"), '"',
    ' data-data-off="', escape(T"Mobile data disabled"), '"',
    ' data-unavailable="', escape(T"Phone unavailable"), '"',
    ' data-checking="', escape(T"Checking connection"), '"><div class="divtable">')
ngx.print('<div class="pull-right" style="margin-right:15px;height:22px;font-size:0" aria-hidden="true">')
for index = 1, 5 do
    ngx.print('<div class="bar-small bar-small', index, '"></div>')
end
ngx.print('</div>')
ngx.print(ui_helper.createSimpleLight("0", T"Smartphone" .. ' <span data-bind="text: phoneBattery"></span>'))
ngx.print('<div style="height:25px"><label class="card-label">', T"Status", ':</label> ',
    '<strong class="smartphone-status" data-bind="text: phoneStatus"></strong></div>')
ngx.print('<div style="height:25px"><label class="card-label">', T"Network", ':</label> ',
    '<strong data-bind="text: phoneNetwork"></strong></div>')
ngx.print('<div style="height:25px" title="', escape(T"Estimated from LTE RSRP"), '"><label class="card-label">',
    T"Signal", ':</label> <strong data-bind="text: phoneSignal"></strong></div></div></div></div></div>')
if target then
ngx.print([===[
<script>
/* Use the same card lifecycle, bindings and mobile indicators as the dashboard. */
$(function () {
    var element = document.getElementById("smartphone-card");
    if (!element) return;
    var root = $(element), content = root.find(".content");
    function current() { return document.getElementById("smartphone-card") === element; }
    function render(binding, data) {
        var available = data && !data.ERROR && data.status !== "error" && !!data.DEV;
        var tether = available && /^(Attivo|Connesso)\b/.test(data.TETHER || "");
        var connected = tether && data.DATA_ST === "1";
        var state = available ? content.attr(!tether ? "data-tether-off" :
            (connected ? "data-connected" : "data-data-off")) : content.attr("data-unavailable");
        var operator = available && data.OPER && data.OPER !== "No SIM" && data.OPER !== "N/A" ? data.OPER : "";
        binding.phoneStatus(state + (operator ? " (" + operator + ")" : ""));
        root.find(".smartphone-status").attr("title", (data && (data.ERROR || data.message)) || data && data.TETHER || state);
        root.find(".light").toggleClass("green", !!connected).toggleClass("orange", !!available && !connected)
            .toggleClass("off", !available);
        root.find(".simple-desc").attr("title", available ? data.DEV : "");
        var battery = available && /^(\d{1,3})%$/.exec(data.BATT || "");
        binding.phoneBattery(battery && Number(battery[1]) <= 100 ?
            "(" + (data.BATT_STAT === "In Carica" ? "⚡ " : "") + data.BATT + ")" : "(—)");
        binding.phoneNetwork(available && data.NET && data.NET !== "N/A" ? data.NET : "—");
        // The percentage is an indicative LTE RSRP level, not a throughput estimate.
        var rsrp = available && /^-\d+(?:\.\d+)?$/.test(String(data.SIGNAL_RAW)) ? Number(data.SIGNAL_RAW) : NaN;
        var valid = isFinite(rsrp) && rsrp >= -140 && rsrp <= -43;
        var quality = valid ? Math.max(0, Math.min(100, Math.round((rsrp + 120) * 2.5))) : null;
        binding.phoneSignal(valid ? quality + "% (" + rsrp + " dBm)" : "—");
        var bars = valid ? Math.ceil(quality / 20) : 0;
        root.find(".bar-small").each(function (index) { $(this).toggleClass("bar-small-active", index < bars); });
    }
    function refresh(binding) {
        if (binding.phoneStatus() === undefined) {
            binding.phoneStatus(content.attr("data-checking"));
            binding.phoneNetwork("—"); binding.phoneSignal("—"); binding.phoneBattery("(—)");
        }
        return $.ajax({url: "/modals/smartphone-modal.lp", type: "POST", dataType: "json", timeout: 25000,
            data: [tch.elementCSRFtoken(), {name: "action", value: "get_stats"}]
        }).done(function (data) { if (current()) render(binding, data); })
            .fail(function (_, status) { if (current() && status !== "abort") render(binding, null); });
    }
    new modgui.createAjaxUpdateCard("smartphone-card", null, "SmartphoneCardInterval", 30000, refresh);
});
</script>
]===])
end
