--pretranslated: do not change this file
 
--[[
   Hostmap Page
   Page is to show a more logical layout of how devices are connected
]]
-- Localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local ch = require("web.content_helper")
local string, pairs, ngx = string, pairs, ngx
local ui_helper = require("web.ui_helper")
local format, print, match = string.format, ngx.print , string.match
local eth0, eth1, eth2, eth3, wifi = {}, {}, {}, {}, {}

local function AJAX(ap,path,mac)
  if ap and path and mac then
    local rssi = format("%s",proxy.get("rpc.wireless.ap.@" .. ap:untaint() .. ".station.@" .. mac:untaint() ..".rssi")[1].value)
    if rssi == "0" then rssi ="-100" end
    path = path:untaint()
    local content = {
      Speed = path .. ".Speed",
      State = path .. ".State",
    }
    ch.getExactContent(content)
    local state = T"Offline"
    if content["State"] == "1" then
      state = T"Online"
    end
    local html = {}
    html[#html+1]="{"
    html[#html+1]=format("\"Speed\":\"%s\"",(content["Speed"] or "0") .. " Mbs")
    html[#html+1]=","
    html[#html+1]=format("\"State\":\"%s\"",state)
    html[#html+1]=","
    html[#html+1]=format("\"AP\":\"%s\"",ap)
    html[#html+1]=","
    html[#html+1]=format("\"MAC\":\"%s\"",mac)
    html[#html+1]=","
    html[#html+1]=format("\"RSSI\":\"%s\"",rssi)
    html[#html+1]="}"
    print(html)
  end
end
local args = ngx.req.get_uri_args()
if args.isAjax == "1" then
   AJAX(args.ap,args.path,args.mac)
   ngx.exit(ngx.HTTP_OK)
end
local function generate_host(HostName,IPAddress,MACAddress,Speed,State,hostpath,wifiDetails,ap)
   local fade = ""
   if State == "0" then
      fade = "fadedtxt"
   end
   return format("<div><span class=\"centertxt host %s\" data-host=\"%s\" data-ip=\"%s\" data-MAC=\"%s\" data-speed=\"%s\" data-state=\"%s\" data-wifi=\"%s\" data-hostpath=\"%s\" data-ap=\"%s\">%s</span></div>",fade,HostName,IPAddress,MACAddress,Speed,State,wifiDetails or "0",hostpath or "0", ap or "0",HostName)
end
print(ui_helper.createHeader(T"Devices", false, true))
  ngx.print('\
<div class="modal-body update">\
');  
local tabs = {
    {
        desc = T"Devices List",
        target = "modals/device-modal.lp",
    },
    {
        desc = T"Devices Map",
        active = "active",
        target = "modals/hostmap-modal.lp",
    },
}
ngx.print(ui_helper.createModalTabs(tabs))
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/hostmap-modal.lp">\
<fieldset>\
');  
local html = {}
local eth_sys_path = "sys.eth.port."
local eth_sys_content = proxy.get(eth_sys_path)
eth_sys_content = ch.convertResultToObject(eth_sys_path,eth_sys_content)
local ethstate = {
      ["eth0"] = "0",
      ["eth1"] = "0",
      ["eth2"] = "0",
      ["eth3"] = "0",
      ["eth4"] = "0",
}
for _, v in pairs (eth_sys_content) do
  if v.status == "up" then
    local port = v.paramindex
    port = format("%s",match(port, "eth%d+") or "")
    ethstate[port] = v.speed
  end
end
  --Get Wireless Device details
  local hosts = proxy.get("sys.hosts.host.")
  hosts = ch.convertResultToObject("sys.hosts.host.",hosts)
  local wifiAP = ch.getMatchedContent("rpc.wireless.ap.")
  for _,f in ipairs(hosts) do
      local displayname = f.HostName
      if displayname == "" then
         f.HostName = format("%s%s",T"Unknown",string.upper(f.MACAddress):sub(-6))
      end
      local intf = f.L2Interface
      if intf == "vlan_eth0" or intf == "eth0" then
        eth0[#eth0+1] = f
      elseif intf == "vlan_eth1" or intf == "eth1" then
        eth1[#eth1+1] = f
      elseif intf == "vlan_eth2" or intf == "eth2" then
        eth2[#eth2+1] = f
      elseif intf == "vlan_eth3" or intf == "eth3" then
        eth3[#eth3+1] = f
      else
        f.path = "sys.hosts.host."..f.paramindex
        wifi[#wifi+1] = f
      end
  end

  html[#html+1]=format("<legend>%s</legend>",T"Ethernet Ports")
  html[#html+1]="<table class=\"hostmaptable\">"
  html[#html+1]=format("<tr class=\"grey\"><td class=\"centertxt centertitle\">%s</td><td class=\"centertxt centertitle\">%s</td><td class=\"centertxt centertitle\">%s</td><td class=\"centertxt centertitle\">%s</td></tr>",T"Port 1",T"Port 2",T"Port 3",T"Port 4")
  html[#html+1]="<tr>"
  --ETH0
  html[#html+1]="<td class=\"twentyfive\">"
  for x=1, #eth0, 1 do
      html[#html+1] = generate_host(eth0[x].HostName, eth0[x].IPAddress, eth0[x].MACAddress:upper(), ethstate["eth0"], eth0[x].State, eth0[x].path)
  end
  html[#html+1]="</td>"
  --ETH1
  html[#html+1]="<td class=\"twentyfive\">"
  for x=1, #eth1, 1 do
      html[#html+1] = generate_host(eth1[x].HostName, eth1[x].IPAddress, eth1[x].MACAddress:upper(), ethstate["eth1"], eth1[x].State, eth1[x].path)
  end
  html[#html+1]="</td>"
  --ETH2
  html[#html+1]="<td class=\"twentyfive\">"
  for x=1, #eth2, 1 do
      html[#html+1] = generate_host(eth2[x].HostName, eth2[x].IPAddress, eth2[x].MACAddress:upper(), ethstate["eth2"], eth2[x].State, eth2[x].path)
  end
  html[#html+1]="</td>"
  --ETH3
  html[#html+1]="<td class=\"twentyfive\">"
  for x=1, #eth3, 1 do
      html[#html+1] = generate_host(eth3[x].HostName, eth3[x].IPAddress, eth3[x].MACAddress:upper(), ethstate["eth3"], eth3[x].State, eth3[x].path)
  end
  html[#html+1]="</td></tr></table><br/>"
  --WIFI
  --Wireless
  local wifiintf = proxy.get("uci.wireless.wifi-iface.")
  wifiintf = ch.convertResultToObject("uci.wireless.wifi-iface.",wifiintf)
  local wifiintf_extra = proxy.get("rpc.wireless.ssid.")
  wifiintf_extra = ch.convertResultToObject("rpc.wireless.ssid.",wifiintf_extra)
  local paramindex = {}
  local apindex = {}
  local wifispan = 100 / #wifiintf
  html[#html+1]=format("<script>$(\".wifilist\").css({\"width\":\"%s%s\"})</script>",wifispan,"%")
  html[#html+1]=format("<legend>%s</legend>",T"Wireless Networks")
  html[#html+1]="<table class=\"hostmaptable\">"
  html[#html+1]="<tr class=\"grey\">"
  for x=1, #wifiintf, 1 do
      local disabled, radio = "","2.4GHz"
      paramindex[x] = wifiintf[x].paramindex
      for k,v in pairs(wifiAP) do
           if paramindex[x]:sub(2) == v["ssid"] then
              apindex[x] = v["path"]:match("@(.+)%.")
           end
      end
      if wifiintf[x].state == "0" then disabled = "wifidisabled" end
      if wifiintf[x].device ~= "radio_2G" then radio = "5GHz" end
      if wifiintf[x].ssid == "" then
         for k, v in pairs (wifiintf_extra) do
            if wifiintf[x].paramindex == v.paramindex then
                    wifiintf[x].ssid = v.ssid
            end
         end
      end
      -- Check if the ssid has an ap_display_name, if so, display that instead
      local display_ssid = wifiintf[x].ssid
      if wifiintf[x].ap_display_name ~= nil and wifiintf[x].ap_display_name ~= "" then
          display_ssid = wifiintf[x].ap_display_name
      elseif wifiintf[x].stb == "1" then
          display_ssid = "IPTV"
      end
      html[#html+1]=format("<td class=\"centertxt centertitle %s wifilist\">%s (%s)</td>",disabled, display_ssid, radio)
  end
  html[#html+1]="</tr><tr>"
  for x=1, #paramindex, 1 do
      html[#html+1]="<td class=\"twentyfive wifilist\">"
      for y=1, #wifi, 1 do
         if paramindex[x]:sub(2) == wifi[y].L2Interface then
            html[#html+1] = generate_host(wifi[y].HostName, wifi[y].IPAddress, wifi[y].MACAddress, wifi[y].Speed, wifi[y].State, wifi[y].path, "1",apindex[x])
         end
      end
      html[#html+1]="</td>"
  end
  html[#html+1]="</tr></table>"
  print(html)
  ngx.print('\
</fieldset>\
</form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
<script type=\'text/javascript\'>\
function Popupdevice(Title,txt,height){\
    var moveLeft = 10;\
    var moveRight = -390;\
    var moveDown = -50;\
    var header = \'<div class="header"><div  class="header-title pull-left"><p id="device_poptitle"></p></div></div>\';\
   $("body").append(\'<div class=\\"device_popUpBG\\"></div>\');\
   $("body").append(\'<div id="device_popUp" class="popUp smallcard span4">\'+header+\'<div id="device_Poptxt" class="content"></div>\');\
   $("#device_poptitle").html(Title);\
   $("#device_Poptxt").html(txt);\
   $d = $("#device_popUp");\
   var pagewidth = $("body").width();\
   var thiswidth = $d.width();\
   var center = (pagewidth / 2) - (thiswidth / 2);\
   var width = window.innerWidth || document.documentElement.clientWidth;\
   $d.css({\'left\': center,  \'margin\' : \'0px\', \'border-radius\': \'13px\'}).appendTo(\'body\').slideDown("fast");\
   $(\'html, body\').css({\'overflow\': \'hidden\',\'height\': \'100%\'});\
  $( ".device_popUpBG" ).click(function() {\
        $(".device_popUpBG").remove();\
        $("#device_popUp").remove();\
        clearTimeout(timerajax);\
        $(\'html, body\').css({\'overflow\': \'auto\',\'height\': \'auto\'});\
  });\
  $( "#device_popUp" ).click(function() {\
        $(".device_popUpBG").remove();\
        $("#device_popUp").remove();\
        clearTimeout(timerajax);\
        $(\'html, body\').css({\'overflow\': \'auto\',\'height\': \'auto\'});\
  });\
}\
var timerajax = ""\
function getInfo(mac,path,wifi,ap)\
{\
  var url = \'/modals/hostmap-modal.lp\';\
  var checktimer = 1000;\
  var gets =  {}\
  gets.isAjax = "1";\
  //gets.wifi = wifi;\
  gets.path = path;\
  gets.mac = mac;\
  gets.ap = ap;\
  $.getJSON(url, gets )\
   .done(function( data ) {\
      $("#speed").html(data.Speed);\
      $("#state").html(data.State);\
      $("#rssivalue").html(data.RSSI + "dBm");\
      bars(data.RSSI);\
   })\
   .error(function() {\
   });\
   timerajax = window.setTimeout(function () {getInfo(mac,path,wifi,ap);}, checktimer);\
}\
// Wifi chart scripts\
    var countwifi = 0;\
   function bars(x){\
          var y = 100 + parseInt(x);\
          var x = parseInt(x) * -1\
          $("#chartcontainerwifi").append(\'<div class=\\"barswifi\\" id=\\"bar-\'+countwifi+\'\\"></div>\');\
          var $d = $("#bar-"+countwifi)\
          var color = \'#FF0000\'; //default red\
          if (x <= 55){\
            color =  \'#00FF00\'; //green\
          }else if (x<80 && x>55){\
            color =  \'#FF9900\'; //orange\
          }\
          $d.css({\'height\': y+\'px\', \'left\': $(\'#chartcontainerwifi\').width() + \'px\', \'background-color\': color }).appendTo(\'#div-1\');;\
          $(".barswifi").each(function(){\
                $(this).animate({//left: \'5px\'\
                //$(this).css({\
                  \'left\': $(this).position().left -5,\
                  \'opacity\': $(this).css(\'opacity\')-0.02,\
                  \'filter\': \'alpha(opacity=\'+toString(($(this).css(\'opacity\')-0.02)*100)+\')\'\
                },\'1500\');\
                if ($(this).position().left < 0){$(this).remove();}\
           });\
           countwifi++;\
           //window.setTimeout(function(){ bars(random(100));}, 1500);\
   }\
   $(function(d) {\
      $( ".host" ).click(function(e) {\
        var height = "300";\
        var wifi = $(this).attr(\'data-wifi\');\
        var path = $(this).attr(\'data-hostpath\');\
        var ap = $(this).attr(\'data-ap\');\
        var host = $(this).html();\
        var ip = ($(this).attr(\'data-ip\') != "" ? $(this).attr(\'data-ip\') : "');  ngx.print(T"No-IP"); ngx.print('");\
        var mac = $(this).attr(\'data-mac\');\
        var speed = ($(this).attr(\'data-state\') == "1" ? $(this).attr(\'data-speed\')+" Mbs" : "');  ngx.print(T"Last"); ngx.print('@ "+$(this).attr(\'data-speed\')+" Mbs");\
        var state = ($(this).attr(\'data-state\') == "1" ? "');  ngx.print(T"Online"); ngx.print('" : "');  ngx.print(T"Offline"); ngx.print('");\
        var ips=ip.split(\' \');\
        var txt = "<div class=\\"ctsinfoline\\"><span class=\\"hostinfoleft\\">');  ngx.print(T"IP Address"); ngx.print('</span><span class=\\"hostinforight\\">"+ips[0]+"</span></div>";\
        if (ips[1]) {\
            txt = txt + "<div class=\\"ctsinfoline\\"><span class=\\"hostinfoleft\\"></span><span class=\\"hostinforight\\">"+ips[1]+"</span></div>";\
        }\
        if (ips[2]) {\
            txt = txt + "<div class=\\"ctsinfoline\\"><span class=\\"hostinfoleft\\"></span><span class=\\"hostinforight\\">"+ips[2]+"</span></div>";\
            //height = "225";\
        }\
        if (ips[3]) {\
            txt = txt + "<div class=\\"ctsinfoline\\"><span class=\\"hostinfoleft\\"></span><span class=\\"hostinforight\\">"+ips[3]+"</span></div>";\
            //height = "250";\
        }\
        txt = txt + "<div class=\\"ctsinfoline\\"><span class=\\"hostinfoleft\\">');  ngx.print(T"MAC Address"); ngx.print('</span><span class=\\"hostinforight\\">"+mac+"</span></div>";\
        if ($(this).attr(\'data-speed\')){\
          txt = txt + "<div class=\\"ctsinfoline\\"><span class=\\"hostinfoleft\\">');  ngx.print(T"Port Speed"); ngx.print('</span><span class=\\"hostinforight\\" id=\\"speed\\">"+speed+"</span></div>";\
        }\
        txt = txt + "<div class=\\"ctsinfoline\\"><span class=\\"hostinfoleft\\">');  ngx.print(T"Status"); ngx.print('</span><span class=\\"hostinforight\\" id=\\"state\\">"+state+"</span></div>";\
        if (wifi == "1"){\
          txt = txt + "<div id=\\"charttitalwifiwifi\\" class=\\"hostinfoleft\\">RSSI</div><div id=\\"chartcontainerwifi\\"><div id=\\"scale1wifi\\" class=\\"scalewifi\\">-0dBm</div><div id=\\"scale2wifi\\" class=\\"scalewifi\\">-100dBm</div><div id=\\"rssivalue\\" class=\\"scalewifi\\">-50dBm</div></div>"\
          getInfo(mac,path,wifi,ap)\
        }\
        Popupdevice(host,txt,height)\
        });\
  });\
</script>\
'); 