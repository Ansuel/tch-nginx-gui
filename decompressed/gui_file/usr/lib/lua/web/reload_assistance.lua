local require = require
local pairs = pairs
local ipairs = ipairs

local untaint = string.untaint

local assistance = require 'web.assistance'
local dm = require 'datamodel'

local M = {}

local function parse_actions(args)
  local actions = {}
  for assistant, action in pairs(args) do
    local enable, mode, pwdcfg, pwd = action:match("(.*)_(.*)_(.*)_(.*)")
    actions[#actions+1] = {
      assistant = assistant:untaint(),
      enable = enable,
      mode = mode,
      pwdcfg = pwdcfg,
      pwd = pwd
    }
  end
  return actions
end

local function load_users()
  local users = {}
  local user_params = dm.get("uci.web.user.") or {}
  for _, param in ipairs(user_params) do
    local sectionname = param.path:match("^uci.web.user.@([^.]+)%.")
    local section = users[sectionname]
    if not section then
      section = {}
      users[sectionname] = section
    end
    section[param.param] = param.value
  end
  return users
end

local function get_user_byname(username, users)
  for _, user in pairs(users) do
    if user.name == username then
      return user
    end
  end
end

local function get_assistant_user(assistant)
  return get_user_byname(assistant:username(), load_users())
end

local _boolean = {}
_boolean.__index = _boolean

local function Boolean(trueValue, falseValue)
  return setmetatable({
    trueValue = trueValue,
    falseValue = falseValue
  }, _boolean)
end

function _boolean:__call(s, default)
  if s == self.trueValue then
    return true
  elseif s == self.falseValue then
    return false
  else
    return default
  end
end

local enableAsBoolean = Boolean("on", "off")
local permanentAsBoolean = Boolean("permanent", "temporary")

local function perform_action(action)
  local assistant = assistance.getAssistant(action.assistant)
  if not assistant then
    return
  end
  local pwd = action.pwd
  local pwdcfg = action.pwdcfg or "keep"
  if pwdcfg == "random" then
    pwd=nil
  elseif pwdcfg == "keep" then
    pwd=false
  elseif pwdcfg == "srpuci" then
    local user = get_assistant_user(assistant)
    pwd = {
      salt = untaint(user.srp_salt),
      verifier = untaint(user.srp_verifier),
    }
    if not (pwd.salt and pwd.verifier) then
      pwd = nil
    end
  end
  local enable = enableAsBoolean(action.enable, assistant:enabled())
  local permanent = permanentAsBoolean(action.mode, assistant:isPermanentMode())
  assistant:enable_with_reload(enable, permanent, pwd)
end

local function perform_all_actions(actions)
  for _, action in ipairs(actions) do
    perform_action(action)
  end
end

local function refresh_assistant(name)
  local assistant = assistance.getAssistant(name)
  if assistant then
    local enabled = assistant:enabled()
    local permanent = assistant:isPermanentMode()
    local pswcfg = false --keep
    assistant:enable_with_reload(enabled, permanent, pswcfg)
  end
end

local function refresh_all_assistants()
  local assistants = assistance.assistantNames()
  for _, name in ipairs(assistants) do
    refresh_assistant(name)
  end
end

function M.reload(args)
  local actions = parse_actions(args)
  if #actions>0 then
    perform_all_actions(actions)
  else
    refresh_all_assistants()
  end
end

return M