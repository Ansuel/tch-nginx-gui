--pretranslated: do not change this file
 
-- Enable localization

local content_helper = require("web.content_helper")
local session = ngx.ctx.session

local lp = require("web.lp")

local cui = {
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_skin = "uci.env.var.gui_skin",
}
content_helper.getExactContent(cui)

local rightcard = {}

local leftcard = {}

ngx.print('\
<div id="dynamic-content">\
  <div id ="infocardrow" class="row">\
')
lp.setpath("/www/info-cards/")
       local cards = require("cards")
	cards.setpath("/www/info-cards/")
       for n,card in pairs(cards.cards()) do
         if not ( n % 2 == 0 ) then
		 	table.insert(leftcard,card)
		 else
		 	table.insert(rightcard,card)
		 end
       end
	
	ngx.print( '<div id="leftinfocard">' )
	for _,card in pairs(leftcard) do
		lp.include(card)
	end
	ngx.print( '</div>' )
	ngx.print( '<div id="rightinfocard">' )
	for _,card in pairs(rightcard) do
		lp.include(card)
	end
	ngx.print( '</div>' )

ngx.print('\
  </div>\
</div>\
<script>\
AOS.init();\
\
$(document).ready(function () {\
	$("#refresh-cards").hide();\
});\
</script>\
')