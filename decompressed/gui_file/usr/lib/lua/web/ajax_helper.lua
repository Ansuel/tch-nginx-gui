local ngx, require = ngx, require
local match, next = string.match, next
local content_helper = require("web.content_helper")
local json = require("dkjson")

local ipairs, type = ipairs, type

--- ajax_helper module
--  Client should be running the corresponding js or requests can be crafted by hand.
--  Make sure that you do not generate any output yourself server side otherwise the output won't be valid (it will be
--  a mix of html and json which is incorrect).
--  * Server side, we only react to POST queries with form input if the "action" is set to "AJAX-GET"
--  * If that is the case, we look in "requested_params" and check for an array of parameter names to retrieve.
--  * The parameter names are not transformer paths but an id that is mapped to a transformer path through the use of the
--    mapParams variable. It is a dictionnary id -> path (same format as getExactContent or handleQuery calls so it makes
--    it easy to reuse the same dictionnary if you want to expose the same parameters through AJAX)
--  * The transform function is provided as a way to do additional processing on the retrieved data (such as formatting)
--  @module ajax_helper
--  @usage local ajax_helper = require('web.ajax_helper')
--  @usage require('web.ajax_helper')
local M = {}

function M.handleAjaxQuery(mapParams, transform)
    -- Check if we're in a POST query
    if ngx.var.request_method == "POST" and ngx.var.content_type and match(ngx.var.content_type, "application/x%-www%-form%-urlencoded") then
        local post_data = ngx.req.get_post_args()
        if post_data["action"] == "AJAX-GET" then
            local params = post_data["requested_params"]

            if type(params) ~= "table" then
                 params = { params }
            end

            -- we only fetch the requested parameters (this allows to have one call in the page that can handle multiple cases)
            local content = {}
            for _,k in ipairs(params) do
                local key = k:untaint()
                if mapParams[key] then
                    content[key] = mapParams[key]
                end
            end
            if next(content) ~= nil then
                local success, errmsg = content_helper.getExactContent(content)
                if type(transform) == "function" then
                    transform(content)
                end
                if success then
                    local buffer = {}
                    success = json.encode (content, { indent = false, buffer = buffer })
                    if success then
                        ngx.header.content_type = "application/json"
                        ngx.print(buffer)
                        ngx.exit(ngx.HTTP_OK )
                    else
                        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
                    end
                else
                    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
                end
            else
                ngx.exit(ngx.HTTP_BAD_REQUEST)
            end
        end
    end
end

return M