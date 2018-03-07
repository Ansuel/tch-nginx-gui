<%
-- Enable localization
gettext.textdomain('webui-wizard')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local wizard_helper = require("wizard")
local session = ngx.ctx.session
local vNES = post_helper.validateNonEmptyString
local vN = post_helper.validatePositiveNum
local gVIES = post_helper.getValidateInEnumSelect
local vSIP = post_helper.validateStringIsIP
local vIPv4MSK = post_helper.validateIPv4Netmask
local gmatch, format, lower = string.gmatch, string.format, string.lower
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable

local wan_interface_options = {
    {"adsl", T"ADSL"},
    {"vdsl", T"VDSL"},
    {"eth",  T"Ethernet"},
}

local wan_proto_options = {
    {"pppoe",  T"PPP over Ethernet"},
    {"pppoa",  T"PPP over ATM"},
    {"dhcp",   T"Dynamic IP Address"},
    {"static", T"Static IP Address"},
}

local ifname2wantype = setmetatable({
    ["atmwan"] = "adsl",
    ["wanptm0"] = "vdsl",
    ["waneth4"] = "eth",
}, untaint_mt)

local wan_atm_uci_path = "uci.xtm.atmdevice.@atmwan."
local wan_atm_uci_ipoe_path = "uci.xtm.atmdevice.@atmwan."
local wan_interface_path = "uci.network.interface.@wan."
local static_dns_path = "rpc.network.interface.@wan.static_dns_servers"

local mapParams = {
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    wan_ifname = wan_interface_path .. "ifname",
    wan_proto = wan_interface_path .. "proto",
    wan_ppp_user_name = wan_interface_path .. "username",
    wan_ppp_password = wan_interface_path .. "password",
    wan_ppp_vpi_number = wan_atm_uci_path .. "vpi",
    wan_ppp_vci_number = wan_atm_uci_path .. "vci",
    wan_ppp_enc = wan_atm_uci_path .. "enc",
    wan_ppp_ulp = wan_atm_uci_path .. "ulp",
    wan_ppp_vpi_number_if = wan_interface_path .. "vpi",
    wan_ppp_vci_number_if = wan_interface_path .. "vci",
    wan_ppp_keepalive = wan_interface_path .. "keepalive",
    wan_ipoe_vpi_number = wan_atm_uci_ipoe_path .. "vpi",
    wan_ipoe_vci_number = wan_atm_uci_ipoe_path .. "vci",
    wan_static_ipaddr = wan_interface_path .. "ipaddr",
    wan_static_submsk = wan_interface_path .. "netmask",
    wan_static_gatewayip = wan_interface_path .. "gateway",
    wan_static_dns = static_dns_path,
    wan_metric = wan_interface_path .. "metric",
    wan_dhcp_reqopts = wan_interface_path .. "reqopts",
    wan_dhcp_neighreachabletime = wan_interface_path .. "neighreachabletime",
    wan_dhcp_neighgcstaletime = wan_interface_path .. "neighgcstaletime",
    ppp_username  = "uci.network.interface.@wan.username",
    ppp_password = "uci.network.interface.@wan.password",
    wan_peerdns = wan_interface_path .. "peerdns",
    id_vlan_vdsl = "uci.network.device.@wanptm0.vid",
    id_vlan_eth = "uci.network.device.@waneth4.vid",
}

local mapParams_wans = {
    wansensing_enable = "uci.wansensing.global.enable",
    wansensing_l2type = "uci.wansensing.global.l2type",
    wansensing_l3type = "uci.wansensing.global.l3type",
    ppp_auto = "uci.network.interface.@wan.auto",
    ipoe_auto = "uci.network.interface.@ipoe.auto",
    wan_auto = wan_interface_path .. "auto",
}

local function validateVlanID(value, object, key)
    if object["wan_type"] ~= "vdsl" and object["wan_type"] ~= "eth" or object["vlan_enabled"] == "0" or object["wan_proto"] ~= "pppoe" then
        object["id_vlan_eth"] = nil
        object["id_vlan_vdsl"] = nil
        return true
    else
        if object["wan_type"] == "vdsl" and "id_vlan_vdsl" ~= key or object["wan_type"] == "eth" and "id_vlan_eth" ~= key then
            object[key] = nil
            return true
        end
    end

    local pattern = "^(%d+)$"
    local number = { string.match(value, pattern) }
    if #number ~= 1 or tonumber(number[1]) < 2 or tonumber(number[1]) > 4094 then
        return nil, T"Invalid VLAN ID, it must be a number on the range 2-4094"
    end
    return vN(value)
end

local function validateWanIfName(value, object, key)
    if object["wan_type"] == "adsl" then
        if "pppoe" == object["wan_proto"] or "pppoa" == object["wan_proto"] then
            object["wan_ifname"] = "atmwan"
        end
        if "dhcp" == object["wan_proto"] or "static" == object["wan_proto"] then
            object["wan_ifname"] = "atmwan"
        end
    end
    if object["wan_type"] == "vdsl" then
        object["wan_ifname"] = "ptm0"
        if "pppoe" == object["wan_proto"] and object["vlan_enabled"] == "1" then
            object["wan_ifname"] = "wanptm0"
        end
    end
    if object["wan_type"] == "eth" then
        object["wan_ifname"] = "eth4"
        if "pppoe" == object["wan_proto"] and object["vlan_enabled"] == "1" then
            object["wan_ifname"] = "waneth4"
        end
    end
    return true
end

local function validateWanIfProto(value, object, key)
    if object["wan_type"] == "adsl" then
        if object["wan_proto"] == "pppoe" then
            object["wan_ppp_ulp"] = "eth"
            object["wan_ppp_enc"] = "llc"
        end

        if object["wan_proto"] == "pppoa" then
            object["wan_ppp_ulp"] = "ppp"
            object["wan_ppp_enc"] = "vcmux"
        end
    end

    if object["wan_proto"] == "pppoe" or object["wan_proto"] == "pppoa" then
        object["wan_metric"] = "10"
        object["wan_ppp_keepalive"] = "4,20"
    else
        object["wan_metric"] = "1"
        object["wan_ppp_keepalive"] = ""
    end

    if object["wan_proto"] == "dhcp" then
        object["wan_dhcp_reqopts"] = "1 3 6 43 51 58 59"
        object["wan_dhcp_neighreachabletime"] = "1200000"
        object["wan_dhcp_neighgcstaletime"] = "2400"
    else
        object["wan_dhcp_reqopts"] = ""
        object["wan_dhcp_neighreachabletime"] = ""
        object["wan_dhcp_neighgcstaletime"] = ""
    end

    if object["wan_proto"] ~= "static" then
        object["wan_static_ipaddr"] = ""
        object["wan_static_submsk"] = ""
        object["wan_static_gatewayip"] = ""
        object["wan_static_dns"] = ""
    end
    object["wan_peerdns"] = ""

    return true
end

local function validateWanPPPUsername(value, object, key)
    if (object["wan_proto"] == "pppoe" or object["wan_proto"] == "pppoa")  then
        object["ppp_username"] = object[key]
        return vNES(value)
    end
    object[key] = ""
    return true
end

local function validateWanPPPPassword(value, object, key)
    if (object["wan_proto"] == "pppoe" or object["wan_proto"] == "pppoa") then
        if value == "********" then
            object[key] = session:retrieve("network_password")
            object["ppp_password"] = object[key]
            return true
        end
        local ret, msg = vNES(value)
        if ret then
            session:store("network_password", value)
        end
        return ret, msg
    end
    object[key] = ""
    return true
end

local function validateVpiAndVciNum(value, object, key)
    if object["wan_type"] == "adsl" then
        if object["wan_proto"] == "pppoa" then
            object[key .. "_if"] = value
        else
            object[key .. "_if"] = ""
        end
        return vN(value)
    end
    object[key] = nil
    object[key .. "_if"] = ""
    return true
end

local function validateWanStaticIpAddr(value, object, key)
    if object["wan_proto"] == "static" then
        return vSIP(value)
    end
    object[key] = ""
    return true
end

local dns_errors = {}
local function validateDnsServers(value, object, key)
    if object["wan_proto"] == "static" then
        local ret1, msg1 = vSIP(object["wan_static_pri_dns"])
        local ret2, msg2 = vSIP(object["wan_static_sec_dns"])
        if ret1 and ret2 then
            object["wan_static_dns"] = object["wan_static_pri_dns"] .. "," .. object["wan_static_sec_dns"]
            return true
        end
        if not ret1 then
            dns_errors["wan_static_pri_dns"] = true
        end

        if not ret2 then
            dns_errors["wan_static_sec_dns"] = true
        end
        if not ret1 then return ret1, msg1 end
        if not ret2 then return ret2, msg2 end
    end
    object[key] = ""
    return true
end


local function validateWanStaticIpNetMask(value, object, key)
    if object["wan_proto"] == "static" then
        return vIPv4MSK(value)
    end
    object[key] = ""
    return true
end

local function validateWansensing(value, object, key)
    if object["wansensing_enable"] == "1" then
        local content = {
            wan_ifname = "uci.network.interface.@wan.ifname",
            wan_proto = "uci.network.interface.@wan.proto",
            ppp_ifname = "uci.network.interface.@wan.ifname",
        }
        content_helper.getExactContent(content)
        if object["wan_type"] ~= ifname2wantype[content["wan_ifname"]] or content["wan_proto"] ~= object["wan_proto"] then
            object[key] = "0"
            object["wansensing_l2type"] = ""
            object["wansensing_l3type"] = ""
            object["ppp_auto"] = "0"
            object["pppv_auto"] = "0"
            object["ipoe_auto"] = "0"
            object["wan_auto"] = "1"
            return true
        end
    end
    object[key] = nil
    object["wansensing_l2type"] = nil
    object["wansensing_l3type"] = nil
    object["ppp_auto"] = nil
    object["pppv_auto"] = nil
    object["ipoe_auto"] = nil
    object["wan_auto"] = nil
    return true
end

local function getWanType(content, content_wans)
    local wansensing_l2type = lower(content_wans["wansensing_l2type"])
    if wansensing_l2type == "" then wansensing_l2type = "adsl" end
    return content["wan_type"] or ifname2wantype[content["wan_ifname"]] or wansensing_l2type
end

local mapValid = {
    wan_ifname = validateWanIfName,
    wan_proto = validateWanIfProto,
    wan_ppp_user_name = validateWanPPPUsername,
    wan_ppp_password = validateWanPPPPassword,
    wan_ppp_vpi_number = validateVpiAndVciNum,
    wan_ppp_vci_number = validateVpiAndVciNum,
    wan_ipoe_vpi_number = validateVpiAndVciNum,
    wan_ipoe_vci_number = validateVpiAndVciNum,
    wan_static_ipaddr = validateWanStaticIpAddr,
    wan_static_submsk = validateWanStaticIpNetMask,
    wan_static_dns = validateDnsServers,
    wan_static_gatewayip = validateWanStaticIpAddr,
    id_vlan_vdsl = validateVlanID,
    id_vlan_eth = validateVlanID,
}

local mapValid_wans = {
    wansensing_enable = validateWansensing,
}
local content_wans, helpmsg_wans = wizard_helper.handleQuery(mapParams_wans, mapValid_wans)
local content, helpmsg = wizard_helper.handleQuery(mapParams, mapValid)
local vlan_is_on = content["vlan_enabled"]
if vlan_is_on == nil then
    if string.find(content["wan_ifname"], "^vlan_") ~= nil then
        vlan_is_on = "1"
    else
        vlan_is_on = "0"
    end
end

if ngx.req.get_method() == "GET" then
    session:store("network_password", content["wan_ppp_password"])
elseif content["action"] == "SAVE" then
    session:store("network_password", nil)
end

local wan_type = getWanType(content, content_wans)

if not content["wan_static_pri_dns"] then
    local dns_servers = {}
    --to get the dns server value, the string is 1.1.1.1,2.2.2.2,
    for dns_server in gmatch(content["wan_static_dns"], "([^,]+)") do
        dns_servers[#dns_servers+1] = dns_server
    end
    content["wan_static_pri_dns"] = dns_servers[1] or ""
    content["wan_static_sec_dns"] = dns_servers[2] or ""
end

local wan_interface_options_confirm = setmetatable({
    ["adsl"] = "ADSL",
    ["eth"] = "Ethernet",
    ["vdsl"] = "VDSL",
}, untaint_mt)

local wan_proto_options_confirm = setmetatable({
    ["pppoe"] = "PPP over Ethernet",
    ["pppoa"] = "PPP over ATM",
    ["dhcp"]   = "Dynamic IP Address",
    ["static"] = "Static IP Address",
}, untaint_mt)

%>
<div class='wizard-card'>
   <fieldset>
     <%
        local html = {}
        -- The reserved legend to be filled automatically when loading
        html[#html+1] =  "<legend></legend>"
		html[#html+1] = ui_helper.createMessages(message_helper.popMessages())

        local wan_type_class = {
            select = {
                class = "monitor-changes",
            },
        }
        html[#html+1] = ui_helper.createInputSelect(T"WAN Interfaces", "wan_type", wan_interface_options, wan_type, wan_type_class)

        local wan_proto_class = {
            select = {
                class = "monitor-changes",
            },
        }

        html[#html+1] = ui_helper.createInputSelect(T"WAN Type:", "wan_proto", wan_proto_options, content["wan_proto"], wan_proto_class)

        local wan_vlan_class = {
            group = {
                class = "monitor-wan_type monitor-vdsl monitor-eth monitor-wan_proto monitor-pppoe",
            },
            input = {
                class = "monitor-changes",
            },
        }
        html[#html+1] = ui_helper.createSwitch(T"VLAN Enabled","vlan_enabled", vlan_is_on, wan_vlan_class)
        wan_vlan_class.group.class = "monitor-vlan_enabled monitor-1 monitor-wan_proto monitor-pppoe monitor-wan_type monitor-vdsl"
        html[#html+1] = ui_helper.createInputText(T"VLAN ID", "id_vlan_vdsl", content["id_vlan_vdsl"], wan_vlan_class, helpmsg["id_vlan_vdsl"])
        wan_vlan_class.group.class = "monitor-vlan_enabled monitor-1 monitor-wan_proto monitor-pppoe monitor-wan_type monitor-eth"
        html[#html+1] = ui_helper.createInputText(T"VLAN ID", "id_vlan_eth", content["id_vlan_eth"], wan_vlan_class, helpmsg["id_vlan_eth"])
        local wan_pppoa_class = {
            group = {
                class = "monitor-wan_type monitor-adsl monitor-wan_proto monitor-pppoe monitor-pppoa",
            },
            input = {
                class= "span4",
            },
        }
        local wan_ipoe_class = {
            group = {
                class = "monitor-wan_type monitor-adsl monitor-wan_proto monitor-static monitor-dhcp",
            },
            input = {
                class= "span4",
            },
        }
        local wan_ppp_class = {
            group = {
                class = "monitor-wan_proto monitor-pppoe monitor-pppoa",
            },
            input = {
                class= "span4",
            },
        }
        html[#html+1] = ui_helper.createInputText(T"Username: ", "wan_ppp_user_name", content["wan_ppp_user_name"], wan_ppp_class, helpmsg["wan_ppp_user_name"])
        html[#html+1] = ui_helper.createInputPassword(T"Password:", "wan_ppp_password", content["wan_ppp_password"], wan_ppp_class, helpmsg["wan_ppp_password"])
        html[#html+1] = ui_helper.createInputText(T"VPI Number: ", "wan_ppp_vpi_number", content["wan_ppp_vpi_number"], wan_pppoa_class, helpmsg["wan_ppp_vpi_number"])
        html[#html+1] = ui_helper.createInputText(T"VPI Number: ", "wan_ipoe_vpi_number", content["wan_ipoe_vpi_number"], wan_ipoe_class, helpmsg["wan_ipoe_vpi_number"])
        html[#html+1] = ui_helper.createInputText(T"VCI Number: ", "wan_ppp_vci_number", content["wan_ppp_vci_number"], wan_pppoa_class, helpmsg["wan_ppp_vci_number"])
        html[#html+1] = ui_helper.createInputText(T"VCI Number: ", "wan_ipoe_vci_number", content["wan_ipoe_vci_number"], wan_ipoe_class, helpmsg["wan_ipoe_vci_number"])

        local wan_static_class = {
            group = {
               class ="monitor-wan_proto monitor-static",
            },
        }
        html[#html+1] = ui_helper.createInputText(T"Static IP Address:", "wan_static_ipaddr", content["wan_static_ipaddr"], wan_static_class, helpmsg["wan_static_ipaddr"])
        html[#html+1] = ui_helper.createInputText(T"Static Subnet Mask:", "wan_static_submsk", content["wan_static_submsk"], wan_static_class, helpmsg["wan_static_submsk"])
        html[#html+1] = ui_helper.createInputText(T"Static Gateway:", "wan_static_gatewayip", content["wan_static_gatewayip"], wan_static_class, helpmsg["wan_static_gatewayip"])
        html[#html+1] = ui_helper.createInputText(T"Static Primary DNS: ",  "wan_static_pri_dns", content["wan_static_pri_dns"], wan_static_class, dns_errors["wan_static_pri_dns"] and helpmsg["wan_static_dns"])
        html[#html+1] = ui_helper.createInputText(T"Static Secondary DNS: ", "wan_static_sec_dns", content["wan_static_sec_dns"], wan_static_class, dns_errors["wan_static_sec_dns"] and helpmsg["wan_static_dns"])

        ngx.print(html)
    %>
  </fieldset>
</div>

<div class='wizard-confirm'>
  <fieldset>
    <%
        local html = {}
        local notice_confirm_attr = {
          alert = {
              class = "alert-info monitor-fw_level monitor-normal"
          },
        }
        -- The reserved legend to be filled automatically when loading
        html[#html+1] =  "<legend></legend>"
        html[#html+1] =  T"<h4>Router Installation is Complete</h4>"
        html[#html+1] = ui_helper.createAlertBlock(T"Please review your settings and click finish.<br/>Your Router will reset and settings will be saved.", notice_confirm_attr)
        html[#html+1] = ui_helper.createLabel(T"WAN Interfaces:", wan_interface_options_confirm[wan_type] or "")
        html[#html+1] = ui_helper.createLabel(T"WAN Type:", wan_proto_options_confirm[content["wan_proto"]] or "")

        if  (content["wan_proto"] == "pppoe" or content["wan_proto"] == "pppoa") then
            html[#html+1] = ui_helper.createLabel(T"Username: ", content["wan_ppp_user_name"])
            html[#html+1] = ui_helper.createLabel(T"Password:", content["wan_ppp_password"])
        end

        if (content["wan_proto"] == "static") then
            html[#html+1] = ui_helper.createLabel(T"Static IP Address:", content["wan_static_ipaddr"])
            html[#html+1] = ui_helper.createLabel(T"Static Subnet Mask:", content["wan_static_submsk"])
            html[#html+1] = ui_helper.createLabel(T"Static Gateway:", content["wan_static_gatewayip"])
            html[#html+1] = ui_helper.createLabel(T"Static Primary DNS: ", content["wan_static_pri_dns"])
            html[#html+1] = ui_helper.createLabel(T"Static Secondary DNS: ", content["wan_static_sec_dns"])
        end
        if  (wan_type == "adsl") then
            if (content["wan_proto"] == "pppoe" or content["wan_proto"] == "pppoa") then
                html[#html+1] = ui_helper.createLabel(T"VPI Number: ", content["wan_ppp_vpi_number"])
                html[#html+1] = ui_helper.createLabel(T"VCI Number: ", content["wan_ppp_vci_number"])
            else
                html[#html+1] = ui_helper.createLabel(T"VPI Number: ", content["wan_ipoe_vpi_number"])
                html[#html+1] = ui_helper.createLabel(T"VCI Number: ", content["wan_ipoe_vci_number"])
            end
        end
        if (content["wan_proto"] == "pppoe" and content["vlan_enabled"] == "1") then
            if (wan_type == "vdsl") then
                html[#html+1] = ui_helper.createLabel(T"VLAN ID: ", content["id_vlan_vdsl"])
            end
            if (wan_type == "eth") then
                html[#html+1] = ui_helper.createLabel(T"VLAN ID: ", content["id_vlan_eth"])
            end
        end
        ngx.print(html)
    %>
  </fieldset>
</div>
<script type="text/javascript">
$(document).ready(function () {
  var wan_type = $("select[name='wan_type']").val();
  if (wan_type != "adsl") {
    $('option[value="pppoa"]').hide();
  }
})

$('select[name="wan_type"]').on("change", function() {
  var wan_type = $("select[name='wan_type']").val();
  if (wan_type == "adsl") {
    $('option[value="pppoa"]').show();
  }
  else {
    $('option[value="pppoa"]').hide();
    var wan_proto_el = $("select[name='wan_proto']")
    var wan_proto = wan_proto_el.val();
    if (wan_proto == "pppoa") {
        wan_proto_el.val("pppoe");
    }
  }
})
</script>
