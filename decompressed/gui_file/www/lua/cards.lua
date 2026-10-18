local ngx = ngx
local lfs = require("lfs")
local uci = require("uci")
local sort = table.sort
local M = {}

local function plain(value)
  if string.untaint then value = string.untaint(value) end
  if type(value) == "string" then return value end
end

local function clean_card(value)
  value = plain(value)
  return value and value:gsub("^%d+_", "")
end

local function get_config()
  local config = ngx.ctx.modgui_cards_config
  if config then return config end

  config = {cards = {}, card_to_modal = {}, modal_to_card = {}}
  local cursor = uci.cursor()
  local rules = {}
  cursor:foreach("web", "rule", function(rule)
    rules[rule[".name"]] = plain(rule.target)
  end)
  cursor:foreach("web", "card", function(card)
    local target = rules[card.modal]
    local original = plain(card.card)
    if target and original and not card[".anonymous"] then
      local name = clean_card(original)
      -- hide controls visibility when modal access is denied. It is not a
      -- user preference to hide a card from an otherwise authorized session.
      config.cards[name] = {modal = target, hide = card.hide ~= "0"}
      config.card_to_modal[original] = target
      config.card_to_modal[name] = target
      config.modal_to_card[target] = original
    end
  end)
  cursor:unload("web")
  ngx.ctx.modgui_cards_config = config
  return config
end

local function card_visible(config, cardname)
  local card = config.cards[cardname]
  if card and card.hide and not ngx.ctx.session:hasAccess(card.modal) then
    return false
  end
  return true
end

local cards_limiter
do
  local found
  found, cards_limiter = pcall(require, "cards_limiter")
  if not found then cards_limiter = nil end
end

local function get_limit_info()
  local fn = cards_limiter and cards_limiter.get_limit_info
  if fn then return fn() end
end

local function card_limited(info, cardname, path)
  local fn = cards_limiter and cards_limiter.card_limited
  if fn then return fn(info, cardname, path) end
  return false
end

function M.setpath(path)
  ngx.ctx.modgui_cards_path = plain(path)
end

-- Invalidates this request only. Subsequent requests always read fresh UCI
-- configuration without sharing a cursor, paths or authorization decisions.
function M.reload_config()
  ngx.ctx.modgui_cards_config = nil
end

function M.get_card_from_modal(modal)
  modal = plain(modal)
  if not modal then return end
  local config = get_config()
  local card = config.modal_to_card[modal]
  if card and card_visible(config, clean_card(card)) then return card end
end

function M.get_modal_from_card(card)
  card = plain(card)
  if not card then return end
  local config = get_config()
  return config.card_to_modal[card] or config.card_to_modal[clean_card(card)]
end

function M.cards()
  local config = get_config()
  local path = ngx.ctx.modgui_cards_path
  local limit_info = get_limit_info()
  local result = {}
  if path and lfs.attributes(path, "mode") == "directory" then
    for file in lfs.dir(path) do
      if file:find("%.lp$") then
        local cardname = clean_card(file)
        if card_visible(config, cardname) and not card_limited(limit_info, cardname, path) then
          result[#result + 1] = file
        end
      end
    end
  end
  sort(result)
  return result
end

return M
