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
  <div class="smallcard" data-aos="fade-up" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  
    local eth4_data = {
      eth4_status = "sys.eth.port.@eth4.status",
	  eth4_mode = "uci.ethernet.port.@eth4.wan",
    }

    if xdsl_exist == true then
      content_helper.getExactContent(eth4_data)
      if (eth4_data["eth4_status"] == "up") and ( eth4_data["eth4_mode"] == "1") then
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
      <tr>');  
	if xdsl_exist then   ngx.print('\
		  <td>\
		    <div data-toggle="modal" data-remote="modals/diagnostics-xdsl-modal.lp" data-id="diagnostics-xdsl-modal">\
			  <picture>\
				<source srcset="/img/bandwidth-px-png.webp" type="image/webp">\
				<source srcset="/img/bandwidth-px-png.png" type="image/png">\
				<img class="smallsomeInfos" href="#" rel="tooltip" data-placement="bottom" data-original-title="XDSL" src="/img/bandwidth-px-png.png" alt="dsl">\
			  </picture>\
			</div>\
		  </td>\
		  <td>\
                    <div data-toggle="modal" data-remote="modals/diagnostics-xdsl-graphics-modal.lp" data-id="diagnostics-xdsl-graphics-modal">\
                            <i class="smallsomeInfos fa fa-line-chart" style="font-size:32px;" href="#" rel="tooltip" data-placement="bottom" data-original-title="XDSL charts" alt="charts"></i>\
                        </div>\
                  </td>\
	');
	end	
	ngx.print('\
          <td>\
			<div data-toggle="modal" data-remote="modals/diagnostics-ping-modal.lp" data-id="diagnostics-ping-modal">\
			  <picture>\
			    <source srcset="/img/pocket-32-black.webp" type="image/webp">\
		        <source srcset="/img/pocket-32-black.png" type="image/png">\
			    <img class="smallsomeInfos" href="#" rel="tooltip" data-placement="bottom" data-original-title="PING" src="/img/pocket-32-black.png" alt="ping/trace">\
			  </picture>\
			</div>\
	      </td>\
		  <td>\
	        <div data-toggle="modal" data-remote="modals/port-mirror-modal.lp" data-id="port-mirror-modal">\
			    <i class="smallsomeInfos fa fa-exchange" style="font-size:32px;" href="#" rel="tooltip" data-placement="bottom" data-original-title="PORT-MIRROR" alt="port-mirror"></i>\
			</div>\
	      </td>\
	    </tr>\
        <tr>\
		  <td>\
			<div data-toggle="modal" data-remote="modals/diagnostics-connection-modal.lp" data-id="diagnostics-connection-modal">\
			  <picture>\
				<source srcset="/img/connection-established.webp" type="image/webp">\
				<source srcset="/img/connection-established.png" type="image/png">\
				<img class="smallsomeInfos" href="#" rel="tooltip" data-placement="top" data-original-title="CONNECTION" src="/img/connection-established.png" alt="connection">\
			  </picture>\
		    </div>\
	      </td>\
		  <td>\
	        <div data-toggle="modal" data-remote="modals/diagnostics-network-modal.lp" data-id="diagnostics-network-modal">\
			  <picture>\
				<source srcset="/img/network_sans-32.webp" type="image/webp">\
				<source srcset="/img/network_sans-32.png" type="image/png">\
			    <img class="smallsomeInfos" href="#" rel="tooltip" data-placement="top" data-original-title="NETWORK" src="/img/network_sans-32.png" alt="network">\
			  </picture>\
			</div>\
	      </td>\
		  <td>\
	        <div data-toggle="modal" data-remote="modals/diagnostics-tcpdump-modal.lp" data-id="diagnostics-network-tcpdump">\
			    <i class="smallsomeInfos fa fa-download" style="font-size:32px;" href="#" rel="tooltip" data-placement="top" data-original-title="TCPDUMP" alt="tcpdump"></i>\
			</div>\
	      </td>\
	    </tr>\
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
