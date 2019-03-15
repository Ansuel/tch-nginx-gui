--pretranslated: do not change this file
 ngx.print('<div class="container">\
    <div class="row">\
\
');  
    gettext.textdomain('webui-telstra')
    local content_helper = require("web.content_helper")

	local content_wansensing = {
		autofailover = "uci.wansensing.global.autofailover"
	}
	content_helper.getExactContent(content_wansensing)

	local mobiledongle_note = "<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;NOTE: If your gateway has mobile reception, you can connect your backup service by clicking <a href=/gateway.lp?openmodal=lte-modal.lp > here </a>"
	if content_wansensing.autofailover == "1" then
		mobiledongle_note = "<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;NOTE: If your gateway has mobile reception, your backup service will be connected automatically."
	end

    local ipairs, string = ipairs, string
    local items = {
        ["OK"] = {"ok", T"Your Broadband service is working normally. You are connected online."},
        ["OK_LTE"] = {"backup", T"Your Broadband service is working in backup mode. You are connected and online."},
        -- error msg for no previous connection method
        ["E_NO_PRE"] = {"error", T"Your Internet connection is currently down. You can try the following: <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1. Check that your Telephone or Ethernet cable is firmly connected to the correct port on your Gateway, the Filter on the Telephone<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;socket or the Ethernet socket on the wall.<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2. Check that your username is correct and re-enter your password <a href=/broadband.lp> here </a> .<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;3. Restart my gateway." .. mobiledongle_note},
        -- error msg if PPPoEoDSL was previously connected
        ["E_PPP_DSL"] = {"error", T"Your Internet connection is currently down. You can try the following: <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1. Check that your Telephone cable is firmly connected to the correct port on your Gateway or the Filter on the telephone socket <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;on the wall.<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2. Check that your username is correct and re-enter your password <a href=/broadband.lp> here </a> . <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;3. Restart my gateway." .. mobiledongle_note},
        -- error msg if PPPoEoEWAN was previously connected
        ["E_PPP_ETH"] = {"error", T"Your Internet connection is currently down. You can try the following: <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1. Check that your Ethernet cable is firmly connected to the correct port on your Gateway or the Ethernet socket on the wall.<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2. Check that your username is correct and re-enter your password <a href=/broadband.lp> here </a> . <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;3. Restart my gateway." .. mobiledongle_note},
        -- error msg if IPoEoDSL was previously connected
        ["E_DHCP_DSL"] = {"error", T"Your Internet connection is currently down. You can try the following: <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1. Check that your Telephone cable is firmly connected to the correct port on your Gateway or the Filter on the telephone socket <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;on the wall. <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2. Restart my gateway." .. mobiledongle_note},
        -- error msg if IPoEoEWAN was previously connected
        ["E_DHCP_ETH"] = {"error", T"Your Internet connection is currently down. You can try the following: <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1. Check that your Ethernet cable is firmly connected to the correct port on your Gateway or the Ethernet socket on the wall. <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2. Restart my gateway." .. mobiledongle_note},
    }
    local html = {}

    local content = {
        wanip = "rpc.network.interface.@wan.ipaddr",
        wwanip = "rpc.network.interface.@wwan.ipaddr",
    }
    content_helper.getExactContent(content)

    -- in case wan6 is not configured in uci, protection is needed
    local content_wan6 = {
        ipaddr = "rpc.network.interface.@wan6.ipaddr",
    }
    content_helper.getExactContent(content_wan6)

    local msg_key = "OK"
    if content.wanip:len() == 0 and content_wan6.ipaddr:len() == 0 then
		msg_key = "OK_LTE"
		if content.wwanip:len() == 0 then
			local content_type = {
				proto = "uci.network.interface.@wan.proto",
				l2 = "uci.wansensing.global.l2type",
				l3 = "uci.wansensing.global.l3type",
			}
			content_helper.getExactContent(content_type)

			local L3, L2 = "NO", "PRE"
			if content_type.l2 == "ADSL" or content_type.l2 == "VDSL" then
				L2 = "DSL"
			elseif content_type.l2 == "ETH" then
				L2 = "ETH"
			end

			if content_type.l3 == "L3PPP" or content_type.l3 == "L3Sense" or content_type.proto == "pppoe" then
				L3 = "PPP"
			elseif content_type.l3 == "L3DHCP" or content_type.proto == "dhcp" then
				L3 = "DHCP"
			end

			msg_key = string.format("E_%s_%s", L3, L2)
		end
    end

    local item = items[msg_key]

    html[#html+1] = string.format('<div class="message"><img class="%s" src="/img/telstra/status.png"/>%s</div>', item[1], item[2])
    ngx.print(html)

  ngx.print('\
    </div>\
</div>\
'); 