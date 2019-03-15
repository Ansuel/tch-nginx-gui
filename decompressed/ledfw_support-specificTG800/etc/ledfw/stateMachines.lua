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
                staticLed("voip:green", false),
				staticLed("voip:white", false),
				staticLed("voip:blue", false),
				staticLed("voip:purple", false)
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
                power_service_notok = "service_notok",
                thermalProtection_overheat = "power_overheated",
            },
            service_ok_eco = {
                power_service_fullpower = "service_ok_fullpower",
                power_service_notok = "service_notok",
                thermalProtection_overheat = "power_overheated"
            },
            power_overheated = {
                power_service_eco = "service_ok_eco",
                thermalProtection_operational = "service_ok_fullpower",
            },
            service_ok_fullpower = {
                power_service_eco = "service_ok_eco",
                power_service_notok = "service_notok",
                thermalProtection_overheat = "power_overheated",
            },
            service_notok = {
                power_service_eco = "service_ok_eco",
                power_service_fullpower = "service_ok_fullpower",
                thermalProtection_overheat = "power_overheated"
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
            power_overheated = {
                staticLed("power:orange", false),
                staticLed("power:red", true),
                staticLed("power:blue", false),
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
            power_overheated = { "fw_upgrade" },
            service_ok_eco = { "fw_upgrade" },
            service_ok_fullpower = { "fw_upgrade" },
            service_notok = { "fw_upgrade" }
        }
    },
    broadband = {
        initial = "idling",
        transitions = {
            idling = {
                xdsl_1 = "training",
                xdsl_2 = "synchronizing",--for ADSL event
                xdsl_6 = "synchronizing", --for VDSL event
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
                staticLed("ethernet:green", false),
                staticLed("ethernet:red", false),
                staticLed("ethernet:white", false),
                staticLed("ethernet:blue", false),
                netdevLed("ethernet:green", 'eth4', 'link'),
            },
            training = {
                staticLed("ethernet:green", false),
                staticLed("ethernet:red", false),
                staticLed("ethernet:blue", false),
                staticLed("ethernet:white", true),
            },
            synchronizing = {
                staticLed("ethernet:green", false),
                staticLed("ethernet:red", false),
                staticLed("ethernet:white", false),
                staticLed("ethernet:blue", true)
            },
            connected = {
                staticLed("ethernet:white", false),
                staticLed("ethernet:red", false),
                staticLed("ethernet:blue", false),
                staticLed("ethernet:green", true)
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
                network_interface_connected_without_bigpond = "internet_connected",
                network_interface_broadband_ifup = "internet_connecting",
                network_interface_wan_ppp_connecting = "internet_connecting",
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan6_ifup = "internet_connected",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
            },
            internet_connecting = {
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan_off_wan6_off = "internet_disconnected",
                network_interface_connected_without_bigpond = "internet_connected",
                network_interface_connected_with_bigpond = "internet_bigpond_connected",
                network_interface_wan_ppp_disconnected = "internet_disconnected",
                network_interface_wan_ppp_authenticating = "internet_ppp_authenticating",
            },
            internet_connected = {
                network_interface_wan_off_wan6_off = "internet_disconnected",
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_connected_with_bigpond = "internet_bigpond_connected",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
            },
            internet_bigpond_connected = {
                network_interface_wan_off_wan6_off = "internet_disconnected",
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan6_ifup = "internet_connected",
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_connected_without_bigpond = "internet_connected",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
            },
            internet_ppp_authenticating = {
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan_ppp_disconnecting = "internet_ppp_authentication_failed",
                network_interface_wan_ppp_connected = "internet_connecting",
            },
            internet_ppp_authentication_failed = {
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan_ppp_connected = "internet_connecting",
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan6_ifup = "internet_connected",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
            },
            internet_connected_mobiledongle = {
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_connected_without_bigpond = "internet_connected",
                network_interface_connected_with_bigpond = "internet_bigpond_connected",
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan6_ifup = "internet_connected",
                network_interface_wwan_ifdown = "internet_disconnected",
            }
        },
        actions = {
            internet_disconnected = {
                staticLed("internet:green", false),
                staticLed("internet:red", true),
                staticLed("internet:blue", false),
                staticLed("internet:white", false),
            },
            internet_connecting = {
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("internet:blue", false),
                staticLed("internet:white", true),
            },
            internet_bigpond_connected = {
                staticLed("internet:white", false),
                staticLed("internet:red", false),
                staticLed("internet:green", false),
                staticLed("internet:blue", true),
            },
            internet_connected = {
                staticLed("internet:white", false),
                staticLed("internet:blue", false),
                staticLed("internet:red", false),
                staticLed("internet:green", true),
            },
            internet_ppp_authenticating = {
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("internet:blue", false),
                staticLed("internet:white", true),
            },
            internet_ppp_authentication_failed = {
                staticLed("internet:white", false),
                staticLed("internet:green", false),
                staticLed("internet:blue", false),
                staticLed("internet:red", true),
            },
            internet_connected_mobiledongle = {
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("internet:blue", false),
                staticLed("internet:magenta", true),
            },
        },
		patterns_depend_on = {
            internet_disconnected = {"status"},
            internet_connecting = {"status"},
            internet_bigpond_connected = {"status"},
            internet_connected = {"status"},
            internet_ppp_authenticating = {"status"},
            internet_ppp_authentication_failed = {"status"},
            internet_connected_mobiledongle = {"status"},
        }
    },
    wifi = {
        initial = "wifi_off",
        transitions = {
            wifi_off = {
                wifi_leds_on = "wifi_on",
                wifi_state_on_wl0 = "wifi_on",
                wifi_state_on_wl1 = "wifi_on",
                network_interface_fonopen_ifup = "wifi_telstra_air_broadcasting",
            },
            wifi_on = {
                wifi_leds_off = "wifi_off",
                wifi_state_wl0_off_wl1_off = "wifi_off",
                network_interface_fonopen_ifup = "wifi_telstra_air_broadcasting",
            },
            wifi_telstra_air_broadcasting = {
                wifi_leds_off = "wifi_off",
                wifi_state_wl0_off_wl1_off = "wifi_off",
                network_interface_fonopen_ifdown = "wifi_on",
            },
        },
        actions = {
            wifi_off = {
                staticLed("wireless:green", false),
                staticLed("wireless:red", false),
                staticLed("wireless:white", false),
                staticLed("wireless:blue", false),
                staticLed("wireless:magenta", false)
            },
            wifi_on = {
                staticLed("wireless:red", false),
                staticLed("wireless:blue", false),
                staticLed("wireless:green", true),
            },
            wifi_telstra_air_broadcasting = {
                staticLed("wireless:green", true),
                staticLed("wireless:red", false),
                staticLed("wireless:blue", false),
            },
        },
		patterns_depend_on = {
            wifi_off = {"status"},
            wifi_on = {"status"},
            wifi_telstra_air_broadcasting = {"status"},
        }
    },
    dect_wps ={
      initial = "off",
      transitions = {
            off = {
                pairing_inprogress = "pairing_inprogress",
                pairing_success = "pairing_success",
                paging_alerting_true = "paging_alerting"
            },
            pairing_inprogress = {
                pairing_off = "off",
                pairing_success = "pairing_success",
                pairing_error = "pairing_error",
                pairing_overlap = "pairing_overlap",
                paging_alerting_true = "paging_alerting",
                profile_state_stop = "off"
            },
            pairing_error = {
                pairing_off = "off",
                pairing_success = "pairing_success",
                pairing_inprogress = "pairing_inprogress",
                pairing_overlap = "pairing_overlap",
                paging_alerting_true = "paging_alerting",
                profile_state_stop = "off"
            },
            pairing_overlap = {
                pairing_off = "off",
                pairing_success = "pairing_success",
                pairing_inprogress = "pairing_inprogress",
                pairing_error = "pairing_error",
                paging_alerting_true = "paging_alerting",
                profile_state_stop = "off"
            },
            pairing_success = {
                pairing_off = "off",
                pairing_overlap = "pairing_overlap",
                pairing_inprogress = "pairing_inprogress",
                pairing_error = "pairing_error",
                paging_alerting_true = "paging_alerting",
                profile_state_stop = "off"
            },
            paging_alerting = {
                paging_alerting_false = "pairing_success",
                pairing_off = "off",
                pairing_success = "pairing_success",
                pairing_inprogress = "pairing_inprogress",
                pairing_error = "pairing_error",
                profile_state_stop = "off"
            }
        },
        actions = {
            off = {
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                staticLed("dect:blue", false),
                staticLed("dect:white", false)
            },
            pairing_inprogress ={
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                staticLed("dect:blue", false),
                timerLed("dect:white", 400, 400)
            },
            pairing_error ={
                staticLed("dect:white", false),
                staticLed("dect:green", false),
                staticLed("dect:blue", false),
                timerLed("dect:red", 100, 100)
            },
            pairing_success ={
                staticLed("dect:white", false),
                staticLed("dect:red", false),
                staticLed("dect:blue", false),
                staticLed("dect:green", true)
            },
            pairing_overlap ={
                staticLed("dect:white", false),
                staticLed("dect:blue", false),
                staticLed("dect:green", false),
                timerLed("dect:red", 1000, 1000)
            },
            paging_alerting ={
                staticLed("dect:white", false),
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                timerLed("dect:blue", 400, 400)
            }
        },
		patterns_depend_on = {
            off = {"status"},
            pairing_inprogress = {"status"},
            pairing_error = {"status"},
			pairing_success = {"status"},
			pairing_overlap = {"status"},
			paging_alerting = {"status"},
        }
    },

    voip = {
        initial = "off",
        transitions = {
            off = {
                profile_register_registering = "profile_registering",
                profile_register_registered = "profile_registered"
            },
            profile_registering = {
                profile_register_unregistered = "off",
                profile_register_registered = "profile_registered",
                new_call_started = "voip_on_registering",
                profile_state_stop = "off"
            },
            profile_registered = {
                profile_register_unregistered = "off",
                profile_register_registering = "profile_registering",
                new_call_started = "voip_on_registered",
                profile_state_stop = "off"
            },
            voip_on_registered = {
                profile_register_unregistered = "voip_on_unregistered",
                profile_register_registering = "voip_on_registering",
                all_calls_ended = "profile_registered",
                profile_state_stop = "off"
            },
            voip_on_registering = {
                profile_register_unregistered = "voip_on_unregistered",
                profile_register_registered = "voip_on_registered",
                all_calls_ended = "profile_registering",
                profile_state_stop = "off"
            },
            voip_on_unregistered = {
                profile_register_registering = "voip_on_registering",
                profile_register_registered = "voip_on_registered",
                all_calls_ended = "off",
                profile_state_stop = "off"
            }
        },
        actions = {
            off = {
                staticLed("voip:white", false),
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", false)
            },
            profile_registering = {
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", false),
                staticLed("voip:white", true)
            },
            profile_registered = {
                staticLed("voip:white", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", false),
                staticLed("voip:green", true)
            },
            voip_on_registered = {
                staticLed("voip:white", false),
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", true)
            },
            voip_on_registering = {
                staticLed("voip:white", false),
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", true)
            },
            voip_on_unregistered = {
                staticLed("voip:white", false),
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", true)
            }
        },
		patterns_depend_on = {
            off = {"status"},
            profile_registering = {"status"},
            profile_registered = {"status"},
			voip_on_registered = {"status"},
			voip_on_registering = {"status"},
			voip_on_unregistered = {"status"},
        }
    }
}