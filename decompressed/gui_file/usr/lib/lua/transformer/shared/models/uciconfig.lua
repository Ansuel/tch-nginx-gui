-- Copyright © 2015 Technicolor

---
-- A convenience interface to UCI.
-- 
-- @module uciconfig
-- 
-- @usage
-- local uciconfig = require("uciconfig").Loader()
-- local cfg = uciconfig.load("network")
-- 
local require = require
local setmetatable = setmetatable
local pairs = pairs

local lfs = require "lfs"
local ucihelper = require "transformer.mapper.ucihelper"

--- A config loader class.
-- @type Loader
-- 
-- loads uci config and keeps track of which configs
-- were loaded
local Loader = {}
Loader.__index = Loader

local function last_config_mod_time(cfg)
	return lfs.attributes("/etc/config/"..cfg, "modification")
end

--- Load a uci config.
-- The named uci config is loaded and its filesystem
-- modification time is noted to track changes to the file.
-- @param configname the name of the config
-- @return a config table, which may be empty if the config does not exist.
function Loader:load(configname)
	self._configs[configname] = last_config_mod_time(configname)
	local config = {
		_all = {}
	}
	ucihelper.foreach_on_uci({config=configname, state=false}, function(s)
		local sectype = s['.type']
		local secname = s['.name']
		local placeholder = sectype:match("^([^_]+)_placeholder")
		if placeholder then
			sectype = placeholder
			s['.placeholder'] = true
		end
		local tplist = config[sectype]
		if not tplist then
			tplist = {}
			config[sectype] = tplist
		end
		local all = config._all
		tplist[#tplist+1] = s
		tplist[secname] = s
		all[#all+1] = s
		all[secname] =s
	end)
	return config
end

--- Has any loaded config changed.
-- 
-- Did any of the previously loaded configs change,
-- based on their filesystem modification time.
-- -- 
-- The modification time of each loaded config is checked
-- against the modifiaction time of the last time the config
-- was loaded using `load`
-- 
-- @return true if any loaded config has changed 
function Loader:config_changed()
	local changed = false
	for cfg, mod in pairs(self._configs) do
		if mod< last_config_mod_time(cfg) then
			changed = true
			break
		end
	end
	return changed
end


local M = {}

--- Create a config loader
-- @within uciconfig
function M.Loader()
	return setmetatable({
		_configs = {}
	}, Loader)
end

return M