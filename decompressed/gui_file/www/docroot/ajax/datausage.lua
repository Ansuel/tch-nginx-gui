-- Enable localization
gettext.textdomain('webui-datausage')

local json = require("dkjson")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")

local post_data = ngx.req.get_post_args()
if post_data.action == "get" and post_data.interface then
  local path = string.format("rpc.datausage.interface.@%s.", post_data.interface)
  local datausage_info = proxy.get(path)
  if datausage_info then
    local dataUsage = content_helper.convertResultToObject("rpc.datausage.interface.@.", datausage_info)
    local buffer = {}
    local ret = json.encode (dataUsage[1], { indent = false, buffer = buffer })
    if ret then
      ngx.say(buffer)
      ngx.exit(ngx.HTTP_OK)
    end
  end
elseif post_data.action == "reset" and post_data.interface then
  proxy.set(string.format("rpc.datausage.interface.@%s.reset", post_data.interface), "1")
elseif post_data.action == "overview" then
  local data = {}
  local selected_interface = proxy.get("rpc.datausage_notifier.web_selected_interface")[1].value
  data.rx_value =proxy.get(string.format("rpc.datausage.interface.@%s.rx_bytes_per_second", selected_interface))[1].value
  data.tx_value =proxy.get(string.format("rpc.datausage.interface.@%s.tx_bytes_per_second", selected_interface))[1].value
  ngx.print(data.rx_value..","..data.tx_value)
  ngx.exit(ngx.HTTP_OK)
end

ngx.say("{}")
ngx.exit(ngx.HTTP_OK)
