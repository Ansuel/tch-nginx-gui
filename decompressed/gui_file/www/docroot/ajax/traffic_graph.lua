-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local content_helper = require("web.content_helper")
local ngx = ngx

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local string, ngx, os = string, ngx, os
local tonumber = tonumber
local format, match = string.format, string.match

local old_rx_value
local old_tx_value
local interface

if ngx.req.get_method() == "POST" then
  old_rx_value = ngx.req.get_uri_args().oldrx or "1000"
  old_tx_value = ngx.req.get_uri_args().oldtx or "1000"
  interface = ngx.req.get_uri_args().interface
end

local int_rx = format("/sys/class/net/%s/statistics/rx_bytes",interface or "ptm0")
local int_tx = format("/sys/class/net/%s/statistics/tx_bytes",interface or "ptm0")

local file = io.open(int_rx,"r")
local rx_traffic = file:read()
file:close()

local file = io.open(int_tx,"r")
local tx_traffic = file:read()
file:close()

local data = {
	old_rx_traffic = old_rx_value,
	old_tx_traffic = old_tx_value,
	rx_traffic = rx_traffic,
	tx_traffic = tx_traffic
}

local buffer = {}
if not interface then
	ngx.say("Invalid interface in args")
elseif json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)