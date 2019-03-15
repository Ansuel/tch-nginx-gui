--pretranslated: do not change this file

local lp = require("web.lp")
local content_helper = require("web.content_helper")

local cui = {
	gui_skin = "uci.modgui.gui.gui_skin",
}

content_helper.getExactContent(cui)

local counter = 0

-- dch = dummy_card_html VARIABLE TOO LONG... 
local function gen_dummy_card(modalPath)

	local dch = {}
	
	counter = counter+1
	
	dch[#dch+1] = '<div class="span3" id="'..counter..'_card">'
	dch[#dch+1] =   '<div class="smallcard">'
	dch[#dch+1] =     '<div class="header">'
	dch[#dch+1] =		'<div data-toggle="modal" class="header-title pull-left" data-remote="'..modalPath..'">'
	dch[#dch+1] =		  '<p id="Load_tab">Loading...</p>'
	dch[#dch+1] =		'</div>'
	dch[#dch+1] =	  '</div>'
	dch[#dch+1] =	  '<div class="content card_bg" data-bg-text="&#xf021">'
  	dch[#dch+1] =	  	'<div class="divtable">'
    dch[#dch+1] =	  		'<div class="spinner3"><div class="rect1"></div><div class="rect2"></div><div class="rect3"></div><div class="rect4"></div><div class="rect5"></div></div>'
  	dch[#dch+1] =	  	'</div>'
	dch[#dch+1] =	  '</div>'
	dch[#dch+1] =   '</div>'
	dch[#dch+1] = '<script>\
					    $.get("/ajax/get_card.lua?modal='..modalPath..'").done(function (data) {\
					      $("#'..counter..'_card").replaceWith(data);\
					    }).fail(function (data) {\
					      $("#'..counter..'_card").find(".divtable").html(\'Error \'+data.status+$(data.responseText).find(".control-group").html());\
					    });\
				   </script>'
	dch[#dch+1] = '</div>'
	return dch 

end

ngx.print('\
	<div class="row dynamic-content" id="cardrow" >\
	  ');
	  	lp.setpath("/www/cards/")
        local cards = require("cards")
        for _,v in pairs(cards.cards()) do
			if not string.untaint(cui.gui_skin):match("Fritz") then
				ngx.print(gen_dummy_card(cards.get_modal_from_card(v)))
			else
				lp.include(v)
			end
		end
        ngx.print('\
    </div>\
');
