--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local session = ngx.ctx.session
if session:hasAccess("/modals/tod-modal.lp") then

local tod_paths = {
	tod = "uci.tod.hostNumberOfEntries",
	dnd = "uci.tod.voicedndNumberOfEntries",
	wifi = "uci.tod.wifitodNumberOfEntries",
}

content_helper.getExactContent(tod_paths)

local rulecount = tod_paths.tod or 0
local rulecount_wifi = tod_paths.wifi or 0
local rulecount_dnd = tod_paths.dnd or 0


ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    '); ngx.print(ui_helper.createCardHeader(T"Time of Day", "/modals/tod-modal.lp")); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf017;">\
	<div class="divtable">\
	')
    ngx.print(
            '<span class="simple-desc">',
           '<i " class="far fa-eye" aria-hidden="true" href="#">&nbsp</i>',
           format(N("<strong %s>%d Access Control</strong> rule defined",
                     "<strong id=\"todcard_timeofday\" %s>%d Access Control</strong> rules defined", rulecount),
                   'class="modal-link" data-toggle="modal" data-remote="/modals/tod-modal.lp" data-id="tod-modal"',
                   rulecount),
            '</span>')

    if session:hasAccess("/modals/tod_wireless-modal.lp") then
       ngx.print(
            '<span class="simple-desc">',
          '<i " class="far fa-eye" aria-hidden="true" href="#">&nbsp</i>',
          format(N("<strong %s>%d Wireless Control</strong> rule defined",
                     "<strong id=\"todcard_timeofday\" %s>%d Wireless Control</strong> rules defined", rulecount_wifi),
                   'class="modal-link" data-toggle="modal" data-remote="/modals/tod_wireless-modal.lp" data-id="tod-modal"',
                   rulecount_wifi),
            '</span>')
       end
	if session:hasAccess("/modals/tod_dnd-modal.lp") then
       ngx.print(
            '<span class="simple-desc">',
          '<i " class="far fa-eye" aria-hidden="true" href="#">&nbsp</i>',
          format(N("<strong %s>%d DoNotDisturb Control</strong> rule defined",
                     "<strong id=\"todcard_timeofday\" %s>%d DoNotDisturb Control</strong> rules defined", rulecount_dnd),
                   'class="modal-link" data-toggle="modal" data-remote="/modals/tod_dnd-modal.lp" data-id="tod-modal"',
                   rulecount_dnd),
            '</span>')
       end
	ngx.print('\
    </div>\
	</div>\
  </div>\
</div>\
')

end

