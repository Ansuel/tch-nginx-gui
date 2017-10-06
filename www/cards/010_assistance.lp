<%
-- The card is shown, even if the modal is not accessible
-- NG-74016 assistance card hidden for admin
gettext.textdomain('webui-core')

local modal = '/modals/assistance-modal.lp'

local format = string.format

local session = ngx.ctx.session
local admin = session:hasAccess(modal)

local ui_helper = require 'web.ui_helper'

local assistance = require 'web.assistance'
local assistant = assistance.getAssistant('remote')

if assistant then
    local content
    local state
    if assistant:enabled() then
        state = "1"
        local light = ui_helper.createSimpleLight(state, T"Enabled", { light = { id =  "Assistance_LEDStatus" }, span = { id =  "Assistance_Status" } })
        if admin then
            local url = assistant:URL()
            if url then
                content = {
                    light,'<br/>',
                    T"URL:",format(' <strong id="port">%s</strong>', url),'<br/>',
                    T"Username:",format(' <strong id="username">%s</strong>', assistant:username()),"<br/>",
                    T"Password:", format(' <strong id="password">%s</strong>', assistant:password()),
                }
            else
                content = {
                    light, '<br/>',
                    T"There is no connection to the Internet."
                }
            end
        else
            content = {light}
        end
    else
        state = "0"
        content = {
            ui_helper.createSimpleLight(state, T"Disabled", { light = { id =  "Assistance_LEDStatus" }, span = { id =  "Assistance_Status" } })
        }
    end
	if session:hasAccess(modal) then
%>

<div class="span3">
  <div class="smallcard">
    <% if admin then
        ngx.print(ui_helper.createCardHeader(T"Assistance", modal))
    else
        ngx.print(ui_helper.createCardHeader(T"Assistance"))
    end %>
    <div class="content card_bg" data-bg-text="&#xf1cd;">
	<div class="divtable">
        <%= content %>
	</div>
    </div>
  </div>
</div>
<% end 
end
%>
