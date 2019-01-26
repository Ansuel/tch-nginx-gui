--pretranslated: do not change this file
 
-- Enable localization

local content_helper = require("web.content_helper")

local lp = require("web.lp")

local firstpage

local cui = {
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_skin = "uci.modgui.var.gui_skin",
	firstpage = "uci.modgui.var.firstpage",
}
content_helper.getExactContent(cui)

if cui.firstpage == "stats" then
	firstpage = "stats.lp"
elseif cui.firstpage == "telstra" then
	firstpage = "telstra-gui.lp"
else
	firstpage = "cards.lp"
end

	lp.setpath("/www/gateway-snippets/")
if not firstpage:match("telstra") then
	lp.include("head-js-css.lp")

  ngx.print('\
<body>\
');
	lp.setpath("/www/gateway-snippets/")
	lp.include("header.lp")
end
	lp.include(firstpage)

if not firstpage:match("telstra") then
	lp.setpath("/www/gateway-snippets/")
	lp.include("footer.lp")
	
ngx.print('\
</body>\
</html>\
');
end