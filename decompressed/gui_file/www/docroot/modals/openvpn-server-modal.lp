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
local function escape(value)
  local raw = string.untaint(value or "")
  if type(raw) ~= "string" then raw = tostring(raw) end
  -- Transformer values are tainted userdata. Untaint before any tostring.
  return raw:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
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

local tab = args.tab == "client" and "client" or "server"
local function tabs()
  ngx.print('<ul class="nav nav-tabs">')
  for _, item in ipairs({ { "server", T"Server" }, { "client", T"Client" } }) do
    local active = item[1] == tab and ' class="active"' or ""
    ngx.print('<li', active, '><a href="#" data-remote="modals/openvpn-server-modal.lp?tab=', item[1], '">', item[2], '</a></li>')
  end
  ngx.print('</ul>')
end

ngx.print(ui_helper.createHeader(T"OpenVPN"))
ngx.print('<div class="modal-body update">')
tabs()

if tab == "server" then
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
  ngx.print('<form class="form-horizontal" method="post" action="modals/openvpn-server-modal.lp?tab=server">')
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('<fieldset><legend>', T"General", '</legend>')
  ngx.print(ui_helper.createSwitch(T"OpenVPN server state", "enabled", content.enabled))
  ngx.print(ui_helper.createInputText(T"WAN port", "port", content.port, nil, helpmsg.port))
  ngx.print(ui_helper.createInputText(T"Protocol (udp or tcp)", "proto", content.proto, nil, helpmsg.proto))
  ngx.print(ui_helper.createInputText(T"VPN network and netmask", "server", content.server, nil, helpmsg.server))
  ngx.print(ui_helper.createSwitch(T"Allow VPN clients to access LAN", "allow_lan", content.allow_lan))
  ngx.print('<p><a class="btn" href="/modals/openvpn-server-modal.lp?download=1"><i class="icon-download-alt"></i> ', T"Download client profile", '</a></p></fieldset>')
  ngx.print('<fieldset><legend>', T"Users", '</legend>', ui_helper.createTable(user_columns, user_data, user_options, nil, user_help), '</fieldset></form>')
else
  local map_params = {
    client_enabled = "uci.openvpn.openvpn.@client.enabled",
    remote_host = "uci.openvpn.openvpn.@client.remote_host",
    remote_port = "uci.openvpn.openvpn.@client.remote_port",
    remote_proto = "uci.openvpn.openvpn.@client.remote_proto",
    client_cipher = "uci.openvpn.openvpn.@client.client_cipher",
    client_auth = "uci.openvpn.openvpn.@client.client_auth",
    client_username = "uci.openvpn.openvpn.@client.username",
    client_ca = "rpc.openvpn.client.ca",
    client_cert = "rpc.openvpn.client.cert",
    client_key = "rpc.openvpn.client.key",
    client_password = "rpc.openvpn.client.password",
  }
  local function valid_host(value)
    if value ~= "" and (not value:match("^[%w][%w.-]*$") or #value > 253) then return nil, T"Enter a valid VPN server name or IPv4 address" end
    return true
  end
  local function valid_client_port(value)
    local port = tonumber(value)
    if not port or port < 1 or port > 65535 then return nil, T"Port must be between 1 and 65535" end
    return true
  end
  local function valid_client_proto(value)
    if value ~= "udp" and value ~= "tcp" then return nil, T"Protocol must be udp or tcp" end
    return true
  end
  local function valid_client_username(value)
    if value ~= "" and (not value:match("^[%w_.@-]+$") or #value > 128) then return nil, T"Use only letters, numbers, dot, underscore, @ or dash" end
    return true
  end
  local function valid_cipher(value)
    if value ~= "AES-128-CBC" and value ~= "AES-256-CBC" and value ~= "BF-CBC" and
       value ~= "AES-128-GCM" and value ~= "AES-256-GCM" then return nil, T"Unsupported cipher" end
    return true
  end
  local function valid_auth(value)
    if value ~= "SHA1" and value ~= "SHA256" and value ~= "SHA512" then return nil, T"Unsupported digest" end
    return true
  end
  local function valid_material(value)
    if type(value) ~= "string" or #value > 32768 then return nil, T"Certificate or key is too large" end
    return true
  end
  local function valid_client_password(value)
    if type(value) ~= "string" or #value > 512 or value:find("[\r\n]") then return nil, T"Invalid client password" end
    return true
  end
  local validation = {
    client_enabled = post_helper.validateBoolean, remote_host = valid_host,
    remote_port = valid_client_port, remote_proto = valid_client_proto,
    client_cipher = valid_cipher, client_auth = valid_auth,
    client_username = valid_client_username, client_ca = valid_material,
    client_cert = valid_material, client_key = valid_material,
    client_password = valid_client_password,
  }
  local ssids = {}
  for _, item in ipairs(proxy.getPN("rpc.openvpn.client.ssid.", true) or {}) do
    local path = item.path and string.untaint(item.path)
    local key = path and path:match("^rpc%.openvpn%.client%.ssid%.@([%w_]+)%.$")
    if key then
      local base = "rpc.openvpn.client.ssid.@" .. key .. "."
      local field = "ssid_" .. key
      map_params[field] = base .. "selected"
      validation[field] = post_helper.validateBoolean
      ssids[#ssids + 1] = { field = field, ssid = getvalue(base .. "ssid"), network = getvalue(base .. "network") }
    end
  end
  local content, helpmsg = post_helper.handleQuery(map_params, validation)
  local function material_field(label, name, kind)
    local configured = getvalue("rpc.openvpn.client." .. kind .. "_present") == "1"
    local status = configured and T"Configured" or T"Missing"
    ngx.print('<div class="control-group"><label class="control-label">', label, '</label><div class="controls">')
    ngx.print('<textarea class="span4" rows="4" name="', name, '" placeholder="', escape(status), '"></textarea>')
    ngx.print('<span class="help-inline">', T"Leave blank to keep the saved value", '</span></div></div>')
  end
  ngx.print('<form class="form-horizontal" method="post" action="modals/openvpn-server-modal.lp?tab=client">')
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('<fieldset><legend>', T"Client connection", '</legend>')
  ngx.print('<p>', T"The client uses a separate tunnel. It does not change the router or main LAN default route.", '</p>')
  ngx.print(ui_helper.createSwitch(T"OpenVPN client state", "client_enabled", content.client_enabled))
  ngx.print(ui_helper.createInputText(T"VPN server", "remote_host", content.remote_host, nil, helpmsg.remote_host))
  ngx.print(ui_helper.createInputText(T"VPN port", "remote_port", content.remote_port, nil, helpmsg.remote_port))
  ngx.print(ui_helper.createInputSelect(T"Protocol", "remote_proto", { { "udp", "UDP" }, { "tcp", "TCP" } }, content.remote_proto, nil, helpmsg.remote_proto))
  ngx.print(ui_helper.createInputSelect(T"Cipher", "client_cipher", { { "AES-256-CBC", "AES-256-CBC" }, { "AES-128-CBC", "AES-128-CBC" }, { "AES-256-GCM", "AES-256-GCM" }, { "AES-128-GCM", "AES-128-GCM" }, { "BF-CBC", "BF-CBC" } }, content.client_cipher, nil, helpmsg.client_cipher))
  ngx.print(ui_helper.createInputSelect(T"Authentication digest", "client_auth", { { "SHA256", "SHA256" }, { "SHA1", "SHA1" }, { "SHA512", "SHA512" } }, content.client_auth, nil, helpmsg.client_auth))
  ngx.print(ui_helper.createInputText(T"Username (optional)", "client_username", content.client_username, nil, helpmsg.client_username))
  ngx.print('<div class="control-group"><label class="control-label">', T"Password (optional)", '</label><div class="controls">')
  ngx.print(ui_helper.createSimpleInputPassword("client_password", "", nil, helpmsg.client_password), '</div></div>')
  material_field(T"CA certificate (PEM)", "client_ca", "ca")
  material_field(T"Client certificate (PEM, optional)", "client_cert", "cert")
  material_field(T"Client private key (PEM, optional)", "client_key", "key")
  ngx.print('</fieldset><fieldset><legend>', T"Wi-Fi SSIDs over VPN", '</legend>')
  ngx.print('<p>', T"Select any isolated Wi-Fi SSID. New isolated SSIDs appear here automatically. The main LAN is never selectable. If the tunnel drops, selected SSIDs cannot reach the Internet until it reconnects.", '</p>')
  for _, item in ipairs(ssids) do
    ngx.print(ui_helper.createSwitch(escape(item.ssid) .. ' (' .. escape(item.network) .. ')', item.field, content[item.field]))
  end
  if #ssids == 0 then ngx.print('<p>', T"No isolated Wi-Fi SSIDs are configured.", '</p>') end
  ngx.print('</fieldset></form>')
end

ngx.print('</div>')
ngx.print(ui_helper.createFooter())
