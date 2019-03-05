-- The only available function is helper (ledhelper)
local timerLed, staticLed, netdevLed, netdevLedOWRT = timerLed, staticLed, netdevLed, netdevLedOWRT

patterns = {
    status = {
        state = "status_inactive",
        transitions = {
            status_inactive = {
                status_ok = "status_active",
            },
            status_active = {
                status_nok = "status_inactive",
            },
        },
        actions = {
            status_active = {
                staticLed("broadband:red", false),
                staticLed("broadband:green", false),
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("iptv:green", false),
                staticLed("iptv:red", false),
                staticLed("ethernet:green", false),
                staticLed("wireless:green", false),
                staticLed("wireless:red", false),
                staticLed("wireless_5g:green", false),
                staticLed("wireless_5g:red", false),
                staticLed("wps:orange", false),
                staticLed("wps:red", false),
                staticLed("wps:green", false),
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                staticLed("dect:orange", false),
                staticLed("voip:green", false)
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
                timerLed("power:blue", 50, 50)
            }
        }
    }
}

stateMachines = {
    power = {
        initial = "power_started",
        transitions = {
            power_started = {
                power_service_eco = "service_ok_eco",
                power_service_fullpower = "service_ok_fullpower",
                power_service_notok = "service_notok"
            },
            service_ok_eco = {
                power_service_fullpower = "service_ok_fullpower",
                power_service_notok = "service_notok"
            },
            service_ok_fullpower = {
                power_service_eco = "service_ok_eco",
                power_service_notok = "service_notok"
            },
            service_notok = {
                power_service_fullpower = "service_ok_fullpower",
                power_service_eco = "service_ok_eco"
            }
        },
        actions = {
            power_started = {
                staticLed("power:orange", false),
                staticLed("power:red", false),
                staticLed("power:blue", false),
                staticLed("power:green", true)
            },
            service_ok_eco = {
                staticLed("power:orange", false),
                staticLed("power:red", false),
                staticLed("power:blue", true),
                staticLed("power:green", false)
            },
            service_ok_fullpower = {
                staticLed("power:orange", false),
                staticLed("power:red", false),
                staticLed("power:blue", false),
                staticLed("power:green", true)
            },
            service_notok = {
                staticLed("power:orange", false),
                staticLed("power:red", true),
                staticLed("power:blue", false),
                staticLed("power:green", false)
            }
        },
        patterns_depend_on = {
            power_started = { "fw_upgrade" },
            service_ok_fullpower = { "fw_upgrade" },
            service_ok_eco = { "fw_upgrade" },
            service_notok = { "fw_upgrade" }
        }
    },
    broadband = {
        initial = "idling",
        transitions = {
            idling = {
                xdsl_1 = "training",
                xdsl_2 = "synchronizing",
                xdsl_6 = "synchronizing",
            },
            training = {
                xdsl_0 = "idling",
                xdsl_2 = "synchronizing",
                xdsl_6 = "synchronizing",
            },
            synchronizing = {
                xdsl_0 = "idling",
                xdsl_1 = "training",
                xdsl_5 = "connected",
            },
            connected = {
                xdsl_0 = "idling",
                xdsl_1 = "training",
                xdsl_2 = "synchronizing",
                xdsl_6 = "synchronizing",
            },
        },
        actions = {
            idling = {
                netdevLed("broadband:green", 'eth4', 'link'),
            },
            training = {
                timerLed("broadband:green", 250, 250)
            },
            synchronizing = {
                timerLed("broadband:green", 125, 125)
            },
            connected = {
                staticLed("broadband:green", true)
            },
        },
		patterns_depend_on = {
            idling = {"status"},
            training = {"status"},
            synchronizing = {"status"},
            connected = {"status"},
        }
    },
    internet = {
        initial = "internet_disconnected",
        transitions = {
            internet_disconnected = {
                network_interface_wan_ifup = "internet_connected_wan",
                network_interface_wan6_ifup = "internet_connected_wan6",
                network_interface_broadband_ifup = "internet_connecting",
                network_interface_wan_ppp_connecting = "internet_connecting"
            },
            internet_connecting = {
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan_off_wan6_off = "internet_disconnected",
                network_interface_wan6_ifup = "internet_connected_wan6",
                network_interface_wan_ifup = "internet_connected_wan",
                network_interface_wan_ppp_disconnected = "internet_disconnected"
            },
            internet_connected_wan = {
                network_interface_wan_off_wan6_off = "internet_disconnected",
                network_interface_broadband_ifdown = "internet_disconnected",
            },
            internet_connected_wan6 = {
                network_interface_wan_off_wan6_off = "internet_disconnected",
                network_interface_broadband_ifdown = "internet_disconnected",
            }
        },
        actions = {
            internet_disconnected = {
                staticLed("internet:green", false),
                staticLed("internet:red", true)
            },
            internet_connecting = {
                staticLed("internet:green", false),
-- timerLed("internet:red", 500, 500), was not behaving as expected; using same values since last time when setting timerLed for same LED can cause LED *NOT* to blink at all;
-- Probably LED driver problem; workaround is setting twice with different values
                timerLed("internet:red", 498, 502),
                timerLed("internet:red", 499, 501)
            },
            internet_connected_wan = {
                netdevLedOWRT("internet:green", 'wan', 'link tx rx'),
                staticLed("internet:red", false)
            },
            internet_connected_wan6 = {
                netdevLedOWRT("internet:green", 'wan6', 'link tx rx'),
                staticLed("internet:red", false)
            }

        },
		patterns_depend_on = {
            internet_disconnected = {"status"},
            internet_connecting = {"status"},
            internet_connected_wan = {"status"},
            internet_connected_wan6 = {"status"},
        }
    },
    ethernet = {
        initial = "ethernet",
        transitions = {
        },
        actions = {
            ethernet = {
                netdevLed("ethernet:green", 'eth0 eth1 eth2 eth3', 'link tx rx')
            }
        },
		patterns_depend_on = {
            ethernet = {"status"},
        },
    },
    wifi = {
        initial = "wifi_off",
        transitions = {
            wifi_off = {
                wifi_leds_on = "wifi_security",
                wifi_security_wpapsk_wl0 = "wifi_security",
                wifi_security_wpa_wl0 = "wifi_security",
                wifi_security_wep_wl0 = "wifi_wep",
                wifi_security_disabled_wl0 = "wifi_nosecurity",
            },
            wifi_nosecurity = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl0 = "wifi_off",
                wifi_security_wpapsk_wl0 = "wifi_security",
                wifi_security_wpa_wl0 = "wifi_security",
                wifi_security_wep_wl0 = "wifi_wep",
            },
            wifi_wep = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl0 = "wifi_off",
                wifi_security_wpapsk_wl0 = "wifi_security",
                wifi_security_wpa_wl0 = "wifi_security",
                wifi_security_disabled_wl0 = "wifi_nosecurity",
            },
            wifi_security = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl0 = "wifi_off",
                wifi_security_wep_wl0 = "wifi_wep",
                wifi_security_disabled_wl0 = "wifi_nosecurity",
            }
        },
        actions = {
            wifi_off = {
                staticLed("wireless:green", false),
                staticLed("wireless:red", false),
            },
            wifi_nosecurity = {
                netdevLed("wireless:red", 'wl0', 'link tx rx'),
                netdevLed("wireless:green", 'wl0', 'link tx rx'),
            },
            wifi_wep = {
                netdevLed("wireless:red", 'wl0', 'link tx rx'),
                netdevLed("wireless:green", 'wl0', 'link tx rx'),
            },
            wifi_security = {
                staticLed("wireless:red", false),
                netdevLed("wireless:green", 'wl0', 'link tx rx')
            }
        },
        patterns_depend_on = {
            wifi_off = {
                "status"
            },
            wifi_nosecurity = {
                "status"
            },
            wifi_wep = {
                "status"
            },
            wifi_security = {
                "status"
            }
        }
    },
    wifi_5G = {
        initial = "wifi_off",
        transitions = {
            wifi_off = {
                wifi_leds_on = "wifi_security",
                wifi_security_wpapsk_wl1 = "wifi_security",
                wifi_security_wpa_wl1 = "wifi_security",
                wifi_security_wep_wl1 = "wifi_wep",
                wifi_security_disabled_wl1 = "wifi_nosecurity",
            },
            wifi_nosecurity = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl1 = "wifi_off",
                wifi_security_wpapsk_wl1 = "wifi_security",
                wifi_security_wpa_wl1 = "wifi_security",
                wifi_security_wep_wl1 = "wifi_wep",
            },
            wifi_wep = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl1 = "wifi_off",
                wifi_security_wpapsk_wl1 = "wifi_security",
                wifi_security_wpa_wl1 = "wifi_security",
                wifi_security_disabled_wl1 = "wifi_nosecurity",
            },
            wifi_security = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl1 = "wifi_off",
                wifi_security_wep_wl1 = "wifi_wep",
                wifi_security_disabled_wl1 = "wifi_nosecurity",
            }
        },
        actions = {
            wifi_off = {
                staticLed("wireless_5g:green", false),
                staticLed("wireless_5g:red", false),
            },
            wifi_nosecurity = {
                netdevLed("wireless_5g:red", 'wl1', 'link tx rx'),
                netdevLed("wireless_5g:green", 'wl1', 'link tx rx'),
            },
            wifi_wep = {
                netdevLed("wireless_5g:red", 'wl1', 'link tx rx'),
                netdevLed("wireless_5g:green", 'wl1', 'link tx rx'),
            },
            wifi_security = {
                staticLed("wireless_5g:red", false),
                netdevLed("wireless_5g:green", 'wl1', 'link tx rx')
            }
        },
        patterns_depend_on = {
            wifi_off = {
                "status"
            },
            wifi_nosecurity = {
                "status"
            },
            wifi_wep = {
                "status"
            },
            wifi_security = {
                "status"
            }
        }
    },
    wps ={
        initial = "off",
        transitions = {
            idle = {
                wifi_wps_inprogress = "inprogress",
                wifi_wps_off = "off"
            },
            inprogress = {
                wifi_wps_error = "error",
                wifi_wps_session_overlap = "session_overlap",
                wifi_wps_setup_locked = "setup_locked",
                wifi_wps_off = "off",
                wifi_wps_success = "success",
                wifi_wps_idle = "idle"
            },
            success = {
                wifi_wps_idle = "idle",
                wifi_wps_off = "off",
                wifi_wps_error = "error",
                wifi_wps_session_overlap = "session_overlap",
                wifi_wps_inprogress = "inprogress",
                wifi_wps_setup_locked = "setup_locked"
	    },
            setup_locked = {
                wifi_wps_off = "off",
                wifi_wps_inprogress = "inprogress",
                wifi_wps_idle = "idle"
            },
            error = {
                wifi_wps_off = "off",
                wifi_wps_inprogress = "inprogress",
                wifi_wps_idle = "idle"
            },
            session_overlap = {
                wifi_wps_off = "off",
                wifi_wps_inprogress = "inprogress",
                wifi_wps_idle = "idle"
            },
            off = {
                wifi_wps_inprogress = "inprogress",
                wifi_wps_idle = "idle"
            }

        },
        actions = {
            idle = {
                staticLed("wps:orange", false),
                staticLed("wps:red", false),
                staticLed("wps:green", false),
            },
            session_overlap = {
                staticLed("wps:orange", false),
                timerLed("wps:red", 1000, 1000),
                staticLed("wps:green", false),
            },
            error = {
                staticLed("wps:orange", false),
                timerLed("wps:red", 100, 100),
                staticLed("wps:green", false),
            },
            setup_locked = {
                staticLed("wps:orange", false),
                staticLed("wps:red", false),
                staticLed("wps:green", true),
            },
            off = {
                staticLed("wps:orange", false),
                staticLed("wps:red", false),
                staticLed("wps:green", false),
            },
            inprogress ={
                staticLed("wps:red", false),
                staticLed("wps:green", false),
                timerLed("wps:orange", 200, 100),
            },
            success = {
                staticLed("wps:orange", false),
                staticLed("wps:red", false),
                staticLed("wps:green", true),
            },
        },
        patterns_depend_on = {
            idle = {
                "status"
            },
            session_overlap = {
                "status"
            },
            setup_locked = {
                "status"
            },
            off = {
                "status"
            },
            success = {
                "status"
            }
        }
    },
    dect = {
        initial = "off",
        transitions = {
            off = {
                dect_registering_usable = "registering",
                dect_registering_unusable = "registering",
                dect_registered_usable = "registered",
                dect_registered_unusable = "registered",
            },
            registering = {
                dect_unregistered_unusable = "off",
                dect_unregistered_usable = "off",
                dect_registered_unusable = "registered",
                dect_registered_usable = "registered",
            },
            registered = {
                dect_unregistered_unusable = "off",
                dect_unregistered_usable = "off",
                dect_registering_usable = "registering",
                dect_registering_unusable = "registering",
            },
        },
        actions = {
            off = {
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                staticLed("dect:orange", false)
            },
            registering = {
                timerLed("dect:orange", 400, 400)
            },
            registered = {
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                staticLed("dect:green", true)
            },
        },
        patterns_depend_on = {
            off = {
                "status"
            },
            registering = {
                "status"
            },
            registered = {
                "status"
            }
        }
    },
    phone1 = {
        initial = "off",
        transitions = {
            profile_line1_usable = {
                    fxs_line1_off = "off",
                    fxs_line1_error = "profile_line1_unusable",
                    fxs_line1_inactive = "profile_line1_solid",
                    fxs_line1_active = "profile_line1_flash",
            },
            profile_line1_unusable = {
                    fxs_line1_off = "off",
                    fxs_line1_usable = "profile_line1_usable",
                },
            profile_line1_solid = {
                    fxs_line1_active = "profile_line1_flash",
                    fxs_line1_inactive = "profile_line1_usable",
                    fxs_line1_usable = "profile_line1_usable",
                    fxs_line1_error = "profile_line1_unusable",
                    fxs_line1_off = "off",
            },
            profile_line1_flash = {
                    fxs_line1_inactive = "profile_line1_solid",
                    fxs_line1_active  = "profile_line1_flash",
                    fxs_line1_error = "profile_line1_unusable",
                    fxs_line1_off = "off",
            },
            off = {
                    fxs_line1_usable = "profile_line1_usable",
                    fxs_line1_error = "profile_line1_unusable",
                    fxs_line1_off = "off",
            },
        },
        actions = {
            profile_line1_usable = {
                staticLed("iptv:green", true)
            },
            profile_line1_unusable = {
                staticLed("iptv:green", false)
            },
            profile_line1_solid = {
                staticLed("iptv:green", true)
           },
            profile_line1_flash = {
                timerLed("iptv:green", 100, 100)
            },
            off = {
                staticLed("iptv:green", false)
            },
        },
        patterns_depend_on = {
            profile_line1_usable = {
                 "status"
            },
            profile_line1_unusable = {
                 "status"
            },
            profile_line1_solid = {
                 "status"
            },
            profile_line1_flash = {
                 "status"
            },
            off = {
                 "status"
            }
        }
    },
    phone2 = {
        initial = "off",
        transitions = {
            profile_line2_usable = {
                    fxs_line2_error = "profile_line2_unusable",
                    fxs_line2_inactive = "profile_line2_solid",
                    fxs_line2_active = "profile_line2_flash",
                    fxs_line2_off = "off",
            },
            profile_line2_unusable = {
                    fxs_line2_off = "off",
                    fxs_line2_usable = "profile_line2_usable"
            },
            profile_line2_solid = {
                    fxs_line2_active = "profile_line2_flash",
                    fxs_line2_inactive = "profile_line2_usable",
                    fxs_line2_usable = "profile_line2_usable",
                    fxs_line2_error = "profile_line2_unusable",
                    fxs_line2_off = "off",
            },
            profile_line2_flash = {
                    fxs_line2_inactive = "profile_line2_solid",
                    fxs_line2_active  = "profile_line2_flash",
                    fxs_line2_error = "profile_line2_unusable",
                    fxs_line2_off = "off",
            },
            off = {
                    fxs_line2_usable = "profile_line2_usable",
                    fxs_line2_error = "profile_line2_unusable",
                    fxs_line2_off = "off",
            },
        },
        actions = {
            profile_line2_usable = {
                staticLed("voip:green", true)
            },
            profile_line2_unusable = {
                staticLed("voip:green", false)
            },
            profile_line2_solid = {
                staticLed("voip:green", true)
            },
            profile_line2_flash = {
                timerLed("voip:green", 100, 100)
            },
            off = {
                staticLed("voip:green", false)
            },
        },
        patterns_depend_on = {
            profile_line2_usable = {
                 "status"
            },
            profile_line2_unusable = {
                 "status"
            },
            profile_line2_solid = {
                 "status"
            },
            profile_line2_flash = {
                 "status"
            },
            off = {
                 "status"
            }
        }
    }
}
