-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local json = require("dkjson")
local post_helper = require("web.post_helper")
local ngx = ngx

if ngx.req.get_method() == "POST" then
	datatype = ngx.req.get_uri_args().datatype
end

local data= {}

if datatype and datatype== "xdsl" then
	local sub, format, floor = string.sub, string.format, math.floor
	
	data = {
		status = "sys.class.xdsl.@line0.LinkStatus",
		max_upstream = "Device.DSL.Line.1.UpstreamMaxBitRate",
		max_downstream = "Device.DSL.Line.1.DownstreamMaxBitRate",
		dsl_linerate_up = "sys.class.xdsl.@line0.UpstreamCurrRate",
		dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
		dsl_margin_up = "sys.class.xdsl.@line0.UpstreamNoiseMargin",
		dsl_margin_down = "sys.class.xdsl.@line0.DownstreamNoiseMargin",
		dsl_attenuation_up = "sys.class.xdsl.@line0.UpstreamAttenuation",
		dsl_attenuation_down = "sys.class.xdsl.@line0.DownstreamAttenuation",
		dsl_power_up = "sys.class.xdsl.@line0.UpstreamPower",
		dsl_power_down = "sys.class.xdsl.@line0.DownstreamPower",
		dsl_type = "sys.class.xdsl.@line0.ModulationType",
		dsl_margin_SNRM_up = "sys.class.xdsl.@line0.UpstreamSNRMpb",
		dsl_margin_SNRM_down = "sys.class.xdsl.@line0.DownstreamSNRMpb",
		dslam_chipset = "rpc.xdslctl.DslamChipset",
		dslam_version = "rpc.xdslctl.DslamVersion",
		dsl_profile = "rpc.xdslctl.DslProfile",
		dsl_port = "rpc.xdslctl.DslamPort"
	}
	
	content = {
		dslam_version_raw = "rpc.xdslctl.DslamVersionRaw"
	}
	
	content_helper.getExactContent(content)
	
	content_helper.getExactContent(data)
	
	if not ( data.dsl_linerate_down == "0" ) then
		data.dsl_linerate_up = floor(tonumber(data.dsl_linerate_up) / 10) / 100 .. " Mbps"
		data.dsl_linerate_down = floor(tonumber(data.dsl_linerate_down) / 10) / 100 .. " Mbps"
		data.max_upstream = floor(tonumber(data.max_upstream) / 10) / 100 .. " Mbps"
		data.max_downstream = floor(tonumber(data.max_downstream) / 10) / 100 .. " Mbps"
		
		if not ( data.dsl_type:match("ADSL") ) then
			data.dsl_margin_down = data.dsl_margin_SNRM_down
			data.dsl_margin_up = data.dsl_margin_SNRM_up
		end
		
		if data.dslam_chipset:match("BDCM") then
			data.dslam_chipset = "Broadcom" .. " ( " .. data.dslam_chipset .. " )"
		elseif data.dslam_chipset:match("IFTN") then
			data.dslam_chipset = "Infineon" .. " ( " .. data.dslam_chipset .. " )"
		end
		
		if not ( content.dslam_version_raw:sub(0,2) == "0x" ) then
			if content.dslam_version_raw == "" then
				data.dslam_chipset = T"Can't recover dslam version."
			else
				data.dslam_chipset = format(T"Invalid version, can't convert. Raw value: %s", content.dslam_version_raw)
			end
		end
		
		if data.status == "Showtime" then
			data.status = T"Connected"
		elseif data.status == "" then
			data.status = T"Disconnected"
		else
			data.status = T(data.status)
		end
	else
		for index in pairs(data) do
			if not ( index == "status" ) then
				data[index] = "N/A"
			end
		end
	end
else
	local ppp_status, ppp_light_map, ppp_state_map
	
	local table = table
	local format = string.format
	local content_uci = {
	wan_proto = "uci.network.interface.@wan.proto",
	wan_auto = "uci.network.interface.@wan.auto",
	wan_ipv6 = "uci.network.interface.@wan.ipv6",
	wan_mode = "uci.network.config.wan_mode",
	}
	content_helper.getExactContent(content_uci)
	
	local content_rpc = {
	wan_ppp_state = "rpc.network.interface.@wan.ppp.state",
	wan_ppp_error = "rpc.network.interface.@wan.ppp.error",
	ipaddr = "rpc.network.interface.@wan.ipaddr",
	pppoe_uptime = "rpc.network.interface.@wan.uptime",
	up = "rpc.network.interface.@wan.up",
	ipaddr = "rpc.network.interface.@wan.ipaddr",
	nexthop = "rpc.network.interface.@wan.nexthop",
	dns_wan = "rpc.network.interface.@wan.dnsservers",
	}
	
	local interface = proxy.getPN("rpc.network.interface.", true)
	
	if interface then
		for i,v in ipairs(interface) do
			local intf = string.match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
			if intf then
				if intf == "6rd" then
				content_rpc.ip6addr = "rpc.network.interface.@6rd.ip6addr"
				content_rpc.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
				elseif intf == "wan6" then
				content_rpc.ip6addr = "rpc.network.interface.@wan6.ip6addr"
				content_rpc.ip6prefix = "rpc.network.interface.@wan6.ip6prefix"
				end
			end
		end
	end
	
	content_helper.getExactContent(content_rpc)
	
	if content_rpc.dns_wan:match(",") then
		content_rpc.dns_wan = content_rpc.dns_wan:gsub(","," , ")
	end
	
	if content_rpc.up == "1" then
		content_rpc.up = T"Connected"
	else
		content_rpc.up = T"Disconnected"
	end
	
	local IPv6State = "none"
	
	if content_uci.wan_ipv6 ~= "1" then
		IPv6State = "disabled"
	elseif content_rpc.ip6prefix ~= "" then
		IPv6State = "prefix"
	elseif content_rpc.ip6prefix == "" then
		IPv6State = "noprefix"
	end
	
	local untaint_mt = require("web.taint").untaint_mt
	local ipv6_state_map = {
		none = T"IPv6 Disabled",
		noprefix = T"IPv6 Connecting",
		prefix = T"IPv6 Connected",
	}
	
	setmetatable(ipv6_state_map, untaint_mt)
	
	local ipv6_light_map = {
		none = "off",
		noprefix = "orange",
		prefix = "green",
	}
	setmetatable(ipv6_light_map, untaint_mt)
	
	local status_light
	local attributes = { light = { } ,span = { class = "span4" } }
	
	if content_uci.wan_mode == "pppoe" then
		local ppp_state_map = {
			disabled = T"PPP disabled",
			disconnecting = T"PPP disconnecting",
			connected = T"PPP connected",
			connecting = T"PPP connecting",
			disconnected = T"PPP disconnected",
			error = T"PPP error",
			AUTH_TOPEER_FAILED = T"PPP authentication failed",
			NEGOTIATION_FAILED = T"PPP negotiation failed",
		}
		
		local untaint_mt = require("web.taint").untaint_mt
		setmetatable(ppp_state_map, untaint_mt)
		
		local ppp_light_map = {
			disabled = "0",--"off"
			disconnected = "4",--"red"
			disconnecting = "2",--"orange"
			connecting = "2",--"orange"
			connected = "1",--"green"
			error = "4",--"red"
			AUTH_TOPEER_FAILED = "4",--"red"
			NEGOTIATION_FAILED = "4",--"red"
		}
		
		setmetatable(ppp_light_map, untaint_mt)
		
		local ppp_status
		if content_uci.wan_auto ~= "0" then
		-- WAN enabled
		content_uci.wan_auto = "1"
		ppp_status = format("%s", content_rpc.wan_ppp_state) -- untaint
		if ppp_status == "" or ppp_status == "authenticating" then
			ppp_status = "connecting"
		elseif not ppp_state_map[ppp_status] then
			ppp_status = "error"
		end
		
		if not (content_rpc.wan_ppp_error == "" or content_rpc.wan_ppp_error == "USER_REQUEST") then
			if ppp_state_map[content_rpc.wan_ppp_error] then
				ppp_status = content_rpc.wan_ppp_error
			else
				ppp_status = "error"
			end
		end
		else
		-- WAN disabled
		ppp_status = "disabled"
		end
		
		local ppp_light, ppp_state, WAN_IP, ipv6_light, ipv6_state
		if ppp_status then
			ppp_light = ppp_light_map[ppp_status]
			ppp_state = ppp_state_map[ppp_status]
			if content_rpc["ipaddr"] and content_rpc["ipaddr"]:len() > 0 then
				WAN_IP = content_rpc["ipaddr"]
			elseif content_rpc["ip6addr"] and content_rpc["ip6addr"]:len() > 0 then
				WAN_IP = content_rpc["ip6addr"]
			end
			if ppp_status == "connected" and IPv6State ~= "disabled" then
				ipv6_light = ipv6_light_map[IPv6State]
				ipv6_state = ipv6_state_map[IPv6State]
			end
		end
		
		status_light = ui_helper.createSimpleLight(ppp_light_map[ppp_status], ppp_state_map[ppp_status] , attributes , "fa-at")
	elseif content_uci.wan_mode == "static" then

		-- Figure out interface state
		local static_state = "disabled"
		local static_state_map = {
			disabled = T"Static disabled",
			connected = T"Static on",
		}
		
		local static_light_map = {
		disabled = "0",--"off",
		connected = "1",--"green",
		}
		
		if content_uci.wan_auto ~= "0" and content_rpc["ipaddr"]:len() > 0 then
			static_state = "connected"
		end
		
		status_light = ui_helper.createSimpleLight(static_light_map[static_state], static_state_map[static_state] , attributes , "fa-at")
	end
	
	
	data = {
	status_light = status_light or "",
	WAN_IP_text = not ( content_rpc["ipaddr"] == "" ) and format(T'WAN IP is <strong>%s</strong>'..'<br/>', content_rpc["ipaddr"]) or "",
	uptime_text = not ( content_rpc["pppoe_uptime"] == "" ) and format(T"Uptime" .. ": <strong>%s</strong>",post_helper.secondsToTimeShort(content_rpc["pppoe_uptime"])) or "",
	pppoe_uptime = post_helper.secondsToTimeShort(content_rpc["pppoe_uptime"]) or "",
	pppoe_uptime_extended = post_helper.secondsToTime(content_rpc["pppoe_uptime"]) or "",
	ppp_status = ppp_status or "",
	ppp_light = ppp_light or "" ,
	ppp_state = ppp_state or "",
	WAN_IP = content_rpc["ipaddr"] or "",
	ipv6_light = ipv6_light or "",
	ipv6_state = ipv6_state or "",
	status = content_rpc["up"],
	wangateway = content_rpc["nexthop"],
	wandns = content_rpc["dns_wan"]
	}
end
	

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
 ngx.say(buffer)
else
 ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)
