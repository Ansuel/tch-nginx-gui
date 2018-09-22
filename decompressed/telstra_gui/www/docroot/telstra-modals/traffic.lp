--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/telstra-snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
  ngx.print('\
<script src ="/js/graphic-min.js"></script>\
');  
-- Localization
gettext.textdomain('webui-telstra')

local table, ipairs, require, ngx, io = table, ipairs, require, ngx, io
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local format = string.format
local tonumber = tonumber

local getargs = ngx.req.get_uri_args()
local getiface = getargs.iface

local check_data_file = "/root/trafficmon/check_data"
local all_ifaces, content_iface = {}, {}

local curiface = "wl0"
local curssid = ""

local piface = "uci.wireless.wifi-iface."
local awls = content_helper.convertResultToObject(piface .. "@.", proxy.get(piface))
local wls = {}
for i,v in ipairs(awls) do
    wls[#wls+1] = {
      radio = v.device,
        ssid = v.ssid,
        iface = v.paramindex
    }
    if v.paramindex == getiface then
        curiface = v.paramindex
        curssid = v.ssid
    end
    all_ifaces[v.paramindex] = true
end

content_iface.wifi = {{ iface = curiface}}

table.sort(wls, function(a,b)
    if a.radio == b.radio then
        return a.iface < b.iface
    else
        return a.radio < b.radio
    end
end)

piface = "uci.ethernet.port."
local aeth = content_helper.convertResultToObject(piface .. "@.", proxy.get(piface))
local eth = {}
for i,v in ipairs(aeth) do
    if v.wan ~= "1" then
        eth[#eth+1] = { iface = v.paramindex }
        all_ifaces[v.paramindex] = true
    end
end
content_iface.eth = eth

local content_wan = {}
local wwan_up = proxy.get("rpc.network.interface.@wwan.up")[1].value

if wwan_up == "1" then
    content_wan["iface"] = "rpc.network.interface.@wwan.ifname"
else
    content_wan["iface"] = "uci.network.interface.@wan.ifname"
end
content_helper.getExactContent(content_wan)
content_wan["iface"] = format("%s", content_wan["iface"])
all_ifaces[content_wan["iface"]] = true
content_iface.wan = { content_wan }

local function s2n(str)
  if str == nil or str == "" then
    return 0
  else
    return tonumber(str)
  end
end

local function b2m(number)
  return tonumber(format("%.3f", number / 1048576))
end

local function getTrafficHistoryData(direct, ifaces)
    local nline = 1
    local data = {}
    local total = 0
    for _, v in ipairs(ifaces) do
        local i = 0
        filename = string.format("/root/trafficmon/%s_%s", v.iface, direct)
        f = io.open(filename, "r")
        if f then
            for line in f:lines() do
                if ( i > 0) then
                    data[i] = data[i] or 0
                    data[i] = data[i] + tonumber(line)
                else
                    total = total + tonumber(line)
                end
                i = i + 1
            end
            f:close()
        end
    end
    return table.concat(data, ","), total
end

local function getLastCheck(file_name)
  local match = string.match
  local fd = io.open(file_name,"r")
  local lastcheck = {}
  if fd then
    local pattern = "([^|]*)|([^|]*)|(%d+)|(%d+)"
    local i = 0
    for line in fd:lines() do
      i = i + 1
      if i > 1 then
        local iface, direct, carry, number = match(line, pattern)
        if iface then
          lastcheck[iface] = lastcheck[iface] or {}
          lastcheck[iface][direct] = {
            ["carry"] = tonumber(carry),
            ["number"] = tonumber(number)
          }
        end
      end
    end
    fd:close()
    return lastcheck
  end
end

local count, lastcheck
local history, lasttotal = {}, {}
local types = { "rx_bytes", "tx_bytes" }
proxy.set("rpc.system.lock.lockdir", "/root/trafficmon/")
local lock = proxy.get("rpc.system.lock.lock")[1].value
local count = 0
while lock ~= "1" and count < 5 do
    ngx.sleep(1)
    lock = proxy.get("rpc.system.lock.lock")[1].value
    count = count + 1
end

if count == 5 then
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

_, lastcheck = pcall(getLastCheck, check_data_file)
for iface_type, ifaces in pairs(content_iface) do
  history[iface_type], lasttotal[iface_type] = {}, {}
  for _, direct in ipairs(types) do
    _, history[iface_type][direct], lasttotal[iface_type][direct] = pcall(getTrafficHistoryData, direct, ifaces)
  end
end
proxy.set("rpc.system.lock.free", "0")


local iface_total = {}
for iface,_ in pairs(all_ifaces) do
  if iface ~= "" then
    for _, direct in pairs(types) do
      iface_total[iface .. "_" .. direct] = "sys.class.net.@" .. iface ..".statistics." .. direct
    end
  end
end
content_helper.getExactContent(iface_total)

if lastcheck then
  for iface, _ in pairs(all_ifaces) do
    if iface ~= "" then
      for _, direct in pairs(types) do
        local traffic_name = iface .. "_" .. direct
        lastcheck[iface] = lastcheck[iface] or {}
        local lastcheck_data = lastcheck[iface]
        lastcheck_data[direct] = lastcheck_data[direct] or { carry = 0, number = 0 }
        iface_total[traffic_name] = s2n(iface_total[traffic_name])
        if lastcheck_data[direct]["number"] > iface_total[traffic_name] and iface_total[traffic_name] > 0 then
          lastcheck_data[direct]["carry"] = lastcheck_data[direct]["carry"] + 1
        end
      end
    end
  end
end

local function getTrafficTotal(ifaces)
  local total = { rx_bytes = 0, tx_bytes = 0}
  local carry = { rx_bytes = 0, tx_bytes = 0}
  for _, direct in ipairs(types) do
    for _,v in ipairs(ifaces) do
      if v.iface ~= "" then
        total[direct] = total[direct] + iface_total[v.iface  .. "_" .. direct]
        if lastcheck[v.iface] then
          carry[direct] = carry[direct] + lastcheck[v.iface][direct]["carry"]
        end
      end
    end
    total[direct] = total[direct] + carry[direct]*4294967296
  end
  return total
end

local content_total = {}
content_iface.allwifi = wls
for iface_type, ifaces in pairs(content_iface) do
    content_total[iface_type] = getTrafficTotal(ifaces)
end

for iface_type, data in pairs(history) do
  for direct, value in pairs(data) do
    history[iface_type][direct] = value .. "," .. tostring(content_total[iface_type][direct] - lasttotal[iface_type][direct])
    content_total[iface_type][direct] = b2m(content_total[iface_type][direct])
  end
end
content_total.allwifi.tx_bytes = b2m(content_total.allwifi.tx_bytes)
content_total.allwifi.rx_bytes = b2m(content_total.allwifi.rx_bytes)

for iface_type, total in pairs(content_total) do
    content_total[iface_type]["txrx_bytes"]= format("%.3f", total.tx_bytes + total.rx_bytes)
end

local attributes = {
  label = { class = "control-llabel" } ,
  span = { class = "span2 text-right" } ,
}

  ngx.print('\
<div class="container toplevel">\
');  lp.include("tabs-services.lp")   ngx.print('\
<div class="row">\
<div class="span11">\
<fieldset>\
<form class="form-horizontal" >\
<legend>');  ngx.print( T"Internet Traffic" ); ngx.print('</legend>\
');  
ngx.print(
  ui_helper.createLabel(T"Total Send/Receive (in MB)", content_total.wan.txrx_bytes , attributes),
  ui_helper.createLabel(T"Total Send (in MB)", content_total.wan.tx_bytes, attributes),
  ui_helper.createLabel(T"Total Receive (in MB)", content_total.wan.rx_bytes, attributes)
)
  ngx.print('\
<legend>');  ngx.print( T"Ethernet Network Traffic" ); ngx.print('</legend>\
');  
ngx.print(
  ui_helper.createLabel(T"Total Send/Receive (in MB)", content_total.eth.txrx_bytes , attributes),
  ui_helper.createLabel(T"Total Send (in MB)", content_total.eth.tx_bytes, attributes),
  ui_helper.createLabel(T"Total Receive (in MB)", content_total.eth.rx_bytes, attributes)
)
  ngx.print('\
<legend>');  ngx.print( T"Wi-Fi Network Traffic" ); ngx.print('</legend>\
');  
ngx.print(
  ui_helper.createLabel(T"Total Send/Receive (in MB)",  content_total.allwifi.txrx_bytes , attributes),
  ui_helper.createLabel(T"Total Send (in MB)", content_total.allwifi.tx_bytes, attributes),
  ui_helper.createLabel(T"Total Receive (in MB)", content_total.allwifi.rx_bytes, attributes)
)
  ngx.print('\
</form>\
</fieldset>\
</div>\
</div>\
</div>\
\
<div class="container toplevel">\
<div class="row">\
<div class="span11">\
<table width="100%">\
  <tr>\
    <td style="background-color:red">&nbsp;&nbsp;&nbsp;&nbsp;</td>\
    <td nowrap>Total Send/Receive<input type="checkbox" id="redLine" name="redLine" checked onclick="redrawLine()"/></td>\
    <td style="background-color:green">&nbsp;&nbsp;&nbsp;&nbsp;</td>\
    <td nowrap>Total Send<input type="checkbox" id="greenLine" name="greenLine" checked onclick="redrawLine()"/></td>\
    <td style="background-color:blue">&nbsp;&nbsp;&nbsp;&nbsp;</td>\
    <td nowrap>Total Receive<input type="checkbox" id="blueLine" name="blueLine" checked onclick="redrawLine()"/></td>\
    <td width="40%">&nbsp;</td>\
  </tr>\
</table>\
\
<div id="wanTraffic">\
<div id ="wanLineDiv" style ="position:relative;height:350px;width:800px;"></div>\
<center>Internet Traffic</center>\
</div>\
\
<div id="lanTraffic">\
<div id ="lanLineDiv" style ="position:relative;height:350px;width:800px;"></div>\
<center>Ethernet Network Traffic</center>\
</div>\
\
<ul class="nav nav-tabs">\
  ');  
    html = {}
    for i,v in ipairs(wls) do
        local active = ""
        if v.iface == curiface then
            active = "active"
        end
        local url = "traffic.lp?iface=" .. v.iface
        html[#html+1] = string.format('<li class="%s"><a href="%s" target="_self">%s</a></li>', active, url, v.ssid)
    end
    ngx.print(html)
    ngx.print('\
</ul>\
<div id="wifiTraffic">\
<div id ="wifiLineDiv" style ="position:relative;height:350px;width:800px;"></div>\
<center>Wi-Fi ');  ngx.print(curssid); ngx.print(' Network Traffic</center>\
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
      wanLine = drawLineDiv("');  ngx.print(history.wan.tx_bytes); ngx.print('", "');  ngx.print(history.wan.rx_bytes); ngx.print('", "wan");\
\
      //Draw the line chart for lan triffic.\
      lanLine = drawLineDiv("');  ngx.print(history.eth.tx_bytes); ngx.print('", "');  ngx.print(history.eth.rx_bytes); ngx.print('", "lan");\
\
      //Draw the line chart for wifi triffic.\
      wifiLine = drawLineDiv("');  ngx.print(history.wifi.tx_bytes); ngx.print('", "');  ngx.print(history.wifi.rx_bytes); ngx.print('", "wifi");\
  }\
\
  drawInit();\
</script>\
</div>\
</div>\
</div>\
\
');  
lp.include("footer.lp")
  ngx.print('\
\
'); 