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
ngx.print('<div class="content card_bg" style="height:auto;min-height:110px" data-bg-text="&#xf012;"',
    ' data-connected="', escape(T"Connected"), '"',
    ' data-tether-off="', escape(T"USB tethering disabled"), '"',
    ' data-data-off="', escape(T"Mobile data disabled"), '"',
    ' data-unavailable="', escape(T"Phone unavailable"), '"',
    ' data-unauthorized="', escape(T"ADB authorization required"), '"',
    ' data-offline="', escape(T"ADB device offline"), '"',
    ' data-no-device="', escape(T"Phone not detected by ADB"), '"',
    ' data-multiple-devices="', escape(T"Multiple ADB devices"), '"',
    ' data-adb-missing="', escape(T"ADB not installed"), '"',
    ' data-usb-only="', escape(T"USB detected; ADB unavailable"), '"',
    ' data-link-up="', escape(T"Link up"), '"',
    ' data-link-down="', escape(T"Link down"), '"',
    ' data-no-interface="', escape(T"Interface not detected"), '"',
    ' data-checking="', escape(T"Checking connection"), '"><div class="divtable">')
ngx.print('<div class="pull-right smartphone-signal-bars" style="display:none;margin-right:15px;height:22px;font-size:0" aria-hidden="true">')
for index = 1, 5 do
    ngx.print('<div class="bar-small bar-small', index, '"></div>')
end
ngx.print('</div>')
ngx.print(ui_helper.createSimpleLight("0", T"Smartphone" .. ' <span data-bind="text: phoneDevice"></span><span data-bind="text: phoneBattery"></span>'))
ngx.print('<div style="min-height:25px"><label class="card-label">', T"Status", ':</label> ',
    '<strong class="smartphone-status" data-bind="text: phoneStatus"></strong></div>')
ngx.print('<div class="smartphone-network-row" style="display:none;height:25px"><label class="card-label">', T"Network", ':</label> ',
    '<strong data-bind="text: phoneNetwork"></strong></div>')
ngx.print('<div class="smartphone-signal-row" style="display:none;height:25px" title="', escape(T"Estimated from LTE RSRP"), '"><label class="card-label">',
    T"Signal", ':</label> <strong data-bind="text: phoneSignal"></strong></div>')
ngx.print('<div class="smartphone-tether-row" style="display:none;height:25px"><label class="card-label">', T"Tethering", ':</label> ',
    '<strong data-bind="text: phoneTether"></strong></div></div></div></div></div>')
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
        var errors = {unauthorized: "data-unauthorized", offline: "data-offline", no_device: "data-no-device",
            multiple_devices: "data-multiple-devices", adb_missing: "data-adb-missing", usb_only: "data-usb-only"};
        if (!available && data && Object.prototype.hasOwnProperty.call(errors, data.ERROR_CODE)) {
            state = content.attr(errors[data.ERROR_CODE]);
        }
        var operator = available && data.OPER && data.OPER !== "No SIM" && data.OPER !== "N/A" ? data.OPER : "";
        binding.phoneStatus(state + (operator ? " (" + operator + ")" : ""));
        var usbDevice = !available && data && data.USB_DEV;
        binding.phoneDevice(usbDevice ? "(" + usbDevice + ")" : "");
        root.find(".smartphone-status").attr("title", (data && (data.ERROR || data.message)) || data && data.TETHER || state);
        root.find(".light").toggleClass("green", !!connected).toggleClass("orange", !!(available || usbDevice) && !connected)
            .toggleClass("off", !available && !usbDevice);
        root.find(".simple-desc").attr("title", available ? data.DEV : data && data.USB_DEV || "");
        var battery = available && /^(\d{1,3})%$/.exec(data.BATT || "");
        binding.phoneBattery(battery && Number(battery[1]) <= 100 ?
            "(" + (data.BATT_STAT === "In Carica" ? "⚡ " : "") + data.BATT + ")" : "");
        var network = available && data.NET && data.NET !== "N/A" && data.NET !== "—" ? data.NET : "";
        binding.phoneNetwork(network);
        root.find(".smartphone-network-row").toggle(!!network);
        var host = data && data.HOST_IF;
        var linkUp = host && data.HOST_ADMIN === "up" && data.HOST_CARRIER === "1";
        var hostState = host ? host + " · " + content.attr(linkUp ? "data-link-up" : "data-link-down") :
            data && data.USB_NETWORK === "1" ? content.attr("data-no-interface") : "";
        binding.phoneTether(hostState);
        root.find(".smartphone-tether-row").toggle(!!hostState).attr("title",
            host && data.HOST_IPV4 || data && data.HOST_DRIVER_STATUS || "");
        // The percentage is an indicative LTE RSRP level, not a throughput estimate.
        var rsrp = available && /^-\d+(?:\.\d+)?$/.test(String(data.SIGNAL_RAW)) ? Number(data.SIGNAL_RAW) : NaN;
        var valid = isFinite(rsrp) && rsrp >= -140 && rsrp <= -43;
        var quality = valid ? Math.max(0, Math.min(100, Math.round((rsrp + 120) * 2.5))) : null;
        binding.phoneSignal(valid ? quality + "% (" + rsrp + " dBm)" : "");
        root.find(".smartphone-signal-row").toggle(valid);
        root.find(".smartphone-signal-bars").toggle(valid);
        var bars = valid ? Math.ceil(quality / 20) : 0;
        root.find(".bar-small").each(function (index) { $(this).toggleClass("bar-small-active", index < bars); });
    }
    function refresh(binding) {
        if (binding.phoneStatus() === undefined) {
            binding.phoneStatus(content.attr("data-checking"));
            binding.phoneDevice("");
            binding.phoneNetwork(""); binding.phoneSignal(""); binding.phoneBattery("");
            binding.phoneTether("");
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
