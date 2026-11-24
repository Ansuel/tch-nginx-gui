--pretranslated: do not change this file

local lp = require("web.lp")
local content_helper = require("web.content_helper")

gettext.textdomain("webui-core")

local cui = {
	gui_skin = "uci.modgui.gui.gui_skin",
}

content_helper.getExactContent(cui)

local function escape(value)
	return string.untaint(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

-- dch = dummy_card_html VARIABLE TOO LONG... 
local function gen_dummy_card(modalPath)
	
	if not modalPath then
		return {}
	end
	
	local dch = {}
	
	modalPath = escape(modalPath)
	dch[#dch+1] = '<div class="span3" data-card-modal="'..modalPath..'">'
	dch[#dch+1] =   '<div class="smallcard">'
	dch[#dch+1] =     '<div class="header">'
	dch[#dch+1] =		'<div data-toggle="modal" class="header-title pull-left" data-remote="'..modalPath..'">'
	dch[#dch+1] =		  '<p>'..escape(T"Loading...")..'</p>'
	dch[#dch+1] =		'</div>'
	dch[#dch+1] =	  '</div>'
	dch[#dch+1] =	  '<div class="content card_bg" data-bg-text="&#xf021;">'
  	dch[#dch+1] =	  	'<div class="divtable">'
    dch[#dch+1] =	  		'<div class="spinner3"><div class="rect1"></div><div class="rect2"></div><div class="rect3"></div><div class="rect4"></div><div class="rect5"></div></div>'
  	dch[#dch+1] =	  	'</div>'
	dch[#dch+1] =	  '</div>'
	dch[#dch+1] =   '</div>'
	dch[#dch+1] = '</div>'
	return dch 

end

local load_async = not string.untaint(cui.gui_skin):match("Fritz")
ngx.print('<div class="row dynamic-content" id="cardrow"')
if load_async then
	ngx.print(' data-card-error-title="', escape(T"Error"),
		'" data-card-timeout="', escape(T"The server timed out waiting for the request"),
		'" data-card-error="', escape(T"The request could not be performed due to some error"), '"')
end
ngx.print('>')
lp.setpath("/www/cards/")
local cards = require("cards")
for _, card in ipairs(cards.cards()) do
	if load_async then
		ngx.print(gen_dummy_card(cards.get_modal_from_card(card)))
	else
		lp.include(card)
	end
end
if load_async then
	ngx.print('<script>window.modguiLoadDashboardCards(document.getElementById("cardrow"));</script>')
end
ngx.print('</div>')
