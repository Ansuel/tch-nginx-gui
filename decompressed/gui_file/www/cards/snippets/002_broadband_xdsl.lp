<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local floor = math.floor
local tonumber = tonumber
local ui_helper = require("web.ui_helper")

local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")

-- xdsl data
local xdsl_data = {
  dsl_status = "sys.class.xdsl.@line0.Status",
  dsl_linerate_up = "sys.class.xdsl.@line0.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
}
content_helper.getExactContent(xdsl_data)

local other_line_xdsl_data = {
  dsl_status = "sys.class.xdsl.@line1.Status",
  dsl_linerate_up = "sys.class.xdsl.@line1.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line1.DownstreamCurrRate",
}
content_helper.getExactContent(other_line_xdsl_data)

-- DSL enable switch
local dsl_switch_params = {
  dsl_enable = "sys.class.xdsl.@line0.Enable",
}
local dsl_switch_valid = {
    dsl_enable = post_helper.validateBoolean,
}
local dsl_switch_data, dsl_switch_helpmsg = post_helper.handleQuery(dsl_switch_params, dsl_switch_valid)

local session = ngx.ctx.session

local switchName
local modalPath

if session:hasAccess("/modals/broadband-modal.lp") then
    switchName = "dsl_enable"
    modalPath = "modals/broadband-modal.lp"
end
%>

<%= ui_helper.createCardHeader(T"Broadband", modalPath) %>
<div class="content card_bg" data-bg-text="&#xf0b2;">
<div class="divtable">
<%
  local iconUp = "<i class=\"icon-upload icon-small gray\"></i> "
  local iconDown = " <i class=\"icon-download icon-small gray\"></i> "

  if (xdsl_data["dsl_status"] == "Up") or (other_line_xdsl_data["dsl_status"] == "Up") then
    ngx.print(
      "<div class=\"light green\" id=\"Broadband_LED\"></div><p id=\"Broadband_Status_Id\">",
      T"Connected",
      "</p>"
    )
    -- After disabling broadband the page immediately refreshes. At this time the state is still up but the line
    -- rate is already cleared.
    local rate_up = tonumber(xdsl_data["dsl_linerate_up"])
    local rate_down = tonumber(xdsl_data["dsl_linerate_down"])
    local other_line_rate_up = tonumber(other_line_xdsl_data["dsl_linerate_up"])
    local other_line_rate_down = tonumber(other_line_xdsl_data["dsl_linerate_down"])

    if (rate_up and rate_down) or (other_line_rate_up and other_line_rate_down) then
      if rate_up and rate_down then
        rate_up = floor(rate_up / 10) / 100
        rate_down = floor(rate_down / 10) / 100
      else
        rate_up = 0
        rate_down = 0
      end
      if other_line_rate_up and other_line_rate_down then
        rate_up = rate_up + (floor(other_line_rate_up / 10) / 100)
        rate_down = rate_down + (floor(other_line_rate_down / 10) / 100)
      end
      ngx.print(
        "<p  id=\"Line_Rate_Up\" class=\"subinfos\">&emsp; ",
        iconUp,
        format("%.2f Mbps", rate_up),
        "</p>",
        "<p  id=\"Line_Rate_Down\" class=\"subinfos\">&emsp; ",
        iconDown,
        format('%.2f Mbps', rate_down),
        "</p>"
      )
    end
  elseif xdsl_data["dsl_status"] == "NoSignal" and other_line_xdsl_data["dsl_status"] == "NoSignal" then
    ngx.print(
      "<div class=\"light red\" id=\"Broadband_LED\"></div><p>",
      T"Disconnected",
      "</p>"
    )
  elseif xdsl_data["dsl_status"] == "Unknown" then
    ngx.print(
      "<div class=\"light orange\" id=\"Broadband_LED\"></div><p>",
      T"Connecting",
      "</p>"
    )
  else
    ngx.print(
      "<div class=\"light orange\" id=\"Broadband_LED\"></div><p>",
      T"Connecting",
      ": ",
      T(xdsl_data["dsl_status"]),
      "...</p>"
    )
  end
%>
</div>
</div>
