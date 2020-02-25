-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local proxy = require("datamodel")
local utils = require("web.lte-utils")
local content_helper = require("web.content_helper")

local post_data = ngx.req.get_post_args()

if post_data["id"] ~= nil and post_data["id"] ~= ""  and post_data["action"] ~= nil and post_data["action"] ~= "" then
	local action = post_data["action"]
	if action == 'read' then
		proxy.set("rpc.mobiled.sms.markread", post_data["id"])
	elseif action == 'unread' then
		proxy.set("rpc.mobiled.sms.markunread", post_data["id"])
	elseif action == 'delete' then
		proxy.set("rpc.mobiled.sms.delete", post_data["id"])
	end
end

local response = {
	info = utils.getContent("rpc.mobiled.sms.info.")
}

local path = "rpc.mobiled.sms.message."
local results = proxy.get(path)
response.messages = content_helper.convertResultToObject(path, results)

local buffer = {}
local success = json.encode (response, { indent = false, buffer = buffer })
if success then
	utils.sendResponse(buffer)
end
utils.sendResponse("{}")
