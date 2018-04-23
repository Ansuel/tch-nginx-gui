<%
-- Enable localization
-- NG-70799
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")

local imh = require("internetmode_helper")

local tabdata = dyntab_helper.process(imh)

local mode_current = tabdata.current.name
local mode_options = tabdata.options

local bridgemode = require("bridgedmode_helper")
local voicemode = require("voicemode_helper")

local session = ngx.ctx.session
local tech = false
if session:getrole() == "engineer" then
   tech = true
end

local wan_ppp_ll_intf = proxy.get("rpc.network.interface.@wan.ppp.ll_intf")[1].value
local wan_ppp_over_atm = proxy.get(string.format("uci.xtm.atmdevice.@%s.", wan_ppp_ll_intf)) ~= nil
if not wan_ppp_over_atm then
   for k,v in ipairs(mode_options) do
       if v[1] == "pppoa" then
           table.remove(mode_options, k)
           break
       end
   end
end


%>

<%
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
%>
<%
-- Currently, the only advanced field is the conncection mode.
-- So if it's not included, there's no need for an advanced button.
ngx.print(ui_helper.createHeader(T"Internet Access", tech, true))
%>

<div class="modal-body update">
<form class="form-horizontal" method="post" action="modals/internet-modal.lp">
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>

<fieldset id="conn_mode" class="advanced hide">
<legend><%= T"Connection mode" %></legend>

<%
	if tech then
    local html = {}

    local mode_attributes = {
        radio = {
            class = "inline"
        },
        input = {
            class = "no-save",
            ["data-for"] = "SWITCH_MODE",
        }
    }
    local mode_button = {
        button = {
            ["data-name"] = "action",
            ["data-value"] = "SWITCH_MODE",
        }
    }
	
    html[#html+1] = ui_helper.createInputRadio(T"Mode", "newmode", mode_options, mode_current, mode_attributes)
    html[#html+1] = ui_helper.createButton("", T"Switch connection mode", "icon-cog", mode_button)

    ngx.print(html)
	end
%>
</fieldset>

<% end %>
<%
    lp.setpath("/www/snippets/")
    lp.include(tabdata.current.view)
%>

<%
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
%>

</form>
</div>

<% ngx.print(ui_helper.createFooter()) %>

<% end %>
