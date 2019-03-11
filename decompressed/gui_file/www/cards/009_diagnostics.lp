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
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');

  ngx.print(ui_helper.createCardHeader(T"Diagnostics", "/modals/diagnostics-ping-modal.lp"))
  ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf085;">\
	<div class="divtable">\
     <table align="center" cellspacing="10%" cellpadding="10%" >\
      <tr>');
  if xdsl_exist then
    local dsl_data = {
      dsl_status = "sys.class.xdsl.@line0.Enable",
    }
    content_helper.getExactContent(dsl_data)
    if ( dsl_data["dsl_status"] == "1") then
      ngx.print('\
		  <td>\
		    <div data-toggle="modal" data-remote="/modals/diagnostics-xdsl-modal.lp" data-id="diagnostics-xdsl-modal">\
				<i class="smallsomeInfos modal-link fas fa-list-ul" style="font-size:32px;" href="#" rel="tooltip" data-placement="bottom" data-original-title="'); ngx.print(T"xDSL"); ngx.print('" alt="dsl"></i>\
			</div>\
		  </td>\
		   <td>\
		    <div data-toggle="modal" data-remote="/modals/diagnostics-xdsl-graphics-modal.lp" data-id="iagnostics-xdsl-graphics-modal">\
			  <i class="smallsomeInfos modal-link fas fa-chart-line" style="font-size:32px;" href="#" rel="tooltip" data-placement="bottom" data-original-title="'); ngx.print(T"xDSL Graphics"); ngx.print('" alt="dsl graph"></i>\
			</div>\
		  </td>');
    end
  end
  ngx.print('\
          <td>\
			<div data-toggle="modal" data-remote="/modals/diagnostics-ping-modal.lp" data-id="diagnostics-ping-modal">\
			    <i class="smallsomeInfos modal-link fas fa-upload" style="font-size:32px;" href="#" rel="tooltip" data-placement="bottom" data-original-title="'); ngx.print(T"Ping & Traceroute"); ngx.print('" alt="ping/trace"></i>\
			</div>\
	      </td>\
		  <td>\
	        <div data-toggle="modal" data-remote="/modals/port-mirror-modal.lp" data-id="port-mirror-modal">\
			    <i class="smallsomeInfos modal-link fas fa-exchange-alt" style="font-size:32px;" href="#" rel="tooltip" data-placement="bottom" data-original-title="'); ngx.print(T"Port Mirror"); ngx.print('" alt="port-mirror"></i>\
			</div>\
	      </td>\
	    </tr>\
        <tr>\
		  <td>\
			<div data-toggle="modal" data-remote="/modals/diagnostics-connection-modal.lp" data-id="diagnostics-connection-modal">\
				<i class="smallsomeInfos modal-link far fa-lightbulb" style="font-size:32px;" href="#" rel="tooltip" data-placement="top" data-original-title="'); ngx.print(T"Connection"); ngx.print('" alt="connection"></i>\
		    </div>\
	      </td>\
		  <td>\
	        <div data-toggle="modal" data-remote="/modals/diagnostics-network-modal.lp" data-id="diagnostics-network-modal">\
			  <i class="smallsomeInfos modal-link fas fa-plug" style="font-size:32px;" href="#" rel="tooltip" data-placement="top" data-original-title="'); ngx.print(T"Network"); ngx.print('" alt="network"></i>\
			</div>\
	      </td>\
		  <td>\
	        <div data-toggle="modal" data-remote="/modals/diagnostics-tcpdump-modal.lp" data-id="diagnostics-network-tcpdump">\
			  <i class="smallsomeInfos modal-link fa fa-download" style="font-size:32px;" href="#" rel="tooltip" data-placement="top" data-original-title="'); ngx.print(T"TCPDump"); ngx.print('" alt="tcpdump"></i>\
			</div>\
	      </td>\
	    </tr>\
      </table>\
    </div>\
	</div>\
  </div>\
  <script>\
  $(document).ready(function(){\
  var tsmall = $(".smallsomeInfos");\
	tsmall.on("click", function () {\
		tsmall.tooltip("hide");\
	});\
	tsmall.tooltip();\
  });\
  </script>\
</div>\
');
end
