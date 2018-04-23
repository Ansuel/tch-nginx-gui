local M = {}
-- Localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ngx, format = ngx, string.format
local proxy = require("datamodel")

local function wait_for_completion(base_path, return_json, filename)
    local state_path = base_path .. "state"
    local sleep_time = 0.250
    local max_time = 5
    local total_time = 0
    local content
    repeat
        ngx.sleep(sleep_time)
        total_time = total_time + sleep_time

        content = {
          state = state_path,
        }
        content_helper.getExactContent(content)

        if content.state ~= "Requested" then
            break
        end
    until (total_time >= max_time)
    if filename then
        os.remove(filename)
    end
    if content.state ~= "Complete" then
        if content.state == "Requested" then
            ngx.log(ngx.ERR, "Timeout on ", base_path)
        else
            ngx.log(ngx.ERR, format('Error on %s (state="%s")', base_path, content.state))
        end
        if return_json then
            ngx.print('{ "error":"10" }')
            ngx.exit(ngx.OK)
        else
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end
    end
end

function M.export_log(export_way_assign)
    local export_rpc_path = "rpc.system.log.download."
    local export_way = export_rpc_path .. "way"
    local export_state = export_rpc_path .. "state"

    -- start the file export, first set the log getting way, then export
    local export_way_value = export_way_assign or "logread"
    proxy.set(export_way, export_way_value)
    proxy.set(export_state, "Requested")
    -- wait for completion; does not return on error or timeout
    wait_for_completion(export_rpc_path)
    -- return exported data
    ngx.header.content_disposition = "attachment; filename=log.txt"
    ngx.header.content_type = "application/octet-stream"
    ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JS download code requires this cookie
    local export_path = ("/tmp/log.msg")
    local f = io.open(export_path, "r")
    if f then
        ngx.print(f:read("*all"))
        f:close()
        -- cleanup (reset state and remove export file)
        proxy.set(export_state, "None")
    end
    -- and we're done
    ngx.exit(ngx.HTTP_OK)
end

return M
