local M = {}
local pairs = pairs
local find = string.find
local sub = string.sub
local ubus

local convert_action = {
   on = "off",
   off = "on"
}

local translate_dnd_action = {
    on = '1',
    off = '0'
}

local function is_in_table(value, table)
    if (table ~= nil) then
        for _, v in pairs(table) do
            if v == value then
                return true
            end
        end
    end
    return false
end

local function no_available_schedules(cursor)
    local timer_found = false
    cursor:foreach("tod","action", function(s)
       if (s.object:match("^voicednd")) then
            if (s.timers) then
                for _,timer in ipairs (s.timers) do
                    if (timer ~= '') then
                        timer_found = true
                        return
                    end
                end
            end
        end
    end)
    if (timer_found == true) then
        return false
    end
    return true
end

-- function to return ringing state
local function get_ringing_state(action, cursor, logger)
    local ringing_scheme = cursor:get("tod", "voicednd", "ringing")
    if (action == "start") then
         ringing_scheme = convert_action[ringing_scheme]
    end
    return ringing_scheme
end

-- function to get profiles to operate from object
local function get_profile_to_operate(object, cursor, logger)
    local profile_name_list = nil
    local type, instance = find(object, "%.")
    if type then
        local tod_type = sub(object, 1, type-1)
        local tod_instance = sub(object, instance+1, -1)
        cursor:foreach("tod", tod_type, function(s)
            if s['.name'] == tod_instance then
                profile_name_list = s['profile']
                return true
            end
        end)

    cursor:unload("tod")
    return profile_name_list
    end
end

local function execute_action(action, runtime, action_trigger, object)

    local logger = runtime.logger
    local uci = runtime.uci
    local ubus = runtime.ubus
    local cursor = uci.cursor()

    logger:warning("execute_action: " .. action .. " for " .. action_trigger .. " on " .. object)
    local profile_instance = get_profile_to_operate(object, cursor, logger)
    if not profile_instance then
        logger:warning("there is no profile instance to operate")
        return true
    end

-- get value of ringing allowed / muted

    local ringing_state = get_ringing_state(action, cursor, logger)
    local is_updated = false
    logger:debug("ringing state value %s", ringing_state)



    if ringing_state and translate_dnd_action[ringing_state] then

-- if action object is "All", then trigger ubus event and update uci
        if is_in_table("All", profile_instance) then
            ubus:send ("mmpbx.profile.dnd", { dnd = ringing_state })
            cursor:foreach("mmpbx", "service", function(s)
               if s["type"] == "DND" then
                   cursor:set("mmpbx", s['.name'], "activated", translate_dnd_action[ringing_state])
                   is_updated = true
               end
            end)
        else
-- if action object is list of profiles, then check current state for a profile and update if needed
            for _,profile_name in pairs (profile_instance) do
                local current_state = nil
                ubus:send ("mmpbx.profile.dnd", { profile = profile_name, dnd = ringing_state })
                cursor:foreach("mmpbx", "service", function(s)
                   if (s["type"] == "DND") and ((is_in_table(profile_name, s["profile"]))== true) then
                        current_state = cursor:get("mmpbx", s['.name'], "activated")
                       if (current_state ~= nil) and (current_state ~= translate_dnd_action[ringing_state]) then
                           cursor:set("mmpbx", s['.name'], "activated", translate_dnd_action[ringing_state])
                           is_updated = true
                       end
                   end
                end)
            end
        end
    end
    if is_updated then
        cursor:commit("mmpbx")
    end
    cursor:unload("mmpbx")
end

-- start action

function M.start(runtime, action_trigger, object)
    local logger = runtime.logger
    local uci = runtime.uci
    local cursor = uci.cursor()
    local activated = cursor:get("tod","voicednd","enabled")
    if activated == "1" then
        execute_action("start", runtime, action_trigger, object)
    end
    cursor:unload("tod")
    return true
end

-- stop action

function M.stop(runtime, action_trigger, object)
    local uci = runtime.uci
    local cursor = uci.cursor()
    local activated = cursor:get("tod","voicednd","enabled")
    if activated == "1" then
        execute_action("stop", runtime, action_trigger, object)
    end
    cursor:unload("tod")
    return true
end

return M
