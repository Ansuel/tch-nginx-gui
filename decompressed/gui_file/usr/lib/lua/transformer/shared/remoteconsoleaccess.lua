
local string = string
local pairs = pairs
local os = os
local uciHelper = require("transformer.mapper.ucihelper")
local get_from_uci = uciHelper.get_from_uci
local set_on_uci = uciHelper.set_on_uci
local foreach_on_uci = uciHelper.foreach_on_uci
local match = string.match
local find = string.find
local format = string.format
local lower = string.lower

local lfs = require("lfs")

local ubus = require("transformer.mapper.ubus").connect()

local open = io.open
local remove = os.remove
local configBinding = {}
local transactions = {}
local process = require("tch.process")

local M = {}

-- data model binding templates tied to uci settings
local dropbearBinding = { config = "dropbear" }
local firewallBinding = { config = "firewall" }
local clashBinding = { config = "clash" }

-- lookup table for idle disconnect timeout -> drop-down conversion
local IDLE_UCI_TO_WEBUI = {
  ["0"] = "0",
  ["300"] = "1",
  ["900"] = "2",
  ["1800"] = "3",
  ["3600"] = "4",
  ["21600"] = "5",
  ["43200"] = "6",
  ["86400"] = "7",
  ["259200"] = "8",
  ["604800"] = "9"
}

local IDLE_WEBUI_TO_UCI = {}
for i,j in pairs(IDLE_UCI_TO_WEBUI) do
  IDLE_WEBUI_TO_UCI[j] = i
end

-- applicable console type options
local CONSOLE_DISABLED = "0"
local CONSOLE_LAN_SSH = "1"
local CONSOLE_WAN_SSH = "2"
local CONSOLE_LANWAN_SSH = "3"
local CONSOLE_LAN_TELNET = "4"
local CONSOLE_WAN_TELNET = "5"
local CONSOLE_LANWAN_TELNET = "6"

--- get console type based on dropbear configuration
--- Retrieves current remote console type
-- @return #string remote console state derived from dropbear settings
function M.getRemoteConsoleType()
  -- holds final console type
  local consoleType = CONSOLE_DISABLED
  -- checks for which console type is being used
  local sshLan, sshWan, telnetLan, telnetWan
  dropbearBinding.sectionname = "dropbear"
  dropbearBinding.option = nil
  foreach_on_uci(dropbearBinding, function(s)
    if s.Port == "22" and s.Interface == "lan" then
      sshLan = s.enable == "1"
    elseif s.Port == "22" and s.Interface == "wan" then
      sshWan = s.enable == "1"
    elseif s.Port == "23" and s.Interface == "lan" then
      telnetLan = s.enable == "1"
    elseif s.Port == "23" and s.Interface == "wan" then
      telnetWan = s.enable == "1"
    end
  end)
  -- determine final console type from configuration
  if not sshLan and not sshWan and not telnetLan and not telnetWan then
    consoleType = CONSOLE_DISABLED
  elseif sshLan and not sshWan and not telnetLan and not telnetWan then
    consoleType = CONSOLE_LAN_SSH
  elseif not sshLan and sshWan and not telnetLan and not telnetWan then
    consoleType = CONSOLE_WAN_SSH
  elseif sshLan and sshWan then
    consoleType = CONSOLE_LANWAN_SSH
  elseif not sshLan and not sshWan and telnetLan and not telnetWan then
    consoleType = CONSOLE_LAN_TELNET
  elseif not sshLan and not sshWan and not telnetLan and telnetWan then
    consoleType = CONSOLE_WAN_TELNET
  elseif not sshLan and not sshWan and telnetLan and telnetWan then
    consoleType = CONSOLE_LANWAN_TELNET
  end
  return consoleType
end

-- @param #string iface Interface name ("lan", "wan")
-- @param #string port Port number to match based on console (ssh = "22", telnet = "23")
local function get_dropbear_section(intf, port)
  local sectionName
  dropbearBinding.sectionname = "dropbear"
  dropbearBinding.option = nil
  foreach_on_uci(dropbearBinding, function(s)
    if s.Interface == intf and s.Port == port then
      sectionName = s[".name"]
      return false
    end
  end)
  return sectionName or ""
end

--- get value from dropbear section data
-- @param #string iface Interface name ("lan", "wan")
-- @param #string port Port number to match based on console (ssh = "22", telnet = "23")
-- @param #string opt UCI option to update
local function get_dropbear_param(iface, port, opt)
  dropbearBinding.sectionname = get_dropbear_section(iface, port)
  dropbearBinding.option = opt
  return get_from_uci(dropbearBinding)
end

--- update dropbear section data
-- @param #string iface Interface name ("lan", "wan")
-- @param #string port Port number to match based on console (ssh = "22", telnet = "23")
-- @param #string opt UCI option to update
-- @param #string value Target value to set
local function set_dropbear_param(iface, port, opt, value, commitapply)
  dropbearBinding.sectionname = get_dropbear_section(iface, port)
  dropbearBinding.option = opt
  set_on_uci(dropbearBinding, value, commitapply)
  transactions[dropbearBinding.config] = true
end

local function set_clash_param(curruser, opt, value, commitapply)
  clashBinding.sectionname = curruser
  clashBinding.option = opt
  set_on_uci(clashBinding, value, commitapply)
  transactions[clashBinding.config] = true
end

-- validate if user name actually exists
-- @param #string, username to be validated
-- @return #string, #boolean User account and true/false depending on whether it exists
local function validate_user_account(user)
  local exists = false
  local fp = open("/etc/passwd","r")
  if fp then
    for line in fp:lines() do
      if user and line:match("^"..user..":") then
        -- found the account
        exists = true
        break
      end
    end
    fp:close()
  end
  return user, exists
end

--- get user account data to aid in password update
-- @return #string, #boolean User account and true/false depending on whether it exists
local function get_user_to_update()
  -- holds user account name
  local user
  -- first find out which account to update
  -- assumption is only one clash user section exists within configuration,
  -- so return after acquiring first one
  clashBinding.sectionname = "user"
  clashBinding.option = nil
  foreach_on_uci(clashBinding, function(s)
    -- Skip the "superuser", as it is required for EFU control. Only update the other section.
    if s[".name"] ~= "superuser" then
      user = s[".name"]
      return false
    end
  end)
  return validate_user_account(user)
end

--- update SSH/Telnet firewall rules and their states
-- @param #string srcif Source Interface ("lan", "wan")
-- @param #string port Port number to match based on console (ssh = "22", telnet = "23")
-- @param #string target How to handle packets originating from source interface and port ("ACCEPT", "DROP", "REJECT")
local function set_iptables_rule(srcif, port, target, commitapply)
  firewallBinding.sectionname = "rule"
  firewallBinding.option = nil
  foreach_on_uci(firewallBinding, function(s)
    if s.src == srcif and s.dest_port == port then
      -- update detected firewall rule target
      firewallBinding.sectionname = s[".name"]
      firewallBinding.option = "target"
      set_on_uci(firewallBinding, target, commitapply)
      transactions[firewallBinding.config] = true
      return false
    end
  end)
end

--- change clash user name
-- @param #string curruser Current remote console username to read (from clash settings)
-- @param #string newuser New remote console username to update
local function renameClashUser(curruser, newuser, commitapply)
  clashBinding.sectionname = curruser
  uciHelper.rename_on_uci(clashBinding, newuser, commitapply)
  return true
end

--- remove old history file and create new history file
-- @param #string curruser Current remote console username to read (from clash settings)
-- @param #string newuser New remote console username to update
local function removeAndCreateHistoryFile(curruser, newuser, commitapply)
  local newhistfile = "/etc/clash/history" .. newuser .. ".txt"
  local oldhistfile = "/etc/clash/history" .. curruser .. ".txt"
  -- update command history file configuration
  clashBinding.sectionname = newuser
  clashBinding.option = "historyfile"
  set_on_uci(clashBinding, newhistfile, commitapply)
  -- remove previous historyfile
  remove(oldhistfile)
  transactions[clashBinding.config] = true
end

--- change username for remote console access
-- @param #string curruser Current remote console username to read (from clash settings)
-- @param #string newuser New remote console username to update
-- @return true if operation succeeded or nil plus error message on failure
local function change_remoteconsole_userdata(curruser, newuser, commitapply)
  if not curruser or not newuser then
    return nil, "cannot change user account without proper info"
  end
  -- convert user names to lower-case to handle issue with
  -- usermod not allowing upper-case letters when changing login account
  curruser = lower(curruser)
  newuser = lower(newuser)
  -- redirect configured 'root' username to a restricted account (requires LD_PRELOAD to override credentials)
  -- this keeps the current 'root' account (UID = 0) intact
  dropbearBinding.sectionname = "global"
  dropbearBinding.option = "restrictRoot"
  if lower(newuser) == "root" then
    -- changing to restricted root user, redirecting clash user
    newuser = get_from_uci(dropbearBinding)
  end
  -- first check for presence of tools
  if lfs.attributes("/usr/sbin/usermod", "mode") ~= "file" or
     lfs.attributes("/usr/sbin/groupmod", "mode") ~= "file" then
    return nil , "could not find required tools"
  end

  local exitCode
  -- now update username
  exitCode = process.execute("usermod", {"-l", newuser, curruser})
  if exitCode ~= 0 then
    return nil, "could not change username"
  end
  -- now update group name
  exitCode = process.execute("groupmod", {"-n", newuser, curruser})
  if exitCode ~= 0 then
    return nil, "could not change group name"
  end
  -- rename clash user section in uci
  local result = renameClashUser(curruser, newuser, commitapply)
  if not result then
    return nil, "could not change clash user section"
  end
  removeAndCreateHistoryFile(curruser, newuser, commitapply)
  -- construct string for new command history file
  return true
end

-- list of invalid sequences (case-insensitive) for remote console password
-- based on TCH.VALID.ConsolePassword() method in validator.js
local badSeq = { "qwerty", "uiop[]", "asdfgh", "jkl;'", "zxcvbn", "m,./" }

--- validate new password based on console password criteria
-- @param #string value Data to be checked
-- @return true if valid, false otherwise
local function check_remoteconsole_password(value)
  -- checks if password is 8 characters long with at least one lower case letter,
  -- one upper case letter, one number and no spaces
  local isGood = (#value >= 8) and
               match(value, "%l+") and
               match(value, "%u+") and
               match(value, "%d+") and
               not match(value, "%s+")

  if not isGood then
    return false
  end
  -- check to make sure it doesn't match any special sequences
  local lStr = lower(value)
  for _, seq in ipairs(badSeq) do
    if find(lStr, seq, 1, true) then
      isGood = false
      break
    end
  end
  return isGood
end

--- Retrieves current remote console username
function M.getRemoteConsoleUserName()
  dropbearBinding.sectionname = "global"
  dropbearBinding.option = "AdminUser"
  return get_from_uci(dropbearBinding)
end

--- Retrieves current remote console password
function M.getRemoteConsolePassword()
  dropbearBinding.sectionname = "global"
  dropbearBinding.option = "hPass"
  return get_from_uci(dropbearBinding)
end

--- Retrieves current remote console idle timeout value
function M.getRemoteConsoleIdleTimeout()
  local consoleType = M.getRemoteConsoleType()
  local timeout
  if consoleType == CONSOLE_DISABLED or
    consoleType == CONSOLE_LAN_SSH or
    consoleType == CONSOLE_LANWAN_SSH then
    timeout = get_dropbear_param("lan", "22", "IdleTimeout")
  elseif consoleType == CONSOLE_LAN_TELNET or
    consoleType == CONSOLE_LANWAN_TELNET then
    timeout = get_dropbear_param("lan", "23", "IdleTimeout")
  elseif consoleType == CONSOLE_WAN_TELNET then
    timeout = get_dropbear_param("wan", "23", "IdleTimeout")
  else -- for all other console types, by default ssh wan side idle timeout is shown
    timeout = get_dropbear_param("wan", "22", "IdleTimeout")
  end
  return IDLE_UCI_TO_WEBUI[timeout] or "0"
end

--- Retrieves whether current telnet via wan is enabled or not
function M.getRemoteTelnetEnable()
  local enable = get_dropbear_param("wan", "23", "enable")
  return enable ~= "" and enable or "0"
end

--- Retrieves timeout value of remote telnet access
function M.getRemoteTelnetIdleTimeout()
  local timeout = get_dropbear_param("wan", "23", "IdleTimeout")
  return IDLE_UCI_TO_WEBUI[timeout] or "0"
end

local dropBearSettings = {
  [CONSOLE_DISABLED] = {"0","0","0","0"},
  [CONSOLE_LAN_SSH] = {"1","0","0","0"},
  [CONSOLE_WAN_SSH]= { "0", "1", "0", "0"},
  [CONSOLE_LANWAN_SSH] = { "1", "1", "0", "0"},
  [CONSOLE_LAN_TELNET] = { "0", "0", "1", "0"},
  [CONSOLE_WAN_TELNET] = { "0", "0", "0", "1"},
  [CONSOLE_LANWAN_TELNET] = { "0", "0", "1", "1"},
}

local fireWallSettings = {
  [CONSOLE_DISABLED] = {"REJECT","REJECT","REJECT"},
  [CONSOLE_LAN_SSH] = {"REJECT","REJECT","REJECT"},
  [CONSOLE_WAN_SSH]= {"ACCEPT", "REJECT", "REJECT"},
  [CONSOLE_LANWAN_SSH] = {"ACCEPT", "REJECT", "REJECT"},
  [CONSOLE_LAN_TELNET] = {"REJECT" ,"REJECT","ACCEPT"},
  [CONSOLE_WAN_TELNET] = {"REJECT" ,"ACCEPT","REJECT"},
  [CONSOLE_LANWAN_TELNET] = {"REJECT" ,"ACCEPT","ACCEPT"},
}

local clashSettings = {
  [CONSOLE_DISABLED] = "0",
  [CONSOLE_LAN_SSH] = "0",
  [CONSOLE_WAN_SSH]= "0",
  [CONSOLE_LANWAN_SSH] = "0",
  [CONSOLE_LAN_TELNET] = "1",
  [CONSOLE_WAN_TELNET] = "1",
  [CONSOLE_LANWAN_TELNET] = "1",
}

--- Changes remote console type, based on required access via lan, wan, ssh or telnet.
-- @param #string Console type enum to be set.
-- @return true
function M.setRemoteConsoleType(value, commitapply)
-- update dropbear console flags based on CURRENT value
  local curruser, exists = get_user_to_update()
  set_dropbear_param("lan", "22", "enable", dropBearSettings[value][1], commitapply)
  set_dropbear_param("wan", "22", "enable", dropBearSettings[value][2], commitapply)
  set_dropbear_param("lan", "23", "enable", dropBearSettings[value][3], commitapply)
  set_dropbear_param("wan", "23", "enable", dropBearSettings[value][4], commitapply)
  set_clash_param(curruser, "telnet", clashSettings[value], commitapply)
  -- toggle wan based firewall rules
  set_iptables_rule("wan", "22", fireWallSettings[value][1], commitapply)
  set_iptables_rule("wan", "23", fireWallSettings[value][2], commitapply)
  -- toggle lan based firewall rules / lan ssh rule is not modified as per legacy behaviour
  set_iptables_rule("lan", "23", fireWallSettings[value][3], commitapply)
  return true
end

--- Modifies username of existing user other than super user.
-- @param #string value username to be set.
-- @return nil
function M.setRemoteConsoleUserName(value, commitapply)
  -- invoke method to update new login (provided current user account exists)
  local curruser, exists = get_user_to_update()
  if not curruser or not exists then
    return nil, format("user account %s not found, cannot change username", curruser)
  end
  -- update uci settings
  dropbearBinding.sectionname = "global"
  dropbearBinding.option = "AdminUser"
  set_on_uci(dropbearBinding, value, commitapply)
  transactions[dropbearBinding.config] = true
  -- process information
  if lower(value) ~= "superuser" then
    return change_remoteconsole_userdata(curruser, value, commitapply)
  else
    -- Blacklist superuser as a configurable username
    return nil, "username not allowed"
  end
end

--- Sets Remote console user's password after checking current user, password strength.
-- @param #string value password of user to be set.
-- @return true or nil
function M.setRemoteConsolePassword(value, commitapply)
  local curruser, exists = get_user_to_update()
  if not curruser or not exists then
    return nil, format("user account %s not found, cannot change passwd", curruser)
  end
  -- don't change password if invalid data received
  if check_remoteconsole_password(value) then
    local  p = io.popen("chpasswd", "w")
    if p then
      p:write(format("%s:%s", curruser, value))
      p:close()
    end
    -- update uci settings
    dropbearBinding.sectionname = "global"
    dropbearBinding.option = "hPass"
    -- replace with hidden characters to avoid exposing as plain-text
    value = value:gsub("(%S)", "*")
    set_on_uci(dropbearBinding, value, commitapply)
    transactions[dropbearBinding.config] = true
  else
    return nil, "password doesn't meet the requirements"
  end
  return true
end

--- Sets Remote console idle timeout.
-- @param #string value enum code of idle timeout.
-- @return true
function M.setRemoteConsoleIdleTimeout(value, commitapply)
  set_dropbear_param("lan", "22", "IdleTimeout", IDLE_WEBUI_TO_UCI[value] or "0", commitapply)
  set_dropbear_param("wan", "22", "IdleTimeout", IDLE_WEBUI_TO_UCI[value] or "0", commitapply)
  set_dropbear_param("lan", "23", "IdleTimeout", IDLE_WEBUI_TO_UCI[value] or "0", commitapply)
  set_dropbear_param("wan", "23", "IdleTimeout", IDLE_WEBUI_TO_UCI[value] or "0", commitapply)
  -- send ubus event to trigger remote console access handler (shellremoteaccessd-tch.lua)
  -- event is not sent from shelleventerd-tch daemon because
  -- we want to make sure only one event is sent out for shell configuration change
  ubus:send("shellremoteaccess", { access = "start", timeout = IDLE_WEBUI_TO_UCI[value] or "0" })
  return true
end

local wanTelnetRule = {
  ['0'] = "REJECT",
  ['1'] = "ACCEPT"
}

--- Enables/Disables Remote console access via Telnet.
-- @param #string value of 0 (Disable) or 1 (Enable).
function M.setRemoteTelnetEnable(value, commitapply)
  set_dropbear_param("wan", "23", "enable", value, commitapply)
  return set_iptables_rule("wan","23",wanTelnetRule[value], commitapply)
end

--- sets timeout for Remote console access via Telnet.
-- @param #string value of timeout.
function M.setRemoteTelnetTimeout(value, commitapply)
  set_dropbear_param("wan", "23", "IdleTimeout", IDLE_WEBUI_TO_UCI[value] or "0", commitapply)
  -- send ubus event to trigger remote console access handler (shellremoteaccessd-tch.lua)
  -- event is not sent from shelleventerd-tch daemon because
  -- we want to make sure only one event is sent out for shell configuration change
  ubus:send("shellremoteaccess", { access = "start", timeout = IDLE_WEBUI_TO_UCI[value] or "0" })
end

--- Commits recent set actions in dropbear, firewall and clash config.
function M.commit_remoteconsole_data()
  for config in pairs(transactions) do
    configBinding.config = config
    uciHelper.commit(configBinding)
  end
  transactions = {}
end

--- Reverts recent set actions in dropbear, firewall and clash config.
function M.revert_remoteconsole_data()
  for config in pairs(transactions) do
    configBinding.config = config
    uciHelper.revert(configBinding)
  end
  transactions = {}
end

return M
