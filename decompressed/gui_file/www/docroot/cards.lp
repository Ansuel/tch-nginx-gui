--pretranslated: do not change this file
 
-- Enable localization

local lp = require("web.lp")

local contentonly

if ngx.req.get_method() == "GET" then
	contentonly = ngx.req.get_uri_args().contentonly or false
end

if not contentonly then --Fix: Load content only if the entire page is need (loads workaround)

	lp.setpath("/www/gateway-snippets/")
	lp.include("head-js-css.lp")

  ngx.print('\
<body>\
');

lp.setpath("/www/gateway-snippets/")
lp.include("header.lp")
end

	lp.setpath("/www/gateway-snippets/")
	lp.include("cards.lp")

if not contentonly then

lp.setpath("/www/gateway-snippets/")
lp.include("footer.lp")
	
ngx.print('\
</body>\
</html>\
');
end