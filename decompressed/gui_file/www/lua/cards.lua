local ngx = ngx
local find, require = string.find, require
local sort = table.sort
local lfs = require("lfs")

local uci = require("uci"):cursor()

local includepath

local M = {}

local function get_rules_from_config()
	
	local rules = {}

	uci:foreach('web', 'rule', function(s)
		rules[s['.name']] = s
	end)
	
	uci:unload('web')
	
	return rules
end

local rules = get_rules_from_config()

local function get_cards_from_config()
  local config = {}
  
  uci:foreach('web', 'card', function(card)
    -- only include cards that refer to a valid modal
    -- and are not anonymous
    local rule = rules[card.modal]
    if rule and not card['.anonymous'] then
      -- set modal to the actual path of the modal
      card.modal = rule.target
      -- set correct value for hide (missing means true)
      card.hide = (card.hide~='0')
      -- remove any initial digits
      card.card = card.card:gsub("^%d+_", "")

      config[card.card] = card
    end
  end)
  uci:unload('web')
  return config
end

local config = get_cards_from_config()

local function card_visible(session, config, cardname)
  local card = config[cardname]
  if card then
    local access
    if card.modal then
      access = session:hasAccess(card.modal)
    end
    if not access and card.hide then
      return false
    end
  end
  return true
end

local cards_limiter
do
  local found
  found, cards_limiter = pcall(require, "cards_limiter")
  if not found then
    cards_limiter = nil
  end
end

local function get_limit_info()
  local fn = cards_limiter and cards_limiter.get_limit_info
  if fn then
    return fn()
  end
end

local function card_limited(info, cardname, includepath)
  local fn = cards_limiter and cards_limiter.card_limited
  if fn then
    return fn(info, cardname, includepath)
  end
  return false
end

function M.setpath(path)
  includepath = path
end

local dataReq = {
	
}

local function compareValueFromConfig(dataReq,val2)
	
	local result = nil
	
	uci:foreach('web', 'card', function(card)

		local rule = rules[card.modal]

		if rule and not card['.anonymous'] then
			if val1 == val2 then
				result = rule.target
			end
		end
	end)

	uci:unload('web')
	
	return result
end

--Returns card from modal provided or nil
function M.get_card_from_modal(ModalSearch)
	local session = ngx.ctx.session
	local result
	
	uci:foreach('web', 'card', function(card)

		local rule = rules[card.modal]

		if rule and not card['.anonymous'] then
			if rule.target == ModalSearch then
				result = card.card
			end
		end
	end)

	uci:unload('web')
	
	if result and card_visible(session, config, (result:gsub("^%d+_", ""))) then
	  return result
	end
	
	return
end

--Returns card from modal provided or nil
function M.get_modal_from_card(CardSearch)
	local result
	
	uci:foreach('web', 'card', function(card)

		local rule = rules[card.modal]

		if rule and not card['.anonymous'] then
			if card.card == CardSearch then
				result = rule.target
			end
		end
	end)

	uci:unload('web')
	return result
end

function M.cards()
  local session = ngx.ctx.session
  local limit_info = get_limit_info()
  local result = {}
  if includepath and lfs.attributes(includepath, 'mode') == 'directory' then
    for file in lfs.dir(includepath) do
      if find(file, "%.lp$") then
        local cardname = file:gsub("^%d+_", "")
        if card_visible(session, config, cardname) and not card_limited(limit_info, cardname, includepath) then
          result[#result+1] = file
        end
      end
    end
  end
  sort(result)
  return result
end

return M
