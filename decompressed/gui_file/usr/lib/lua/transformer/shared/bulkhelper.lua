local require = require
local setmetatable = setmetatable
local ipairs = ipairs
local tostring = tostring
local format = string.format
local match = string.match
local insert = table.insert
local remove = table.remove
local sort = table.sort

local uci = require('transformer.mapper.ucihelper')
local duplicator = require('transformer.mapper.multiroot').duplicate

local mt = { __index = function() return "" end }
local M = {}
M.entries = {}

local ProfileMap = {}
ProfileMap.__index = ProfileMap

-- iterate over all uci interfaces calling a function for each
-- @param f [function] the function to call
local uci_profiles = { config="bulkdata", sectionname="profile"}
local function foreach_profile(f)
  return uci.foreach_on_uci(uci_profiles, f)
end

local boolean_table = setmetatable({
  ['0'] = 'false',
  ['1'] = 'true',
  ['true'] = '1',
  ['false'] = '0'
}, mt)

-- convert different format boolean types and server for configuration and mapping implementation
-- @param value [string] the value to be converted
local function convert_boolean(value)
  return boolean_table[value]
end
M.convert_boolean = convert_boolean

-- sorted by number
local function nsort(a,b)
  local na = tonumber(match(a, ".*_(%d+)$"))
  local nb = tonumber(match(b, ".*_(%d+)$"))
  return na < nb
end

--- retrieve keys for bulk data profile map for transformer
-- @param parentkey [string] the key of the parent instance.
-- @returns a list (table) of keys to pass to transformer
function ProfileMap:getProfileKeys(parentkey)
  self.keys = {}
  M.entries = {}
  foreach_profile(function(s)
    self.keys[#self.keys+1] = s['.name']
    M.entries[s['.name']] = s
  end)
  sort(self.keys, nsort)
  return self.keys
end

--- retrieve keys for parament maps for transformer
-- @param id [string] the identification for parameters
-- @param parentkey [string] the key of the parent instance.
-- @returns a list (table) of keys to pass to transformer
function ProfileMap:getParamKeys(id, parentkey)
  self.keys = {}
  if type(M.entries[parentkey][id]) == "table" then
    for i,_ in ipairs(M.entries[parentkey][id]) do
      local key = format("%s|%s|%d", parentkey, id,  #self.keys+1)
      self.keys[#self.keys+1] = key
    end
  end
  return self.keys
end

--- retrieve object for from saved objects in entries
-- @param key [string] the key of the current instance and key is also the index of objects
-- @returns an object (table) of saved all the profile items, if the key is invalid, return one empty table
-- @returns an index identify (string) served for the list of parameters
local function getObject(key)
  local keyid, indexid = key:match("(.*)|.*|(.*)")
  if keyid and indexid then
    indexid = tonumber(indexid)
  else
    keyid = key
  end
  return M.entries[keyid] or {}, indexid
end


--- get all parameter's values for the given mapping
-- @param mapping [table] a mapping
-- @param key [string] the key of the current instance
-- @returns a list (table) of parameter values
function M.getall(mapping, key)
  local data = {}
  local object, indexid = getObject(key)
  local map = mapping._profile.map.get
  local parameters = mapping.objectType.parameters
  for p in pairs(parameters) do
    if (map[p]) then
      if type(map[p]) == "function" then
        data[p] = map[p](object)
      elseif type(map[p]) == "table" then
        -- for parameters or http_uri
        if not data.Name or not data.Reference then
          local ref, name = match((object[map[p][1]] and object[map[p][1]][indexid]) or "", "(.*)|(.*)")
          data.Name = name or ""
          data.Reference = ref or ""
        end
      else
        data[p] = object[map[p]]
      end
    end
    data[p] = data[p] or parameters[p].default or ""
  end
  return data
end

--- get one parameter's value for the given mapping and given parameter name
-- @param mapping [table] a mapping
-- @param param [string] the parameter name to be gotten
-- @param key [string] the key of the current instance
-- @returns a value (string) of parameter
function M.get(mapping, param, key)
  local object, indexid = getObject(key)
  local map = mapping._profile.map.get
  local parameters = mapping.objectType.parameters

  if (map[param]) then
    if type(map[param]) == "function" then
      return map[param](object)
    elseif type(map[param]) == "table" then
      -- for parameters or http_uri
      local ref, name = match((object[map[param][1]] and object[map[param][1]][indexid]) or "", "(.*)|(.*)")
      if param == "Name" then
        return name
      else
        return ref
      end
    else
      return object[map[param]] or parameters[param].default or ""
    end
  end
end

--- set one parameter's value for the given mapping and given parameter name
-- @param mapping [table] a mapping
-- @param param [string] the parameter name to be set
-- @param value [string] the parameter value to be set
-- @param key [string] the key of the current instance
-- @returns true (boolean) if setting successful, or nil and error message (string) if failed
function M.set(mapping, param, value, key)
  local object, indexid = getObject(key)
  local map = mapping._profile.map.set
  local commitapply = mapping._profile.commitapply
  local transactions = mapping._profile.transactions
  local binding = {config = "bulkdata"}

  binding.sectionname = object['.name']
  if map[param] then
    if type(map[param]) == "function" then
      local ok, msg = map[param](binding, value)
      if not ok then
        return nil, msg
      end
    elseif type(map[param]) == "string" then
      binding.option = map[param]
      uci.set_on_uci(binding, value, commitapply)
    elseif type(map[param]) == "table" then
      -- for parameters or http_uri
      binding.option = map[param][1]
      uci.delete_on_uci(binding, commitapply)
      local ref, name = match(object[binding.option][indexid] or "", "(.*)|(.*)")
      if param == "Name" then
        name = value
      else
        ref = value
      end
      object[binding.option][indexid] = format("%s|%s", ref or "", name or "")
      uci.set_on_uci(binding, object[binding.option], commitapply)
    end
    transactions[binding.config] = true
    return true
  else
    return nil, "Invalid or not supported parameter"
  end
end

--- generate a profile name according to the 1..N sequence first found first used
-- @param max [int] the max number of profiles allowed to be existed
-- @returns profile name (string), the format is "profile_N"
local function get_profile_name(max)
  local all = {}
  local id
  foreach_profile(function(s)
    id = tonumber(s['.name']:match("(%d+)$"))
    all[id] = id
  end)

  return #all < max and format("profile_%d", #all+1) or nil
end

--- add a new profile for the given mapping
-- @param mapping [table] a mapping
-- @param parentkey [string] the key of the parent instance.
-- @returns new profile key (string)
function M.add_profile(mapping, parentkey)
  local binding = {config = "bulkdata"}
  local commitapply = mapping._profile.commitapply
  local transactions = mapping._profile.transactions

  binding.sectionname = "global"
  binding.option = "max_num_profiles"
  local max = uci.get_from_uci(binding)

  local name = get_profile_name(tonumber(max))
  if name == nil then
    return nil, "The profile's instance number has reached the maximize and can't add any new!"
  end
  binding.sectionname = name
  binding.option = nil
  uci.set_on_uci(binding, "profile", commitapply)
  transactions[binding.config] = true
  return binding.sectionname
end

--- delete an existed profile for the given mapping
-- @param mapping [table] a mapping
-- @param key [string] the key of the current instance to be deleted
-- @param parentkey [string] the key of the parent instance.
-- @returns executed status (boolean)
function M.delete_profile(mapping, key, parentkey)
  local binding = {config = "bulkdata"}
  local commitapply = mapping._profile.commitapply
  local transactions = mapping._profile.transactions
  binding.sectionname = key
  binding.option = nil
  uci.delete_on_uci(binding, commitapply)
  transactions[binding.config] = true
  return true
end

--- add a new element for the given mapping and profile
-- @param mapping [table] a mapping
-- @param parentkey [string] the key of the parent instance.
-- @param option [string] the parameter option to be saved in uci
-- @returns the index (string) be added in the list
local function add_elements(mapping, parentkey, option)
  local commitapply = mapping._profile.commitapply
  local transactions = mapping._profile.transactions
  local binding = {config = "bulkdata"}

  binding.sectionname = parentkey
  binding.option = option
  local elements = uci.get_from_uci(binding)
  if type(elements) ~= "table" then
    elements = {"|"}
  else
    insert(elements, "|")
    uci.delete_on_uci(binding, commitapply)
  end
  uci.set_on_uci(binding, elements, commitapply)
  transactions[binding.config] = true
  return tostring(#elements)
end

--- delete an existed element for the given mapping and profile
-- @param mapping [table] a mapping
-- @param key [string] the key of the current instance to be deleted
-- @param parentkey [string] the key of the parent instance.
-- @param option [string] the parameter option to be saved in uci
-- @returns true (boolean) if setting successful, or nil and error message (string) if failed
local function delete_elements(mapping, key, parentkey, option)
  local commitapply = mapping._profile.commitapply
  local transactions = mapping._profile.transactions
  local binding = {config = "bulkdata"}
  binding.sectionname = parentkey
  binding.option = option
  local elements = uci.get_from_uci(binding)
  if type(elements) ~= "table" then
    return nil, "No elements!"
  end
  local id = key:match(".*|.*|(.*)")
  remove(elements, tonumber(id))
  uci.delete_on_uci(binding, commitapply)
  if #elements > 0 then
    uci.set_on_uci(binding, elements, commitapply)
  end
  transactions[binding.config] = true
  return true
end

--- add a new parameter for the given mapping and profile
-- @param option [string] the parameter option value
-- @returns function [function] to be used by mapping
function M.add_parameter(option)
  return function(mapping, parentkey)
    if reference == "parameters" then
      local binding = {config = "bulkdata"}
      binding.sectionname = "global"
      binding.option = "max_num_parameters"
      local max = uci.get_from_uci(binding)
      binding.sectionname = parentkey
      binding.option = reference
      local elements = uci.get_from_uci(binding)
      if #elements >= tonumber(max) then
        return nil, "The parameter's instance number has reached the maximize and can't add any new!"
      end
    end
    local key = add_elements(mapping, parentkey, option)
    return format("%s|%s|%d", parentkey, option, key)
  end
end

--- delete an existed parameter for the given mapping and profile
-- @param option [string] the parameter option value
-- @returns function [function] to be used by mapping
function M.delete_parameter(option)
  return function(mapping, key, parentkey)
    return delete_elements(mapping, key, parentkey, option)
  end
end

--- perform given action on all outstanding transaction
-- @param profile [table] a connection object
-- @param action [function] the function to call for each transaction
local function finalize_transactions(profile, action)
  local binding = {}
  for config in pairs(profile.transactions) do
    binding.config = config
    action(binding)
  end
  profile.transactions = {}
end

--- commit the pending transactions
-- @param mapping [table] the mapping
function M.commit(mapping)
  finalize_transactions(mapping._profile, uci.commit)
end

--- revert the pending transactions
-- @param mapping [table] the mapping
function M.revert(mapping)
  finalize_transactions(mapping._profile, uci.revert)
end

--- register the mapping to IGD and Device
-- @param mapping [table] the mapping
-- @param register [function] the register function
function M.register(mapping, register)
  local duplicates = duplicator(mapping, "#ROOT", {"InternetGatewayDevice", "Device"})
  for _, dupli in ipairs(duplicates) do
    register(dupli)
  end
end

--- create a new profile map for the given mapping
-- @param mapping [table] a mapping
-- @param map [table] the map format is {get={}, set={}}
-- @param commitapply [] a commit and apply context
function M.SetProfileMap(mapping, map, commitapply)
  local profile = {
    map = map,
    commitapply = commitapply,
    transactions = {}
  }

  mapping._profile = setmetatable(profile, ProfileMap)
  return profile
end

return M
