--pretranslated: do not change this file
 
--[[
Version 1.0 DHCP Relay Setup Page

  - Allow direct configuration of DHCP Relay

]]
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local valEnumSel = post_helper.getValidateInEnumSelect
local format, match = string.format, string.match

local function resetreboot(path,value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" then
  local setIPValues = {}
  if ngx.req.get_post_args().uci_relay_status == "0" then
    setIPValues["uci.dhcp.relay.@relay.server_addr"] = ""
    setIPValues["uci.dhcp.relay.@relay.local_addr"] = ""
    setIPValues["uci.dhcp.relay.@relay.interface"] = ""
    proxy.del("uci.dhcp.relaybackup.")
    proxy.add("uci.dhcp.relaybackup.", post_helper.getRandomKey())
    proxy.set(setIPValues)
  else
    proxy.del("uci.dhcp.relaybackup.")
  end
  proxy.apply()
  local action = ngx.req.get_post_args().action
  -- now process non-file POSTs
  if action == "system_reset" then
    return resetreboot("rpc.system.reset", "1")
  elseif action == "system_reboot" then
    return resetreboot("rpc.system.reboot", "GUI")
  end
end

local uci_relay_status = "0"

local relay_Params = {
    uci_relay_server_ip = "uci.dhcp.relay.@relay.server_addr",
    uci_relay_local_ip  = "uci.dhcp.relay.@relay.local_addr",
    uci_relay_interface = "uci.dhcp.relay.@relay.interface",
    uci_pppoerelay_enable = "uci.pppoerelayd.config.enable",
    uci_pppoerelay_server_intf = "uci.pppoerelayd.config.server_intf",
    uci_pppoerelay_client_intf = "uci.pppoerelayd.config.client_intf",
    uci_pppoerelay_nsessions = "uci.pppoerelayd.config.nsessions"
}

local vSII = post_helper.validateStringIsIP
local aIPV = post_helper.advancedIPValidation
local pIPV = post_helper.isPublicIP
local gAV = post_helper.getAndValidation

--the [value] a valid IPv4 address
--the [value] is not the GW IP address
--the [value] is not the GW WAN IP address
--@return nil+error message
local function validateRelay(value, object, key)
  if vSII(value) then
    local ipaddr = proxy.get("rpc.network.interface.@lan.ipaddr")[1].value
    local wan_ipaddr = proxy.get("rpc.network.interface.@wan.ipaddr")[1].value
    if ipaddr == value then
       return nil, T"Cannot use the gateway IP address."
    end
    if wan_ipaddr == value then
       return nil, T"Cannot use the gateway WAN IP address."
    end
    --Adding localdevicemask in post to find the input is a network or broadcast IPv4 address in advancedIPValidation
    object["localdevmask"] = proxy.get("uci.network.interface.@lan.netmask")[1].value
    return true
  end
end

-- Description Function to get the list of wan interface Paths
-- @function getWanInterfacePath
-- @return table
local function getWanInterfacePath()
  local interfaceList = proxy.getPN("rpc.network.interface.", true)
  local wanIntfPaths = {}
  if interfaceList then
    for _,intf in ipairs(interfaceList) do
      local values = proxy.get(intf.path .. "type")
      if values ~= "" and values[1].value == "wan" then
        wanIntfPaths[#wanIntfPaths + 1] = values[1].path
      end
    end
  end
  return wanIntfPaths
end

local function getInterfacePath()
  local interfaceList = proxy.getPN("rpc.network.interface.", true)
  local wanIntfPaths = {}
  if interfaceList then
    for _,intf in ipairs(interfaceList) do
      local values = proxy.get(intf.path .. "type")
      wanIntfPaths[#wanIntfPaths + 1] = values[1].path
    end
  end
  return wanIntfPaths
end

local wanIntfPaths = getWanInterfacePath()
local allIntfPaths = getInterfacePath()
local wanData = content_helper.convertResultToObject("rpc.network.interface.", proxy.get(unpack(wanIntfPaths)))
local allData = content_helper.convertResultToObject("rpc.network.interface.", proxy.get(unpack(allIntfPaths)))

local wanConInfo = {}
for _, data in ipairs(wanData) do
  if data.type == "wan" then
    wanConInfo[#wanConInfo + 1] = {}
    wanConInfo[#wanConInfo].interface = match(data.paramindex, "([%w%_]+)")
  end
end

local WanDetails = {}
for _, data in ipairs(wanConInfo) do
  if data.interface ~= "wan6" then
    WanDetails[#WanDetails + 1] = {
      data and data.interface,
      data and data.interface,
    }
  end
end

local allConInfo = {}
for _, data in ipairs(allData) do
    allConInfo[#allConInfo + 1] = {}
    allConInfo[#allConInfo].interface = match(data.paramindex, "([%w%_]+)")
end

local AllDetails = {}
for _, data in ipairs(allConInfo) do
	AllDetails[#AllDetails + 1] = {
	  data and data.interface,
	  data and data.interface,
	}
end

local relay_valid = {
  uci_relay_server_ip = gAV(validateRelay, aIPV),
  uci_relay_local_ip  = gAV(validateRelay, pIPV),
  uci_relay_interface = valEnumSel(WanDetails),
  uci_pppoerelay_enable = post_helper.validateBoolean,
  uci_pppoerelay_client_intf = valEnumSel(AllDetails),
  uci_pppoerelay_server_intf = valEnumSel(AllDetails),
  uci_pppoerelay_nsessions = post_helper.validatePositiveNum

}

local function getRelayBackUpValues()
  local getBackUpValues = content_helper.convertResultToObject("uci.dhcp.relaybackup.", proxy.get("uci.dhcp.relaybackup."))
  if getBackUpValues and next(getBackUpValues) then
    for _, v in pairs(getBackUpValues) do
      relay_Params["uci_relay_server_ip"] = format("uci.dhcp.relaybackup.%s.server_addr", v.paramindex)
      relay_Params["uci_relay_local_ip"]  = format("uci.dhcp.relaybackup.%s.local_addr", v.paramindex)
      relay_Params["uci_relay_interface"] = format("uci.dhcp.relaybackup.%s.interface", v.paramindex)
    end
  end
end

if (ngx.req.get_method() == "POST" and  ngx.req.get_post_args().uci_relay_status == "0") then
  getRelayBackUpValues()
end

server_addr = proxy.get("uci.dhcp.relay.@relay.server_addr")

if not server_addr or ( server_addr[1].value == "" and proxy.get("uci.dhcp.relay.@relay.local_addr")[1].value == "" )  then
  getRelayBackUpValues()
end

local relay_Values, helpmsg = post_helper.handleQuery(relay_Params, relay_valid)
if server_addr and server_addr[1].value ~= "" and proxy.get("uci.dhcp.relay.@relay.local_addr")[1].value ~= "" then
  uci_relay_status = "1"
end
local title = T"Relay Setup"
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(title, false, false))   ngx.print('\
<div class="modal-body update">\
');
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/relay-modal.lp">\
<fieldset>\
  <legend>');  ngx.print( T"DHCP Relay" ); ngx.print('</legend>\
       ');
         local html = {}
         html[#html + 1] = ui_helper.createSwitch(T"Status", "uci_relay_status", uci_relay_status)
         html[#html + 1] = ui_helper.createInputText(T"Server IP", "uci_relay_server_ip", relay_Values["uci_relay_server_ip"], nil, helpmsg["uci_relay_server_ip"])
         html[#html + 1] = ui_helper.createInputText(T"Local IP", "uci_relay_local_ip", relay_Values["uci_relay_local_ip"], nil, helpmsg["uci_relay_local_ip"])
         html[#html + 1] = ui_helper.createInputSelect(T"Interface", "uci_relay_interface", WanDetails, relay_Values["uci_relay_interface"])
         ngx.print(html)
         ngx.print('\
\
</fieldset>\
<fieldset>\
  <legend>');  ngx.print( T"PPPoE Relay" ); ngx.print('</legend>\
       ');
        local html = {}
        html[#html + 1] = ui_helper.createSwitch(T"Status", "uci_pppoerelay_enable", relay_Values["uci_pppoerelay_enable"])
        html[#html + 1] = ui_helper.createInputSelect(T"Client Interface", "uci_pppoerelay_client_intf", AllDetails, relay_Values["uci_pppoerelay_client_intf"])
        html[#html + 1] = ui_helper.createInputSelect(T"Server Interface", "uci_pppoerelay_server_intf", AllDetails, relay_Values["uci_pppoerelay_server_intf"])
		html[#html + 1] = ui_helper.createInputText(T"Sessions", "uci_pppoerelay_nsessions", relay_Values["uci_pppoerelay_nsessions"], nil, helpmsg["uci_pppoerelay_nsessions"])
        ngx.print(html)

         ngx.print('\
\
</fieldset>\
\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
');