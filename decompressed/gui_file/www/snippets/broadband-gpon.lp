--pretranslated: do not change this file

-- Enable localization

gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format
local tonumber = tonumber

local iconUp = "<i class=\"icon-upload icon-large gray\"></i> "
local iconDown = "<i class=\"icon-download icon-large gray\"></i> "
local bridge = require("bridgehelper")

local byte_units = {"B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB"}
local function formatBytes(value)
    local bytes = tonumber(value) or 0
    local unit = 1
    while bytes >= 1024 and unit < #byte_units do
        bytes = bytes / 1024
        unit = unit + 1
    end
    if unit == 1 then
        return format("%.0f B", bytes)
    end
    return format("%.2f %s", bytes, byte_units[unit])
end

if bridge.hasIntegratedGpon() then
    local stats = "sys.class.net.@gpondef.statistics."
    local content = {
        status = "rpc.gpon.ploam.state",
        rx = "rpc.gpon.trsv.info.status.DS_Rx_RSSI",
        tx = "rpc.gpon.trsv.info.status.US_TX_Power",
        rx_bytes = stats .. "rx_bytes",
        tx_bytes = stats .. "tx_bytes",
        rx_packets = stats .. "rx_packets",
        tx_packets = stats .. "tx_packets",
        rx_errors = stats .. "rx_errors",
        tx_errors = stats .. "tx_errors",
    }
    require("internethelper").getOptionalContent(content)
    for _, entry in ipairs(require("datamodel").get("rpc.gpon.stat.gtc.fec.") or {}) do
        content[entry.param] = entry.value
    end
    ngx.print("<fieldset><legend>", T"Physical link status", "</legend>")
    ngx.print(ui_helper.createLabel(T"GPON Status", content.status ~= "" and content.status or T"Unavailable"))
    local rx, tx = tonumber(content.rx), tonumber(content.tx)
    if rx then ngx.print(ui_helper.createLabel(T"OpticalSignalLevel", format("%.2f dBm", rx))) end
    if tx then ngx.print(ui_helper.createLabel(T"TransmitOpticalLevel", format("%.2f dBm", tx))) end
    ngx.print("</fieldset>")
    ngx.print("<fieldset><legend>", T"Network Statistics", "</legend>")
    local available = false
    for _, field in ipairs({
        {"rx_bytes", T"Rx Bytes"}, {"tx_bytes", T"Tx Bytes"},
        {"rx_packets", T"Rx Packets"}, {"tx_packets", T"Tx Packets"},
        {"rx_errors", T"Rx Errors"}, {"tx_errors", T"Tx Errors"},
        {"BIP_error", T"BIP errors"}, {"FEC_corrected_codewords", T"Corrected FEC codewords"},
        {"FEC_uncorrectable_codewords", T"Uncorrectable FEC codewords"},
    }) do
        local value = content[field[1]]
        if value and value:match("^%d+$") then
            if field[1] == "rx_bytes" or field[1] == "tx_bytes" then
                value = formatBytes(value)
            end
            ngx.print(ui_helper.createLabel(field[2], value))
            available = true
        end
    end
    if not available then ngx.print('<p class="muted">', T"Unavailable", '</p>') end
    ngx.print("</fieldset>")
    return
end
local ajax_attr = {
    span = {
        ["data-ajaxrefresh"] = "5",
        class = "span4"
    }
}

local mapParams = {
    gpon_state = "rpc.optical.Interface.1.Status",
    optical_signal_level = "rpc.optical.Interface.1.OpticalSignalLevel",
    transmit_optical_level = "rpc.optical.Interface.1.TransmitOpticalLevel",
    vendor_name = "rpc.optical.Interface.1.VendorName",
    interface_alias = "rpc.optical.Interface.1.Alias",
    bytes_sent = "rpc.optical.Interface.1.Stats.BytesSent",
    bytes_received = "rpc.optical.Interface.1.Stats.BytesReceived",
    packets_sent = "rpc.optical.Interface.1.Stats.PacketsSent",
    packets_received = "rpc.optical.Interface.1.Stats.PacketsReceived",
    discard_sent = "rpc.optical.Interface.1.Stats.DiscardPacketsSent",
    discard_received = "rpc.optical.Interface.1.Stats.DiscardPacketsReceived",
    errors_sent = "rpc.optical.Interface.1.Stats.ErrorsSent",
    errors_received = "rpc.optical.Interface.1.Stats.ErrorsReceived",

}
content_helper.getExactContent(mapParams)

local opticalBytes = format("%s %s %s %s", iconUp, formatBytes(mapParams.bytes_sent), iconDown, formatBytes(mapParams.bytes_received))
if ngx.var.request_method == "POST" and ngx.req.get_post_args().action == "AJAX-GET" then
    local function notnil(path)
        if path == nil or path == "" then
            return "0"
        end
        return path
    end
    local counters = {
        optical_bytes = opticalBytes,
        optical_packets = format("%s %s %s %s", iconUp, notnil(mapParams.packets_sent), iconDown, notnil(mapParams.packets_received)),
        optical_discard = format("%s %s %s %s", iconUp, notnil(mapParams.discard_sent), iconDown, notnil(mapParams.discard_received)),
        optical_errors = format("%s %s %s %s", iconUp, notnil(mapParams.errors_sent), iconDown, notnil(mapParams.errors_received)),
    }
    ngx.header.content_type = "application/json"
    ngx.print(require("dkjson").encode(counters))
    return ngx.exit(ngx.HTTP_OK)
end

local gpon_status = "connecting"
if mapParams.gpon_state == "Up" then
    gpon_status = "connected"
end

local gpon_light_map = {
    connecting = "orange",
    connected = "green",
}

  ngx.print('\
\
<fieldset>\
  <legend>');  ngx.print( T"Physical link status" ); ngx.print('</legend>\
\
  ');
    local html = {}
    -- Label that shows gpon status
    html[#html + 1] = ui_helper.createLight(T"Status",nil, T(mapParams["gpon_state"]), { light = { class = gpon_light_map[gpon_status] } })
    html[#html + 1] = ui_helper.createLabel(T"OpticalSignalLevel",(mapParams["optical_signal_level"]/1000).." dBm")
    html[#html + 1] = ui_helper.createLabel(T"TransmitOpticalLevel",(mapParams["transmit_optical_level"]/1000).." dBm")
    html[#html + 1] = ui_helper.createLabel(T"Vendor Name",mapParams["vendor_name"])
    html[#html + 1] = ui_helper.createLabel(T"Interface Alias",mapParams["interface_alias"])

    ajax_attr.span.id="optical_bytes"
    html[#html + 1] =
    ui_helper.createLabel(
            T"Bytes",
            opticalBytes,
            ajax_attr
    )
    ajax_attr.span.id="optical_packets"
    html[#html + 1] =
    ui_helper.createLabel(
            T"Packets",
            format("%s %s %s %s", iconUp, mapParams["packets_sent"], iconDown, mapParams["packets_received"]),
            ajax_attr
    )
    ajax_attr.span.id="optical_discard"
    html[#html + 1] =
    ui_helper.createLabel(
            T"Packets Discard",
            format("%s %s %s %s", iconUp, mapParams["discard_sent"], iconDown, mapParams["discard_received"]),
            ajax_attr
    )
    ajax_attr.span.id="optical_errors"
    html[#html + 1] =
    ui_helper.createLabel(
            T"Errors",
            format("%s %s %s %s", iconUp, mapParams["errors_sent"], iconDown, mapParams["errors_received"]),
            ajax_attr
    )

    ngx.print(html)
    ngx.print('\
</fieldset>\
');
