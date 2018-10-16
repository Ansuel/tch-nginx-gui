--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")

-- Process POST query
local post_helper = require("web.post_helper")

local mapParams = {
    uci_wan_username = "uci.network.interface.@ppp.username",
    uci_wan_password = "uci.network.interface.@ppp.password",
}

-- Shortcuts to validation helpers to make lines shorter
local vNES = post_helper.validateNonEmptyString
local gVP = post_helper.getValidationPassword

local mapValid = {
    uci_wan_username = vNES,
    uci_wan_password = gVP(vNES),
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process

local string = string

local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_domain = "uci.network.interface.@ppp.domain",
  wan_auto = "uci.network.interface.@wan.auto",
}
content_helper.getExactContent(content_uci)

local content_rpc = {
    wan_ppp_state = "rpc.network.interface.@ppp.ppp.state",
    wan_ppp_error = "rpc.network.interface.@ppp.ppp.error",
    wan_ppp_ll_intf = "rpc.network.interface.@ppp.ppp.ll_intf",
    ipaddr = "rpc.network.interface.@ppp.ipaddr",
    nexthop = "rpc.network.interface.@ppp.nexthop",
    ip6addr = "rpc.network.interface.@wan6ppp.ip6addr",
    dns = "rpc.network.interface.@ppp.dnsservers",
}
content_helper.getExactContent(content_rpc)

local wan_ppp_over_atm = string.find(content_rpc["wan_ppp_ll_intf"], "atm_") == 1
local content_uci_xtm
if wan_ppp_over_atm then
  -- need to untaint the string otherwise getExactContent will get lost
  local wan_atm_uci_path = string.format("uci.xtm.atmdevice.@%s.", content_rpc["wan_ppp_ll_intf"])
  content_uci_xtm = {
    wan_atm_vpi = wan_atm_uci_path.."vpi",
    wan_atm_vci = wan_atm_uci_path.."vci",
    wan_atm_enc = wan_atm_uci_path.."enc",
  }
  content_helper.getExactContent(content_uci_xtm)
end

if content_uci["wan_domain"] ~= "" then
  content["uci_wan_username"] = string.match(content["uci_wan_username"], "[^@]*")
end

local ppp_state_map = {
    disabled = T"disabled",
    disconnecting = T"disconnecting",
    connected = T"connected",
    connecting = T"connecting",
    disconnected = T"disconnected",
    error = T"error",
    AUTH_TOPEER_FAILED = T"authentication failed",
    NEGOTIATION_FAILED = T"negotiation failed",
}
local ppp_light_map = {
    disabled = "off",
    disconnected = "red",
    disconnecting = "orange",
    connecting = "orange",
    connected = "green",
    error = "red",
    AUTH_TOPEER_FAILED = "red",
    NEGOTIATION_FAILED = "red",
}


local ppp_status
if content_uci.wan_auto ~= "0" then
  -- WAN enabled
  content_uci.wan_auto = "1"
  ppp_status = string.format("%s", content_rpc.wan_ppp_state) -- untaint
  if ppp_status == "" then
    ppp_status = "connecting"
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

  ngx.print('\
\
<fieldset>\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"PPP connection" ); ngx.print('</legend>\
\
');  
    local html = {}
    -- Label that shows PPP status
    --html[#html + 1] = ui_helper.createLight(T"Status", nil, ppp_state_map[ppp_status], { light = { class = ppp_light_map[ppp_status] } })
    -- Switch PPP on/off
    --html[#html + 1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content.uci_wan_auto)
   
    -- PPP username
    local class_username = {
      input = {
        maxlength= "128",
        class = "span6",
      }
    }
    html[#html + 1] = "<div class='control-group'><label class='control-label'>" .. T"Username" .. "</label><div class='controls'>"
    html[#html + 1] = ui_helper.createSimpleInputText("uci_wan_username", content["uci_wan_username"], class_username, helpmsg["uci_wan_username"])
    if content_uci["wan_domain"] ~= "" then
      html[#html + 1] = " @ " .. content_uci["wan_domain"]
    end
    html[#html + 1] = "</div></div>"

    -- PPP password
    local class_password = class_username
    html[#html + 1] = ui_helper.createInputPassword(T"Password", "uci_wan_password", content["uci_wan_password"], class_username, helpmsg["uci_wan_password"])

    --html[#html+1] = ui_helper.createLabel(T"IP address", content_rpc["ipaddr"])
    --html[#html+1] = ui_helper.createLabel(T"IPv6 address", content_rpc["ip6addr"])
    --html[#html+1] = ui_helper.createLabel(T"Gateway", content_rpc["nexthop"])
    --html[#html+1] = ui_helper.createLabel(T"DNS servers", content_rpc["dns"])


    -- ATM VP/VC
    if wan_ppp_over_atm then
      local advanced = {
        group = {
          class = "advanced hide",
        }
      }
      local vp_vc = string.format("%s / %s", content_uci_xtm["wan_atm_vpi"], content_uci_xtm["wan_atm_vci"])
--      html[#html + 1] = ui_helper.createLabel(T"ATM VP / VC", vp_vc, advanced)
--      html[#html + 1] = ui_helper.createLabel(T"Encapsulation", string.upper(content_uci_xtm["wan_atm_enc"]), advanced)
    end

    ngx.print(html)
  ngx.print('\
\
</fieldset>\
'); 