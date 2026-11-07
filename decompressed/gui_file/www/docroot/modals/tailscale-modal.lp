--pretranslated: do not change this file
gettext.textdomain('webui-tailscale')

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")

local function escape(value)
  local raw = string.untaint(value or "")
  if type(raw) ~= "string" then raw = tostring(raw) end
  return raw:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

local function status_snapshot()
  local result = {}
  local command = io.popen("/usr/share/transformer/scripts/tailscaleStatus.sh", "r")
  if command then
    for line in command:lines() do
      local key, value = line:match("^([%w_]+)=(.*)$")
      if key then result[key] = value end
    end
    command:close()
  end
  return result
end

local function valid_hostname(value)
  if not value or #value > 63 or not value:match("^[%w][%w.-]*$") then
    return nil, T"Use a valid device name containing letters, numbers, dots or dashes"
  end
  return true
end

local validate_subnet = post_helper.validateIPAndSubnet(4)
local function valid_optional_subnet(value)
  if value == "" then return true end
  return validate_subnet(value)
end

local function valid_funnel_port(value, data, key)
  local enabled = data.funnel_enabled
  if key == "funnel_ssh_port" then enabled = data.funnel_ssh_enabled end
  if (value == nil or value == "") and enabled ~= "1" then return true end
  if key == "funnel_ssh_port" and enabled == "1" and data.funnel_enabled == "1" and value == data.funnel_port then
    return nil, T"HTTP and SSH Funnel must use different public ports"
  end
  if value == "443" or value == "8443" or value == "10000" then return true end
  return nil, T"Funnel supports HTTPS ports 443, 8443 or 10000"
end

local function valid_optional_port(value, data, key)
  local enabled = data.funnel_enabled
  if key == "funnel_ssh_target_port" then enabled = data.funnel_ssh_enabled end
  if (value == nil or value == "") and enabled ~= "1" then return true end
  return post_helper.validateStringIsPort(value, data, key)
end

local function valid_optional_ip(value)
  if value == nil or value == "" then return true end
  return post_helper.validateStringIsIP(value)
end

local function valid_optional_boolean(value)
  if value == nil or value == "" then return true end
  return post_helper.validateBoolean(value)
end

local map_params = {
  enabled = "uci.tailscale.service.enabled",
  connect = "uci.tailscale.service.connect",
  port = "uci.tailscale.service.port",
  hostname = "uci.tailscale.service.hostname",
  advertise_routes = "uci.tailscale.service.advertise_routes",
  advertise_exit_node = "uci.tailscale.service.advertise_exit_node",
  accept_routes = "uci.tailscale.service.accept_routes",
  accept_dns = "uci.tailscale.service.accept_dns",
  ssh = "uci.tailscale.service.ssh",
  funnel_enabled = "uci.tailscale.service.funnel_enabled",
  funnel_port = "uci.tailscale.service.funnel_port",
  funnel_target_port = "uci.tailscale.service.funnel_target_port",
  funnel_target_ip = "uci.tailscale.service.funnel_target_ip",
  funnel_ssh_enabled = "uci.tailscale.service.funnel_ssh_enabled",
  funnel_ssh_port = "uci.tailscale.service.funnel_ssh_port",
  funnel_ssh_target_ip = "uci.tailscale.service.funnel_ssh_target_ip",
  funnel_ssh_target_port = "uci.tailscale.service.funnel_ssh_target_port",
  funnel_ssh_password_auth = "uci.tailscale.service.funnel_ssh_password_auth",
}
local validation = {
  enabled = post_helper.validateBoolean,
  connect = post_helper.validateBoolean,
  port = post_helper.validateStringIsPort,
  hostname = valid_hostname,
  advertise_routes = valid_optional_subnet,
  advertise_exit_node = post_helper.validateBoolean,
  accept_routes = post_helper.validateBoolean,
  accept_dns = valid_optional_boolean,
  ssh = post_helper.validateBoolean,
  funnel_enabled = valid_optional_boolean,
  funnel_port = valid_funnel_port,
  funnel_target_port = valid_optional_port,
  funnel_target_ip = valid_optional_ip,
  funnel_ssh_enabled = valid_optional_boolean,
  funnel_ssh_port = valid_funnel_port,
  funnel_ssh_target_ip = valid_optional_ip,
  funnel_ssh_target_port = valid_optional_port,
  funnel_ssh_password_auth = valid_optional_boolean,
}
local content, helpmsg = post_helper.handleQuery(map_params, validation)
local status = status_snapshot()
local online = status.online == "true"
local state_text = T"Disconnected"
if status.phase == "authorization_required" then
  state_text = T"Authorization required"
elseif status.phase == "downloading" then
  state_text = T"Downloading runtime"
elseif status.phase == "verifying" or status.phase == "extracting" or
    status.phase == "starting" or status.phase == "waiting" or status.phase == "connecting" then
  state_text = T"Preparing Tailscale"
elseif status.phase == "error" then
  state_text = T"Tailscale error"
elseif online then
  state_text = T"Connected"
end

local advanced = { group = { class = "advanced hide" } }
local monitor_switch = { input = { class = "monitor-changes" } }

ngx.print(ui_helper.createHeader(T"Tailscale", true, true))
ngx.print('<div class="modal-body update"><form class="form-horizontal" method="post" action="modals/tailscale-modal.lp">')
ngx.print(ui_helper.createMessages(message_helper.popMessages()))

if not online and status.auth_url and status.auth_url:match("^https://login%.tailscale%.com/[%w%p]+$") then
  ngx.print('<div class="alert alert-info"><strong>', T"Authorization required", '</strong><br/>')
  ngx.print(T"Open this Tailscale link to authorize the gateway, then reopen this window to verify the connection.", '<br/>')
  ngx.print('<a class="btn" target="_blank" rel="noopener noreferrer" href="', escape(status.auth_url), '"><i class="icon-external-link"></i> ', T"Authorize gateway", '</a></div>')
end

ngx.print('<fieldset><legend>', T"Connection", '</legend>')
ngx.print('<ul class="inline"><li><strong>', T"Status", ':</strong> ', state_text, '</li>')
if status.ip and status.ip ~= "" then ngx.print('<li><strong>', T"Tailscale IP", ':</strong> ', escape(status.ip), '</li>') end
if status.version and status.version ~= "" then ngx.print('<li><strong>', T"Version", ':</strong> ', escape(status.version), '</li>') end
ngx.print('</ul>')
if status.phase == "error" and status.message and status.message ~= "" then
  ngx.print('<p class="alert alert-error">', escape(status.message), '</p>')
end
if status.dns and status.dns ~= "" then ngx.print('<p class="advanced hide"><strong>', T"Tailnet name", ':</strong> ', escape(status.dns), '</p>') end
ngx.print('<p class="advanced hide">', T"The service starts disabled. Enabling Connect for the first time generates an authorization link without storing account credentials in the gateway GUI.", '</p>')
ngx.print(ui_helper.createSwitch(T"Tailscale service", "enabled", content.enabled))
ngx.print(ui_helper.createSwitch(T"Connect to tailnet", "connect", content.connect))
ngx.print(ui_helper.createSwitch(T"Use Tailscale DNS", "accept_dns", content.accept_dns))
ngx.print('<p class="advanced hide">', T"Disabled by default: keep the gateway DNS settings. Enable this to use the tailnet DNS configuration and MagicDNS.", '</p>')
ngx.print(ui_helper.createInputText(T"Device name", "hostname", content.hostname, nil, helpmsg.hostname))
ngx.print(ui_helper.createInputText(T"UDP listen port", "port", content.port, advanced, helpmsg.port))
ngx.print('</fieldset>')

ngx.print('<fieldset class="advanced hide"><legend>', T"Routing", '</legend>')
ngx.print('<p>', T"Route and exit-node advertisements must also be approved in the Tailscale admin console. Leave the subnet empty to expose only the gateway itself.", '</p>')
ngx.print(ui_helper.createInputText(T"Advertised LAN subnet (optional)", "advertise_routes", content.advertise_routes, nil, helpmsg.advertise_routes))
ngx.print(ui_helper.createSwitch(T"Advertise as exit node", "advertise_exit_node", content.advertise_exit_node))
ngx.print(ui_helper.createSwitch(T"Accept routes from tailnet", "accept_routes", content.accept_routes))
ngx.print('</fieldset>')

ngx.print('<fieldset class="advanced hide"><legend>', T"Remote access", '</legend>')
ngx.print('<p>', T"Tailscale SSH permits shell access according to your tailnet ACLs. Enable it only when those policies are configured.", '</p>')
ngx.print(ui_helper.createSwitch(T"Tailscale SSH", "ssh", content.ssh))
ngx.print('</fieldset>')

ngx.print('<fieldset><legend>', T"Funnel", '</legend>')
ngx.print('<p class="alert alert-info">', T"Funnel publishes the selected service on the Internet.", '</p>')
ngx.print('<p class="advanced hide">', T"Funnel makes the selected local HTTP service public on the Internet. Enable it only for a service you intend to publish. Tailscale HTTPS and Funnel permissions must be enabled for this device.", '</p>')
ngx.print(ui_helper.createSwitch(T"Enable Funnel", "funnel_enabled", content.funnel_enabled, monitor_switch))
ngx.print('<div class="monitor-funnel_enabled monitor-1"', content.funnel_enabled ~= "1" and ' style="display:none"' or '', '>')
ngx.print(ui_helper.createInputSelect(T"Public HTTPS port", "funnel_port", { { "443", "443" }, { "8443", "8443" }, { "10000", "10000" } }, content.funnel_port ~= "" and content.funnel_port or "443", nil, helpmsg.funnel_port))
ngx.print(ui_helper.createInputText(T"HTTP destination IP", "funnel_target_ip", content.funnel_target_ip and content.funnel_target_ip ~= "" and content.funnel_target_ip or "127.0.0.1", nil, helpmsg.funnel_target_ip))
ngx.print(ui_helper.createInputText(T"HTTP destination port", "funnel_target_port", content.funnel_target_port ~= "" and content.funnel_target_port or "8080", nil, helpmsg.funnel_target_port))
ngx.print('<p class="advanced hide">', T"Choose an IPv4 or IPv6 address reachable from the gateway. Funnel terminates public TLS and forwards HTTP to this destination. The service and tailnet connection must be enabled. Reopen this window after approving Funnel.", '</p>')
ngx.print('</div>')
local funnel_text = T"Funnel disabled"
if status.funnel_state == "active" then funnel_text = T"Funnel active"
elseif status.funnel_state == "authorization_required" then funnel_text = T"Authorization required"
elseif status.funnel_state == "error" then funnel_text = T"Funnel error"
elseif status.funnel_state == "waiting" or status.funnel_state == "configuring" then funnel_text = T"Preparing Funnel" end
ngx.print('<ul class="inline"><li><strong>', T"Status", ':</strong> ', funnel_text, '</li>')
if status.funnel_state == "active" and status.funnel_url and status.funnel_url:match('^https://[%w.-]+%.ts%.net[:%d]*/?$') then
  ngx.print('<li><strong>', T"Public URL", ':</strong> <a target="_blank" rel="noopener noreferrer" href="', escape(status.funnel_url), '">', escape(status.funnel_url), '</a></li>')
end
ngx.print('</ul>')
if status.funnel_state == "error" and status.funnel_message then
  ngx.print('<p class="alert alert-error">', escape(status.funnel_message), '</p>')
end
if status.funnel_approval_url and status.funnel_approval_url:match('^https://login%.tailscale%.com/[%w%p]+$') then
  ngx.print('<p><a class="btn" target="_blank" rel="noopener noreferrer" href="', escape(status.funnel_approval_url), '">', T"Authorize Funnel", '</a></p>')
end
ngx.print('</fieldset>')

ngx.print('<fieldset><legend>', T"SSH through Funnel", '</legend>')
ngx.print(ui_helper.createSwitch(T"Enable SSH Funnel", "funnel_ssh_enabled", content.funnel_ssh_enabled, monitor_switch))
ngx.print('<div class="monitor-funnel_ssh_enabled monitor-1"', content.funnel_ssh_enabled ~= "1" and ' style="display:none"' or '', '>')
ngx.print('<p class="help-block">', T"SSH through Funnel requires a TLS client, even on port 10000.", '</p>')
ngx.print('<p class="advanced hide">', T"Public Funnel requires TLS even on port 10000: SSH clients need a TLS wrapper such as OpenSSL 3. Choose the SSH server IP and port; that server controls authentication.", '</p>')
ngx.print(ui_helper.createInputSelect(T"SSH public TLS port", "funnel_ssh_port", { { "10000", "10000" }, { "8443", "8443" }, { "443", "443" } }, content.funnel_ssh_port and content.funnel_ssh_port ~= "" and content.funnel_ssh_port or "10000", nil, helpmsg.funnel_ssh_port))
ngx.print(ui_helper.createInputText(T"SSH destination IP", "funnel_ssh_target_ip", content.funnel_ssh_target_ip and content.funnel_ssh_target_ip ~= "" and content.funnel_ssh_target_ip or "127.0.0.1", nil, helpmsg.funnel_ssh_target_ip))
ngx.print(ui_helper.createInputText(T"SSH destination port", "funnel_ssh_target_port", content.funnel_ssh_target_port and content.funnel_ssh_target_port ~= "" and content.funnel_ssh_target_port or "22", nil, helpmsg.funnel_ssh_target_port))
ngx.print(ui_helper.createSwitch(T"Allow SSH password login", "funnel_ssh_password_auth", content.funnel_ssh_password_auth))
ngx.print('<p class="advanced hide">', T"For the built-in SSH listener on 127.0.0.1 ports 22 or 2222, enable this to use existing gateway usernames and passwords. Disabled means SSH keys only. Other destinations use their own server settings. Use a strong password for public access.", '</p>')
ngx.print('</div>')
local ssh_text = T"Funnel disabled"
if status.funnel_ssh_state == "active" then ssh_text = T"Funnel active"
elseif status.funnel_ssh_state == "authorization_required" then ssh_text = T"Authorization required"
elseif status.funnel_ssh_state == "error" then ssh_text = T"Funnel error"
elseif status.funnel_ssh_state == "waiting" or status.funnel_ssh_state == "configuring" then ssh_text = T"Preparing Funnel" end
ngx.print('<p><strong>', T"Status", ':</strong> ', ssh_text, '</p>')
if status.funnel_ssh_state == "error" and status.funnel_ssh_message then
  ngx.print('<p class="alert alert-error">', escape(status.funnel_ssh_message), '</p>')
end
if status.funnel_ssh_state == "active" and status.funnel_ssh_url then
  local host, port = status.funnel_ssh_url:match('^([%w.-]+%.ts%.net):(%d+)$')
  if host and port then
    local command = table.concat({
      "ssh \\",
      "  -o PubkeyAcceptedAlgorithms=+ssh-rsa \\",
      "  -o 'ProxyCommand=openssl s_client -quiet -verify_return_error -verify_hostname %h -connect %h:" .. port .. " -servername %h' \\",
      "  root@" .. host,
    }, "\n")
    ngx.print('<p><strong>', T"SSH command", ':</strong></p><pre class="tailscale-ssh-command" style="white-space:pre-wrap;word-wrap:break-word;overflow-wrap:anywhere;word-break:break-word;max-width:100%;box-sizing:border-box">', escape(command), '</pre>')
  end
end
if status.funnel_ssh_approval_url and status.funnel_ssh_approval_url:match('^https://login%.tailscale%.com/[%w%p]+$') then
  ngx.print('<p><a class="btn" target="_blank" rel="noopener noreferrer" href="', escape(status.funnel_ssh_approval_url), '">', T"Authorize Funnel", '</a></p>')
end
ngx.print('</fieldset></form></div>')
ngx.print(ui_helper.createFooter())
