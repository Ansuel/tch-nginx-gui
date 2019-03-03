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
	dch[#dch+1] =   '<div class="smallcard" data-aos="fade-up" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">'
	dch[#dch+1] =     '<div class="header">'
	dch[#dch+1] =		'<div data-toggle="modal" class="header-title pull-left" data-remote="'..modalPath..'">'
	dch[#dch+1] =		  '<p id="Load_tab">Loading...</p>'
	dch[#dch+1] =		'</div>'
	dch[#dch+1] =		'<div class="header-items">'
	dch[#dch+1] =			'<i class="fa fa-sync fa-spin"></i>'
	dch[#dch+1] =		'</div>'
	dch[#dch+1] =	  '</div>'
	dch[#dch+1] =   '</div>'
	dch[#dch+1] = '</div>'
	dch[#dch+1] = '<script>\
					$("document").ready(function() { \
					    $.get("/ajax/get_card.lua?modal='..modalPath..'", function (data) {\
					      $("#'..counter..'_card").replaceWith(data);\
					    });\
					  });\
				   </script>'
	return dch 

end

ngx.print('\
 <div class="feedback">\
\
  </div>\
	<div id="dynamic-content">\
      <div id="cardrow" class="row">\
	  ');
		lp.setpath("/www/gateway-snippets/")
		lp.include("js-after-header.lp")
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
	</div>\
<script>\
AOS.init();\
$(document).ready(function () {\
	$("#refresh-cards").hide();\
});\
</script>\
');
