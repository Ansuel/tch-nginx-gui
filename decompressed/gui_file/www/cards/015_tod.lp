<%
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

if session:hasAccess("/modals/tod-modal.lp") then
%>

<div class="span3">
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">

    <%= ui_helper.createCardHeader(T"Time of Day", "/modals/tod-modal.lp") %>

    <div class="content card_bg" data-bg-text="&#xf017;">
	<div class="divtable">

    <% ngx.print(
            '<p></p>',
            '<span class="simple-desc">',
           '<i " class="far fa-eye" aria-hidden="true" href="#">&nbsp</i>',
           format(N("<strong %s>%d Access Control</strong> rule defined",
                     "<strong id=\"todcard_timeofday\" %s>%d Access Control</strong> rules defined", rulecount),
                   'class="modal-link" data-toggle="modal" data-remote="/modals/tod-modal.lp" data-id="tod-modal"',
                   rulecount),
            '</span>')
    %>

    <% if session:hasAccess("/modals/tod_wireless-modal.lp") then
       ngx.print(
            '<p></p>',
            '<span class="simple-desc">',
          '<i " class="far fa-eye" aria-hidden="true" href="#">&nbsp</i>',
          format(N("<strong %s>%d Wireless Control</strong> rule defined",
                     "<strong id=\"todcard_timeofday\" %s>%d Wireless Control</strong> rules defined", rulecount_wifi),
                   'class="modal-link" data-toggle="modal" data-remote="/modals/tod_wireless-modal.lp" data-id="tod-modal"',
                   rulecount_wifi),
            '</span>')
       end
    %>
    </div>
	</div>
  </div>
</div>
<%
end
%>
