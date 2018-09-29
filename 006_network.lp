--pretranslated: do not change this file
 
-- Enable localization
-- NG-92675 implement changes required from the customer
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")

local find, sub, format = string.find, string.sub, string.format

local contentonly

if ngx.req.get_method() == "GET" then
	contentonly = ngx.req.get_uri_args().contentonly or false
end

local content = {
eth0stat = "sys.eth.port.@eth0.status",
eth0speed = "sys.eth.port.@eth0.speed",
eth0mode = "sys.eth.port.@eth0.mode",

eth1stat = "sys.eth.port.@eth1.status",
eth1speed = "sys.eth.port.@eth1.speed",
eth1mode = "sys.eth.port.@eth1.mode",

eth2stat = "sys.eth.port.@eth2.status",
eth2speed = "sys.eth.port.@eth2.speed",
eth2mode = "sys.eth.port.@eth2.mode",

eth3stat = "sys.eth.port.@eth3.status",
eth3speed = "sys.eth.port.@eth3.speed",
eth3mode = "sys.eth.port.@eth3.mode",

eth4stat = "sys.eth.port.@eth4.status",
eth4speed = "sys.eth.port.@eth4.speed",
eth4mode = "sys.eth.port.@eth4.mode",

}


content_helper.getExactContent(content)

if not ( content.max_upstream == "0" ) then
  ngx.print('\
\
<div class="infocard" id="portstab">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Ports", nil, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf362;">\
	<div class="divtable">\
	<form class="form-horizontal">\
	<fieldset>');
	
	local basic = {
      span = {
        class = "span3"
      },
    }
    local advanced = {
      group = {
        class = "advanced hide",
      },
      span = {
        class = "span5"
      },
    }
	local advancedshow = {
      group = {
        class = "advanced show",
      },
      span = {
        class = "span5"
      },
    }
	
	local html = {}
	
html[#html + 1] = ui_helper.createLabel(T"<b>eth0 (LAN1) Status</b>", content["eth0stat"], basic)
if not ( content.eth0stat == "Down" ) then
html[#html + 1] = ui_helper.createLabel(T"eth0 (LAN1) Speed", content["eth0speed"] .. " Mbps", basic)
html[#html + 1] = ui_helper.createLabel(T"eth0 (LAN1) Mode", content["eth0mode"], basic)
end

html[#html + 1] = ui_helper.createLabel(T"<b>eth1 (LAN2) Status</b>", content["eth1stat"], basic)
if not ( content.eth1stat == "Down" ) then
html[#html + 1] = ui_helper.createLabel(T"eth1 (LAN2) Speed", content["eth1speed"] .. " Mbps", basic)
html[#html + 1] = ui_helper.createLabel(T"eth1 (LAN2) Mode", content["eth1mode"], basic)
end

html[#html + 1] = ui_helper.createLabel(T"<b>eth2 (LAN3) Status</b>", content["eth2stat"], basic)
if not ( content.eth2stat == "Down" ) then
html[#html + 1] = ui_helper.createLabel(T"eth2 (LAN3) Speed", content["eth2speed"] .. " Mbps", basic)
html[#html + 1] = ui_helper.createLabel(T"eth2 (LAN3) Mode", content["eth2mode"], basic)
end

html[#html + 1] = ui_helper.createLabel(T"<b>eth3 (LAN4) Status</b>", content["eth3stat"], basic)
if not ( content.eth3stat == "Down" ) then
html[#html + 1] = ui_helper.createLabel(T"eth3 (LAN4) Speed", content["eth3speed"] .. " Mbps", basic)
html[#html + 1] = ui_helper.createLabel(T"eth3 (LAN4) Mode", content["eth3mode"], basic)
end

html[#html + 1] = ui_helper.createLabel(T"<b>eth4 (WAN) Status</b>", content["eth4stat"], basic)
if not ( content.eth4stat == "Down" ) then
html[#html + 1] = ui_helper.createLabel(T"eth4 (WAN) Speed", content["eth4speed"] .. " Mbps", basic)
html[#html + 1] = ui_helper.createLabel(T"eth4 (WAN) Mode", content["eth4mode"], basic)
end





	
	ngx.print(html)
ngx.print('\
	  </fieldset>\
	  </form>\
	  </div>\
    </div>\
  </div>\
</div>\
'); 
end