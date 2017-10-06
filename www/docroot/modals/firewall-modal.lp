--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')
-- Process POST query
-- NG-93504 Creation of user specific Firewall shall not be possible for user admin
-- NG-93802 TI-GUI : Enabling/Disabling IPv6 Firewall option is not available in GUI

local ngx = ngx
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local portslist = require("portslist_helper")
local protolist = require("protolist_helper")
local hosts_ac, hosts_ac_v6 = require("web.uinetwork_helper").getAutocompleteHostsList()
local remove = table.remove
local role = ngx.ctx.session:getrole()
local str_format, str_match, str_untaint = string.format, string.match, string.untaint


local tech = false
if role == "engineer" then
	tech = true
end

local outgoingpolicy = {
    {"ACCEPT", T"ACCEPT"},
    {"DROP", T"DROP"},
    {"REJECT", T"REJECT"},
}

local incomingpolicy = {
    {"DROP", T"DROP"},
    {"REJECT", T"REJECT"},
}

local fw_levels = {
    {"lax", T"<strong>Low</strong>"},
    {"normal", T"<strong>Medium</strong>"},
    {"high", T"<strong>High</strong>"},
}

if tech then
	fw_levels[#fw_levels + 1] = {"user", T"<strong>User</strong>"}
end

local fw_params = {
    fwv4_ping = "rpc.network.firewall.internetpingipv4",
	fw_ipv6 = "Device.Firewall.X_000E50_EnableIPv6",
    fwv6_ping = "rpc.network.firewall.internetpingipv6",
    fw_level = "rpc.network.firewall.mode",
    fw_outgoing_policy = "rpc.network.firewall.useroutgoingdefault",
    fw_incoming_policy = "rpc.network.firewall.userincomingdefault",
}

-- Retrieve GW IP + netmask for use by validation function
local ipdetails = {
    gw = "uci.network.interface.@lan.ipaddr",
    netmask = "uci.network.interface.@lan.netmask"
}
content_helper.getExactContent(ipdetails)

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean
local vSII = post_helper.validateStringIsIP
local gVIES = post_helper.getValidateInEnumSelect
local vSIPR = post_helper.validateStringIsPortRange
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)
local vSIIv6 = post_helper.validateStringIsIPv6
local gAV = post_helper.getAndValidation
local vNES = post_helper.validateNonEmptyString
local gOV = post_helper.getOptionalValidation
local vIP4AS = post_helper.validateIPAndSubnet(4)
local vIP6AS = post_helper.validateIPAndSubnet(6)

local fw_valid = {
    fwv4_ping = vB,
	fw_ipv6 = vB,
    fwv6_ping = vB,
    fw_level = gVIES(fw_levels),
    fw_outgoing_policy = gVIES(outgoingpolicy),
    fw_incoming_policy = gVIES(incomingpolicy),
}

local content = post_helper.handleQuery(fw_params, fw_valid)

-- Firewall rules
local function fwrule_sort(rule1, rule2)
  return tonumber(rule1.paramindex) < tonumber(rule2.paramindex)
end

local fwrules_targets = {
    { "ACCEPT", "ACCEPT"},
    { "DROP", "DROP"},
    { "REJECT", "REJECT"},
}

-- DSCP markings for firewall rules
-- First column denotes value to set
-- Second column denotes string displayed to user in drop-down
local fwrules_dscp = {
    {"", ""},
    {"-m dscp --dscp 0x0a", T"AF11" },
    {"-m dscp --dscp 0x0c", T"AF12" },
    {"-m dscp --dscp 0x0e", T"AF13" },
    {"-m dscp --dscp 0x12", T"AF21" },
    {"-m dscp --dscp 0x14", T"AF22" },
    {"-m dscp --dscp 0x16", T"AF23" },
    {"-m dscp --dscp 0x1a", T"AF31" },
    {"-m dscp --dscp 0x1c", T"AF32" },
    {"-m dscp --dscp 0x1e", T"AF33" },
    {"-m dscp --dscp 0x22", T"AF41" },
    {"-m dscp --dscp 0x24", T"AF42" },
    {"-m dscp --dscp 0x26", T"AF43" },
    {"-m dscp --dscp 0x08", T"CS1" },
    {"-m dscp --dscp 0x10", T"CS2" },
    {"-m dscp --dscp 0x18", T"CS3" },
    {"-m dscp --dscp 0x20", T"CS4" },
    {"-m dscp --dscp 0x28", T"CS5" },
    {"-m dscp --dscp 0x30", T"CS6" },
    {"-m dscp --dscp 0x38", T"CS7" },
    {"-m dscp --dscp 0x2e", T"EF" },
}

local fwrule_columns = {
  {
    header = "",
    name = "enabled",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Action",
    name = "target",
    param = "target",
    default = "DROP",
    type = "select",
    values = fwrules_targets,
    attr = { select = { class="span1", style="width: 100px" } },
  },
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto",
    default = "tcp",
    type = "select",
    values = protolist.IPv4Protocol,
    attr = { select = { class="span1", style="width: 100px" } },
  },
  {
    header = T"Src IP/Subnet",
    name = "src_ip",
    param = "src_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="18"} },
  },
  {
    header = T"Src port",
    name = "src_port",
    param = "src_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
  {
    header = T"Dst IP/Subnet",
    name = "dest_ip",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="18"}, autocomplete = hosts_ac },
  },
  {
    header = T"Dst port",
    name = "dest_port",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
  {
    header = T"DSCP",
    name = "dscp",
    param = "extra",
    default = "",
    type = "select",
    values = fwrules_dscp,
    attr = { select = { class="span1", style="width: 100px" } },
  },
}

local fwrule_options = {
    tableid = "fwrules",
    basepath = "rpc.network.firewall.userrule.@.",
    createMsg = T"Add new IPv4 firewall rule",
    sorted = fwrule_sort
}

local duplicatedErrMsg = nil
local session = ngx.ctx.session
--[[
   The following function used to validate the duplicate entries while adding or editing on firewall table.
   We will throw the duplicate error if any rows containing all 6 values below are duplicated
   Sample:- Protocol    Src IP       Src port      Dst IP         Dst port    DSCP
            TCP         192.168.1.1  1000          192.168.1.4    2000        AF23
            TCP         192.168.1.1  1000          192.168.1.5    2000        CS7
            UDP         192.168.1.1  1000          192.168.1.5    2001        AF23
            TCP         192.168.1.1  1000          192.168.1.5    2000        EF
   In above example the 4th and 2nd rows are exactly duplicated. In this case we throw the error message as duplicated.
   If anyone of the value of row is different then we dont consider as duplicated row.
]]
local function rulesDuplicateCheck(basepath,tableid,columns)
  return function(value, postdata, key)
  local sucess,msg
    if value and value ~= "" then
      sucess,msg = vSIPR(value, postdata, key)
    else
      sucess = true
    end
    if sucess then
      -- specify column range to check for duplicates
      local startIndex, endIndex= 3,8
      local fullpath = nil
      if postdata.action =="TABLE-MODIFY" then
        local index = tonumber(postdata.index)
        local tablesessionindexes = tableid..".allowedindexes"
        local allowedIndexes = session:retrieve(tablesessionindexes) or {}
        if allowedIndexes[index] then
          index = allowedIndexes[index].paramindex
        end
        -- fullpath => The UCI path which is going to be modifed, Ex: rpc.network.firewall.userrule.@4.
        fullpath = basepath .. "@"..index.."."
      end
      local paths=nil
      for i=startIndex, endIndex do
        local value = string.untaint(postdata[columns[i].name])
        local cmatch = content_helper.getMatchedContent(basepath, {[columns[i].param] = value })
        if fullpath then
          for u,v in ipairs(cmatch) do
            if v.path == fullpath then
            --The rpc.network.firewall.userrule.@4. will be removed
            --because we no need to validate with the path which we need to modify
              remove(cmatch, u)
              break
            end
          end
        end
        -- If cmatch is empty then there will be no duplicated rows in UCI.
        if #cmatch > 0 then
        -- The below condition will be true at first iteration.
          if i == startIndex then
            -- At the first iteration the duplicate paths will be stored in a temp table
            -- which can be used to validate with duplicate path of subsequest columns
            paths={}
            for _,v in ipairs(cmatch) do
              paths[v.path]=true
            end
          -- If path is empty then no duplicates in previous columns. So we can break the loop and can say no duplicates
          elseif paths then
            local duplicate = {}
            local flag = false
            for _,v in ipairs(cmatch) do
              if paths[v.path] then
                duplicate[v.path] = true
                flag = true
              end
            end
            -- if current duplicated path is not matching with previouse duplicatd paths.
            -- Then there is no exact duplicated rows.
            if flag then
              paths = duplicate
            else
               paths = nil
               break
            end
          else
            paths = nil
            break
          end
        else
          paths=nil
          break
        end
      end
      --Finally if you get one or more paths which contain all
      --the 4 values are duplicated (sr ip,port and dest ip, port) are duplicated
      if paths then
          sucess = nil
          msg = T"duplicate value"
          duplicatedErrMsg = msg
      end
    end
    return sucess, msg
  end
end

local function removeSpace(validation)
  return function(value, postdata, key)
  local sucess,msg
  if value and value ~= "" then
    value = string.gsub(value," " ,"")
    postdata[key] = value
    success,msg = validation(value)
  end
  return success,msg
 end
end

local fwrule_valid = {
    enabled = vB,
    target = gVIES(fwrules_targets),
    protocol = gVIES(protolist.IPv4Protocol),
    src_ip = vIP4AS,
    src_port = gOV(vSIPR),
    dest_ip = vIP4AS,
    dest_port = rulesDuplicateCheck("rpc.network.firewall.userrule.", "fwrules",fwrule_columns),
    dscp = gVIES(fwrules_dscp),
}

local fwrule_defaultObject = {
    src = "lan",
    dest = "wan"
}

-- PING WHITELIST RULES START

-- select list for icmp-type
local icmpTypeList = { {"echo-request", "echo-request"}, }

-- pingrule handleTableQuery parameter to match columns to rpc table data
local fwrule_ping_columns = {
  {
    header = T"Enabled",
    name = "enabled",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Source IP",
    name = "src_ip",
    param = "src_ip",
    type = "text",
    unique = true,  -- sadly unique doesn't work for this field
    attr = { input = { class="span3", maxlength="39" }, },
  },
  {
    -- I don't want this entry in the table ... but it must be set and I
    -- can't figure out how to put it in the defaultObject
    header = T"icmp-type",
    name = "icmp_type",
    param = "icmp_type.@1.value",
    default = "echo-request",
    type = "select",
    values = icmpTypeList,
    attr = { select = { class="span2", readonly="true"}, },
  },
}

local fwrulev4_ping_columns = {
  {
    header = T"Enabled",
    name = "enabled",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Source IP",
    name = "src_ip",
    param = "src_ip",
    type = "text",
    unique = true,
    attr = { input = { class="span3", maxlength="39" }, },
  },
  {
    header = T"icmp-type",
    name = "icmp_type",
    param = "icmp_type.@1.value",
    default = "echo-request",
    type = "select",
    values = icmpTypeList,
    attr = { select = { class="span2", readonly="true"}, },
  },
  {
    header = "",
    name = "family",
    param = "family",
    type = "hidden",
    default = "ipv4",
  },
}

local fwrulev6_ping_columns = {
  {
    header = T"Enabled",
    name = "enabled",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Source IP",
    name = "src_ip",
    param = "src_ip",
    type = "text",
    unique = true,
    attr = { input = { class="span3", maxlength="39" }, },
  },
  {
    header = T"icmp-type",
    name = "icmp_type",
    param = "icmp_type.@1.value",
    default = "echo-request",
    type = "select",
    values = icmpTypeList,
    attr = { select = { class="span2", readonly="true"}, },
  },
  {
     header = "",
     name = "family",
     param = "family",
     type = "hidden",
     default = "ipv6",
  },
}

-- pingrule handleTableQuery parameter for query and display
local fwrulev4_ping_options = {
    tableid = "fwv4_ping_rules",
    basepath = "uci.firewall.rule.",
    createMsg = T"Add new IPv4 Ping WhiteList rule",
    -- Only allow table edits if overall remote ping is disabled when the page
    -- is loaded. If you disable remote ping your must save the change before
    -- editing is enabled. This is a GUI problem work around.
    canEdit = content["fwv4_ping"] == "0" and role == "engineer",
    canAdd = content["fwv4_ping"] == "0" and role == "engineer",
    canDelete = content["fwv4_ping"] == "0" and role == "engineer",
}

local fwrulev6_ping_options = {
    tableid = "fwv6_ping_rules",
    basepath = "uci.firewall.rule.",
    createMsg = T"Add new IPv6 Ping WhiteList rule",
    -- Only allow table edits if overall remote ping is disabled when the page
    -- is loaded. If you disable remote ping your must save the change before
    -- editing is enabled. This is a GUI problem work around.
    canEdit = content["fwv6_ping"] == "0" and role == "engineer",
    canAdd = content["fwv6_ping"] == "0" and role == "engineer",
    canDelete = content["fwv6_ping"] == "0" and role == "engineer",
}

-- pingrule handleTableQuery parameter filter callback to only show ping
-- whitelist rules
-- return true if entry should be displayed
local function fwrulev4_ping_filter(data)
    if ( string.sub(data.name, 1, string.len("WhiteList")) == "WhiteList" ) and data["family"] == "ipv4" then
        return true
    end

    return false
end

local function fwrulev6_ping_filter(data)
    if ( string.sub(data.name, 1, string.len("WhiteList")) == "WhiteList" ) and data["family"] == "ipv6" then
        return true
    end

    return false
end

-- ipv6 handleTableQuery parameter for default values when adding entry
local fwrule_ping_defaultObject = {
    src = "wan",
    target = "ACCEPT",
    name = "WhiteList",
    proto = "icmp"
}

-- pingrule handleTableQuery parameter to check validity of new entry values
-- every editable column needs a validity check function
local function validateIPv4(value, object, key)
    if string.find(value, ":") then
        return nil, T"Invalid IPv4 Address"
    end
    --object["family"] = "ipv4"
    return vSII(value, object, key)
end

local fwrulev4_ping_valid = {
    enabled = vB,
    src_ip = gAV(vNES, removeSpace(validateIPv4)),
    icmp_type = gVIES(icmpTypeList),
}

local fwrulev6_ping_valid = {
    enabled = vB,
    src_ip = gAV(vNES, removeSpace(vIP6AS)),
    icmp_type = gVIES(icmpTypeList),
}

local fwrulev4_ping_data, fwrulev4_ping_helpmsg = post_helper.handleTableQuery(fwrulev4_ping_columns, fwrulev4_ping_options, fwrulev4_ping_filter, fwrule_ping_defaultObject, fwrulev4_ping_valid)
local fwrulev6_ping_data, fwrulev6_ping_helpmsg = post_helper.handleTableQuery(fwrulev6_ping_columns, fwrulev6_ping_options, fwrulev6_ping_filter, fwrule_ping_defaultObject, fwrulev6_ping_valid)

-- PING WHITELIST RULES END

local fwrule_data, fwrule_helpmsg = post_helper.handleTableQuery(fwrule_columns, fwrule_options, nil, fwrule_defaultObject, fwrule_valid)

if duplicatedErrMsg then
  fwrule_helpmsg.protocol = duplicatedErrMsg
  fwrule_helpmsg.src_ip = duplicatedErrMsg
  fwrule_helpmsg.src_port = duplicatedErrMsg
  fwrule_helpmsg.dest_ip = duplicatedErrMsg
  fwrule_helpmsg.dest_port = duplicatedErrMsg
  fwrule_helpmsg.dscp = duplicatedErrMsg
  duplicatedErrMsg = nil
end

local fwrule_v6_columns = {
  {
    header = "",
    name = "enabled_v6",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Action",
    name = "target_v6",
    param = "target",
    default = "DROP",
    type = "select",
    values = fwrules_targets,
    attr = { select = { class="span1", style="width: 100px" } },
  },
  {
    header = T"Protocol",
    name = "protocol_v6",
    param = "proto",
    default = "tcp",
    type = "select",
    values = protolist.IPv6Protocol,
    attr = { select = { class="span1", style="width: 100px" } },
  },
  {
    header = T"Src IP/Subnet",
    name = "src_ip_v6",
    param = "src_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="39"} },
  },
  {
    header = T"Src port",
    name = "src_port_v6",
    param = "src_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
  {
    header = T"Dst IP/Subnet",
    name = "dest_ip_v6",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="39"}, autocomplete = hosts_ac_v6 },
  },
  {
    header = T"Dst port",
    name = "dest_port_v6",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
  {
    header = T"DSCP",
    name = "dscp_v6",
    param = "extra",
    default = "",
    type = "select",
    values = fwrules_dscp,
    attr = { select = { class="span1", style="width: 100px" } },
  },
}

local fwrule_v6_options = {
    tableid = "fwrules_v6",
    basepath = "rpc.network.firewall.userrule_v6.@.",
    createMsg = T"Add new IPv6 firewall rule",
    sorted = fwrule_sort
}

local fwrule_v6_valid = {
    enabled_v6 = vB,
    target_v6 = gVIES(fwrules_targets),
    protocol_v6 = gVIES(protolist.IPv6Protocol),
    src_ip_v6 = vIP6AS,
    src_port_v6 = gOV(vSIPR),
    dest_ip_v6 = vIP6AS,
    dest_port_v6 = rulesDuplicateCheck("rpc.network.firewall.userrule_v6.", "fwrules_v6",fwrule_v6_columns),
    dscp_v6 = gVIES(fwrules_dscp),
}

local fwrule_v6_data, fwrule_v6_helpmsg = post_helper.handleTableQuery(fwrule_v6_columns, fwrule_v6_options, nil, fwrule_defaultObject, fwrule_v6_valid)

if duplicatedErrMsg then
  fwrule_v6_helpmsg.protocol_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.src_ip_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.src_port_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.dest_ip_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.dest_port_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.dscp_v6 = duplicatedErrMsg
end
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Firewall", false, false))   ngx.print('\
\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/firewall-modal.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"Firewall level" ); ngx.print('</legend>\
\
');  
    local fwallmsg_visible_status = {
        lax = "monitor-hidden-fw_level",
        normal = "monitor-hidden-fw_level",
        high = "monitor-hidden-fw_level",
        user = "monitor-hidden-fw_level"
    }
    if content["fw_level"] == "lax" then
        fwallmsg_visible_status["lax"]=""
    elseif content["fw_level"] == "normal" then
        fwallmsg_visible_status["normal"]=""
    elseif content["fw_level"] == "high" then
        fwallmsg_visible_status["high"]=""
    elseif content["fw_level"] == "user" then
        fwallmsg_visible_status["user"]=""
    end
    local fwlevel_attr = {
        group = {
            class = ""
        },
        select = {
            class = "monitor-changes"
        }
    }
    local lax_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-lax " .. fwallmsg_visible_status["lax"]
        },
    }
    local normal_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-normal " .. fwallmsg_visible_status["normal"]
        },
    }
    local high_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-high " .. fwallmsg_visible_status["high"]
        },
    }
    local user_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-user " .. fwallmsg_visible_status["user"]
        },
    }
    ngx.print(
        ui_helper.createSliderSelect(T"Level", "fw_level", fw_levels, content["fw_level"], fwlevel_attr),
        ui_helper.createAlertBlock(T"In <strong>low mode</strong>, firewall allows all outbound connections and rejects unknown incoming connections but acknowledges presence of the gateway.", lax_attr),
        ui_helper.createAlertBlock(T"In <strong>medium mode</strong>, firewall allows all outbound connections and silently drops unknown incoming connections.", normal_attr),
        ui_helper.createAlertBlock(T"In <strong>high mode</strong>, firewall allows outgoing connections to HTTP, HTTPS, SMTP, POP3, IMAP, SSH services and silently drops unknown incoming connections.", high_attr),
        ui_helper.createAlertBlock(T"In <strong>user mode</strong>, individual firewall rules may be configured as well as the default behavior.", user_attr)
    )
  ngx.print('\
</fieldset>\
\
<fieldset>\
<legend>');  ngx.print( T"Firewall default behavior" ); ngx.print('</legend>\
\
');  
    local outgoing_attr = {
        group = {
            class = "monitor-fw_level monitor-user " .. fwallmsg_visible_status["user"]
        }
    }

    local info_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-user " .. fwallmsg_visible_status["user"]
        },
    }

    -- To monitor the ping enable switch
    local switch_class_enable = {
        input = {
            class = "monitor-changes",
        }
    }

    -- enable/disable the pingAllow table
     local pingrespv4_table_attr = {
        group = {
           class = "monitor-fwv4_ping monitor-0"
        }
     }

      local pingrespv6_table_attr = {
         group = {
            class = "monitor-fwv6_ping monitor-0"
         }
      }

    -- enable/disable the pingAllow text
    local pingrespv4_alert_attr = {
        alert = {
            class = "alert-info monitor-fwv4_ping monitor-0"
        },
    }

    local pingrespv6_alert_attr = {
        alert = {
            class = "alert-info monitor-fwv6_ping monitor-0"
        },
    }


    ngx.print(ui_helper.createSwitch(T"Answer All IPv4 Internet pings", "fwv4_ping", content["fwv4_ping"], switch_class_enable))
    ngx.print(ui_helper.createAlertBlock(T"Answer only these selected Internet IPv4 pings", pingrespv4_alert_attr))
    ngx.print(ui_helper.createTable(fwrulev4_ping_columns, fwrulev4_ping_data, fwrulev4_ping_options, pingrespv4_table_attr, fwrulev4_ping_helpmsg))

	ngx.print(ui_helper.createSwitch(T"IPv6 Firewall", "fw_ipv6", content["fw_ipv6"]))
	
    ngx.print(ui_helper.createSwitch(T"Answer All IPv6 Internet pings", "fwv6_ping", content["fwv6_ping"], switch_class_enable))
    ngx.print(ui_helper.createAlertBlock(T"Answer only these selected Internet IPv6 pings", pingrespv6_alert_attr))
    ngx.print(ui_helper.createTable(fwrulev6_ping_columns, fwrulev6_ping_data, fwrulev6_ping_options, pingrespv6_table_attr, fwrulev6_ping_helpmsg))
  ngx.print('\
        <legend></legend>\
');  

    ngx.print(
        ui_helper.createInputSelect(T"Outgoing default policy", "fw_outgoing_policy", outgoingpolicy, content["fw_outgoing_policy"], outgoing_attr),
        ui_helper.createAlertBlock(T"The <strong>outgoing policy</strong> defines what is done with packets coming from the LAN devices toward the internet. Setting it to REJECT or DROP will forbid any internet traffic from the LAN unless explicitly allowed by a firewall rule.", info_attr),
        ui_helper.createInputSelect(T"Incoming default policy", "fw_incoming_policy", incomingpolicy, content["fw_incoming_policy"], outgoing_attr),
        ui_helper.createAlertBlock(T"The <strong>incoming policy</strong> defines what is done with packets destined to the gateway. They can be either REJECTED (the gateway will notify the sender they were rejected) or DROPPED (the gateway will silently discard those packets).", info_attr)
    )
  ngx.print('\
\
\
</fieldset>\
\
<fieldset class="monitor-fw_level monitor-user ');  ngx.print(fwallmsg_visible_status["user"]); ngx.print('">\
<legend>');  ngx.print( T"IPv4 Firewall Rules" ); ngx.print('</legend>\
');  
    ngx.print(ui_helper.createTable(fwrule_columns, fwrule_data, fwrule_options, nil, fwrule_helpmsg))
  ngx.print('\
\
<legend>');  ngx.print( T"IPv6 Firewall Rules" ); ngx.print('</legend>\
');  
    ngx.print(ui_helper.createTable(fwrule_v6_columns, fwrule_v6_data, fwrule_v6_options, nil, fwrule_v6_helpmsg))
  ngx.print('\
\
</fieldset>\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
<script>\
(function() {\
    //by disabling the add new rule button, we prevent that the user start adding a rule, before the adapted firewall level user is saved.\
    //as this is a special case, we implement this here and not in actions.js\
    $(document).on("change", \'.modal select:not(.no-save):not(.disabled)\', function() {\
        $(".btn-table-new").addClass("disabled");\
    });\
}());\
var portLessProtocol = {};\
');  for _, v in ipairs(protolist.portless_proto) do   ngx.print('\
   portLessProtocol["');  ngx.print(v[1]); ngx.print('"] = true;\
');  end  ngx.print('\
\
if(portLessProtocol[$("#protocol").val()]){\
   $("#src_port, #dest_port").attr("readonly","true");\
}\
\
if(portLessProtocol[$("#protocol_v6").val()]){\
   $("#src_port_v6, #dest_port_v6").attr("readonly","true");\
}\
\
$("#protocol, #protocol_v6").on("change", function(){\
   if(portLessProtocol[this.value]){\
      $("#src_port, #dest_port").val("");\
      $("#src_port, #dest_port").attr("readonly","true");\
      $("#src_port_v6, #dest_port_v6").val("");\
      $("#src_port_v6, #dest_port_v6").attr("readonly","true");\
   }\
   else{\
      $("#src_port, #dest_port").removeAttr("readonly");\
      $("#src_port_v6, #dest_port_v6").removeAttr("readonly");\
   }\
});\
</script>\
'); 