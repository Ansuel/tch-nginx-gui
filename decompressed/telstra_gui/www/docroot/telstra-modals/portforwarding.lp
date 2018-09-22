--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/telstra-snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
  ngx.print('\
\
');  
-- Localization
gettext.textdomain('webui-telstra')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local portslist = require("portslist_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local table, ipairs = table, ipairs

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.getValidateCheckboxSwitch()
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vSIP = post_helper.validateStringIsPort
local vSIPR = post_helper.validateStringIsPortRange

-- In UCI
--config 'redirect'
--        option 'name' 'ssh'
--        option 'src' 'wan'
--        option 'proto' 'tcp'
--        option 'src_dport' '5555'
--        option 'dest_ip' '192.168.1.100'
--        option 'dest_port' '22'
--        option 'target' 'DNAT'
--        option 'dest' 'lan'

-- In Transformer
-- uci.firewall.redirect.{i}.name
-- uci.firewall.redirect.{i}.src
-- uci.firewall.redirect.{i}.src_dport
-- uci.firewall.redirect.{i}.dest_ip
-- uci.firewall.redirect.{i}.dest_port
-- uci.firewall.redirect.{i}.target
-- uci.firewall.redirect.{i}.dest
-- uci.firewall.redirect.{i}.proto.@1.value

-- Templates for pre-defined rules
local knownapps = require("pfwd_helper")

local portrange_pattern = "^(%d+)%:(%d+)$"
function compare_startport(a,b)
  return a.start < b.start
end

local function validPorts(ports)
    local curend = -1

    for _,v in ipairs(ports) do
        if v.start <= curend then
            return nil, { wanport = T"An existing mapping overlaps with the ports range" }
        else
            curend = v["end"]
        end
    end
    return true
end

local function globalValid(data)
    local tcp = {}
    local udp = {}
    local p1,p2
    local err, msg

    for i,v in ipairs(data) do
        local chunks = { v[4]:match(portrange_pattern) }
        if #chunks == 2 then
            p1 = tonumber(chunks[1])
            p2 = tonumber(chunks[2])
        else
            p1 = tonumber(v[4])
            p2 = p1
        end

        local proto = v[3]
        if proto == "tcp" or proto == "tcpudp" then
            tcp[#tcp+1] = { start = p1, ["end"] = p2, index = i }
        end
        if proto == "udp" or proto == "tcpudp" then
            udp[#udp+1] = { start = p1, ["end"] = p2, index = i }
        end
    end

    table.sort(tcp, compare_startport)
    table.sort(udp, compare_startport)

    err, msg = validPorts(tcp)
    if not err then
        return err, msg
    end
    err, msg = validPorts(udp)
    return err, msg
end

-- Firewall forwarding rules
local pfw_columns = {
    {
        header = "",
        name = "enabled",
        param = "enabled",
        type = "checkboxswitch",
        default = "1",
        --attr = { switch = { ["data-placement"] = "right" }}
    },
    {
        header = T"Name",
        name = "name",
        param = "name",
        type = "text",
	unique = true,
        attr = { input = { class="span2" } },
    },
    {
        header = T"Protocol",
        name = "protocol",
        param = "proto.@1.value",
        default = "tcp",
        type = "select",
        values = {
            { "tcp", "TCP"},
            { "udp", "UDP"},
            { "tcpudp", "TCP/UDP"}
        },
        attr = { select = { class="span2" } },
    },
    {
        header = T"WAN port",
        name = "wanport",
        param = "src_dport",
        type = "text",
        attr = { input = { class="span1", maxlength="11" }, autocomplete=portslist },
    },
    {
        header = T"LAN port",
        name = "lanport",
        param = "dest_port",
        type = "text",
        attr = { input = { class="span1", maxlength="11" }, autocomplete=portslist },
    },
    {
        header = T"Destination IP",
        name = "destinationip",
        param = "dest_ip",
        type = "text",
        attr = { input = { class="span2", maxlength="15"}, autocomplete=hosts_ac },
    },
}

local pfw_attributes = {
}

local function getValidateLanPort(value, object, key)
    if value == "" then
       local validated, msg = vSIPR(object["wanport"], object, key)
       if validated then
          return true
       end
    end
    return vSIPR(value, object, key)
end

local pfw_valid = {
    enabled = vB,
    name = vNES,
    lanport = getValidateLanPort,
    wanport = vSIPR,
    destinationip = vSII,
}

-- Warning, this uses transformer paths. So use correct naming
local pfw_defaultObject = {
    src = "wan",
    dest = "lan",
    family = "ipv4",
    target = "DNAT",
}

local pfw_filter = nil

local pfw_options = {
    tableid = "portforwarding",
    basepath = "uci.firewall.userredirect.",
    createMsg = T"Add new port mapping",
    newList = knownapps,
    valid = globalValid,
}

local pfw_data, pfw_helpmsg = post_helper.handleTableQuery(pfw_columns, pfw_options, pfw_filter, pfw_defaultObject, pfw_valid)

  ngx.print('\
\
<div class="container">\
\
');  lp.include("tabs-services.lp")   ngx.print('\
\
<div class="row">\
<div class="span11">\
\
<form class="form-horizontal" method="post" action="portforwarding.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
');  
ngx.print(ui_helper.createTable(pfw_columns, pfw_data, pfw_options, pfw_attributes, pfw_helpmsg))
  ngx.print('\
</fieldset>\
</form>\
\
');  
lp.include("save.lp")
  ngx.print('\
\
</div>\
</div>\
</div>\
\
');  
lp.include("footer.lp")
  ngx.print('\
'); 