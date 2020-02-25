local ngx, require = ngx, require
local proxy = require("datamodel")
local io = require("io")
local bit = require("bit")
local inet = require("tch.inet")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local pairs, ipairs, tonumber, type, setmetatable, next = pairs, ipairs, tonumber, type, setmetatable, next
local floor = math.floor
local open = io.open
local random, huge = math.random, math.huge
local istainted, format, match, find, sub, untaint, lower = string.istainted, string.format, string.match, string.find, string.sub, string.untaint, string.lower
local gsub, upper = string.gsub, string.upper
local concat, remove = table.concat, table.remove
local untaint_mt = require("web.taint").untaint_mt
local min = math.min
local max = math.max

local posix = require 'tch.posix'
local inet_pton = posix.inet_pton
-- Translation initialization. Every function relying on translation MUST call setlanguage to ensure the current
-- language is correctly set (it will fetch the language set by web.web and use it)
-- We create a dedicated context for the web framework (since we cannot easily access the context of the current page)
local intl = require("web.intl")
local function log_gettext_error(msg)
    ngx.log(ngx.NOTICE, msg)
end
local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext
local N = gettext.ngettext

local function setlanguage()
    gettext.language(ngx.header['Content-Language'])
end

local function errorsFound()
    checkUiMessages = false
    local session = ngx.ctx.session
    local err = session:retrieve("uimessages")
    for _, err in ipairs(err or {}) do
        if err.level == "error" then
            checkUiMessages = true
        end
    end
    return checkUiMessages
end

gettext.textdomain('web-framework-tch')

--- post_helper module
--  @module post_helper
--  @usage local post_helper = require('web.post_helper')
--  @usage require('web.post_helper')
local M = {}

-- Method to get all the LAN interfaces
-- @param #table allIntfs contains the available Interfaces(like wan, lan, loopback) and its details like ipv6uniquelocaladdr, paramindex, ipaddr
-- @return #table it returns the only LAN interface name and index values.
function M.getAllNonWirelessInterfaces(allIntfs)
  local lanIntfs = {}
  for _, intfs in ipairs(allIntfs) do
    if intfs.type == "lan" then
      local intfsName
      if intfs.name and intfs.name ~= "" then
        intfsName = intfs.name
      else
        intfsName = intfs.paramindex
      end
      lanIntfs[#lanIntfs + 1] = {name = intfsName, index = intfs.paramindex}
    end
  end
  return lanIntfs
end

--- Method to store the POST parameters sent by the UI in UCI (SAVE action)
-- @function [parent=#post_helper] handleQuery
-- @param #table mapParams key/string dictionary containing for each form control's name, the associated path
--                      this should be an exact path since we're going to write
--                      if you need to READ partial paths, please do so after this function has run
-- @param #table mapValidation key/function dictionary containing for each form control's name, the associated
--                      validation function. The validation function should return (err, msg). If err
--                      is nil, then msg should contain an error message, otherwise err should be true
-- @return #table,#table it returns a dictionary containing for each input name, the retrieved value from UCI
--          and another dictionary containing for each failed validation the help message
function M.handleQuery(mapParams, mapValidation)
    setlanguage()
    -- if GET, we'll need to retrieve everything. Code path in POST can change that based on input
    local content = {}
    local helpmsg = {}

    for k,v in pairs(mapParams) do
        content[k] = v
    end
    local success, errmsg = content_helper.getExactContent(content)
    if not success then
        message_helper.pushMessage(errmsg, "error")
        return content, helpmsg
    end

    -- Check if we're in a POST query or in a GET query, if POST only process on form encoded data
    if ngx.var.request_method == "POST" and ngx.var.content_type and match(ngx.var.content_type, "application/x%-www%-form%-urlencoded") then
        local post_data = ngx.req.get_post_args()

        if (post_data["action"] == "SAVE") then
            -- Save original data in case validation does remove some parameters
            local original_data = {}
            for k,v in pairs(content) do
                original_data[k] = v
            end
            -- now overwrite the data
            for k,v in pairs(post_data) do
                if mapParams[k] and not mapValidation[k] then
					message_helper.pushMessage("Validation missing for " .. k, "error")
                    ngx.log(ngx.ERR,"Validation missing for " .. k)
                    return content, helpmsg
                end
                content[k] = v
            end

            -- Start by applying the corresponding validation function to each parameter
            -- we receive.
            local validated
            validated, helpmsg = content_helper.validateObject(content, mapValidation)

            -- Now assuming that everything was validated, we can prepare to store the data

            if validated and not errorsFound() then
                for index, postcontent in pairs(content) do
                  -- Save only the updated values
                    if postcontent == original_data[index] then
                        content[index] = nil
                    end
                end
                local ok, msg = content_helper.setObject(content, mapParams)
                if ok then
                    if next(content) then
                        ok, msg = proxy.apply()
                    end
                    -- now in case some validation function removed some data, we bring it back from the original load
                    -- for instance, password validation will just remove the password data when getting the dummy value
                    for k in pairs(mapParams) do
                        if not content[k] then
                            content[k] = original_data[k]
                        end
                    end
                    if not ok then
                        ngx.log(ngx.ERR, "apply failed: " .. msg)
                        message_helper.pushMessage(T"Error while applying changes", "error")
                    else
                        message_helper.pushMessage(T"Changes saved successfully", "success")
                    end
                else
                    for _,v in ipairs (msg) do
                        ngx.log(ngx.ERR, "setObject failed on " .. v.path .. ": " .. v.errcode .. " " .. v.errmsg)
                    end
                    message_helper.pushMessage(T"Error while saving changes", "error")
                    -- we cannot assume every transaction is atomic (not every mapping will implement it) so to be safe
                    -- we reload the data
                    for k,v in pairs(mapParams) do
                        content[k] = v
                    end
                    content_helper.getExactContent(content)
                end
            else
				local err_msg = {}
				err_msg[#err_msg+1] = T"Some parameters failed validation"
				err_msg[#err_msg+1] = "<br/>"
				for i , j in pairs(helpmsg) do
					err_msg[#err_msg+1] = "<strong>" .. i .. "</strong>" .. ": " .. j .. "<br/>"
				end
				message_helper.pushMessage(table.concat(err_msg) , "error")
            end
        end
    end

    return content, helpmsg
end

--- Merge two tables. Take the content of toadd and put it in content overwriting any existing element
-- @function [parent=#post_helper] mergeTables
-- @param #table content the main table
-- @param #table toadd the table to add to the main table
-- @return nothing but content is updated
function M.mergeTables(content, toadd)
    if content == nil then
        content = {}
    end
    if toadd == nil then
        return
    end
    for _,v in ipairs(toadd) do
        content[v.param] = v.value
    end
end

---
-- Converts a columns table to a input name => transformer name table
-- @param #table columns structure
-- @param #bool withro [optional] also include parameters set as readonly
-- @return #table map
local function columnsToParamMap(columns, withro)
    local map = {}
    for _,v in ipairs(columns) do
        if v.type == "aggregate" then
            for _, sv in ipairs(v.subcolumns) do
                if withro or not sv.readonly then
                    map[sv.name] = sv.param
                end
            end
        else
            if withro or not v.readonly then
                map[v.name] = v.param
            end
        end
    end
    return map
end

-- Construct an time string from the number of seconds
-- @param #number time
-- @return #string number of seconds
function M.secondsToTime(time)
  setlanguage()
  local time_no = tonumber(time)
  if (time_no and time_no >= 0) then
    local durations = {
      floor(time_no / 86400),      -- days
      floor(time_no / 3600) % 24,  -- hours
      floor(time_no / 60) % 60,    -- minutes
      floor(time_no) % 60          -- seconds
    }
    local start = 4
    local duration = durations[4]
    durations[4] = format(N("%d second", "%d seconds", duration), duration)
    duration = durations[3]
    if duration > 0 then
      start = 3
    end
    durations[3] = format(N("%d minute", "%d minutes", duration), duration)
    duration = durations[2]
    if duration > 0 then
      start = 2
    end
    durations[2] = format(N("%d hour", "%d hours", duration), duration)
    duration = durations[1]
    if duration > 0 then
      start = 1
    end
    durations[1] = format(N("%d day", "%d days", duration), duration)
    return concat(durations, " ", start)
  end
  return nil, T"Positive number expected."
end

-- Construct an time string from the number of seconds
-- @param #number time
-- @return #string number of seconds
function M.secondsToTimeShort(time)
  setlanguage()
  local time_no = tonumber(time)
  if (time_no and time_no >= 0) then
    local durations = {
      floor(time_no / 86400),      -- days
      floor(time_no / 3600) % 24,  -- hours
      floor(time_no / 60) % 60,    -- minutes
	  floor(time_no) % 60          -- seconds
    }
    local start = 4
    local duration = durations[4]
    durations[4] = format(N("%ds", "%ds", duration), duration)
    duration = durations[3]
    if duration > 0 then
      start = 3
    end
    durations[3] = format(N("%dm", "%dm", duration), duration)
    duration = durations[2]
    if duration > 0 then
      start = 2
    end
    durations[2] = format(N("%dh", "%dh", duration), duration)
    duration = durations[1]
    if duration > 0 then
      start = 1
    end
    durations[1] = format(N("%dd", "%dd", duration), duration)
    return concat(durations, " ", start)
  end
  return nil, T"Positive number expected."
end

-- Ensuring the integrity of the changes made to a table
-- modify -> might overwrite previous changes, or line could have been deleted - check when starting the change and when applying the change
-- delete -> might try to delete something that was already deleted
-- add -> fine nothing to fear (still need proper validation)
--
-- when trying to apply the change, check if changes were made in between
-- to know if a change is allowed, one thing needs to be considered: did we load the page before or after the last change
--
-- every time there is a change to a table, I generate a new stateId
-- when I load a table, I include the current stateId in the data sent to the browser
-- when I submit something, I include the transactionId
-- the server compares the transactionId in the query and the one in the session store
-- - if they're the same, we make the change
-- - if they're different, we cancel the query and show a warning message telling the user changes took place and he should start again
--
-- NOTE: this mechanism should actually be implemented at a "global" level rather than session level. We need to take into account changes that
--       could be made by another user or another browser session
local function generateStateId()
    -- TODO: use something more robust
    return "stateid." .. random()
end

--- Checks if the state sent by the client corresponds to the one stored in the session
--  If not, then changes happened between the time we displayed the page and now, so the
--  user must start again
-- @param #string server
-- @param #string client
local function checkStateId(server, client)
    if server == nil and client == "" then
        return true
    end
    if server == client then
        return true
    end
    return false
end

local changesNotAllowed = "Changes not allowed."
local changesconflictMsg = "Changes were made to this table which require you to start again."
local invalidIndexMsg = "You tried to access an invalid line."
local errorWhileSaving = "An error occured while saving your changes."
local errorWhileApplying = "An error occured while applying your changes."

--- apply changes if successful, other set error message in the options object
-- @param #bool success result from the proxy call
-- @param #bool canApply
-- @param #table options
local function applyOnSuccess(success, canApply, options)
    if success then
        if canApply == true then
            proxy.apply()
        end
    else
      options.errmsg = T(errorWhileSaving)
    end
end

--- this function retrieves any missing data vs the data provided in the post
-- this is used to validate the full dataset instead of just one parameter
-- otherwise it could be possible to
-- @param #string indexpath
-- @param #string index
-- @param #table postdata data sent by the user in the post query
-- @param #table mapparam complete list of parameters for the columns
-- @param #table mapvalid validation functions
local function getObjectAndValidate(indexpath, index, postdata, mapparam, mapvalid)
    local toretrieve = {}
    for k,v in pairs(mapparam) do
        if not postdata[k] then
            toretrieve[k] = indexpath .. index .. "." .. v
        end
    end
    local success = content_helper.getExactContent(toretrieve)
    if success then
        for k,v in pairs(toretrieve) do
           postdata[k] = v
        end
    end
    return content_helper.validateObject(postdata, mapvalid)
end

local function complementObjectAndValidate(postdata, mapparam, mapvalid)
    for k,v in pairs(mapparam) do
        if not postdata[k] then
          postdata[k] = "" -- put a default value to get it through validation, it should have been sent in the post data
        end
    end
    return content_helper.validateObject(postdata, mapvalid)
end

local function checkUniqueParams(basepath, fullpath, columns, content)
  local success = true
  local helpmsg = {}

  for _,v in ipairs(columns) do
    if v.unique then
      local value = string.untaint(content[v.name])
      local cmatch = content_helper.getMatchedContent(basepath, { [v.param] = value })
      if fullpath then
        for i,v in ipairs(cmatch) do
          if v.path == fullpath then
            remove(cmatch, i)
            break
          end
        end
      end
      if #cmatch > 0 then
        success = nil
        helpmsg[v.name] = T"duplicate value"
      end
    end
  end
  return success, helpmsg
end

local function convertPostToArray(columns, data)
    local line = {}
    for _,v in ipairs(columns) do
        if v.type == "aggregate" then
            line[#line+1] = convertPostToArray(v.subcolumns, data)
        else
            line[#line+1] = data[v.name]
        end
    end
    return line
end

local function applyGlobalValidation(basepath, columns, filter, paramindex, content, valid, sorted)
    if valid then
        local data, allowedIndexes = content_helper.loadTableData(basepath, columns, filter, sorted)
        local idx

        if paramindex then
            -- Modify or Delete
            for i,v in ipairs(allowedIndexes) do
                -- We're looking at the actual instance index because the order in which elements are returned is not
                -- always stable. So just to be sure, we find the correct index based on the paramindex of the element
                if paramindex == v.paramindex then
                    idx = i
                end
            end

            -- If idx was not found, then something is completely wrong
            if not idx then
               return nil
            end
        else
            idx = #data + 1
        end

        if content == nil then
            -- Delete case
            remove(data, idx)
        else
            -- Add / Modify case
            data[idx] = convertPostToArray(columns, content)
        end
        return valid(data)
    else
        return true
    end
end

--- Method to handle queries generated by standard UI tables
-- @function [parent=#post_helper] handleTableQuery
-- @param #table columns array describing each column of the table
-- @param #table options table containing options for the table
--               canEdit - bool indicating if we should allow editing a line
--               canAddDelete - bool indicating if we should allow adding / removing lines
--               canApply - bool indicating if we should allow restart related module after uci changes
--               editing - int - index of the currently edited element (-1 if new element, 0 if not editing)
--               minEntries - int - minimum number of entries in the table (will prevent delete under this number)
--               maxEntries - int - maximum number of entries in the table (will prevent adding above this number)
--               tableid - string - id of the table
--               basepath - string - base path for parameters in transformer
--               stateid - string - token used to detect if changes happened since the page was displayed
--               errmsg - string - global error message (for the table) to display
--               sorted - string or function - sorted method for table data
-- @param filter function that accepts a line data as the input and returns true if it should be included
--               or false otherwise
-- @param #table defaultObject table or nil (transformer param name => value)
--               1) table that is merged with the data gathered from the form before being written
--               2) nil just use the data gathered from the form without change
-- @param #table mapValidation for each input name maps to a function that returns true if the value is "valid"
--               or returns false if the value is invalid
-- @return #table, #table
function M.handleTableQuery(columns, options, filter, defaultObject, mapValidation)
    setlanguage()
    local data, allowedIndexes
    local helpmsg = {}
    local content = {}
    local paramMap = columnsToParamMap(columns)
    local basepath = options.basepath or ""
    local addpath, indexpath, instanceprefix = content_helper.getPaths(basepath)
    local session = ngx.ctx.session

    if options == nil then
        options = {}
    end
    -- options and their default value
    -- do we allow to edit a table entry?
    local canEdit = options and not (options.canEdit == false) or true
    -- do we allow to add and delete entries
    local canAdd = options and not (options.canAdd == false) or true
    local canDelete = options and not (options.canDelete == false) or true
    -- do we add a named object
    local addNamedObject = options and (options.addNamedObject == true)
    -- do we allow to restart related module after uci is changed
    local canApply = options and not (options.canApply == false)
    -- are we editing an entry and which line (-1 means new entry)
    local editing = options and tonumber(options.editing) or 0
    -- do we disallow delete if under a certain number of entries
    local minEntries = options and tonumber(options.minEntries) or 0
    -- do we disallow adding if above a certain number of entries
    local maxEntries = options and options.maxEntries or huge
    local newList = options and options.newList
    local sorted = options and options.sorted
    local tablesessionkey = options.tableid .. ".stateid"
    local tablesessionindexes = options.tableid .. ".allowedindexes"
    local globalValidation = options.valid
    local sendBackUserData = false
    local success
    local validated

    -- Check if we're in a POST query or in a GET query
    if ngx.var.request_method == "POST" and ngx.var.content_type and match(ngx.var.content_type, "application/x%-www%-form%-urlencoded") then
        content = ngx.req.get_post_args()
        local action = content.action
        local index = tonumber(content.index) or -1
        local sid = options.tableid
        local cid = content.tableid
        local sstateid = session:retrieve(tablesessionkey)
        local cstateid = content.stateid
        allowedIndexes = session:retrieve(tablesessionindexes) or {}

        -- Kept because Voice pages depend on it but this was really not a well though modification...
        if allowedIndexes[index] then
            options.changesessionindex = allowedIndexes[index].paramindex
        end
        -- Check if the POST is for this table or another one in the page
        -- for this compare the id parameter in options and in the POST query
        if(sid ~= nil and sid == cid) then
            -- Check the action POST parameter to know what to do
            -- User wants to delete a line
            if action == "TABLE-DELETE" and canDelete then
                -- Check if changes happened in between
                if checkStateId(sstateid, cstateid) == true then
                    -- User clicked on the DELETE button of a line
                    if index and allowedIndexes[index] then
                        if allowedIndexes[index].canDelete then
                            validated, helpmsg = applyGlobalValidation(basepath, columns, filter, allowedIndexes[index].paramindex, nil, globalValidation, sorted)
                            if validated == true then
                                success = proxy.del(indexpath .. allowedIndexes[index].paramindex .. ".")
                                if type(options.onDelete) == "function" and success then
                                    options.onDelete(allowedIndexes[index].paramindex)
                                end
                                applyOnSuccess(success, canApply, options)
                                session:store(tablesessionkey, generateStateId())
                            end
                        else
                            options.errmsg = T(changesNotAllowed)
                        end
                    else
                        options.errmsg = T(invalidIndexMsg);
                    end
                else
                    options.errmsg = T(changesconflictMsg)
                end
                -- User wants to edit a line
            elseif action == "TABLE-EDIT" and canEdit then
                -- Check if changes happened in between
                if checkStateId(sstateid, cstateid) == true then
                    -- User clicked on the EDIT button
                    if index and allowedIndexes[index] then
                        if allowedIndexes[index].canEdit then
                            options.editing = index
                        else
                            options.errmsg = T(changesNotAllowed)
                        end
                    else
                        options.errmsg = T(invalidIndexMsg);
                    end
                else
                    options.errmsg = T(changesconflictMsg)
                end
                -- User wants to apply the changes to a line
            elseif action == "TABLE-MODIFY" and canEdit then
                -- Check if changes happened in between
                if checkStateId(sstateid, cstateid) == true then
                    -- User clicked on the SAVE button after starting a modify "session"
                    if index and allowedIndexes[index] then
                        if allowedIndexes[index].canEdit then
                            validated, helpmsg = getObjectAndValidate(indexpath, allowedIndexes[index].paramindex, content, paramMap, mapValidation)
                            if validated == true then
                                validated, helpmsg = checkUniqueParams(basepath, indexpath .. allowedIndexes[index].paramindex .. ".", columns, content)
                            end
                            if validated == true then
                                validated, helpmsg = applyGlobalValidation(basepath, columns, filter, allowedIndexes[index].paramindex, content, globalValidation, sorted)
                            end
                            if validated == true then
                                success = content_helper.setObject(content, paramMap, indexpath .. allowedIndexes[index].paramindex .. ".", defaultObject)
                                if type(options.onModify) == "function" and success then
                                    options.onModify(allowedIndexes[index].paramindex, content)
                                end
                                applyOnSuccess(success, canApply, options)
                                session:store(tablesessionkey, generateStateId())
                            else
                                -- Stay in editing mode
                                options.editing = index
                                sendBackUserData = true
                            end
                        else
                            options.errmsg = T(changesNotAllowed)
                        end
                    else
                        options.errmsg = T(invalidIndexMsg);
                    end
                else
                    options.errmsg = T(changesconflictMsg)
                end
                -- User wants to cancel the edition of the line without saving
            elseif action == "TABLE-CANCEL" then
                -- User clicked on the CANCEL button after starting a modify "session"
                options.editing = 0
            elseif action == "TABLE-ADD" and canAdd then
                -- User clicked on the ADD button
                validated, helpmsg = complementObjectAndValidate(content, paramMap, mapValidation)
                if validated == true then
                    validated, helpmsg = checkUniqueParams(basepath, nil, columns, content)
                end
                if validated == true then
                    validated, helpmsg = applyGlobalValidation(basepath, columns, filter, nil, content, globalValidation, sorted)
                end
                if validated == true then
                    if addNamedObject == true then
                        local firstColumnValue = format("%s", content[columns[1].name])
                        --options.objectName given name is the 1st choice
                        --If no such given name, the value of the 1st column should be set as object name
                        local objectName = options.objectName or firstColumnValue
                        success = content_helper.addNewObject(basepath, content, paramMap, defaultObject, objectName)
                    else
                        success = content_helper.addNewObject(basepath, content, paramMap, defaultObject)
                    end
                    if type(options.onAdd) == "function" and success then
                        options.onAdd(success, content)
                    end
                    applyOnSuccess(success, canApply, options)
                    options.editing = 0
                else
                    sendBackUserData = true
                    options.editing = -1
                end
            elseif action == "TABLE-NEW" and canAdd then
                -- User clicked on the Create New button
                options.editing = -1
            elseif action == "TABLE-NEW-LIST" and canAdd then
                -- User clicked on one of the predefined elements in the predefined list
                local listid = tonumber(content.listid)
                options.editing = -1
                -- Set the defaults defined in the newList variable
                if newList ~= nil and listid ~= nil and listid then
                    if newList[listid] ~= nil then
                        local values = newList[listid].values
                        for _,v in ipairs(columns) do
                            v.default = values[v.name] or v.default or ""
                        end
                    end
                end
            end
        end
    end

    -- retrieve the current state id so that it can be included in the table
    options.stateid = session:retrieve(tablesessionkey) or ""
    -- retrieve the data to load in the table
    data, allowedIndexes = content_helper.loadTableData(basepath, columns, filter, sorted)
    -- store the allowed indexes in the session datastore and verify that changes are allowed
    session:store(tablesessionindexes, allowedIndexes)

    -- if the user entered invalid values, we must send them back in the form so that he can modify
    -- them but at the same time does not lose the other changes he made
    if sendBackUserData == true then
        if options.editing == -1 then
            -- we need to put the input in the add line at the bottom, we'll use the default values for that
            for _,v in ipairs(columns) do
              if v.type == "aggregate" then
                for _,s in ipairs(v.subcolumns) do
                  s.default = content[s.name] or s.default or ""
                end
              else
                v.default = content[v.name] or v.default or ""
              end
            end
        else
            -- we need to modify the loaded data and replace the loaded elements with the ones that were sent by the user
            local userData = {}
            for _,v in ipairs(columns) do
                -- for r/o fields, we need to take the actual data
                if v.type == "aggregate" then
                  local sdata = {}
                  for _,s in ipairs(v.subcolumns) do
                    sdata[#sdata + 1] =  content[s.name] or data[options.editing][#sdata + 1] or ""
                  end
                    userData[#userData + 1] = sdata
                else
                  userData[#userData + 1] = content[v.name] or data[options.editing][#userData + 1] or ""
                end
            end
            data[options.editing] = userData
        end
    end

    return data, helpmsg
end

local function alwaysTrue()
    return true
end

local function alwaysFalse()
    return false, "" -- this is used in the context of a validation function and false means there is an help message
end

---
-- @function [parent=#post_helper] validateNonEmptyString
-- @param value
-- @return #boolean, #string
function M.validateNonEmptyString(value)
    if type(value) ~= "string" and not istainted(value) then
        return nil, T"Received a non string value."
    end
    if #value == 0 then
        return nil, T"String cannot be empty."
    end
    return true
end

--- Returns the type of IP address the string is
-- Based on http://stackoverflow.com/a/16643628
-- @param #string ip the string representing the ip address
-- @return #number 0 = error
--                 4 = ipv4
--                 6 = ipv6
function M.GetIPType(ip)
    ip = string.untaint(ip)
    if ip and inet.isValidIPv4(ip) then
       return 4
    elseif ip and inet.isValidIPv6(ip) then
       return 6
    end
    return 0
end
local GetIPType = M.GetIPType
---
-- @function [parent=#post_helper] validateStringIsIP
-- @param value
-- @return #boolean, #string
function M.validateStringIsIP(value)
    local iptype = GetIPType(value)
    if iptype == 4 or iptype == 6 then
        return true
    end
    return nil, T"Invalid IP address."
end

---
-- This function is used to validate MAC address format and reserved MAC address.
-- the [value] a valid MAC address format
-- the [value] is not the reserved MAC address based on the RFC7042
-- don't allow if mac address is in Mulicast or Unicast or IPv6 mulicast or PPP ranges.
-- @param value
-- @return true or nil+error message
local mac_pattern1 = "^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$"
local mac_pattern2 = "^%x%x%-%x%x%-%x%x%-%x%x%-%x%x%-%x%x$"
function M.validateStringIsMAC(value)
    local mac
    if not value then
        return nil, T"Invalid input"
    end
    if value:match(mac_pattern1) then
        mac = gsub(value,":","")
    elseif value:match(mac_pattern2) then
        mac = gsub(value,"-","")
    else
        return nil, T"Invalid MAC address, it must be of the form 00:11:22:33:44:55 or 00-11-22-33-44-55"
    end

    mac = upper(mac)
    if mac == "000000000000" or mac == "FFFFFFFFFFFF" then
        return nil, T"Invalid MAC address"
    end

    --reference link: https://tools.ietf.org/html/rfc7042
    --validate Reserved MAC filtering functionality. It is validating that:
    --Multicast identifiers from 01-00-5E-00-00-00 to 01-00-5E-FF-FF-FF
    --Unicast identifiers from 00-00-5E-00-00-00 to 00-00-5E-FF-FF-FF
    --IPv6 multicast identifiers from 33-33-00-00-00-00 to 33-33-FF-FF-FF-FF
    --PPP identified from CF-00-00-00-00-00 to CF-FF-FF-FF-FF-FF
    if (match(mac, "^0[01]005E")) or (sub(mac, 1, 4) == "3333") or (sub(mac, 1, 2) == "CF") then
        return nil, T"Reserved MAC address"
    end
    return true
end

---
-- Check whether the received 'value' has the syntax of a domain name [RFC 1123]
-- @function [parent=#post_helper] validateStringIsDomainName
-- @param value
-- @return #boolean, #string
function M.validateStringIsDomainName(value)
    if type(value) ~= "string" and not istainted(value) then
        return nil, T"Received a non string value."
    end
    if #value == 0 then
        return nil, T"Domain name cannot be empty."
    end

    if #value > 255 then
        return nil, T"Received domain name is too long."
    end

    local i=0
    local j=0

    repeat
        i = i+1
        j = find(value, ".", i, true)
        local label = sub(value, i, j)
        local strippedLabel = match(label, "[^%.]*")
        if strippedLabel ~= nil then
            if #strippedLabel == 0 then
                return nil, T"Empty label not allowed."
            end
            if #strippedLabel > 63 then
                return nil, T"Domain name contains a label that is longer than 63 characters."
            end
            local correctLabel = match(strippedLabel, "^[a-zA-z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9]")
            if #strippedLabel == 1 then
                if not match(strippedLabel, "[a-zA-Z0-9]") then
                    return nil, T"Label within domain name has invalid syntax."

                end
            elseif strippedLabel ~= correctLabel then
                return nil, T"Label within domain name has invalid syntax."
            end
        end

        i = j
    until not j

    return true
end

---
-- @function [parent=#post_helper] validateBoolean
-- @param value
-- @return #boolean, #string
function M.validateBoolean(value)
    value = tonumber(value)
    if value == 1 or value == 0 then
        return true
    end
    return nil, T"0 or 1 expected."
end

---
-- Strips leading zeroes and whitespaces from port number and Validates it
-- If valid, Saves the port number to the corresponding input field in GUI
-- @function [parent=#post_helper] validateStringIsPort
-- @param value
-- @return #boolean, #string
function M.validateStringIsPort(value,data,key)
    value = value and match(value, "^[%s0]*(%d+)%s*$")
    local port = value and tonumber(value)
    if port and (floor(port) == port) and port >= 1 and port < 65536 then
        if data and key then
            data[key] = value
        end
        return true
    end
    return nil, T"Port is invalid. It should be between 1 and 65535 or it must be of format port1:port2 with port1 <= port2."
end

---
-- Strips leading zeroes and whitespaces from port numbers and Validates the port range
-- If valid, Saves the port range to the corresponding input field in GUI
-- @function [parent=#post_helper] validateStringIsPortRange
-- @param value
-- @return #boolean, #string
local portrange_pattern = "^[%s0]*(%d+)%s*%:[%s0]*(%d+)%s*$"
function M.validateStringIsPortRange(value,data,key)
    if not value then
        return nil, T"Invalid port range."
    end
    local p1, p2 = match(value, portrange_pattern)
    if p1 then
        local isStart, errStart = M.validateStringIsPort(p1)
        local isEnd, errEnd = M.validateStringIsPort(p2)
        if errStart then
          return nil, errStart
        elseif errEnd then
          return nil, errEnd
        end
        if isStart and isEnd and tonumber(p1) <= tonumber(p2) then
            data[key] = p1 .. ":" .. p2
            return true
        else
            return nil, T"Port range is invalid, it must be of format port1:port2 with port1 <= port2."
        end
    else
        return M.validateStringIsPort(value,data,key)
    end
end

---
-- @function [parent=#post_helper] validatePositiveNum
-- @param value
-- -- @return #boolean, #string
function M.validatePositiveNum(value)
    local num = tonumber(value)
    if (num and num >= 0) then
        return true
    end
    return nil, T"Positive number expected."
end

---
-- Return a function that can be used to validate if the input is a number between min and max (inclusive)
-- If min is nil or max is nil, it won't check for it
-- @function [parent=#post_helper] getValidateNumberInRange
-- @param #number min
-- @param #number max
-- @return #boolean, #string
function M.getValidateNumberInRange(min, max)
    local helptext = T"Input must be a number."
    if min and max then
        helptext = format(T"Input must be a number between %d and %d included.", min, max)
    elseif not min and not max then
        helptext = T"Input must be a number."
    elseif not min then
        helptext = format(T"Input must be a number smaller than %d included.", max)
    elseif not max then
        helptext = format(T"Input must be a number greater than %d included.", min)
    end

    return function(value)
        local num = tonumber(value)
        if not num then
            return nil, helptext
        end
        if min and num < min then
            return nil, helptext
        end
        if max and num > max then
            return nil, helptext
        end
        return true
    end
end

-- Return a function that can be used to validate if the input is a whole number
-- @function [parent=#post_helper] getValidateWholeNumber
-- @param #number value
-- @return #boolean, #string

function M.getValidateWholeNumber(value)
  local helptext = T"Input must be a whole number."
  --Check to see if the given string is a whole number
  if not (value and value:match("^%d+$")) then
    return nil, helptext
  end
  return true
end

---
-- @function [parent=#post_helper] validateRegExpire
-- @param value
-- @param min
-- @param max
-- --@return #boolean, #string
function M.validateRegExpire (value)
    local num = tonumber (value)
    if num and num >= 60 and num <= 600000 and M.getValidateWholeNumber(value) then
        return true
    end
    return nil, T"Expire Time is invalid. It should be a whole number, between 60 and 600000."
end

---
-- Return a function that can be used to validate if the given value/array is part of the choices
-- It also does some processing on the data to normalize it for use.
-- If only one checkbox is selected, then we don't get an array -> make an array of one element
-- @function [parent=#post_helper] getValidateInCheckboxgroup
-- @param #table enum array of entries of a select input
-- @return #boolean, #string
function M.getValidateInCheckboxgroup(enum)
    local choices = setmetatable({}, untaint_mt)

    -- store that as a dictionnary, will make it simpler
    for _,v in ipairs(enum) do
        choices[v[1]] = true
    end

    return function(value, object, key)
        local uv
        local canary
        local canaryvalue = ""

        if not value then
            return nil, T"Invalid input."
        end

        if type(value) == "table" then
            uv = value
        else
            uv = { value }
        end
        object[key] = uv
        for i,v in ipairs(uv) do
            if v == canaryvalue then
                canary = i
            elseif not choices[v] then
               return nil, T"Invalid value."
            end
        end
        if canary then
            remove(uv, canary)
        end
        return true
    end
end

---
-- Return a function that can be used to validate if the checkbox for switch is checked or not,
-- If the checkbox is checked, then the corresponding value in the post array is set "1", otherwise "0"
-- @function [parent=#post_helper] getValidateInCheckboxgroup
-- @return #boolean, #string
function M.getValidateCheckboxSwitch()
    --return true or nil
    return function(value, object, key)
        if not value then
            return nil, T"Invalid input."
        end

        if type(value) == "table" then
          for k,v in pairs(value) do
            if (v ~= "_DUMMY_" and  v ~= "_TRUE_") then
              return nil, T"Invalid value."
            end
          end
          object[key] = "1"
          return true
        else
          if (value == "_DUMMY_") then
            object[key] = "0"
            return true
          else
            return nil, T"Invalid value."
          end
        end
    end
end

---
-- Return a function that can be used to validate if the given value is part of the choices
-- @function [parent=#post_helper] getValidateInEnumSelect
-- @param #table enum array of entries of a select input
-- @return #boolean, #string
function M.getValidateInEnumSelect(enum)
    local choices = setmetatable({}, untaint_mt)

    -- store that as a dictionnary, will make it simpler
    for _,v in ipairs(enum) do
        choices[v[1]] = true
    end

    return function(value)
        return choices[value], T"Invalid value."
    end
end

---
-- Return a function that can be used to validate if a string's length is greater or equal to length
-- @function [parent=#post_helper] getValidateStringLength
-- @param #number length minimum length of the string
-- @return #boolean, #string
function M.getValidateStringLength(length)
    return function(value)
        if type(value) ~= "string" and not istainted(value) then
            return nil, T"Received a non string value."
        end
        if #value < length then
            return nil, format(T"String must be at least %d characters long.", length)
        end
        return true
    end
end

---
-- Return a function that can be used to validate if the string length is between l1 and l2 (included)
-- @function [parent=#post_helper] getValidateStringLengthInRange
-- @param #number minl minimum length of the string
-- @param #number maxl maximum length of the string
-- @return #boolean, #string
function M.getValidateStringLengthInRange(minl, maxl)
    return function(value)
        if type(value) ~= "string" and not istainted(value) then
            return nil, T"Received a non string value."
        end
        if #value < minl or #value > maxl then
            return nil, format(T"String must be between %1$d and %2$d characters long.", minl, maxl)
        end
        return true
    end
end

---
-- Return a validation function that will be enabled only if a given property is present otherwise remove the parameter from the object and return true
-- @function [parent=#post_helper] getValidationIfPropInList
-- @param validation function (prototype is of type (value, object)
-- @param #string prop name of the property used as a trigger
-- @param #table values array of values that should trigger the behavior
-- @return validation function
function M.getValidationIfPropInList(func, prop, values)
    local options = setmetatable({}, untaint_mt)

    -- store that as a dictionnary, will make it simpler
    for _,v in ipairs(values) do
        options[v] = true
    end

    -- This function should apply the given validation function if the property is in the allowed values otherwise remove the parameter from the object and return true
    return function(value, object, key)
        if not object then
            return true
        end
        if object[prop] and options[object[prop]] then
            return func(value, object, key)
        end
        object[key] = nil
        return true
    end
end

---
-- Return a validation function that will be enabled only if a given checkboxswitch property is present otherwise remove the parameter from the object and return true
-- @function [parent=#post_helper] getValidationIfPropInList
-- @param validation function (prototype is of type (value, object)
-- @param #string prop name of the property used as a trigger
-- @param #table values array of values that should trigger the behavior
-- @return validation function
function M.getValidationIfCheckboxSwitchPropInList(func, prop, values)
    local options = setmetatable({}, untaint_mt)

    -- store that as a dictionnary, will make it simpler
    for _,v in ipairs(values) do
        options[v] = true
    end

    -- This function should apply the given validation function if the property is in the allowed values otherwise remove the parameter from the object and return true
    return function(value, object, key)
        if not object then
            return true
        end
        if object[prop] then
            -- Before M.getValidateCheckboxSwitch is called,
            -- the post value of a switchcheck box is still {"_DUMMY_", "_TRUE_"} or "_DUMMY_"
            -- these values need to be converted to "1" or "0"
            local property = object[prop]
            if type(property) == "table" then
                for k,v in pairs(property) do
                    if (v ~= "_DUMMY_" and  v ~= "_TRUE_")  then
                        return nil, T"Invalid value."
                    end
                end
                property = "1"
            elseif (property == "_DUMMY_") then
                property = "0"
            end
            if options[property] then
                return func(value, object, key)
            end
        end
        object[key] = nil
        return true
    end
end

---
-- @function [parent=#post_helper] validateStringIsLeaseTime
-- @param value
-- @return #boolean, #string
function M.validateStringIsLeaseTime(value)
    if not value then
        return nil, T"Invalid value."
    end
    local leasetime_pattern = "^(%d+)([wdhms])$"
    local leaseTime = setmetatable({
        s = 1814400,
        m = 30240,
        h = 504,
        d = 21,
        w = 3,
    }, untaint_mt)
    local number, precision = value:match(leasetime_pattern)
    number = number and tonumber(number)
    if not number or number < 1 then
        return nil, T"Invalid value; enter 'infinite' for infinite time or a number greater than 0, followed by 's' for seconds or 'm' for minutes or 'h' for hours or 'd' for days or 'w' for weeks. No spaces."
    end
    if (((precision == "s") and (number < 120)) or
        ((precision == "m") and (number < 2))) then
        return nil, T"The minimum leasetime must be 120 seconds or 2 minutes."
    elseif leaseTime[precision] and number > leaseTime[precision] then
        return nil, T"The Maximum leasetime must be 3 weeks or 21 days or 504 hours or 30240 minutes or 1814400 seconds."
    end
    return true
end

---
-- The object of this function is to not modify the password when we receive the predefined
-- dummy value ********. If we do, we remove it from the post data so that this parameter
-- won't be written to transformer. You can pass an additional validation function that will
-- be called on a "modified" value to add for instance password strength check
-- @function [parent=#post_helper] getValidationPassword
-- @param #function additionalvalid
-- @return #function
function M.getValidationPassword(additionalvalid)
    return function(value, object, key)
        -- Check if this is the "dummy" value. If it is, we must remove it,
        -- we don't want to store it
        -- TODO: find a better dummy value
        -- TODO: define better
        -- TODO: make a version that checks the password strength as well
        if value == "********" then
            object[key] = nil
            return true
        end
        if type(additionalvalid) == "function" then
            return additionalvalid(value, object, key)
        end
        return true
    end
end

---
-- This function will allow to only apply validation if the value is non empty / nil
-- This is useful in the case of an optional parameter that has to nonetheless follow
-- a certain format
-- @function [parent=#post_helper] getOptionalValidation
-- @param #function additionalvalid
-- @return #function
function M.getOptionalValidation(additionalvalid)
    local av = additionalvalid
    if type(av) ~= "function" then
        av = alwaysTrue
    end

    return function(value, object, key)
        if not value or value == "" then
            return true
        end
        return av(value, object, key)
    end
end

---
-- This function will apply different validation function based on the outcome of the condition function
-- Helpful when needing to apply different validations / operations based on other elements
-- @function [parent=#post_helper] getConditionalValidation
-- @param #function condition the test function to decide which validation function to apply (uses the same prototype as validation function)
-- @param #function istrue validation function to apply if condition returns true (uses always true if not a function)
-- @param #function isfalse validation function to apply if condition returns false (uses always true if not a function)
-- @return #function
function M.getConditionalValidation(condition, istrue, isfalse)
    local t, f = istrue, isfalse
    if type(t) ~= "function" then
        t = alwaysTrue
    end
    if type(f) ~= "function" then
        f = alwaysTrue
    end

    return function(value, object, key)
        if type(condition) == "function" then
            if condition(value, object, key) then
                return t(value, object, key)
            else
                return f(value, object, key)
            end
        end
        return true
    end
end

local function onlyFunctions(validators)
    local onlyFunc = {}
    for _, v in pairs(validators) do
      if type(v) == "function" then
        onlyFunc[#onlyFunc + 1] = v
      end
    end
    return onlyFunc
end

---
-- This function does function(s) validations and will only return true
-- if all the functions return's true, else return's nil, error message.
-- @function [parent=#post_helper] getAndValidation
-- @param #function ... validation functions
-- @return #boolean, #string
function M.getAndValidation(...)
    local validators = onlyFunctions{...}
    return function(value, object, key)
        local help = {}
        local result = true
        for _, v in ipairs(validators) do
            local r, h = v(value, object, key)
            result = result and r
            if not r then
                help[#help+1] = h
            end
        end
        return result, concat(help, " ")
    end
end

---
-- This function does function(s) validations and will only return true
-- if one of them returns true, else return's nil, error message.
-- @function [parent=#post_helper] getOrValidation
-- @param #function ... validation functions
-- @return #boolean, #string
function M.getOrValidation(...)
    local validators = onlyFunctions{...}
    return function(value, object, key)
        local help = {}
        local result
        for _, v in ipairs(validators) do
            local r, h = v(value, object, key)
            result = result or r
            if not r then
                help[#help+1] = h
            end
        end
        return result, concat(help, " ")
    end
end

local psklength = M.getValidateStringLengthInRange(8,63)
local pskmatch = "^[ -~]+$"
--- This function validates a WPA/WPA2 PSK key
-- It must be between 8 and 63 characters long and those characters must be ASCII printable (32-126)
-- or 64 hexa decimal values (0-9,a-f,A-F)
-- @param #string psk the PSK key to validate
-- @return #boolean, #string
function M.validatePSK(psk)
    if psk and #psk == 64 and psk:match("^[%x]+$") then
        return true
    else
        local err, msg = psklength(psk)
        if not err then
            return err, msg
        end
    end

    if not match(psk, pskmatch) then
        return nil, T"The wireless key contains invalid characters, only space, letters, numbers and the following characters !\"'`#$%&()*+,-./:;<=>?@[\\]^_{|}~ are allowed."
	--elseif match(psk, "[']+") or match(psk, "[`]+") then
	--	return nil, T"The wireless key contains invalid characters, only space, letters, numbers and the following characters !\"#$%&()*+,-./:;<=>?@[\\]^_{|}~ are allowed."
    end

    return true
end

--- Following the Wifi certificationw we need to check if the pin with 8 digits the last digit is the
-- the checksum of the others
-- @param #number the PIN code value
local function validatePin8(pin)
    if pin then
        local accum = 0
        accum = accum + 3*(floor(pin/10000000)%10)
        accum = accum + (floor(pin/1000000)%10)
        accum = accum + 3*(floor(pin/100000)%10)
        accum = accum + (floor(pin/10000)%10)
        accum = accum + 3*(floor(pin/1000)%10)
        accum = accum + (floor(pin/100)%10)
        accum = accum + 3*(floor(pin/10)%10)
        accum = accum + (pin%10)
        if 0 == (accum % 10) then
            return true
        end
    end
    return nil, T"Invalid Pin."
end

--- valide WPS pin code. Must be 4-8 digits (can have a space or - in the middle)
-- @param #string value the PIN code that was entered
function M.validateWPSPIN(value)
    local errmsg = T"PIN code must be 4 or 8 digits with potentially a dash or space in the middle."
    if value == nil or #value == 0 then
        -- empty pin code just means that we don't want to set one
        return true
    end

    local pin4 = value:match("^(%d%d%d%d)$")
    local pin8_1, pin8_2 = value:match("^(%d%d%d%d)[%-%s]?(%d%d%d%d)$")

    if pin4 then
        return true
    end
    if pin8_1 and pin8_2 then
        local pin8 = tonumber(pin8_1..pin8_2)
        return validatePin8(pin8)
    end
    return nil, errmsg
end

-- end of code related to WPS pin validation

--- check for WEP keys
-- 5,10,13 and 26 characters are allowed for the WEP key
-- 5 and 13 can contain ASCII characters
-- 10 and 26 can only contain Hexadecimal values
-- @param #string value the WEP key
-- @return #boolean, #string
function M.validateWEP(value)
    if value == nil or (#value ~= 5 and #value ~= 10 and #value ~= 13 and #value ~= 26) then
        return nil, T"Invalid length, a WEP key must be 5, 10, 13 or 26 characters long, length of 10 and 26 can only contain the letters A to F or digits"
    end

    if (#value == 10 or #value == 26) and (not value:match("^[%x]+$")) then
        return nil, T"A WEP key of length 10 or 26 can only contain the letters A to F or digits"
    end
    return true
end

-- Return number representing the IP address / netmask (first byte is first part ...)
local function ipv42num(ipstr)
    if ipstr then
      ipstr = string.untaint(ipstr)
	  --Handle EXTREME OLD INSTALLATION with no posix lib at all...
      local ip = inet_pton and inet_pton(posix.AF_INET, ipstr) or nil
      if not ip then
        return nil
      end
      local b1, b2, b3, b4 = ip:byte(1,4)
      return bit.tobit((b1*16777216) + (b2*65536) + (b3*256) + b4)
    end
end

-- Return broadcast address as number to calling function
local function broadcastAddress(network, netmask)
  local broadcast = bit.bor(network, bit.bnot(netmask))
  return broadcast
end

-- Return network address as number to calling function
local function networkAddress(ipAddr, netmask)
  local network = bit.band(ipAddr,netmask)
  return network
end

--- Return the number representing the given IPv4 address (or netmask) string.
--  @function [parent=#post_helper] ipv42num
--  @param #string ip
--  @return #number or nil if the given string doesn't represent a IPv4 address
M.ipv42num = ipv42num

--- Check that the given value is a valid IPv4 netmask.
-- In particular it will check that the netmask falls in the
-- range of /8 and /30 (both inclusive) which is what makes
-- sense for DHCP pool configuration.
-- @param #string value The netmask in dotted decimal notation.
-- @treturn boolean True if it's a valid subnet mask.
-- @treturn number The number of bits in the host part of the subnet mask.
-- @error Error message.
function M.validateIPv4Netmask(value)
  setlanguage()
  -- validateIPv4Netmask function uses inet_pton which requires string to be passed as an argument.
  -- value when it comes from GUI, will be of type userdata so untainting it.
  value = string.untaint(value)
  local valid, result = inet.validateIPv4Netmask(value)
  if not valid then
    return valid, T"Invalid netmask."
  end
  return valid
end

-- Validates the Destination IP.
-- In particular if the IPs are reserved/network/invalid IPs, then this function returns an error message.
-- @param #string ipAddr The destination IP in dotted decimal notation.
-- @tparam table object The table containing the IPv4 Static Routes Configuration userdata.
-- @error Error message.
function M.validateDestinationIP(ipAddr, object)
  local resIP, errMsg = M.validateStringIsIP(ipAddr)
  if not resIP then
    return nil, errMsg
  end

  resIP, errMsg = M.reservedIPValidation(ipAddr)
  if not resIP then
    return nil, errMsg
  end

  resIP, errMsg = M.getValidateStringIsIPv4InNetwork(object.Gateway, object.Mask)
  if not resIP then
    return nil, errMsg
  end

  resIP, errMsg = resIP(ipAddr)
  if not resIP then
    return nil,T"Destination is not in the Gateway network"
  end
  return resIP
end

--- This function returns a validator that will check that the provided value is an IPv4 in the same network
-- as the network based on the GW IP + Netmask
-- @param #string gw the gateway IP@ on the considered network
-- @param #string nm the netmask to use
-- @treturns a function or nil
function M.getValidateStringIsIPv4InNetwork(gw, nm)
    local gwip = ipv42num(gw)
    local netmask = ipv42num(nm)
    if gwip and netmask then
        local network = networkAddress(gwip, netmask)

        return function(value)
            if(GetIPType(value) ~= 4) then
                return nil, T"String is not an IPv4 address."
            end
            local ip = ipv42num(value)

            if network ~= networkAddress(ip, netmask) then
                return nil, format(T"IP is not in the same network as the gateway %s.", gw)
            end
            return true
        end
    end
end

--- This function returns a validator that will check that the provided value is an IPv4 in the same network
-- as the network based on the GW IP + Netmask except the GW and forbidden IPs (broadcast & network identifier)
-- @param #string gw the gateway IP@ on the considered network
-- @param #string nm the netmask to use
-- @return true or nil+error message
function M.getValidateStringIsDeviceIPv4(gw, nm)
    local gwip = ipv42num(gw)
    local netmask = ipv42num(nm)
    if gwip and netmask then
        local network = networkAddress(gwip, netmask)
        local broadcast = broadcastAddress(network, netmask)
        local mainValid = M.getValidateStringIsIPv4InNetwork(gw, nm)

        return function(value)
            local err, msg = mainValid(value)
            if err == nil then
                return err, msg
            end
            local ip = ipv42num(value)
            if gwip == ip then
                return nil, T"Cannot use the GW IP."
            end
            if broadcast == ip then
                return nil, T"Cannot use the broadcast address."
            end
            if network == ip then
                return nil, T"Cannot use the network address."
            end
            return true
        end
    end
    return nil,T"Invalid IP address."
end

local function checkBlockValue(str)
    local val = tonumber(str, 16)
    if val and val <= 0xFFFF then
        return true
    end
    return false
end

--- This function returns a validator that will check that the provided value is an IPv6 address
--
-- @param #string value the IPv6 Address
-- @return true or nil+error message
function M.validateStringIsIPv6(value)
    value = string.untaint(value)
    if value and inet.isValidIPv6(value) then
        return true
    else
        return nil, T"Invalid IPv6 Address, address group is invalid."
    end
end

local startLoopback = ipv42num("127.0.0.0")
local endLoopback = ipv42num("127.255.255.255")
local startMulticastRange = ipv42num("224.0.0.0")
local endMulticastRange = ipv42num("239.255.255.255")
local limitedBroadcast = ipv42num("255.255.255.255")
local classEStartIP = ipv42num("240.0.0.0")
local classEEndIP = ipv42num("255.255.255.254")
local softwareStartIP = ipv42num("0.0.0.1")
local softwareEndIP = ipv42num("0.255.255.255")

-- Check whether the given IPv4 address is a public IP address.
-- @param @tstring value the IP Address$
-- @param @ttable object has $localcpeip
-- @param @tstring key the random key value$
function M.publicIPValidation(value, object, key)
  if value ~= "" then
    if not M.isPublicIP(value) then
      return nil, T"Not a Public address"
    end
    local ip = M.ipv42num(value)
    if classEStartIP <= ip and classEEndIP >= ip then
      return nil, T"Cannot use a reserved IP address."
    end
    if softwareStartIP <= ip and softwareEndIP >= ip then
      return nil, T"Cannot use software address range."
    end
    if startLoopback <= ip and ip <= endLoopback  then
      return nil, T"Cannot use IPv4 loopback address range."
    end
    if startMulticastRange <= ip and endMulticastRange >= ip then
      return nil, T"Cannot use a multicast address."
    end
    if object.localpublicmask then
      local success1 = M.isNetworkAddress(value, object.localpublicmask)
      if success1 then
        return nil, T"Cannot use the network address"
      end
      local success2 = M.isBroadcastAddress(ip, object.localpublicmask)
      if success2 then
        return nil, T"Cannot use the broadcast address"
      end
    end
    return true
  end
end

--- is the given IP address valid as a Local Device IP and NTP server$
-- @param @tstring value the IP Address$
-- @param @ttable object has localdevmask$
-- @param @tstring key the random key value$
-- @return true or nil+error message$

function M.advancedIPValidation(value, object, key)
    if not value then
        return nil, T"Invalid IP Address."
    end
    local ip = M.ipv42num(value)
    if not ip then
        return nil, T"Invalid IP Address."
    end

    if startLoopback <= ip and ip <= endLoopback  then
        return nil,T"Cannot use IPv4 loopback address range."
    end

    --don't allow if ip is in the CLASS A IP range 0.0.0.0/2, except the private 10.0.0.0/8 range
    local endClassARange = "127.255.255.255"
    local startClassAPrivRange = "10.0.0.0"
    local endClassAPrivRange = "10.255.255.255"
    -- ip 0.0.0.0/32 is not valid
    if object.localdevmask then
        if 0 < ip and M.ipv42num(endClassARange) >= ip then
            if ipv42num(startClassAPrivRange) >= ip or ipv42num(endClassAPrivRange) <= ip then
                return nil, T"Cannot use an address in this address range."
            end
        end
    end
    if ip == 0 then
        return nil, T"Cannot use an address in this address range."
    end
    --check if ip is not in the multicast range 224.0.0.0/4
    if startMulticastRange <= ip and endMulticastRange >= ip then
        return nil, T"Cannot use a multicast address."
    end

    --check if ip is not in the limited broadcast destination address 255.255.255.255/32
    if limitedBroadcast == ip then
        return nil, T"Cannot use the limited broadcast destination address."
    end

    --in case of valid ip is the broadcast or network adress based on the network mask
    if object.localdevmask then
        local success1, errmsg = M.isNetworkAddress(value, object.localdevmask)
        if success1 then
            return nil, T"Cannot use the network address"
        end

        local success2, errmsg2 = M.isBroadcastAddress(ip, object.localdevmask)
        if success2 then
            return nil, T"Cannot use the broadcast address"
        end
    end

    return true
end

local classAIPStart = ipv42num("10.0.0.0")
local classAIPEnd = ipv42num("10.255.255.255")
local classBIPStart = ipv42num("172.16.0.0")
local classBIPEnd = ipv42num("172.31.255.255")
local classCIPStart = ipv42num("192.168.0.0")
local classCIPEnd = ipv42num("192.168.255.255")

--- Check whether the given IPv4 address is a public address.
-- @string value The IP address to be validated.
-- @return true or nil+error message
function M.isPublicIP(value)
    if not value then
        return nil, T"Invalid IP Address."
    end

    local ip = ipv42num(value)
    if not ip then
        return nil, T"Invalid IP Address"
    end

    if (classAIPStart <= ip and ip <= classAIPEnd) or (classBIPStart <= ip and ip <= classBIPEnd) or
      (classCIPStart <= ip and ip <= classCIPEnd) then
        return nil, T"Not a Public Address"
    end
    return true
end

--- is the given ip address valid as a DNS server IP in the given context
-- @param @tstring ipaddr the IP address
-- @param @ttable dnsData the localdev mask
-- @return true or nil+error message
function M.DNSIPValidation(ipaddr, dnsData)
    local ip = ipv42num(ipaddr)
    if not ip then
        return nil, T"Invalid IP Address."
    end

    if startLoopback <= ip and ip <= endLoopback then
        return nil,T"Cannot use IPv4 loopback address range"
    end

    if startMulticastRange <= ip and endMulticastRange >= ip then
        return nil, T"Cannot use a multicast address"
    end

    if limitedBroadcast == ip then
        return nil, T"Cannot use the limited broadcast destination address"
    end

    local success1, errmsg = M.isNetworkAddress(ipaddr, dnsData.localdevmask)
    if success1 then
        return nil, T"Cannot use the network address"
    end

    local success2, errmsg2 = M.isBroadcastAddress(ip, dnsData.localdevmask)
    if success2 then
        return nil, T"Cannot use the broadcast address"
    end

    return true
end

--- Check whether the given IP address is in any WAN interface subnet range
-- @tstring ipAddress the IP address
-- @ttable all_intfs the all interfaces
-- @treturn true and interface name if the given IP address is in any WAN subnet range otherwise nil
function M.isWANIP(ipAddress, all_intfs)
  local ip = ipv42num(ipAddress)
  if not ip then
    return nil, T"Invalid input"
  end

  for _, v in ipairs(all_intfs) do
    local networkWan, wanIpMax
    if v.type == "wan" and v.ipaddr ~= "" then
      local baseip = ipv42num(v.ipaddr)
      local netmask = inet.netmaskToNumber(tonumber(v.ipmask))
      if not netmask then
        return nil, T"Invalid netmask"
      end

      if baseip and netmask then
        networkWan = networkAddress(baseip, netmask)
        wanIpMax = broadcastAddress(networkWan, netmask)
      end

      if networkWan and wanIpMax then
        if networkWan <= ip and ip <= wanIpMax then
          return true, v.paramindex
        end
      end
    end
  end
end

--- Check whether the given IP address is in any LAN interface subnet range
-- @tstring ipAddress the IP address
-- @ttable all_intfs the all interfaces
-- @tstring curif the current interrface that will not be checked
-- @treturn true and interface name if the given IP address is in any LAN subnet range otherwise nil

function M.isLANIP(ipAddress, all_intfs, curif)
  local ip = ipv42num(ipAddress)
  if not ip then
    return nil, T"Invalid input"
  end
  local wanInterface = {}
  local firewall_zone = proxy.get("uci.firewall.zone.")
  local firewall_zones = content_helper.convertResultToObject("uci.firewall.zone.", firewall_zone)
  for _, zone in ipairs(firewall_zones) do
    if zone.wan == "1" and zone.name == "wan" then
      local wanInterfaceList = content_helper.convertResultToObject("uci.firewall.zone.@" .. zone.name .. ".network.", zone)
      for _, v in ipairs(wanInterfaceList) do
        wanInterface[untaint(v.value)] = true
      end
    end
  end

  for _, v in ipairs(all_intfs) do
    if not wanInterface[v.paramindex] and v.ipaddr ~= "" and v.paramindex ~= curif then
      local networkLan, lanIpMax
      local baseip = ipv42num(v.ipaddr)
      local netmask = inet.netmaskToNumber(tonumber(v.ipmask))
      if not netmask then
        return nil, T"Invalid netmask"
      end

      if baseip and netmask then
        networkLan = networkAddress(baseip, netmask)
        lanIpMax = broadcastAddress(networkLan, netmask)
      end

      if networkLan and lanIpMax then
        if networkLan <= ip and ip <= lanIpMax then
          return true, v.paramindex
        end
      end
    end
  end
end

---This function converts a CIDR(Classless Inter-domain routing) notation to a subnet mask. Eg, convert 24 to 255.255.255.0
-- @param #string 'cidr' The CIDR notation number. Eg: "24"
-- @return #string network mask or nil+error message. Eg: "255.255.255.0"
function M.cidr2mask(cidr)
    if not cidr then
        return nil, T"Invalid CIDR number."
    end

    cidr = tonumber(cidr)
    if not cidr or cidr < 0 or cidr > 32 then
      return nil, T"Invalid CIDR number."
    end

    local mask = ""
    for i=1,4 do
      mask = mask .. tostring(256 - 2^(8 - min(8, cidr)))
      if (i < 4) then
        mask = mask .. "."
      end
      cidr = max(0, cidr - 8)
    end
    return mask
end

-- This function returns a validator that check that the given value is valid IPv4 subnet or IPv6 subnet
-- @param #number ipTypeV4orV6 is IP address type. Eg:'4' denotes for IPv4 address type and '6' denotes for IPv6 address type
function M.validateIPAndSubnet(ipTypeV4orV6)
-- @param #string value User specified data entered for IPv4 or IPv6
-- @return true or nil+error message
    return function (value)
        local errMsg = T"Invalid data format detected"

        if not value or value == "" then
            return nil, errMsg
        end

        -- split ipaddress/subnet combination
        local ipaddress, netmask = match(untaint(value),"^([^/]+)/?(%d*)$")

        if not ipaddress or ipaddress == "" or untaint(value):match("/$") == "/" then
            -- not in proper ip format
            return nil, errMsg
        end

        local ip_type = GetIPType(ipaddress)
        if ipTypeV4orV6 ~= ip_type then
            return nil, format("%s%d",T"Please enter valid IPv", ipTypeV4orV6)
        end

        -- validate subnet range
        if netmask ~= "" then
            -- holds subnet numeric value and range
            local netmaskvalue, minsubnet, maxsubnet

            -- assign subnet range for IPv4 and IPv6
            if ip_type == 4 then
                minsubnet, maxsubnet = 1, 32
            elseif ip_type == 6 then
                minsubnet, maxsubnet = 8, 128
            end

            netmaskvalue = tonumber(netmask)
            if not netmaskvalue or netmaskvalue < minsubnet or netmaskvalue > maxsubnet then
                return nil, format(T"Subnet must be between %d and %d (inclusive)", minsubnet, maxsubnet)
            end
        end
        return true
    end
end

function M.validateURL(url,proto)
  if url then
    local protocol, domain = match(url,"([%w]+)://([^/]*)/?")
    if protocol and protocol ~= proto then
      return nil, T"Invalid URL"
    end
    if not protocol then
      domain = match(url,"([^/]*)/?")
    end
    local addr, port = string.match(domain, "%[(.+)%]%:(%d+)$")
    if addr and port then
      if M.validateStringIsPort(port) and (M.validateStringIsIP(addr) or M.validateStringIsDomainName(addr)) then
        return true
      end
    else
      if (M.validateStringIsIP(domain) or M.validateStringIsDomainName(domain)) then
        return true
      end
    end
  end
  return nil, T"Invalid URL"
end

--Validate the given ip/mac is Quantenna.
function M.validateQTN(value)
  local qtnMac = { mac = "uci.env.var.qtn_eth_mac" }
  local success = content_helper.getExactContent(qtnMac)
  -- No need to validate for non QTN board
  if not success then
    return true
  end
  if not value then
    return nil, "Invalid input"
  end
  value = untaint(value)
  if M.validateStringIsMAC(value) then
    if lower(qtnMac.mac) == lower(value) then
      return nil, format(T"Cannot assign, %s in use by system.", value)
    end
    return true
  elseif inet.isValidIPv4(value) == true then
    local qtnIP = content_helper.getMatchedContent("sys.proc.net.arp.",{ hw_address = lower(qtnMac.mac)})
    if #qtnIP > 0 then
      for _,v in ipairs(qtnIP) do
        if v.ip_address == value then
          return nil, format(T"Cannot assign, %s in use by system.", value)
        end
      end
    end
    return true
  end
  return nil, T"Invalid input."
end

-- validate the given ip/subnet is broadcast address or not
function M.isBroadcastAddress(ip, subnetMask)
  local netmask = ipv42num(subnetMask)
  if netmask then
    local network = networkAddress(ip, netmask)
    local broadcast = broadcastAddress(network, netmask)
    return broadcast == ip
  end
end

-- validate the given ip/subnet is network address or not
function M.isNetworkAddress(ipAddress, subnetMask)
  local netMask = ipv42num(subnetMask)
  if netMask then
    local ip = M.ipv42num(ipAddress)
    if not ip then
      return nil, T"Invalid IP Address."
    end
    if networkAddress(ip, netMask) == ip then
      return true
    end
    return nil, T"Invalid Network Address."
  end
end

--- This function is used to get default subnet mask.
-- if user enters the [ipAddress] without subnet mask, get default mask.
-- the [ipAddress] is in the Class A IP range 10.0.0.0 to 127.255.255.255, then return default mask "8"
-- the [ipAddress] is in the Class B IP range 128.0.0.0 to 191.255.255.255, then return default mask "16"
-- the [ipAddress] is in the Class C IP range 192.0.0.0 to 223.255.255.255, then return default mask "24"
-- @return #default subnet mask, nil+error message
function M.getDefaultSubnetMask(ipAddress)
  local defaultSubnetMask
  if not ipAddress then
    return nil, T"Invalid IP Address."
  end
  local ip = M.ipv42num(ipAddress)
  if not ip then
    return nil, T"Invalid IP Address."
  end
  -- If user enters an IPv4 address with class A range then default mask is "255.0.0.0"
  if ipv42num("10.0.0.0") <= ip and ip <= ipv42num("127.255.255.255") then
    defaultSubnetMask = "8"
  --If user enters an IPv4 address with class B range then default mask is "255.255.0.0"
  elseif ipv42num("128.0.0.0") <= ip and ip <= ipv42num("191.255.255.255") then
    defaultSubnetMask = "16"
  --If user enters an IPv4 address with class C range then default mask is "255.255.255.0"
  elseif ipv42num("192.0.0.0") <= ip and ip <= ipv42num("223.255.255.255") then
    defaultSubnetMask = "24"
  else
    return nil,  T"IP Address does not belong to Class A, B or C."
  end
  return defaultSubnetMask
end

-- Calculate the number of effective hosts possible in the network with the given subnet mask.
-- @string subnetmask The subnet mask, in dotted-decimal notation.
-- @treturn number The number of effective hosts possible in the network with the given subnet mask.
-- @error Error message.
function M.getPossibleHostsInSubnet(subnetmask)
  setlanguage()
  -- getPossibleHostsInIPv4Subnet function will use inet_pton which requires string to be passed as an argument.
  -- subnetmask when it comes from GUI, will be of type userdata so untainting it.
  subnetmask = string.untaint(subnetmask)
  local result = inet.getPossibleHostsInIPv4Subnet(subnetmask)
  if not result then
    return nil, T"Invalid subnet."
  end
  return result
end

-- Validate the given IP address is not in the broadcast, multicast, loopback, reserved, gatewayip, network.
-- @string object The localdevIP and localdevmask.
-- @string value The IPv4 address.
-- @treturn true For valid IP address.
-- @error Error message.
function M.staticLeaseIPValidation(value, object)
  local valid, errmsg = M.advancedIPValidation(value, object)
  if not valid then
    return nil, errmsg
  end
  local networkvalid  =  M.getValidateStringIsDeviceIPv4(object.localdevIP, object.localdevmask)
  local isnetworkvaild, msg = networkvalid(value)
  if not isnetworkvaild then
     return isnetworkvaild, msg
  end
  return true
end

-- Validate the given IP address is not in the Reserved IP list.
-- @string value The IPv4 address.
-- @return true valid IP address not present in Reserved IP list, nil+error message.
function M.reservedIPValidation(ip)
  if inet.isValidIPv4(untaint(ip)) then
    local reservedIPList = proxy.get("uci.dhcp.host.")
    reservedIPList = content_helper.convertResultToObject("uci.dhcp.host.", reservedIPList) or {}
    for _, v in ipairs(reservedIPList) do
      if match(v.name, "^ReservedStatic") and v.mac == "" then
        if ip == v.ip then
          return nil, T"The IP is internally used for other services."
        end
      end
    end
    return true
  end
  return nil, T"Invalid input."
end

--Generate random key for new rule
--@return 16 digit random key.
function M.getRandomKey()
  local bytes
  local key = ("%02X"):rep(16)
  local fd = open("/dev/urandom", "r")
  if fd then
    bytes = fd:read(16)
    fd:close()
  end
  return key:format(bytes:byte(1, 16))
end

--validates the SSID if both pattern matches then only the user able to apply changes
--if any of the pattern fails then it will show the corresponding Error messages
function M.validateSSID(value)
  local validSSID = "^[^?\"$%[%]+\\]*$"
  local validStart = "^[^%s#!;]"
  if not value then
    return nil, T"SSID should not be empty"
  elseif not value:match(validStart) then
    return nil, T"SSID should not start with ; # !"
  elseif not value:match(validSSID) then
    return nil, T"SSID should not contain ?, \", $, [, \\, ],and + special characters"
  end
  return true
end

--Validates if the 'dhcpIgnore' value is '1' or '0'
--Changes the 'dhcpIgnore' to '0' if it is '1' and the 'dhcpv4State' is 'server'
--@string value the 'dhcpIgnore' state
--@table object the table containing 'dhcpv4State' and 'dhcpIgnore'
--@return true if the 'dhcpIgnore' is valid
--@return nil+error message if the 'dhcpIgnore' is not valid
function M.validateDHCPIgnore(value, object)
  if not M.getOptionalValidation(M.validateBoolean)(value) then
    return nil, T"Invalid value."
  end
  --While board boot up, dhcpv4State will be "", in that case it needs to be enabled in GUI.
  if object.dhcpv4State == "" or object.dhcpv4State == "server" then
    if object.dhcpIgnore == "1" then
      object.dhcpIgnore = "0"
    end
  end
  return true
end

--- converts given number to IPv4 address.
--  @function [parent=#post_helper] num2ipv4
--  @param #number a number that needs to be converted
--  @treturn #string IPv4 address
--  @error Error message
function M.num2ipv4(num)
    if type(num)~="number" then
        return nil, T"Invalid Number"
    end
    -- unbit
    if num<0 then
      num = (2^32)+num
    end
    local ip = inet.numberToIpv4(num)
    if not ip then
        return nil, T"Invalid Number"
    end
    return ip
end

-- Checks whether the received 'value' is in HH:MM format
-- @function [parent=#post_helper] validateTime
-- @param value
-- @treturn #boolean true if valid nil+msg if invalid
-- @error Error message
function M.validateTime(value)
    if not value then
        return nil, T"Invalid input"
    end
    local time_pattern = "^(%d+):(%d+)$"
    local hour, min = value:match(time_pattern)
    if min then
        hour = tonumber(hour)
        min = tonumber(min)
        if hour < 0 or 23 < hour then
           return nil, T"Invalid hour, must be between 0 and 23"
        end
        if min < 0 or 59 < min then
           return nil, T"Invalid minutes, must be between 0 and 59"
        end
        return true
    end
    return nil, T"Invalid time (must be hh:mm)"
end

local function formatAttenuation(attenuation, direction, index)
    return format("%s%s%s%s%s",
        direction or "",
        index or "",
        (direction or index) and " " or "",
        attenuation,
        (attenuation == "N/A") and "" or " dB"
    )
end

local function attenuationIndexOffset(direction)
  local offset = 0
  if direction == "DS" then
    offset = 1
  end
  return offset
end

--- Formats the attenuation values for ADSL and Gfast in the format "20.2 dB" (OR) "8.7 dB",
--- VDSL in the format "DS1 20.2 dB, DS2 53.6 dB, DS3 N/A (OR) US0 8.0 dB, US1 N/A, US2 41.6 dB"
-- @string attenuation the attenuation value
-- @string direction upstream or downstream direction
-- @treturn string the formatted string of attenuation values for VDSL/ADSL/Gfast
function M.populateAttenuation(attenuation, direction)
    if not attenuation then
        return
    end
    if find(attenuation, "[,%s]") then
        local attenTable = {}
        local offset = attenuationIndexOffset(direction)
        for atten in attenuation:gmatch('([^,%s]+)') do
            local n = #attenTable
            attenTable[n + 1] = formatAttenuation(atten, direction, n + offset)
        end
        return table.concat(attenTable, ", ")
    else
        return formatAttenuation(attenuation)
    end
end

---Validator that will check whether the given value is valid IPv4 address
-- @function [parent=#post_helper] validateStringIsIPv4
-- @param ip
-- @return true or nil+error message
function M.validateStringIsIPv4(ip)
    if not ip then
        return nil, T"Invalid input"
    end
    ip = untaint(ip)
    if inet.isValidIPv4(ip) then
        return true
    end
    return nil, T"String is not an IPv4 address."
end
-- convert string value to table value
-- @function [parent=#post_helper] stringToTable
-- @string value, pattern
-- @treturn table
function M.stringToTable(value, pattern)
  local table = {}
  if value and pattern then
    for v in value:gmatch(pattern) do
      table[#table + 1] =  v
    end
  end
  return table
end

---Compares two mac addresses and return true if
-- they are same, nil otherwise.
-- Comparator is case insensitive
-- Delimiter can be : or -
-- @param mac1 first mac address
-- @param mac2 second mac address
-- @return boolean true or nil
function M.compareMACAddresses(mac1, mac2)
  if not (M.validateStringIsMAC(mac1) or M.validateStringIsMAC(mac2)) then
    return nil, T"Invalid MAC Address"
  end
  if lower(mac1:gsub("[:-]", "")) == lower(mac2:gsub("[:-]", "")) then
    return true
  end
end

---Validator that will check whether the given value
-- is present in inputList table or not,
-- it optionally accepts comparator.
-- If no comparator is present, it just checks both values are equal.
-- @function [parent=#post_helper] valueInList
-- @param inputList table
-- @param value value to be checked
-- @param comparator function optional
-- @return boolean true or nil
function M.valueInList(inputList, value, comparator)
  if inputList then
    for _, v in pairs(inputList) do
      if type(comparator) == "function" then
        if comparator(v.value, value) then
          return true
        end
      elseif v.value == value then
        return true
      end
    end
  end
end

--- Validator that will check whether the given IP address is in Network Range.
--- Validate the given IP address is not in the Reserved IP list.
-- @return true or nil+error message
function M.validateDMZ(value, object)
    local network = {
        gateway_ip = "uci.network.interface.@lan.ipaddr",
        netmask = "uci.network.interface.@lan.netmask",
    }
        content_helper.getExactContent(network)
        if object.DMZ_enable ~= "1" and value == "" then
           return true
        end
        local isDestIP, errormsg = M.getValidateStringIsDeviceIPv4(network.gateway_ip, network.netmask)(value)
        if not isDestIP then
            return nil, errormsg
        end
        isDestIP, errormsg = M.reservedIPValidation(value)
        if not isDestIP then
            return nil, errormsg
        end
        isDestIP, errormsg = M.validateQTN(value)
        if not isDestIP then
            return nil, errormsg
        end
        return true
end

--- Is upgrade allowed or not
-- @param upgradefw upgradefw config value
-- @param userRole Role of the user
-- @return true if upgrade is allowed
-- @return nil if upgrade is not allowed
function M.isUpgradeAllowed(upgradefw, userRole)
  if upgradefw ~= "1" then
    return
  end
  local allowedRoles = proxy.get("uci.web.uiconfig.@uidefault.upgradefw_role.") or {}
  if #allowedRoles == 0 then
    return true
  end
  for _, role in ipairs(allowedRoles) do
    if role.value == userRole then
      return true
    end
  end
end

-- Is space allowed or not
-- @param value is a input string
-- @return true if no space in input string
-- @return nil, error message if space in input string
function M.isSpaceInString(value)
  if value:match("%s") then
    return nil, T"space is not allowed"
  end
  return true
end

-- Calculates DHCP start and end addresses
-- @function calculateDHCPStartAndLimitAddress
-- @param baseip gateway address
-- @param netmask subnet mask
-- @param start DHCP start address
-- @param limit DHCP Limit address
-- @return DHCP startAddress, DHCP endAddress, network address
function M.DHCPStartAndLimitAddress(baseip, netmask, start, limit)
  if start and limit and baseip and netmask then
    baseip = ipv42num(baseip)
    netmask  = ipv42num(netmask)
    if not baseip or not netmask then
      return nil, T"Invalid IP Address."
    end
    local network = bit.band(baseip, netmask)
    local ipmax = bit.bor(network, bit.bnot(netmask)) - 1
    local startAddress = bit.bor(network, bit.band(start, bit.bnot(netmask)))
    local endAddress = startAddress+limit - 1
    startAddress = M.num2ipv4(startAddress)
    if endAddress > ipmax then
      endAddress = ipmax
    end
    endAddress = M.num2ipv4(endAddress)
    network = M.num2ipv4(network)
    return startAddress, endAddress, network
  end
end

--- Is feature enabled or not
-- @param feature Specific feature
-- @param userRole Role of the user
-- @return true if feature is enabled
-- @return nil if feature is disabled
function M.isFeatureEnabled(feature, userRole)
  local allowedRoles = proxy.get("uci.web.feature.@"..feature..".")
  if not allowedRoles then
     return true
  end
  for _, role in ipairs(allowedRoles) do
    if role.value == userRole then
      return true
    end
  end
end

-- Function to validate a UciName
-- value must be between 1 and 63 characters long
-- valid name must be non-empty string that consists of letters, digits or underscores
-- @return true or nil+error message
function M.validateUciName(value)
  if not match(value, "^[%w_]+$") or #value > 63 then
    return nil, T"Invalid input."
  end
  return true
end

--- Validate the given IP/MAC is LXC's IP/MAC
-- @param value IP/MAC address
-- @return true if the value is not an LXC's IP/MAC Address
-- @return nil+error message if the given input is LXC's IP/MAC Address
function M.validateLXC(value)
  if not value then
    return nil, "Invalid input"
  end

  local lxcMac = { mac = "uci.env.var.local_eth_mac_lxc" }
  local lxcAvailable = content_helper.getExactContent(lxcMac)
  if not lxcAvailable then
    return true
  end
  if M.validateStringIsMAC(value) then
    if lower(lxcMac.mac) == lower(value) then
      return nil, format(T"Cannot assign, %s in use by system.", value)
    end
    return true
  elseif inet.isValidIPv4(untaint(value)) then
    local lxcIP = content_helper.getMatchedContent("sys.proc.net.arp.",{ hw_address = lower(lxcMac.mac)})
    for _, v in ipairs(lxcIP) do
      if v.ip_address == value then
        return nil, format(T"Cannot assign, %s in use by system.", value)
      end
    end
    return true
  end
  return nil, T"Invalid input."
end

return M
