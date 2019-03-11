--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local tonumber = tonumber

local lfs = require("lfs")
local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local format, find, sub, match = string.format, string.find, string.sub, string.match

-- Devices data
local devices_data = {
  numWireless = "sys.hosts.ActiveWirelessNumberOfEntries",
  numEthernet = "sys.hosts.ActiveEthernetNumberOfEntries",
}
content_helper.getExactContent(devices_data)

local modalPath = nil
local switchName = nil
local modal_link = ""
local wireless_modal_link = ""
local traffic_monitor_link = ""
local session = ngx.ctx.session
if session:hasAccess("/modals/device-modal.lp") then
  modalPath = "/modals/device-modal.lp"
  modal_link='class="modal-link" data-toggle="modal" data-remote="/modals/device-modal.lp" data-id="device-modal"'
  wireless_modal_link='class="modal-link" data-toggle="modal" data-remote="/modals/wifi-nurse-modal.lp" data-id="device-modal"'
  traffic_monitor_link='class="modal-link" data-toggle="modal" data-remote="/modals/traffic-monitor.lp" data-id="device-modal"'
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print( ui_helper.createCardHeader(T"Devices", modalPath, switchName, nil)  ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf1e6;">\
	<div class="divtable">\
      ');  local Hotspot_len = {}
        local ap_path = "rpc.wireless.ap."
        local ap_path_value = content_helper.convertResultToObject(ap_path,proxy.get(ap_path))
        for _,v in ipairs(ap_path_value) do
          if match(v.ssid, "wl%d_%d") then
            local ap = match(v.paramindex, "@([^%.]+)")
            local station_path = "rpc.wireless.ap.@" .. ap .. ".station."
            local station_path_value = content_helper.convertResultToObject(station_path,proxy.get(station_path))
            for _,v in ipairs(station_path_value) do
              if v.state == "Authenticated Associated" then
                Hotspot_len[#Hotspot_len+1] = v.state
              end
            end
          end
        end
        local nEth = tonumber(devices_data["numEthernet"]) or 0
        local nWiFi = tonumber(devices_data["numWireless"]) or 0
        local nHot = #Hotspot_len or 0
        ngx.print(
            '<p class="subinfos">',
            '<i style="margin-left:-20px;" class="fa fa-link" aria-hidden="true" href="#">&nbsp</i>',
            format( N('<strong id = "Ethernet_Devices" %1$s>%2$d Ethernet device</strong> connected',
                      '<strong id = "Ethernet_Devices" %1$s>%2$d Ethernet devices</strong> connected', nEth),
                      modal_link, nEth),
            '</p>',
            '<p class="subinfos">',
            '<i style="margin-left:-20px;" class="fa fa-wifi" aria-hidden="true" href="#">&nbsp</i>',
            format( N('<strong id = "Wifi_Devices" %1$s>%2$d Wi-Fi device</strong> connected',
                      '<strong id = "Wifi_Devices" %1$s>%2$d Wi-Fi devices</strong> connected', nWiFi),
                      wireless_modal_link, nWiFi),
			'</p>',
			'<p class="subinfos">',
				'<i style="margin-left:-20px;" class="fas fa-chart-line" href="#">&nbsp</i>',
				format( '<strong id = "Traffic_Monitor" %1$s>%s</strong>', traffic_monitor_link, T"Traffic Monitor"),
				--'<div data-toggle="modal" data-remote="/modals/diagnostics-xdsl-graphics-modal.lp" data-id="iagnostics-xdsl-graphics-modal">',
				--	,T("Traffic Monitor"),
				--'</div>',
            '</p>'
--NG-89441            '</p>',
--NG-89441           '<p class="subinfos">',
--NG-89441            format( N('<strong id = "Ethernet_Devices" %1$s>%2$d Hotspot device</strong> connected',
--NG-89441                     '<strong id = "Ethernet_Devices" %1$s>%2$d Hotspot devices</strong> connected', nHot),
--NG-89441                     modal_link, nHot),
--           '</p>'
        )
--NG-89441,7725_upstep        if lfs.attributes("/etc/config/hotspot", "mode") == "file" then  ngx.print('                                     \
--NG-89441,7725_upstep           <p class="subinfos">                                                             \
--NG-89441,7725_upstep           '); 
--NG-89441,7725_upstep           ngx.print(format( N('<strong id = "Ethernet_Devices" %1$s>%2$d Hotspot device</strong> connected',             
--NG-89441,7725_upstep                               '<strong id = "Ethernet_Devices" %1$s>%2$d Hotspot devices</strong> connected', nHot),     
--NG-89441,7725_upstep                                modal_link, nHot))
--NG-89441,7725_upstep             ngx.print('\
--NG-89441,7725_upstep           </p>\
--NG-89441,7725_upstep      %>\
--NG-89441,7725_upstep
        ngx.print('\
    </div>\
	</div>\
  </div>\
</div>\
'); 