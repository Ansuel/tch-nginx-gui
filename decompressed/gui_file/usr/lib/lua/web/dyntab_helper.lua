local ngx, require = ngx, require
local ipairs, type = ipairs, type
local string = string

local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local gVIES = post_helper.getValidateInEnumSelect

local function processOperations(operations)
    if type(operations) == "table" then
        local success, msg
        local ok = true
        for _,v in ipairs(operations) do
            local path = v[1]
            local val = v[2]

            success = proxy.set(path, val)
            ok = ok and success
        end
        return ok
    elseif type(operations) == "function" then
        return operations()
    end
end

local function processChecks(config)
    local content_cache = {}

    for _,v in ipairs(config) do
        if type(v.check) == "function" then
            if v.check() then
                return v.name
            end
        elseif type(v.check) == "table" then
            local ok = true
            -- array of pairs { transformer path, value }, do an equality check on each one of those and then and
            for _,s in ipairs(v.check) do
                if #s ~= 2 then
                    ok = false
                else
                    if not content_cache[s[1]] then
                        local data = proxy.get(s[1])
                        if not data then
                            ok = false
                        else
                            local value = data[1].value
                            content_cache[s[1]] = value
                        end
                    end
                    ok = ok and string.find(content_cache[s[1]],s[2])
                end
            end
            if ok then
                return v.name
            end
        end
    end
    return ""
end


--- dyntab_helper module
--  @module dyntab_helper
--  @usage local dyntab_helper = require('web.dyntab_helper')
--  @usage require('web.dyntab_helper')
local M = {}


M.process = function(conf)
    local mode_options = {}
    local mode_data = {}
    local mode_default = "" -- the default mode to use
    local mode_active = ""  -- the mode currently in use (mode_default if not set)
    local mode_current = "" -- the mode currently selected (not necessarily active yet)
    local ajax_query = false

    for _,v in ipairs(conf) do
        mode_options[#mode_options + 1] = { v.name, v.description }
        mode_data[v.name] = v
        if v.default == true then
            mode_default = v.name
        end
    end

    -- Get current mode
    local content

    if ngx.var.request_method == "POST" then
        content = ngx.req.get_post_args()
        local action = content["action"]
        local newmode = content["newmode"]

        if action == "SWITCH_MODE" then
            if gVIES(mode_options)(newmode) then
                mode_current = newmode:untaint()

                processOperations(mode_data[mode_current].operations)
                proxy.apply()
            end
        elseif action == "AJAX-GET" then
            ajax_query = true
        end
    end

    mode_active = processChecks(conf)
    if mode_active == "" then
        mode_active = mode_default
    end

    if mode_current == "" then
        mode_current = mode_active
    end
    local  result ={}
    local mc = mode_data[mode_current]
    if mc then
      result = {
        name = mc.name,
        description = mc.description,
        ajax = ajax_query
      }
      if type(mc.view) == "function" then
        result.view = mc.view()
      else
        result.view = mc.view
      end
      if type(mc.card) == "function" then
        result.card = mc.card()
      else
        result.card = mc.card
      end
    end
    return {
        current = result,
        options = mode_options
    }
end

return M
