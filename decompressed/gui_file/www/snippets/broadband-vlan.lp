--pretranslated: do not change this file

-- NG.... to support vlan device methode

-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local bmh = require("broadbandmode_helper")

local session = ngx.ctx.session
local tech = false
if session:getrole() == "engineer" then
   tech = true
end

function getValidateNumberInRange(min, max, value)
    local helptext = T"Input must be a number"
    if min and max then
        helptext = string.format(T"Input must be a number between %d and %d included", min, max)
    elseif not min and not max then
        helptext = T"Input must be a number"
    elseif not min then
        helptext = string.format(T"Input must be a number smaller than %d included", max)
    elseif not max then
        helptext = string.format(T"Input must be a number greater than %d included", min)
    end


        local num = tonumber(value)
        if not num then
            return nil, helptext
        end
        if min and num < min then
            return nil, helptext
        end
        if max and num > max then
            return nil, helptext
        end
        return true

end

local bridge = require("bridgehelper")
local manual = bridge.get("uci.wansensing.global.enable") ~= "1"
local channel = bridge.vlanContext()
local helpmes

if tech and manual and ngx.var.request_method == "POST" then
    local content = ngx.req.get_post_args()
    if content.action == "SAVE" and content.intf_vlan ~= nil then
        local enabled = content.intf_vlan ~= "0"
        local valid = true
        if enabled then
            valid, helpmes = getValidateNumberInRange(2, 2048, content.intf_vlanid)
            valid = valid and type(content.intf_vlanid) == "string" and content.intf_vlanid:match("^%d+$")
            valid = valid and (content.auswahlliste == "devnot" or content.auswahlliste == "dotnot")
        end
        if channel.connection == "" then valid = false end
        if valid then
            local ok, err = true, nil
            local ifname = channel.connection
            if enabled and content.auswahlliste == "devnot" then
                local name = bridge.get(channel.path .. "name")
                if not name then
                    name = channel.path:match("@([^%.]+)%.$")
                    ok, err = proxy.add("uci.network.device.", name)
                end
                if ok then
                    ok, err = proxy.set({
                        [channel.path .. "type"] = channel.vlanType,
                        [channel.path .. "name"] = name,
                        [channel.path .. "vid"] = content.intf_vlanid,
                        [channel.path .. "ifname"] = channel.connection,
                    })
                end
                ifname = name
            else
                -- Release the previous named VLAN before using dot notation or
                -- the untagged parent. Do not alter an unrelated fallback device.
                if channel.notation == "devnot" and channel.difname ~= "" then
                    ok, err = proxy.set(channel.path .. "ifname", "")
                end
                if enabled then ifname = channel.connection .. "." .. content.intf_vlanid end
            end
            if ok then ok, err = bridge.setUplink(ifname) end
            if ok then ok, err = proxy.apply() end
            if not ok then
                message_helper.pushMessage(err or T"Error while applying changes", "error")
            end
            channel = bridge.vlanContext()
        else
            message_helper.pushMessage(helpmes or T"Invalid input", "error")
        end
    end
end

local vid = channel.vid
local difname = channel.difname or ""
local check = channel.notation
local b = difname ~= "" and channel.connection or "empty"

local intf_state = "disabled"

local intf_state_map = {
    disabled = T"VLAN disabled",
    connected = T"VLAN enabled",
    disconnected = T"VLAN not connected",
}

local intf_light_map = {
  disabled = "off",
  disconnected = "red",
  connected = "green",
}

if difname ~= "" then
        intf_state = "connected"
else
    intf_state = "disabled"
end

ngx.print('\
<fieldset>\
\
    '); ngx.print(ui_helper.createMessages(message_helper.popMessages())) ngx.print('\
\
  <legend>'); ngx.print( T"Internet channel" ); ngx.print('</legend>');

	liste = {	{"devnot", T"Device &nbsp;"},
				{"dotnot", T"Dot"},
			}
	
    local html = {}
    local vlanswitchclass = {
        input = {
            class = "monitor-changes"
        },
		values = {on = b, off = ""},

    }
	
    local vlanidclass = {
        group = {
            class =string.format("monitor-intf_vlan monitor-%s",b),
        },
    }
	if tech and manual then
    html[#html + 1] = ui_helper.createSwitch(T"Using VLAN", "intf_vlan", difname, vlanswitchclass)
	html[#html + 1] = ui_helper.createInputRadio(T"Notation", "auswahlliste" , liste, check, vlanidclass)
    html[#html + 1] = ui_helper.createInputText(T"VLAN ID", "intf_vlanid", vid, vlanidclass, helpmes)
	else
	html[#html + 1] = ui_helper.createLight(T"Using VLAN", nil, intf_state_map[intf_state], { light = { class = intf_light_map[intf_state] } })
	html[#html + 1] = ui_helper.createLabel(T"VLAN ID", vid)
	end
    ngx.print(html)
	
  ngx.print('\
</fieldset>\
');
