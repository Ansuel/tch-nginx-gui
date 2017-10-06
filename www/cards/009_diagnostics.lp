--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lfs = require("lfs")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local session = ngx.ctx.session
if session:hasAccess("/modals/diagnostics-xdsl-modal.lp") and
   session:hasAccess("/modals/diagnostics-ping-modal.lp") and
   session:hasAccess("/modals/diagnostics-connection-modal.lp") and
   session:hasAccess("/modals/diagnostics-network-modal.lp")
   then

local xdsl_exist = false
if lfs.attributes("/etc/config/xdsl", "mode") == "file" then
  xdsl_exist = true
end

  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
\
    ');  
    local eth4_data = {
      eth4_status = "sys.eth.port.@eth4.status",
    }

    if xdsl_exist == true then
      content_helper.getExactContent(eth4_data)
      if (eth4_data["eth4_status"] == "up") then
        ngx.print(ui_helper.createCardHeader(T"Diagnostics", "modals/diagnostics-ping-modal.lp"))
      else
        ngx.print(ui_helper.createCardHeader(T"Diagnostics", "modals/diagnostics-xdsl-modal.lp"))
      end
    else
      ngx.print(ui_helper.createCardHeader(T"Diagnostics", "modals/diagnostics-ping-modal.lp"))
    end
      ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf085;">\
	<div class="divtable">\
     <table align="center" cellspacing="10%" cellpadding="10%" >\
      <tr>');  if xdsl_exist and eth4_data["eth4_status"] ~= "up" then   ngx.print('\
      <td><div data-toggle="modal" data-remote="modals/diagnostics-xdsl-modal.lp" data-id="diagnostics-xdsl-modal"><img  href="#" rel="tooltip" data-original-title="XDSL" src="/img/bandwidth-px-png.png" alt="dsl"></div></td>\
    ');  end  ngx.print('\
      <td><div data-toggle="modal" data-remote="modals/diagnostics-ping-modal.lp" data-id="diagnostics-ping-modal"><img href="#" rel="tooltip" data-original-title="PING" src="/img/pocket-32-black.png" alt="ping/trace"></div></td></tr>\
      <tr><td><div data-toggle="modal" data-remote="modals/diagnostics-connection-modal.lp" data-id="diagnostics-connection-modal"><img href="#" rel="tooltip" data-original-title="CONNECTION" src="/img/connection-established.png" alt="connection"></div></td>\
      <td><div data-toggle="modal" data-remote="modals/diagnostics-network-modal.lp" data-id="diagnostics-network-modal"><img href="#" rel="tooltip" data-original-title="NETWORK" src="/img/network_sans-32.png" alt="network"></div></td></tr>\
      </table>\
    </div>\
	</div>\
  </div>\
</div>\
');  
end
  ngx.print('\
\
'); 