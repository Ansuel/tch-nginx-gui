--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format, match = string.format, string.match
local floor = math.floor
local tonumber = tonumber

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

-- Figure out interface state
local intf_state_map = {
    disabled = T"Bridge disabled",
    connected = T"Bridge connected",
    disconnected = T"Bridge not connected",
}

local intf_light_map = {
  disabled = "off",
  disconnected = "red",
  connected = "green",
}
local intf_state = "disabled"

local stats = {
    operstate = "sys.class.net.@ptm0.operstate",
    carrier = "sys.class.net.@ptm0.carrier",
}
content_helper.getExactContent(stats)

if stats.operstate == "up" then
    if stats.carrier ~= "0" then
        intf_state = "connected"
    else
        intf_state = intf_state ~= "connected" and "disconnected"
    end
end


-- xdsl data
local xdsl_data = {
  dsl_enable = "sys.class.xdsl.@line0.Enable",
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


local session = ngx.ctx.session
local modalPath

if session:hasAccess("/modals/broadband-modal.lp") then
    modalPath = "modals/broadband-modal.lp"
end
  ngx.print('\
\
');  ngx.print( ui_helper.createCardHeader(T"Broadband", modalPath) ); ngx.print('\
<div class="content card_bg" data-bg-text="&#xf0b2;">\
<div class="divtable">\
  ');  
    local html = {
      ui_helper.createSimpleLight(nil, intf_state_map[intf_state], {light = {class = intf_light_map[intf_state]}}),
      '<p class="subinfos">',
      "",
      '</p>',
    }
    ngx.print(html)
	if xdsl_data["dsl_enable"] == "1" then
		local iconUp = "<i class=\"icon-upload icon-small gray\"></i> "
		local iconDown = " <i class=\"icon-download icon-small gray\"></i> "
		
		if (xdsl_data["dsl_status"] == "Up") or (other_line_xdsl_data["dsl_status"] == "Up") then
		
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
	end
    ngx.print('\
</div>\
</div>\
'); 