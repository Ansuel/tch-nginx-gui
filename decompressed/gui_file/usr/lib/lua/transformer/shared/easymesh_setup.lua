-- Opt-in initialization for firmware which ships native MultiAP components.
-- Never install binaries from another board or start services while rendering.
local uci = require("uci")
local M = {}
local stage = "/etc/config/.multiap-gui"

local function exists(path)
  local file = io.open(path, "r")
  if not file then return false end
  file:close()
  return true
end

function M.can_initialize()
  if exists("/etc/config/multiap") then return false end
  for _, path in ipairs({"/rom/etc/config/multiap", "/usr/bin/multiap_agent",
    "/usr/bin/multiap_controller", "/etc/init.d/multiap_agent",
    "/etc/init.d/multiap_controller", "/usr/lib/libplatform_map.so",
    "/usr/share/transformer/mappings/uci/multiap.map",
    "/usr/share/transformer/commitapply/uci_multiap.ca"}) do
    if not exists(path) then return false end
  end
  local has_lfs, lfs = pcall(require, "lfs")
  if not has_lfs then return false end
  for _, path in ipairs({"/usr/bin/multiap_agent", "/usr/bin/multiap_controller",
    "/etc/init.d/multiap_agent", "/etc/init.d/multiap_controller"}) do
    local permissions = lfs.attributes(path, "permissions")
    if not permissions or not permissions:find("x", 1, true) then return false end
  end
  -- File names alone do not identify a compatible backend. Inspect the native
  -- template read-only, without applying production UCI deltas or starting it.
  local ok, valid = pcall(function()
    local c = uci.cursor("/rom/etc/config", "/rom/tmp/.uci")
    local compatible = true
    for _, section in ipairs({"agent", "controller", "al_entity"}) do
      if c:get("multiap", section) ~= "global" then compatible = false end
    end
    for _, section in ipairs({"agent", "controller"}) do
      local enabled = c:get("multiap", section, "enabled")
      if enabled ~= "0" and enabled ~= "1" then compatible = false end
    end
    local credentials = 0
    c:foreach("multiap", "controller_credentials", function() credentials = credentials + 1 end)
    c:unload("multiap")
    return compatible and credentials > 0
  end)
  return ok and valid or false
end

local function valid_credentials(ssid, key)
  return ssid and #ssid > 0 and #ssid <= 32 and key and
    ((#key >= 8 and #key <= 63) or (#key == 64 and key:match("^%x+$")))
end

-- Retain an existing native backhaul only if its APs are provisioned on this
-- device. Use their active credentials instead of the ROM credential values.
local function native_backhaul(c, source, main)
  local list = c:get("multiap", "agent", "backhaul_list") or ""
  if not list:match("^[%w_,%-]+$") then return nil end
  local profile, count = nil, 0
  c:foreach("multiap", "controller_credentials", function(s)
    if s.backhaul == "1" and s.fronthaul == "0" and s.state == "1" and s.security_mode == "wpa2-psk" then
      profile, count = s, count + 1
    end
  end)
  if count ~= 1 or main[profile[".name"]] then return nil end

  local aps = {}
  source:foreach("wireless", "wifi-ap", function(ap)
    if ap.iface then aps[ap.iface] = aps[ap.iface] == nil and ap or false end
  end)
  local interfaces, ssid, key = {}, nil, nil
  for name in list:gmatch("[^,]+") do
    local ap = aps[name]
    local candidate = source:get("wireless", name, "ssid")
    if main[name] or source:get("wireless", name, "mode") ~= "ap" or
      source:get("wireless", name, "network") ~= "lan" or source:get("wireless", name, "backhaul") ~= "1" or
      source:get("wireless", name, "state") ~= "1" or not ap or ap.state ~= "1" or
      ap.security_mode ~= "wpa2-psk" or not valid_credentials(candidate, ap.wpa_psk_key) or
      (ssid and (ssid ~= candidate or key ~= ap.wpa_psk_key)) then return nil end
    interfaces[#interfaces + 1] = name
    ssid, key = candidate, ap.wpa_psk_key
  end
  if not ssid then return nil end
  return {name=profile[".name"], interfaces=interfaces, ssid=ssid, key=key}
end

-- Seed active native network associations, never factory credentials.
-- Split and shared profiles follow the original web.main association lists.
function M.seed(c, source)
  local interfaces = source:get("web", "main", "intf")
  local credentials = source:get("web", "main", "cred")
  local split = source:get("web", "main", "splitssid")
  if type(interfaces) ~= "table" or type(credentials) ~= "table" or
    #interfaces == 0 or #interfaces ~= #credentials or
    (split ~= nil and split ~= "0" and split ~= "1") then
    return nil, "Complete native network associations are required for initialization."
  end
  local profiles, seen = {}, {}
  for i, intf in ipairs(interfaces) do
    local cred = credentials[i]
    if not intf:match("^[%w_%-]+$") or not cred:match("^[%w_%-]+$") or seen[cred] or seen[intf] then
      return nil, "Invalid or ambiguous native network associations."
    end
    seen[cred], seen[intf] = true, true
    local existing = c:get("multiap", cred)
    if existing and existing ~= "controller_credentials" then
      return nil, "A credential association conflicts with a native service section."
    end
    local ap
    source:foreach("wireless", "wifi-ap", function(s)
      if s.iface == intf then
        if ap then ap = false; return false end
        ap = s
      end
    end)
    local device = source:get("wireless", intf, "device")
    local ssid = source:get("wireless", intf, "ssid")
    if not ap or not device or not device:match("^[%w_%-]+$") or
      ap.security_mode ~= "wpa2-psk" or not valid_credentials(ssid, ap.wpa_psk_key) or
      source:get("wireless", intf, "backhaul") == "1" or
      source:get("wireless", intf, "network") ~= "lan" then
      return nil, "Initialization requires native LAN interfaces using WPA2-PSK."
    end
    if source:get("wireless", intf, "state") ~= "1" or ap.state ~= "1" then
      return nil, "Enable the main Wi-Fi networks before initializing EasyMesh."
    end
    profiles[#profiles + 1] = {name=cred, radio=device, ssid=ssid, key=ap.wpa_psk_key}
  end
  local shared = true
  for _, p in ipairs(profiles) do
    if p.ssid ~= profiles[1].ssid or p.key ~= profiles[1].key then
      shared = false
      break
    end
  end
  -- Some native configurations omit splitssid and store only the associations.
  if split == nil then split = shared and "0" or "1" end
  if split == "0" and not shared then
    return nil, "Shared-network metadata does not match the active Wi-Fi credentials."
  end
  local backhaul = native_backhaul(c, source, seen)
  -- Validate everything before changing the staging cursor.
  c:foreach("multiap", "controller_credentials", function(s)
    if backhaul and s[".name"] == backhaul.name then
      assert(c:set("multiap", backhaul.name, "ssid", backhaul.ssid))
      assert(c:set("multiap", backhaul.name, "wpa_psk_key", backhaul.key))
      return
    end
    c:set("multiap", s[".name"], "state", "0")
    c:set("multiap", s[".name"], "operational_state", "0")
    c:set("multiap", s[".name"], "ssid", "")
    c:set("multiap", s[".name"], "wpa_psk_key", "")
  end)
  for i, p in ipairs(profiles) do
    c:set("multiap", p.name, "controller_credentials")
    local active = (split == "1" or i == 1) and "1" or "0"
    local bands = p.radio
    if split == "0" and i == 1 then
      local radios, added = {}, {}
      for _, profile in ipairs(profiles) do
        if not added[profile.radio] then
          radios[#radios + 1], added[profile.radio] = profile.radio, true
        end
      end
      bands = table.concat(radios, ",")
    end
    for key, value in pairs({ssid=p.ssid, wpa_psk_key=p.key, security_mode="wpa2-psk",
      state=active, operational_state=active, public_state="1", fronthaul="1", backhaul="0",
      type="home", frequency_bands=bands}) do
      assert(c:set("multiap", p.name, key, value))
    end
  end
  for _, role in ipairs({"agent", "controller"}) do assert(c:set("multiap", role, "enabled", "0")) end
  if c:get("multiap", "controller_selection") then c:set("multiap", "controller_selection", "enabled", "0") end
  for _, key in ipairs({"fronthaul_list", "home_list"}) do
    assert(c:set("multiap", "agent", key, table.concat(interfaces, ",")))
  end
  local bss = table.concat(interfaces, ",")
  if backhaul then bss = bss .. "," .. table.concat(backhaul.interfaces, ",") end
  assert(c:set("multiap", "agent", "bss_list", bss))
  if not backhaul then
    for _, key in ipairs({"backhaul_list", "bh_list"}) do c:set("multiap", "agent", key, "") end
  end
  c:set("multiap", "agent", "guest_list", "")
  return true
end

function M.initialize()
  if not M.can_initialize() then return nil, "Initialization is unavailable on this firmware. Reopen the page." end
  local lfs = require("lfs")
  if not lfs.mkdir(stage) then return nil, "EasyMesh initialization is already running or needs cleanup." end
  local function cleanup()
    os.remove(stage .. "/multiap")
    os.remove(stage .. "/saved/multiap")
    lfs.rmdir(stage .. "/saved"); lfs.rmdir(stage)
  end
  local ok, result = pcall(function()
    assert(os.execute("chmod 700 /etc/config/.multiap-gui") == 0)
    assert(lfs.mkdir(stage .. "/saved"))
    local original = assert(io.open("/rom/etc/config/multiap", "r"))
    local data = original:read("*a"); original:close()
    local file = assert(io.open(stage .. "/multiap", "w"))
    assert(file:write(data)); assert(file:close())
    local c = uci.cursor(stage, stage .. "/saved")
    local success, message = M.seed(c, uci.cursor())
    if not success then c:unload("multiap"); return message end
    assert(c:commit("multiap")); c:unload("multiap")
    assert(os.execute("chmod 600 /etc/config/.multiap-gui/multiap") == 0)
    assert(not exists("/etc/config/multiap"))
    assert(os.rename(stage .. "/multiap", "/etc/config/multiap"))
    return true
  end)
  cleanup()
  if not ok then return nil, "Unable to initialize native EasyMesh. No service was started." end
  if result ~= true then return nil, result end
  return true
end

return M
