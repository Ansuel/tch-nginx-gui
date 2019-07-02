-- The only available function is helper (ledhelper)
local timerLed, staticLed, runFunc, patternLed = timerLed, staticLed, runFunc, patternLed

patterns = {
    ambient_status = {
        state = "ambient_active", -- default state, indicates this pattern is inactive state, in which led stateMachine doesn't depend on it. 
        transitions = {
            ambient_active = { -- ambient means it can be lighting on or off, active to accept control
                ambient_switch_off = "ambient_inactive",
            },
            ambient_inactive = {  -- ambient leds are switched off by user or timer scheduler 
                ambient_switch_on = "ambient_active",
            },
        },
        actions = {
            ambient_inactive = {
                staticLed("ambient1:white", false),
                staticLed("ambient2:white", false),
                staticLed("ambient3:white", false),
                staticLed("ambient4:white", false),
                staticLed("ambient5:white", false),
            },
        },
    },
    reset_status = {
        state = "reset_noaction",
        transitions = {
            reset_noaction = {
                reset_pressed = "reset_prepare",
            },
            reset_prepare = {
                reset_abort = "reset_noaction",
                reset_factory = "reset_ongoing",
            },
            reset_ongoing = {
                reset_complete = "reset_noaction",
            },
        },
        actions = {
            reset_prepare = {
                staticLed("broadband:red", false),
                staticLed("broadband:orange", false),
                timerLed("broadband:green", 150, 150),
            },
            reset_ongoing = {
                staticLed("broadband:red", false),
                staticLed("broadband:orange", false),
                timerLed("broadband:green", 400, 400),
            },
        }
    },
	fw_upgrade = {
        state = "fwupgrade_state_done",
        transitions = {
            fwupgrade_state_done = {
                fwupgrade_state_upgrading = "fwupgrade_state_upgrading",
            },
            fwupgrade_state_upgrading = {
                fwupgrade_state_done = "fwupgrade_state_done"
            }
        },
        actions = {
            fwupgrade_state_upgrading = {
                patternLed("ambient1:white", "10000000", 500),
                patternLed("ambient2:white", "01000001", 500),
                patternLed("ambient3:white", "00100010", 500),
                patternLed("ambient4:white", "00010100", 500),
                patternLed("ambient5:white", "00001000", 500),
            }
        }
    }
}

stateMachines = {
    ambient = {
        initial = "ambient_loop",
        transitions = {
            ambient_loop = {
                service_led_on = "ambient_off",
                service_led_off = "ambient_on",
            },
            ambient_off = {
                service_led_off = "ambient_on",
            },
            ambient_on = {
                service_led_on = "ambient_off",
            },
        },
        actions = {
            ambient_loop = {
                patternLed("ambient1:white", "10000000", 500),
                patternLed("ambient2:white", "01000001", 500),
                patternLed("ambient3:white", "00100010", 500),
                patternLed("ambient4:white", "00010100", 500),
                patternLed("ambient5:white", "00001000", 500),
            },
            ambient_on = {
                staticLed("ambient1:white", true),
                staticLed("ambient2:white", true),
                staticLed("ambient3:white", true),
                staticLed("ambient4:white", true),
                staticLed("ambient5:white", true),
            },
            ambient_off = {
                staticLed("ambient1:white", false),
                staticLed("ambient2:white", false),
                staticLed("ambient3:white", false),
                staticLed("ambient4:white", false),
                staticLed("ambient5:white", false),
            },
        },
        patterns_depend_on = {  -- if ambient inactive, doesn't light.
            ambient_on = {"ambient_status","fw_upgrade"},
        },
    },

    broadband = {
        initial = "initial_idle", --initializing
        transitions = {
            initial_idle = {
                system_startup_complete = "red_solid",  -- if no line and initializing completed
                xdsl_0 = "red_solid", --link synchronizing failed
                xdsl_1 = "synchronizing_red_flashing", -- training
                xdsl_2 = "synchronizing_red_flashing", -- for ADSL
                xdsl_3 = "synchronizing_red_flashing",
                xdsl_4 = "synchronizing_red_flashing",
                xdsl_5 = "synchronizing_red_flashing", -- Showtime
                xdsl_6 = "synchronizing_red_flashing", -- for VDSL
                network_device_eth_wan_ifup = "synchronizing_red_flashing", -- starts eth wan synchronizing
                network_device_eth_wan_ifdown = "red_solid", -- eth wan down
                network_interface_wan_ifup = "green_solid",
                network_interface_wan_ifdown = "synchronizing_red_flashing",
            },
            synchronizing_red_flashing = {  --status: synchronizing or retrieving IP
                xdsl_0 = "red_solid", --link synchronizing failed
                network_device_eth_wan_ifdown = "red_solid", -- eth wan down
                network_interface_wan_ifup = "green_solid",
                fwupgrade_state_upgrading = "writing_firmware_green_flashing_quickly",
            },
            green_solid = {  --status: ip connected
                xdsl_0 = "red_solid", --xdsl synchronizing failed
                xdsl_1 = "synchronizing_red_flashing",
                xdsl_2 = "synchronizing_red_flashing",
                xdsl_3 = "synchronizing_red_flashing",
                xdsl_4 = "synchronizing_red_flashing",
                -- xdsl_5 is Showtime staus, don't response when layer3 interface UP.
                xdsl_6 = "synchronizing_red_flashing",
                network_device_eth_wan_ifdown = "red_solid", -- eth wan down
                network_interface_wan_ifdown = "synchronizing_red_flashing",
                ping_failed = "serviceko_red_flashing",
                ping_success = "serviceok_green_flashing_quickly",
                broadband_led_timeout = "broadbandled_off",  -- turns led off
                fwupgrade_state_upgrading = "writing_firmware_green_flashing_quickly",
            },
            serviceko_red_flashing = {  --status: ping failed
                xdsl_0 = "red_solid", --xdsl synchronizing failed
                xdsl_1 = "synchronizing_red_flashing",
                xdsl_2 = "synchronizing_red_flashing",
                xdsl_3 = "synchronizing_red_flashing",
                xdsl_4 = "synchronizing_red_flashing",
                xdsl_6 = "synchronizing_red_flashing",
                network_device_eth_wan_ifdown = "red_solid", -- eth wan down
                network_interface_wan_ifdown = "synchronizing_red_flashing",
                ping_success = "serviceok_green_flashing_quickly",
                ping_failed = "serviceko_red_flashing",
                broadband_led_timeout = "broadbandled_off",  -- turns led off
                fwupgrade_state_upgrading = "writing_firmware_green_flashing_quickly",
            },
            red_solid = {  --status: link synchronizing failed or no line
                xdsl_1 = "synchronizing_red_flashing", -- starts xdsl synchronizing
                xdsl_2 = "synchronizing_red_flashing",
                xdsl_3 = "synchronizing_red_flashing",
                xdsl_4 = "synchronizing_red_flashing",
                xdsl_5 = "synchronizing_red_flashing",
                xdsl_6 = "synchronizing_red_flashing",
                network_device_eth_wan_ifup = "synchronizing_red_flashing", -- starts eth wan synchronizing
                network_interface_wan_ifup = "green_solid",
                fwupgrade_state_upgrading = "writing_firmware_green_flashing_quickly",
            },
            serviceok_green_flashing_quickly = {  --status: ping success
                xdsl_0 = "red_solid", --xdsl synchronizing failed
                xdsl_1 = "synchronizing_red_flashing",
                xdsl_2 = "synchronizing_red_flashing",
                xdsl_3 = "synchronizing_red_flashing",
                xdsl_4 = "synchronizing_red_flashing",
                xdsl_6 = "synchronizing_red_flashing",
                network_device_eth_wan_ifdown = "red_solid", -- eth wan down
                network_interface_wan_ifdown = "synchronizing_red_flashing",
                ping_failed = "serviceko_red_flashing",
                broadband_led_timeout = "broadbandled_off",  -- turns led off
                fwupgrade_state_upgrading = "writing_firmware_green_flashing_quickly",
            },
            writing_firmware_green_flashing_quickly = {  --status: writing firmware
                fwupgrade_state_failed = "serviceko_red_flashing",
            },
            broadbandled_off = {  --status: 5 seconds after ip connected or service status indicating 
                xdsl_0 = "red_solid",
                xdsl_1 = "synchronizing_red_flashing",
                xdsl_2 = "synchronizing_red_flashing",
                xdsl_3 = "synchronizing_red_flashing",
                xdsl_4 = "synchronizing_red_flashing",
                xdsl_6 = "synchronizing_red_flashing",
                network_device_eth_wan_ifdown = "red_solid", -- eth wan down
                network_interface_wan_ifdown = "synchronizing_red_flashing",
                ping_success = "serviceok_green_flashing_quickly",
                ping_failed = "serviceko_red_flashing",
                fwupgrade_state_upgrading = "writing_firmware_green_flashing_quickly",
            },
        },
        actions = {
            initial_idle = {
                staticLed("broadband:green", false),
                staticLed("broadband:red", false),
            },
            nolink_red_solid = {
                staticLed("broadband:green", false),
                staticLed("broadband:red", true),
            },
            green_solid = {
                staticLed("broadband:red", false),
                staticLed("broadband:green", true),
            },
            serviceok_green_flashing_quickly = {
                staticLed("broadband:red", false),
                timerLed("broadband:green", 250, 250),
            },
            writing_firmware_green_flashing_quickly = {
                staticLed("broadband:red", false),
                timerLed("broadband:green", 250, 250),
            },
            red_solid = {
                staticLed("broadband:red", true),
                staticLed("broadband:green", false),
            },
            synchronizing_red_flashing = {
                staticLed("broadband:green", false),
                timerLed("broadband:red", 250, 250),
            },
            serviceko_red_flashing = {
                staticLed("broadband:green", false),
                timerLed("broadband:red", 250, 250),
            },
            broadbandled_off = {
                staticLed("broadband:green", false),
                staticLed("broadband:red", false),
            },
        },
        patterns_depend_on = {
            initial_idle = {"reset_status"},
            nolink_red_solid = {"reset_status"},
            green_solid = {"reset_status"},
            serviceok_green_flashing_quickly = {"reset_status"},
            writing_firmware_green_flashing_quickly = {"reset_status"},
            red_solid = {"reset_status"},
            synchronizing_red_flashing = {"reset_status"},
            serviceko_red_flashing = {"reset_status"},
            broadbandled_off = {"reset_status"},
        },
    },

    wireless = {
        initial = "wirelessled_off", --initially the wireless led is off
        transitions = {
            wirelessled_off = {
                wifi_both_radio_off = "red_solid",
                channel_analyzing = "channel_analyzing_green_flashing",
            },
            channel_analyzing_green_flashing = {  --status: synchronizing or retrieving IP
                best_channel_inuse = "best_channel_inuse_green_solid",
                not_best_channel_inuse = "red_solid",
            },
            best_channel_inuse_green_solid = {  --status: ip connected
                channel_analyzing = "channel_analyzing_green_flashing",
                wireless_led_timeout = "wirelessled_off",
            },
            red_solid = {  --status: link synchronizing failed or no line
                channel_analyzing = "channel_analyzing_green_flashing",
                wireless_led_timeout = "wirelessled_off",
            },
        },
        actions = {
            wirelessled_off = {
                staticLed("wireless:green", false),
                staticLed("wireless:red", false),
                staticLed("wireless:orange", false),
            },
            channel_analyzing_green_flashing = {
                staticLed("wireless:red", false),
                staticLed("wireless:orange", false),
                timerLed("wireless:green", 250, 250),
            },
            best_channel_inuse_green_solid = {
                staticLed("wireless:red", false),
                staticLed("wireless:orange", false),
                staticLed("wireless:green", true),  -- true must be set at last
            },
            red_solid = {
                staticLed("wireless:green", false),
                staticLed("wireless:orange", false),
                staticLed("wireless:red", true),  -- true must be set at last
            },
        },
    },

    wps = {
        initial = "wpsled_off",  --initially the wps led is off
        transitions = {
            wpsled_off = {
                wps_activate_radio = "green_solid",
                wps_registration_ongoing = "wps_ongoing_green_flashing",
                wps_registration_fail = "wps_registration_fail_red_solid",
            },
            wps_ongoing_green_flashing = {
                wps_registration_success = "green_solid",
                wps_registration_fail = "wps_registration_fail_red_solid",
            },
            green_solid = {
                wps_registration_ongoing = "wps_ongoing_green_flashing",
                wps_led_timeout = "wpsled_off",
            },
            wps_registration_fail_red_solid = {
                wps_registration_ongoing = "wps_ongoing_green_flashing",
                wps_led_timeout = "wpsled_off",
            },
        },
        
        actions = {
            wpsled_off = {
                staticLed("wps:green", false),
                staticLed("wps:red", false),
                staticLed("wps:orange", false),
            },
            wps_ongoing_green_flashing = {
                staticLed("wps:red", false),
                staticLed("wps:orange", false),
                timerLed("wps:green", 250, 250),
            },
            green_solid = {
                staticLed("wps:red", false),
                staticLed("wps:orange", false),
                staticLed("wps:green", true), -- true must be set at last
            },
            wps_registration_fail_red_solid = {
                staticLed("wps:green", false),
                staticLed("wps:orange", false),
                staticLed("wps:red", true), -- true must be set at last
            },
        },
    },
}
