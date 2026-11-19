-- Model assets and cycle-safe parent relationships shared by topology views.
local M = {}
local function plain(value)
  if value == nil then return "" end
  if string.untaint then value = string.untaint(value) end
  return tostring(value)
end
M.plain = plain

function M.mac(value)
  return plain(value):upper():gsub("%-", ":")
end

function M.image(model, fallback)
  model = plain(model):match("^%s*(.-)%s*$")
  local ok, models = pcall(require, "model_helper")
  local short = model:gsub("^MediaAccess%s+", ""):gsub("^Technicolor%s+", "")
  local token = ok and (models[model] or models[short] or models["MediaAccess " .. short] or models["Technicolor " .. short]) or nil
  token = token or short
  if token:match("^[%w _%-]+$") then
    local name = "gateway_" .. token .. ".png"
    local f = io.open("/www/docroot/img/" .. name, "r")
    if f then f:close(); return name, true end
  end
  return fallback == "gateway" and "gateway_icon.png" or "extender_icon.png", false
end

function M.local_image()
  local ok, values = pcall(require("datamodel").get, "uci.env.var.prod_friendly_name")
  return M.image(ok and values and values[1] and values[1].value, "gateway")
end

function M.forest(nodes)
  local copies, indexed, parents, roots = {}, {}, {}, {}
  for _, node in ipairs(nodes) do
    local copy = {children={}}
    for k, v in pairs(node) do copy[k] = v end
    copy.children = {}
    copies[#copies + 1] = copy
    local key = M.mac(copy.macAddr)
    if key ~= "" and not indexed[key] then indexed[key] = copy end
  end
  for _, node in ipairs(copies) do
    local parent = indexed[M.mac(node.parentAccessPoint)]
    if parent ~= node then parents[node] = parent end
  end
  for _, node in ipairs(copies) do
    local seen, current = {}, node
    while current do
      if seen[current] then parents[node] = nil; break end
      seen[current], current = true, parents[current]
    end
  end
  for _, node in ipairs(copies) do
    local parent = parents[node]
    local siblings = parent and parent.children or roots
    siblings[#siblings + 1] = node
  end
  return roots
end

return M
