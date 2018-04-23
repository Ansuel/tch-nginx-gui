local proxy = require("datamodel")
local M = {}

function M.process()
  local hostname = proxy.get("uci.dhcp.dnsmasq.1.hostname.@1.value")[1].value
  local domain = proxy.get("uci.dhcp.dnsmasq.1.domain")[1].value
  ngx.redirect("http://" .. string.untaint(hostname) .. "." .. string.untaint(domain) .. "/parental-block.lp", ngx.HTTP_MOVED_TEMPORARILY)
end

return M
