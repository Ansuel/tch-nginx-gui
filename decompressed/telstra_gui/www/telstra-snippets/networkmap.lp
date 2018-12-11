--pretranslated: do not change this file
 

local format,        find,        sub,        untaint =
string.format, string.find, string.sub, string.untaint
local floor, ipairs = math.floor, ipairs

-- Localization
gettext.textdomain('webui-telstra')

local content_helper = require("web.content_helper")
local proxy = require("datamodel")

local dcols = {
    {--[1]
        param = "State",
        type = "light",
    },
    {--[2]
        param = "HostName",
        type = "text",
    },
    {--[3]
        param = "IPAddress",
        type = "text",
    },
    {--[4]
        param = "MACAddress",
        type = "text",
    },
    {--[5]
        param = "InterfaceType",
        type = "text",
    },
    {--[6]
        param = "Port",
        type = "text",
    },
    {--[7]
        param = "Speed",
        type = "text",
    },
    {--[8]
        param = "L2Interface",
        type = "text",
    },
    {--[9]
        param = "tod.enabled",
        type = "switch",
    },
    {--[10]
        param = "tod.mode",
        type = "select",
    },
    {--[11]
        param = "tod.start_time",
        type = "text",
    },
    {--[12]
        param = "tod.stop_time",
        type = "text",
    },
    {--[13]
        param = "tod.weekdays",
        type = "checkboxgroup",
    },
    {--[14]
        param = "L3Interface",
        type = "text",
    },
}
-- Button for hide/ unhide non-connected device
-- by default is un-hide un-connected device
local hide_non_connected_flag = 0
local hidedevicetext = "Hide non-connected Device"
if ngx.req.get_method() == "POST" then
    local args = ngx.req.get_post_args();
    if not (args["hide_unhide_non_connected_device"] == nil and args["button_new_text"] == nil) then
        hide_non_connected_flag = args["hide_unhide_non_connected_device"]
        hidedevicetext = args["button_new_text"]
    end
end

local hideunhidedevicehtml = string.format('<input id="hide-unhide-non-connected-device" class="btn"" value="%s"/>', hidedevicetext)

-- Button for Delete non-connected device, by default , not delete the non-connected device , value is 0
local delete_non_connected_flag = 0
if ngx.req.get_method() == "POST" then
    local args = ngx.req.get_post_args();
    delete_non_connected_flag = args["delete_non_connected_device"]
end

local deletedevicehtml = string.format('<input id="delete-non-connected-device" class="btn"" value="Delete non-connected Device"/>')

-- Load all known network devices
local devices, indexes = content_helper.loadTableData("sys.hosts.host.", dcols)

local uri = ngx.var.uri
local getargs = ngx.req.get_uri_args()
local wired = {}
local wireless = {}

for k,v in ipairs(devices) do
    local ticked
    local tooltip
    local iswireless
    if not (v[1] == "0" and hide_non_connected_flag == "1")  then
        tooltip = string.format("LAN IP: %s<br />Device Name: %s<br />Link Speed: %s Mbps", v[3], v[2], v[7])

        if v[1] == "1" then
            ticked = "_ticked"
        else
            ticked = ""
        end
        if v[5] == "wireless" then
            iswireless = "1"
        else
            iswireless = "0"
        end

        local html = string.format('<div class="device"><a href=telstra-modals/device.lp?mac=%s&wireless=%s&ticked=%s><img src="/img/telstra/dev_laptop%s.gif"/></a><div class="deviceinfo right">%s</div><div><br /></div></div>', v[4], iswireless, ticked, ticked, tooltip)

        if v[5] == "wireless" then
            if uri == "telstra-modals/wifi.lp" then
                if (getargs.radio=="2.4") and (v[8]=="wl0") then
                    wireless[#wireless+1] = html
                elseif (getargs.radio=="5") and (v[8]=="wl1") then
                    wireless[#wireless+1] = html
                end
            elseif uri == "telstra-modals/wifiguest.lp" then
                if (getargs.guest=="2g_1") and (v[8]=="wl0_1") then
                    wireless[#wireless+1] = html
                elseif (getargs.guest=="5g_1") and (v[8]=="wl1_1") then
                    wireless[#wireless+1] = html
                end
            else
                if ((v[8]=="wl0") or (v[8]=="wl1")) then
                    wireless[#wireless+1] = html
                end
            end
        else
            if uri ~= "telstra-modals/wifiguest.lp" then
                if(v[14]=="br-lan") then
                    wired[#wired+1] = html
                end
            else   --Interface type for Guest1 and Guest1_5G is ethernet, and l3interface is wl0_1 and wl1_1
                if (getargs.guest=="2g_1") and (v[14]=="wl0_1") then
                    wireless[#wireless+1] = html
                elseif (getargs.guest=="5g_1") and (v[14]=="wl1_1") then
                    wireless[#wireless+1] = html
                end
            end
        end
    end
end

-- Delete the non-connected device via UCI

if delete_non_connected_flag == 1 then

end

local usbcols = {
    {
        param = "product",
        type = "text",
    },
    {
        param = "manufacturer",
        type = "text",
    },
    {
        param = "path",
        type = "text",
    },
    {
        param = "version",
        type = "text",
    },
    {
        param = "speed",
        type = "text",
    },
    {
        param = "idVendor",
        type = "text",
    },
    {
        param = "idProduct",
        type = "text",
    },
}
-- Load all known usb devices
local usbdevices = content_helper.loadTableData("sys.usb.device.", usbcols)

local utils = require("web.lte-utils")
local device_info = utils.getContent("rpc.mobiled.device.@1.info.")
local env = { model = "uci.env.var.embedded_mobile", }
content_helper.getExactContent(env)
local usb = {}
for k,v in ipairs(usbdevices) do
    local tooltip
    local port = "High Power"

    if uri == "/wifiguest.lp" then break end --don't show usb devices in wifiguest page
-- don't show embedded Huawei mobile on basic GUI
    if device_info.model ~= env["model"] or v[6] ~= device_info.vid or v[7] ~= device_info.pid then
        tooltip = string.format("Product Name: %s<br />Manufacturer: %s<br />Port: %s", v[1], v[2], port)
        usb[#usb+1] = string.format('<div class="device"><img src="/img/telstra/dev_usb.png"/><div class="deviceinfo right">%s</div><div><br /></div></div>', tooltip)
    end
end

--Load all connected dect devices:
local dectcols = {
    {--[1]
        param = "IPUI",
        type = "text",
    },
    {--[2]
        param = "FriendlyName",
        type = "text",
    },
    {--[3]
        param = "LocationStatus",
        type = "text",
    },
}

local dectdevices, indexes = content_helper.loadTableData("sys.dect.dev.", dectcols)

local dect = {}
for _,v in ipairs(dectdevices) do
    local tooltip
    local port = ""

    if uri == "/wifiguest.lp" then break end --don't show dect devices in wifiguest page

    if v[3] == "Located" then
        tooltip = string.format("Handset ID: %s<br />Friendly Name: %s>", v[1], v[2])
        dect[#dect+1] = string.format('<div class="device"><img src="/img/telstra/dev_dectphone.png"/><div class="deviceinfo right">%s</div><div><br /></div></div>', tooltip)
    end
end

local wan_intf = "wan"
local content_wwan = {
  ipaddr = "rpc.network.interface.@wwan.ipaddr",
}
content_helper.getExactContent(content_wwan)

if content_wwan.ipaddr:len() ~= 0 then
  wan_intf = "wwan"
end

-- Load other parameters
local content = {
    wanip = "rpc.network.interface.@" .. wan_intf .. ".ipaddr",
    wan_ll_intf = "rpc.network.interface.@" .. wan_intf .. ".ppp.ll_intf",
    lanip = "uci.network.interface.@lan.ipaddr",
    fwversion = "uci.version.version.@version[0].version",
    hostname = "uci.system.system.@system[0].hostname",
}
content_helper.getExactContent(content)

if content.fwversion then
    local version = content.fwversion
    content.fwversion = sub(version, 1, find(version, "%-") - 1)
end

local wan_type = "Ethernet"
if find(content.wan_ll_intf, "atm_") == 1 then
   wan_type = "ADSL"
elseif find(content.wan_ll_intf, "ptm") == 1 then
   wan_type = "VDSL"
elseif wan_intf == "wwan" then
   wan_type = "Mobile"
end

local wanhtml = string.format('WAN IP: <font color="green"><strong>%s</strong></font><br />Conn. type: %s', content.wanip, wan_type)
local gwhtml = string.format('Router IP: %s<br />Hostname: %s<br />FW Version: %s', content.lanip, content.hostname, content.fwversion)

local wifihtml = {}
local radio, wl, ap

if uri == "/wifi.lp" then
    if getargs.radio == "2.4" then
        radio = "radio_2G"
        wl = "wl0"
        ap = "ap0"
    else
        radio = "radio_5G"
        wl = "wl1"
        ap = "ap1"
    end
elseif uri == "/wifiguest.lp" then
    if getargs.guest == "2g_1" then
        radio = "radio_2G"
        wl = "wl0_1"
        ap = "ap2"
    elseif getargs.guest == "5g_1" then
        radio = "radio_5G"
        wl = "wl1_1"
        ap = "ap3"
    end
end

--in wifi page or wifiguest page, only show the related wifi info
local function s2n(str)
  if str == "" or str == nil then
    return 0
  else
    return tonumber(str)
  end
end

if ((uri == "/wifi.lp") or (uri == "/wifiguest.lp")) then
    local wifibase, wifisec, wifistate
    local app = "uci.wireless.wifi-ap.@" .. ap .. "."
    local content_wifi = {
        wifistate = app .. "state",
        wifissid = "uci.wireless.wifi-iface.@" .. wl .. ".ssid",
        wifipsk = app .. "wpa_psk_key",
        wifiwep = app .. "wep_key",
        wifisecmode = app .."security_mode",
        wifispeed = "rpc.wireless.radio.@" .. radio .. ".phy_rate",
        radiostate = "uci.wireless.wifi-device.@" .. radio .. ".state",
    }
    content_helper.getExactContent(content_wifi)
    --The wifispeed value should NOT be nil
    content_wifi.wifispeed = s2n(content_wifi.wifispeed) / 1000
    wifibase = string.format("Wi-Fi Name: %s<br />", content_wifi.wifissid)
    wifisec = ""
    wifistate = ""
    if content_wifi.wifistate == "1" and content_wifi.radiostate == "1"  then
        wifistate = string.format("Wi-Fi Status: On<br />Wi-Fi Link Speed: %s Mbps", content_wifi.wifispeed)
        if string.find(content_wifi.wifisecmode, "wep") then
            wifisec = string.format("Wi-Fi Key: %s<br />", content_wifi.wifiwep)
        end
        if string.find(content_wifi.wifisecmode, "psk") then
            wifisec = string.format("Wi-Fi Key: %s<br />", content_wifi.wifipsk)
        end
    else
        wifistate = "Wi-Fi Status: Off"
    end

    wifihtml[#wifihtml+1] = string.format('<div class="deviceinfo left">%s%s%s</div>', wifibase, wifisec, wifistate)
else --in other pages, display both 2.4G and 5G info
    local wifibase, wifisec, wifistate,wifibase_5g, wifisec_5g, wifistate_5g
    local content_wifi = {
        wifistate = "uci.wireless.wifi-ap.@ap0.state",
        wifissid = "uci.wireless.wifi-iface.@wl0.ssid",
        wifipsk = "uci.wireless.wifi-ap.@ap0.wpa_psk_key",
        wifiwep = "uci.wireless.wifi-ap.@ap0.wep_key",
        wifisecmode = "uci.wireless.wifi-ap.@ap0.security_mode",
        wifispeed = "rpc.wireless.radio.@radio_2G.phy_rate",
        radiostate = "uci.wireless.wifi-device.@radio_2G.state",
    }
    --check whether the 5G exists. 
    local line_through = ""
    local dev_5g = proxy.get("uci.wireless.wifi-device.@radio_5G.")

    if dev_5g ~= nil then
       content_wifi.wifistate_5g = "uci.wireless.wifi-ap.@ap1.state"
       content_wifi.wifissid_5g = "uci.wireless.wifi-iface.@wl1.ssid"
       content_wifi.wifipsk_5g = "uci.wireless.wifi-ap.@ap1.wpa_psk_key"
       content_wifi.wifiwep_5g = "uci.wireless.wifi-ap.@ap1.wep_key"
       content_wifi.wifisecmode_5g = "uci.wireless.wifi-ap.@ap1.security_mode"
       content_wifi.wifispeed_5g = "rpc.wireless.radio.@radio_5G.phy_rate"
       content_wifi.radiostate_5g = "uci.wireless.wifi-device.@radio_5G.state"
    end
    content_helper.getExactContent(content_wifi)
    content_wifi.wifispeed = s2n(content_wifi.wifispeed) / 1000
    content_wifi.wifispeed_5g = s2n(content_wifi.wifispeed_5g) / 1000

    wifibase = string.format("2.4G Wi-Fi Name: %s<br />", content_wifi.wifissid)
    wifisec = ""
    wifistate = ""
    if content_wifi.wifistate == "1" and content_wifi.radiostate == "1" then
        wifistate = string.format("2.4G Wi-Fi Status: On<br />2.4G Wi-Fi Link Speed: %s Mbps", content_wifi.wifispeed)
        if string.find(content_wifi.wifisecmode, "wep") then
            wifisec = string.format("2.4G Wi-Fi Key: %s<br />", content_wifi.wifiwep)
        end
        if string.find(content_wifi.wifisecmode, "psk") then
            wifisec = string.format("2.4G Wi-Fi Key: %s<br />", content_wifi.wifipsk)
        end
    else
        wifistate = "2.4G Wi-Fi Status: Off"
    end

    wifibase_5g = content_wifi.wifissid_5g and string.format("5G Wi-Fi Name: %s<br />", content_wifi.wifissid_5g) or ""
    wifisec_5g = ""
    wifistate_5g = ""
    if dev_5g ~= nil then
       line_through = '<div style="text-decoration:line-through">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<br /></div>'
       if content_wifi.wifistate_5g == "1" and content_wifi.radiostate_5g == "1" then
          wifistate_5g = string.format("5G Wi-Fi Status: On<br />5G Wi-Fi Link Speed: %s Mbps", content_wifi.wifispeed_5g)
          if string.find(content_wifi.wifisecmode_5g, "wep") then
              wifisec_5g = string.format("5G Wi-Fi Key: %s<br />", content_wifi.wifiwep_5g)
          end
          if string.find(content_wifi.wifisecmode_5g, "psk") then
              wifisec_5g = string.format("5G Wi-Fi Key: %s<br />", content_wifi.wifipsk_5g)
          end
       else
          wifistate_5g = "5G Wi-Fi Status: Off"
       end
    end
    wifihtml[#wifihtml+1] = string.format('<div id="ap_info" class="apinfo longleft">%s%s%s%s%s%s%s</div>', wifibase, wifisec, wifistate, line_through, wifibase_5g, wifisec_5g, wifistate_5g)
end


  ngx.print('\
\
<div class="container">\
    <div class="row">\
        <br />\
        <div class="networkmap span11" id="networkmap">\
            <table class="table">\
                <tbody>\
                    <tr>\
                        <td colspan="8">\
                            ');  
                               if ((uri ~= "/wifi.lp") and (uri ~= "/wifiguest.lp")) then
                                  ngx.print(wifihtml)
                               end
                              ngx.print('\
                            <div class="device">\
                                <img class="devicepicture" src="/img/telstra/globe.png"/>\
                                <div class="deviceinfo right">');  ngx.print(wanhtml); ngx.print('</div>\
                            </div>\
                        </td>\
                    </tr>\
                    <tr>\
                        <td colspan="4" style="border-right-style:solid">&nbsp;</td>\
                        <td colspan="4">&nbsp;</td>\
                    </tr>\
                    <tr>\
                        <td colspan="8">\
                            <div id="gateway" class="device">\
                                 ');  
                                   if ((uri == "/wifi.lp") or (uri == "/wifiguest.lp")) then
                                      ngx.print(wifihtml)
                                   end
                                   ngx.print('\
                                <img class="devicepicture" src="/img/telstra/gw-telstra.png"/>\
                                <div class="deviceinfo right">');  ngx.print(gwhtml); ngx.print('</div>\
                            </div>\
                        </td>\
                    </tr>\
                    <tr>\
                        <td colspan="4" style="border-right-style:solid">&nbsp;</td>\
                        <td colspan="3" style="border-bottom-style:solid">&nbsp;</td>\
                        <td colspan="1">&nbsp;</td>\
                    </tr>\
                    <tr>\
                        <td>&nbsp;</td>\
                        <td colspan="2" style="border-style:dashed none none dashed">&nbsp;</td>\
                        <td colspan="1" style="border-style:dashed solid solid none">&nbsp;</td>\
                        <td colspan="1" style="border-bottom-style:solid">&nbsp;</td>\
                        <td colspan="2" style="border-bottom-style:none">&nbsp;</td>\
                        <td colspan="1" style="border-left-style:solid">&nbsp;</td>\
                    </tr>\
                    <tr>\
                        <td>&nbsp;</td>\
                        <td style="border-style:none none none dashed">&nbsp;</td>\
                        <td>&nbsp;</td>\
                        <td colspan="2" style="border-style:none solid none solid">&nbsp;</td>\
                        <td>&nbsp;</td>\
                        <td style="border-style:none solid none none">&nbsp;</td>\
                        <td>&nbsp;</td>\
                    </tr>\
                    <tr>\
                        <td colspan="2" class="networkinterface">\
                            <div class="devicelist">\
                                <div class="interface-name">Wi-Fi</div>\
                                <div>\
                                    ');  ngx.print(wireless)   ngx.print('\
                                </div>\
                            </div>\
                        </td>\
                        <td colspan="2" class="networkinterface">\
                            <div class="devicelist">\
                                <div class="interface-name">Ethernet/Wired</div>\
                                <div>\
                                    ');  ngx.print(wired)   ngx.print('\
                                </div>\
                            </div>\
                        </td>\
                        <td colspan="2" class="networkinterface">\
                            <div class="devicelist">\
                                <div class="interface-name">USB</div>\
                                <div>\
                                    ');  ngx.print(usb)   ngx.print('\
                                </div>\
                            </div>\
                        </td>\
                        <td colspan="2" class="networkinterface">\
                            <div class="devicelist">\
                                <div class="interface-name">DECT</div>\
                                <div>\
                                    ');  ngx.print(dect)   ngx.print('\
                                </div>\
                            </div>\
                        </td>\
                    </tr>\
                </tbody>\
            </table>\
            <div align="right">\
                <tr>\
                    <div>\
                        ');  ngx.print(hideunhidedevicehtml)   ngx.print('\
                    </div>\
                </tr>\
            </div>\
        </div>\
    </div>\
</div>\
<script src="/js/srp-min.js"></script>\
<script type="text/javascript">\
    var hoveronly_flag = false;\
\
    function showhideTooltips()\
    {\
        hoveronly_flag = false;\
        setTimeout(function() {\
            $(".deviceinfo").addClass("hoveronly");\
            $("#ap_info").addClass("hoveronly");\
            hoveronly_flag = true;\
        }, 15000);\
    }\
\
    $(window).load(function() {\
        showhideTooltips();\
    });\
    $(window).resize(function() {\
        showhideTooltips();\
    });\
\
    $("#gateway").mouseover(function(){\
        if (hoveronly_flag) {\
           $("#ap_info").removeClass("hoveronly");\
           $("#ap_info").addClass("showinfo");\
        }\
      });\
\
    $("#gateway").mouseout(function(){\
        if (hoveronly_flag) {\
           $("#ap_info").removeClass("showinfo");\
           $("#ap_info").addClass("hoveronly");\
        }\
      });\
\
    $(document).on("click", "#hide-unhide-non-connected-device", function() {\
        var button = $(this);\
        var button_text = button.val();\
        var hide_non_connected_device = 0;\
        if(button_text == "Hide non-connected Device")  {\
            button.val("Unhide non-connected Device");\
            hide_non_connected_device = 1;\
        } else {\
            button.val("Hide non-connected Device");\
            hide_non_connected_device = 0;\
        }\
        button_new_text = button.val();\
        var form = $("form");\
        var params = form.serializeArray();\
        params.push({\
            name : "hide_unhide_non_connected_device",\
            value : hide_non_connected_device\
        });\
        params.push({\
            name : "button_new_text",\
            value : button_new_text\
        });\
        params.push({\
            name : "action",\
            value : "SAVE"\
        });\
        params.push(tch.elementCSRFtoken());\
        var target = form.attr("action");\
        tch.postParams(target,params);\
        }\
    );\
\
    $(document).on("click", "#delete-non-connected-device", function() {\
        var form = $("form");\
        var params = form.serializeArray();\
        params.push({\
            name : "delete_non_connected_device",\
            value : 1\
        });\
        params.push({\
            name : "action",\
            value : "SAVE"\
        });\
        params.push(tch.elementCSRFtoken());\
        var target = form.attr("action");\
        tch.postParams(target,params);\
        }\
    );\
\
\
</script>\
'); 