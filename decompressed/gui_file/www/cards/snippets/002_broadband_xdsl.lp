--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local floor = math.floor
local tonumber = tonumber
local ui_helper = require("web.ui_helper")

local dyntab_helper = require("web.dyntab_helper")
local bmh = require("broadbandmode_helper")
local tabdata = dyntab_helper.process(bmh)

local attributes = { light = { } ,span = { class = "span4" } }

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
  modalPath = "/modals/broadband-modal.lp"
end

local xdslstate = nil

if xdsl_data.dsl_status == "Up" or other_line_xdsl_data.dsl_status == "Up" then
  xdslstate = "Up"
elseif xdsl_data.dsl_status == "NoSignal" or other_line_xdsl_data.dsl_status == "NoSignal" then
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
if tabdata.current.name == "bridge" then
  ngx.print(format("<strong>%s</strong></br>",T"Bridge Mode Active"))
end
if tabdata.current.name == "voice" then
  ngx.print(format("<strong>%s</strong></br>",T"Voice Mode Active"))
end
ngx.print( ui_helper.createSimpleLight(intf_light_map[xdslstate] or "3" --[[ orange ]] ,
  ("xDSL ") .. (intf_text_map[xdslstate] or (T"Connecting" .. "...")), attributes,"fa-signal"))
if (xdslstate == "Up") then
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
