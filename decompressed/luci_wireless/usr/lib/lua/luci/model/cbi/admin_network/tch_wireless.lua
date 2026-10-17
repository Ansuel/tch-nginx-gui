local backend = require("luci.model.tch_wireless")
local http = require("luci.http")
local dispatcher = require("luci.dispatcher")
local base = dispatcher.build_url("admin", "network", "wireless")
local m = SimpleForm("tch_wireless", translate("Wireless"))
m.reset = false
http.header("Cache-Control", "no-store")
local selected = arg[1]
if selected == 'pending' then
  if not arg[2] or #arg[2]~=32 or not arg[2]:match('^%x+$') then http.redirect(base); return end
  m.template='tch_wireless_pending'
  m.submit=false
  m.pending_url=base..'/pending/'..arg[2]
  m.overview_url=base
  return m
end
local snapshot, err = backend.snapshot()
if not snapshot then m.errmessage = err; m.submit = false; return m end
local function redirect(message)
  http.redirect(base .. "?saved=" .. message)
  return false
end

if not selected or selected == "" then
  m.template = "tch_wireless_overview"
  m.snapshot = snapshot
  m.creation = backend.creation_options(snapshot)
  function m.handle(self, state)
    if state == FORM_VALID then
      local fresh, message = backend.snapshot()
      if not fresh then self.errmessage = message; return true end
      local ok
      if http.formvalue("remove") then
        ok, message = backend.remove(fresh, http.formvalue("remove"))
      elseif http.formvalue("toggle") then
        ok, message = backend.toggle(fresh, http.formvalue("toggle"))
      else return true end
      if ok then return redirect("1") end
      self.errmessage = message
    end
    return true
  end
elseif selected == "add" then
  m.title = translate("Add Wireless Network")
  m.submit = translate("Save & Apply")
  local choices = backend.creation_options(snapshot)
  local section = m:section(SimpleSection, translate("Interface Configuration"))
  local radio = section:option(ListValue, "radio", translate("Device"))
  radio.rmempty = false
  for _, r in ipairs(snapshot.radios) do
    if choices.radios[r.id] and (not arg[2] or arg[2] == r.id) then radio:value(r.id, r.id .. " (" .. (r.band or "") .. ")") end
  end
  radio.default = arg[2]
  local ssid = section:option(Value, "ssid", translate("ESSID"))
  ssid.rmempty = false
  local remote = false
  for _, r in ipairs(snapshot.radios) do if r.id == arg[2] and r.type == "quantenna" then remote = true end end
  if remote then ssid.description = translate("For this radio, use letters, numbers, dot, underscore or hyphen.") end
  function ssid.validate(self, value)
    if remote then return backend.validate_remote_ssid(value) end
    return backend.validate({kind="ssid"}, value)
  end
  local network = section:option(ListValue, "network", translate("Network"))
  network.rmempty = false
  for _, id in ipairs(choices.networks_by_radio[arg[2]] or choices.networks) do network:value(id) end
  network.default = "lan"
  local encryption = section:option(DummyValue, "encryption", translate("Encryption"))
  encryption.default = "WPA2-PSK (CCMP)"
  local password = section:option(Value, "password", translate("Key"))
  password.password = true
  password.rmempty = false
  function password.validate(self, value)
    if value == "" then return nil, translate("A WPA2 password is required") end
    return backend.validate({kind="password"}, value)
  end
  local enabled = section:option(ListValue, "enabled", translate("Enable this network"))
  enabled:value("1", translate("Enabled")); enabled:value("0", translate("Disabled"))
  enabled.default = "1"; enabled.rmempty = false
  function m.handle(self, state, data)
    if state == FORM_VALID then
      local fresh, message = backend.snapshot()
      if not fresh then self.errmessage = message; return true end
      local sid, pending; sid, message, pending = backend.create(fresh, data, nil, nil, true)
      if sid then
        http.redirect(base .. (pending=='pending' and '/pending/'..sid or '/'..sid..'?saved=1'))
        return false
      end
      self.errmessage = message
    end
    self.data.password = nil
    return true
  end
else
  local scoped, net = backend.scope(snapshot, selected)
  if not scoped then http.redirect(base); return end
  local radio = scoped.radios[1]
  m.title = radio.id .. ": " .. translate("Master") .. " \"" .. luci.util.pcdata(net.ssid or net.id) .. "\""
  m.description = translate("The Device Configuration section covers physical settings of the radio shared among all defined wireless networks. Per network settings are grouped in the Interface Configuration.")
  m.submit = translate("Save & Apply")
  local fields = backend.fields(scoped)
  local function option(section, tab, class, id, title)
    local f = fields[id]
    if not f then return end
    local o = section:taboption(tab, class, id, title)
    o.default = f.value; o.rmempty = f.kind == "password"
    if class == ListValue then
      for _, value in ipairs(f.choices) do o:value(value, value == "auto" and translate("Auto") or value) end
    end
    function o.validate(self, value)
      if net.qtn and f.kind == "ssid" then return backend.validate_remote_ssid(value) end
      return backend.validate(f, value)
    end
    if net.qtn and f.kind == "ssid" then o.description = translate("For this radio, use letters, numbers, dot, underscore or hyphen.") end
    return o
  end
  local device = m:section(SimpleSection, translate("Device Configuration"), radio.id)
  device.template = "tch_wireless_tabs"
  device.tabgroup = "device"
  device:tab("general", translate("General Setup"))
  local status = device:taboption("general", DummyValue, "_status", translate("Status"))
  status.default = string.format("%s | %s: %s | %s", radio.up and translate("Active") or translate("Inactive"),
    translate("Channel"), tostring(radio.channel or "?"), radio.width or "?")
  local enabled = option(device, "general", ListValue, radio.id .. "_enabled", translate("Radio enabled"))
  enabled.vallist = {translate("Disabled"), translate("Enabled")}
  option(device, "general", ListValue, radio.id .. "_channel", translate("Channel"))
  option(device, "general", ListValue, radio.id .. "_width", translate("Width"))
  local section = m:section(SimpleSection, translate("Interface Configuration"))
  section.template = "tch_wireless_tabs"
  section.tabgroup = "interface"
  section:tab("general", translate("General Setup"))
  section:tab("encryption", translate("Wireless Security"))
  local mode = section:taboption("general", DummyValue, "_mode", translate("Mode"))
  mode.default = translate("Access Point")
  option(section, "general", Value, net.id .. "_ssid", translate("ESSID"))
  if not net.editable then
    local ssid = section:taboption("general", DummyValue, "_ssid", translate("ESSID"))
    ssid.default = net.ssid
    ssid.description = translate("Use the native wireless UI to edit paired or band-steered networks.")
  end
  local ap = option(section, "general", ListValue, net.id .. "_enabled", translate("Enable this network"))
  if ap then ap.vallist = {translate("Disabled"), translate("Enabled")} end
  local encryption = section:taboption("encryption", DummyValue, "_encryption", translate("Encryption"))
  encryption.default = net.security
  if net.security == "wpa2-psk" or net.security == "wpa-wpa2-psk" or net.security == "wpa3-psk" then
    local password = option(section, "encryption", Value, net.id .. "_password", translate("Key"))
    if not password then
      password = section:taboption("encryption", Value, "_password", translate("Key"))
      password.readonly = true
    end
    password.password = true
    local saved = backend.password(net.ap)
    password.default = saved or ""
    password.description = saved and translate("Click the asterisk to reveal/hide the saved key. Leave empty to keep it unchanged.") or
      translate("Saved key unavailable. Leave empty to keep it unchanged.")
  end
  function m.handle(self, state, data)
    if state == FORM_VALID then
      local fresh, message = backend.snapshot()
      fresh = fresh and backend.scope(fresh, selected)
      if not fresh then self.errmessage = message or translate("Network no longer available"); return true end
      local ok; ok, message = backend.save(fresh, data)
      if ok then
        http.redirect(base .. "/" .. selected .. (message == "No changes to apply" and "?saved=0" or "?saved=1"))
        return false
      end
      self.errmessage = message
    end
    for id, f in pairs(fields) do if f.kind == "password" then self.data[id] = nil end end
    return true
  end
end
if http.formvalue("saved") == "1" then m.message = translate("Changes applied; radio status may take a few seconds to update.") end
if http.formvalue("saved") == "0" then m.message = translate("No changes to apply") end
m:section(SimpleSection).template = "tch_wireless_back"
return m
