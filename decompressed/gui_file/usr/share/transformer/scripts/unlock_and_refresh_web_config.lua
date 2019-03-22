#!/usr/bin/lua

--Helper script to adds element to web config file

local uci = require("uci"):cursor()
local new_rule

local _, elem

local function contains(elem, tbl)

	local v
	
	if not tbl then
		return nil
	end
	
	for _, v in ipairs(tbl) do
		if v == elem then
			return true
		end
	end
	
	new_rule = true
	
	return nil
end

local ruleset={}

--Pupulate ruleset table with ruleset from config
uci:foreach('web', 'ruleset', function(s)
	if s['.name'] == 'ruleset_main' then
		for _ , s in pairs(s.rules) do
			ruleset[#ruleset+1] = s
		end
	end
  end)

local check_rule = {
	{ name = 'error', target = '/error.lua' },
	{ name = 'applicationsmodal', target = '/modals/applications-modal.lp' },
	{ name = 'diagnosticsxdslgraphicsmodal', target = '/modals/diagnostics-xdsl-graphics-modal.lp' },
	{ name = 'mwanmodal', target = '/modals/mwan-modal.lp' },
	{ name = 'fastcacheoptionmodal', target = '/modals/fast-cache-option-modal.lp' },
	{ name = 'dosprotectmodal', target = '/modals/dosprotect-modal.lp' },
	{ name = 'mmpbxdectmodal', target = '/modals/mmpbx-dect-modal.lp' },
	{ name = 'modemstatsmodal', target = '/modals/modem-stats-modal.lp' },
	{ name = 'nfcmodal', target = '/modals/nfc-modal.lp' },
	{ name = 'stats', target = '/stats.lp' },
	{ name = 'cards', target = '/cards.lp' },
	{ name = 'ajaxinfotrafficcard', target = '/ajax/traffic_graph.lua' },
	{ name = 'ecomodal', target = '/modals/eco-modal.lp' },
	{ name = 'modguimodal', target = '/modals/modgui-modal.lp' },
	{ name = 'ajaxgatewaytab', target = '/ajax/cpuload.lua' },
	{ name = 'ajaxinternet', target = '/ajax/internet.lua' },
	{ name = 'ajaxinfoconndevicecard', target = '/ajax/connected_device.lua' },
	{ name = 'ajaxinfoportscard', target = '/ajax/port_status.lua' },
	{ name = 'ajaxinfommpbxstatuscard', target = '/ajax/mmpbx_status.lua' },
	{ name = 'ajaxgetcard', target = '/ajax/get_card.lua' },
}

--We add telstra rules anyway as nginx will respond 404 if not found
local telstra_check_rule = {
	{ name = 'telstra_broadband' , target = '/telstra-modals/broadband.lp' },
	{ name = 'telstra_contentsharing_refresh' , target = '/telstra-modals/contentsharing.lp' },
	{ name = 'telstra_device' , target = '/telstra-modals/device.lp' },
	{ name = 'telstra_dyndns' , target = '/telstra-modals/dyndns.lp' },
	{ name = 'telstra_home' , target = '/telstra-gui.lp' },
	{ name = 'telstra_parental' , target = '/telstra-modals/parental-modal.lp' },
	{ name = 'telstra_portforwarding' , target = '/telstra-modals/portforwarding.lp' },
	{ name = 'telstra_remoteaccess' , target = '/telstra-modals/remoteaccess.lp' },
	{ name = 'telstra_tod' , target = '/telstra-modals/tod.lp' },
	{ name = 'telstra_traffic' , target = '/telstra-modals/traffic.lp' },
	{ name = 'telstra_user' , target = '/telstra-modals/user.lp' },
	{ name = 'telstra_wifi' , target = '/telstra-modals/wifi.lp' },
	{ name = 'telstra_wifiguest' , target = '/telstra-modals/wifiguest.lp' },
	{ name = 'telstra_helpbroadband' , target = '/telstra-helpfiles/help_broadband.lp' },
	{ name = 'telstra_helpcontentsharing' , target = '/telstra-helpfiles/help_contentsharing.lp' },
	{ name = 'telstra_helpdyndns' , target = '/telstra-helpfiles/help_dyndns.lp' },
	{ name = 'telstra_helphome' , target = '/telstra-helpfiles/help_home.lp' },
	{ name = 'telstra_helpportforwarding' , target = '/telstra-helpfiles/help_portforwarding.lp' },
	{ name = 'telstra_helpremoteaccess' , target = '/telstra-helpfiles/help_remoteaccess.lp' },
	{ name = 'telstra_helpservices' , target = '/telstra-helpfiles/help_services.lp' },
	{ name = 'telstra_helptod' , target = '/telstra-helpfiles/help_tod.lp' },
	{ name = 'telstra_helptraffic' , target = '/telstra-helpfiles/help_traffic.lp' },
	{ name = 'telstra_helpusersetting' , target = '/telstra-helpfiles/help_usersetting.lp' },
	{ name = 'telstra_helpwifi', target = '/telstra-helpfiles/help_wifi.lp' },
}

--Check every element in table
for _ , elem in pairs(check_rule) do
	if not contains(elem.name, ruleset) then
		uci:set('web', elem.name ,'rule')
		uci:set('web', elem.name , 'target', elem.target)
		uci:set('web', elem.name , 'roles', {'admin','engineer'})
		ruleset[#ruleset+1] = elem.name
	end
end

--Check every element in table
for _ , elem in pairs(telstra_check_rule) do
	if not contains(elem.name, ruleset) then
		uci:set('web', elem.name ,'rule')
		uci:set('web', elem.name , 'target', elem.target)
		uci:set('web', elem.name , 'roles', {'admin','engineer'})
		ruleset[#ruleset+1] = elem.name
	end
end

local cardset = {}

--Pupulate cardset table with card list from config
uci:foreach('web', 'ruleset', function(s)
	cardset[#cardset+1] = s['.name']
  end)
  
local card_check_rule = {
	{ name = 'gateway_card', card = '001_gateway.lp', modal = 'gatewaymodal' },
	{ name = 'modgui_card', card = '001_modgui.lp', modal = 'modguimodal' },
	{ name = 'boradband_card', card = '002_broadband.lp', modal = 'broadbandmodal' },
	{ name = 'internet_card', card = '003_internet.lp', modal = 'internetmodal' },
	{ name = 'wireless_card', card = '004_wireless.lp', modal = 'wirelessmodal' },
	{ name = 'lan_card', card = '005_LAN.lp', modal = 'ethernetmodal' },
	{ name = 'devices_card', card = '006_Devices.lp', modal = 'devicemodal' },
	{ name = 'wanservices_card', card = '007_wanservices.lp', modal = 'wanservices' },
	{ name = 'firewall_card', card = '008_firewall.lp', modal = 'firewallmodal' },
	{ name = 'qos_card', card = '008_qos.lp', modal = 'qosqueuemodal' },
	{ name = 'telephony_card', card = '008_telephony.lp', modal = 'mmpbxglobalmodal' },
	{ name = 'diagnostics_card', card = '009_diagnostics.lp', modal = 'diagnosticspingmodal' },
	{ name = 'extensions_card', card = '009_extensions.lp', modal = 'applicationsmodal' },
	{ name = 'assistance_card', card = '010_assistance.lp', modal = 'assistancemodal' },
	{ name = 'lte_card', card = '010_lte.lp', modal = 'ltemodal' },
	{ name = 'usermgr_card', card = '011_usermgr.lp', modal = 'usermgrmodal' },
	{ name = 'contentsharing_card', card = '012_contentsharing.lp', modal = 'contentsharing' },
	{ name = 'printersharing_card', card = '012_printersharing.lp', modal = 'printersharing' },
	{ name = 'parental_card', card = '013_parental.lp', modal = 'parentalmodal' },
	{ name = 'iproutes_card', card = '015_iproutes.lp', modal = 'iproutesmodal' },
	{ name = 'tod_card', card = '015_tod.lp', modal = 'todmodal' },
	{ name = 'nfc_card', card = '016_nfc.lp', modal = 'nfcmodal' },
	{ name = 'relaysetup_card', card = '018_relaysetup.lp', modal = 'relaymodal' },
	{ name = 'eco_card', card = '020_eco.lp', modal = 'ecomodal' },
	{ name = 'cwmpconf_card', card = '090_cwmpconf.lp', modal = 'cwmpconf' },
	{ name = 'system_card', card = '091_system.lp', modal = 'systemmodal' },
	{ name = 'natalghelper_card', card = '092_natalghelper.lp', modal = 'natalghelper' },
	{ name = 'xdsl_card', card = '093_xdsl.lp', modal = 'xdsllowmodal' },
}

--Check every element in table
for _ , elem in pairs(card_check_rule) do
	if not contains(elem.name, cardset) then
		uci:set('web', elem.name ,'card')
		uci:set('web', elem.name , 'card', elem.card)
		uci:set('web', elem.name , 'modal', elem.modal)
		uci:set('web', elem.name , 'hide', '0')
	end
end

local rule_roles

--Check if rule contains engineer role and adds it
uci:foreach('web', 'rule', function(s)
	rule_roles={}
	if type(s.roles) == "table" then
		for _ , s in pairs(s.roles) do
			rule_roles[#rule_roles+1]=s
		end
	elseif type(s.roles) == "string" then
		rule_roles[#rule_roles+1]=s.roles
	end
	if not contains("engineer",rule_roles) then
		rule_roles[#rule_roles+1]="engineer"
	end
	if not contains("admin",rule_roles) then
		rule_roles[#rule_roles+1]="admin"
	end
	uci:set('web',s['.name'],'roles',rule_roles)
  end)

uci:set('web','usr_admin','role','engineer')

--Commit only if new rules added
if new_rule then
	uci:set('web','ruleset_main','rules',ruleset)
	uci:commit('web')
end