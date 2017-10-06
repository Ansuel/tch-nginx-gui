local ngx = ngx
local pairs, ipairs, tonumber, type, setmetatable = pairs, ipairs, tonumber, type, setmetatable
local format, match, find, gsub, require = string.format, string.match, string.find, string.gsub, require
local sort = table.sort
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")
local lfs = require("lfs")

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

gettext.textdomain('web-framework-tch')

local includepath

module ("wizard")

function setpath(path)
  includepath = path
end

function cards()
  local result = {}
  if includepath and lfs.attributes(includepath, 'mode') == 'directory' then
    for file in lfs.dir(includepath) do
      if find(file, "%.lp$") then
        result[#result+1] = file
      end
    end
  end
  sort(result)
  return result
end

function createFooter()
  return format([[
     <div class="modal-footer">
      <div id="modal-changes">
        <div id="wizard-previous" class="btn btn-primary btn-large">%s</div>
        <div id="wizard-next" class="btn btn-primary btn-large">%s</div>
        <div id="wizard-complete" class="btn btn-primary btn-large">%s</div>
        <div id="cancel-config" class="btn btn-large" data-dismiss="modal">%s</div>
      </div>
    </div>
    ]], T"Back", T"Next", T"Finish", T"Exit")
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
function handleQuery(mapParams, mapValidation)
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

        if (post_data["action"] == "SAVE" or post_data["action"] == "VALIDATE") then
            -- Save original data in case validation does remove some parameters
            local original_data = {}
            for k,v in pairs(content) do
                original_data[k] = v
            end

            -- now overwrite the data
            for k,v in pairs(post_data) do
                content[k] = v
            end

            -- Start by applying the corresponding validation function to each parameter
            -- we receive.
            local validated
            validated, helpmsg = content_helper.validateObject(content, mapValidation)

            -- Now assuming that everything was validated, we can prepare to store the data
            if validated then
                if post_data["action"] == "SAVE" then
                    local ok, msg = content_helper.setObject(content, mapParams)
                    if ok then
                        ok, msg = proxy.apply()
                        -- now in case some validation function removed some data, we bring it back from the original load
                        -- for instance, password validation will just remove the password data when getting the dummy value
                        for k,_ in pairs(mapParams) do
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
                        ngx.log(ngx.ERR, "setObject failed: " .. msg)
                        message_helper.pushMessage(T"Error while saving changes", "error")
                        -- we cannot assume every transaction is atomic (not every mapping will implement it) so to be safe
                        -- we reload the data
                        for k,v in pairs(mapParams) do
                            content[k] = v
                        end
                        content_helper.getExactContent(content)
                    end
                elseif post_data["action"] == "VALIDATE" then
                    -- now in case some validation function removed some data, we bring it back from the original load
                    -- for instance, password validation will just remove the password data when getting the dummy value
                    for k,_ in pairs(mapParams) do
                        if not content[k] then
                            content[k] = original_data[k]
                        end
                    end
                end
            else
                message_helper.pushMessage(T"Some parameters failed validation", "error")
            end
        end
    end

    return content, helpmsg
end
