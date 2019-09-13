local ubus, uloop, uci = require('ubus'), require('uloop'), require('uci')
local netlink = require("tch.netlink")
local format = string.format
--local dbg = io.open("/tmp/sle.txt", "w") -- "a" for full logging

local M = {}

local config = "ledfw"
local cursor = uci.cursor()
local linkstatus = "down"

cursor:load(config)
local info_service_led_timeout, err = cursor:get(config, 'timeout', 'ms')
if info_service_led_timeout == nil then
    info_service_led_timeout = 2000
end

local provisioning_status = "completed"

cursor:unload(config)

local wan_status = "initial"


--Led runtime data structure:
-- broadband
--    status: initial, off, no_line, sync, ip_connected, ping_ok, ping_ko, upgrade_ko, upgrade_ongoing.
--    mode: initial, persistent, timerled.
--    color: refers to definition in statemachine.
--    utimer: uloop timer instance.
-- wireless
--    status: initial, off, radio_off, channel_analyzing, not_best_channel, best_channel.
--    mode: initial, persistent, timerled.
--    color: refers to definition in statemachine.
--    utimer: uloop timer instance.
-- wps
--    status: initial, off, wifi_on, wps_ongoing, wps_ko, wps_ok.
--    mode: initial, persistent, timerled.
--    color: refers to definition in statemachine.
--    utimer: uloop timer instance.
-- ambient
--    pattern: 'active' (inuse), 'inactive' (not inuse), 'to-inactive' (will be inactive); status: initial (white-loop), on (white-solid), off. 
local led = {
    broadband = {status = "initial", mode = "initial", color = "none", utimer = nil},
    wireless = {status = "initial", mode = "initial", color = "none", utimer = nil},
    wps = {status = "initial", mode = "initial", color = "none", utimer = nil},
    ambient = {pattern = "active", status = "initial"},
}

local reset_timer = nil
local reset_timeout = 10000

local function export_led_color(ledname, color)
    led[ledname].color = color

    cursor:load("ledfw")
    if (cursor:get(config, ledname, "status") == nil) then
        cursor:set(config, ledname, "led")
    end
    
    cursor:set("ledfw", ledname, "status", led[ledname].status)

    -- For ambient led, the color exported to uci should represent the color is seen,
    -- while color stored in led status memory represents its running color.
    if ledname == "ambient" and (led[ledname].status == "off" or led.ambient.pattern == "inactive") then
        cursor:set("ledfw", ledname, "color", "off")
    else
        cursor:set("ledfw", ledname, "color", color)
    end

    cursor:commit("ledfw")
    cursor:unload("ledfw")
end

local function led_timer_cb(ledname, cb)
    --dbg:write(ledname, ": led_timeout\n")
    --dbg:flush()

--    status: initial, off, no_line, sync, ip_connected, ping_ok, ping_ko, upgrade_ko, upgrade_ongoing.
    if ledname == "broadband" then
        if led[ledname].status ~= "initial" and led[ledname].status ~= "off" and led[ledname].status ~= "no_line" and led[ledname].status ~= "sync" and led[ledname].status ~= "upgrade_ongoing" then
            led[ledname].status = "off"
            cb(ledname..'_led_timeout')
        end
    else
        led[ledname].status = "off"
        cb(ledname..'_led_timeout')
    end

    if led.broadband.status == "off" and (led.wireless.status == "off" or led.wireless.status == "initial") and (led.wps.status == "off" or led.wps.status == "initial") then
        -- Always update ambient status inspite of its pattern, so that status can be represent as soon as it gets active.
        cb('service_led_off')
        led.ambient.status = "on"
        export_led_color("ambient", "white-solid")
    end

end

local function update_led_status(cb, ledname, status, mode, color)
    --dbg:write(ledname.." "..status.." "..mode.." "..color, ": update_led_status\n")
    --dbg:flush()

    -- In fastweb definition, there is no chance to directly set led 'off', but only timeout 'off'.
    -- So, only process '~off' status here, while 'off' is processed in timer callback.
    if status ~= "off" then
        -- If ambient is set to be 'inactive' by user, trigger it at the first event of service-led.
        if led.ambient.pattern == "to-inactive" then
            cb('ambient_inactive')
            led.ambient.pattern = "inactive"
        end

        -- If any service-led is not 'off', then ambient-led should be 'off'.
        -- Always update ambient status inspite of it's active or not, so that its status can be represent as soon as it gets active.
        cb('service_led_on')
        led.ambient.status = "off"
        export_led_color("ambient", "off")
    end
    
    if mode == "timerled" then
        -- set timer to turn off this led after 5s
        if led[ledname].utimer == nil then
            led[ledname].utimer = uloop.timer(function() led_timer_cb(ledname, cb) end, info_service_led_timeout)
        else
            --refresh timeout value
            led[ledname].utimer:set(info_service_led_timeout)
        end
    elseif mode == "persistent" and led[ledname].utimer ~= nil then
        led[ledname].utimer:cancel()
        led[ledname].utimer = nil
    end

    led[ledname].status = status
    led[ledname].mode = mode

    export_led_color(ledname, color)
end

function M.start(cb)
    uloop.init()
    local conn = ubus.connect()
    if not conn then
        error("Failed to connect to ubusd")
    end

    local events = {}

    events['network.interface'] = function(msg)
        if msg ~= nil and msg.interface ~= nil then
            local wanevent = false
            if msg.action ~= nil and msg.interface == "wan" then
                if msg.action:gsub('[^%a%d_]','_') == "ifup" then
                    wan_status = "ifup"

                    if provisioning_status == "completed" then
                      cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. 'ifup')
                      wanevent = true
                    end
                else
                    wan_status = "ifdown"
                    cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_'))
                    wanevent = true
                end
            end

            if msg.interface:match('^wan6?$') ~= nil then
                if (msg['ipv4-address'] ~= nil or msg['ipv6-address'] ~= nil) then 
                   if (msg['ipv4-address'] == nil or msg['ipv4-address'][1] == nil) and (msg['ipv6-address'] == nil or msg['ipv6-address'][1]== nil) then
                      cb('network_interface_' .. msg.interface .. '_no_ip')
                   end
                end
            end

            if msg.pppinfo ~= nil  and msg.pppinfo.pppstate ~= nil then
                cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_ppp_' .. msg.pppinfo.pppstate:gsub('[^%a%d_]','_'))
            end

            if wanevent == true then
                if msg.action:gsub('[^%a%d_]','_') == "ifup" then
                    if led.broadband.status == "no_line" or led.broadband.status == "sync" then
                      -- set timer to turn off this led after 5s
                      update_led_status(cb, "broadband", "ip_connected", "timerled", "green-solid")
                    end
                else
                    -- layer3 down, doesn't timeout led
                    if led.broadband.status ~= "no_line" and led.broadband.status ~= "sync" then
                      update_led_status(cb, "broadband", "sync", "persistent", "red-blink")
                    end
                end
            end
        end
    end 

    events['FaultMgmt.Event'] = function(msg)
        if msg ~= nil and msg.EventType:match("ACS provisioning") ~= nil and msg.ProbableCause:match("Inform success") ~= nil then
            if wan_status == "ifup" then
                if led.broadband.status == "no_line" or led.broadband.status == "sync" then
                    cb('network_interface_wan_ifup')
                    update_led_status(cb, "broadband", "ip_connected", "timerled", "green-solid")
                end
            end

            if provisioning_status ~= "completed" then
                provisioning_status = "completed"

                cursor:load(config)
                if (cursor:get(config, "broadband", "status") == nil) then
                    cursor:set(config, "broadband", "led")
                end

                cursor:set(config, "broadband", "provisioning_status", "completed")

                cursor:commit(config)
                cursor:unload(config)
            end
        end
    end

    events['xdsl'] = function(msg)
        if msg ~= nil then
            cb('xdsl_' .. msg.statuscode)

            local xdslcode = tonumber(msg.statuscode)
            if (xdslcode >= 1 and xdslcode <= 4) or (xdslcode == 6) then
                update_led_status(cb, "broadband", "sync", "persistent", "red-blink")
                linkstatus = "up"
            elseif xdslcode == 0 then
                update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                linkstatus = "down"
            end
        end
    end

    events['gpon.ploam'] = function(msg)
        if msg ~= nil and msg.statuscode ~= nil then
            if msg.statuscode ~= '5' then
                cb('gpon_ploam_' .. msg.statuscode)
                local gponcode = tonumber(msg.statuscode)
                if gponcode >= 1 and gponcode <= 8 then
                    if gponcode >= 2 and gponcode <= 4 then
                        update_led_status(cb, "broadband", "sync", "persistent", "red-blink")
                        linkstatus = "up"
                    else
                        update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                        linkstatus = "down"
                    end
                end
            else
                cb('gpon_ploam_50')
                update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                linkstatus = "down"
            end
        end
    end

    events['gpon.omciport'] = function(msg)
        if msg ~= nil and msg.statuscode ~= nil then
            cb('gpon_ploam_5' .. msg.statuscode)
            if msg.statuscode == '0' then
                update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                linkstatus = "down"
            end
        end
    end

    events['ambient.status'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            if msg.state == "inactive" then
                if led.ambient.pattern == "active" then
                    if led.ambient.status == "initial" then
                        -- If ambient is in initial status when system starting, mark inactive status only currently.
                        -- And, it will be turned inactive untill service-led event pops which stops ambient's initial (white-loop) status.
                        led.ambient.pattern = "to-inactive"
                    else
                        -- Turns ambient inactive immediatelly.
                        -- Ambient inactive just means it's not in use to represent its staus.
                        -- Ambient status and color should be updated according to service-led status,
                        -- so that its status can be represent correctly as soon as it get active again.
                        cb('ambient_inactive')
                        led.ambient.pattern = "inactive"
                    end
                end
            elseif msg.state == "active" then
                -- Always turns ambient.pattern immediatelly.
                cb('ambient_active')
                led.ambient.pattern = "active"
            end
        end
    end

    events['line.button'] = function(msg)
        if msg ~= nil and led.broadband.status == "off" or led.broadband.status == "ip_connected" or led.broadband.status == "ping_ok" or led.broadband.status == "ping_ko" then
            if msg.lineinfo == "ping OK" then
                cb('ping_success')
                update_led_status(cb, "broadband", "ping_ok", "timerled", "green-blink")
            elseif msg.lineinfo == "ping KO" then
                cb('ping_failed')
                update_led_status(cb, "broadband", "ping_ko", "timerled", "red-blink")
            end

        end
    end

    events['wireless.button'] = function(msg)
        if msg ~= nil and msg.action ~= nil then
            if msg.radioinfo["2G_state"] == "off" and msg.radioinfo["5G_state"] == "off" then
                cb('wifi_both_radio_off')
                update_led_status(cb, "wireless", "radio_off", "timerled", "red-solid")
            elseif msg.radioinfo["2G_state"] == "not best channel in use" or msg.radioinfo["5G_state"] == "not best channel in use" then
                cb('not_best_channel_inuse')
                update_led_status(cb, "wireless", "not_best_channel", "timerled", "red-solid")
            elseif msg.radioinfo["2G_state"] == "channel analyzing" or msg.radioinfo["5G_state"] == "channel analyzing" then
                cb('channel_analyzing')
                update_led_status(cb, "wireless", "channel_analyzing", "persistent", "green-blink")
            else
                cb('best_channel_inuse')
                update_led_status(cb, "wireless", "best_channel", "timerled", "green-solid")
            end
        end
    end

    events['wps.button'] = function(msg)
        if msg ~= nil and msg.wpsinfo ~= nil then
            if string.match(msg.wpsinfo, "activate") == "activate" then
                cb('wps_activate_radio')
                update_led_status(cb, "wps", "wifi_on", "timerled", "green-solid")
            end

        end
    end

    events['wireless.wps_led'] = function(msg)
        if msg ~= nil and msg.wps_state ~= nil then
            if led.wps.status == "wps_ongoing" then
                if string.match(msg.wps_state, "success") == "success" then
                    cb('wps_registration_success')
                    update_led_status(cb, "wps", "wps_ok", "timerled", "green-solid")
                elseif (string.match(msg.wps_state, "idle") == "idle") or (string.match(msg.wps_state, "error") == "error") or (string.match(msg.wps_state, "off") == "off") or (string.match(msg.wps_state, "session_overlap") == "session_overlap") then
                    cb('wps_registration_fail')
                    update_led_status(cb, "wps", "wps_ko", "timerled", "red-solid")
                end
            elseif string.match(msg.wps_state, "inprogress") == "inprogress" then
                cb('wps_registration_ongoing')
                update_led_status(cb, "wps", "wps_ongoing", "persistent", "green-blink")
            end
        end
    end

    events['fwupgrade'] = function(msg)
        if msg ~= nil and msg.state ~= nil and led.broadband.status ~= "initial" then
            cb("fwupgrade_state_" .. msg.state)

            if msg.state == "failed" then
                update_led_status(cb, "broadband", "upgrade_ko", "timerled", "red-blink")
            elseif msg.state == "upgrading" then
                update_led_status(cb, "broadband", "upgrade_ongoing", "persistent", "green-blink")
			elseif msg.state == "done" then 
				update_led_status(cb, "broadband", "ping_ok", "timerled", "green-blink")
            end
        end
    end

    events['system.startup'] = function(msg)
        if msg ~= nil and msg.state ~= nil and led.broadband.status == "initial" then
            cb("system_startup_" .. msg.state)
            -- If there is no other broadband led event untill system startup, we regard there is no wan line.
            update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
        end
    end

    events['reset.button'] = function(msg)
        if msg ~= nil and msg.action ~= nil then
            if msg.action == "pressed" then
                -- Changes to 'reset_prepare' pattern, so that line led can go its prior status if reset aborted.
                -- Broadband led status will be controlled according to pattern when reset pressed, don't change its status.
                -- However we still need to set the ambient led 'off' since line led 'on' during 'reset_prepare' and 'reset_ongoing'.

                if led.broadband.status ~= "initial" then
                    cb('reset_prepare')
                    cb('service_led_on')
                    led.ambient.status = "off"
                    export_led_color("ambient", "off")
                end

                reset_timer = uloop.timer(function() cb('reset_ongoing') end, reset_timeout)
            elseif msg.action == "released" then
                if string.match(msg.resetinfo, "factory") == "factory" then
                    -- Broadband led status will be controlled according to pattern when reset pressed, don't change its status.
                    -- Ambient led has been set during the pre-condition pattern 'reset_prepare', no need to reset here.
                    cb('reset_ongoing')
                elseif string.match(msg.resetinfo, "abort") == "abort" or string.match(msg.resetinfo, "complete") == "complete" then
                    cb('reset_noaction')
                    reset_timer:cancel()
                    reset_timer = nil

                    if led.broadband.status == "off" and (led.wireless.status == "off" or led.wireless.status == "initial") and (led.wps.status == "off" or led.wps.status == "initial") then
                        -- Always update ambient status inspite of its pattern, so that status can be represent as soon as it gets active.
                        cb('service_led_off')
                        led.ambient.status = "on"
                        export_led_color("ambient", "white-solid")
                    end
                end
            end
        end 
    end

    events['sfp'] = function(msg)
        if msg ~= nil and msg.status ~= nil then
            if string.match(msg.status, "tx_enable") == "tx_enable" then
                if wan_status == "ifup" then
                    if led.broadband.status == "no_line" or led.broadband.status == "sync" then
                        cb('network_interface_wan_ifup')
                        update_led_status(cb, "broadband", "ip_connected", "timerled", "green-solid")
                    end
                elseif wan_status == "ifdown" then
                    cb('network_device_eth_wan_ifup')
                    update_led_status(cb, "broadband", "sync", "persistent", "red-blink")
                end

                linkstatus = "up"
            elseif string.match(msg.status, "tx_disable") == "tx_disable" then
                cb('network_device_eth_wan_ifdown')
                update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                linkstatus = "down"
            end
        end
    end

    conn:listen(events)

    --register for netlink events
    local nl,err = netlink.listen(function(dev, status)
        cursor:load("network")
        local broadband_ifname = nil

        broadband_ifname = cursor:get("network", "wan", "ifname")
        if broadband_ifname ~= nil and string.sub(broadband_ifname, 1, 1) == '@' then
          local at_intf = string.sub(broadband_ifname, 2, -1)
          if at_intf ~= nil then
            broadband_ifname = cursor:get("network", at_intf, "ifname")
          end
        end

        -- Eth4 status represents SFP module.
        -- Other eth interface is possible to be set as WAN interface also according to fastweb.
        if (string.match(dev, "eth") == "eth" and broadband_ifname ~= nil and dev == broadband_ifname) then
            if status then
                if led.broadband.status == "initial" or led.broadband.status == "no_line" then
                    cb('network_device_eth_wan_ifup')
                    update_led_status(cb, "broadband", "sync", "persistent", "red-blink")
                    linkstatus = "up"
                end
            else
                cb('network_device_eth_wan_ifdown')
                update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                linkstatus = "down"
            end

        end
        cursor:unload("network")
    end)

    if not nl then
        error("Failed to register with netlink" .. err)
    end

    uloop.run()
end

return M
