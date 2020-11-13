--pretranslated: do not change this file

-- Enable localization

gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format
local tonumber = tonumber

local iconUp = "<i class=\"icon-upload icon-large gray\"></i> "
local iconDown = "<i class=\"icon-download icon-large gray\"></i> "
local ajax_helper = require("web.ajax_helper")
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

ajax_helper.handleAjaxQuery({}, function(c)
    local function notnil(path)
        if path == nil or path == "" then
            return "0"
        end
        return path
    end
    c.optical_bytes = format("%s %s %s %s", iconUp, notnil(mapParams.bytes_sent), iconDown, notnil(mapParams.bytes_received))
    c.optical_packets = format("%s %s %s %s", iconUp, notnil(mapParams.packets_sent), iconDown, notnil(mapParams.packets_received))
    c.optical_discard = format("%s %s %s %s", iconUp, notnil(mapParams.discard_sent), iconDown, notnil(mapParams.discard_received))
    c.optical_errors = format("%s %s %s %s", iconUp, notnil(mapParams.errors_sent), iconDown, notnil(mapParams.errors_received))
end)

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
            format("%s %s %s %s", iconUp, mapParams["bytes_sent"], iconDown, mapParams["bytes_received"]),
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
