--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")								  
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local string, ngx, os = string, ngx, os
local tonumber = tonumber
local format, match = string.format, string.match
local traffic_data_file = "/var/state/traffic_data_file"

local getargs = ngx.req.get_uri_args()
local getiface = getargs.iface

local curiface = "wl0"
local curssid = ""

local fonpath = "uci.hotspotd.wifi-iface."
local fonifaces = content_helper.convertResultToObject(fonpath .. "@.", proxy.get(fonpath))

local ssidMap = {}

for i,v in ipairs(fonifaces) do
    local iface = string.format("%s", v.iface)
    ssidMap[iface] = true
end

local piface = "uci.wireless.wifi-iface."
local awls = content_helper.convertResultToObject(piface .. "@.", proxy.get(piface))
local wls = {}
for i,v in ipairs(awls) do
    if not ssidMap[v.paramindex] then
        wls[#wls+1] = {
            radio = v.device,
            ssid = v.ssid,
            iface = v.paramindex
        }
        if v.paramindex == getiface then
            curiface = v.paramindex
			if curiface == "wl1" then
				curiface = "eth5"
			end
            curssid = v.ssid
        end
    end
end
table.sort(wls, function(a,b)
    if a.radio == b.radio then
        return a.iface < b.iface
    else
        return a.radio < b.radio
    end
end)

local wan_intf ="wan"
local ipaddr = proxy.get("rpc.network.interface.@wwan.ipaddr")[1].value
if ipaddr:len() ~= 0 then
  wan_intf = "wwan"
end

local content_wan = {
  tx_bytes = "rpc.network.interface.@" .. wan_intf .. ".tx_bytes",
  rx_bytes = "rpc.network.interface.@" .. wan_intf .. ".rx_bytes",
  ifname = "uci.network.interface.@" .. wan_intf .. ".ifname",
}
content_helper.getExactContent(content_wan)

local content_lan = {
  tx_bytes = "rpc.network.interface.@lan.tx_bytes",
  rx_bytes = "rpc.network.interface.@lan.rx_bytes",
  ifname = "uci.network.interface.@lan.ifname",
}
content_helper.getExactContent(content_lan)

local function s2n(str)
  if str == nil or str == "" then
    return 0
  else
    return tonumber(str)
  end
end

local function b2m(number)
  return format("%.3f", number / 1048576)
end

local function getFile(file_name)
  local fd = io.open(file_name,"r")
  local values = {}
    if fd  then
       for l in fd:lines() do
         values[#values+1] = l
      end
      fd:close()
      return values
    else
      return nil
    end
end


local wantx = b2m(s2n(content_wan.tx_bytes))
local wanrx = b2m(s2n(content_wan.rx_bytes))
local lantx = b2m(s2n(content_lan.tx_bytes))
local lanrx = b2m(s2n(content_lan.rx_bytes))

local wifitx, wifirx = 0, 0
local content_wifi = {}
for i,v in ipairs(wls) do
    content_wifi["tx_bytes"] = "sys.class.net.@" .. v.iface .. ".statistics.tx_bytes"
    content_wifi["rx_bytes"] = "sys.class.net.@" .. v.iface .. ".statistics.rx_bytes"
    content_helper.getExactContent(content_wifi)
    wifitx = wifitx + s2n(content_wifi.tx_bytes)
    wifirx = wifirx + s2n(content_wifi.rx_bytes)
end
wifitx = b2m(wifitx)
wifirx = b2m(wifirx)

local content_result = getFile(traffic_data_file)
if content_result then
  if s2n(content_result[2]) > s2n(wanrx)  then
     content_result[1] = content_result[1]+1
  end
  if s2n(content_result[4]) > s2n(wantx)  then
     content_result[3] = content_result[3]+1
  end
  if s2n(content_result[6]) > s2n(lanrx)  then
     content_result[5] = content_result[5]+1
  end
  if s2n(content_result[8]) > s2n(lantx)  then
     content_result[7] = content_result[7]+1
  end
  if s2n(content_result[10]) > s2n(wifirx)  then
     content_result[9] = content_result[9]+1
  end
  if s2n(content_result[12]) > s2n(wifitx)  then
     content_result[11] = content_result[11]+1
  end
  wanrx = wanrx+content_result[1]*4096
  wantx = wantx+content_result[3]*4096
  lanrx = lanrx+content_result[5]*4096
  lantx = lantx+content_result[7]*4096
  wifirx = wifirx+content_result[9]*4096
  wifitx = wifitx+content_result[11]*4096
end

local wantotal = format("%.3f", wantx + wanrx)
local lantotal = format("%.3f", lantx + lanrx)
local wifitotal = format("%.3f", wifitx + wifirx)

local function getTrafficData(dtype, name)
    local nline = 1
    local data = ""
    filename = string.format("/tmp/trafficmon/%s_%s", name, dtype)
    f = io.open(filename, "r")
    if f then
        for line in f:lines() do
            if (nline == 1) then
                nline = 2
            elseif (nline == 2) then
                nline = 3
                data = line
            else
                data = data .. "," .. line
            end
        end
        f:close()
    end
    return data
end

local wanTx, wanRx, lanTx, lanRx, wifiTx, wifiRx
proxy.set("rpc.system.lock.datadir", "/tmp/trafficmon/")

_, wanTx = pcall(getTrafficData, "tx_bytes", content_wan.ifname)
_, wanRx = pcall(getTrafficData, "rx_bytes", content_wan.ifname)
_, lanTx = pcall(getTrafficData, "tx_bytes", "br-lan")
_, lanRx = pcall(getTrafficData, "rx_bytes", "br-lan")
_, wifiTx = pcall(getTrafficData, "tx_bytes", curiface)
_, wifiRx = pcall(getTrafficData, "rx_bytes", curiface)
proxy.set("rpc.system.lock.free", "0")

ngx.print('<script src ="/js/graphic-min.js"></script>')

ngx.print(ui_helper.createHeader(T"Traffic Monitor", false, false) ); ngx.print('\
<div class="modal-body update no-save">\
');
if ngx.ctx.session:hasAccess("/modals/hostmap-modal.lp") then
    local tabs = {
        {
            desc = T"Devices List",
            target = "modals/device-modal.lp",
        },
        {
            desc = T"Devices Map",
            target = "modals/hostmap-modal.lp",
        },
		{
            desc = T"WiFi Nurse",
            target = "modals/wifi-nurse-modal.lp",
        },
		{
            desc = T"Traffic Monitor",
			active = "active",
            target = "modals/traffic-monitor.lp",
        },
    }
    ngx.print(ui_helper.createModalTabs(tabs))
end
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/traffic-monitor.lp">\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      local html = {}
	  local attributes = {
			label = { class = "control-label" } ,
			span = { class = "span1 text-right" } ,
			}
	  html[#html+1] = '<div class="span3">'
	  html[#html+1] = "<fieldset><legend>" .. T"Internet Traffic" .. "</legend>"
	  html[#html+1] = ui_helper.createLabel(T"Total Mixed (in MB)", wantotal , attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Send (in MB)", wantx, attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Receive (in MB)", wanrx, attributes)
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "</div>"
	  html[#html+1] = '<div class="span3">'
	  html[#html+1] = "<fieldset><legend>" .. T"Ethernet Network Traffic" .. "</legend>"
	  html[#html+1] = ui_helper.createLabel(T"Total Mixed (in MB)", lantotal , attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Send (in MB)", lantx, attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Receive (in MB)", lanrx, attributes)
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "</div>"
	  html[#html+1] = '<div class="span3">'
	  html[#html+1] = "<fieldset><legend>" .. T"Wi-Fi Network Traffic" .. "</legend>"
	  html[#html+1] = ui_helper.createLabel(T"Total Mixed (in MB)",  wifitotal , attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Send (in MB)", wifitx, attributes)
	  html[#html+1] = ui_helper.createLabel(T"Total Receive (in MB)", wifirx, attributes)
	  html[#html+1] = "</fieldset>"
	  html[#html+1] = "</div>"
	  html[#html+1] = "<fieldset><legend>" .. T"Graph" .. "</legend>"
	  html[#html+1] = [[
					<table>
					<tr>
						<td style="background-color:red">&nbsp;&nbsp;&nbsp;&nbsp;</td>
						<td nowrap>Total Send/Receive<input type="checkbox" id="redLine" name="redLine" checked onclick="redrawLine()"/></td>
						<td style="background-color:green">&nbsp;&nbsp;&nbsp;&nbsp;</td>
						<td nowrap>Total Send<input type="checkbox" id="greenLine" name="greenLine" checked onclick="redrawLine()"/></td>
						<td style="background-color:blue">&nbsp;&nbsp;&nbsp;&nbsp;</td>
						<td nowrap>Total Receive<input type="checkbox" id="blueLine" name="blueLine" checked onclick="redrawLine()"/></td>
						<td width="40%">&nbsp;</td>
					</tr>
					</table>]]
	html[#html+1] = "</fieldset>"
	html[#html+1] = "<fieldset><legend>" .. T"WAN Graph" .. "</legend>"
	html[#html+1] = [[<div id="wanTraffic">
				<div id ="wanLineDiv" style ="position:relative;height:350px;width:600px;"></div>
				</div>
				]]
	html[#html+1] = "</fieldset>"
	html[#html+1] = "<fieldset><legend>" .. T"LAN Graph" .. "</legend>"
	html[#html+1] = [[<div id="lanTraffic">
				<div id ="lanLineDiv" style ="position:relative;height:350px;width:600px;"></div>
				</div>
				]]
	html[#html+1] = "</fieldset>"
	ngx.print(html)
	local html = {}
    html[#html+1] = '<ul class="nav nav-tabs">'
    for i,v in ipairs(wls) do
        local active = ""
        if v.iface == curiface or ( v.iface == "wl1" and curiface == "eth5" ) then
            active = "active"
        end
        local url = "modals/traffic-monitor.lp?iface=" .. v.iface
        html[#html+1] = format('<li class="%s"><a id ="%s" href="#" data-remote="%s">%s</a></li>', active, v.iface , url, v.ssid)
    end
    html[#html+1] =  "</ul>"
	html[#html+1] =  '<div id="wifiTraffic">\
				<div id="wifiLineDiv" style="position:relative;height:350px;width:900px;"></div>\
				</div>'
	  ngx.print(html)
	  
	  ngx.print('\
  </form>\
 </div>\
\
	<script language ="javascript">\
	var wanLine, lanLine, wifiLine;\
	// Data will be done\
\
	function redrawLine()\
	{\
		wanLine.clearLine();\
		lanLine.clearLine();\
		wifiLine.clearLine();\
		drawInit();\
	}\
\
	function drawInit()\
	{\
		//Draw the line chart for internet triffic.\
		wanLine = drawLineDiv("'); ngx.print(wanTx) ngx.print('", "'); ngx.print(wanRx) ngx.print('", "wan");\
\
		//Draw the line chart for lan triffic.\
		lanLine = drawLineDiv("'); ngx.print(lanTx) ngx.print('", "'); ngx.print(lanRx) ngx.print('", "lan");\
\
		//Draw the line chart for wifi triffic.\
		wifiLine = drawLineDiv("'); ngx.print(wifiTx) ngx.print('", "'); ngx.print(wifiRx) ngx.print('", "wifi");\
	}\
\
	drawInit();\
	</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 
