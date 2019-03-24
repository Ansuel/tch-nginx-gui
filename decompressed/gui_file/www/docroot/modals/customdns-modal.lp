--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")

local match = string.match

local uniqueKey = post_helper.getRandomKey()

-- DNS rules
local policy_select = {{"any", "any"}}
local outpolicy_select = {{"copy", "copy"}, {"default", "default"}}

local policy_pn = proxy.getPN("uci.mwan.policy.",true)
if policy_pn then
    for _,v in ipairs(policy_pn) do
        local path = v["path"]
        local policy_name = match(path,"@([^@%.]-)%.")
        if policy_name then
            policy_select[#policy_select + 1] = {policy_name, policy_name}
            outpolicy_select[#outpolicy_select + 1] = {policy_name, policy_name}
        end
    end
end

local intfs_select = {{"default", "default"}}

local intfs_pn = proxy.getPN("uci.network.interface.",true)
if intfs_pn then
    for _,v in ipairs(intfs_pn) do
        local path = v["path"]
        local intf_name = match(path,"@([^@%.]-)%.")
        if intf_name and intf_name ~= "loopback" and intf_name ~= "lan" then
            intfs_select[#intfs_select + 1] = {intf_name,intf_name}
        end
    end
end

local dnsrule_columns = {
  {
    header = "",
    name = "enable",
    param = "enable",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Domain",
    name = "domain",
    param = "domain",
    type = "text",
    attr = { input = { class="span2", maxlength="30"} },
  },
  {
    header = T"DNS Set",
    name = "dnsset",
    param = "dnsset",
    type = "select",
    values = intfs_select,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Policy",
    name = "policy",
    param = "policy",
    type = "select",
    values = policy_select,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Out Policy",
    name = "outpolicy",
    param = "outpolicy",
    type = "select",
    values = outpolicy_select,
    attr = { select = { class="span1" } },
  },
}

local function dns_sort(rule1, rule2)
  return rule1.paramindex < rule2.paramindex
end

local domain_valid = {
   domain = post_helper.getOrValidation(post_helper.validateStringIsDomainName, post_helper.validateStringIsIP),
}
local dnsrule_options = {
    tableid = "dnsrules",
    basepath = "uci.dhcp.dnsrule.@.",
    createMsg = T"Add new dns rule",
    sorted = dns_sort,
    objectName  = "dns_"..uniqueKey,
    addNamedObject = true
}

local dnsrule_data, dnsrule_helpmsg = post_helper.handleTableQuery(dnsrule_columns, dnsrule_options, nil, nil, domain_valid)

for k, v in pairs(dnsrule_data) do
    if(v[1] == nil or v[1] == "") then
        v[1] = "1"
    end
    if(v[4] == nil or v[4] == "") then
        v[4] = "any"
    end
    if(v[5] == nil or v[5] == "") then
        v[5] = "copy"
    end
end

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"DNS rules", false, false))   ngx.print('\
\
<div class="modal-body update">\
');
	local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-wanservices.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="/modals/customdns-modal.lp">\
    <fieldset>\
      ');  
        ngx.print(ui_helper.createTable(dnsrule_columns, dnsrule_data, dnsrule_options, nil, dnsrule_helpmsg))
        ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');