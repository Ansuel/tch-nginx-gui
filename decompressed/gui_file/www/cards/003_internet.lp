--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local format = string.format
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local untaint_mt = require("web.taint").untaint_mt

-- Process the selected mode if any
local imh = require("internetmode_helper")

local mode_data = {}
local mode_default = "" -- the default mode to use
local mode_active = ""  -- the mode currently in use (mode_default if not set)
for _,v in ipairs(imh) do
    mode_data[v.name] = v
    if v.default == true then
        mode_default = v.name
    end
end
mode_data = setmetatable(mode_data, untaint_mt)

local mode_active = "default"
local content_mode = {
    mode_active = "uci.network.config.wan_mode",
    wan_proto = "uci.network.interface.@wan.proto",
    wwan_up = "rpc.network.interface.@wwan.up",
}
content_helper.getExactContent(content_mode)
if content_mode.mode_active ~= "" then
    -- Get current mode by 'wan_mode'
    mode_active = content_mode.mode_active
elseif content_mode.wan_proto ~="" then
    --'wan_mode' not there, then get @wan.proto
    mode_active = content_mode.wan_proto
end

local mobile_ip
if content_mode.wwan_up == "1" then
    local content_mobile = {
	ipaddr = "rpc.network.interface.@wwan.ipaddr",
	ip6addr = "rpc.network.interface.@wwan.ip6addr",
    }
    content_helper.getExactContent(content_mobile)
    if content_mobile.ipaddr ~= "" then
        mobile_ip = content_mobile.ipaddr
    elseif content_mobile.ip6addr ~= "" then
        mobile_ip = content_mobile.ip6addr
        local count = 0
        mobile_ip = mobile_ip:gsub("(:)", function(str)
            count = count + 1
            if count == 3 then
                return "- :"
            end
        end)
    end
end

-- Display the card but do not give access if not allowed
local switchName = nil
local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    switchName = "uci_wan_auto"
    modalPath = "/modals/internet-modal.lp"
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print( ui_helper.createCardHeader(T"Internet Access", modalPath) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf0ac;">\
      <div class="divtable">\
');  
    lp.setpath("/www/cards/snippets/")
    lp.include(mode_data[mode_active].card)
    -- have to bring it back to original value ... singleton
    lp.setpath("/www/cards/")
    if mobile_ip then
        ngx.print(ui_helper.createSimpleLight(content_mode["wwan_up"], "Mobile Internet connected"),
         '<p class="subinfos">',
           format(T'WAN IP is <strong>%s</strong>', mobile_ip),
         '</p>'
        )
    end
  ngx.print('\
      </div>\
    </div>\
  </div>\
</div>\
'); 
