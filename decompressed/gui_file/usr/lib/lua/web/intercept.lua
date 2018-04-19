local proxy = require("datamodel")
local M = {}

local function getLanIP()
  return proxy.get("uci.network.interface.@lan.ipaddr")[1].value
end

function M.process()
  local server_addr = getLanIP()
  local req_uri = ngx.var.http_host .. ngx.unescape_uri(ngx.var.request_uri)
  ngx.log(ngx.NOTICE, "Intercept: uri=" .. string.untaint(req_uri))

  ngx.header.content_type = "text/html"

  ngx.say([[<html><head></head>
  <body><center>
  <p><b>INTERCEPT TEST</b></p>
  You have been intercepted for the following destination :<br>
  <i>]], req_uri, [[</i>
  <div>
  <p><b>WAN connection is unavailable.</b><br>
  Please check internet access settings, close your browser and try again.</p>
  <div>
  <p><a href="http://]], server_addr, [[">Click here to access NG-gateway webinterface</a></p>
  </center></body>
  </html>]])

  ngx.exit(ngx.HTTP_OK)
end

return M
