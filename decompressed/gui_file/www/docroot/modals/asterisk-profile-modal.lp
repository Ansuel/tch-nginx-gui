--pretranslated: do not change this file

gettext.textdomain('webui-voice')

local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local html_escape = require("web.web").html_escape

local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

local function escape_html(value)
  return html_escape(value or "")
end

local timeout_available = os.execute("command -v timeout >/dev/null 2>&1") == 0

local function command_output(command)
  if not timeout_available then
    return T"Asterisk status is unavailable: the timeout utility is missing."
  end
  local process = io.popen("timeout 3 " .. command .. " 2>&1", "r")
  if not process then
    return T"Unable to run the Asterisk command."
  end
  local output = process:read(8192) or ""
  process:close()
  if output == "" then
    return T"No output."
  end
  return output
end

local asterisk_available = file_exists("/etc/init.d/asterisk")
local configurator_available = file_exists("/etc/init.d/pbx-asterisk")

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end

ngx.print(ui_helper.createHeader(T"Asterisk", false, true))
ngx.print('<div class="modal-body update">')

if not asterisk_available or not configurator_available then
  local unavailable_box = { alert = { class = "alert alert-error" } }
  ngx.print(ui_helper.createAlertBlock(
    T"Asterisk and the PBX configurator must both be installed before this page can be used.",
    unavailable_box
  ))
  ngx.print('</div>')
  ngx.print(ui_helper.createFooter())
  return
end

local yes_no = {
  { "yes", T"Yes" },
  { "no", T"No" },
}

local map_params = {
  useragent = "uci.pbx-advanced.advanced.useragent",
  ringtime = "uci.pbx-advanced.advanced.ringtime",
  externhost = "uci.pbx-advanced.advanced.externhost",
  bindport = "uci.pbx-advanced.advanced.bindport",
  rtpstart = "uci.pbx-advanced.advanced.rtpstart",
  rtpend = "uci.pbx-advanced.advanced.rtpend",
}

local host_validation = post_helper.getOrValidation(
  post_helper.validateStringIsDomainName,
  post_helper.validateStringIsIP
)
local optional_host = post_helper.getOptionalValidation(host_validation)

local map_valid = {
  useragent = post_helper.getValidateStringLengthInRange(1, 64),
  ringtime = post_helper.getValidateNumberInRange(1, 300),
  externhost = optional_host,
  bindport = post_helper.getOptionalValidation(post_helper.validateStringIsPort),
  rtpstart = post_helper.validateStringIsPort,
  rtpend = post_helper.validateStringIsPort,
}

local content, helpmsg = post_helper.handleQuery(map_params, map_valid)

local post_args = {}
if ngx.var.request_method == "POST" then
  post_args = ngx.req.get_post_args()
end

local function post_string(key)
  local value = post_args[key]
  if type(value) == "string" or string.istainted(value) then
    return string.untaint(value)
  end
  return nil
end

local function provider_name(defaultuser, host)
  return (defaultuser .. "_" .. host):gsub("[^%w_]", "_"):sub(1, 63)
end

local function table_add_name(tableid)
  if post_args.action ~= "TABLE-ADD" or post_args.tableid ~= tableid then
    return nil
  end
  local defaultuser = post_string("defaultuser")
  if not defaultuser or defaultuser == "" then
    return nil
  end
  if tableid == "asterisk_local_users" then
    return defaultuser
  end
  local host = post_string("host")
  if host and host ~= "" then
    return provider_name(defaultuser, host)
  end
  return nil
end

local function validate_uci_name(value)
  if type(value) ~= "string" and not string.istainted(value) then
    return nil, T"Received a non string value."
  end
  local valid, message = post_helper.validateNonEmptyString(value)
  if not valid then
    return valid, message
  end
  return post_helper.validateUciName(value)
end

local user_columns = {
  {
    header = T"Full Name",
    name = "fullname",
    param = "fullname",
    type = "text",
    attr = { input = { class = "span2", maxlength = "64" } },
  },
  {
    header = T"Extension",
    name = "defaultuser",
    param = "defaultuser",
    type = "text",
    unique = true,
    attr = { input = { class = "span2", maxlength = "32" } },
  },
  {
    header = T"Password",
    name = "secret",
    param = "secret",
    type = "password",
    attr = { input = { class = "span2", maxlength = "128" } },
  },
  {
    header = T"Receives Incoming Calls",
    name = "ring",
    param = "ring",
    type = "select",
    values = yes_no,
    default = "yes",
    attr = { select = { class = "span2" } },
  },
  {
    header = T"Makes Outgoing Calls",
    name = "can_call",
    param = "can_call",
    type = "select",
    values = yes_no,
    default = "yes",
    attr = { select = { class = "span2" } },
  },
}

local user_options = {
  tableid = "asterisk_local_users",
  basepath = "uci.pbx-users.local_user.@.",
  createMsg = T"Add SIP User",
  canApply = true,
  addNamedObject = true,
  objectName = table_add_name("asterisk_local_users"),
}

local user_valid = {
  fullname = post_helper.getOptionalValidation(post_helper.getValidateStringLengthInRange(1, 64)),
  defaultuser = validate_uci_name,
  secret = post_helper.getValidationPassword(post_helper.validateNonEmptyString),
  ring = post_helper.getValidateInEnumSelect(yes_no),
  can_call = post_helper.getValidateInEnumSelect(yes_no),
}

local user_data, user_helpmsg = post_helper.handleTableQuery(
  user_columns,
  user_options,
  nil,
  nil,
  user_valid
)

local provider_columns = {
  {
    header = T"User Name",
    name = "defaultuser",
    param = "defaultuser",
    type = "text",
    attr = { input = { class = "span2", maxlength = "63" } },
  },
  {
    header = T"Password",
    name = "secret",
    param = "secret",
    type = "password",
    attr = { input = { class = "span2", maxlength = "128" } },
  },
  {
    header = T"SIP Server/Registrar",
    name = "host",
    param = "host",
    type = "text",
    attr = { input = { class = "span2", maxlength = "253" } },
  },
  {
    header = T"Incoming Calls",
    name = "register",
    param = "register",
    type = "select",
    values = yes_no,
    default = "yes",
    attr = { select = { class = "span2" } },
  },
  {
    header = T"Outgoing Calls",
    name = "make_outgoing_calls",
    param = "make_outgoing_calls",
    type = "select",
    values = yes_no,
    default = "yes",
    attr = { select = { class = "span2" } },
  },
  {
    header = T"SIP Realm",
    name = "fromdomain",
    param = "fromdomain",
    type = "text",
    attr = { input = { class = "span2", maxlength = "253" } },
  },
  {
    header = T"Port",
    name = "port",
    param = "port",
    type = "text",
    attr = { input = { class = "span1", maxlength = "5" } },
  },
  {
    header = T"Outbound Proxy",
    name = "outboundproxy",
    param = "outboundproxy",
    type = "text",
    attr = { input = { class = "span2", maxlength = "253" } },
  },
}

local provider_basepath = "uci.pbx-voip.voip_provider.@."

local function update_provider_name(index, provider)
  local defaultuser = string.untaint(provider.defaultuser or "")
  local host = string.untaint(provider.host or "")
  -- luci-app-pbx reads the 'name' option; the UCI section is a stable key.
  proxy.set(provider_basepath .. index .. ".name", provider_name(defaultuser, host))
end

local provider_options = {
  tableid = "asterisk_voip_providers",
  basepath = provider_basepath,
  createMsg = T"Add SIP Provider",
  canApply = true,
  addNamedObject = true,
  objectName = table_add_name("asterisk_voip_providers"),
  onModify = update_provider_name,
}

local provider_valid = {
  defaultuser = validate_uci_name,
  secret = post_helper.getValidationPassword(post_helper.validateNonEmptyString),
  host = function(value)
    if type(value) ~= "string" and not string.istainted(value) then
      return nil, T"Received a non string value."
    end
    return host_validation(value)
  end,
  register = post_helper.getValidateInEnumSelect(yes_no),
  make_outgoing_calls = post_helper.getValidateInEnumSelect(yes_no),
  fromdomain = optional_host,
  port = post_helper.getOptionalValidation(post_helper.validateStringIsPort),
  outboundproxy = optional_host,
}

local provider_name = table_add_name("asterisk_voip_providers")
local provider_defaults = provider_name and { name = provider_name } or nil

local provider_data, provider_helpmsg = post_helper.handleTableQuery(
  provider_columns,
  provider_options,
  nil,
  provider_defaults,
  provider_valid
)

-- Never send configured SIP secrets back to the browser. The password validator
-- treats this placeholder as "keep the existing value" when a row is edited.
for _, row in ipairs(user_data) do
  row[3] = "********"
end
for _, row in ipairs(provider_data) do
  row[2] = "********"
end

local status_box = { alert = { class = "alert alert-info" } }
local service_status = command_output(
  "if pidof asterisk >/dev/null || pidof asterisk.bin >/dev/null; then echo Running; else echo Stopped; fi"
)
local version = command_output("asterisk -V")
local uptime = command_output("asterisk -rx 'core show uptime'")
local registrations = command_output("asterisk -rx 'sip show registry'")
local peers = command_output("asterisk -rx 'sip show peers'")
local channels = command_output("asterisk -rx 'core show channels'")

ngx.print('\
  <form class="form-horizontal" method="post" action="'); ngx.print(escape_html(uri)); ngx.print('">\
')
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
ngx.print('<fieldset><legend>' .. T"Asterisk Status" .. '</legend>')
ngx.print(ui_helper.createAlertBlock(
  T"The status is read directly from Asterisk. Refresh this page to update it.",
  status_box
))
ngx.print('<p><strong>' .. T"Service" .. ':</strong></p><pre>' .. escape_html(service_status) .. '</pre>')
ngx.print('<p><strong>' .. T"Version" .. ':</strong></p><pre>' .. escape_html(version) .. '</pre>')
ngx.print('<p><strong>' .. T"Uptime" .. ':</strong></p><pre>' .. escape_html(uptime) .. '</pre>')
ngx.print('<p><strong>' .. T"SIP Registrations" .. ':</strong></p><pre>' .. escape_html(registrations) .. '</pre>')
ngx.print('<p><strong>' .. T"SIP Peers" .. ':</strong></p><pre>' .. escape_html(peers) .. '</pre>')
ngx.print('<p><strong>' .. T"Active Channels" .. ':</strong></p><pre>' .. escape_html(channels) .. '</pre>')
ngx.print('</fieldset>')

ngx.print('<fieldset><legend>' .. T"PBX Settings" .. '</legend>')
ngx.print(ui_helper.createInputText(T"User Agent", "useragent", content.useragent, nil, helpmsg.useragent))
ngx.print(ui_helper.createInputText(T"Ring Time", "ringtime", content.ringtime, nil, helpmsg.ringtime))
ngx.print(ui_helper.createInputText(T"External Host", "externhost", content.externhost, nil, helpmsg.externhost))
ngx.print(ui_helper.createInputText(T"SIP Bind Port", "bindport", content.bindport, nil, helpmsg.bindport))
ngx.print(ui_helper.createInputText(T"RTP Start Port", "rtpstart", content.rtpstart, nil, helpmsg.rtpstart))
ngx.print(ui_helper.createInputText(T"RTP End Port", "rtpend", content.rtpend, nil, helpmsg.rtpend))
ngx.print('</fieldset>')

ngx.print('<fieldset><legend>' .. T"SIP Provider Accounts" .. '</legend>')
ngx.print(ui_helper.createTable(provider_columns, provider_data, provider_options, nil, provider_helpmsg))
ngx.print('</fieldset>')

ngx.print('<fieldset><legend>' .. T"SIP User Accounts" .. '</legend>')
ngx.print(ui_helper.createTable(user_columns, user_data, user_options, nil, user_helpmsg))
ngx.print('</fieldset></form></div>')
ngx.print(ui_helper.createFooter())
