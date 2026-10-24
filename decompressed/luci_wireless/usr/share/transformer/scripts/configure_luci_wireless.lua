-- Idempotent patch for current and legacy LuCI network controllers.
local path = "/usr/lib/lua/luci/controller/admin/network.lua"
local marker = 'require("luci.model.tch_wireless").target('
local function clear_cache()
  os.remove("/tmp/luci-indexcache")
  for _, module in ipairs({"luci.controller.admin.network", "luci.model.tch_wireless", "modgui.luci_qtn", "modgui.wpa_psk"}) do
    local hex = module:gsub(".", function(c) return string.format("%02X", c:byte()) end)
    os.remove("/tmp/luci-modulecache/" .. hex)
  end
end
local f = io.open(path, "r")
if not f then return end
local source = f:read("*a"); f:close()
if source:find(marker, 1, true) then clear_cache(); return end
if not require("luci.model.tch_wireless").supported() then return end
local updated, count = source, 0
-- Legacy MIPS LuCI renders the overview as a template rather than a CBI form.
for _, overview in ipairs({"cbi", "template"}) do
  local pattern = 'arcombine%s*%(%s*' .. overview .. '%s*%(%s*"admin_network/wifi_overview"%s*%)%s*,%s*cbi%s*%(%s*"admin_network/wifi"%s*%)%s*%)'
  local matched
  updated, matched = updated:gsub(pattern, function(target)
    return marker .. target .. ')'
  end)
  count = count + matched
end
if count ~= 1 then error("Unsupported LuCI wireless controller; original retained") end
-- Suppress stock subpages (their identifiers assume the iwinfo backend).
updated, count = updated:gsub('([%w_]+)%.subindex%s*=%s*true%s*if%s+([%w_]+)%.inreq%s+then', function(node, request_node)
  return node .. '.subindex=not require("luci.model.tch_wireless").supported()\nif ' .. request_node .. '.inreq and not require("luci.model.tch_wireless").supported() then'
end, 1)
if count ~= 1 then error("Unsupported LuCI index layout; original retained") end
assert(loadstring(updated))
local backup = io.open(path .. ".modgui-wireless-original", "r")
if backup then backup:close() end
-- A package update may replace the controller: retain that version as backup.
backup = assert(io.open(path .. ".modgui-wireless-original", "w"))
assert(backup:write(source)); assert(backup:close())
f = assert(io.open(path .. ".modgui-wireless-new", "w"))
assert(f:write(updated)); assert(f:close())
assert(os.rename(path .. ".modgui-wireless-new", path))
clear_cache()
