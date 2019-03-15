--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local session = ngx.ctx.session
local format = string.format
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local modalPath = "/modals/system-modal.lp"
syslog_present = "disabled"

-- Check availability of file, return true if found, else false
local function file_check(file_name)
  local file_found=io.open(file_name, "rb")
  if file_found==nil then
    return false
  else
    return true
  end
end

local Syslog = proxy.get("uci.system.system.@system[0].log_ip", "uci.system.system.@system[0].log_filter_ip")
if Syslog and (Syslog[1].value ~= "" or Syslog[2].value ~= "") then
    syslog_present = "enabled"
end

local syslog_state_map = {
  disabled = T"Syslog disabled",
  enabled = T"Syslog enabled",
}

local syslog_light_map = {
  disabled = "0",--"off"
  enabled = "1",--"green"
}

local ssh_enable = "disabled"
local SSH_legacy = proxy.get("uci.dropbear.dropbear.@dropbear[0].enable")
local SSH_lan = proxy.get("uci.dropbear.dropbear.@lan.enable")
local SSH_wan = proxy.get("uci.dropbear.dropbear.@wan.enable")
if SSH_legacy and (SSH_legacy[1].value == "1") then
    ssh_enable = "Enabled"
end
if SSH_lan and (SSH_lan[1].value == "1") then
    ssh_enable = "enabled"
end
if SSH_wan and (SSH_wan[1].value == "1") then
    ssh_enable = "enabled"
end

local SSH_state_map = {
  disabled = T"SSH disabled",
  enabled = T"SSH enabled",
}

local SSH_light_map = {
  disabled = "0",--"off"
  enabled = "1",--"green"
}

local telnet_available = file_check("/bin/busybox_telnet")
local telnet_state = "NotAvailable"

if telnet_available then
	local TELNET = proxy.get("uci.telnet.general.enable")
	if TELNET and (TELNET[1].value == "1") then
		telnet_state = "enabled"
	else
		telnet_state = "disabled"
	end
end

local TELNET_state_map = {
  disabled = T"Telnet disabled",
  enabled = T"Telnet enabled",
  NotAvailable = T"Telnet Not Available",
}

local TELNET_light_map = {
  disabled = "0",--"off"
  enabled = "1",--"green"
  NotAvailable = "4",--red
}

if session:hasAccess("/modals/system-modal.lp") then
    local modal_link = format("class=\"modal-link\" data-toggle=\"modal\" data-remote=\"%s\" data-id=\"device-modal\"",modalPath)
  ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print( ui_helper.createCardHeader(T"System Extras", modalPath) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf1de;">\
      <div class="divtable">');
			ngx.print(
				ui_helper.createSimpleLight(syslog_light_map[syslog_present], syslog_state_map[syslog_present], nil,"fas fa-align-left"),
				ui_helper.createSimpleLight(SSH_light_map[ssh_enable], SSH_state_map[ssh_enable], nil,"fas fa-keyboard"));
			if telnet_available then
				ngx.print(
					ui_helper.createSimpleLight(TELNET_light_map[telnet_state], TELNET_state_map[telnet_state], nil,"fas fa-terminal")
				);
			end
		ngx.print('\
      </div>\
    </div>\
  </div>\
</div>\
');  
    end -- end for the second if
  ngx.print('\
'); 
