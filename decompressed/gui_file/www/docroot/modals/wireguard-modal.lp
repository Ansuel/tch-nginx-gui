--pretranslated: do not change this file
gettext.textdomain('webui-wireguard')

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")

local keygen_script = "/usr/share/transformer/scripts/wireguardKeygen.sh"
local client_profile = "/tmp/modgui-wireguard-client.conf"

local function plain(value)
  local raw = string.untaint(value or "")
  if type(raw) ~= "string" then raw = tostring(raw) end
  return raw
end

local function escape(value)
  local raw = plain(value)
  return raw:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

local function getvalue(path)
  local values = proxy.get(path)
  return values and values[1] and values[1].value or ""
end

local function run_keygen(argument)
  local command_line = plain(keygen_script .. " " .. argument .. " 2>/dev/null")
  local command = io.popen(command_line, "r")
  if not command then return nil end
  local output = command:read("*a") or ""
  command:close()
  return output
end

local args = ngx.req.get_uri_args()
if args.download == "1" then
  local profile_file = io.open(client_profile, "r")
  if not profile_file then
    ngx.status = ngx.HTTP_NOT_FOUND
    ngx.say(T"Generate a client key pair first.")
    return ngx.exit(ngx.HTTP_NOT_FOUND)
  end
  local profile = profile_file:read("*a") or ""
  profile_file:close()
  ngx.header.content_type = "text/plain"
  ngx.header.content_disposition = 'attachment; filename="modgui-wireguard-client.conf"'
  ngx.header.cache_control = "no-store"
  ngx.print(profile)
  return ngx.exit(ngx.HTTP_OK)
end

local post_args = ngx.req.get_method() == "POST" and ngx.req.get_post_args() or {}
local keygen_action = plain(post_args.action)
local keygen_note

local function status_snapshot()
  local result = {}
  local command = io.popen("/usr/share/transformer/scripts/wireguardStatus.sh", "r")
  if command then
    for line in command:lines() do
      local key, value = line:match("^([%w_]+)=(.*)$")
      if key then result[key] = value end
    end
    command:close()
  end
  return result
end

local map_params = {
  enabled = "uci.wireguard.wg.enabled",
  listen_port = "uci.wireguard.wg.listen_port",
  address = "uci.wireguard.wg.address",
  allow_lan = "uci.wireguard.wg.allow_lan",
  allow_wan = "uci.wireguard.wg.allow_wan",
}

local function valid_port(value)
  local port = tonumber(value)
  if value == "" or not port or port < 1 or port > 65535 or not value:match("^%d+$") then
    return nil, T"Port must be between 1 and 65535"
  end
  return true
end

local function valid_private_key(value)
  value = plain(value)
  if value == "" then return true end
  local body = value:match("^([A-Za-z0-9+/]+)=$")
  if not body or #body ~= 43 then
    return nil, T"Invalid private key: expected 44 base64 characters ending with ="
  end
  return true
end

local function valid_address(value)
  local ip, prefix = value:match("^(%d+%.%d+%.%d+%.%d+)/(%d+)$")
  if not ip or tonumber(prefix) > 32 then
    return nil, T"Use a tunnel address in CIDR notation, for example 10.66.66.1/24"
  end
  for octet in ip:gmatch("%d+") do
    if tonumber(octet) > 255 then
      return nil, T"Use a tunnel address in CIDR notation, for example 10.66.66.1/24"
    end
  end
  return true
end

-- Password inputs are deliberately rendered empty. Only map this option when
-- the user actually enters a replacement, otherwise preserve the stored key.
local submitted_private = plain(post_args.private_key)
if submitted_private == "********" then submitted_private = "" end
local validators = {
  enabled = post_helper.validateBoolean,
  listen_port = valid_port,
  address = valid_address,
  allow_lan = post_helper.validateBoolean,
  allow_wan = post_helper.validateBoolean,
}
if submitted_private ~= "" then
  map_params.private_key = "uci.wireguard.wg.private_key"
  validators.private_key = valid_private_key
end

local content, helpmsg = post_helper.handleQuery(map_params, validators)
if not content.private_key then
  content.private_key = getvalue("uci.wireguard.wg.private_key")
end

if keygen_action == "WG_KEYGEN_INTERFACE" then
  local output = run_keygen("interface export")
  local private = output and output:match("private=([A-Za-z0-9+/=]+)")
  local public = output and output:match("public=([A-Za-z0-9+/=]+)")
  if private and public then
    proxy.set({
      ["uci.wireguard.wg.private_key"] = private,
      ["uci.wireguard.wg.public_key"] = public,
    })
    proxy.apply()
    content.private_key = private
    keygen_note = T"Gateway key pair is ready. Share the public key with new peers."
  else
    keygen_note = T"Key generation failed: check that the WireGuard runtime is installed."
  end
elseif keygen_action == "WG_KEYGEN_PEER" then
  local host = plain(ngx.var.http_host)
  -- OpenResty propagates the request taint through gsub, so untaint the
  -- sanitized result before it is concatenated into the local command.
  host = plain(host:gsub(":%d+$", ""):gsub("[^A-Za-z0-9.%-]", ""))
  local server_public = getvalue("uci.wireguard.wg.public_key"):match("^([A-Za-z0-9+/]+=)$") or ""
  local port = getvalue("uci.wireguard.wg.listen_port"):gsub("[^0-9]", "")
  local address = getvalue("uci.wireguard.wg.address"):gsub("[^0-9./]", "")
  server_public = plain(server_public)
  port = plain(port)
  address = plain(address)
  local output = run_keygen("client " .. host .. " " .. server_public .. " " .. port .. " " .. address)
  local public = output and output:match("public=([A-Za-z0-9+/=]+)")
  if public then
    keygen_note = T"Client profile generated. Add this public key to a new peer: " .. public
  else
    keygen_note = T"Client profile generation failed: generate the gateway key pair first."
  end
end

local function valid_peer_name(value)
  if not value or #value > 64 or not value:match("^[%w_%-%. ]+$") then
    return nil, T"Use only letters, numbers, space, dot, underscore or dash"
  end
  return true
end

local function valid_public_key(value)
  local body = value:match("^([A-Za-z0-9+/]+)=$")
  if not body or #body ~= 43 then
    return nil, T"Invalid public key: expected 44 base64 characters ending with ="
  end
  return true
end

local function valid_optional_key(value)
  if value == "********" then return true end
  if value == "" then return true end
  return valid_public_key(value)
end

local function valid_endpoint_host(value)
  if value == "" then return true end
  if #value > 253 or not value:match("^[%w][%w%.%-]*$") then
    return nil, T"Enter a valid host name or IPv4 address"
  end
  return true
end

local function valid_optional_port(value)
  if value == "" then return true end
  return valid_port(value)
end

local function valid_allowed_ips(value)
  for item in value:gmatch("[^,%s]+") do
    local ip, prefix = item:match("^(%d+%.%d+%.%d+%.%d+)/(%d+)$")
    if not ip or tonumber(prefix) > 32 then
      return nil, T"Use comma separated IPv4 networks, for example 10.66.66.2/32"
    end
    for octet in ip:gmatch("%d+") do
      if tonumber(octet) > 255 then
        return nil, T"Use comma separated IPv4 networks, for example 10.66.66.2/32"
      end
    end
  end
  return true
end

local function valid_keepalive(value)
  if value == "" then return true end
  local seconds = tonumber(value)
  if not seconds or seconds < 0 or seconds > 320 or not value:match("^%d+$") then
    return nil, T"Keepalive must be between 0 and 320 seconds"
  end
  return true
end

local peer_columns = {
  { header = "", name = "enabled", param = "enabled", type = "switch", default = "1",
    attr = { switch = { ["data-placement"] = "right" } } },
  { header = T"Name", name = "name", param = "name", type = "text", default = "peer",
    attr = { input = { class = "span2" } } },
  { header = T"Public key", name = "public_key", param = "public_key", type = "text", default = "",
    attr = { input = { class = "span3" } } },
  { header = T"Preshared key (optional)", name = "preshared_key", param = "preshared_key", type = "password", default = "",
    attr = { input = { class = "span2" } } },
  { header = T"Endpoint host (optional)", name = "endpoint_host", param = "endpoint_host", type = "text", default = "",
    attr = { input = { class = "span2" } } },
  { header = T"Endpoint port", name = "endpoint_port", param = "endpoint_port", type = "text", default = "",
    attr = { input = { class = "span1" } } },
  { header = T"Allowed IPs", name = "allowed_ips", param = "allowed_ips", type = "text", default = "",
    attr = { input = { class = "span2" } } },
  { header = T"Keepalive", name = "persistent_keepalive", param = "persistent_keepalive", type = "text", default = "",
    attr = { input = { class = "span1" } } },
}
local peer_options = {
  tableid = "wireguard-peers",
  basepath = "uci.wireguard.peer.@.",
  createMsg = T"Add new peer",
  minEntries = 0,
  maxEntries = 16,
  sorted = "name",
}
local peer_data, peer_help = post_helper.handleTableQuery(peer_columns, peer_options, nil, nil, {
  name = valid_peer_name,
  public_key = valid_public_key,
  preshared_key = valid_optional_key,
  endpoint_host = valid_endpoint_host,
  endpoint_port = valid_optional_port,
  allowed_ips = valid_allowed_ips,
  persistent_keepalive = valid_keepalive,
})

local status = status_snapshot()
local enabled_on = content.enabled == "1"
local running = status.running == "true"
local live = tonumber(status.live) or 0
local peers = tonumber(status.peers) or 0
local state_text = T"Tunnel disabled"
if enabled_on and running and live > 0 then
  state_text = T"Peers connected"
elseif enabled_on and running then
  state_text = T"Waiting for peers"
elseif enabled_on then
  state_text = T"Interface down"
end
local public_key = getvalue("uci.wireguard.wg.public_key")

ngx.print(ui_helper.createHeader(T"WireGuard"))
ngx.print('<div class="modal-body update">')
if keygen_note then
  ngx.print('<div class="alert alert-info">', escape(keygen_note), '</div>')
end
ngx.print('<form class="form-horizontal" method="post" action="modals/wireguard-modal.lp">')
ngx.print(ui_helper.createMessages(message_helper.popMessages()))

ngx.print('<fieldset><legend>', T"Interface", '</legend>')
ngx.print('<p>', T"The gateway acts as a WireGuard endpoint. Peers connect to this gateway UDP port, or the gateway connects to peers that define an endpoint. Everything stays disabled until the interface is enabled.", '</p>')
ngx.print(ui_helper.createSwitch(T"WireGuard interface", "enabled", content.enabled))
ngx.print(ui_helper.createInputText(T"UDP listen port", "listen_port", content.listen_port, nil, helpmsg.listen_port))
ngx.print(ui_helper.createInputText(T"Tunnel address (CIDR)", "address", content.address, nil, helpmsg.address))
ngx.print(ui_helper.createInputPassword(T"Private key", "private_key", content.private_key, nil, helpmsg.private_key))
ngx.print('<span class="help-block">', T"Keep the private key secret or generate it with the button below.", '</span>')
ngx.print(ui_helper.createSwitch(T"Allow peers to reach the LAN", "allow_lan", content.allow_lan))
ngx.print(ui_helper.createSwitch(T"Allow peers to reach the Internet", "allow_wan", content.allow_wan))
if enabled_on and content.private_key == "" then
  ngx.print('<div class="alert alert-error">', T"Generate or paste a private key before enabling the interface.", '</div>')
end
ngx.print('<p>')
ngx.print('<div class="btn" data-name="action" data-value="WG_KEYGEN_INTERFACE"><i class="icon-refresh"></i> ', T"Generate gateway key pair", '</div> ')
ngx.print('<div class="btn" data-name="action" data-value="WG_KEYGEN_PEER"><i class="icon-plus"></i> ', T"Generate client profile", '</div>')
ngx.print('</p>')
if public_key ~= "" then
  ngx.print('<p><strong>', T"Gateway public key", ':</strong> <code>', escape(public_key), '</code></p>')
else
  ngx.print('<p><strong>', T"Gateway public key", ':</strong> ', T"Not generated yet", '</p>')
end
ngx.print('</fieldset>')

ngx.print('<fieldset><legend>', T"Status", '</legend>')
ngx.print('<p><strong>', T"Status", ':</strong> ', state_text, '</p>')
if status.ip and status.ip ~= "" then
  ngx.print('<p><strong>', T"Tunnel address", ':</strong> ', escape(status.ip), '</p>')
end
ngx.print('<p><strong>', T"Active peers", ':</strong> ', tostring(live), ' / ', tostring(peers), '</p>')
if status.message and status.message ~= "" and not enabled_on then
  ngx.print('<p class="muted">', escape(status.message), '</p>')
end
ngx.print('</fieldset>')

ngx.print('<fieldset><legend>', T"Peers", '</legend>')
ngx.print('<p>', T"Add one peer per device or remote gateway. Leave the endpoint empty for devices connecting in; fill it to connect out to a remote server. Allowed IPs are comma separated; use 0.0.0.0/0 on a remote server peer to route all traffic through it.", '</p>')
ngx.print(ui_helper.createTable(peer_columns, peer_data, peer_options, nil, peer_help))
ngx.print('</fieldset></form>')

local profile_file = io.open(client_profile, "r")
if profile_file then
  local profile = profile_file:read("*a") or ""
  profile_file:close()
  ngx.print('<fieldset><legend>', T"Sample client profile", '</legend>')
  ngx.print('<p>', T"Generated with the last client key pair. Copy it to the WireGuard client app and add its public key to a peer above.", '</p>')
  ngx.print('<textarea class="span6" rows="10" readonly>', escape(profile), '</textarea>')
  ngx.print('<p><a class="btn" href="/modals/wireguard-modal.lp?download=1"><i class="icon-download-alt"></i> ', T"Download client profile", '</a></p>')
  ngx.print('</fieldset>')
end

ngx.print('</div>')
ngx.print(ui_helper.createFooter())
