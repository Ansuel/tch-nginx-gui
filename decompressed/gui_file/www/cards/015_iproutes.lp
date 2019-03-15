--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local session = ngx.ctx.session
local modalPath = "/modals/iproutes-modal.lp"

if session:hasAccess(modalPath) then
--Dynamic Routes
local dyn_count = proxy.getPN("sys.class.iproutes.", true)
dyn_count = dyn_count and #dyn_count or 0

--DNS

function split(x,sep)
        x = tostring(x)
        local sep, fields = sep or ":", {}
        local pattern = format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

local dns_rpc_path = "rpc.network.interface."
local interface_pn = proxy.getPN(dns_rpc_path, true)
local dnsservers_paths = {}
for _, v in pairs(interface_pn or {}) do
    if v.path then
        dnsservers_paths[#dnsservers_paths + 1] = v.path .. "dnsservers"
    end
end

local dns_rpc_content = proxy.get(unpack(dnsservers_paths)) -- use unpack for get() compatibility
local dns_count = 0
for _, v in pairs (dns_rpc_content or {}) do
   if v and v.value ~= "" then
      local subcount = split(format("%s",v.value),",")
      dns_count = dns_count + #subcount
   end
end

local dosprotect = proxy.get("uci.dosprotect.globals.enabled") and proxy.get("uci.dosprotect.globals.enabled")[1].value or "0"
local flowcache = proxy.get("uci.fcctlsettings.state.enabled") and proxy.get("uci.fcctlsettings.state.enabled")[1].value or "0"

local flowcache_status , dosprotect_status

if dosprotect and dosprotect == "1" then
    dosprotect_status = T"DoS Protect enabled"
else
    dosprotect_status = T"DoS Protect disabled"
end

if flowcache and flowcache == "1" then
    flowcache_status = T"Flow Cache enabled"
else
    flowcache_status = T"Flow Cache disabled"
end

  ngx.print('\
\
<div class="span3">\
    <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
        ');  ngx.print( ui_helper.createCardHeader(T"IP Extras", "/modals/iproutes-modal.lp") ); ngx.print('\
        <div class="content card_bg" data-bg-text="&#xf018;">\
		<div class="divtable">\
            <span class="simple-desc">\
            <i class="fas fa-exchange-alt" aria-hidden="true" href="#">&nbsp</i>\
              ');  
            local modal_link=format('class="modal-link" data-toggle="modal" data-remote="%s" data-id="device-modal"',modalPath)
            ngx.print(
            format( N('<strong %1$s>%2$d Route</strong>',
                      '<strong id="iproutescard_noofroutes" %1$s>%2$d Routes</strong> ', dyn_count),
                      modal_link, dyn_count))
              ngx.print('\
            </span>\
            <span class="simple-desc">\
            ');  
            ngx.print(
           '<i class="fas fa-server" aria-hidden="true" href="#">&nbsp</i>' .. format( N('<strong %1$s>%2$d DNS Server</strong>',
                      '<strong id="iproutescard_dnsservers" %1$s>%2$d DNS Servers</strong>', dns_count),
                      modal_link, dns_count))
              ngx.print('\
            </span>\
			')
			local subinfo_light = {
				span = {
					style = "font-weight: bold;"
				}
			}
			ngx.print( ui_helper.createSimpleLight(dosprotect, dosprotect_status, subinfo_light,"fa fas fa-exchange-alt") )
			ngx.print( ui_helper.createSimpleLight(flowcache, flowcache_status, subinfo_light,"fa fas fa-exchange-alt") )
			ngx.print('\
         </div>\
		 </div>\
\
    </div>\
</div>\
');  
end
  ngx.print('\
'); 
