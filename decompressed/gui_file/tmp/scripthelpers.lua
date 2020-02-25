---------------------------------
--! @file
--! @brief The scripthelpers module containing functions reused throughout Mobiled, mappings and webui
---------------------------------

local lfs = require("lfs")
local bit = require("bit")
local socket = require("socket")

local M = {}

local function empty()
    return ""
end
local empty_mt = { __index = empty }

-- Used by mobiled.lua Netifd helper
function M.getopt(args, ostr)
    local arg, place = nil, 0;
    return function ()
        if place == 0 then -- update scanning pointer
            place = 1
            if #args == 0 or args[1]:sub(1, 1) ~= '-' then place = 0; return nil end
            if #args[1] >= 2 then
                place = place + 1
                if args[1]:sub(2, 2) == '-' then -- found "--"
                    place = 0
                    table.remove(args, 1);
                    return nil;
                end
            end
        end
        local optopt = args[1]:sub(place, place);
        place = place + 1;
        local oli = ostr:find(optopt);
        if optopt == ':' or oli == nil then -- unknown option
            if optopt == '-' then return nil end
            if place > #args[1] then
                table.remove(args, 1);
                place = 0;
            end
            return '?';
        end
        oli = oli + 1;
        if ostr:sub(oli, oli) ~= ':' then -- do not need argument
            arg = nil;
            if place > #args[1] then
                table.remove(args, 1);
                place = 0;
            end
        else -- need an argument
            if place <= #args[1] then  -- no white space
                arg = args[1]:sub(place);
            else
                table.remove(args, 1);
                if #args == 0 then -- an option requiring argument is the last one
                    place = 0;
                    if ostr:sub(1, 1) == ':' then return ':' end
                    return '?';
                else arg = args[1] end
            end
            table.remove(args, 1);
            place = 0;
        end
        return optopt, arg;
    end
end

function M.startswith(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

function M.sanitize(data)
    local sanitizedData = {}
    for k, v in pairs(data) do
        if type(v) == "table" then
            sanitizedData[k] = M.sanitize(v)
        else
            sanitizedData[k] = tostring(v)
        end
    end
    return sanitizedData
end

function M.floats_to_string(data)
    for k, v in pairs(data) do
        if type(v) == "table" then
            M.floats_to_string(data[k])
        elseif type(v) == "number" then
            local _, fractional = math.modf(v)
            if fractional ~= 0 then
                data[k] = tostring(v)
            end
        end
    end
end

function M.getUbusData(conn, facility, func, params)
    local data = conn:call(facility, func, params or {}) or {}
    local result = M.sanitize(data)
    setmetatable(result, empty_mt)
    return result
end

-- Print anything - including nested tables
local function tprint (tt, output, indent, done)
    done = done or {}
    indent = indent or 0
    if type(tt) == "table" then
        for key, value in pairs (tt) do
            table.insert(output, string.rep (" ", indent)) -- indent it
            if type (value) == "table" and not done [value] then
                done [value] = true
                table.insert(output, string.format("[%s] => table\n", tostring (key)));
                table.insert(output, string.rep (" ", indent+4)) -- indent it
                table.insert(output, "(\n");
                tprint (value, output, indent + 7, done)
                table.insert(output, string.rep (" ", indent+4)) -- indent it
                table.insert(output, ")\n");
            else
                table.insert(output, string.format("[%s] => %s\n", tostring (key), tostring(value)))
            end
        end
    else
        if tt then table.insert(output, tostring(tt) .. "\n") end
    end
end

function M.twrite(tt, f, append)
    local output = {}
    tprint(tt, output)
    local file
    if not append then
        file = io.open(f, "w")
    else
        file = io.open(f, "a")
    end
    for _, line in pairs(output) do
        file:write(line)
    end
    file:close()
end

function M.tprint(tt)
    local output = {}
    tprint(tt, output)
    for _, line in pairs(output) do
        io.write(line)
    end
end

function M.tablelength(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

function M.sleep(sec)
    socket.sleep(tonumber(sec))
end

function M.split(data, delimiter)
    local result = {}
    if not data then return result end
    local from  = 1
    local delim_from, delim_to = string.find(data, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(data, from , delim_from-1 ))
        from  = delim_to + 1
        delim_from, delim_to = string.find(data, delimiter, from)
    end
    local str = string.sub(data, from)
    if str and #str > 0 then
        table.insert(result, str)
    end
    return result
end

function M.read_file(name)
    local content = nil
    local f = io.open(name, "rb")
    if f then
        content = f:read("*all")
        f:close()
    end
    return content
end

function M.write_file(name, contents)
    local f = io.open(name, "w")
    if not f then
        return nil, "Failed to open file"
    end
    f:write(contents)
    f:close()
    return true
end

function M.capture_cmd(cmd)
    local f = io.popen(cmd, 'r')
    if not f then return "" end
    local s = f:read('*a')
    f:close()
    return s
end

function M.merge_tables(t1, t2)
    if type(t1) == "table" and type(t2) == "table" then
        for k,v in pairs(t2) do
            if type(v) == "table" then
                if type(t1[k] or false) == "table" then
                    M.merge_tables(t1[k] or {}, t2[k] or {})
                else
                    t1[k] = v
                end
            else
                t1[k] = v
            end
        end
    end
    return t1
end

function M.table_eq(table1, table2)
    local avoid_loops = {}
    local function recurse(t1, t2)
        -- compare value types
        if type(t1) ~= type(t2) then return false end
        -- Base case: compare simple values
        if type(t1) ~= "table" then return t1 == t2 end
        -- Now, on to tables.
        -- First, let's avoid looping forever.
        if avoid_loops[t1] then return avoid_loops[t1] == t2 end
        avoid_loops[t1] = t2
        -- Copy keys from t2
        local t2keys = {}
        local t2tablekeys = {}
        for k, _ in pairs(t2) do
            if type(k) == "table" then table.insert(t2tablekeys, k) end
            t2keys[k] = true
        end
        -- Let's iterate keys from t1
        for k1, v1 in pairs(t1) do
            local v2 = t2[k1]
            if type(k1) == "table" then
                -- if key is a table, we need to find an equivalent one.
                local ok = false
                for i, tk in ipairs(t2tablekeys) do
                    if M.table_eq(k1, tk) and recurse(v1, t2[tk]) then
                        table.remove(t2tablekeys, i)
                        t2keys[tk] = nil
                        ok = true
                        break
                    end
                end
                if not ok then return false end
            else
                -- t1 has a key which t2 doesn't have, fail.
                if v2 == nil then return false end
                t2keys[k1] = nil
                if not recurse(v1, v2) then return false end
            end
        end
        -- if t2 has a key which t1 doesn't have, fail.
        if next(t2keys) then return false end
        return true
    end
    return recurse(table1, table2)
end

function M.swap(data)
    if type(data) ~= "string" then return nil end
    local t = {}
    for i = 1, #data, 2 do
        local a = data:sub(i,i)
        local b = data:sub(i+1,i+1)
        if b then table.insert(t, b) end
        table.insert(t, a)
    end
    return table.concat(t, "")
end

function M.uptime()
    local f = io.open("/proc/uptime")
    local line = f:read("*line")
    f:close()
    return math.floor(tonumber(line:match("[%d%.]+")))
end

function M.seed_random()
    local random_device = io.open("/dev/urandom", "rb")
    if random_device then
        -- Seed needs to be a signed integer in Lua 5.1
        local random_data = random_device:read(3)
        random_device:close()
        if random_data then
            local seed = 0
            for i = 1, string.len(random_data) do
                seed = seed * 256 + string.byte(random_data, i)
            end
            math.randomseed(seed)
        end
    end
end

function M.get_lte_band_mask(bands)
    local mask
    if bands then
        mask = 0
        for _, band in pairs(bands) do
            mask = bit.bor(mask, bit.lshift(1, band-1))
        end
    end
    return mask
end

local BASE64_DIGITS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function M.encode_base64(text)
    local result = ""
    for in_1, in_2, in_3 in text:gmatch("(.)(.?)(.?)") do
        local value = in_1:byte() * 65536 + (in_2:byte() or 0) * 256 + (in_3:byte() or 0)
        local out_1 = math.floor(value / 262144) % 64 + 1
        local out_2 = math.floor(value / 4096) % 64 + 1
        result = result .. BASE64_DIGITS:sub(out_1, out_1) .. BASE64_DIGITS:sub(out_2, out_2)

        if in_2 ~= "" then
            local out_3 = math.floor(value / 64) % 64 + 1
            result = result .. BASE64_DIGITS:sub(out_3, out_3)

            if in_3 ~= "" then
                local out_4 = value % 64 + 1
                result = result .. BASE64_DIGITS:sub(out_4, out_4)
            else
                result = result .. "="
            end
        else
            result = result .. "=="
        end
    end
    return result
end

function M.decode_base64(base64)
    local result = ""
    local end_reached = false
    for in_1, in_2, in_3, in_4 in base64:gmatch("%s*(%S)%s*(%S?)%s*(%S?)%s*(%S?)") do
        if end_reached or in_4 == "" then
            return nil, "input is not a valid base64 string"
        end

        local digit_1 = BASE64_DIGITS:find(in_1, 1, true)
        local digit_2 = BASE64_DIGITS:find(in_2, 1, true)
        if not digit_1 or not digit_2 then
            return nil, "input is not a valid base64 string"
        end

        local value = (digit_1 - 1) * 262144 + (digit_2 - 1) * 4096
        local out_1 = math.floor(value / 65536) % 256
        result = result .. string.char(out_1)

        if in_3 ~= "=" then
            local digit_3 = BASE64_DIGITS:find(in_3, 1, true)
            if not digit_3 then
                return nil, "input is not a valid base64 string"
            end

            value = value + (digit_3 - 1) * 64
            local out_2 = math.floor(value / 256) % 256
            result = result .. string.char(out_2)

            if in_4 ~= "=" then
                local digit_4 = BASE64_DIGITS:find(in_4, 1, true)
                if not digit_4 then
                    return nil, "input is not a valid base64 string"
                end

                value = value + digit_4 - 1
                local out_3 = value % 256
                result = result .. string.char(out_3)
            else
                end_reached = true
            end
        else
            end_reached = true
        end
    end
    return result
end

function M.isDir(name)
    if type(name)~="string" then return false end
    local cd = lfs.currentdir()
    local is = lfs.chdir(name) and true or false
    lfs.chdir(cd)
    return is
end

function M.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[M.deepcopy(orig_key)] = M.deepcopy(orig_value)
        end
        setmetatable(copy, M.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

return M
