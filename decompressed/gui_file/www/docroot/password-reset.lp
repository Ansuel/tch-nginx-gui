--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')


local content_helper = require("web.content_helper")
local proxy = require("datamodel")

if ngx.var.request_method == "POST" then
  if ngx.req.get_post_args().action == "reset" then
    local success, msg = proxy.set("rpc.forgotpassword.trigger", "1")
    if success then
      proxy.apply();
    end
  end
  ngx.ctx.session:logout()
  ngx.redirect("/")
end

local cui = {
    defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    timestamp = "uci.version.version.@version[0].timestamp",
  }

content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year,1,4))

  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
<head>\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <link href="/css/gw.css" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <script src="/js/srp-min.js" ></script>\
    <title>');  ngx.print( T"Login" ); ngx.print('</title>\
</head>\
<body>\
  <div class="container">\
    <div class="logo-technicolor">\
	<a href="'); ngx.print(cui.nsplink); ngx.print('" target="_blank">\
	  <picture>');
		if cui.gui_skin == "TIM" then
			ngx.print('<img width="168px" height="39px" src="/img/TIM.png">');
		elseif cui.gui_skin == "Fritz" or string.match(cui.gui_skin, "[dD][aA][rR][kK]") then
			ngx.print('<source srcset="/img/logo_white.webp" type="image/webp">\
				<source srcset="/img/logo_white.png" type="image/png">\
				<img width="131px" height="50px" src="/img/logo_white.png">');
		else
			ngx.print('<source srcset="/img/logo.webp" type="image/webp">\
				<source srcset="/img/logo.png" type="image/png">\
				<img width="131px" height="50px" src="/img/logo.png">');
		end
	  ngx.print('  </picture>\
	</a>\
	</div>\r\
     <div class="row">\
      <div class="offset4 span4">\
	<div class="login">\
        <form class="form-horizontal" id = "password_reset" method = "post" action = "/password-reset.lp">\
          <input type = "hidden" name = "CSRFtoken" value = "');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('"/>\
          <input type = "hidden" id = "action" name = "action" value = "reset"/>\
          <fieldset>\
                <h2>');  ngx.print(T"Reset Password" ); ngx.print('</h2>\
            <div class="control-group">\
			<label for="srp_password2" class="alert-info">');  ngx.print(T'Select the <strong>"Reset"</strong> button to confirm resetting the password to the default value.'); ngx.print('</label>\
            </div>\
            <div class="pull-right">\
                <a href="#" class="btn btn-primary btn-large" id ="btn_cancel" >');  ngx.print( T"Cancel" ); ngx.print('</a>\
                &nbsp;\
                <div id="btn_reset" class="btn btn-primary btn-large">');  ngx.print(T"Reset" ); ngx.print('</div>\
            </div>\
          </fieldset>\
        </form>\
      </div>\
      </div>\
	  </div>\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
  </div>\
<script>\
  $(document).ready(function(){\
    $("#btn_cancel").click(function(){\
      $("#action").val("cancel");\
      $("#password_reset").submit();\
    });\
     $("#btn_reset").click(function(){\
       $("#password_reset").submit();\
    });\
  });\
</script>\
</body>\
</html>\
'); 
