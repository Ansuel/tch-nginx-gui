local json = require("dkjson")
local proxy = require("datamodel")
local ngx = ngx

local data = {}

local upgradegui_path = "rpc.system.modgui.executeCommand."
data["state"] = proxy.get(upgradegui_path.."state")[1].value

local action = { 
	Checking = function()
		local data = {}
		local new_ver = proxy.get("uci.modgui.gui.new_ver")
		
		if new_ver and not ( new_ver[1].value == "" ) then
			data["new_version_text"] = new_ver[1].value
		end
		
		return data
	end,
}

if action[string.untaint(data.state)] then 
	for key, val in pairs(action[string.untaint(data.state)]()) do
		data[key] = val
	end
else
	local file = io.open("/tmp/command_log","r")
	if file then
		data["log"] = file:read('*a')
		file:close()
	end
end

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end

ngx.exit(ngx.HTTP_OK)