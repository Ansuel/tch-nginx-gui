--pretranslated: do not change this file

-- NG.... to support vlan device methode

-- Enable localization
gettext.textdomain('webui-core')

local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")

local session = ngx.ctx.session
local tech = false
if session:getrole() == "engineer" then
   tech = true
end

local bridge = require("bridgehelper")
local manual = bridge.get("uci.wansensing.global.enable") ~= "1"
local channel = bridge.vlanContext()
local helpmes

if tech and manual and ngx.var.request_method == "POST" then
    local content = ngx.req.get_post_args()
    if content.action == "SAVE" and content.intf_vlan ~= nil
        and (content.intf_vlan ~= "0" or channel.difname ~= "") then
        local enabled = content.intf_vlan == "1"
        local valid = enabled or content.intf_vlan == "0"
        local vid
        if enabled then
            -- Homeware wraps POST strings in tainted userdata.
            vid = string.untaint and string.untaint(content.intf_vlanid) or content.intf_vlanid
            if type(vid) == "string" and vid:match("^%d+$") then
                valid, helpmes = post_helper.getValidateNumberInRange(2, 2048)(vid)
            else
                valid = false
            end
            valid = valid and (content.auswahlliste == "devnot" or content.auswahlliste == "dotnot")
        end
        if channel.connection == "" then valid = false end
        if valid then
            local ok, err = true, nil
            local ifname = channel.connection
            if enabled and content.auswahlliste == "devnot" then
                if channel.notation == "devnot" and channel.difname ~= "" then
                    ifname = bridge.getUplink()
                    ok, err = proxy.set(channel.path .. "vid", vid)
                else
                    ifname = bridge.findVlanDevice(channel.connection, vid)
                    if not ifname then
                        ifname = bridge.get(channel.path .. "name")
                        local section = channel.path:match("@([^%.]+)%.$")
                        if not bridge.get(channel.path .. "type") then
                            ok, err = proxy.add("uci.network.device.", section)
                        end
                        if not ifname or ifname == "" then
                            ifname = section
                        end
                        if ok then
                            ok, err = proxy.set({
                                [channel.path .. "type"] = channel.vlanType,
                                [channel.path .. "name"] = ifname,
                                [channel.path .. "vid"] = vid,
                                [channel.path .. "ifname"] = channel.connection,
                            })
                        end
                    end
                end
            else
                -- Release the previous named VLAN before using dot notation or
                -- the untagged parent. Do not alter an unrelated fallback device.
                if channel.notation == "devnot" and channel.difname ~= "" then
                    ok, err = proxy.set(channel.path .. "ifname", "")
                end
                if enabled then ifname = channel.connection .. "." .. vid end
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
local vlanEnabled = difname ~= "" and "1" or "0"

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
    }
	
    local vlanidclass = {
        group = {
            class = "monitor-intf_vlan monitor-1",
        },
    }
	if tech and manual then
    html[#html + 1] = ui_helper.createSwitch(T"Using VLAN", "intf_vlan", vlanEnabled, vlanswitchclass)
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
