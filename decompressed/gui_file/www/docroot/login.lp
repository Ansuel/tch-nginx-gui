--pretranslated: do not change this file
 
		  
-- Enable localization
-- NG-58110
-- NG-78957
-- GHG-3791  Implemented Custo changes based on new baseline 17.3-238
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local triesbeforemsg = 3
local content_helper = require("web.content_helper")
local proxy = require("datamodel") -- Custo
local format = string.format
local passwd_count_msg = format(T"You are trying to login with wrong password for %s times", '<span id="pwdCount"></span>')
local timer_msg = format(T"Please wait %s seconds to enter new password", '<span id="timerSec"></span>')

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "getcsrf" then
  ngx.print(ngx.ctx.session:getCSRFtoken())
  ngx.exit(ngx.HTTP_OK)
end

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  timestamp = "uci.version.version.@version[0].timestamp",
  gui_version = "uci.env.var.gui_version",
  gui_skin = "uci.env.var.gui_skin",
}
content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year,1,4))
local users = content_helper.getMatchedContent("uci.web.user.")
local userNames = ""
local legacySalts = ""

local httpi = proxy.get("rpc.network.interface.@wan.up")

if httpi and httpi[1].value then
	httpi = httpi[1].value
else
	httpi = ""
end

local httpi_wwan = proxy.get("rpc.network.interface.@wwan.up")

if httpi_wwan and httpi_wwan[1].value then
	httpi_wwan = httpi_wwan[1].value
else
	httpi_wwan = ""
end

local wan_sensing = proxy.get("uci.wansensing.global.enable")

if wan_sensing and wan_sensing[1].value then
	wan_sensing = wan_sensing[1].value
else
	wan_sensing = ""
end

local assistance_port = proxy.get("uci.web.assist_state.@state_remote.port")

if assistance_port and not  ( assistance_port[1].value == "" ) then
	assistance_port = assistance_port[1].value
else
	assistance_port = "0"
end


for _, v in ipairs(users) do
  if v.legacy_salt ~= "" then
    userNames = userNames .. v.name ..","
    legacySalts = legacySalts .. v.legacy_salt .. ","
  end
end

  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
<head>\
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
	<link href="/css/font-awesome-all-5.1.0.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
    <link href="/css/gw.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
    <link href="/css/responsive.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
	<link rel="shortcut icon"    type="image/x-icon"   href="/img/favicon.ico"/>');
	ngx.print('<link rel="stylesheet" href="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/style.css?version='); ngx.print(cui.gui_version); ngx.print('">\
	<link rel="stylesheet" href="/css/aos.css?version='); ngx.print(cui.gui_version); ngx.print('" >\
    <title>');  ngx.print( T"Login" ); ngx.print('</title>\
</head>'); 
ngx.print('\
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
	</div>\
	<div class="row">\
      <div class="span4" id="login-card">\
        <div class="login" data-aos="fade-right" data-aos-delay="200" data-aos-anchor-placement="top-center">\
          <form class="form-horizontal">\
		    <div class="login_bg" data-bg-text="&#xf023;">\
		      <div style="z-index : 2;  position: relative;">\
                <fieldset>\
                      <h2>');  ngx.print( T"Sign in" ); ngx.print('</h2>');
                      if httpi=="0" and httpi_wwan=="0" then
                      ngx.print('<div id="httpi" class="alert alert-error ">');
		    	  		if httpi=="0" and httpi_wwan=="0" and wan_sensing=="1" then
		    	  			ngx.print('<strong>'); ngx.print( T"You don't have internet access at this time" ); ngx.print('</strong>');
		    	  		end
		    	  		if httpi=="0" and httpi_wwan=="0" and wan_sensing=="0" then
		    	  			ngx.print('<strong>'); ngx.print( T"Your modem is in bridge mode. It only connect to DSLAM and nothings else." ); ngx.print('</strong>')
		    	  		end
                      ngx.print('</div>')
                      end
                  ngx.print('<div id="erroruserpass" class="alert alert-error hide">\
                     <strong>');  ngx.print( T"Invalid Username or Password" ); ngx.print('</strong>\
                  </div>\
                  <div class="control-group">\
                      <label for="srp_username"><div class="label-icon">\
                          <i class="icon-user icon-large"></i>\
                      </div></label>\
                      <input class="span3" type="text" placeholder="');  ngx.print( T"Your username" ); ngx.print('" id="srp_username" value="');  ngx.print( cui.defaultuser ); ngx.print('" autofocus><br><br>\
                  </div>\
                  <div class="control-group">\
                      <label for="srp_password"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                      <input class="span3" type="password" autocomplete="current-password" placeholder="');  ngx.print( T"Your password" ); ngx.print('" id="srp_password"><br><br>\
                  </div>\
                  <!-- HIDE WARNING - NOT NOT USED IN DEFAULT CUSTO\
                  <div id="defaultpassword" class="alert alert-info hide">\
                      ');  ngx.print( T"If you haven't changed it, the default password can be found on the sticker under your gateway (it's called <strong>\"access code\"</strong>)" ); ngx.print('\
                  </div>\
                  -->\
                  <div class="pull-right">\
                      <a id="sign-cancel" href="/" class="btn btn-primary btn-large">');  ngx.print( T"Cancel" ); ngx.print('</a>\
                      &nbsp;\
                      <div class="btn btn-primary btn-large">\
		    	  	  <span id="sign-me-in-icon"></span>\
		    	  	  <span id="sign-me-in">');  ngx.print( T"Sign in" ); ngx.print('</span>\
		    	  	</div>\
		    	  </div>\
                  <!--<div id="forgot-login-password">\
                      <a href="#">');  ngx.print(T"Forgot Login Password")  ngx.print('</a>\
                 </div>-->\
                </fieldset>\
		      </div>\
		    </div>\
          </form>\
	    </div>\
        <div class="login hide" id ="forgot-login">\
          <form class="form-horizontal">\
            <fieldset>\
              <h2>');  ngx.print(T"Reset Password")  ngx.print('</h2>\
              <div id="erroruserpass1" class="alert alert-error hide">\
                <strong>');  ngx.print(T"Invalid Password")  ngx.print('</strong>\
              </div>\
              <div class="control-group">\
                <label for="srp_password1" class="alert-info">');  ngx.print(T'Enter the default <strong>"access code"</strong>. This code is located on the label underneath your gateway.')  ngx.print('</label>\
                <label for="srp_password1"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                <input class="span3" type="password" placeholder="');  ngx.print(T"Your password")  ngx.print('" id="srp_password1"><br><br>\
              </div>\
              <div class="pull-right">\
                <a href="/" class="btn btn-primary btn-large">');  ngx.print( T"Cancel" )  ngx.print('</a>&nbsp;\
                <div id="verify-password" class="btn btn-primary btn-large">');  ngx.print( T"Verify" )  ngx.print('</div>\
              </div>\
            </fieldset>\
          </form>\
        </div>\
      </div>\
	</div>\
');
	local lp = require("web.lp")
    lp.setpath("/www/gateway-snippets/")
	lp.include("footer.lp")
ngx.print('\
</div>\
<div class="modal-fade hide" id="loginfailure" data-backdrop="static" role="dialog">\
     <div class="popUp smallcard popUp-modal span4" style="margin-top: -50px">\
       <div class="header"><div data-toggle="modal" class="header-title pull-left"><p>Processing</p></div></div>\
        <div class="modal-body no-padding">\
           <form class="form-horizontal">\
              <div>\
                 <label id="wronguser-attempt" for="inputPassword" class="control-label">');  ngx.print(passwd_count_msg); ngx.print('<br/>');  ngx.print(timer_msg); ngx.print('</label>\
              </div>\
              <div id="spinner" class="spinner" align="center">\
              <div class="spinner3">\
                <div class="rect1" style="background-color: rgb(92, 22, 96);"></div>\
                <div class="rect2" style="background-color: rgb(92, 22, 96);"></div>\
                <div class="rect3" style="background-color: rgb(92, 22, 96);"></div>\
                <div class="rect4" style="background-color: rgb(92, 22, 96);"></div>\
                <div class="rect5" style="background-color: rgb(92, 22, 96);"></div>\
              </div>\
             </div>\
           </form>\
        </div>\
      </div>\
  </div>\
<script src="/js/jquery.min.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>\
<!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css?version='); ngx.print(cui.gui_version); ngx.print('"><![endif]-->\
<script  language="JavaScript" type="text/javascript"   src="/js/main-min-nojquery.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>\
<!--[if lt IE 9]> <script src="/js/media-min.js?version='); ngx.print(cui.gui_version); ngx.print('"></script> <![endif]-->\
<script  language="JavaScript" type="text/javascript"   src="/js/srp-min.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>\
<script src="/js/aos.js?version='); ngx.print(cui.gui_version); ngx.print('"></script>');
local script_file_presence = io.open(string.format("/www/docroot/theme/%s/script.js",cui.gui_skin),"r")
if script_file_presence then
	ngx.print('<script src="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/script.js?version='); ngx.print(cui.gui_version); ngx.print('"></script>');
end
ngx.print('\
<script language="JavaScript" type="text/javascript">\
AOS.init();\
$(document).ready(\
  function() {\
    var triesbeforemsg = ');  ngx.print( triesbeforemsg ); ngx.print(';\
    var tries = 0;\
    var password = "";\
	var port = window.location.port || ( window.location.protocol === \'https:\' ? \'443\' : \'80\');\
	if ( port == '); ngx.print(assistance_port); ngx.print(' ) {\
		document.getElementById("srp_username").value = "assist";\
	}\
\
    // Set the focus on the first input field\
    $(\'form:first *:input[type!=hidden]:first\').focus();\
    // Handle press of enter. Could be handled by adding a hidden input submit but\
    // this requires a lot of css tweaking to get it right since display:none does\
    // not work on every browser. So go for the js way\
    $(\'form input\').keydown(function(e) {\
        if(e.which == 13 || e.which == 10) {\
            e.preventDefault();\
            $("#sign-me-in").click();\
        }\
    });\
\
    $("#sign-me-in").on("click", function () {\
	  $("#sign-cancel").hide();\
	  $("#sign-me-in-icon").show();\
	  $("#sign-me-in-icon").css("margin-right","5px");\
	  $("#sign-me-in-icon").addClass("fa fa-sync fa-spin");\
      $(this).text(\'');  ngx.print( T"Verifying" ); ngx.print('\');\
      password = $("#srp_password")[0].value;\
\
      //If the user has option legacy_salt, do migration\
      var legacySalts = "');  ngx.print( legacySalts ); ngx.print('";\
      var userNames = "');  ngx.print( userNames ); ngx.print('";\
      var inputUsername = $("#srp_username")[0].value;\
      var index = -1;\
      var userNameArray = userNames.split(",")\
      var legacySaltArray = legacySalts.split(",")\
	  var timesecond;\
\
      for (var i = 0; i < userNameArray.length - 1; i ++)\
      {\
         if ( inputUsername == userNameArray[i] )\
         {\
           index = i;\
         }\
      }\
      if (index >= 0)\
      {\
          var hashObj = new jsSHA((legacySaltArray[index]+tch.stringToHex(password)), "HEX");\
          password = hashObj.getHash("SHA-1", "HEX");\
      }\
\
      var srp = new SRP();\
      srp.success = function() {\
        // If we showed the login page using an internal redirect (detected\
        // by checking if the URL ends with "/login.lp") then we simply\
        // have to reload the page to get the actual page content now that\
        // we\'re logged in.\
        // Otherwise we explicitly go back to the main page.\
        if (window.location.pathname.search(/\\/login\\.lp$/) == -1){\
  		  var curl = window.location.href\
          window.location.href = curl.substring(0,curl.indexOf("#"));\
        }else\
          window.location = "/";\
      }\
      srp.error_message = function(err) {\
      if(err == 403){\
        $.get("login.lp", {action:"getcsrf"}, function (data){\
          $(\'meta[name=CSRFtoken]\').attr(\'content\', data);\
          if (!$("#loginfailure").is(":visible")) {\
            srp.identify("/authenticate", $("#srp_username")[0].value, password);\
          }\
        });\
      }else{\
        $("#sign-me-in").text(\'');  ngx.print( T"Sign in" ); ngx.print('\');\
        $("#erroruserpass").show();\
		$("#sign-cancel").show();\
		$("#sign-me-in-icon").show();\
		$("#sign-me-in-icon").addClass("fa-spin");\
		$("#sign-me-in-icon").toggle();\
        $(".control-group").addClass("error");\
      }\
      timeSecond = err.waitTime;\
      tries++;\
      if (timeSecond > 0 ) {\
        $("#timerSec").text(timeSecond);\
        $("#pwdCount").text(tries);\
        $(\'#loginfailure\').modal(\'show\');\
      }\
      updateWaitingTime();\
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {\
            $("#defaultpassword").show();\
        }\
      }\
      function updateWaitingTime() {\
        var timeInterval = setInterval(function() {\
          $("#timerSec").text(--timeSecond);\
          if (timeSecond <= 0) {\
            clearInterval(timeInterval);\
            $(\'#loginfailure\').modal(\'hide\');\
            $("#sign-me-in").removeAttr("disabled");\
          };\
        }, 1000);\
      }\
      if (!$("#loginfailure").is(":visible")) {\
        srp.identify("/authenticate", $("#srp_username")[0].value, password);\
      }\
    });\
    $("#forgot-login-password").on("click", "a", function(){\
      $("#login").hide();\
      $("#forgot-login").show();\
    });\
    $("#verify-password").click(function(){\
      var srp = new SRP();\
      srp.success = function() {\
        window.location = "/password-reset.lp";\
        $("#login").hide();\
        $("#forgot-login").hide();\
      }\
      srp.error_message = function(err) {\
        $("#verify-password").text(\'');  ngx.print( T"Verify" ); ngx.print('\');\
        $("#erroruserpass1").show();\
        $(".control-group").addClass("error");\
      }\
      if (this.id == "verify-password")\
     {\
       password = $("#srp_password1").val();\
     }\
     srp.identify("/authenticate", "forgotpassword", password);\
    });\
  })\
</script>\
</body>\
</html>\
'); 
