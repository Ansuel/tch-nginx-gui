--pretranslated: do not change this file

gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local escape = require("web.web").html_escape
local stats = require("internethelper").getWanStats()

ngx.print([=[
<div class="infocard" id="wanstatsinfotab">
  <div class="smallcard">
]=])
ngx.print(ui_helper.createCardHeader(T"WAN Stats", nil, nil, nil, nil))
ngx.print([=[
    <div class="content card_bg" data-bg-text="&#xf0ac;">
      <div class="divtable">
        <form class="form-horizontal">
          <fieldset>
]=])
for _, field in ipairs({
    {"status", T"Status"},
    {"broadband", T"Broadband Connection"},
    {"connection", T"Connection Type"},
    {"ipv4", T"IPv4 address"},
    {"ipv6", T"IPv6 address"},
    {"concentrator", T"Concentrator Name"},
    {"gateway", T"Gateway"},
    {"dns", T"DNS servers"},
    {"uptime", T"Uptime"},
}) do
    local key, label = field[1], field[2]
    local value = stats[key]
    local markup = '<span data-wan-value>' .. escape(value or "") .. '</span>'
    if key == "status" then
        markup = '<i aria-hidden="true" class="light_icon fa fa-at ' ..
            (stats.connected and "green" or "off") .. '"></i>' .. markup
    end
    ngx.print(ui_helper.createLabel(label, markup, {
        group = {["data-wan-field"] = key, style = (not value or value == "") and "display:none" or nil},
        span = {style = "width:auto;overflow-wrap:break-word"},
    }))
end
ngx.print([=[
          </fieldset>
        </form>
      </div>
    </div>
  </div>
</div>
<script>
$(document).ready(function () {
    var card = document.getElementById("wanstatsinfotab");
    if (!card) return;
    var rows = $(card).find("[data-wan-field]");
    function refreshWanStats() {
        var send = window.modguiDashboardRequest || $.ajax;
        return send({
            url: "/ajax/internet.lua?datatype=wanstats&auto_update=true",
            type: "POST",
            data: [tch.elementCSRFtoken()],
            dataType: "json",
            timeout: 8000,
            success: function(data) {
                if (document.getElementById("wanstatsinfotab") !== card || !data) return;
                rows.each(function () {
                    var row = $(this);
                    var key = row.attr("data-wan-field");
                    var value = data[key];
                    var available = typeof value === "string" && /\S/.test(value);
                    row.find("[data-wan-value]").text(available ? value : "");
                    if (key === "status") {
                        row.find(".light_icon").toggleClass("green", data.connected === true)
                            .toggleClass("off", data.connected !== true);
                    }
                    row.toggle(available);
                });
            }
        });
    }
    new modgui.createAjaxUpdateCard("wanstatsinfotab", null, "InfoWanStatsCardInterval", 5000, refreshWanStats);
});
</script>
]=])
