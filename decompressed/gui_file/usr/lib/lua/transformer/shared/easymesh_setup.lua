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

-- Seed only the native main-network associations, never factory credentials.
-- Split and shared profiles follow the original web.main association lists.
function M.seed(c, source)
  local interfaces = source:get("web", "main", "intf")
  local credentials = source:get("web", "main", "cred")
  local split = source:get("web", "main", "splitssid")
  if type(interfaces) ~= "table" or type(credentials) ~= "table" or
    #interfaces == 0 or #interfaces ~= #credentials or
    (split ~= "0" and split ~= "1") then
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
    if not ap or not device or not device:match("^[%w_%-]+$") or not ssid or #ssid == 0 or #ssid > 32 or
      ap.security_mode ~= "wpa2-psk" or not ap.wpa_psk_key or
      not ((#ap.wpa_psk_key >= 8 and #ap.wpa_psk_key <= 63) or
        (#ap.wpa_psk_key == 64 and ap.wpa_psk_key:match("^%x+$"))) or
      source:get("wireless", intf, "backhaul") == "1" or
      source:get("wireless", intf, "network") ~= "lan" then
      return nil, "Initialization requires native LAN interfaces using WPA2-PSK."
    end
    if source:get("wireless", intf, "state") ~= "1" or ap.state ~= "1" then
      return nil, "Enable the main Wi-Fi networks before initializing EasyMesh."
    end
    profiles[#profiles + 1] = {name=cred, radio=device, ssid=ssid, key=ap.wpa_psk_key}
  end
  if split == "0" then
    for _, p in ipairs(profiles) do
      if p.ssid ~= profiles[1].ssid or p.key ~= profiles[1].key then
        return nil, "Shared-network metadata does not match the active Wi-Fi credentials."
      end
    end
  end
  -- Validate everything before changing the staging cursor.
  c:foreach("multiap", "controller_credentials", function(s)
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
  for _, key in ipairs({"bss_list", "fronthaul_list", "home_list"}) do
    assert(c:set("multiap", "agent", key, table.concat(interfaces, ",")))
  end
  for _, key in ipairs({"backhaul_list", "bh_list", "guest_list"}) do c:set("multiap", "agent", key, "") end
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
