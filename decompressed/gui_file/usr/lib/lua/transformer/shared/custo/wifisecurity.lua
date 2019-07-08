local format = string.format
local uci = require 'transformer.mapper.ucihelper'

local M = {}

local ap_to_r_name = {
  ap0 = "r0",
  ap1 = "r1"
}
local function get_default_option_names(ap)
  local rname = ap_to_r_name[ap]
  if rname then
    return {
      wep_key = format("default_wep_key_%s_s0", rname),
      wpa_psk_key = format("default_key_%s_s0", rname),
      wps_ap_pin = format("default_wps_ap_pin_%s_s0", rname),
      security_mode = format("default_security_mode_%s_s0", rname)
    }
  end
end

local env_var = {config="env", sectionname="var"}
local function load_uci_env_vars()
  return uci.getall_from_uci(env_var)
end

local function load_default_values(ap)
  local options = get_default_option_names(ap)
  if options then
    local defaults = {}
    local envvars = load_uci_env_vars()
    for option, varname in pairs(options) do
      local v = envvars[varname]
      if not v then
        -- we want all defaults, if one is missing it fails
        return
      end
      defaults[option] = v
    end
    return defaults
  end
end

local wireless_ap = {config="wireless"}
local function apply_defaults(ap, defaults, commitapply)
  wireless_ap.sectionname = ap
  for option, value in pairs(defaults) do
    wireless_ap.option = option
    uci.set_on_uci(wireless_ap, value, commitapply)
  end
  return true
end

function M.reset(ap, commitapply)
  local defaults = load_default_values(ap)
  if defaults then
    return apply_defaults(ap, defaults, commitapply)
  end
  return nil, "no defaults found for this AccessPoint"
end

return M
