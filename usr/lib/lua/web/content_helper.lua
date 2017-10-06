local proxy = require("datamodel")
local html_escape = require("web.web").html_escape
local open = io.open
local pairs, ipairs, unpack, type, tonumber = pairs, ipairs, unpack, type, tonumber
local concat, sort = table.concat, table.sort
local string = string

--- content_helper module
--  @module content_helper
--  @usage local content_helper = require('web.content_helper')
--  @usage require('web.content_helper')
local M = {}

--- Retrieve the values from a table and return them in an array.
-- @param content A table.
-- @return The values of the table are returned in an array. This essentially
--         strips the keys.
local function getValues(content)
    local result = {}
    if content then
        for _,v in pairs(content) do
            result[#result+1] = v
        end
    end
    return result
end

--- Return the path to use with add or as base for index based access given a basepath
-- @function (parent=#content_helper] getPaths
-- @param #string path
-- @return #string, #string, #string addpath, indexpath, instanceprefix
function M.getPaths(path)
    local isit, addpath, indexpath, instanceprefix
    if path:find("%.@%.$") then
        addpath = path:sub(1, -3)
        indexpath = path:sub(1, -2)
        instanceprefix = "@"
    else
        addpath = path
        indexpath = path
        instanceprefix = ""
    end
    return addpath, indexpath, instanceprefix
end

--- Method to get content from exact paths from UCI via transformer.
--  It only accepts UNTAINTED strings
-- @function [parent=#content_helper] getExactContent
-- @param content A table containing key, path pairs. Every path will be retrieved
--                via transformer and the retrieved value will replace the path in the
--                table.
-- @return #bool, #string returns true if successful otherwise returns nil + errmsg
function M.getExactContent(content)
    local paths = getValues(content)
    local result, errmsg = proxy.get(unpack(paths))
    local temp = {}
    for _,v in ipairs(result or {}) do
        temp[v.path..v.param] = v.value
    end
    for k,v in pairs(content) do
        content[k] = temp[v] or ""
    end
    if result then
        return true
    else
        return nil, errmsg
    end
end

--- Method to filter section content from uci path.
-- @function [parent=#content_helper] getMatchedContent
-- @param path   A string. Such as "uci.mmpbx.inmap."
-- @param filter A table containing param, value pairs. Only the sections match with the
--               filter will be returned.
--                filter = {
--		      profile = "profile1",
--		      voicePort = {"FXS0", "FXS1"}
--                }
-- @param num    A number. if num matched sections are found, return.
-- 			   Or ergodic all sections to find all matched sections
-- @return A table. Including param and value pairs. The path for this section also returned.
--               content = {
--		     {
--		       profile = "profile1",
--		       ...
--		       path = "uci.mmpbx.inmap.1.", -- if path is not a param, then path will contain the actual path
--		       path = "/usr/lib/mmpbx.sh", -- if path is a param, then path will contain the value of that param
--		       __path = "uci.mmpbx.inmap.1.", -- __path will always contain the actual path and it is preferred over path
--		       voicePort = {
--		           {
--		             value = "FXS0",
--		             path = "uci.mmpbx.inmap.1.voicePort.@1."
--		           },
--		           {...}
--		       }
--		     },
--		     {...},
--               }
function M.getMatchedContent (path, filter, num)
    if (path == nil) then
        return {}
    end

    local content, list_options = {}, {}
    local basic_path, option = "", ""
    local match_num, match_count = 0, 0

    if (type(filter) == "table") then
        for _, _ in pairs (filter) do
            match_num = match_num + 1
        end
    end
    local exactPath = M.getPaths(path)
    local res = proxy.get (exactPath)
    if (type(res) == "table") then
        local v = {}
        for _, v in pairs (res) do
            --A new section
	    --if v.path == uci.mmpbx.outgoing_map.14. and basic_path == uci.mmpbx.outgoing_map.1.
            --we need update basic_path, simple match is not enough
	    --if v.path = "uci.mmpbx.inmap.1.voicePort.@2."
	    --then basic_path == "uci.mmpbx.inmap.1."
	    local tmp_basic_path = v.path:match("^("..exactPath.."[^%.]+)") .. "."
            if (basic_path == "" or tmp_basic_path ~= basic_path) then
                -- If the last section is not matched, remove it
                if (match_count ~= match_num) then
                    content[#content] = nil
                end
                if (#content == num) then
                    return content
                end

                basic_path = tmp_basic_path
                content[#content+1] = { path = basic_path, __path = basic_path }
                match_count = 0
            end

            --Deal with List option
			option = v.path:match (".(%w+).@[%w+].$")
            if (v.path:match(basic_path) and v.path ~= basic_path and option) then
                content[#content][option] = content[#content][option] or {}
                local t = content[#content][option]
                t[#t + 1] = {value = v.value, path = v.path}
                list_options[#list_options + 1] = v.value

                --If there is a filter for this list option and
                --After all value for this list option is recorded, check if it is matched with the filter
                if (type(filter) == "table") then
                    if (type(filter[option]) == "table") then
                        sort (list_options)
                        sort (filter[option])
                        local options_str = concat(list_options, "")
                        local filter_str = concat (filter[option], "")
                        if (options_str == filter_str) then
                            match_count = match_count + 1
                        end
                    end
                end

                --Deal with Basic option
            elseif (v.path == basic_path) then
                content[#content][v.param] = v.value
                list_options = {}

                --Check if this basic option is matched
                if (type(filter) == "table") then
                    if (v["value"] == filter[v["param"]]) then
                        match_count = match_count + 1
                    end
                end
            end
        end
    end

    if (match_count ~= match_num) then
        content[#content] = nil
    end

    return content
end


--- Method to add content from list paths from UCI via transformer.
-- @function [parent=#content_helper] addListContent
-- @param content A table to which the lists need to be added.
-- @param incompletes A table containing key, path pairs. Every path will be retrieved
--                    via transformer and the retrieved values will be inserted into
--                    an array which is added to the content table with the corresponding
--                    key.
-- @param Nothing is returned, but the content table contains the lists corresponding
--        to the given incomplete paths after this method is called.
function M.addListContent(content, incompletes)
    for k,v in pairs(incompletes) do
        local result = proxy.get(v)
        if(result) then
            local temp = {}
            for _,w in ipairs(result) do
                temp[#temp+1] = w.value
            end
            content[k] = temp
        end
    end
end

--- Format conversion table.
local formats = {
    number = "*n",
    line = "*l",
    file = "*a"
}

--- Method to retrieve information from a file.
-- @function [parent=#content_helper] readfile
-- @param #string filename The file from which information needs to be retrieved.
-- @param #string form The format to be used when reading from the file. Possible formats:
--             number: retrieve a number
--             line: retrieve a line
--             file: retrieve the entire file
-- @param conversion An optional function to convert the retrieved data from the file
--                   before returning the value.
-- @return
function M.readfile(filename,form,conversion)
    local fd = open(filename)
    if not fd then
        -- Don't throw an error, this will abort generating the rest of the page.
        -- Just return an empty string.
        return ""
    end
    local format = formats[form] or formats["line"]
    local result = fd:read(format)
    fd:close()
    if type(conversion) == "function" then
        return conversion(result)
    end
    return result
end

--- Method to convert proxy result to aggregated objects
--  This method only work on results from an array type of elements
--  It will discard elements deeper than the array
--  @param  #string basepath
--  @param  #table results array returned by proxy.get
--  @param  sorted
--  @return #table table of "objects"
local function convertResultToObject(basepath, results, sorted)
    local indexstart, indexmatch, subobjmatch
    local data = {}
    local output = {}

    indexstart = #basepath
    if not basepath:find("%.@%.$") then
        indexstart = indexstart + 1
    end

    if results then
        for _,v in ipairs(results) do
            -- Try to match the path with basepath.{index}.{subobj}
            -- subobj can be nil (if the parameter is just under basepath) but if it is not, then we concatenate it with the param name
            -- so subobjects will be defined using their full "subpath"
            indexmatch, subobjmatch = v.path:match("^([^%.]+)%.(.*)$", indexstart)
            if indexmatch ~= nil then
                if data[indexmatch] == nil then
                    -- Initializes 2 structures. One (data) is used to gather the data for a given "object"
                    -- The other (output) is used to create an array of those objects to be able to list data in order
                    data[indexmatch] = {}
                    data[indexmatch]["paramindex"] = indexmatch
                    output[#output + 1] = data[indexmatch]
                end
                -- No need to check on subobj, "worst" case, it's an empty string, not nil since the capture allows for an empty string
                -- Store value using a key that contains the full "sub path"
                data[indexmatch][subobjmatch .. v.param] = v.value
            end
        end
    end

    if sorted and #output > 1 then
        if type(sorted) == "function" then
            table.sort(output, sorted)
        elseif type(sorted) == "string" then
            local reverse = false
            local index = string.match(sorted, "^-(.*)")
            if index then
                reverse = true
            else
                index = sorted
            end
            -- Avoid the table.sort crash when meets nil object
            if output[1][index] then
                table.sort(output, function(a, b)
                    if a[index] and b[index] then
                        if reverse then
                            return a[index] > b[index]
                        else
                            return a[index] < b[index]
                        end
                    else
                        return true
                    end
                end)
            end
        end
    end

    return output
end

---
-- Expose function in module
--  @function [parent=#content_helper] convertResultToObject
--  @param  #string basepath
-- 	@param  #table results array returned by proxy.get
-- 	@return #table table of "objects"
M.convertResultToObject = convertResultToObject

---
-- process a checkbox group data and store it
-- @param #table c column details
-- @param #table v line data
-- @return #table
local function processCheckboxGroupData(c,v)
    local cb_data = {}
    if c.param ~= nil then
        local i = 0
        while true do
            i = i + 1
            local key = v[c.param .. ".@" .. i .. ".value"]
            if not key then
                break
            end
            cb_data[#cb_data + 1] = string.untaint(key)
        end
    end
    return cb_data
end

---
-- Process one line of data
-- @param #table columns columns details
-- @param #table v line data
-- @return #table
local function loadLineData(columns, v)
    local line = {}
    for _,c in ipairs(columns) do
        if c.type == "checkboxgroup" then
            line[#line + 1] = processCheckboxGroupData(c,v)
        elseif c.type == "aggregate" then
            line[#line + 1] = loadLineData(c.subcolumns, v)
        else
            if v[c.param] ~= nil then
                line[#line + 1] = v[c.param]
            else
                line[#line + 1] = ""
            end
        end
    end
    return line
end

--- Method to load an array for use in a table
--  @function [parent=#content_helper] loadTableData
--  @param #string ucipath partial path to a UCI array
--  @param #table columns
--  @param filter
--  @param sorted
--  @return #table,#table output, allowedIndexes
function M.loadTableData(ucipath, columns, filter, sorted)
    local addpath, indexpath = M.getPaths(ucipath)
    local results = proxy.get(addpath)

    local data = convertResultToObject(ucipath, results, sorted)
    local output = {}
    local allowedIndexes = {}

    -- Now that we have the "objects", filter them
    for _,v in ipairs(data) do
        -- If there is a filter function, we'll decide which entries should be returned based on its answer
        -- otherwise, include everything
        local f
        if type(filter) == "function" then
            f = filter(v)
        elseif filter == nil then
            f = true
        end

        if f then
            local fil
            if type(f) == "table" then -- contains canedit and candelete properties
                fil = f
            else -- canedit and candelete are true by default
                fil = {
                    canEdit = true,
                    canDelete = true,
                }
            end
            fil.paramindex = v.paramindex
            allowedIndexes[#allowedIndexes + 1] = fil
            output[#output + 1] = loadLineData(columns, v)
        end

    end
    return output, allowedIndexes
end

--- Method to set parameters using a mapping table
-- @function [parent=#content_helper] setObject
-- @param #table object - the object to write
-- @param #table map - the object property -> transformer mapping
-- @param #string basepath - basepath to append to every path
-- @param #table defaultObject table or nil (transformer param name => value)
-- 			     1) table that is merged with the data gathered from the form before being written
-- 			     2) nil just use the data gathered from the form without change
function M.setObject(object, map, basepath, defaultObject)
    local success, msg = true, {}
    local pathvalues = {}
    local something = false
    basepath = basepath or ""

    -- If defaultObject is not nil, then we start adding it
    -- Anything that is also present in object will overwrite this
    if type(defaultObject) == "table" then
        for k,v in pairs(defaultObject) do
            pathvalues[basepath .. k] = v
        end
    end

    for k, v in pairs(object) do
        if map[k] ~= nil then
            something = true
            if type(v) == "table" then
                -- array (checkboxgroup for instance), in the form of an array
                -- first delete the entries, then add the values back
                -- expect an empty array -> validation function must set it
                proxy.del(basepath .. map[k] .. ".")
                for i,d in ipairs(v) do
                    proxy.add(basepath .. map[k] .. ".")
                    pathvalues[basepath .. map[k] .. ".@" .. i .. ".value"] = d
                end
            else
                pathvalues[basepath .. map[k]] = v
            end
        end
    end

    if something == true then
        success, msg = proxy.set(pathvalues)
    end
    return success, msg
end

local function extractSubPaths(path, structure)
    local patName = "%.@[^%.]+%."
    local bp, index
    local s,e = path:find(patName)
    if s then
        bp = path:sub(1, s) -- includes the trailing .
        index = path:sub(s+2, e-1) -- no starting @
        if not structure[bp] then
            structure[bp] = {}
        end

        if not structure[bp][index] then
            structure[bp][index] = {}
        end

        extractSubPaths(path:sub(e+1), structure[bp][index])
    end
end

local function addSubPaths(basepath, structure)
    local numpattern = "^%d+$"
    local path
    for k,v in pairs(structure) do
        for i,w in pairs(v) do
            if i:match(numpattern) then
                proxy.add(basepath .. k)
            else
                proxy.add(basepath .. k, i)
            end
            addSubPaths(basepath .. k .. "@" .. i .. ".", w)
        end
    end
end

--- create the subpaths (when indexed) as needed based on the content of the map under the given basepath
-- it only supports named (with @) entries since with regular indexes, there is no way of knowing the index
-- it assumes it is being called on a "brand new" object so it just has to create entries, not to delete existing ones
-- @param #string basepath which object to add the subpaths to
-- @param #table map table containing the subpaths being used. The function will extract those that include an indexed object
local function createSubPaths(basepath, map)
    local structure = {}

    for _,v in pairs(map) do
        extractSubPaths(v, structure)
    end

    addSubPaths(basepath, structure)
end

--- Method to create a new element and populate its fields using a mapping table
-- @function [parent=#content_helper] addNewObject
-- @param #string basepath - transformer path
-- @param #table object - object to use to populate the fields
-- @param #table map - property name to transformer name conversion table
-- @param #table defaultObject table or nil (transformer param name => value)
-- 			     1) table that is merged with the data gathered from the form before being written
-- 			     2) nil just use the data gathered from the form without change
-- @param #string objectName - name for the new added object
-- @return #strings, #table index,msg
function M.addNewObject(basepath, object, map, defaultObject, objectName)
    local indexpath, addpath, instanceprefix, setok

    addpath, indexpath, instanceprefix = M.getPaths(basepath)

    local index, msg = proxy.add(addpath, objectName)
    if index ~= nil then
        createSubPaths(indexpath .. index .. ".", map)
        _, msg = M.setObject(object, map, indexpath .. index .. ".", defaultObject)
    end
    return index, msg
end

---
-- Method that takes an object and applies the validation methods provided in mapValidation on it
-- @function [parent=#content_helper] validateObject
-- @param #table object
-- @param #table mapValidation
-- @return #boolean, #table success, helpmsg
function M.validateObject(object, mapValidation)
    if object == nil then
        return true
    end

    local success = true
    local helpmsg = {}

    if mapValidation then
        for k, v in pairs(object) do
            if mapValidation[k] then
                local err, msg = mapValidation[k](v, object, k)
                success = success and err ~= nil
                if err == nil then
                    helpmsg[k] = msg
                end
            end
        end
    end
    return success, helpmsg
end

--Comparing the values of two tables.
--@param table object, table object
--@return boolean.
local function tableEquals(a, b)
  --We only support tables
  if (type(a)~="table" or type(b)~="table") then
    return false
  end
  --Check each key-value pair
  for k,v in pairs(a) do
    if v ~= b[k] and not tableEquals(v, b[k]) then
      return false
    end
  end
  --tables differ if b contains keys that are not in a.
  for k in pairs(b) do
    if not a[k] then
      return false
    end
  end
  return true
end
M.tableEquals = tableEquals

-- Method that takes two lists of comma separated values and merges into a single list.
-- Also removes the duplicate entries if any.
-- @function [parent=#content_helper] getMergedList
-- @param #string list1
-- @param #string list2
-- @return #string mergedList
function M.getMergedList(list1, list2)
  local mergedList = ""
  list1 = html_escape(list1) -- remove tainted string from list1
  list2 = html_escape(list2) -- remove tainted string from list2

  if list1 == "" and list2 ~= "" then
    mergedList = list2
  elseif list1 ~= "" and list2 == "" then
    mergedList = list1
  elseif list1 ~= "" and list2 ~= "" then
    mergedList = list1 .. "," .. list2
  end

  -- eliminate duplicate entries
  local tmp = {}
  local duplicates = {}
  for k in mergedList:gmatch("[^,]+") do
    if not duplicates[k] then
      tmp[#tmp + 1] = k
      duplicates[k] = true
    end
  end
  mergedList = table.concat(tmp, ",")

  return mergedList
end

return M
