local cfg = require("transformer.shared.ConfigCommon")
local format = string.format
local open, stderr = io.open, io.stderr
local execute = os.execute

local function errmsg(fmt, ...)
    local msg = format(fmt, ...)
    stderr:write('*error: ', msg, '\n')
    return {msg}
end

local function output_state(state, stateFile)
    local f
    if stateFile and (stateFile~='-') then
        local err
        f, err = open(stateFile, 'w')
        if not f then
            errmsg("failed to open statefile %s: %s", stateFile, err or '???')
            f = io.stdout
        end
    else
        f = io.stdout
    end

    for k, v in pairs(state) do
        f:write( k, "=", v, "\n" )
    end
    f:close()
end

local function main(config, stateFile)
    local import_mapdata = cfg.export_init("")
    import_mapdata.filename = config
    import_mapdata.state = "Requested"
    cfg.import_start(import_mapdata)
    local sleep_time = 1
    local max_time = 5
    local total_time = 0
    repeat
        execute("sleep " .. sleep_time)
        total_time = total_time + sleep_time
        if import_mapdata.state ~= "Requested" then
            break
        end
    until (total_time >= max_time)
    if import_mapdata.state ~= "Complete" then
        if import_mapdata.state == "Requested" then
            errmsg("Timeout when import the config file")
            return 1
        else
            errmsg('Import config error (state="%s", info="%s")', import_mapdata.state, import_mapdata.info or "")
            return 1
        end
    end
    output_state({ REBOOT = "1" }, stateFile)
    return 0
end

os.exit(main(...) or 0)
