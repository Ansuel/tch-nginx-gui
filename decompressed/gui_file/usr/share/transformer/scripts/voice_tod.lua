#!/usr/bin/env lua
-- Copyright (c) 2017 Technicolor

local uci = require("uci")
local cursor = uci.cursor()
local ubus = require("ubus")
local conn = ubus.connect()
if not conn then
   error("Failed to connect to ubusd")
end

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

function scan_for_profile_with_schedule(active_profile, inactive_profile)
    cursor:foreach("tod","action", function(s)
        local object = nil
        if ((s.activedaytime ~= nil) and (s.object:match("^voicednd"))) then
            object = s.object:match("^voicednd%.(.*)$")
            if (object ~= nil) then
                cursor:foreach("tod", "voicednd", function(profile_list)
                    if (profile_list[".name"] == object) then
                        for _, profile_name in ipairs (profile_list.profile) do
                            active_profile[#active_profile + 1] = profile_name
                        end
                    end
                end)
            end
        elseif ((s.activedaytime == nil) and (s.object:match("^voicednd"))) then
            object = s.object:match("^voicednd%.(.*)$")
            if (object ~= nil) then
                cursor:foreach("tod", "voicednd", function(profile_list)
                    if (profile_list[".name"] == object) then
                        for _, profile_name in ipairs (profile_list.profile) do
                            inactive_profile[#inactive_profile + 1] = profile_name
                        end
                    end
                end)
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

function notify_new_state()
    cursor:load("tod")
    cursor:load("mmpbx")
    local all_profiles = { }
    local profile_ringing_state = { }
    local active_schedule_profile = { }
    local inactive_schedule_profile = { }
    local current_ringing_state = cursor:get("tod", "voicednd", "ringing")
    if (current_ringing_state == nil) then
         -- if not able to fetch current state, then it's better to exit, than modifying any of existing ringing states
         return
    end

    -- fetch all DND provisioned profiles and initialize their relevant status to false, on updating mark them true
    get_all_profiles(all_profiles)

    for _,profile in pairs(all_profiles) do
        profile_ringing_state[profile] = false
    end

    local tod_enabled = cursor:get("tod", "global", "enabled")
    local voicednd_enabled = cursor:get("tod","voicednd", "enabled")

    if (tod_enabled == "0" or voicednd_enabled == "0") then
        for profile,_ in pairs(profile_ringing_state) do
            update_current_state(profile, "off")
        end
        return
    end

    local voice_rules_count = 0
    local unscheduled_rules_count = 0
    cursor:foreach("tod", "action", function(schedule)
        if (schedule.object:match("^voicednd%.(.*)$")) then
            voice_rules_count = voice_rules_count + 1
        if (#schedule.timers == 1 and is_in_table("",schedule.timers)== true) then
            unscheduled_rules_count = unscheduled_rules_count + 1
        end
        end
    end)

    if (voice_rules_count == unscheduled_rules_count) then
        for profile,_ in pairs(profile_ringing_state) do
             update_current_state(profile, "off")
        end
        return
    end

    -- identify all active schedule related profiles
    scan_for_profile_with_schedule(active_schedule_profile, inactive_schedule_profile)

    -- no schedule configured for any profile, do nothing
    if (#active_schedule_profile < 1) and (#inactive_schedule_profile < 1) then
        return
    end

    if (active_schedule_profile ~= nil) and (#active_schedule_profile > 0) then
        if (is_in_table("All", active_schedule_profile)== true) then
            for _,profile_name in pairs (all_profiles) do
                update_current_state(profile_name, convert_action[current_ringing_state])
                profile_ringing_state[profile_name] = true
            end
            return
        else
            for _, profile_instance in ipairs (active_schedule_profile) do
                 if (profile_ringing_state[profile_instance] == false) then
                     update_current_state(profile_instance, convert_action[current_ringing_state])
                     profile_ringing_state[profile_instance] = true
                 end
            end
        end
    end

    for profile_name,_ in pairs (profile_ringing_state) do
         if (profile_ringing_state[profile_name] == false) then
             update_current_state(profile_name, current_ringing_state)
             profile_ringing_state[profile_name] = true
         end
    end
    cursor:unload("tod")
    cursor:unload("mmpbx")
end

local time_mon_freq = cursor:get("tod", "global", "time_change_monfreq")
local timer_and_action_modified = cursor:get("tod", "voicednd","timerandactionmodified")
if (timer_and_action_modified == "1") then
   os.execute("sleep " .. tonumber(time_mon_freq))
   cursor:set("tod", "voicednd","timerandactionmodified", "0")  -- after waiting for time_change_monfreq, reset param to "0"
   cursor:commit("tod")
   cursor:unload("tod")
end
notify_new_state()
