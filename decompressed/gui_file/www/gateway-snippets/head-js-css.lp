--pretranslated: do not change this file
 
-- Enable localization

local content_helper = require("web.content_helper")
local session = ngx.ctx.session

local cui = {
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_skin = "uci.modgui.gui.gui_skin",
	gui_version = "uci.modgui.gui.gui_version",
	gui_animation = "uci.modgui.gui.gui_animation",
}
content_helper.getExactContent(cui)

ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
  <head>\
    <title>');  ngx.print( T"Gateway" ); ngx.print('</title>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( session:getCSRFtoken() ); ngx.print('">\
    <meta name="Advanced" content="');  ngx.print( cui.advanced ); ngx.print('">\
	<link href="/css/font-awesome-all-5.7.2.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
    <link href="/css/gw.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
	<link id="theme_skin" rel="stylesheet" href="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/style.css?version='); ngx.print(cui.gui_version); ngx.print('">\
	<link rel="shortcut icon"    type="image/x-icon"   href="/img/favicon.ico"    />\
    <link href="/css/responsive.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
	<!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css?version='); ngx.print(cui.gui_version); ngx.print('"><![endif]-->\
    <!--[if lt IE 9]> <script src="/js/media-min.js?version='); ngx.print(cui.gui_version); ngx.print('"></script> <![endif]-->')
	if cui.gui_animation == "1" then
		ngx.print('<link rel="stylesheet" href="/css/aos.css?version='); ngx.print(cui.gui_version); ngx.print('" >')
	end
	ngx.print('\
	<script src="/js/jquery.min.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>\
	<script src="/js/main-min-nojquery.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>\
	<script src="js/knockout-min.js?version='); ngx.print(cui.gui_version); ngx.print('"></script>')
	if cui.gui_animation == "1" then
		ngx.print('<script src="/js/aos.js?version='); ngx.print(cui.gui_version); ngx.print('"></script>')
	end
	ngx.print('\
	<script src="/js/Chart.bundle.min.js?version='); ngx.print(cui.gui_version); ngx.print('"></script>\
	<script async src="/js/srp-min.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>');
	--ngx.print('<script src="/js/jquery-migrate.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>')  -- Usefull to debug deprecated function from jquery update
	local script_file_presence = io.open(string.format("/www/docroot/theme/%s/script.js",cui.gui_skin),"r")
	if script_file_presence then
		ngx.print('<script src="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/script.js?version='); ngx.print(cui.gui_version); ngx.print('"></script>');
		script_file_presence:close()
	end
ngx.print('\
  </head>\
')