#!/usr/bin/env lua
-- Copyright (c) 2017 Technicolor

local uci = require("uci")
local cursor = uci.cursor()
local conn = require("ubus").connect()
if not conn then
   error("Failed to connect to ubusd")
end

local translate_dnd_action = {
    on = '1',
    off = '0',
    ['1'] = "on",
    ['0'] = "off"
}

local function is_in_table(value, value_list)
    if ((value_list ~= nil) and type(value_list) == "table") then
        for _, v in ipairs(value_list) do
            if (v == value) then
                return true
            end
        end
    end
    return false
end

function get_all_profiles(profile_list)
    cursor:foreach("mmpbx", "service", function(s)
        if (s.type == "DND") then
            local profiles = s["profile"]
            if #profiles >= 1 then
                for _, profile_name in ipairs (profiles) do
                    profile_list[#profile_list + 1] = profile_name
                end
            end
        end
    end)
end

function update_current_state(profile_name,ringing_state)
    conn:send ("mmpbx.profile.dnd", { profile = profile_name, dnd = ringing_state })
    cursor:foreach("mmpbx", "service", function(s)
        if (s["type"] == "DND") and ((is_in_table(profile_name, s["profile"]))== true) then
            current_state = cursor:get("mmpbx", s['.name'], "activated")
            if (current_state ~= nil) and (current_state ~= translate_dnd_action[ringing_state]) then
                 cursor:set("mmpbx", s['.name'], "activated", translate_dnd_action[ringing_state])
            end
        end
    end)
    cursor:commit("mmpbx")
end

function update_ringing_schedule()
    local is_ringing_enabled = cursor:get("tod", "voicednd", "enabled")
    local time_mon_freq = cursor:get("tod", "global", "time_change_monfreq")
    local timer_and_action_modified = cursor:get("tod", "voicednd","timerandactionmodified")
    local all_profiles = {}
    if (is_ringing_enabled == nil) then
         -- if not able to fetch current state, then it's better to exit, than modifying any of existing ringing states
         return
    end

    -- fetch all DND provisioned profiles and initialize their relevant status to false, on updating mark them true
    get_all_profiles(all_profiles)

    if (#all_profiles < 1) then
        return
    end

    if (is_ringing_enabled == "0") then
        if (timer_and_action_modified == "1") then
            os.execute("sleep " .. tonumber(time_mon_freq))
            cursor:set("tod", "voicednd","timerandactionmodified", "0")
            cursor:commit("tod")
            cursor:unload("tod")
        end
        for _,profile in pairs (all_profiles) do
            update_current_state(profile,"off")
        end
    elseif (is_ringing_enabled == "1") then
        os.execute ("/usr/bin/lua /usr/share/transformer/scripts/voice_tod.lua")
    end
end

update_ringing_schedule()
