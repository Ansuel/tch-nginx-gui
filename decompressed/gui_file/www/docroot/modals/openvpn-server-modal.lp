--pretranslated: do not change this file
gettext.textdomain('webui-openvpn-server')
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")

local function getvalue(path)
  local values = proxy.get(path)
  return values and values[1] and values[1].value or ""
end
local args = ngx.req.get_uri_args()
if args.download == "1" then
  local ca = getvalue("rpc.openvpn.server.client.ca")
  local cert = getvalue("rpc.openvpn.server.client.cert")
  local key = getvalue("rpc.openvpn.server.client.key")
  if ca == "" or cert == "" or key == "" then
    ngx.status = ngx.HTTP_NOT_FOUND
    ngx.say(T"Client keys are not available. Start the server once to generate them.")
    return ngx.exit(ngx.HTTP_NOT_FOUND)
  end
  local host = (ngx.var.http_host or "vpn.example.com"):gsub(":%d+$", "")
  local proto = getvalue("uci.openvpn.openvpn.@server.proto")
  local port = getvalue("uci.openvpn.openvpn.@server.port")
  ngx.header.content_type = "application/x-openvpn-profile"
  ngx.header.content_disposition = 'attachment; filename="modgui-openvpn-client.ovpn"'
  ngx.print("client\ndev tun\nproto ", proto, "\nremote ", host, " ", port, "\nresolv-retry infinite\nnobind\npersist-key\npersist-tun\nremote-cert-tls server\nauth-user-pass\ncipher AES-256-CBC\nauth SHA256\nverb 3\n<ca>\n", ca, "\n</ca>\n<cert>\n", cert, "\n</cert>\n<key>\n", key, "\n</key>\n")
  return ngx.exit(ngx.HTTP_OK)
end

local user_columns = {
  { header = T"Username", name = "username", param = "username", type = "text", default = "vpn_user", attr = { input = { class = "span2" } } },
  { header = T"Password", name = "password", param = "password", type = "password", default = "", attr = { input = { class = "span2" } } },
}
local user_options = { tableid = "openvpn-users", basepath = "rpc.openvpn.server.user.", createMsg = T"Add new user", minEntries = 0, maxEntries = 32, sorted = "username" }
local function valid_username(value)
  if not value or not value:match("^[%w_.@-]+$") then return nil, T"Use only letters, numbers, dot, underscore, @ or dash" end
  return true
end
local function valid_password(value)
  if not value or #value < 8 or value:find("%s") then return nil, T"Password must contain at least 8 characters and no spaces" end
  return true
end
local user_data, user_help = post_helper.handleTableQuery(user_columns, user_options, nil, nil, { username = valid_username, password = valid_password })

local map_params = {
  enabled = "uci.openvpn.openvpn.@server.enabled",
  port = "uci.openvpn.openvpn.@server.port",
  proto = "uci.openvpn.openvpn.@server.proto",
  server = "uci.openvpn.openvpn.@server.server",
  allow_lan = "uci.openvpn.openvpn.@server.allow_lan",
}
local function valid_port(value)
  local port = tonumber(value)
  if not port or port < 1 or port > 65535 then return nil, T"Port must be between 1 and 65535" end
  return true
end
local function valid_proto(value)
  if value ~= "udp" and value ~= "tcp" then return nil, T"Protocol must be udp or tcp" end
  return true
end
local function valid_server(value)
  if not value or not value:match("^%d+%.%d+%.%d+%.%d+%s+%d+%.%d+%.%d+%.%d+$") then return nil, T"Use network and netmask, for example 10.8.0.0 255.255.255.0" end
  return true
end
local content, helpmsg = post_helper.handleQuery(map_params, { enabled = post_helper.validateBoolean, port = valid_port, proto = valid_proto, server = valid_server, allow_lan = post_helper.validateBoolean })

ngx.print(ui_helper.createHeader(T"OpenVPN Server"))
ngx.print('<div class="modal-body update"><form class="form-horizontal" method="post" action="modals/openvpn-server-modal.lp">')
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
ngx.print('<fieldset><legend>', T"General", '</legend>')
ngx.print(ui_helper.createSwitch(T"OpenVPN server state", "enabled", content.enabled))
ngx.print(ui_helper.createInputText(T"WAN port", "port", content.port, nil, helpmsg.port))
ngx.print(ui_helper.createInputText(T"Protocol (udp or tcp)", "proto", content.proto, nil, helpmsg.proto))
ngx.print(ui_helper.createInputText(T"VPN network and netmask", "server", content.server, nil, helpmsg.server))
ngx.print(ui_helper.createSwitch(T"Allow VPN clients to access LAN", "allow_lan", content.allow_lan))
ngx.print('<p><a class="btn" href="/modals/openvpn-server-modal.lp?download=1"><i class="icon-download-alt"></i> ', T"Download client profile", '</a></p></fieldset>')
ngx.print('<fieldset><legend>', T"Users", '</legend>', ui_helper.createTable(user_columns, user_data, user_options, nil, user_help), '</fieldset></form></div>')
ngx.print(ui_helper.createFooter())
