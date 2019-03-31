--NG-99970 [TI] Radio and Access point button not disabled during Wireless control blocked time even though SSID is not broadcasting
local M = {}
local pairs = pairs
local find = string.find
local sub = string.sub
local table_remove = table.remove
local ubus

local need_to_reload = false

-- does a value exist in the table
local function is_in_table(value, table)
    for k, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

-- is it an option to set or restore
local function is_to_operate(option)
    if not find(option, "%.") and not find(option, "%_orig%_") and option ~= "ap" then
        return true
    else
        return false
    end
end

-- get the ap instances to set or restore
local function get_ap_instances_to_operate(object, cursor, logger)
    local ap_instance_list = nil

    -- get the wifitod instance
    local i, j = find(object, "%.")
    if i then    -- there is "." in object, the part before "." is the type, and after "." is the instance
        local tod_type = sub(object, 1, i-1)
        local tod_instance = sub(object, j+1, -1)
        logger:debug("type=" .. tod_type .. ", instance=" .. tod_instance)
        cursor:foreach("tod", tod_type, function(s)
            if s['.name'] == tod_instance then
                ap_instance_list = s['ap']
                return false
            end
        end)
    else    -- object is the type when there is no ".", first section of the type is taken into account
        cursor:foreach("tod", object, function(s)
            if s['.index'] == 0 then
                ap_instance_list = s['ap']
                return false
            end
        end)
    end -- if i

    cursor:unload("tod")
    return ap_instance_list
end

-- get the aps to set or restore
local function get_aps_to_operate(ap_instances, cursor, logger)
    local ap
    local ap_list = {}

    for _, ap_instance in pairs(ap_instances) do
        ap = cursor:get("tod", ap_instance, "ap")
        if ap then
            ap_list[#ap_list+1] = ap
        end
    end

    cursor:unload("tod")
    return ap_list
end

-- get all the aps in a config
local function get_all_aps(cursor, config, section)
    local ap_list = {}
    cursor:foreach(config, section, function(s)
        ap_list[#ap_list+1] = s['.name']
    end)

    cursor:unload(config)
    return ap_list
end

-- execute the operation: "backup and set" or "restore and remove"
local function execute_operation(operation, ap_name, ap_section, action_name, is_all, cursor, logger)
    local value_to_operate, value_in_wireless
    local operate_option -- option name for backing up or restoring
    logger:debug("execute_operation: " .. operation)

    for option, value in pairs(ap_section) do
        if type(value) ~= "boolean" then
            logger:debug(ap_section['.name'] .. "." .. option .. "=" .. value)
        end

        if is_to_operate(option) then
            value_in_wireless = cursor:get("wireless", ap_name, option)
            if value_in_wireless then    -- the option exists in wireless
                if is_all then
                    operate_option = ap_name .. "_" .. action_name .. "_orig_" .. option    -- ap_name is included in the case of "all"
                else
                    operate_option = action_name .. "_orig_" .. option
                end -- if is_all
                logger:debug(option .. " is an option to operate, operate_option is " .. operate_option)

                if operation == "backup_and_set" then
                    value_to_operate = value

                    -- back up the original value in wireless to tod
                    cursor:set("tod", ap_section['.name'], operate_option, value_in_wireless)
                elseif operation == "remove_and_restore" then
                    value_to_operate = ap_section[operate_option]
                    if value_to_operate == nil then -- no value to restore
                        return true
                    end

                    -- remove the restored option from tod
                    cursor:set("tod", ap_section['.name'], operate_option, "")
                else
                    logger:debug("operation is not expected, do nothing")
                    return true
                end -- if operation

                -- send a UBUS event if WiFi is scheduled to be switched OFF/ON
                if value_to_operate == "0" then
                    logger:debug("wifi_OFF due to scheduling")
                    ubus:send("wifitod", { event = "wifi_off_tod_scheduler_start" })
                else
                    logger:debug("wifitod schedule period ends")
                    ubus:send("wifitod", { event = "wifi_tod_scheduler_stop" })
                end

                -- update wireless when values differ between wireless and to_operate
                if value_in_wireless ~= value_to_operate then
                    logger:debug("values differ between wireless and to_operate: " .. value_in_wireless .. " and " .. value_to_operate)
                    cursor:set("wireless", ap_name, option, value_to_operate)
					if option == "state" then
						local radio_name = "radio_2G"
						local wl_name = cursor:get("wireless", ap_name, "iface")
						if string.match(wl_name, "wl1") then
							radio_name = "radio_5G"
						end
						cursor:set("wireless", wl_name, option, value_to_operate)
						--cursor:set("wireless", radio_name, option, value_to_operate)
					end
                    need_to_reload = true
                else
                    logger:debug("values are the same between wireless and to_operate: " .. value_in_wireless)
                end -- if value_in_wireless...
            else
                logger:notice(option .. " does NOT exist in wireless." .. ap_name)
            end -- if value_in_wireless
        end -- if is_to_operate
    end -- for option, value...

    return true
end

local function call_operation(start_or_stop, runtime, actionname, object)
    local logger = runtime.logger
    local uci = runtime.uci
    local x = uci.cursor()
    -- logger:set_log_level(6)

    logger:debug("enter call_operation: "  .. start_or_stop .. " " .. actionname .. " on " .. object)

    local operation
    if start_or_stop == "start" then
        operation = "backup_and_set"
    elseif start_or_stop == "stop" then
        operation = "remove_and_restore"
    else
        return true
    end

    local ap_instances_to_operate = get_ap_instances_to_operate(object, x, logger)
    if not ap_instances_to_operate then
        logger:warning("there is no ap instance to operate")
        return true
    end

    local aps_to_operate = get_aps_to_operate(ap_instances_to_operate, x, logger)
    if #aps_to_operate == 0 then
        logger:warning("there is no ap to operate")
        return true
    end

    local all_aps_in_wireless = get_all_aps(x, "wireless", "wifi-ap")
    if #all_aps_in_wireless == 0 then
        logger:warning("there is no ap in wireless")
        return true
    end

    need_to_reload = false

    if is_in_table("all", aps_to_operate) then
        local is_all = true
        logger:debug("\'all\' is in aps_to_operate")
        local ap_section = x:get_all("tod", ap_instances_to_operate[1])

        for _, ap_name in pairs(all_aps_in_wireless) do
            execute_operation(operation, ap_name, ap_section, actionname, is_all, x, logger)
        end
    else -- if is_in_table("all", aps_to_operate)
        local is_all = false
        local ap_name, ap_section
        for _, ap_instance in pairs(ap_instances_to_operate) do
            ap_name = x:get("tod", ap_instance, "ap")
            if ap_name and is_in_table(ap_name, all_aps_in_wireless) then
                ap_section = x:get_all("tod", ap_instance)

                execute_operation(operation, ap_name, ap_section, actionname, is_all, x, logger)
            end -- if ap_name...
        end -- for _, ap_instance...
    end -- if is_in_table("all", aps_to_operate)

    x:commit("tod")
    x:commit("wireless")
    x:unload("tod")
    x:unload("wireless")

    if need_to_reload then
        logger:debug("reload wireless")
        os.execute("/etc/init.d/hostapd reload")
		os.execute("/etc/init.d/network reload")
    end

    logger:debug("exit call_operation: "  .. start_or_stop .. " " .. actionname .. " on " .. object)

    return true
end

function M.start(runtime, actionname, object)
    ubus = runtime.ubus
    ubus:send("wifitod", { event = "wifitod_started" })
    call_operation("start", runtime, actionname, object)
    return true
end

function M.stop(runtime, actionname, object)
    ubus = runtime.ubus
    call_operation("stop", runtime, actionname, object)
    return true
end

return M
