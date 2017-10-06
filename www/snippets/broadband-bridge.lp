--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local format = string.format
local floor = math.floor
local tonumber = tonumber

local wan = {
    iface = "uci.network.interface.@wan.ifname",
}
content_helper.getExactContent(wan)

-- Figure out interface state
local intf_state_map = {
    disabled = T"disabled",
    connected = T"connected",
    disconnected = T"not connected",
}

local intf_light_map = {
  disabled = "off",
  disconnected = "red",
  connected = "green",
}

local content = {
  dsl_enable = "sys.class.xdsl.@line0.Enable",
}

content_helper.getExactContent(content)

  ngx.print('\
\
<fieldset>\
  <legend>');  ngx.print( T"Physical link status" ); ngx.print('</legend>\
\
  ');  
    local html = {}
    -- Label that shows Bridge status
    for v in string.gmatch(wan.iface, "[^%s]+") do
        local intf_state = "disabled"
        -- Here we just try to remove the potential vlan id from the interface name.
        local iface = string.match(v, "([^%.]+)")
        iface = iface:untaint()
        local stats = {
            operstate = "sys.class.net.@" .. iface .. ".operstate",
            carrier = "sys.class.net.@" .. iface .. ".carrier",
        }
        content_helper.getExactContent(stats)

        if stats.operstate == "up" then
            if stats.carrier ~= "0" then
                intf_state = "connected"
            else
                intf_state = "disconnected"
            end
        end
        local label = format(T"Interface %s status", v)
        html[#html + 1] = ui_helper.createLight(label, nil, intf_state_map[intf_state], {light = {class = intf_light_map[intf_state]}})
    end
	ngx.print(html)
	if content["dsl_enable"] == "1" then
		lp.setpath("/www/snippets/")
		lp.include("broadband-xdsl.lp")
	end
    ngx.print(html)
	lp.setpath("/www/snippets/")
	lp.include("broadband-vlan.lp")
    ngx.print('\
</fieldset>\
'); 