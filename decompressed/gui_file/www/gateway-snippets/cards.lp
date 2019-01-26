--pretranslated: do not change this file
 
-- Enable localization
--NG-56120, NG-56248, NG-77544
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local web = require("web.web")
local session = ngx.ctx.session
local proxy = require("datamodel")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')
local session = ngx.ctx.session

local lp = require("web.lp")

local cui = {
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_skin = "uci.modgui.gui.gui_skin",
}
content_helper.getExactContent(cui)

ngx.print('\
 <div class="feedback">\
\
  </div>\
	<div id="dynamic-content">\
      <div id="cardrow" class="row">\
	  ');
	  	lp.setpath("/www/cards/")
          local cards = require("cards")
          for _,v in pairs(cards.cards()) do
					lp.include(v)
			
          end
          ngx.print('\
      </div>\
	</div>\
<script>\
AOS.init();\
$(document).ready(function () {\
	$("#refresh-cards").hide();\
});\
</script>\
');
