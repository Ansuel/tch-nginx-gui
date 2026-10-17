-- Idempotent, narrowly scoped patch for LuCI 18.06's network controller.
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
local pattern = 'arcombine%s*%(%s*cbi%s*%(%s*"admin_network/wifi_overview"%s*%)%s*,%s*cbi%s*%(%s*"admin_network/wifi"%s*%)%s*%)'
local count
local updated; updated, count = source:gsub(pattern, function(target)
  return marker .. target .. ')'
end)
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
