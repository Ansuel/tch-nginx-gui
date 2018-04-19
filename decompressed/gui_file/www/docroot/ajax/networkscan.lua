-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local proxy = require("datamodel")
local utils = require("web.lte-utils")
local content_helper = require("web.content_helper")

local post_data = ngx.req.get_post_args()
local data = {}

if post_data["action"] == "scan" then
    proxy.set("rpc.mobiled.device.@1.network.scan.start", "true")
    proxy.apply()
elseif post_data["action"] == "selectplmn" then
    local uci_device_path = utils.get_uci_device_path()
    proxy.set(uci_device_path .. "mcc", post_data["mcc"])
    proxy.set(uci_device_path .. "mnc", post_data["mnc"])   
    proxy.set(uci_device_path .. "network_selection", "manual" ) 
    proxy.apply()
elseif post_data["action"] == "getcurrentplmn" then
    local uci_device_path = utils.get_uci_device_path()
    local mcc = utils.getContent(uci_device_path .. "mcc")
    local mnc = utils.getContent(uci_device_path .. "mnc")
    data = {
        mcc = mcc['mcc'],
        mnc = mnc['mnc']
    }
elseif post_data["action"] == "getscanresults" then
    local path = "rpc.mobiled.device.@1.network.scanresults."
    local results = proxy.get(path)
    if results then
        data = content_helper.convertResultToObject(path, results)
    end
else
    data = utils.getContent("rpc.mobiled.device.@1.network.scan.")
end

local buffer = {}
local success = json.encode (data, { indent = false, buffer = buffer })
if success then
    utils.sendResponse(buffer)
end
utils.sendResponse("[]")
