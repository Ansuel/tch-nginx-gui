--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local table = table
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local session = ngx.ctx.session
-- local tprint = require("tch.tableprint")

local uci_tod_path = "uci.tod.host."
local tod_columns = {
  {
    header = T"Hostname",
    name = "id",
    param = "id",
    type = "text",
    attr = { input = { class="span2" } },
  },
}

local tod_options = {
  tableid  = "tod",
  basepath = uci_tod_path,
}

-- get an initial read from UCI
local tod_data = post_helper.handleTableQuery(tod_columns, tod_options)

local uci_tod_dnd_path = "uci.tod.dnd."
local tod_dnd_columns = {
  {
    header = T"Hostname",
    name = "id",
    param = "id",
    type = "text",
    attr = { input = { class="span2" } },
  },
}

local tod_dnd_options = {
  tableid  = "tod",
  basepath = uci_tod_dnd_path,
}

-- get an initial read from UCI
local tod_dnd_data = post_helper.handleTableQuery(tod_dnd_columns, tod_dnd_options)

-- get wifi tod
local todwifi = require("parental_helper").getTodwifi()
if todwifi then
local todwifi_columns, todwifi_default, todwifi_valid, todwifi_sort_func =
      todwifi.columns, todwifi.default, todwifi.valid, todwifi.sort_func

local todwifi_options = {
    tableid     = "tod",
    basepath    = "rpc.wifitod.",
}

local todwifi_data = post_helper.handleTableQuery(todwifi_columns, todwifi_options, nil, todwifi_default, todwifi_valid)

end

-- get rules' count
local rulecount = (type(tod_data)=="table") and #tod_data or 0
local rulecount_wifi = (type(todwifi_data)=="table") and #todwifi_data or 0
local rulecount_dnd = (type(tod_dnd_data)=="table") and #tod_dnd_data or 0

if session:hasAccess("/modals/tod-modal.lp") then

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

