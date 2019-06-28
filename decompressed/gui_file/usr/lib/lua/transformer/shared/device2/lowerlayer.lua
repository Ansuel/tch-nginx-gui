
local require = require
local pairs = pairs

local ucihelper = require "transformer.mapper.ucihelper"

local configChanged
local commit
local revert
do
  local changed_config = {}
  function configChanged(config)
    changed_config[config] = true
  end

  local function complete_transaction(action)
    for config in pairs(changed_config) do
      action{config=config}
    end
    changed_config = {}
  end

  function commit()
    complete_transaction(ucihelper.commit)
  end

  function revert()
    complete_transaction(ucihelper.revert)
  end
end

local function uci_get(section, option, default)
  local binding = {
    config = "network",
    sectionname = section,
    option = option,
    default = default,
  }
  if option then
    return ucihelper.get_from_uci(binding)
  else
    return ucihelper.getall_from_uci(binding)
  end
end

local function uci_get_type(section)
  local s = uci_get(section)
  return s['.type'], s
end

local function uci_set(section, option, value)
  local binding = {
    config = "network",
    sectionname = section,
    option = option,
  }
  ucihelper.set_on_uci(binding, value, commitapply)
  configChanged(binding.config)
end

local set_handler = {}
local function unknown_typepath_handler(_, _, _, typepath)
  return nil, ("a reference to %s can not be used here"):format(typepath)
end

local function propagate_options(section, options)
  while section ~= "" do
    local parent = uci_get(section, "linkedto")
    if parent ~= "" then
      for _, opt in ipairs(options) do
        uci_set(parent, opt, uci_get(section, opt))
      end
    end
    section = parent
  end
end

local defaultPropagate = {"ifname"}
local propagateMap = {}
local function set_propagatable_options(typepath, options)
  propagateMap[typepath] = options
end

local function options_to_propagate_for(typepath)
  return propagateMap[typepath] or defaultPropagate
end

local function propagate_options_for(section, typepath)
  propagate_options(section, options_to_propagate_for(typepath))
end

set_handler["Device.Ethernet.Link.{i}."] = function(model, upper, lowerkey, typepath)
  local ucikey = model:getUciKey(lowerkey)
  if uci_get_type(ucikey) ~= "dev2_link" then
    return nil, "can not attach to hard bound link"
  end
  local upperuci = model:getUciKey(upper)
  uci_set(ucikey, "linkedto", upperuci)
  propagate_options_for(ucikey, typepath)
end

set_handler["Device.Ethernet.VLANTermination.{i}."] = function(model, upper, lowerkey, typepath)
  local loweruci = model:getUciKey(lowerkey)
  local lowertype, lower = uci_get_type(loweruci)
  if lowertype ~= "device" then
    return nil, "not a reference to a dynamically linkable VLAN"
  end
  local upperuci = model:getUciKey(upper)
  uci_set(upperuci, "ifname", lower.name)
  propagate_options_for(upperuci, typepath)
end

set_handler["Device.PPP.Interface.{i}."] = function(model, upper, lowerkey, typepath)
  local ucikey = model:getUciKey(lowerkey)
  if uci_get_type(ucikey) ~= "ppp" then
    return nil, "can not attach to hard bound ppp"
  end
  local upperuci = model:getUciKey(upper)
  uci_set(ucikey, "linkedto", upperuci)
  uci_set(ucikey, "proto", "pppoe")
  propagate_options_for(ucikey, typepath)
end

local function do_set(model, upper, lower, typepath)
  local handler = set_handler[typepath] or unknown_typepath_handler
  return handler(model, upper, lower, typepath)
end

local function setLL(model, upper, lower, typepath, ...)
  local lowerkey, lowertype = tokey(lower, typepath, ...)
  if not lowerkey then
    return nil, "Not a valid link reference"
  end
  return do_set(model, upper, lowerkey, lowertype)
end

local function unsetLL(model, upper)
  local ucikey = model:getUciKey(upper)
  uci_set(ucikey, "ifname", "")
  propagate_options(ucikey, "ifname")
  if uci_get(ucikey, "proto"):match("^ppp")  then
    -- current lowerlayer is PPP.Interface
    uci_set(ucikey, "proto", "")
  end
  local explicit = model:explicit_link_for(ucikey)
  if explicit then
    uci_set(model:getUciKey(explicit), "linkedto", "")
  end
end

local function setLowerLayer(model, upper, lower, typepath, ...)
  if lower ~= "" then
    return setLL(model, upper, lower, typepath, ...)
  end
  return unsetLL(model, upper)
end

return {
  setLowerLayer = setLowerLayer,
  set_propagatable_options = set_propagatable_options,
  propagate_options_for = propagate_options_for,
  commit = commit,
  revert = revert,
}
