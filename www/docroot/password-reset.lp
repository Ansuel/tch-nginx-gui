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
  }

content_helper.getExactContent(cui)
  ngx.print('\r\
<!DOCTYPE HTML>\r\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\r\
<head>\r\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\r\
    <meta charset="UTF-8">\r\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\r\
    <link href="/css/gw.css" rel="stylesheet">\r\
    <link href="/css/responsive.css" rel="stylesheet">\r\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\r\
    <script src="/js/main-min.js" ></script>\r\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\r\
    <script src="/js/srp-min.js" ></script>\r\
    <title>');  ngx.print( T"Login" ); ngx.print('</title>\r\
</head>\r\
<body>\r\
  <div class="container">\r\
    <div class="logo-technicolor"><a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank"><img src="/img/logo.gif"></a></div>\r\
    <div class="row">\r\
      <div class="offset4 span4">\r\
	<div class="login">\r\
        <form class="form-horizontal" id = "password_reset" method = "post" action = "/password-reset.lp">\r\
          <input type = "hidden" name = "CSRFtoken" value = "');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('"/>\r\
          <input type = "hidden" id = "action" name = "action" value = "reset"/>\r\
          <fieldset>\r\
                <h2>');  ngx.print(T"Reset Password" ); ngx.print('</h2>\r\
            <div class="control-group">\r\
			<label for="srp_password2" class="alert-info">');  ngx.print(T'Select the <strong>"Reset"</strong> button to confirm resetting the password to the default value.'); ngx.print('</label>\r\
            </div>\r\
            <div class="pull-right">\r\
                <a href="#" class="btn btn-primary btn-large" id ="btn_cancel" >');  ngx.print( T"Cancel" ); ngx.print('</a>\r\
                &nbsp;\r\
                <div id="btn_reset" class="btn btn-primary btn-large">');  ngx.print(T"Reset" ); ngx.print('</div>\r\
            </div>\r\
          </fieldset>\r\
        </form>\r\
      </div>\r\
      </div>\r\
	  </div>\r\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor 2015</p></div></div>\r\
  </div>\r\
<script>\r\
  $(document).ready(function(){\r\
    $("#btn_cancel").click(function(){\r\
      $("#action").val("cancel");\r\
      $("#password_reset").submit();\r\
    });\r\
     $("#btn_reset").click(function(){\r\
       $("#password_reset").submit();\r\
    });\r\
  });\r\
</script>\r\
</body>\r\
</html>\r\
'); 