
local ucihelper = require 'transformer.mapper.ucihelper'

local M = {}

local _uci_to_commit = {}

local function register_uci_change(config)
  _uci_to_commit[config] = true
end

local function complete_uci_transaction(action)
  for config, _ in pairs(_uci_to_commit) do
    action{config=config}
  end
  _uci_to_commit = {}
end

function M.commit()
  complete_uci_transaction(ucihelper.commit)
end

function M.revert()
  complete_uci_transaction(ucihelper.revert)
end

local GeneratedKey = {}
M.GeneratedKey = GeneratedKey

local function create_new_uci_section(binding, prefix, commitapply)
  local index = 0
  local pattern = prefix.."_(%d+)"
  ucihelper.foreach_on_uci(binding, function(s)
    local suffix = tonumber(s['.name']:match(pattern) or "0")
    if suffix and (suffix>index) then
      index = suffix
    end
  end)
  local section = binding.sectionname
  local name = (prefix.."_%d"):format(index+1)
  binding.sectionname = name
  ucihelper.set_on_uci(binding, section, commitapply)
  register_uci_change(binding.config)
  return name
end

function M.create(config, section, prefix, defaults, commitapply)
  local binding = {
    config = config,
    sectionname = section,
  }
  local key = create_new_uci_section(binding, prefix, commitapply)
  for option, value in pairs(defaults or {}) do
    binding.option = option
    if value == GeneratedKey then
      value = binding.sectionname
    end
    ucihelper.set_on_uci(binding, value, commitapply)
  end
  return key
end

function M.delete(config, section, commitapply)
  ucihelper.delete_on_uci({config=config, sectionname=section}, commitapply)
  register_uci_change(config)
end

function M.is_dynamic(config, section)
  local binding = {
    config = config,
    sectionname = section,
    option = "dev2_dynamic"
  }
  return ucihelper.get_from_uci(binding)=="1"
end

return M
