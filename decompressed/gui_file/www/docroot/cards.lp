--pretranslated: do not change this file
 
-- Enable localization

local content_helper = require("web.content_helper")
local session = ngx.ctx.session

local lp = require("web.lp")

local firstpage

local contentonly

local cui = {
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_skin = "uci.env.var.gui_skin",
}
content_helper.getExactContent(cui)

if ngx.req.get_method() == "GET" then
	contentonly = ngx.req.get_uri_args().contentonly or false
end

if not contentonly then --Fix: Load content only if the entire page is need (loads workaround)
ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( session:getCSRFtoken() ); ngx.print('">\
    <meta name="Advanced" content="');  ngx.print( cui.advanced ); ngx.print('">\
	<link href="/css/font-awesome-all-5.1.0.css" rel="stylesheet">\
    <link href="/css/gw.css" rel="stylesheet">\
	<link rel="shortcut icon"    type="image/x-icon"   href="/img/favicon.ico"    />\
    <link href="/css/responsive.css" rel="stylesheet">\
	<!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
	<link rel="stylesheet" href="/css/aos.css" >\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <title>');  ngx.print( T"Gateway" ); ngx.print('</title>\
	<script src="/js/jquery.min.js" ></script>\
	<script src="/js/main-min-nojquery.js" ></script>\
	<script src="js/knockout-min.js"></script>\
	<script src="/js/aos.js"></script>\
	<script src="/js/Chart.bundle.min.js"></script>\
	<script async src="/js/srp-min.js" ></script>');
	ngx.print('<script src="/js/jquery-migrate.js" ></script>')  -- Usefull to debug deprecated function from jquery update
	ngx.print('<link rel="stylesheet" href="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/style.css">');
local script_file_presence = io.open(string.format("/www/docroot/theme/%s/script.js",cui.gui_skin),"r")
if script_file_presence then
	ngx.print('<script src="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/script.js"></script>');
end
  ngx.print('</head>\
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