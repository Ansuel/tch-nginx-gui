--pretranslated: do not change this file

-- Enable localization

gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

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
    discarderd_sent = "rpc.optical.Interface.1.Stats.DiscardPacketsSent",
    discarderd_received = "rpc.optical.Interface.1.Stats.DiscardPacketsReceived",
    errors_sent = "rpc.optical.Interface.1.Stats.ErrorsSent",
    errors_received = "rpc.optical.Interface.1.Stats.ErrorsReceived",

}
content_helper.getExactContent(mapParams)

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
    html[#html + 1] = ui_helper.createLabel(T"Bytes", '<i class="fa fa-download"></i> '..mapParams["bytes_sent"]..'<i class="fa fa-upload"></i> '..mapParams["bytes_received"])
    html[#html + 1] = ui_helper.createLabel(T"Packets", '<i class="fa fa-download"></i> '..mapParams["packets_received"]..'<i class="fa fa-upload"></i> '..mapParams["packets_sent"])
    html[#html + 1] = ui_helper.createLabel(T"Packets Discard", '<i class="fa fa-download"></i> '..mapParams["discarderd_received"]..'<i class="fa fa-upload"></i> '..mapParams["discarderd_sent"])
    html[#html + 1] = ui_helper.createLabel(T"Errors", '<i class="fa fa-download"></i> '..mapParams["errors_received"]..'<i class="fa fa-upload"></i> '..mapParams["errors_sent"])
    ngx.print(html)
    ngx.print('\
</fieldset>\
');
