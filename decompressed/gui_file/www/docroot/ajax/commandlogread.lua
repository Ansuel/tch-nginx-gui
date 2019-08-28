local json = require("dkjson")
local proxy = require("datamodel")
local ngx = ngx

local data = {}

local upgradegui_path = "rpc.system.modgui.scriptRequest."
data["state"] = proxy.get(upgradegui_path.."state")[1].value

local file = io.open("/tmp/command_log","r")
if file then
	data["log"] = file:read('*a')
	file:close()
end

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end

ngx.exit(ngx.HTTP_OK)