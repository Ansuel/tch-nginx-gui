--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local session = ngx.ctx.session
local format = string.format
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local modalPath = "/modals/system-modal.lp"
syslog_present = "Disabled"

local Syslog = proxy.get("uci.system.system.@system[0].log_ip", "uci.system.system.@system[0].log_filter_ip")
if Syslog and (Syslog[1].value ~= "" or Syslog[2].value ~= "") then
    syslog_present = "Enabled"
end
    local syslog_state_map = {
      Disabled = T"Syslog Disabled",
      Enabled = T"Syslog Enabled",
    }

    local syslog_light_map = {
      Disabled = "off",
      Enabled = "green",
    }

local ssh_enable = "Disabled"
local SSH_legacy = proxy.get("uci.dropbear.dropbear.@dropbear[0].enable")
local SSH_lan = proxy.get("uci.dropbear.dropbear.@lan.enable")
local SSH_wan = proxy.get("uci.dropbear.dropbear.@wan.enable")
if SSH_legacy and (SSH_legacy[1].value == "1") then
    ssh_enable = "Enabled"
end
if SSH_lan and (SSH_lan[1].value == "1") then
    ssh_enable = "Enabled"
end
if SSH_wan and (SSH_wan[1].value == "1") then
    ssh_enable = "Enabled"
end

    local SSH_state_map = {
      Disabled = T"SSH Disabled",
      Enabled = T"SSH Enabled",
    }

    local SSH_light_map = {
      Disabled = "off",
      Enabled = "green",
    }
	
local TELNET = proxy.get("uci.telnet.general.enable")
if TELNET and (TELNET[1].value == "1") then
    telnet_enable = "Enabled"
else
	telnet_enable = "Disabled"
end
    local TELNET_state_map = {
      Disabled = T"Telnet Disabled",
      Enabled = T"Telnet Enabled",
    }

    local TELNET_light_map = {
      Disabled = "off",
      Enabled = "green",
    }
	
    if session:hasAccess("/modals/system-modal.lp") then
    local modal_link = format("class=\"modal-link\" data-toggle=\"modal\" data-remote=\"%s\" data-id=\"device-modal\"",modalPath)
  ngx.print('\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"System Extras", modalPath) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf1de;">\
      <div class="divtable">');
			ngx.print(
				ui_helper.createSimpleLight(nil, syslog_state_map[syslog_present], { light = { class = syslog_light_map[syslog_present] } }),
				'<br/>',
				ui_helper.createSimpleLight(nil, SSH_state_map[ssh_enable], { light = { class = SSH_light_map[ssh_enable] } }),
				'<br/>',
				ui_helper.createSimpleLight(nil, TELNET_state_map[telnet_enable], { light = { class = TELNET_light_map[telnet_enable] } })
			);
		ngx.print('\
      </div>\
    </div>\
  </div>\
</div>\
');  
    end -- end for the second if
  ngx.print('\
'); 