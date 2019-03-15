--pretranslated: do not change this file

local lp = require("web.lp")
local cards = require("cards")

local rightcard = {}

local leftcard = {}

ngx.print('\
<div class="dynamic-content row" id="infocardrow" >\
	')
	lp.setpath("/www/info-cards/")
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
')
