--pretranslated: do not change this file
 
---
--- ENABLE LOCALIZATION
---
gettext.textdomain('webui-core')

---
--- REQUIRED LIBRARIES
---
--- content_helper: extracts information from the data model / uci layer
--- ui_helper:      controls creation of web ui widgets (switches, text entry, radio buttons, etc)
--- post_helper:    controls behavior of POST messages sent from web ui to Transformer
--- proxy:          used for access to the data model / uci layer (get and set methods)
--- message_helper: produces human readable content in the web ui (e.g. errors, success prompts)
---
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")

local ajax_attr = {
    span = {
      ["data-ajaxrefresh"] = "5",
    }
}

local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.",firewall_zone)
local zonenum = ""
local match, format = string.match, string.format

local function split(str, ang)
	local tab = {}
	for vari in string.gfind(format("%s",str), ang) do
		table.insert(tab, vari)
	end
	return tab
end 

local function dns_filter(tab)
	local ipv4_dns = ""
	local ipv6_dns = ""
	
	for _,v in ipairs(tab) do
		if match(v, "^(%d+)%.(%d+)%.(%d+)%.(%d+)$") then
			ipv4_dns=ipv4_dns..format("%s,", v)
		else
			ipv6_dns=ipv6_dns..format("%s,", v)
		end
	end
	
	if #ipv4_dns > 1 then
		ipv4_dns = string.sub(ipv4_dns,1,#ipv4_dns-1)
	end
	if #ipv6_dns > 1 then
		ipv6_dns = string.sub(ipv6_dns,1,#ipv6_dns-1)
	end
	return ipv4_dns, ipv6_dns
end

for _, v in ipairs(firewall_zone_path) do
  if (v["name"] == "wan") then
    zonenum = v["paramindex"]
    break
  end
end
local firewall_forwarding = proxy.get("uci.firewall.forwarding.")
local firewall_forwarding_path = content_helper.convertResultToObject("uci.firewall.forwarding.",firewall_forwarding)
local forwdnum = ""
for _, v in ipairs(firewall_forwarding_path) do
  if (v["src"] == "wan" and v["dest"] == "lan") then
    forwdnum = v["paramindex"]
    break
  end
end
local firewall_value = {["uci.firewall.forwarding."..forwdnum..".src"] = "wan",
                        ["uci.firewall.forwarding."..forwdnum..".dest"] = "lan",
                        ["uci.firewall.forwarding."..forwdnum..".name"] = "for_w2l"}
local function validateNat(value, object, key)
  local valid, msg = post_helper.validateBoolean(value, object, key)
  if valid and zonenum ~= "" and value ~= proxy.get("uci.firewall.zone."..zonenum..".masq")[1].value then
    proxy.set("uci.firewall.zone."..zonenum..".conntrack", "1")
    if value == "1" then
      if forwdnum == "" then
        forwdnum = proxy.add("uci.firewall.forwarding.")
        proxy.set(firewall_value)
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "0")
      else
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "0")
      end
    else
      if forwdnum == "" then
        forwdnum = proxy.add("uci.firewall.forwarding.")
        proxy.set(firewall_value)
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "1")
      else
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "1")
      end
    end
    proxy.apply()
  end
  return valid, msg
end

---
--- SETUP FOR PRINTING DATA
---

---
--- SHORTCUTS FOR DATA PATHS
---
local wanIpAddrPath_uci   = "uci.network.interface.@wan.ipaddr"
local wanNetmaskPath_uci  = "uci.network.interface.@wan.netmask"
local wanGatewayPath_uci  = "uci.network.interface.@wan.gateway"

---
--- CONFIGURABLE DATA FROM MAP FILE (network.map)
---
local mapParams = {
    wanIpAddrParam    = wanIpAddrPath_uci,
    wanNetmaskParam   = wanNetmaskPath_uci,
    wanGatewayParam   = wanGatewayPath_uci,
    uci_wan_masq      = "uci.firewall.zone."..zonenum..".masq",
}

---
--- FIELD VALUE INTEGRITY FUNCTIONS
---
local mapValid = {
    wanIpAddrParam    = post_helper.advancedIPValidation,
    wanNetmaskParam   = post_helper.validateIPv4Netmask,
    wanGatewayParam   = post_helper.advancedIPValidation,
    uci_wan_masq      = validateNat,
}

--- GRAB CURRENT DATA AND HELP MESSAGES FROM POST HANDLER
--- FOR DNS CONFIGURATION, EITHER GET CURRENT VALUE OR LEAVE BLANK BASED ON FINDINGS
--- HELP MESSAGES APPEAR NEXT TO CONTROLS (EXAMPLE INVALID VALUE ERRORS FOR TEXT FIELDS)
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

---
--- DNS CONFIGURATION TABLE ITEMS
---
local content_dns = {
						wandns = "rpc.network.interface.@wan.dnsservers";
						loopbackdns = "rpc.network.interface.@loopback.dnsservers";
						}
						
ajax_helper.handleAjaxQuery(content_dns, function(c)
    -- this will add the HTML for the light
	local dnstab = split(c.loopbackdns, "[^%,]+")
	local dnsv4, dnsv6 = dns_filter(dnstab)
	c.loopbackdns = content_helper.getMergedList(proxy.get("rpc.network.interface.@wan.dnsservers")[1].value, dnsv4)
end)

content_helper.getExactContent(content_dns)


local dnstab = split(content_dns.loopbackdns, "[^%,]+")
local dnsv4, dnsv6 = dns_filter(dnstab)
content_dns.loopbackdns = content_helper.getMergedList(content_dns.wandns, dnsv4)

local ipv4pattern = "^(((([1]?\\d)?\\d|2[0-4]\\d|25[0-5])\\.){3}(([1]?\\d)?\\d|2[0-4]\\d|25[0-5]))$"
local dnsColumns = {
    {
       header = T"DNS IP Address",
       name   = "wanDnsParam",                          -- MAP THIS PARAMETER AGAINST dnsValid TABLE
       param  = "value",                                -- APPENDED TO basepath OF dnsOptions TABLE
       type   = "text",
       attr   = { input = { class="span2", maxlength="15", pattern = ipv4pattern } },
    },
}

local dnsOptions = {
    tableid    = "dnsserver",
    basepath   = "uci.network.interface.@wan.dns.@.",
    createMsg  = T"Add New DNS",
    minEntries = 1,
    maxEntries = 4,                                     -- ADJUST LIMIT AS SEEN FIT
    sorted = function(a, b)
        return tonumber(a.paramindex) < tonumber(b.paramindex)
    end
}

local dnsValid = {
    wanDnsParam =  post_helper.advancedIPValidation,
}

local dnsData, dnsHelpMsg = post_helper.handleTableQuery(dnsColumns, dnsOptions, nil, nil, dnsValid)

---
--- TRIGGERED DURING POST OPERATION ON IP ADDRESS
---    1) GRABS POST ACTION AND ARGUMENTS FROM POST
---    2) CLEARS OUT MESSAGES FROM THE MESSAGE_HELPER QUEUE (THROUGH 'popMessages' CALL)
---    3) AFTER CHECKING WHICH PARAMETER IS GETTING UPDATED, VERIFIES FIELD VALUE
---    4) IF FIELD VALIDATION PASSES, TELL TRANSFORMER (THROUGH PROXY) TO PHYSICALLY UPDATE VALUE
---    5) UNDERLYING HARDWARE SHOULD GET CONFIGURED AUTOMATICALLY
if ngx.req.get_method() == "POST" then
    local postContent = ngx.req.get_post_args()
    local actionVal   = postContent["action"]
    
    local ipVal       = postContent["wanIpAddrParam"]
    local netmaskVal  = postContent["wanNetmaskParam"]
    local gatewayVal  = postContent["wanGatewayParam"]    
	
    if actionVal == "wanIpAddrParam" then
        content["wanIpAddrParam"] = ipVal
        proxy.set(wanIpAddrPath_uci,ipVal)
        proxy.apply()
    end
    if actionVal == "wanNetmaskParam" then
        content["wanNetmaskParam"] = netmaskVal
        proxy.set(wanNetmaskPath_uci,netmaskVal)
        proxy.apply()
    end
    if actionVal == "wanGatewayParam" then
        content["wanGatewayParam"] = gatewayVal
        proxy.set(wanGatewayPath_uci,gatewayVal)
        proxy.apply()
    end
end
    
  ngx.print('\
');  
--- THIS SECTION SETS UP COSMETICS FOR THE SUB-MENU (MODAL)
--- EACH CONTROL HAS THE OPTION OF SETTING ATTRIBUTES (WRAPPED INTO A "CLASS" CONTAINER) 
--- IN THIS CASE, INPUT TEXT FIELDS ARE RESPONSIBLE FOR GATHERING INFORMATION ABOUT THE WAN INTERFACE
  ngx.print('\
');  
-- CLEAR ALL MESSAGES FROM THE QUEUE
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
    <legend>');  ngx.print( T"Static Connection" ); ngx.print('</legend>\
    ');  
        local html = {}

        local wanIPClass = {}
        wanIPClass["input"] = {
            ["data-for"] = "wanIpAddrParam",
            ["pattern"] = ipv4pattern
        }

        local wanNetmaskClass = {}
        wanNetmaskClass["input"] = {
            ["data-for"] = "wanNetmaskParam",
            ["pattern"] = ipv4pattern
        }

        local wanGatewayClass = {}
        wanGatewayClass["input"] = {
            ["data-for"] = "wanGatewayParam",
            ["pattern"] = ipv4pattern
        }

        -- UI CONTROLS LIST
        -- ARGUMENT 2 MUST MUST MATCH PARAMETER NAME FROM mapParams OR ERRORS WILL OCCUR DURING INTERFACE UPDATES
        html[#html + 1] = ui_helper.createSwitch(T"NAT", "uci_wan_masq", content.uci_wan_masq)
        html[#html+1] = ui_helper.createInputText(T"IP Address", "wanIpAddrParam", content["wanIpAddrParam"], wanIPClass, helpmsg["wanIpAddrParam"])
        html[#html+1] = ui_helper.createInputText(T"Subnet Mask", "wanNetmaskParam", content["wanNetmaskParam"], wanNetmaskClass, helpmsg["wanNetmaskParam"])
        html[#html+1] = ui_helper.createInputText(T"Gateway", "wanGatewayParam", content["wanGatewayParam"], wanGatewayClass, helpmsg["wanGatewayParam"])
        if dns_loopback ~= "" then
			ajax_attr.span.id = "loopbackdns"
            html[#html+1] = ui_helper.createLabel(T"DNS Servers", content_dns.loopbackdns,ajax_attr)
        end

        ngx.print(html)
      ngx.print('\
</fieldset>\
');  
--- IN THIS SECTION, TABLE OF DNS SERVERS IS CREATED.  
--- HARD LIMITS ARE SET THROUGH "minEntries" AND "maxEntries" FIELDS OF THE "dnsOptions" TABLE
  ngx.print('\
<fieldset>\
    <legend>');  ngx.print( T"Domain Name Server Configuration"  ); ngx.print('</legend>\
    ');  
        local html2 = {}
        
        -- UI CONTROLS LIST
        html2[#html2+1] = ui_helper.createTable(dnsColumns, dnsData, dnsOptions, nil, dnsHelpMsg)        
        
        ngx.print(html2)
      ngx.print('\
</fieldset>    \
    \
'); 