--[[
Remote Assistance
=================

This modudle defines an Assistant type that keeps track of the state of
remote assistance for a session manager.
It attaches itself to the configured session manager.
When enabled it generate a random password for the configured user and then
updates the SRP salt and hash of this user in the session  manager.
Then the state is written to a file and then the datamodel is updated,
triggering a commit and apply rule to update the firewall.

Session manager code was modified to trigger activity timer resets.
--]]
-- just make sure tainting is set up properly
require 'web.web'

local require, ipairs, setmetatable, type = require, ipairs, setmetatable, type
local tonumber, tostring = tonumber, tostring
local pairs = pairs
local format = string.format
local untaint = string.untaint
local match = string.match
local random = math.random
local concat = table.concat

-- the require is not strictly required, but doing it this way makes stubbing
-- io for testing much easier.
local io = require 'io'

local ngx = ngx
local dm = require 'datamodel'
local srp = require 'srp'
local control = require 'web.sessioncontrol'
local posix = require("tch.posix")
local clock_gettime = posix.clock_gettime
local CLOCK_MONOTONIC = posix.CLOCK_MONOTONIC

local M = {}

-- functions defined later
local assistant_enable
local assistant_disable
local assistant_checkTimeout
local assistant_startTimer

-- The state of the remote assistance must be written to a file as it is
-- needed by the commit/apply script that will update the firewall with the
-- correct rules.
-- We must be able to read the state back here as the commit/apply script
-- relies on the fact that the IP and port numbers are still present in the
-- file when the assistance gets disabled.
local stateFile = "/var/run/assistance/%s"
local function loadState(name)
    local state = {
        wanip="";
        wanport="";
        lanport="";
        enabled="0";
        password="";
        mode="0";
        ifname = "";
    }
    local f = io.open(stateFile:format(name), 'r')
    if f then
        for ln in f:lines() do
            local key, value = ln:match('^%s*([^=%s]*)%s*=%s*([^%s]*)')
            if key then
                state[key] = value
            end
        end
        f:close()
    end
    return state
end
-- loadState is exported to simplify testing
M.loadState = loadState

local function writeState(name, state, stateOnly)
    local f = io.open(stateFile:format(name), 'w')
    if f then
        for key, value in pairs(state) do
            f:write(format("%s=%s\n", key, value))
        end
        f:close()
        if not stateOnly then
            local uci = format("uci.web.assistance.@%s.active", name)
            dm.set(uci, state.enabled or "trigger")
            dm.apply()
        end
    end
end

--- Get the IP address of the named interface
-- \param ifname (string) the interface (wan, lan, ...)
-- \returns the ip address string or nil if not found
local function getInterfaceIP(ifname)
    local info = dm.get(format('rpc.network.interface.@%s.ipaddr', ifname))
    if info and info[1] and (info[1].param=='ipaddr') then
        return info[1].value
    end
end

local function genpsw(size, pswchars)
    local psw = {}
    for i=1,size do
        local idx = random(#pswchars)
        psw[i] = pswchars:sub(idx, idx)
    end
    return concat(psw, '')
end


local Assistant = {}
Assistant.__index = Assistant

--- Check if assistent is enabled
-- \returns true if enabled, false otherwise
function Assistant:enabled()
    return self._psw~=nil
end

--- Get the username for the assistant to use
-- only relevant if the assistant is enabled
function Assistant:username()
    return self._user
end

--- Get the port number
function Assistant:port()
    return self._port or ''
end

--- Get the full URL for the remote assistance
-- @return [string] the URL
-- @return nil if not enabled or no IP address on the interface.
function Assistant:URL()
    if self:enabled() then
        local ip = getInterfaceIP(self._interface)
        local port = self._port
        if ip and (ip~='') and port then
            return format("https://%s:%d", ip, port)
        end
    end
end

--- Get the password for the assistant to use
-- This is only relevant if the assistent is enabled
-- There is no need to show password when random password is not enabled
function Assistant:password()
    return self._pswcfg==nil and self._psw or ''
end

--- Get the mode for the assistant to use
--- true: permanent mode
--- false: temporary mode
function Assistant:isPermanentMode()
    return self._permanent
end

--- check if the random password is used for the assistant
--- return true if random password is enabled otherwise false
function Assistant:isRandomPassword()
    return self._pswcfg==nil
end

local function differentSrpPassword(pswcfg, password)
  if password.salt and pswcfg.salt~=password.salt then
    return true
  end 
  if password.verifier and pswcfg.verifier~=password.verifier then
    return true
  end
end

-- check if there is any change for _mode and _pswcfg
local function checkUpdate(assistant, permanent, password)
    local pswcfg = assistant._pswcfg
    local useSrp = type(pswcfg)=="table" and type(password)=="table"
    if useSrp then
        if differentSrpPassword(pswcfg, password) then
            return true
        end
    elseif pswcfg~=password then
         return true
    end
    return assistant._permanent~=(permanent or false)
end

--- update assistant cfg
-- \param bPermanent (bool) if true permanent mode else temporary mode
-- \param password:
--    if nil, random password is enabled
--    if string, clear text password is given by user
--    if table, srp salt/verifier is given by user
--    otherwise, previous password cfg will be used
local function updatecfg(assistant, bPermanent, password)
    assistant._permanent = bPermanent
    if type(password)=="table" then
         assistant._pswcfg = {
             salt = password.salt,
             verifier = password.verifier
         }
    elseif  password==nil or type(password)=="string" then
         assistant._pswcfg =password
    end

    -- update state file so that IGD can get the correct info
    local config = loadState(assistant._name)
    config.mode = assistant._permanent and "1" or "0"
    if assistant._pswcfg~=nil then
        config.password=''
    elseif not assistant._pswcfg and config.password=='' then
        --set dummy password here to indicate random password is enabled when remote assistance is not enabled
        config.password='_DUMMY_PASSWORD_'
    end
    config.ifname = assistant._interface
    writeState(assistant._name, config, true)
    return true
end

local function load_section(path)
    local r = dm.get(path)
    if r then
        local section = {}
        for _, v in ipairs(r) do
            section[v.param] = v.value
        end
        return section
    end
end

local function persist(assistant)
    local name = assistant._name
    local path = "uci.web.assist_state.@state_%s.%s"
    local enabled = assistant:enabled()
    local user = assistant._mgr.users[assistant._user]

    if assistant._persistent then
        --make sure the state section is present. We ignore the return value.
        --If it fails because it already exists, there is no problem.
        --If it fails for another reason, there is nothing we can do
        dm.add('uci.web.assist_state.', format('state_%s', name))
    else
        -- if the section is not there the following sets will fail, but
        -- that is OK as the end result will be the same: the assistant will
        -- not be restored on reboot
        -- the persisted state is 'disabled'
        enabled = false
    end

    local sets = {
        [path:format(name, 'enabled')] = enabled and '1' or '0',
        [path:format(name, 'port')] = tostring(assistant:port()),
        [path:format(name, 'salt')] = enabled and user.srp_salt or '',
        [path:format(name, 'verifier')] = enabled and user.srp_verifier or '',
    }
    dm.set(sets)
end

--- enable or disable the assistant
-- \param bActive (bool) if true enable else disable
-- \param bPermanent (bool) if true permanent mode else temporary mode
-- \param password:
--    if nil, random password is enabled
--    if string, clear text password is given by user
--    if table, srp salt/verifier is given by user
--    otherwise, previous password cfg will be used
-- \returns true if no error or nil, errmsg is case of error
function Assistant:enable(bActive, bPermanent, password)
    local changed = false
    bPermanent = bPermanent or self._persistent
    -- disable assistance if its cfg needs update
    if checkUpdate(self, bPermanent, password) and self:enabled() then
        local ok, msg = assistant_disable(self)
        if not ok then
            return nil, msg
        end
        changed = true
    end

    -- update cfg
    if not self:enabled() then
        updatecfg(self, bPermanent, password)
    end

    local r = true
    if bActive then
        -- enable assistance
        if not self:enabled() then
            r = assistant_enable(self)
            changed = true
        end
    else
        -- disable assistance
        if self:enabled() then
            r = assistant_disable(self)
            changed = true
        end
    end
    if changed then
        persist(self)
    end
    return r
end

local function restore(assistant)
    if not assistant._persistent then
        return
    end

    local state = load_section(format("uci.web.assist_state.@state_%s.", assistant._name))
    if (not state) or (state.enabled ~= '1') then
        return
    end

    local port = tonumber(untaint(state.port))
    if not port then
        return
    end
    state.port = port

    assistant._restore_state = state
    assistant:enable(true)
    assistant._restore_state = nil
end

-- timeout timer callback
local function disable_assistant(premature, assistant)
    assistant._timerRunning = false
    if premature then
        return
    end
    if not assistant_checkTimeout(assistant) then
        assistant_startTimer(assistant)
    end
end

-- generate a random port number in the configured range
local function genport(fromPort, toPort)
    local range=toPort-fromPort
    local r = 0
    if range>0 then
        r = random(range)-1
    end
    return fromPort+r
end

-- enable the assistant
function assistant_enable(self)
    local port
    if self._restore_state then
        port = self._restore_state.port
    else
        port = genport(self._fromPort, self._toPort)
    end
    local user = self._mgr.users[self._user]
    if user then
        control.user_lock(user)
        local psw, pwd
        if (self._pswcfg == nil) and not self._restore_state then
             psw = genpsw(10, self._pswchars)
             pwd = psw
        elseif type(self._pswcfg) == "string" then
             psw = self._pswcfg
        end
        if self._restore_state then
            --restore_state data comes from transformer, so they are tainted
            user.srp_salt = untaint(self._restore_state.salt)
            user.srp_verifier = untaint(self._restore_state.verifier)
            -- here we explicitly opt to set the password to an empty string
            -- this way no password is shown (but the actual password is set)
            self._psw = ""
        elseif psw then
            local salt, verifier = srp.new_user(self._user, psw)
            user.srp_salt = salt
            user.srp_verifier = verifier
            self._psw = psw
        else
            if self._pswcfg.salt then
                --salt and verifier specified
                user.srp_salt = self._pswcfg["salt"]
                user.srp_verifier = self._pswcfg["verifier"]
            end
            --set dummy password here as self._psw is used to check if the assistant is enabled or not
            self._psw = "_DUMMY_PASSWORD_"
        end
        self._port = port
        self._wanip = getInterfaceIP(self._interface) or ''
        self:activity()
        writeState(self._name, {
            wanip=self._wanip;
            wanport=tostring(port);
            lanport=self._lanport;
            enabled="1";
            password=pwd or '';
            mode = self._permanent and "1" or "0";
            ifname = self._interface
        })
        return true
    end
    return nil, "internal error: user disappeared"
end

--- get the external ip and port
-- only meaningfull if the assistant is enabled
function Assistant:getExternalAddress()
    return self._wanip, self._port
end

-- disable the assistant
function assistant_disable(self)
    local user = self._mgr.users[ self._user ]
    if user then
        control.user_unlock(user)
        -- this will disable login
        user.srp_verifier = ''
    end
    self._mgr:invalidateSessions()
    self._psw = nil
    self._port = nil
    self.timestamp = nil
    ngx.log(ngx.INFO, "disabled assistant ")
    local config = loadState(self._name)
    config.enabled="0"
    writeState(self._name, config)
    return true
end

function assistant_startTimer(self)
    if not self._timerRunning then
        local ok, err = ngx.timer.at(60, disable_assistant, self)
        if not ok then
            ngx.log(ngx.ERR, "failed to create assistant timer ", err)
        else
            self._timerrunning = true
        end
    end
end

--- Notify assistant of user activity in order to prevent a timeout
function Assistant:activity()
    -- in case the timer is not running we now have the opportunity to check
    -- the timer
    assistant_checkTimeout(self)

    -- if still active reset activity timer
    if self._psw then
        self.timestamp = clock_gettime(CLOCK_MONOTONIC)
        assistant_startTimer(self)
    end
end

--- check the timeout
-- \returns true if expired, false if not
-- if expired the assistant is disabled
function assistant_checkTimeout(self)
    local expired = not self._permanent and self.timestamp and (self.timestamp + self._timeout) < clock_gettime(CLOCK_MONOTONIC) or false
    if expired then
        self:enable(false)
    end
    return expired
end

local function newAssistant(config, sessionmgr)
    local persistent = false
    local timeout = tonumber(config.timeout)
    if not timeout then
        ngx.log(ngx.ERR, format("invalid timeout value (%s) for assistant %s", tostring(config.timeout), config._name))
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    if timeout<1 then
        if timeout==-1 then
            persistent = true
        else
            ngx.log(ngx.ERR, format("negative timeout value (%d) for assistant %s", timeout, config._name))
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end
    end
    local fromPort, toPort = config.port:match('^%s*(%d+)%s*-%s*(%d+)%s*$')
    if fromPort then
        fromPort = tonumber(fromPort)
        toPort = tonumber(toPort)
    else
        fromPort = tonumber(config.port)
        toPort = fromPort
    end
    if not( fromPort and toPort) then
        ngx.log(ngx.ERR, format("invalid port spec for assistant %s", config._name))
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    if toPort<fromPort then
        fromPort, toPort = toPort, fromPort
    end


    local assistant = {
        _name = config._name;
        _mgr = sessionmgr;
        _user = config.user;
        _timeout = timeout*60; --convert minutes to seconds
        _interface = config.interface;
        _lanport = control.mgrport(config.sessionmgr);
        _fromPort = fromPort;
        _toPort = toPort;
        _port = nil; --only set if enabled
        _psw = nil; --only set if enabled
        _pswchars = config.passwordchars;
        _persistent = persistent;
        _permanent = false;
        _pswcfg = nil;
    }
    return setmetatable(assistant, Assistant)
end

-- load the config data for the named assistant
-- \param name (string) the name of the assistant
-- \param defaults (table or nil) the default values
-- \returns a table with configured values (possibly with default) or nil
-- if there is no config for the assistant named
local function loadAssistanceConfig(name, defaults)
    local config
    local path=format("uci.web.assistance.@%s.", name)
    local cfg=dm.get(path)
    if cfg then
        config = defaults or {}
        for _, entry in ipairs(cfg) do
            if (entry.path==path) then
                local v = untaint(entry.value)
                if v~='' then
                    config[untaint(entry.param)] = v
                end
            end
        end
        config._name = name
    end
    return config
end

local function loadAssistant(name)
    local config = loadAssistanceConfig(name, {
        interface="wan",
        timeout=30,
        port="55000-56000",
-- valid password chars
-- leave out characters that can be confusing like:
-- 0 1 o O l I
        passwordchars="23456789abcdefghijkmnpqrstuvwxyz!@#$%*.ABCDEFGHJKLMNPQRSTUVWXYZ"
    })

    if not config then
        ngx.log(ngx.INFO, format("%s assistance not enabled", name))
        return
    end

    local mgrname = config.sessionmgr
    if not mgrname then
        ngx.log(ngx.ERR, format("assistant %s has no sessionmgr assigned", name))
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    if not config.user then
        ngx.log(ngx.ERR, format("assistant %s has no user assigned", name))
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local mgr = control.loadmgr(mgrname)
    if not mgr then
        ngx.log(ngx.ERR, format("session manager %s does not exist", mgrname))
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    local user = mgr.users[untaint(config.user or '')]
    if not user then
        ngx.log(ngx.ERR, format("session manager %s has no user %s", mgrname, config.user))
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local assistant = mgr.assistant
    if not assistant then
        assistant = newAssistant(config, mgr)
        mgr.assistant = assistant
    end
    return assistant
end

local assistants_info = {}

--- get the assistant
-- \param name (string) the name of the assistant to retrieve
-- \returns the assistant or nil if no assistant of that name is configured
-- This function will call ngx.exit on any configuration error.
function M.getAssistant(name)
    local info = assistants_info[name]
    if not info then
        -- no attempt to load the named assistant has been attempted yet.
        local assistant = loadAssistant(name)

        -- store the returned assistant in a table (even if it is nil)
        -- this allows us to remember we tried to load it
        info = {assistant=assistant}

        -- store in cache
        assistants_info[name] = info
    end
    return info.assistant
end

-- local module state variables
local enabled = false

-- enable remote assistance by loading all assistants
-- This has effect only once and must be called from the ngx access phase
-- and only if setup is done
function M.enable()
    if not enabled then
        if ngx.get_phase() ~= "access" then
          ngx.log(ngx.ERR, "web.assistance.enable() called outside access phase")
          ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        --list all configured assistant names
        local assistants = {}
        local cfg=dm.get("uci.web.assistance.")
        if cfg then
            for _, entry in ipairs(cfg) do
                -- extract the name
                local name = match(untaint(entry.path),'%.@([^.]*)%.')
                if name then
                    assistants[name] = true
                end
            end
        end
        -- load all assistants
        for name, _ in pairs(assistants) do
            local assistant = M.getAssistant(name)
            if assistant then
                restore(assistant)
            end
        end
        enabled = true
    end
end

return M
