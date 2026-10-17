-- Technicolor wireless backend for legacy LuCI. Never expose credentials in status.
local M = {}
local function qtn()
  local ok, module = pcall(require, "modgui.luci_qtn")
  return ok and module or nil
end

local function sorted(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

local function name(s)
  return type(s) == "string" and s:match("^[%w_%-]+$") ~= nil
end

function M.supported()
  local ok, uci = pcall(require, "luci.model.uci")
  if not ok then return false end
  local c, radios, aps = uci.cursor(), false, false
  c:foreach("wireless", "wifi-device", function(s)
    if s.type == "broadcom" or s.type == "quantenna" then radios = true end
  end)
  c:foreach("wireless", "wifi-ap", function() aps = true end)
  return radios and aps
end

function M.target(upstream)
  if M.supported() then
    local action=require("luci.dispatcher").form("admin_network/tch_wireless")
    local render=action.target
    action.target=function(self,...)
      local args={...}
      local http=require('luci.http')
      if args[1]=='pending' and http.formvalue('status')=='1' then
        http.header('Cache-Control','no-store')
        http.prepare_content('application/json')
        http.write_json(require('modgui.luci_qtn').job_status(args[2]))
        return
      end
      return render(self,...)
    end
    return action
  end
  return upstream
end

-- Only accept complete successful calls; an empty station map is valid.
local function call(bus, object, args)
  local ok, result = pcall(bus, object, "get", args or {})
  if not ok or type(result) ~= "table" then
    return nil, "Wireless backend unavailable: " .. object
  end
  return result
end

local function text(value)
  if type(value)=='string' and #value>0 and #value<=256 and not value:find('[%z\1-\31\127]') then return value end
end
local function counter(value)
  value=tonumber(value)
  if value and value==value and value>=0 and value<math.huge then return value end
end
local function station(mac,st)
  local result={mac=mac,signal=tonumber(st.rssi),rx=counter(st.rx_phy_rate),tx=counter(st.tx_phy_rate)}
  for _,key in ipairs({'assoc_time','idle_time','rx_bytes','tx_bytes','rx_packets','tx_packets','rx_failures',
    'tx_failures','tx_noack_failures','rx_sec_failures','retransmission_count','rx_data_rate','tx_data_rate'}) do
    result[key]=counter(st[key])
  end
  for _,key in ipairs({'flags','capabilities','authentication','encryption','rx_phy_rate_coded','tx_phy_rate_coded'}) do
    result[key]=text(st[key])
  end
  return result
end

local function enrich_hosts(snapshot,bus)
  local devices=call(bus,'hostmanager.device')
  if not devices then return end
  local hosts={}
  for mac,device in pairs(devices) do
    if type(device)=='table' then
      local address=device['mac-address'] or mac
      if type(address)=='string' then hosts[address:lower()]=device end
    end
  end
  for _,radio in ipairs(snapshot.radios) do for _,net in ipairs(radio.networks) do for _,client in ipairs(net.stations) do
    local host=hosts[client.mac:lower()]
    if host then
      client.hostname=text(host.hostname)
      client.ipv4={}; client.ipv6={}
      for _,family in ipairs({'ipv4','ipv6'}) do
        if type(host[family])=='table' then
          for _,ip in pairs(host[family]) do
            if type(ip)=='table' and text(ip.address) and ip.address:match('^[%x:%.]+$') then
              client[family][#client[family]+1]=ip.address
            end
          end
          table.sort(client[family])
        end
      end
    end
  end end end
end

function M.snapshot(cursor, bus)
  cursor = cursor or require("luci.model.uci").cursor()
  bus = bus or require("luci.util").ubus
  local radios, err = call(bus, "wireless.radio")
  if not radios then return nil, err end
  local ssids; ssids, err = call(bus, "wireless.ssid")
  if not ssids then return nil, err end
  local aps = {}
  local steering = false
  cursor:foreach("wireless", "wifi-bandsteer", function(s)
    if s.state == "1" then steering = true end
  end)
  cursor:foreach("wireless", "wifi-ap", function(s)
    if name(s[".name"]) and name(s.iface) then
      aps[s.iface] = s
    end
  end)
  local result = {radios = {}, steering = steering}
  for _, id in ipairs(sorted(radios)) do
    local r = radios[id]
    if name(id) and type(r) == "table" then
      local radio = {id = id, up = r.oper_state == 1, enabled = cursor:get("wireless", id, "state") or tostring(r.admin_state),
        band = r.band, type = cursor:get("wireless", id, "type"), channel = r.channel, width = r.channel_width,
        requested_channel = cursor:get("wireless", id, "channel") or tostring(r.requested_channel or ""),
        requested_width = cursor:get("wireless", id, "channelwidth") or r.requested_channel_width, channels = {}, widths = {"auto", "20MHz"},
        networks = {}}
      for ch in tostring(r.allowed_channels or ""):gmatch("%d+") do radio.channels[#radio.channels + 1] = ch end
      local caps = tostring(r.capabilities or "")
      if caps:find("40MHz", 1, true) or caps:find("80MHz", 1, true) or caps:find("160MHz", 1, true) then
        radio.widths[#radio.widths + 1] = "40MHz"
      end
      if caps:find("80MHz", 1, true) or caps:find("160MHz", 1, true) then radio.widths[#radio.widths + 1] = "80MHz" end
      if caps:find("160MHz", 1, true) then radio.widths[#radio.widths + 1] = "160MHz" end
      for _, sid in ipairs(sorted(ssids)) do
        local s, ap = ssids[sid], aps[sid]
        if name(sid) and type(s) == "table" and s.radio == id and ap then
          local stations, station_error = call(bus, "wireless.accesspoint.station", {name = ap[".name"]})
          local net = {id = sid, ap = ap[".name"], ssid = cursor:get("wireless", sid, "ssid") or s.ssid,
            up = s.oper_state == 1, enabled = tostring(ap.state or "0"),
            security = ap.security_mode, stations = {}, station_error = station_error,
            owned = ap[".name"] ~= "ap0" and ap[".name"] ~= "ap1" and ap[".name"] ~= "ap2" and ap[".name"] ~= "ap3" and
              cursor:get("wireless", sid, "ap_display_name") == "modgui-luci",
            editable = not steering and (not ap.bandsteer_id or ap.bandsteer_id == "" or ap.bandsteer_id == "0" or ap.bandsteer_id == "off")}
          if (net.ap == "ap0" or net.ap == "ap1") and radio.enabled ~= "1" then net.enabled = "0" end
          if stations and type(stations[net.ap]) ~= "table" then
            net.station_error = "Station data missing: " .. net.ap
          elseif stations then
            for _, mac in ipairs(sorted(stations[net.ap])) do
              local st = stations[net.ap][mac]
              if type(st) == "table" and mac:match("^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$") and
                not (st.flags=='' and tonumber(st.rssi)==0) then
                net.stations[#net.stations + 1] = station(mac,st)
              end
            end
          end
          radio.networks[#radio.networks + 1] = net
        end
      end
      result.radios[#result.radios + 1] = radio
    end
  end
  local remote = qtn()
  if remote then
    for _, r in ipairs(result.radios) do
      if r.type == "quantenna" then
        for _, n in ipairs(remote.networks()) do r.networks[#r.networks + 1] = n end
      end
    end
  end
  if #result.radios == 0 then return nil, "No radio data available" end
  enrich_hosts(result,bus)
  return result
end

function M.format_bytes(value)
  if value==nil then return '?' end
  local units={'B','KiB','MiB','GiB','TiB'}; local unit=1
  while value>=1024 and unit<#units do value=value/1024; unit=unit+1 end
  return string.format(unit==1 and '%.0f %s' or '%.2f %s',value,units[unit])
end
function M.format_duration(value)
  if value==nil then return '?' end
  value=math.floor(value)
  local days=math.floor(value/86400); local hours=math.floor(value/3600)%24
  return (days>0 and days..'d ' or '')..string.format('%02d:%02d:%02d',hours,math.floor(value/60)%60,value%60)
end

function M.scope(snapshot, sid)
  for _, r in ipairs(snapshot.radios) do
    for _, n in ipairs(r.networks) do
      if n.id == sid then
        local radio = {}
        for k, v in pairs(r) do radio[k] = v end
        radio.networks = {n}
        return {radios = {radio}, steering = snapshot.steering}, n
      end
    end
  end
end

-- Credentials are read only for the authenticated edit form, never status.
function M.password(ap, proxy)
  if not name(ap) then return nil end
  if ap:match("^qtn_wifi[23]$") then local remote = qtn(); return remote and remote.password(ap) end
  proxy = proxy or require("datamodel")
  local ok, values = pcall(proxy.get, "rpc.wireless.ap.@" .. ap .. ".security.wpa_psk_passphrase")
  if ok and type(values) == "table" and values[1] and type(values[1].value) == "string" then
    return values[1].value
  end
end

local function contains(t, value)
  for _, v in ipairs(t) do if v == value then return true end end
  return false
end

-- Build a whitelist from fresh native state, never from submitted paths.
function M.fields(snapshot)
  local fields = {}
  local function add(id, path, value, kind, choices)
    fields[id] = {path = path, value = value, kind = kind, choices = choices}
  end
  for _, r in ipairs(snapshot.radios) do
    local p = "rpc.wireless.radio.@" .. r.id .. "."
    add(r.id .. "_enabled", p .. "admin_state", r.enabled, "choice", {"0", "1"})
    add(r.id .. "_channel", p .. "requested_channel", r.requested_channel, "choice", {"auto", unpack(r.channels)})
    add(r.id .. "_width", p .. "requested_channel_width", r.requested_width, "choice", r.widths)
    for _, n in ipairs(r.networks) do
      -- Native ap0/ap1 setters also change radio state; use the radio switch
      -- for these APs to avoid order-dependent writes of the same setting.
      if n.ap ~= "ap0" and n.ap ~= "ap1" then
        add(n.id .. "_enabled", "rpc.wireless.ap.@" .. n.ap .. ".admin_state", n.enabled, "choice", {"0", "1"})
      end
      if n.editable then
        add(n.id .. "_ssid", "rpc.wireless.ssid.@" .. n.id .. ".ssid", n.ssid, "ssid")
        if n.security == "wpa2-psk" or n.security == "wpa-wpa2-psk" or n.security == "wpa3-psk" then
          add(n.id .. "_password", "rpc.wireless.ap.@" .. n.ap .. ".security.wpa_psk_passphrase", "", "password")
        end
      end
    end
  end
  return fields
end

function M.validate(field, value)
  if type(value) ~= "string" then return nil, "Missing value" end
  if field.kind == "choice" then
    if not contains(field.choices, value) then return nil, "Unsupported value" end
  elseif field.kind == "ssid" then
    if #value < 1 or #value > 32 or value:find("[%z\1-\31\127]") then return nil, "SSID must contain 1 to 32 bytes without control characters" end
  elseif field.kind == "password" and value ~= "" then
    if not ((#value >= 8 and #value <= 63 and value:match("^[ -~]+$") and not value:find("[<>]")) or
      (#value == 64 and value:match("^%x+$"))) then return nil, "Use 8 to 63 printable characters or 64 hexadecimal digits" end
  end
  return value
end
function M.validate_remote_ssid(value)
  if type(value)~="string" or not value:match("^[%w_.%-]+$") then
    return nil,"For remote 5 GHz SSIDs use letters, numbers, dot, underscore or hyphen"
  end
  return M.validate({kind="ssid"},value)
end

function M.save(snapshot, data, proxy)
  local selected = snapshot.radios[1] and snapshot.radios[1].networks[1]
  if #snapshot.radios == 1 and selected and selected.qtn then
    local valid, err=M.validate_remote_ssid(data[selected.id .. "_ssid"])
    if not valid then return nil,err end
    for id, f in pairs(M.fields(snapshot)) do
      local value, err = M.validate(f, data[id] or (f.kind == "password" and "" or nil))
      if not value then return nil, id .. ": " .. err end
    end
    local r = {}; for k,v in pairs(snapshot.radios[1]) do r[k] = v end; r.networks = {}
    local only_radio = {radios = {r}}
    local radio_ok, radio_message = M.save(only_radio, data, proxy)
    if not radio_ok then return nil, radio_message end
    local remote = qtn()
    local ok, message = remote.update(selected.id, {ssid = data[selected.id .. "_ssid"],
      password = data[selected.id .. "_password"], enabled = data[selected.id .. "_enabled"]})
    if not ok then
      local restore = {}; for id, f in pairs(M.fields(only_radio)) do restore[id] = f.value end
      M.save(only_radio, restore, proxy)
      return nil, message
    end
    if radio_message ~= "No changes to apply" then remote.reconcile(); return true, radio_message end
    return true, message
  end
  local fields, changes = M.fields(snapshot), {}
  for id, f in pairs(fields) do
    local value, err = M.validate(f, data[id] or (f.kind == "password" and "" or nil))
    if not value then return nil, id .. ": " .. err end
    if value ~= f.value and not (f.kind == "password" and value == "") then changes[f.path] = value end
  end
  if not next(changes) then return true, "No changes to apply" end
  proxy = proxy or require("datamodel")
  -- Verify every original value before writing. Never log credentials.
  local previous = {}
  for path in pairs(changes) do
    local read_ok, values = pcall(proxy.get, path)
    if not read_ok or type(values) ~= "table" or not values[1] or type(values[1].value) ~= "string" then
      return nil, "Cannot read current configuration; no changes applied"
    end
    previous[path] = values[1].value
    if changes[path] == previous[path] then changes[path] = nil end
  end
  if not next(changes) then return true, "No changes to apply" end
  local function invoke(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and result
  end
  local ok = invoke(proxy.set, changes)
  if ok then ok = invoke(proxy.apply) end
  if not ok then
    local restored = invoke(proxy.set, previous)
    if restored then restored = invoke(proxy.apply) end
    return nil, restored and "Could not apply changes; previous settings restored" or
      "Could not apply or restore settings; check the native wireless UI"
  end
  return true, "Changes applied successfully"
end

function M.creation_options(snapshot, cursor)
  cursor = cursor or require("luci.model.uci").cursor()
  local options = {radios = {}, networks = {}, networks_by_radio = {}, unavailable = {}}
  cursor:foreach("network", "interface", function(s)
    if name(s[".name"]) and s[".name"] ~= "loopback" then options.networks[#options.networks + 1] = s[".name"] end
  end)
  table.sort(options.networks)
  for _, r in ipairs(snapshot.radios) do
    local base
    cursor:foreach("wireless", "wifi-iface", function(s)
      if s.device == r.id and s[".name"]:match("^wl%d+$") then base = s[".name"] end
    end)
    if r.type == "quantenna" then
      local remote = qtn()
      if remote and remote.available() and remote.primary_network() and #remote.list() < 2 then
        options.radios[r.id] = "qtn"
        options.networks_by_radio[r.id] = {remote.primary_network()}
      else
        options.unavailable[r.id] = "No additional remote SSID slots available."
      end
    elseif base then
      for i = 1, 3 do
        local sid = base .. "_" .. i
        if not cursor:get("wireless", sid) then options.radios[r.id] = sid; break end
      end
    end
  end
  return options
end

function M.create(snapshot, data, cursor, proxy, async)
  cursor = cursor or require("luci.model.uci").cursor()
  local options = M.creation_options(snapshot, cursor)
  local sid = options.radios[data.radio]
  if not sid then return nil, options.unavailable[data.radio] or "No additional SSID slot available on this radio" end
  if not contains(options.networks, data.network) then return nil, "Select an existing network" end
  local valid, err = M.validate({kind = "ssid"}, data.ssid)
  if not valid then return nil, err end
  valid, err = M.validate({kind = "password"}, data.password)
  if not valid or data.password == "" then return nil, err or "A WPA2 password is required" end
  if data.enabled ~= "0" and data.enabled ~= "1" then return nil, "Invalid network state" end
  if sid == "qtn" then
    local valid,err=M.validate_remote_ssid(data.ssid)
    if not valid then return nil,err end
    if async then return qtn().start_job(data) end
    return qtn().create(data)
  end
  local ap
  for i = 4, 31 do
    if not cursor:get("wireless", "ap" .. i) then ap = "ap" .. i; break end
  end
  if not ap then return nil, "No access point slot available" end
  proxy = proxy or require("datamodel")
  local iface_path = "uci.wireless.wifi-iface.@" .. sid .. "."
  local ap_path = "uci.wireless.wifi-ap.@" .. ap .. "."
  local added = {}
  local ok = pcall(function()
    assert(proxy.add("uci.wireless.wifi-iface.", sid) == sid)
    added[#added + 1] = iface_path
    assert(proxy.add("uci.wireless.wifi-ap.", ap) == ap)
    added[#added + 1] = ap_path
    local values = {}
    local iface = {device = data.radio, ssid = data.ssid, network = data.network,
      state = data.enabled, mode = "ap", uapsd = "0", ap_display_name = "modgui-luci"}
    local accesspoint = {iface = sid, state = data.enabled, public = "1", ap_isolation = "0",
      station_history = "1", security_mode = "wpa2-psk", wpa_psk_key = data.password,
      wps_state = "0", wsc_state = "configured", acl_mode = "disabled", bandsteer_id = "off"}
    for k, v in pairs(iface) do values[iface_path .. k] = v end
    for k, v in pairs(accesspoint) do values[ap_path .. k] = v end
    assert(proxy.set(values))
    assert(proxy.apply())
  end)
  if not ok then
    local cleaned = true
    for i = #added, 1, -1 do
      local success, result = pcall(proxy.del, added[i])
      cleaned = success and result and cleaned
    end
    local success, result = pcall(proxy.apply)
    return nil, cleaned and success and result and "Could not create network; new sections removed" or
      "Could not create network; check wireless configuration for incomplete sections"
  end
  return sid
end

function M.remove(snapshot, sid, proxy)
  local _, net = M.scope(snapshot, sid)
  if not net or not net.owned then return nil, "Only networks created here can be removed" end
  if net.qtn then return qtn().remove(sid) end
  proxy = proxy or require("datamodel")
  local ok = pcall(function()
    assert(proxy.del("uci.wireless.wifi-ap.@" .. net.ap .. "."))
    assert(proxy.del("uci.wireless.wifi-iface.@" .. net.id .. "."))
    assert(proxy.apply())
  end)
  return ok, not ok and "Could not remove network; check wireless configuration" or nil
end

function M.toggle(snapshot, sid, proxy)
  local _, net = M.scope(snapshot, sid)
  if not net then return nil, "Unknown network" end
  if net.qtn then return qtn().update(sid, {enabled = net.enabled == "1" and "0" or "1"}) end
  proxy = proxy or require("datamodel")
  local ok = pcall(function()
    assert(proxy.set("rpc.wireless.ap.@" .. net.ap .. ".admin_state", net.enabled == "1" and "0" or "1"))
    assert(proxy.apply())
  end)
  return ok, not ok and "Could not change network state" or nil
end

return M
