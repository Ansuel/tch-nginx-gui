<%
-- NG.... to support vlan device methode

-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")

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

	local pathifname = "uci.network.interface.@wan.ifname"
    local iface = proxy.get(pathifname)[1].value
	local connection = ""
	local path = ""
	local vid = ""
	local dname = ""
	local difname = ""
	if string.match(iface, "eth") then
	connection = "eth4"
	path = "uci.network.device.@waneth4."
		if string.match(iface, "%.") then
		difname = string.match(iface, "eth4%.[%d]+")
		vid = string.match(difname, "[^eth4%.]+")
		else
			if proxy.get(path) then
				vid = proxy.get(path.."vid")[1].value
				dname = proxy.get(path.."name")[1].value
				difname = proxy.get(path.."ifname")[1].value
			end
		end
	elseif string.match(iface, "atm") then
	connection = "atmwan"
	path = "uci.network.device.@wanatmwan."
		if string.match(iface, "%.") then
		difname = string.match(iface, "atmwan%.[%d]+")
		vid = string.match(difname, "[^atmwan%.]+")
		else
			if proxy.get(path) then
				vid = proxy.get(path.."vid")[1].value
				dname = proxy.get(path.."name")[1].value
				difname = proxy.get(path.."ifname")[1].value
			end
		end
	else
	connection = "ptm0"
	path = "uci.network.device.@wanptm0."
		if string.match(iface, "%.") then
			difname = string.match(iface, "ptm0%.[%d]+")
			vid = string.match(difname, "[^ptm0%.]+")
		else
			if proxy.get(path) then
				vid = proxy.get(path.."vid")[1].value
				dname = proxy.get(path.."name")[1].value
				difname = proxy.get(path.."ifname")[1].value
			end
		end
	
	end
	

if ngx.var.request_method == "POST" then
    local content = ngx.req.get_post_args()
	if content["action"]=="SAVE" then
	range, helpmes = getValidateNumberInRange(2, 2048, content["intf_vlanid"])
	if content["auswahlliste"] == "devnot" then
		if range and (content["intf_vlanid"]~=vid or content["intf_vlan"]~="0") then
			if proxy.get(path) then
			dname = proxy.get(path.."name")[1].value
			proxy.set(path.."vid", content["intf_vlanid"])
			proxy.set(pathifname, dname)
			ngx.print(dname)
			proxy.set(path.."ifname", connection)
			else
			proxy.add("uci.network.device.", string.format("%s%s","wan",connection ))
			proxy.set(path.."type","8021q")
			proxy.set(path.."name","wan"..connection)
			proxy.set(path.."macaddr", proxy.get("uci.env.rip.eth_mac")[1].value)
			dname = proxy.get(path.."name")[1].value
			proxy.set(path.."vid", content["intf_vlanid"])
			proxy.set(pathifname, dname)
			proxy.set(path.."ifname", connection)
			end
			proxy.apply()
		end
	elseif content["auswahlliste"] == "dotnot" then
		if range and (content["intf_vlanid"]~=vid or content["intf_vlan"]~="0") then
			if proxy.get(path) and proxy.get(path.."ifname")[1].value ~="" then
				proxy.set(path.."ifname", "")
			end				
			proxy.set(pathifname, string.format("%s.%s",connection, content["intf_vlanid"]))
			proxy.apply()
		end
	end
		if content["intf_vlan"]=="0" then
			if proxy.get(path) then
			proxy.set(path.."ifname", "")
			end
			proxy.set(pathifname, connection)
			proxy.apply()
		end
	iface = proxy.get(pathifname)[1].value
if string.match(iface, "eth") then
	connection = "eth4"
	path = "uci.network.device.@waneth4."
		if string.match(iface, "%.") then
		difname = string.match(iface, "eth4%.[%d]+")
		vid = string.match(difname, "[^eth4%.]+")
		else
			if proxy.get(path) then
				vid = proxy.get(path.."vid")[1].value
				dname = proxy.get(path.."name")[1].value
				difname = proxy.get(path.."ifname")[1].value
			end
		end
	elseif string.match(iface, "ptm") then
	connection = "ptm0"
	path = "uci.network.device.@wanptm0."
		if string.match(iface, "%.") then
			difname = string.match(iface, "ptm0%.[%d]+")
			vid = string.match(difname, "[^ptm0%.]+")
		else
			if proxy.get(path) then
				vid = proxy.get(path.."vid")[1].value
				dname = proxy.get(path.."name")[1].value
				difname = proxy.get(path.."ifname")[1].value
			end
		end
	else
	connection = "atmwan"
	path = "uci.network.device.@wanatmwan."
		if string.match(iface, "%.") then
		difname = string.match(iface, "atmwan%.[%d]+")
		vid = string.match(difname, "[^atmwan%.]+")
		else
			if proxy.get(path) then
				vid = proxy.get(path.."vid")[1].value
				dname = proxy.get(path.."name")[1].value
				difname = proxy.get(path.."ifname")[1].value
			end
		end
	end
	end
end
	local check
	if string.match(iface, "%.") then
		check = "dotnot"
	else
		check = "devnot"
	end
local b
if check == "dotnot" then
	if string.match(difname, "%.") then
		b = string.match(difname, "[%w]+")
		difname = string.match(difname, "[%w]+")
		ngx.print(b)
	else
		b="empty"
	end
else
	if string.match(difname,"[%w]+") then
		b = string.match(difname,"[%w]+")
	else 
		b="empty"
	end
end

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
%>

<fieldset>
  <%
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  %>
  <legend><%= T"Internet channel" %></legend>
  <%
	liste = {	{"devnot", "Device"},
				{"dotnot", "Dot"},
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
	if tech then
    html[#html + 1] = ui_helper.createSwitch(T"Using VLAN", "intf_vlan", difname, vlanswitchclass)
	html[#html + 1] = ui_helper.createInputRadio(T"Notation", "auswahlliste" , liste, check, vlanidclass)
    html[#html + 1] = ui_helper.createInputText(T"VLAN ID", "intf_vlanid", vid, vlanidclass, helpmes)
	else
	html[#html + 1] = ui_helper.createLight(T"Using VLAN", nil, intf_state_map[intf_state], { light = { class = intf_light_map[intf_state] } })
	html[#html + 1] = ui_helper.createLabel(T"VLAN ID", vid)
	end
    ngx.print(html)
	
  %>
</fieldset>