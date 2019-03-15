--pretranslated: do not change this file

local content_helper = require("web.content_helper")
local error

local session =  ngx.ctx.session

local status , err

if ngx.req.get_method() == "GET" then
	err = ngx.req.get_uri_args().err
	status = tonumber(ngx.req.get_uri_args().status)
end

local cui = {
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_skin = "uci.modgui.gui.gui_skin",
	gui_version = "uci.modgui.gui.gui_version",
}

content_helper.getExactContent(cui)

local error_code = {
	[403] = "FORBIDDEN",
	[500] = "INTERNAL_SERVER_ERROR",
	[200] = "HTTP_OK",
	[404] = "NOT_FOUND",
}

if session and not err then
	status = 500
	err = session:retrieve("lasterr")
end

if not err then
	err = ngx.header.error_msg or ""
end

if not status then
	status = ngx.status or 200
end

local status_detail = error_code[status]

if not status_detail then
	status_detail = "UNKNOWN"
end

ngx.print('\
<!DOCTYPE HTML>\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">\
    <meta charset="UTF-8">\
    <meta name="Advanced" content="');  ngx.print( cui.advanced ); ngx.print('">\
	<link href="/css/font-awesome-all-5.7.2.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
    <link href="/css/gw.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
	<link rel="shortcut icon"    type="image/x-icon"   href="/img/favicon.ico"    />\
    <link href="/css/responsive.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
	<!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css?version='); ngx.print(cui.gui_version); ngx.print('"><![endif]-->\
	<link rel="stylesheet" href="/css/aos.css?version='); ngx.print(cui.gui_version); ngx.print('" >\
    <!--[if lt IE 9]> <script src="/js/media-min.js?version='); ngx.print(cui.gui_version); ngx.print('"></script> <![endif]-->\
    <title>');  ngx.print( "Gateway" ); ngx.print('</title>\
	<script src="/js/jquery.min.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>\
	<script src="/js/main-min-nojquery.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>\
	<script async src="/js/srp-min.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>');
	--ngx.print('<script src="/js/jquery-migrate.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>')  -- Usefull to debug deprecated function from jquery update
	ngx.print('<link rel="stylesheet" href="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/style.css?version='); ngx.print(cui.gui_version); ngx.print('">');
local script_file_presence = io.open(string.format("/www/docroot/theme/%s/script.js",cui.gui_skin),"r")
if script_file_presence then
	ngx.print('<script src="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/script.js?version='); ngx.print(cui.gui_version); ngx.print('"></script>');
end
ngx.print('\
  </head>\
<div class="container">\
<div class="row">\
      <div class="span6" id="error-card">\
        <div class="login">\
          <form class="form-horizontal">\
		    <div class="login_bg" data-bg-text="&#xf071;">\
		      <div style="z-index : 2;  position: relative;">\
                <fieldset>\
                      <h2>'); ngx.print("Error "..status.." : "..status_detail); ngx.print('</h2>\
                  <div class="control-group">\
				  '); ngx.print(err); ngx.print('\
                  </div>\
				  <div class="pull-right">\
		    	  	</div>\
		    	  </div>\
                </fieldset>\
		      </div>\
		    </div>\
          </form>\
		   <a href="/" class="btn btn-primary btn-large">');  ngx.print( "Go Back" ); ngx.print('</a>\
	    </div>\
      </div>\
	</div>\
	</div>\
<script>\
$(document).ready(\
	$(".btn-primary").on("click", function() {\
		window.location = "/";\
	})\
)\
</script>\
');

