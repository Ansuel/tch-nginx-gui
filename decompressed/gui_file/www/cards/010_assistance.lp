--pretranslated: do not change this file

-- The card is shown, even if the modal is not accessible
-- NG-74016 assistance card hidden for admin
gettext.textdomain('webui-core')

local modal = '/modals/assistance-modal.lp'
local attributes = { light = { id =  "Assistance_LEDStatus" }, span = { id =  "Assistance_Status" } }
local format = string.format

local session = ngx.ctx.session

local ui_helper = require 'web.ui_helper'

local assistance = require 'web.assistance'
local assistant = assistance.getAssistant('remote')

local assistant_state_light = assistant:enabled() and "1" or "0"
local assistant_state = assistant:enabled() and T"Enabled" or T"Disabled"
local url = assistant:URL() or nil

local modal_link = nil

if session:hasAccess(modal) then
	modal_link = modal
end

ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
  ');
    ngx.print(ui_helper.createCardHeader(T"Assistance", modal_link)); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf1cd;">\
	<div class="divtable">\
	')
		local html = {}
		html[#html+1] = ui_helper.createSimpleLight(assistant_state_light, assistant_state, attributes ,"fas fa-hands-helping")
        html[#html+1] = '<p class="subinfos">'
		if url then
            html[#html+1] = T"URL:" .. format(' <strong id="port">%s</strong>', url)
			html[#html+1] = '<br/>'
            html[#html+1] = T"Username:" .. format(' <strong id="username">%s</strong>', assistant:username())
			html[#html+1] = '<br/>'
			local assist_password = assistant:password()
			if assist_password ~= "" then
				html[#html+1] = T"Password:" .. format(' <strong id="password">%s</strong>', assist_password)
			end
        elseif assistant:enabled() then
            html[#html+1] = T"There is no connection to the Internet."
        end
		html[#html+1] = '</p>'
		ngx.print(html)
	ngx.print('\
	</div>\
    </div>\
  </div>\
</div>\
');
