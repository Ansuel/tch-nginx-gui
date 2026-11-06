-- Enable localization
gettext.textdomain('webui-datausage')

local json = require("dkjson")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")

local post_data = ngx.req.get_post_args()
-- HTTP arguments are tainted userdata on the firmware's Lua VM.
local action = string.untaint(post_data.action)
local interface = string.untaint(post_data.interface)
local valid_interface = type(interface) == "string" and interface:match("^[%w_.%-]+$")
ngx.header.content_type = action == "overview" and "text/plain" or "application/json"
ngx.header["Cache-Control"] = "no-store"
local function value(path)
  local ok, result = pcall(proxy.get, path)
  return ok and type(result) == "table" and result[1] and string.untaint(result[1].value) or nil
end

if action == "get" and valid_interface then
  local path = string.format("rpc.datausage.interface.@%s.", interface)
  local ok, datausage_info = pcall(proxy.get, path)
  if ok and type(datausage_info) == "table" and #datausage_info > 0 then
    local dataUsage = content_helper.convertResultToObject("rpc.datausage.interface.@.", datausage_info)
    local buffer = {}
    local ret = json.encode (dataUsage and dataUsage[1] or {}, { indent = false, buffer = buffer })
    if ret then
      ngx.say(buffer)
      ngx.exit(ngx.HTTP_OK)
    end
  end
elseif action == "reset" and valid_interface then
  proxy.set(string.format("rpc.datausage.interface.@%s.reset", interface), "1")
elseif action == "overview" then
  local selected_interface = value("rpc.datausage_notifier.web_selected_interface")
  local rx, tx = "0", "0"
  if selected_interface and selected_interface:match("^[%w_.%-]+$") then
    rx = value(string.format("rpc.datausage.interface.@%s.rx_bytes_per_second", selected_interface)) or rx
    tx = value(string.format("rpc.datausage.interface.@%s.tx_bytes_per_second", selected_interface)) or tx
  end
  ngx.print(rx .. "," .. tx)
  ngx.exit(ngx.HTTP_OK)
end

ngx.say("{}")
ngx.exit(ngx.HTTP_OK)
