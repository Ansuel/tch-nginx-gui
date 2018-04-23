--- Interpreter for enable/disable style uci manipulations.
--
-- This module provides the interface for loading and running the
-- enable and disable commands present in a config file.
--
-- These config files are normal lua files that must return a table
-- with section definitions that define the actions to be performed
-- on those sections.
--
-- The section definitions provide the config name to use with the `config`
-- field.
--
-- A section can be identified by name, the `section` field or by some
-- values in the sections options, the `section_where` field.
--
-- If a section is not present it will be created if the `add` field is
-- present and is a table with initial values. The section will only be
-- add if enabling the feature.
--
-- finally a list of option manipulations is provided. Each option specifies
-- the option name and an `enable` and/or `disable` action. The action is a
-- table that specifies what to add or delete from the options or to set the
-- option to a specific value.
--
-- 	return {
-- 		{
-- 			config = "network",
-- 			section = "lan"
-- 			{ "ifname",
-- 					-- eth3 is removed from network.lan.ifname on enable
-- 					enable = {del = "eth3"},
-- 					-- eht3 is added to network.lan.ifname on disable
-- 					disable = {add = "eth3"}
-- 			},
-- 		},
-- 		{
-- 			config = "network",
-- 			section_where = {
-- 				-- this match the device section in the network config
-- 				--with VID==102
-- 				['.type'] = "device",
-- 				VID = "102"
-- 			},
-- 			add = {
-- 				-- if the section is not found it is created with
-- 				--these values and the ones present in section_where
-- 				name = "vlan_102"
-- 				type = "8021q"
-- 			},
-- 			{ "mtu",
-- 					enable = {set = "1538" },
-- 					disable = {set = "1500" }
-- 			}
-- 		}
-- 	}
--
-- For an example on how to use to use the module, take a look at the
-- mapping for `InternetGatewayDevice.X_000E50_Smartcontrol.`
--
-- @module uciswitch
--

local require = require
local setmetatable = setmetatable
local loadstring = loadstring
local pairs = pairs
local ipairs = ipairs
local type = type
local pcall = pcall

local tremove = table.remove
local concat = table.concat

local io = require 'io'

local ucihelper = require 'transformer.mapper.ucihelper'
local logger = require 'transformer.logger'

local M = {}

local function readConfig(config)
	local contents
	local f, errmsg = io.open(config, "r")
	if f then
		contents = f:read("*a")
		f:close()
	else
		errmsg = "open failed: "..errmsg
	end
	return contents, errmsg
end

local function loadConfig(config)
	local contents, errmsg = readConfig(config)
	if contents then
		local f, err = loadstring(contents, config)
		if f then
			local ok, cfg = pcall(f)
			if ok then
				if type(cfg)=='table' then
					return cfg
				else
					errmsg = "config map must be a table"
				end
			else
				errmsg = "load failure: "..cfg
			end
		else
			errmsg = "syntax error: "..err
		end
	end
	return nil, errmsg
end

local Switcher = {}
Switcher.__index = Switcher

local function log_error(switcher, msg)
	logger:error("[%s] %s", switcher._configname, msg)
end

local function initSwitcher(switcher, configname)
	local map, err = loadConfig(configname)
	if err then
		log_error(switcher, err)
	end
	map = map or {}
	
	local map_valid = true
	for _, sectionDef in ipairs(map) do
		if type(sectionDef)~='table' then
			-- the map is invalid, do not use it.
			map_valid = false
			log_error(switcher, "all entries in the config map must be tables")
			break
		end
		sectionDef.switcher = switcher
		
	end
	
	switcher._action_map = map_valid and map or {}
end

local function newSwitcher(configname, commitapply)
	local switcher = {
		_commitapply = commitapply,
		_configname = configname
	}
	setmetatable(switcher, Switcher)
	initSwitcher(switcher, configname)	
	return switcher 
end

--- create a Switcher object
-- @param configname the name of the file to load
-- @param commitapply The optional commitapply object to pass
-- to `ucihelper`
function M.switcher(configname, commitapply)
	if configname then
		return newSwitcher(configname, commitapply)
	end
end

local function read_section(sectionDef)
	local section
	local binding = {
		state = false,
		config = sectionDef.config,
	}
	if sectionDef.section then
		binding.sectionname = sectionDef.section
		section = ucihelper.getall_from_uci(binding)
		if not section['.name'] then
			-- section was not found but ucihelper substituted an empty table
			section = nil
		end
	elseif sectionDef.section_where then
		local where = sectionDef.section_where
		binding.sectionname = where['.type']
		ucihelper.foreach_on_uci(binding, function(s)
			for k, v in pairs(where) do
				if s[k]~=v then
					-- this section does not match the search criteria
					return
				end
			end
			-- section matches all search criteria
			section = s
			return false 
		end)
	end
	return section
end

local function set_all_options(section, values, commitapply)
	local b = {
		config = section['.config'],
		sectionname = section['.name'],
		state = false,
	}
	for option, value in pairs(values) do
		if not option:match("^%.") then --ignore options starting with .
			b.option = option
			ucihelper.set_on_uci(b, value, commitapply)
			section[option] = value
		end
	end
end

local function add_anonymous_section(sectionDef, commitapply)
	local config = sectionDef.config
	local sectiontype = sectionDef.section_where['.type']
	if sectiontype then
		local name = ucihelper.add_on_uci({config=config, sectionname=sectiontype}, commitapply)
		local section = {
			['.config'] = config,
			['.type'] = sectiontype,
			['.name'] = name,
			['.anonymous'] = true
		}
		set_all_options(section, sectionDef.section_where, commitapply)
		return section
	end
end

local function add_named_section(sectionDef, commitapply)
	local config = sectionDef.config
	local name = sectionDef.section
	local sectiontype = sectionDef.add['.type']
	if not sectiontype then
		return
	end
	ucihelper.set_on_uci({config=config, sectionname=name, state=false}, sectiontype, commitapply)
	return {
		['.config'] = config,
		['.type'] = sectiontype,
		['.name'] = name,
	}
end

local function create_section(sectionDef, commitapply)
	local addInfo = sectionDef.add
	if type(addInfo)~='table' then
		return nil, "add must be a table"
	end
	local section
	if sectionDef.section then
		section = add_named_section(sectionDef, commitapply)
	elseif sectionDef.section_where then
		section = add_anonymous_section(sectionDef, commitapply)
	end
	if section then
		set_all_options(section, addInfo, commitapply)
	end
	
	return section
end

local function load_section(sectionDef)
	local section = read_section(sectionDef)
	
	if section then
		section['.config'] = sectionDef.config
	end
	
	return section
end

local function find_in_list(list, value)
	for i=1,#list do 
		if list[i]==value then
			return i
		end
	end
end

local function apply_delete(value, to_delete)
	--value MUST be a list
	if not to_delete then
		return value
	end
	local index = find_in_list(value, to_delete)
	if index then
		tremove(value, index)
	end
	return value
end

local function apply_add(value, to_add)
	-- value MUST be a list
	if not to_add then
		return value
	end
	local index = find_in_list(value, to_add)
	if not index then
		value[#value+1] = to_add
	end
	return value
end

local function make_list(v)
	local list
	list = {}
	for entry in v:gmatch("%S+") do
		list[#list+1] = entry
	end
	return list
end

local function apply_action(section, optionName, actionDef)
	local value = section[optionName] or ''
	local set = actionDef.set
	if set then
		return set
	else
		value = make_list(value)
		value = apply_delete(value, actionDef.del)
		value = apply_add(value, actionDef.add)
	
		return concat(value, " ")
	end
end

local function update_section(section, action, sectionDef, commitapply)
	local madeChanges = false
	for _, optionDef in ipairs(sectionDef) do
		local optionName = optionDef[1]
		local actionDef = optionDef[action]
		if not (actionDef and optionName) then
			return false
		end
		if type(actionDef)~="table" then
			log_error(sectionDef.switcher, action.." must be a table")
			return false
		end
		local newValue = apply_action(section, optionName, actionDef)
		local binding = {
			config = section['.config'],
			sectionname = section['.name'],
			option = optionName,
			state = false,
		}
		ucihelper.set_on_uci(binding, newValue, commitapply)
		madeChanges = true
	end
	return madeChanges
end

local function retrieve_section(switcher, sectionDef, enable)
	local add_suppressed = false
	local section = load_section(sectionDef)
	if not section then
		-- the section is not present. Should we create it?
		if sectionDef.add then
			-- we should, but only on enable
			if enable then
				local err
				section, err = create_section(sectionDef, switcher._commitapply)
				if err then
					log_error(switcher, err)
				end
			else
				add_suppressed = true
			end
		end 
	end
	return section, add_suppressed
end

local function get_commit_list(switcher)
	local r = switcher._configs_changed
	if not r then
		r = {}
		switcher._configs_changed = r
	end
	return r
end

--- run the enable (or disable) actions
-- @param enable if `true` (the default) run the enable actions
--   otherwise run the disable actions
-- @return `true` if any uci changes were done. note that the changes are
-- **not** committed.
function Switcher:enable(enable)
	enable = (enable==nil) and true or enable
	local action = enable and "enable" or "disable"
	local action_map = self._action_map
	local configsToCommit = get_commit_list(self)
	local madeChanges = false
	for _, sectionDef in ipairs(action_map) do
		local section, add_suppressed = retrieve_section(self, sectionDef, enable)
		if section then
			if update_section(section, action, sectionDef, self._commitapply) then
				configsToCommit[section['.config']] = true
				madeChanges = true
			end
		elseif add_suppressed then
			-- an add that was not performed on disable, counts as 'changes'
			-- (to make disable succeed if the add would be the only action)
			madeChanges = true
		else
			-- section was not found and could not be created.
			-- no point in continuing we can not set the correct config anyway
			return false
		end
	end
	return madeChanges
end

local function uci_apply(switcher, action)
	local b = {}
	local configs = get_commit_list(switcher)
	for config in pairs(configs) do
		b.config = config
		action(b)
		configs[config] = nil
	end
end

--- commit any uci changed done
function Switcher:commit()
	uci_apply(self, ucihelper.commit)
end

--- revert any uci changes done
function Switcher:revert()
	uci_apply(self, ucihelper.revert)
end

local function check_item_in_value(value, item)
	local lst = make_list(value)
	return find_in_list(lst, item)~=nil
end

local function section_matches_enable(section, optionDef)
	local name = optionDef[1]
	local actionDef = optionDef.enable
	if actionDef then
		local currentValue = section[name] or ""
		if actionDef.set then
			return currentValue==actionDef.set
		elseif actionDef.add then
			return check_item_in_value(currentValue, actionDef.add)
		elseif actionDef.del then
			return not check_item_in_value(currentValue, actionDef.del)
		else
			return false
		end
	end
	return true
end

--- have all enable changes been done already.
-- @return `true` if all changes requested by the enable actions
-- are already present on uci. `false` otherwise.
function Switcher:isEnabled()
	local enabled = false
	for _, sectionDef in ipairs(self._action_map) do
		local section = load_section(sectionDef)
		if not section then
			-- section not present, not enabled
			return false
		end
		for _, optionDef in ipairs(sectionDef) do
			if not section_matches_enable(section, optionDef) then
				return false
			end
			enabled = true
		end
	end
	return enabled
end


return M