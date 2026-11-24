--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local floor = math.floor
local tonumber = tonumber
local ui_helper = require("web.ui_helper")

local attributes = { light = {}, span = {} }
local get_optional_content = require("internethelper").getOptionalContent

local status = {
  line0 = "sys.class.xdsl.@line0.Status",
  line1 = "sys.class.xdsl.@line1.Status",
}
get_optional_content(status)

local session = ngx.ctx.session

local modalPath

if session:hasAccess("/modals/broadband-modal.lp") then
  switchName = "dsl_enable"
  modalPath = "/modals/broadband-modal.lp"
end

local xdslstate = nil

if status.line0 == "Up" or status.line1 == "Up" then
  xdslstate = "Up"
elseif status.line0 == "NoSignal" or status.line1 == "NoSignal" then
  xdslstate = "NoSignal"
end

local intf_light_map = {
  NoSignal = "4",--"red"
  Up = "1",--"green"
}

local intf_text_map = {
  NoSignal = T"Disconnected",--"red"
  Up = T"Connected",--"green"
}

attributes.light.id = "Broadband_LED"
attributes.span.id = "Broadband_State_Enabled"

ngx.print( ui_helper.createCardHeader(T"Broadband", modalPath) ); ngx.print('\
<div class="content card_bg" data-bg-text="&#xf0b2;">\
<div class="divtable">\
');
local iconUp = '<i class="icon-upload icon-small gray"></i> '
local iconDown = '<i class="icon-download icon-small gray"></i> '
ngx.print( ui_helper.createSimpleLight(intf_light_map[xdslstate] or "3" --[[ orange ]] ,
  ("xDSL ") .. (intf_text_map[xdslstate] or (T"Connecting" .. "...")), attributes,"fa-signal"))
if xdslstate == "Up" then
  local rates = {
    line0_up = "sys.class.xdsl.@line0.UpstreamCurrRate",
    line0_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
    line1_up = "sys.class.xdsl.@line1.UpstreamCurrRate",
    line1_down = "sys.class.xdsl.@line1.DownstreamCurrRate",
  }
  get_optional_content(rates)
  -- The link can still report Up while the driver clears the line rates.
  local rate_up = tonumber(rates.line0_up)
  local rate_down = tonumber(rates.line0_down)
  local other_line_rate_up = tonumber(rates.line1_up)
  local other_line_rate_down = tonumber(rates.line1_down)

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
      '<p  id="Line_Rate_Down" class="subinfos">&emsp; ',
      iconDown,
      format('%.2f Mbps', rate_down),
      "</p>",
      '<p  id="Line_Rate_Up" class="subinfos">&emsp; ',
      iconUp,
      format("%.2f Mbps", rate_up),
      "</p>"
    )
  end
end
ngx.print('\
</div>\
</div>');
