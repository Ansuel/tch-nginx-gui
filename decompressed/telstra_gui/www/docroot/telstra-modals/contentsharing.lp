--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/telstra-snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
  ngx.print('\
\
');  
-- Localization
gettext.textdomain('webui-telstra')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local string = string
local format = string.format
local floor = math.floor
local tonumber = tonumber

-- Process POST query
local post_helper = require("web.post_helper")

local function check_dlna(dtype)
	local available = false
	local binname
	if file_check("/usr/bin/dlnad") then
		binname = "dlnad"
		available = true
	elseif file_check("/usr/sbin/minidlnad") then
		binname = "minidlna"
		available = true
	end
	
	if dtype:match("available") then
		return available
	elseif dtype:match("type") then
		return binname or ""
	end
	
	return ""
end

if check_dlna("available") then
	local mapParams = {
		dlna_enabled       = "uci."..check_dlna("type")..".config.enabled",
		dlna_friendly_name = "uci."..check_dlna("type")..".config.friendly_name",
	}
	
	local mapValid = {
		dlna_enabled = post_helper.validateBoolean,
		dlna_friendly_name = valid_empty_string,
	}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
end
-- End POST process

local content_intf_lan = {
    ipaddr = "rpc.network.interface.@lan.ipaddr",
}
content_helper.getExactContent(content_intf_lan)

--local content_ftpd = {
--    enable = "uci.pure-ftpd.pure-ftpd.1.enabled",
--}
--content_helper.getExactContent(content_ftpd)

local content_samba = {
    name = "uci.samba.samba.name",
}
content_helper.getExactContent(content_samba)

--str_ftp_server_enable = "Disabled";
--if (content_ftpd.enable ~= nil and content_ftpd.enable == "1") then
--    str_ftp_server_enable  = "Enabled";
--end

  ngx.print('\
\
<div class="container toplevel">\
<div class="row">\
<div class="span11">\
<form class="form-horizontal" method="post" action="contentsharing.lp">\
');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"Content Sharing" ); ngx.print('</legend>\
');  

  local attributes = {
    input = {
        class = "monitor-changes",
        maxlength = "32" 
    }
  }

  local html = {}
  if check_dlna("available") then
	html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enable DLNA Server", "dlna_enable", content["dlna_enable"], attributes)
	html[#html + 1] = ui_helper.createInputText(T"Media Server Name", "media_server_name", content["dlna_friendly_name"], attributes)
  end
  html[#html + 1] = ui_helper.createLabel(T"Media Server IP", content_intf_lan.ipaddr)
--  html[#html + 1] = ui_helper.createLabel(T"FTP Server State", str_ftp_server_enable)
  html[#html + 1] = ui_helper.createLabel(T"Network Folder Name", content_samba.name)
  ngx.print(html)
  ngx.print('\
</fieldset>\
</form>\
\
');  
lp.include("save.lp")
  ngx.print('\
\
</div>\
</div>\
</div>\
\
<script src="/js/srp-min.js" ></script>\
\
');  
lp.include("footer.lp")
  ngx.print('\
'); 