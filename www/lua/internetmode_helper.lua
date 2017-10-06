return {
    {
        name = "dhcp",
        default = true,
        description = "DHCP routed mode",
        view = "internet-dhcp-routed.lp",
        card = "003_internet_dhcp_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^dhcp$"},
			{ "uci.wansensing.global.enable", "^1$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "dhcp"},
        },
    },
    {
        name = "pppoe",
        default = false,
        description = "PPPoE routed mode",
        view = "internet-pppoe-routed.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^pppoe$"},
			{ "uci.wansensing.global.enable", "^1$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "pppoe"},
        },
    },
    {
        name = "pppoa",
        default = false,
        description = "PPPoA routed mode",
        view = "internet-pppoa-routed.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^pppoa$"},
			{ "uci.wansensing.global.enable", "^1$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "pppoa"},
        },
    },
    {
        name = "static",
        default = false,
        description = "Fixed IP mode",
        view = "internet-static-routed.lp",
        card = "003_internet_static_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^static$"},
			{ "uci.wansensing.global.enable", "^1$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "static"},
        },
    },
	{
        name = "bridge",
        default = false,
        description = "Bridge mode",
        view = "internet-bridged.lp",
        card = "003_internet_bridged.lp",
        check = {
            { "uci.wansensing.global.enable", "^0$"},
        },
        operations = {
        },
    },
}
