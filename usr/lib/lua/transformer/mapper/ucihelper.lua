--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

--- The UCI helper helps you communicate with uci
-- @module transformer.mapper.ucihelper
local M = {}

local uci = require("uci") --doc.ucidoc#doc.ucidoc
local lfs = require("lfs")
local crypto = require("tch.crypto")
local logger = require("transformer.logger")

local next, error, type, pairs, ipairs = next, error, type, pairs, ipairs
local open = io.open
local match = string.match
local tonumber = tonumber

--- A representation of the UCI target on which an action needs to be performed.
-- The required fields differ depending on which action is being performed.
-- @type binding
-- @field #string config A UCI config.
-- @field #string sectionname A UCI section.
-- @field #string option A UCI option.
-- @field #string default A possible default return value for an action.
-- @field #string state If the UCI state dir needs to be loaded or not.
-- @field #string extended If the action wishes to use extended syntax or not.

--- Variable to hold the default value for the search path for config file changes.
-- We set this variable to avoid clashes with uci cli, which uses "/tmp/.uci"
-- as default.
local save_dir = "/tmp/.transformer/" --#string
--- The global UCI_CONFIG can be set when running tests. If set we want to
-- use it. Otherwise we set it to the default UCI conf dir.
local conf_dir = UCI_CONFIG or "/etc/config/"
if conf_dir:sub(#conf_dir)~='/' then
  conf_dir = conf_dir .. "/"
end
local state_dir = "/var/state/"
--- Although we use a different save dir, the delta files in the default UCI save dir are
-- apparently still loaded.
local uci_save_dir = "/tmp/.uci/"

--- Top level entry point to uci (instantiates a uci context instance).
local cursor = uci.cursor(conf_dir, save_dir) --doc.ucidoc#cursor
--- Create a separate cursor for reading state. No sets are allowed on this cursor.
local state_cursor = uci.cursor(conf_dir, save_dir) --doc.ucidoc#cursor
state_cursor:add_delta(state_dir)
--- Create a separate cursor for looping to avoid loop corruption. No sets are allowed on this cursor.
local foreach_cursor = uci.cursor(conf_dir, save_dir)

--- Variable to hold the value for the search path for config file changes for the key cursor.
local save_dir_keys = "/tmp/.transformerkeys" --#string
--- Create a separate cursor for key generation. This will prevent
-- unwanted commits when generating keys on uci. This will also
-- bypass the commitapply context, which we don't want to trigger
-- on key generation.
local keycursor = uci.cursor(conf_dir, save_dir_keys) --doc.ucidoc#cursor

-- For each config we keep track of which cursors are up to date or need to be reloaded. We also
-- keep for each config the timestamp of the last modification of all relevant files.
-- We don't track save_dir_path, since it can only be modified through an internal action. The
-- keycursor does not need this tracking, since all configs should be unloaded on commit_keys
-- or revert_keys.
-- loaded_configs = {
--    cwmpd = {
--      conf_dir_path
--      uci_save_dir_path
--      state_dir_path
--      cursor
--      state_cursor
--      foreach_cursor
--    },
--    system = {
--      ..
--    }
-- }
local loaded_configs = {}

-- When a cursor is used in a foreach loop, we track it here so they can be blocked from being reloaded.
local cursors_in_foreach = {}

-- Debug function to retrieve a name for a given cursor.
local function print_cursor_name(cursor_to_print)
  if cursor_to_print == cursor then
    return "cursor"
  elseif cursor_to_print == state_cursor then
    return "state_cursor"
  elseif cursor_to_print == foreach_cursor then
    return "foreach_cursor"
  else
    return "unknown_cursor"
  end
end

--- Helper function to check if a given cursor needs to be reloaded for the given config.
-- A cursor does not have to be reloaded if one of the following conditions apply:
--   - It is actively being used in a foreach loop
--   - We already checked in the current transaction that the currently loaded config is up to date.
--   - The corresponding configuration files have not been altered since the last time we've loaded the cursor for the given config.
--     (checked configuration files: /etc/config/, /var/state/ and /tmp/.uci/)
-- @param doc.ucidoc#cursor cursor_to_check The UCI cursor we need to verify.
-- @param #string config The config that has to be checked.
-- @return #boolean True if the cursor needs to be reloaded, false otherwise.
local function check_cursor_config_needs_update(cursor_to_check, config)
  if cursors_in_foreach[cursor_to_check] then
    return false -- Never update a cursor that is being used in a foreach loop
  end
  local cached_config = loaded_configs[config]
  if not cached_config or not cached_config.cursor_health[cursor_to_check] then
    return true
  end
  if cached_config.checked then
    -- The config paths have been checked for this config since start was last called
    -- and the cursor health is good.
    return false
  end
  local config_paths = cached_config.paths
  for path, path_info in pairs(config_paths) do
    if not path_info.verifier(path, path_info.value) then
      return true
    end
  end
  cached_config.checked = true
  return false
end

--- Retrieve the inode of the given path.
-- @param #string path The path of the file we need to retrieve the inode from.
-- @return #number The inode of the given path.
-- @error nil, #string
local function retrieve_inode(path)
  return lfs.attributes(path, "ino")
end

--- Check if the inode of the given path matches the given inode.
-- @param #string path The path of the file we need to retrieve the inode from.
-- @param #number previous_ino The inode to which we need to compare.
-- @return #boolean True if the inode of the given path is equal to the given inode, false otherwise.
local function check_inode(path, previous_ino)
  return retrieve_inode(path) == previous_ino
end

--- Retrieve the md5 checksum of the given path.
-- @param #string path The path of the file we need to calculate the md5 checksum for.
-- @return #string The md5 checksum of the given path.
-- @error nil, #string
local function retrieve_md5(path)
  local fd = open(path, "r")
  if fd then
    local cont = fd:read("*a")
    fd:close()
    return crypto.md5(cont or "")  -- Equate content error to empty content (f.e. when path is a directory)
  end
end

--- Check if the md5 checksum of the given path matches the given md5 checksum.
-- @param #string path The path of the file we need to calculate the md5 checksum for.
-- @param #number previous_md5 The md5 checksum to which we need to compare.
-- @return #boolean True if the md5 checksum of the given path is equal to the given md5 checksum, false otherwise.
local function check_md5(path, previous_md5)
  return retrieve_md5(path) == previous_md5
end

--- Retrieve the modification time of the given path.
-- @param #string path The path of the file for which we need to retrieve the modification time.
-- @return #number The modification time of the given path.
-- @error nil, #string
local function retrieve_modification(path)
  return lfs.attributes(path, "modification")
end

--- Check if the modification time of the given path matches the given modification time.
-- @param #string path The path of the file for which we need to retrieve the modification time.
-- @param #number previous_mod The modification time to which we need to compare.
-- @return #boolean True if the modification time of the given path is equal to the given modification time, false otherwise.
local function check_modification(path, previous_mod)
  return retrieve_modification(path) == previous_mod
end

--- Check if the inode and the modification time of the given path matches the given inode and modification time.
-- @param #string path The path of the file for which we need to retrieve the inode and modification time.
-- @param #table previous_values An array with the values to which we need to compare. The first entry should contain
--                               the inode and the second entry should contain the modification time.
-- @return #boolean True if both the inode and the modification time of the given path are equal to the given values, false otherwise.
local function check_inode_and_modification(path, previous_values)
  return check_inode(path, previous_values[1]) and check_modification(path, previous_values[2])
end

--- Retrieve the inode and the modification time of the given path.
-- @param #string path The path of the file for which we need to retrieve the inode and the modification time.
-- @return #table An array with as first entry the inode of the given path and as second entry the modification time of the given path.
-- @error nil, #string
local function retrieve_inode_and_modification(path)
  return {retrieve_inode(path), retrieve_modification(path)}
end

--- Helper function to invalidate the cursor health for a given config file.
-- @param doc.ucidoc#cursor cursor_to_skip A cursor we can skip from being invalidated.
-- @param #string config The config file for which we are invalidating the cursor healths.
-- @param #boolean invalidate_checked Optional parameter to reset the checked flag for the tracked files.
local function invalidate_cursor_health(cursor_to_skip, config, invalidate_checked)
  local cached_config = loaded_configs[config]
  if cached_config then
    for curs in pairs(cached_config.cursor_health) do
      if curs ~= cursor_to_skip then
        cached_config.cursor_health[curs] = false
      end
    end
    if invalidate_checked then
      cached_config.checked = false
    end
  end
end

--- Helper function to reload a given config on the given cursor.
-- The config will first be unloaded and then loaded in the given cursor. We will
-- then update the internal bookkeeping of our cursors for this configuration file.
-- @param doc.ucidoc#cursor cursor_to_reload The UCI cursor we need to reload.
-- @param #string config The config that has to be reloaded.
-- @return #boolean True if the cursor was reloaded, false otherwise.
local function reload_cursor(cursor_to_reload, config)
  cursor_to_reload:unload(config) -- The API documentation of this function is wrong, it does not return true on success.
  if not cursor_to_reload:load(config) then
    return false
  end
  local cached_config = loaded_configs[config]
  if not cached_config then
    -- First time this config is loaded for any cursor.
    local conf_dir_path = conf_dir..config
    local uci_save_dir_path = uci_save_dir..config
    local state_dir_path = state_dir..config
    cached_config = {
      paths = {
        [conf_dir_path] = {
          verifier = check_inode_and_modification,
          updater = retrieve_inode_and_modification,
        },
        [uci_save_dir_path] = {
          verifier = check_md5,
          updater = retrieve_md5,
        },
        [state_dir_path] = {
          verifier = check_md5,
          updater = retrieve_md5,
        },
      },
      checked = false,
      cursor_health = { -- false means reload is required, true means healthy
        [cursor] = false,
        [state_cursor] = false,
        [foreach_cursor] = false,
      },
    }
    loaded_configs[config] = cached_config
  end
  if not cached_config.checked then
    -- We're about to update the cache info for the first time in a transaction, invalidate
    -- all other cursor health, since we will no longer know their loaded state.
    invalidate_cursor_health(cursor_to_reload, config)
    for path, path_info in pairs(cached_config.paths) do
      path_info.value = path_info.updater(path)
    end
    -- The info in the cache is checked in this transaction, mark accordingly.
    cached_config.checked = true
  end
  cached_config.cursor_health[cursor_to_reload] = true
  return true
end

local function save_cursor(cursor_to_save, config, invalidate_all)
  local result = cursor_to_save:save(config)
  if not invalidate_all then
    invalidate_cursor_health(cursor_to_save, config)
  else
    invalidate_cursor_health(nil, config, true)
  end
  return result
end

local function commit_cursor(cursor_to_commit, config)
  local result = cursor_to_commit:commit(config)
  invalidate_cursor_health(cursor_to_commit, config, true)
  return result
end

--- Debug function to trace information of a given binding.
-- @param binding The binding to be logged
-- @param fn_name The function name to use in the logging.
-- @param cursor_to_trace Optional argument to trace on which cursor the function is happening.
local function trace_binding(binding, fn_name, cursor_to_trace)
  local started = false
  local name = fn_name or "unknown"
  local log_msg = name .. "["
  local function add_element(name, value)
    if not value then return end
    if started then log_msg = log_msg .. "/" end
    log_msg = log_msg..name.."="..tostring(value)
    started = true
  end
  add_element("cfg", binding.config)
  add_element("sn", binding.sectionname)
  add_element("op", binding.option)
  add_element("def", binding.default)
  add_element("state", binding.state)
  add_element("ext", binding.extended)
  log_msg = log_msg .. "]"
  if cursor_to_trace then
    log_msg = log_msg .. "[" .. print_cursor_name(cursor_to_trace) .. "]"
  end
  logger:debug(log_msg)
end

--- Function that refreshes the given cursor.
-- It will first check if the given cursor needs to be refreshed and only refresh when needed.
-- @param #binding binding The binding representing the location of the config in uci.
--                 This binding should contain at least 1 named table entry: config.
-- @param doc.ucidoc#cursor cursor The cursor we need to refresh.
-- @return #boolean Status of the refresh. If false, the cursor failed to refresh.
local function refresh_cursor(binding, cursor)
  --trace_binding(binding, "refresh_cursor", cursor)
  local config = binding.config
  if check_cursor_config_needs_update(cursor, config) then
    return reload_cursor(cursor, config)
  end
  return true
end

--- Function that commits the generated keys for the given config.
-- @param #binding binding The binding representing the location of the config in UCI.
--                 This binding should contain at least 1 named table entry: config
local function commit_keys(binding)
  local rc = keycursor:commit(binding.config)
  invalidate_cursor_health(nil, binding.config, true)
  keycursor:unload(binding.config)
  return rc
end

M.commit_keys = commit_keys

--- Function that reverts the generated keys for the given config.
-- @param #binding binding The binding representing the location of the config in UCI.
--                 This binding should contain at least 1 named table entry: config
local function revert_keys(binding)
  -- since all changes are done purely in memory we only
  -- have to unload the cursor to throw them away
  keycursor:unload(binding.config)
end

M.revert_keys = revert_keys

--- Function that looks into the binding to retrieve the section type of the object (if known)
-- @param #binding binding The binding representing the local of the config in UCI
-- @param #string value The value being set if relevant for the current uci call
-- @return #string
local function get_section_type(binding, value)
  if binding.sectiontype then
    return binding.sectiontype
  end

  if not binding.option and value then
    -- Type is the value passed
    -- i.e. uci set network.wan = interface
    -- valid for both extended and "non" extended case
    return value
  end

  if binding.extended and binding.sectionname then
    -- Extract the type from an anonymous indexed path (@redirect[0] for instance)
    -- i.e. uci set config.@type[3].option = value
    -- otherwise, cannot say about type (i.e. uci set network.wan.ifname = eth4)
    local st = match(binding.sectionname, "@([^%[]+)%[%-?%d+]")
    if st then
      return st
    end
  end

  return '?' -- default value if unknown
end

--- Function that commits the changes made to the given config
-- @param #binding binding The binding representing the location of the parameter in uci.
--                 This binding should contain at least 1 named table entry: config
function M.commit(binding)
  --trace_binding(binding, "commit")
  return commit_cursor(cursor, binding.config)
end

--- Function which gets a parameter from uci
-- This function will try to get a parameter from uci using the
-- information available in the given binding.
-- @param #binding binding The binding representing the location of the parameter in uci.
--                 This binding should contain at least 2 named table entries:
--                 config (string), sectionname (string), option (string, optional),
--                 default (string, optional), state (boolean, optional), extended (boolean, optional)
--                 When option is undefined, the section type is retrieved.
--                 When extended is defined, extended syntax lookup is performed.
-- @return #string In order of return preference: The value in UCI, the default defined
--                 in the given binding or the empty string.
function M.get_from_uci(binding)
  --trace_binding(binding, "get_from_uci")
  local config = binding.config
  local section = binding.sectionname
  local option = binding.option
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No section name could be found in the given binding", 2)
  end
  local cursor = binding.state ~= false and state_cursor or cursor --doc.ucidoc#cursor
  local result = refresh_cursor(binding, cursor)
  if result then
    if binding.extended then
      if option then
        result = cursor:get(config .. "." .. section .. "." .. option)
      else
        result = cursor:get(config .. "." .. section)
      end
    else
      if option then
        result = cursor:get(config, section, option)
      else
        result = cursor:get(config, section)
      end
    end
  end
  if result then
    return result
  end
  if binding.default then
    return binding.default
  end
  -- We assume the value is an empty string in this case.
  return ''
end

--- Function which gets a parameter from uci
-- This function will try to get a parameter from uci using the
-- information available in the given binding.
-- @param #binding binding The binding representing the location of the parameter in uci.
--                 This binding should contain at least 1 named table entries:
--                 config (string), sectionname (string, optional), extended (boolean, optional)
-- @return #table
function M.getall_from_uci(binding)
  --trace_binding(binding, "getall_from_uci")
  local config = binding.config
  local section = binding.sectionname
  if not config then
    error("No config could be found in the given binding", 2)
  end
  local cursor = binding.state ~= false and state_cursor or cursor
  local result = refresh_cursor(binding, cursor)
  if result then
    if section then
      if binding.extended then
        result = cursor:get_all(config .. "." .. section)
      else
        result = cursor:get_all(config, section)
      end
    else
      result = cursor:get_all(config)
    end
  end
  if result then
    return result
  end
  -- We assume the value is an empty string in this case.
  return {}
end

--- Function which sets a parameter on uci
-- This function will try to set a parameter on uci using the
-- information available in the given binding.
-- @param #binding binding The binding representing the location of the parameter in uci.
--                This binding should contain at least 2 named table entries:
--                config (string), sectionname (string), option (string, optional),
--                extended (boolean, optional)
--                When option is undefined, the section type is set.
--                When extended is defined, extended syntax lookup is performed.
-- @param #string value The value that needs to be set
-- @param commitapply The Commit & Apply context (optional)
-- WARNING: This function will not commit!
function M.set_on_uci(binding, value, commitapply)
  --trace_binding(binding, "set_on_uci")
  local config = binding.config
  local section = binding.sectionname
  local option = binding.option
  local stype = get_section_type(binding, value)
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No section name could be found in the given binding", 2)
  end
  if not value then
    error("No value given to be set on UCI", 2)
  end
  local result = refresh_cursor(binding, cursor)
  local errmsg
  if result then
    local extended = binding.extended
    if extended and (type(value)=='table') then
      -- extended syntax and a table value do not go well together
      -- translate to simple section name and proceed with non-extended syntax
      extended = false
      -- split in section type and index
      local sectype, idx = section:match('^@([^[]+)%[%s*(%d+)%s*%]')
      if sectype then
        -- extended syntax actually used
        -- loop over all section of the given type until we reach the given
        -- index
        idx = tonumber(idx)
        local i = 0
        local name
        cursor:foreach(config, sectype, function(s)
          if i==idx then
            name = s['.name']
            return false -- break
          end
          i = i + 1
        end)
        if name then
          extended = false
          section = name
        else
          -- the section does not exist
          return
        end
      end
    end
    if extended then
      if option then
        result, errmsg = cursor:set(config .. "." .. section .. "." .. option .. "=" .. value)
      else
        result, errmsg = cursor:set(config .. "." .. section                  .. "=" .. value)
      end
    else
      if option then
        result, errmsg = cursor:set(config, section, option, value)
      else
        result, errmsg = cursor:set(config, section,         value)
      end
    end
  end
  if result then
    -- We save here so the set is persisted to file, although it is not
    -- yet committed! We persist to file, so if we lose or reload our cursor for
    -- some reason, the set won't be lost.
    -- We always invalidate the cache! Either we performed an add and this leads to inconsistencies
    -- between our internal cursors or we performed a set which hits a UCI bug that leads to a corrupt
    -- cursor. (UCI bug: Setting an option that did not exist to empty string should do nothing, but on
    -- a save action will actually create a deletion entry in the overlay. Any set action on the cursor that
    -- performed the save will then fail. Reloading the cursor is a workaround for this bug)
    result = save_cursor(cursor, config, true)
  else
    logger:error("Set failed on %s.%s.%s = %s: %s", tostring(config), tostring(section), tostring(option), tostring(value), tostring(errmsg))
  end
  if result and commitapply then
    if option then
      commitapply:newset(config .. "." .. stype .. '.' .. section .. "." .. option)
    else
      commitapply:newadd(config .. "." .. stype .. '.' .. section)
    end
  end
end

--- Function which adds an object on uci.
-- @param #binding binding The binding representing the object type that needs to be added
--                This binding should contain at least 2 named table entries:
--                config (string), sectionname (string)
--                In this case the section name actually represents the section type.
-- @param commitapply The Commit & Apply context (optional)
-- @return #string The name of the newly created object
-- @return #nil, #string Traditional nil and error message
-- WARNING: This function will not commit!
function M.add_on_uci(binding, commitapply)
  --trace_binding(binding, "add_on_uci")
  local config = binding.config
  local section = binding.sectionname
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No section type could be found in the given binding", 2)
  end
  local result = refresh_cursor(binding, cursor)
  local errmsg
  if result then
    result, errmsg = cursor:add(config, section)
  end
  local save_result
  if result then
    -- We save here so the add is persisted to file, although it is not
    -- yet committed! We persist to file, so if we lose or reload our cursor for
    -- some reason, the add won't be lost.
    save_result = save_cursor(cursor, config, true)
  end
  if result and save_result and commitapply then
    commitapply:newadd(config .. "." .. section .. "." .. result)
  end
  return result, errmsg
end

--- Function to delete an object on uci
-- @param #binding binding The binding representing the instance that needs to be deleted
--                This binding should contain at least 2 named table entries:
--                config (string), sectionname (string), option (string, optional),
--                extended (boolean, optional)
--                When option is undefined, the entire section is deleted.
--                When extended is defined, extended syntax lookup is performed.
-- @param commitapply The Commit & Apply context (optional)
-- WARNING: This function will not commit!
function M.delete_on_uci(binding, commitapply)
  --trace_binding(binding, "delete_on_uci")
  local config = binding.config
  local section = binding.sectionname
  local option = binding.option
  local stype = get_section_type(binding)
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No section name could be found in the given binding", 2)
  end
  local result = refresh_cursor(binding, cursor)
  if result then
    if binding.extended then
      if option then
        result = cursor:delete(config .. "." .. section .. "." .. option)
      else
        result = cursor:delete(config .. "." .. section)
      end
    else
      if option then
        result = cursor:delete(config, section, option)
      else
        result = cursor:delete(config, section)
      end
    end
  end
  local save_result
  if result then
    -- We save here so the delete is persisted to file, although it is not
    -- yet committed! We persist to file, so if we lose or reload our cursor for
    -- some reason, the delete won't be lost.
    save_result = save_cursor(cursor, config, true)
  end
  if result and save_result and commitapply then
    if option then
      commitapply:newdelete(config .. "." .. stype .. '.' .. section .. "." .. option)
    else
      commitapply:newdelete(config .. "." .. stype .. '.' .. section)
    end
  end
end

--- Function to change an item index inside the uci datamodel
-- @param #binding binding The binding representing the instance that needs to be deleted
--                This binding should contain at least 2 named table entries:
--                config (string), sectionname (string), extended (boolean, optional)
--                When extended is defined, extended syntax lookup is performed.
-- @param #number index   The new index to use for the item
-- @param commitapply The Commit & Apply context (optional)
-- WARNING: This function will not commit!
function M.reorder_on_uci(binding, index, commitapply)
  --trace_binding(binding, "reorder_on_uci")
  local config = binding.config
  local section = binding.sectionname
  local stype = get_section_type(binding)
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No section name could be found in the given binding", 2)
  end
  if not (type(index) == "number") then
    error("Index must be a number", 2)
  end
  local result = refresh_cursor(binding, cursor)
  if result then
    if binding.extended then
      result = cursor:reorder(config .. "." .. section .. "=" .. index)
    else
      result = cursor:reorder(config, section, index)
    end
  end
  local save_result
  if result then
    -- We save here so the reorder is persisted to file, although it is not
    -- yet committed! We persist to file, so if we lose or reload our cursor for
    -- some reason, the reorder won't be lost.
    save_result = save_cursor(cursor, config, true)
  end
  if result and save_result and commitapply then
    commitapply:newreorder(config .. "." .. stype .. '.' .. section)
  end
end

--- Function which loops over all instances of the given type
-- in the given config in uci and executes the given function.
-- @param #binding binding The binding representing the config and the type over which
--                needs to be iterated.
--                This binding should contain at least 1 named table entries:
--                config, sectionname(optional), state(optional)
--                When sectionname is nil, all sections will be iterated regardless of type.
-- @param func    The function that needs to be executed for each instance.
function M.foreach_on_uci(binding,func)
  local config = binding.config
  local section = binding.sectionname
  if not config then
    error("No config could be found in the given binding", 2)
  end
  -- Create a separate cursor for the loop. Another ucihelper function can be
  -- passed as second argument and will (un)load the cursor.
  local cursor = uci.cursor(UCI_CONFIG, save_dir)
  if binding.state == nil or binding.state then
    cursor:add_delta("/var/state")
  end
  local result = refresh_cursor(binding, cursor)
  if result then
    if section then
      result = cursor:foreach(config, section, func)
    else
      result = cursor:foreach(config, func)
    end
  end
  cursor:unload(config)
  return result
end

--- Function which reverts the state of uci
-- @param #binding binding The binding representing the config that needs to be reverted
--                This binding should contain at least 1 named table entry:
--                config (string)
function M.revert(binding)
  --trace_binding(binding, "revert")
  local config = binding.config
  if not config then
    error("No config could be found in the given binding", 2)
  end
  local result = cursor:revert(config)
  if result then
    -- Since we don't know what is being reverted, invalidate all caches.
    result = save_cursor(cursor, config, true)
  end
  return result
end

--- Generate a unique key
-- This function will generate a 16byte key by reading data from dev/urandom
local key = ("%02X"):rep(16)
local fd = assert(open("/dev/urandom", "r"))
function M.generate_key()
  local bytes = fd:read(16)
  return key:format(bytes:byte(1,16))
end

--- Function which stores a unique key for the given section in the
-- given config in UCI. If no key is given it generates one.
-- @param #binding binding The binding representing the config and the section for which
--                a unique key needs to be generated.
--                This binding should contain at least 2 named table entries:
--                config (string), sectionname (string)
-- @param #string key The key to store in UCI. Optionally; if not provide a key will
--                    be generated.
-- NOTE: This function works on a separate cursor and needs to be followed by either
-- commit_keys or revert_keys.
function M.generate_key_on_uci(binding, key)
  --trace_binding(binding, "generate_key_on_uci")
  local config = binding.config
  local section = binding.sectionname
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No sectionname could be found in the given binding", 2)
  end
  key = key or M.generate_key()
  -- For performance reasons we do not save; all changes are kept
  -- in memory. The assumption is that several keys are generated and
  -- then commit_keys()/revert_keys() is called immediately afterwards.
  -- Those functions will make the changes persistent or throw them away.
  local result = keycursor:set(config, section, "_key", key)
  if not result then
    error("Cannot set _key field in given config/section", 2)
  end
  return key
end

--- Function that should be called when a new transaction is started.
-- This function will wipe the state of the cached entries, forcing the cache
-- to be validated before being used again. Once the cache is validated, it will
-- not be checked again until the next time the state is cleared.
function M.start()
  for config, config_status in pairs(loaded_configs) do
    config_status.checked = false
  end
  cursors_in_foreach = {}
end

-- Preload the UCI config during startup. We only do it for the state_cursor,
-- since preloading the other cursors costs more then 1 MB of memory and only has
-- a small performance gain (0.3 seconds on the entire UCI datamodel)
for _, file in ipairs(state_cursor:list_configs() or {}) do
  reload_cursor(state_cursor, file)
end

return M
