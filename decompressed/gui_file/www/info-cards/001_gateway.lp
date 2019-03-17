--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")

local find, sub, format = string.find, string.sub, string.format


local content = {
  product_name = "uci.env.var.prod_name",
  friendly_product_name = "uci.env.var.prod_friendly_name",
  software_name = "uci.version.version.@version[0].marketing_name",
  software_version = "uci.version.version.@version[0].marketing_version",
  firmware_version = "uci.env.var.friendly_sw_version_activebank",
  gui_version = "uci.modgui.gui.gui_version",
  cpuusage = "sys.proc.CPUUsage",
  ram_free = "sys.mem.RAMFree",
  ram_total = "sys.mem.RAMTotal",
  outdated_ver = "uci.modgui.gui.outdated_ver",
}

content_helper.getExactContent(content)

content["ram_free"] = math.floor(tonumber(content["ram_free"]) / 1024) 
content["ram_total"] = math.floor(tonumber(content["ram_total"]) / 1024) 

if content.outdated_ver == "1" then
	content.outdated_ver = "yellow"
	content.outdated_ver_text = T"GUI is outdated"
else
	content.outdated_ver = "green"
	content.outdated_ver_text = T"GUI is updated"
end

if content["friendly_product_name"] and content["friendly_product_name"] == "AGHP" then
	content["friendly_product_name"] = "AGTHP" --Wrong product name by telecom!
end

if not ( content.friendly_product_name == "" ) and not ( content.friendly_product_name == content.product_name ) then
	content.product_name = format("%s ( %s )",content.product_name,content.friendly_product_name)
end

local nf_conntrack_count = io.popen("sysctl -n -e net.nf_conntrack_max net.ipv4.netfilter.ip_conntrack_max")

content["uptime"] = content_helper.readfile("/proc/uptime","number",floor)
content["connection"] = content_helper.readfile("/proc/sys/net/netfilter/nf_conntrack_count")
content["total_connection"] = nf_conntrack_count:read()
content["system_time"] = os.date("%d/%m/%Y %Hh:%Mm:%Ss",os.time())

nf_conntrack_count:close()

  ngx.print('\
\
<div class="infocard" id="gatewaytab">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Gateway", nil, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf129;">\
	<div class="divtable">\
	<form class="form-horizontal">\
	<fieldset>');
	
	local basic = {
      span = {
        class = "span3"
      },
    }
	
	local html = {}
	
	basic.span["data-bind"] = nil
	html[#html + 1] = ui_helper.createLabel(T"Product Name", content["product_name"], basic)
	html[#html + 1] = ui_helper.createLabel(T"Software Version", format("%s %s",content["software_version"],content["software_name"]), basic)
	html[#html + 1] = ui_helper.createLabel(T"GUI Version", content["gui_version"], basic)
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label"><span class="gui_version_status fas fa-cog '..content.outdated_ver..'"></span></label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span class="simple-desc span3 gui_version_status_text">'
	html[#html + 1] = 		content.outdated_ver_text
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label"><span class="fa fa-sync check_update_spinner"></span></label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span class=" simple-desc span3">'
	html[#html + 1] = 		format('<a class="check_update" style="cursor: pointer;">%s</a>',T"Check Update")
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	basic.span["data-bind"] = "text: uptime"
	html[#html + 1] = ui_helper.createLabel(T"Uptime", post_helper.secondsToTime(content["uptime"]), basic)
	basic.span["data-bind"] = "text: cpuusage"
	html[#html + 1] = ui_helper.createLabel(T"CPU Usage", content["cpuusage"] .. "%", basic)
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Free Memory") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Ram" class=" simple-desc span3">'
	html[#html + 1] =		format('<span data-bind="text: ram_free">%s</span>',content["ram_free"])
	html[#html + 1] =		format(' / %s MB', content["ram_total"])
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Connection") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Connection" class=" simple-desc span3">'
	html[#html + 1] =		format('<span data-bind="text: connection">%s</span>',content["connection"])
	html[#html + 1] =		format(' / %s', content["total_connection"])
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	basic.span["data-bind"] = "text: system_time"
	html[#html + 1] = ui_helper.createLabel(T"System Time", content["system_time"], basic)
	
	ngx.print(html)
ngx.print('\
	  </fieldset>\
	  </form>\
	  </div>\
    </div>\
  </div>\
</div>\
<script>\
var InfoGatewayCardInterval;\
$(document).ready(function () {\
	new linkCheckUpdate();\
	new createAjaxUpdateCard("gatewaytab","/ajax/cpuload.lua",InfoGatewayCardInterval,5000);\
})\
</script>\
'); 
