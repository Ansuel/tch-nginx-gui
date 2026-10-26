--pretranslated: do not change this file
 
-- Hide Switch for user admin to enable/disable DSL
-- Enable localization
-- NG-88797 WAN statistics is not automatically getting updates as LAN statistics
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local format = string.format
local floor = math.floor
local tonumber = tonumber

local iconUp = "<i class=\"icon-upload icon-large gray\"></i> "
local iconDown = "<i class=\"icon-download icon-large gray\"></i> "
local ajax_helper = require("web.ajax_helper")
local ajax_attr = {
    span = {
      ["data-ajaxrefresh"] = "5",
	  class = "span4"
    }
}

local session = ngx.ctx.session
local tech = false
local role = session:getrole()
if role == "engineer" or role == "ispuser" then
   tech = true
end

local content = {
  dsl_status = "sys.class.xdsl.@line0.Status",
  dsl_type = "sys.class.xdsl.@line0.ModulationType",
  dsl_linerate_up = "sys.class.xdsl.@line0.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
  dsl_linerate_up_max = "sys.class.xdsl.@line0.UpstreamMaxRate",
  dsl_linerate_down_max = "sys.class.xdsl.@line0.DownstreamMaxRate",
  dsl_uptime = "sys.class.xdsl.@line0.ShowtimeStart",
  dsl_power_up = "sys.class.xdsl.@line0.UpstreamPower",
  dsl_power_down = "sys.class.xdsl.@line0.DownstreamPower",
  dsl_attenuation_up = "sys.class.xdsl.@line0.UpstreamAttenuation",
  dsl_attenuation_down = "sys.class.xdsl.@line0.DownstreamAttenuation",
  dsl_margin_up = "sys.class.xdsl.@line0.UpstreamNoiseMargin",
  dsl_margin_down = "sys.class.xdsl.@line0.DownstreamNoiseMargin",
  dsl_transfered_up = "sys.class.xdsl.@line0.BytesSent",
  dsl_transfered_down = "sys.class.xdsl.@line0.BytesReceived",
  dsl_downstream_delay = "sys.class.xdsl.@line0.DownstreamDelay",
  dsl_bonding_support = "sys.class.xdsl.@line0.BondingSupport",
}

local content_other_line = {
  dsl_status = "sys.class.xdsl.@line1.Status",
  dsl_type = "sys.class.xdsl.@line1.ModulationType",
  dsl_linerate_up = "sys.class.xdsl.@line1.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line1.DownstreamCurrRate",
  dsl_linerate_up_max = "sys.class.xdsl.@line1.UpstreamMaxRate",
  dsl_linerate_down_max = "sys.class.xdsl.@line1.DownstreamMaxRate",
  dsl_uptime = "sys.class.xdsl.@line1.ShowtimeStart",
  dsl_power_up = "sys.class.xdsl.@line1.UpstreamPower",
  dsl_power_down = "sys.class.xdsl.@line1.DownstreamPower",
  dsl_attenuation_up = "sys.class.xdsl.@line1.UpstreamAttenuation",
  dsl_attenuation_down = "sys.class.xdsl.@line1.DownstreamAttenuation",
  dsl_margin_up = "sys.class.xdsl.@line1.UpstreamNoiseMargin",
  dsl_margin_down = "sys.class.xdsl.@line1.DownstreamNoiseMargin",
  dsl_transfered_up = "sys.class.xdsl.@line1.BytesSent",
  dsl_transfered_down = "sys.class.xdsl.@line1.BytesReceived",
  dsl_downstream_delay = "sys.class.xdsl.@line1.DownstreamDelay",
}

-- Get the content
content_helper.getExactContent(content)
content_helper.getExactContent(content_other_line)

ajax_helper.handleAjaxQuery({dsl_uptime = "sys.class.xdsl.@line0.ShowtimeStart"}, function(c)
    c.dsl_uptime = post_helper.secondsToTime(c["dsl_uptime"])
	local function notnil(path)
		if path == nil or path == "" then
			return "0"
		end
		return path
	end
	c.dsl_max_linerate = format("%s %s Mbps %s %s Mbps", iconUp, floor(tonumber(notnil(content.dsl_linerate_up_max))/10)/100, iconDown, floor(tonumber(notnil(content.dsl_linerate_down_max))/10)/100)
	c.dsl_linerate = format("%s %s Mbps %s %s Mbps", iconUp, floor(tonumber(notnil(content.dsl_linerate_up))/10)/100, iconDown, floor(tonumber(notnil(content.dsl_linerate_down))/10)/100)
	c.dsl_transfered = format("%s %s MBytes %s %s MBytes", iconUp, floor(tonumber(notnil(content.dsl_transfered_up))/ 1048576 * 100)/100, iconDown, floor(tonumber(notnil(content.dsl_transfered_down))/ 1048576 * 100)/100)
	c.dsl_power = format("%s %s dBm %s %s dBm", iconUp, notnil(content.dsl_power_up), iconDown, notnil(content.dsl_power_down))
	c.dsl_attenuation = format("%s %s dB %s %s dB", iconUp, notnil(content.dsl_attenuation_up), iconDown, notnil(content.dsl_attenuation_down))
	c.dsl_margin = format("%s %s dB %s %s dB", iconUp, notnil(content.dsl_margin_up), iconDown, notnil(content.dsl_margin_down))
end)

local DSLMode
local ddd = tonumber(content["dsl_downstream_delay"])
if not ddd then
    DSLMode = ""
elseif ddd>2 then
    DSLMode = "Interleaved"
else
    DSLMode = "Fast"
end

local DSLMode_other_line
local ddd = tonumber(content_other_line["dsl_downstream_delay"])
if not ddd then
    DSLMode_other_line = ""
elseif ddd>2 then
    DSLMode_other_line = "Interleaved"
else
    DSLMode_other_line = "Fast"
end

local showBondingStats
local bstats = tonumber(content["dsl_bonding_support"])
if bstats == 1 then
  showBondingStats = true
else
  showBondingStats = false
end

-- DSL enable switch
local dsl_switch_params = {
    dsl_enable = "sys.class.xdsl.@line0.Enable",
}
local dsl_switch_valid = {
    dsl_enable = post_helper.validateBoolean,
}
local dsl_switch_data, dsl_switch_helpmsg = post_helper.handleQuery(dsl_switch_params, dsl_switch_valid)

  ngx.print('\
\
<fieldset>\
  ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.print('\
  <legend>');  ngx.print( T"Physical link status" ); ngx.print('</legend>\
\
  ');  
    local html = {}

    -- Icons
    local statusIcon
    if (content["dsl_status"] == "Up") or (content_other_line["dsl_status"] == "Up") then
      statusIcon = "<div class=\"light green\" id = \"DSL_Status_Id\"></div>"
    elseif content["dsl_status"] == "NoSignal" and (content_other_line["dsl_status"] == "NoSignal") then
      statusIcon = "<div class=\"light red\" id = \"DSL_Status_Id\"></div>"
    else
      statusIcon = "<div class=\"light orange\" id = \"DSL_Status_Id\"></div>"
    end
    local iconUp = "<i class=\"icon-upload icon-large gray\"></i> "
    local iconDown = " <i class=\"icon-download icon-large gray\"></i> "

    -- Attributes
    local attributes = { span = { class = "span4" } }
    local attributesAdvanced = { group = { class = "advanced hide" }, span = { class = "span4" } }

    -- Display the xdsl status
    if content_other_line["dsl_status"] == "Up" then
      html[#html + 1] =
        ui_helper.createLabel(
          T"DSL Status",
          format("%s%s", statusIcon, T(content_other_line["dsl_status"]))
                                  -- ^this does not work !!!!
        )
    else
      html[#html + 1] =
        ui_helper.createLabel(
          T"DSL Status",
          format("%s%s", statusIcon, T(content["dsl_status"]))
                                  -- ^this does not work !!!!
        )
    end
    if tech then
      html[#html + 1] = ui_helper.createSwitch(T"DSL Enabled", "dsl_enable", dsl_switch_data["dsl_enable"])
    else
      local intf_state = "disabled"
      local intf_state_map = {
      disabled = T"disabled",
      connected = T"enabled",
      disconnected = T"VLAN not connected",
      }

      local intf_light_map = {
      disabled = "off",
      disconnected = "red",
      connected = "green",
      }

      if dsl_switch_data["dsl_enable"] == "1" then
	intf_state = "connected"
      else
	intf_state = "disabled"
      end
	html[#html + 1] = ui_helper.createLight(T"DSL", nil, intf_state_map[intf_state], { light = { class = intf_light_map[intf_state] } })
    end
    -- Statistics are only relevant if xdsl status is up
    if (content["dsl_status"] == "Up") or (content_other_line["dsl_status"] == "Up") then
      if( content["dsl_status"] == "Up") then
	ajax_attr.span.id = "dsl_uptime"
        html[#html + 1] = ui_helper.createLabel(T"DSL Uptime", post_helper.secondsToTime(content["dsl_uptime"]), ajax_attr)
        html[#html + 1] = ui_helper.createLabel(T"DSL Type", T(content["dsl_type"]), attributesAdvanced)
        html[#html + 1] = ui_helper.createLabel(T"DSL Mode", T(DSLMode), attributesAdvanced)
      else
	ajax_attr.span.id = "dsl_uptime"
        html[#html + 1] = ui_helper.createLabel(T"DSL Uptime", post_helper.secondsToTime(content_other_line["dsl_uptime"]), ajax_attr)
        html[#html + 1] = ui_helper.createLabel(T"DSL Type", T(content_other_line["dsl_type"]), attributesAdvanced)
        html[#html + 1] = ui_helper.createLabel(T"DSL Mode", T(DSLMode_other_line), attributesAdvanced)
      end

      -- Display the xdsl maximum line rate
      local dslLineRateMaxUp, dslLineRateMaxDown = 0, 0
      local otherDslLineRateMaxUp, otherDslLineRateMaxDown = 0, 0
      if tonumber(content["dsl_linerate_up_max"]) ~= nil and tonumber(content["dsl_linerate_down_max"]) ~= nil then
        dslLineRateMaxUp = floor(content["dsl_linerate_up_max"] / 10) / 100
        dslLineRateMaxDown = floor(content["dsl_linerate_down_max"] / 10) / 100
      end
      if tonumber(content_other_line["dsl_linerate_up_max"]) ~= nil and tonumber(content_other_line["dsl_linerate_down_max"]) ~= nil then
    otherDslLineRateMaxUp = floor(content_other_line["dsl_linerate_up_max"] / 10) / 100
        otherDslLineRateMaxDown = floor(content_other_line["dsl_linerate_down_max"] / 10) / 100
  end
      ajax_attr.span.id = "dsl_max_linerate"
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Maximum Line rate",
            format("%s %s Mbps %s %s Mbps", iconUp, dslLineRateMaxUp, iconDown, dslLineRateMaxDown),
            ajax_attr
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Maximum Line rate",
            format("%s %s Mbps %s %s Mbps | %s %s Mbps %s %s Mbps", iconUp, dslLineRateMaxUp, iconDown, dslLineRateMaxDown, iconUp, otherDslLineRateMaxUp, iconDown, otherDslLineRateMaxDown),
            ajax_attr
          )
      end
      -- Display the xdsl current line rate
      local dslLineRateUp, dslLineRateDown, otherDslLineRateUp, otherDslLineRateDown = 0, 0, 0, 0
      if tonumber(content["dsl_linerate_up"]) ~= nil and tonumber(content["dsl_linerate_down"]) ~= nil then
        dslLineRateUp = floor(content["dsl_linerate_up"] / 10) / 100
        dslLineRateDown = floor(content["dsl_linerate_down"] / 10) / 100
      end
      if tonumber(content_other_line["dsl_linerate_up"]) ~= nil and tonumber(content_other_line["dsl_linerate_down"]) ~= nil then
    otherDslLineRateUp = floor(content_other_line["dsl_linerate_up"] / 10) / 100
        otherDslLineRateDown = floor(content_other_line["dsl_linerate_down"] / 10) / 100
      end
      ajax_attr.span.id = "dsl_linerate"
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Rate",
            format("%s %s Mbps %s %s Mbps", iconUp, dslLineRateUp, iconDown, dslLineRateDown),
            ajax_attr
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Rate",
            format("%s %s Mbps %s %s Mbps | %s %s Mbps %s %s Mbps", iconUp, dslLineRateUp, iconDown, dslLineRateDown, iconUp, otherDslLineRateUp, iconDown, otherDslLineRateDown),
            ajax_attr
          )
      end
      -- Display the amount of data transfered over the xdsl conenction
      local dslTransferedUp, dslTransferedDown, otherDslTransferedUp, otherDslTransferedDown = 0, 0, 0, 0
      if tonumber(content["dsl_transfered_up"]) ~= nil and tonumber(content["dsl_transfered_down"]) ~= nil then
        dslTransferedUp = floor(content["dsl_transfered_up"] / 1048576 * 100) / 100
        dslTransferedDown = floor(content["dsl_transfered_down"] / 1048576 * 100) / 100
      end
      if tonumber(content_other_line["dsl_transfered_up"]) ~= nil and tonumber(content_other_line["dsl_transfered_down"]) ~= nil then
    otherDslTransferedUp = floor(content_other_line["dsl_transfered_up"] / 1048576 * 100) / 100
        otherDslTransferedDown = floor(content_other_line["dsl_transfered_down"] / 1048576 * 100) / 100
      end
      ajax_attr.span.id="dsl_transfered"
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Data Transferred",
            format("%s %s MBytes %s %s MBytes", iconUp, dslTransferedUp, iconDown, dslTransferedDown),
            ajax_attr
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Data Transferred",
            format("%s %s MBytes %s %s MBytes | %s %s MBytes %s %s MBytes", iconUp, dslTransferedUp, iconDown, dslTransferedDown, iconUp, otherDslTransferedUp, iconDown, otherDslTransferedDown),
            ajax_attr
          )
      end
      -- Display power, attenuation and noise margin
      local dslPowerUp, dslPowerDown, otherDslPowerUp, otherDslPowerDown = 0, 0, 0, 0
      if tonumber(content["dsl_power_up"]) ~= nil and tonumber(content["dsl_power_down"]) ~= nil then
        dslPowerUp = content["dsl_power_up"]
        dslPowerDown = content["dsl_power_down"]
      end
      if tonumber(content_other_line["dsl_power_up"]) ~= nil and tonumber(content_other_line["dsl_power_down"]) ~= nil then
        otherDslPowerUp = content_other_line["dsl_power_up"]
        otherDslPowerDown = content_other_line["dsl_power_down"]
      end
      ajax_attr.span.id="dsl_power"
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Output Power",
            format("%s %s dBm %s %s dBm", iconUp, dslPowerUp, iconDown, dslPowerDown),
            ajax_attr
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Output Power",
            format("%s %s dBm %s %s dBm | %s %s dBm %s %s dBm", iconUp, dslPowerUp, iconDown, dslPowerDown, iconUp, otherDslPowerUp, iconDown, otherDslPowerDown),
            ajax_attr
          )
      end
      local dslAttenuationUp, dslAttenuationDown, otherDslAttenuationUp, otherDslAttenuationDown
      dslAttenuationUp = content["dsl_attenuation_up"]
      dslAttenuationDown = content["dsl_attenuation_down"]
      otherDslAttenuationUp = content_other_line["dsl_attenuation_up"]
      otherDslAttenuationDown = content_other_line["dsl_attenuation_down"]
      ajax_attr.span.id="dsl_attenuation"
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Attenuation",
            format("%s %s dB %s %s dB", iconUp, dslAttenuationUp, iconDown, dslAttenuationDown),
            ajax_attr
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Attenuation",
            format("%s %s dB %s %s dB | %s %s dB %s %s dB", iconUp, dslAttenuationUp, iconDown, dslAttenuationDown, iconUp, otherDslAttenuationUp, iconDown, otherDslAttenuationDown),
            ajax_attr
          )
      end
      local dslMarginUp, dslMarginDown, otherDslMarginUp, otherDslMarginDown = 0, 0, 0, 0
      if tonumber(content["dsl_margin_up"]) ~= nil and tonumber(content["dsl_margin_down"]) ~= nil then
        dslMarginUp = content["dsl_margin_up"]
        dslMarginDown = content["dsl_margin_down"]
      end
      if tonumber(content_other_line["dsl_margin_up"]) ~= nil and tonumber(content_other_line["dsl_margin_down"]) ~= nil then
        otherDslMarginUp = content_other_line["dsl_margin_up"]
        otherDslMarginDown = content_other_line["dsl_margin_down"]
      end
      ajax_attr.span.id="dsl_margin"
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Noise Margin",
            format("%s %s dB %s %s dB", iconUp, dslMarginUp, iconDown, dslMarginDown),
            ajax_attr
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Noise Margin",
            format("%s %s dB %s %s dB | %s %s dB %s %s dB", iconUp, dslMarginUp, iconDown, dslMarginDown, iconUp, otherDslMarginUp, iconDown, otherDslMarginDown),
            ajax_attr
          )
      end
    end
    ngx.print(html)
    ngx.print('\
\
</fieldset>\
'); 