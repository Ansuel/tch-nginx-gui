local require = require
local ipairs = ipairs

local ngx = ngx
local setmetatable = setmetatable
local posix = require("tch.posix")
local clock_gettime = posix.clock_gettime
local CLOCK_MONOTONIC = posix.CLOCK_MONOTONIC

local network = require "web.network"

local generateRandom
do
  local keylength = 32  -- in bytes
  local key = ("%02x"):rep(keylength)
  local fd = assert(io.open("/dev/urandom", "r"))

  generateRandom=function()
    local bytes = fd:read(keylength)
    return key:format(bytes:byte(1, keylength))
  end
end

local Session = {}
Session.__index = Session

-- user substituted for session.user if session.user is nil
-- this contains the values used in case no user is known
-- this simplifies some logic
local emptyUser = {
  name = "",
  role = "",
  interface = {},
}
local function sessionUser(session)
  local user = session.user
  if not user then
    return emptyUser
  end
  return user
end

--- Return the username associated with the session.
-- @return #string The username associated with this session.
function Session:getusername()
  return sessionUser(self).name
end

--- Returns whether the current user is the default user.
-- @return #boolean True if the current user is the default user; false otherwise.
function Session:isdefaultuser()
  local default_user = self.mgr.default_user
  if not default_user then
    return false
  end
  return (self.user == default_user)
end

function Session:toggleDefaultUser(value)
  if value then
    self.mgr:setDefaultUser(self.user)
  else
    self.mgr:setDefaultUser()
  end
end

--- Return the role associated with the session.
-- @return #string The role associated with this session.
function Session:getrole()
  return sessionUser(self).role
end

--- Store a key-value pair in the session.
-- Anything stored this way will remain available during the
-- lifetime of the session (by using the retrieve method) and as
-- long as privileges are not dropped.
-- Once the session is over, everything in storage is discarded.
-- @param key   the key to use in storage
-- @param value the value to be stored
function Session:store(key, value)
  self.storage[key] = value
end

--- Retrieve a value previously stored in the session.
-- @param key   the key for which the value needs to be retrieved.
-- @return the value corresponding to the given key or nil if not found.
function Session:retrieve(key)
  return self.storage[key]
end

local function generateNewIdentity(session)
  session.sessionid = generateRandom()
  session.CSRFtoken = generateRandom()
end

--- set a new user for the session
-- @param user the user to switch to
-- As the security in the web framework is tied to the
-- user role, the session identity is changed when the
-- role changes so that the client will se a new identity
-- after login or logout
function Session:changeUser(newUser)
  ngx.log(ngx.WARN, "changing user to ", newUser and newUser.name or "default user")
  local oldrole = sessionUser(self).role
  local newrole = newUser and newUser.role
  self.user = newUser
  if oldrole~=newrole then
    generateNewIdentity(self)
  end
end

--- Perform a logout of the current user.
-- The current username and role are reverted to the default values
-- and everything in the storage cache is discarded.
function Session:logout()
  local mgr = self.mgr
  -- Invalidate storage
  self.storage = {}
  -- Revert user to default user
  self:changeUser(mgr.default_user)
end

--- Verify if the given resource can be accessed with the current credentials.
-- @param resource   The resource which needs to be checked.
-- @return True if the given resource can be accessed by this session, false
--         otherwise.
function Session:hasAccess(resource)
  return (self.mgr:authorizeRequest(self, resource))
end

local function value_present(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

local function recalculateUserAllowedOnInterface(user, interfaceIP)
  local interfaces = user and user.interface
  if interfaces then
    local allowed_ips = network.interfacesToIP(interfaces)
    return value_present(allowed_ips, interfaceIP)
  end
  return true
end

local function recalculateUserAllowedOnIpaddress(user, remoteIP)
  local userallowed_ips = user and user.allowed_ip
  if userallowed_ips then
     return userallowed_ips[remoteIP] ~= nil
  end
  return true
end

local function userOrIPInfoChanged(state, user, interfaceIP, remoteIP)
  if not state then
    return true
  end
  if state.user ~= user then
    return true
  end
  if state.interface ~= user.interface then
    return true
  end
  if state.interfaceIP~=interfaceIP then
    return true
  end
  if state.remoteIP~=remoteIP then
    return true
  end
  return false
end

local function isUserAllowedByIP(state, user, interfaceIP, remoteIP)
  if userOrIPInfoChanged(state, user, interfaceIP,remoteIP)then
    local allowed_interface = recalculateUserAllowedOnInterface(user, interfaceIP)
    local allowed_ip = recalculateUserAllowedOnIpaddress(user, remoteIP)
    local allowed = allowed_interface and allowed_ip
    state = {
      user = user,
      interface = user.interface,
      interfaceIP = interfaceIP,
      remoteIP = remoteIP,
      allowed = allowed,
    }
  end
  return state.allowed, state
end

--- Verify user has access via the interface the request was received on
-- @param user an explicit user or nil to use the current session user
-- @returns true if user allowed, false if not
function Session:isUserAllowedByIP(user)
  local allowedState = self:retrieve("UserAllowedState")
  local allowed
  user = user or sessionUser(self)
  allowed, allowedState = isUserAllowedByIP(allowedState, user, self.serverIP, self.remoteIP)
  self:store("UserAllowedState", allowedState)
  return allowed
end

--- Retrieve the CSRF token associated with this session.
-- @return String with this session's CSRF token.
function Session:getCSRFtoken()
  return self.CSRFtoken
end

--- Validate the given token against the session's token.
-- If it doesn't match this function never returns; it ends
-- the request processing with a HTTP Forbidden status code.
-- @param token The token to check.
-- @return True if the token matches.
function Session:checkCSRFtoken(token)
  if token ~= self.CSRFtoken then
    ngx.log(ngx.ERR, "POST without CSRF token")
    ngx.exit(ngx.HTTP_FORBIDDEN)
  end
  return true
end

--- add the user whose instance name is provided to the list of allowed users for the session's manager
-- @param instancename
function Session:addUserToManager(instancename)
    return self.mgr:addUser(instancename)
end

--- remove the user whose instance name is provided from the list of allowed users to the session's manager
function Session:delUserFromManager(instancename)
    return self.mgr:delUser(instancename)
end

--- reload all users to update them if needed
function Session:reloadAllUsers()
  self.mgr.sessioncontrol.reloadUsers()
end

--get currently logged-in user sessions 
function Session:getUserCount()
  return self.mgr:getUserCount()
end

--- Change SRP parameters and crypted password of the current user of this session.
-- @param salt A newly generated SRP salt for the updated password
-- @param verifier A newly calculated SRP verifier for the generated salt and updated password
-- @param cryptedpassword A newly calculated crypted password. This parameter is optional,
-- set to nil if CLI password update is to be omitted
-- @return true or nil, error message
function Session:changePassword(salt, verifier, cryptedpassword)
  return self.mgr.sessioncontrol.changePassword(self.user, salt, verifier, cryptedpassword)
end

--- Create a proxy for a session. This protects the session object
-- from tampering by code in the Lua pages.
-- @param session   The session for which we wish to create a proxy.
-- @return A read-only proxy object for the session with only the
--         desired API exposed. The real session object is hidden by the closure.
local function createProxy(session)
  -- TODO: more generic instead of wrapper function for each public function
  local getusername = function()
    return session:getusername()
  end
  local isdefaultuser = function()
    return session:isdefaultuser()
  end
  local toggleDefaultUser = function(_, value)
    return session:toggleDefaultUser(value)
  end
  local getrole = function()
    return session:getrole()
  end
  local store = function(_, key, value)
    session:store(key,value)
  end
  local retrieve = function(_, key)
    return session:retrieve(key)
  end
  local logout = function()
    session:logout()
  end
  local hasAccess = function(_, resource)
    return session:hasAccess(resource)
  end
  local getCSRFtoken = function()
    return session:getCSRFtoken()
  end
  local checkCSRFtoken = function(_, token)
    return session:checkCSRFtoken(token)
  end
  local addUserToManager = function(_, instancename)
    return session:addUserToManager(instancename)
  end
  local delUserFromManager = function(_, instancename)
    return session:delUserFromManager(instancename)
  end
  local reloadAllUsers = function()
      return session:reloadAllUsers()
  end
  local changePassword = function(_, salt, verifier, cryptedpassword)
    return session:changePassword(salt, verifier, cryptedpassword)
  end
  local getUserCount = function()
    return session:getUserCount()
  end
  local proxy = {
    getusername = getusername,
    isdefaultuser = isdefaultuser,
    toggleDefaultUser = toggleDefaultUser,
    getrole = getrole,
    store = store,
    retrieve = retrieve,
    logout = logout,
    hasAccess = hasAccess,
    getCSRFtoken = getCSRFtoken,
    checkCSRFtoken = checkCSRFtoken,
    addUserToManager = addUserToManager,
    delUserFromManager = delUserFromManager,
    reloadAllUsers = reloadAllUsers,
    changePassword = changePassword,
    getUserCount = getUserCount
  }
  return setmetatable({}, {
    __index = proxy,
    __newindex = function()
      ngx.log(ngx.ERR, "Illegal attempt to modify session object")
    end,
    __metatable = "ah ah ah, you didn't say the magic word"
  });
end

local M = {}

--- Create a new session.
-- @param sessionAddress The IP addresses linked to the new session.
--    This is a table with the field 'server' and 'remote'.
--    This should not change during a session.
-- @param mgr        The session manager that creates the new session.
-- @return A new session is returned that is initiated with the default
--         user and role.
function M.new(sessionAddress, mgr)
  local default_user = mgr.default_user
  ngx.log(ngx.WARN, "new session for ", default_user and default_user.name or "default user")
  local session = {
    mgr = mgr,
    user = default_user,  -- note: default_user can be nil (meaning there is no default user)
    remoteIP = sessionAddress.remote,
    serverIP = sessionAddress.server,
    timestamp = clock_gettime(CLOCK_MONOTONIC),
    storage = {},
  }
  generateNewIdentity(session)
  setmetatable(session, Session)
  session.proxy = createProxy(session)
  return session
end

return M
