local require = require
local ipairs = ipairs
local type = type

local uciconfig = require("transformer.shared.models.uciconfig").Loader()

local M = {}

local config

local function loadOrderings(cfg)
	local orderings = {}
	for _, ordering in ipairs(cfg.ordering or {}) do
		local name = ordering.name or ordering['.name']
		local order = ordering.order
		if type(order)=='string' then
			order = {order}
		end
		orderings[name] = order
	end
	return orderings
end

local function linkspecValid(link)
	return link.type and link.name and link.linkto
end

local function loadLinks(cfg)
	local links = {}
	for _, link in ipairs(cfg.link or {}) do
		if linkspecValid(link) then
			local typed = links[link.type] or { byname={}, bytarget={}}
			typed.byname[link.name] = link.linkto
			local tgt = typed.bytarget[link.linkto] or {}
			tgt[#tgt+1] = link.name
			typed.bytarget[link.linkto] = tgt
			links[link.type] = typed
		end
	end
	return links
end

local function updateConfig()
	if not config or uciconfig:config_changed() then
		local cfg = uciconfig:load("dmordering")
		config = {
			orderings = loadOrderings(cfg),
			links = loadLinks(cfg),
		}
	end
end

local function sortKeys(keys, order)
	local result = {}
	local all = {}
	for _, key in ipairs(keys) do
		all[key] = true
	end
	-- add the ones in sorting in order
	for _, name in ipairs(order) do
		if all[name] then
			result[#result+1] = name
			all[name] = false
		end
	end
	-- add the others in the original order
	for _, name in ipairs(keys) do
		if all[name] then
			result[#result+1] = name
		end
	end
	return result
end

local function getOrder(ordering)
	updateConfig()
	return config.orderings[ordering]
end

M.getOrder = getOrder

function M.sort(keys, ordering)
	local order = getOrder(ordering)
	if order then
		keys = sortKeys(keys, order)
	end
	return keys
end

function M.linked(linkType, linkName)
	updateConfig()
	local typedLinks = config.links[linkType]
	if typedLinks then
		return typedLinks.byname[linkName]
	end
end

function M.linksTo(linkType, name)
	updateConfig()
	local typed = config.links[linkType] or {bytarget={}}
	local tgt = typed.bytarget[name] or {}
	local links = {name} -- name itself is always the first
	if tgt then
		for _, n in ipairs(tgt) do
			links[#links+1] = n
		end
	end
	return links
end

return M
