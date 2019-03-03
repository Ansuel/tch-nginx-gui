--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/firewall-modal.lp") then
    modalPath = "/modals/firewall-modal.lp"
end
local content = {
    mode = "rpc.network.firewall.mode",
    numrules = "rpc.network.firewall.UserRuleNumberOfEntries",
    numrules_v6 = "rpc.network.firewall.UserRuleV6NumberOfEntries",
}

content_helper.getExactContent(content)

local modes = setmetatable({
    lax = T"low",
    normal = T"medium",
    high = T"high",
    user = T"user"
    }, untaint_mt)

  ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print( ui_helper.createCardHeader(T"Firewall", modalPath, switchName, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf074;">\
	<div class="divtable">\
      <p class="subinfos">\
        ');  
            local html = {}
            html[#html+1] = '<i style="margin-left:-20px;" class="fas fa-shield-alt" aria-hidden="true" href="#">&nbsp</i>' .. format(T"Firewall level: <strong id=\"Firewall_Level_ID\">%s</strong><br>", modes[content.mode] or "")
            if content.mode == "user" then
                html[#html+1] = format(T"<strong>%d</strong> IPv4 rule(s) defined<br>", content.numrules)
                html[#html+1] = format(T"<strong>%d</strong> IPv6 rule(s) defined", content.numrules_v6)
            end
            ngx.print(html)
          ngx.print('\
      </p>\
    </div>\
	</div>\
  </div>\
</div>\
'); 