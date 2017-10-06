-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local proxy = require("datamodel")
local utils = require("web.lte-utils")
local content_helper = require("web.content_helper")

local post_data = ngx.req.get_post_args()
local data = {}

if post_data["id"] ~= nil and post_data["id"] ~= ""  and post_data["action"] ~= nil and post_data["action"] ~= "" then
    local action = post_data["action"]
    if action == 'read' then
        proxy.set("rpc.mobiled.device.@1.sms.markread", post_data["id"])
    elseif action == 'unread' then
        proxy.set("rpc.mobiled.device.@1.sms.markunread", post_data["id"])
    elseif action == 'delete' then
        proxy.set("rpc.mobiled.device.@1.sms.delete", post_data["id"])
    end
end

if post_data["storageinfo"] == '1' then
    data = utils.getContent("rpc.mobiled.device.@1.sms.info.")
else
    local ucipath = "rpc.mobiled.device.@1.sms.message."
    local results = proxy.get(ucipath)
    if results ~= nil and results ~= "" then
        data = content_helper.convertResultToObject(ucipath, results)
    end
end

local buffer = {}
local success = json.encode (data, { indent = false, buffer = buffer })
if success then
    utils.sendResponse(buffer)
end
utils.sendResponse("[]")
