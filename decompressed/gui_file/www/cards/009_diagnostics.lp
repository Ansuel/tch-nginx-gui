--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local lfs = require("lfs")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local format = string.format
local tinsert = table.insert
local session = ngx.ctx.session

local dsl_enabled = proxy.get("uci.xdsl.xdsl.@dsl0.enabled")

local function genIcon(id,text,icons,tooltip_pos)
	
	local html = {}

	html[#html+1] = '<td>'
	html[#html+1] = format('<div id="diagnosticIcons" data-toggle="modal" data-remote="/modals/%s.lp" data-id="%s">',id,id)
	html[#html+1] = format('<i class="smallsomeInfos modal-link %s" style="font-size:32px;" href="#" \
			rel="tooltip" data-placement="%s" data-original-title="%s" alt="%s"></i>',icons,tooltip_pos,T(text),T(text))
	html[#html+1] = '</div>'
	html[#html+1] = '</td>'
	
	return html
end

local icons = {
	{"diagnostics-ping-modal","Ping & Traceroute","fas fa-upload"},
	{"port-mirror-modal","Port Mirror","fas fa-exchange-alt"},
	{"diagnostics-connection-modal","Connection","far fa-lightbulb"},
	{"diagnostics-network-modal","Network","fas fa-plug"},
	{"diagnostics-tcpdump-modal","TCPDump","fa fa-download"},
}

if lfs.attributes("/etc/config/xdsl", "mode") == "file" and dsl_enabled and dsl_enabled[1].value == "1" then
  tinsert(icons,1,{"diagnostics-xdsl-modal","xDSL","fas fa-list-ul"})
  tinsert(icons,2,{"diagnostics-xdsl-graphics-modal","xDSL Graphics","fas fa-chart-line"})
end

if lfs.attributes("/etc/config/bcm_spdsvc", "mode") == "file" then
  tinsert(icons,{"speedservice-modal","SpeedTest Service","fas fa-tachometer-alt"})
end

  ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');

  ngx.print(ui_helper.createCardHeader(T"Diagnostics", "/modals/diagnostics-ping-modal.lp"))
  ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf085;">\
	<div id="diagnosticCard">')
	 
		for i, v in pairs(icons) do
			if session:hasAccess(format("/modals/%s.lp",v[1])) then
				ngx.print(genIcon(v[1],v[2],v[3], i < 5 and "bottom" or "top"))
			end
		end

	  ngx.print('\
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
