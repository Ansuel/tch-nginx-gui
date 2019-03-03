--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local triesbeforemsg = 3
local content_helper = require("web.content_helper")
local untaint = string.untaint
local proxy = require("datamodel")

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "PasswordChanged" then
   local result = content_helper.getMatchedContent("uci.web.user.", {name = ngx.ctx.session:getusername()})
    if result and #result > 0 then
      if proxy.set(result[1].path .. "password_reminder", "0") then
        proxy.apply()
      end
    end
	ngx.ctx.session:logout()
    ngx.exit(ngx.HTTP_OK)
end

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  timestamp = "uci.version.version.@version[0].timestamp",
  gui_version = "uci.modgui.gui.gui_version",
  gui_skin = "uci.modgui.gui.gui_skin",
}
content_helper.getExactContent(cui)
local year = cui.timestamp
local current_year = (string.sub(year,1,4))								   
--Start for legacy migration: GUI username/password [NG-48489]
local users = content_helper.getMatchedContent("uci.web.user.")
local userNames = ""
local legacySalts = ""

for _, v in ipairs(users) do
  if v.legacy_salt ~= "" then
    userNames = userNames .. v.name ..","
    legacySalts = legacySalts .. v.legacy_salt .. ","
  end
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().resetLegacySalt then
										   
  --As the legacy user password has changed, to remove the legacy label,i.e., option legacy_salt.
														  
											
  local user = content_helper.getMatchedContent("uci.web.user.", {name = ngx.ctx.session:getusername()})
  if user and #user > 0 then
    user = user[1]
    proxy.set(user.path .. "legacy_salt", "")
    proxy.apply()
	   
  end
end
--End for legacy migration: GUI username/password [NG-48489]

local function createPwdLabel(desc)
    local html = {
        string.format([[
            <div class="control-group">
                <label>
                  <div class="label-icon">
                    <i class="icon-large"></i>
                  </div>
                </label>
                %s
            </div>
        ]], desc),
    }
    return html
end

  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
<head>\
    <meta charset="UTF-8">\
	<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
	<link href="/css/font-awesome-all-5.7.2.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
    <link href="/css/gw.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
	<link href="/css/responsive.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\
	<link rel="shortcut icon"    type="image/x-icon"   href="/img/favicon.ico"    />');
	ngx.print('<link rel="stylesheet" href="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/style.css?version='); ngx.print(cui.gui_version); ngx.print('">\
	<script src="/js/jquery.min.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>\
	<script src="/js/jquery-migrate.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>\
    <script src="/js/main-min-nojquery.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js?version='); ngx.print(cui.gui_version); ngx.print('"></script> <![endif]-->\
    <script src="/js/srp-min.js" ></script>');
	local script_file_presence = io.open(string.format("/www/docroot/theme/%s/script.js",cui.gui_skin),"r")
	if script_file_presence then
		ngx.print('<script src="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/script.js?version='); ngx.print(cui.gui_version); ngx.print('"></script>');
	end
	ngx.print('\
	<style>\
		@media screen and (max-width: 979px) and (min-width: 768px){\
			.span4 {width: 300px;}\
		}\
		@media screen and (max-width: 979px) and (min-width: 768px){\
		input.span3, textarea.span3, .uneditable-input.span3 \
			{width: 206px;}\
		}\
		@media screen and (max-width: 979px) and (min-width: 768px){\
		.offset4 {margin-left: 231px;}\
		}\
		@media screen and (max-width: 1200px){\
		.pstrength0 {width: 10px;}\
		.pstrength1 {width: 55px;}\
		.pstrength2 {width: 100px;}\
		.pstrength3 {width: 140px;}\
		.pstrength4 {width: 185px;}\
		}\
		@media screen and (min-width: 1200px){\
		.pstrength0 {width: 10px;}\
		.pstrength1 {width: 55px;}\
		.pstrength2 {width: 100px;}\
		.pstrength3 {width: 140px;}\
		.pstrength4 {width: 185px;}\
		}\
	</style>\
    <title>');  ngx.print( T"Change password" ); ngx.print('</title>\
\
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
	</div>\
    <div class="row">\
      <div class="span4">\
        <div class="login">\
        <form class="form-horizontal">\
          <fieldset style="min-width:auto">\
                <h2>');  ngx.print( T"Profile Settings" ); ngx.print('</h2>\
            <div id="erroruserpass" class="alert alert-error hide">\
                <strong>');  ngx.print( T"Passwords do not match" ); ngx.print('</strong>\
            </div>\
\
            <div id="erroruserpass_2" class="alert alert-error hide">\
               <strong>');  ngx.print( T"Password must contain at least 12 alphanumeric characters including both upper and lower case letters, at least one number and at least one special character" ); ngx.print('</strong>\
            </div>\
\
            <div id="erroruserpass_3" class="alert alert-error hide">\
               <strong>');  ngx.print( T"Provide a password to prevent unauthorized access to the gateway"); ngx.print('</strong>\
            </div>\
\
            <div id="erroruserpass_4" class="alert alert-error hide">\
               <strong>');  ngx.print( T"Old password is incorrect"); ngx.print('</strong>\
            </div>\
\
            ');  
			ngx.print(createPwdLabel(T"Your Username")); ngx.print('\
				<div class="control-group">\
					<label for="srp_username"><div style="margin-right:14px" class="label-icon">\
						<i class="icon-user icon-large"></i>\
			');
			ngx.print('\</div>\
						</label>');
			ngx.print(ngx.ctx.session:getusername());
			
			ngx.print('\
			</div>');
			
			ngx.print( createPwdLabel(T"Your old password") ); ngx.print('\
            <div class="control-group">\
                <label for="srp_password"><div class="label-icon">\
                    <i class="icon-lock icon-large"></i>\
                </div></label>\
                <input class="span3" type="password" autocomplete="current-password" id="srp_password" autofocus><br><br>\
            </div>\
            <!-- HIDE WARNING - NOT USED IN DEFAULT CUSTO\
            <div id="defaultpassword" class="alert alert-info hide">\
                ');  ngx.print( T"If you haven't changed it, the default password can be found on the sticker under your gateway (it's called <strong>\"access code\"</strong>)" ); ngx.print('\
            </div>\
            -->\
            ');  ngx.print( createPwdLabel(T"Your new password") ); ngx.print('\
            <div class="control-group">\
                <label for="srp_password_new_1"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                <input class="span3" type="password" id="srp_password_new_1" onkeyup="passwordCheck(this.value)"><br>\
                <label for="Strength"></label>\
                <div id="Password_Strength" class="span3"></div><br>\
            </div>\
            ');  ngx.print( createPwdLabel(T"Repeat new password") ); ngx.print('\
            <div class="control-group">\
                <label for="srp_password_new_2"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                <input class="span3" type="password" id="srp_password_new_2"><br><br>\
            </div>\
            <div class="pull-right">\
                <a href="/" id="cancel" class="btn btn-primary btn-large">');  ngx.print( T"Cancel" ); ngx.print('</a>\
                &nbsp;\
                <div id="change-my-pass" class="btn btn-primary btn-large">');  ngx.print( T"Change password" ); ngx.print('</div>\
				<div id="updating" style="display:none" class="btn btn-primary btn-large">');  ngx.print( T"Updating" ); ngx.print('</div>\
				<div id="insecure_question" style="display:none;font-size: 20px;margin-right:48px" >');  ngx.print( createPwdLabel(T"Continue anyway?") ); ngx.print('</div>\
				<a id="yes" style="display:none" class="btn btn-primary btn-large">');  ngx.print( T"Yes" ); ngx.print('</a>\
				&nbsp;\
				<div id="no" style="display:none" class="btn btn-primary btn-large">');  ngx.print( T"No" ); ngx.print('</div>\
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
<script>\
function passwordCheck(password)\
{\
\
	var level = 0;\
\
	//if password bigger than 6 give 1 point\
	if (password.length >= 6) level++;\
\
	//if password has both lower and uppercase characters give 1 point\
	if ( ( password.match(/[a-z]/) ) && ( password.match(/[A-Z]/) ) ) level++;\
\
	//if password has at least one number give 1 point\
	if (password.match(/\\d+/)) level++;\
\
	//if password has at least one special caracther give 1 point\
	if ( password.match(/[!,@,#,$,%,^,&,*,?,_,~,-,(,)]/) )	level++;\
\
	//if password bigger than 8 give another 1 point\
	if (password.length >= 8) level++;\
\
	 $(\'#Password_Strength\').removeClass().addClass("pstrength" + level).addClass("span3");\
         return level;\
}\
\
$(document).ready(\
  function() {\
    var triesbeforemsg = ');  ngx.print( triesbeforemsg ); ngx.print(';\
    var tries = 0;\
\
    function display_error()\
    {\
        $("#change-my-pass").text(\'');  ngx.print( T"Change password" ); ngx.print('\');\
        $("#erroruserpass").show();\
        $(".control-group").addClass("error");\
        tries++;\
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {\
            $("#defaultpassword").show();\
        }\
    }\
\
	var username;\
	var password;\
	var srp;\
	var index = -1;\
	\
	function oneTimeCall()\
	{\
		srp = new SRP();\
		username = \'');  ngx.print( ngx.ctx.session:getusername() ); ngx.print('\';\
		//Start for legacy migration: GUI username/password [NG-48489]\
		/*\
		If the user has option legacy_salt, means it\'s migrated from the legacy build.\
		Then user the sha1 hash of the password to authenticate.\
		*/\
		var legacySalts = "');  ngx.print( legacySalts ); ngx.print('";\
		var userNames = "');  ngx.print( userNames ); ngx.print('";\
\
		var userNameArray = userNames.split(",")\
		var legacySaltArray = legacySalts.split(",")\
		for (var i = 0; i < userNameArray.length - 1; i ++)\
		{\
			if ( username == userNameArray[i] )\
			{\
			index = i;\
			}\
		}\
		if (index >= 0)\
		{\
			var hashObj = new jsSHA((legacySaltArray[index]+tch.stringToHex(password)), "HEX");\
			password = hashObj.getHash("SHA-1", "HEX");\
		}\
		//End for legacy migration: GUI username/password [NG-48489]\
		calls++;\
		index = -1;\
	}\
	var calls = 0;\
	function change_pass()\
	{\
		password = $("#srp_password")[0].value;\
\
		if (calls == 0)\
			oneTimeCall();\
\
		srp.success = function() {\
			srp.generateSaltAndVerifier("/password", username, $("#srp_password_new_1")[0].value)\
			//Start for legacy migration: GUI username/password [NG-48489]\
			if(index >= 0)\
			{\
			$.post("/password.lp", { CSRFtoken:$("meta[name=CSRFtoken]").attr("content"), username:username, resetLegacySalt:"1"});\
			}\
			//End for legacy migration: GUI username/password [NG-48489]\
		}\
		srp.passwordchanged = function() {\
			var params = []\
			params.push({\
				name : "action",\
				value : "PasswordChanged"\
			}, tch.elementCSRFtoken());\
			$.post("password.lp", params, function(){\
			window.location = "/";\
			});\
		}\
		srp.error_message = function() {\
\
			$("#erroruserpass_4").show();\
			$("#yes").hide()\
			$(".control-group").addClass("error");\
			$("#change-my-pass").show();\
			$("#updating").hide();\
			$("#cancel").show();\
\
		}\
		srp.identify("/password", username, password);\
	}\
    // Set the focus on the first input field\
    $(\'form:first *:input[type!=hidden]:first\').trigger("focus");\
    // Handle press of enter. Could be handled by adding a hidden input submit but\
    // this requires a lot of css tweaking to get it right since display:none does\
    // not work on every browser. So go for the js way\
    $(\'form input\').on("keydown", function(e) {\
        if(e.which == 13 || e.which == 10) {\
            e.preventDefault();\
            $("#change-my-pass").click();\
        }\
    });\
\
	$("#yes").on("click", function(){\
		$("#erroruserpass_2").hide();\
		$("#no").hide();\
		$("#yes").hide();\
		$("#cancel").hide();\
		$("#insecure_question").hide();\
		change_pass()\
		$("#updating").show();\
	});\
	\
	$("#no").on ("click", function(){\
		$("#yes").hide();\
		$("#no").hide();\
		$("#cancel").show();\
		$("#change-my-pass").show();\
		$(".control-group").removeClass();\
		$("#erroruserpass_2").hide();\
		$("#insecure_question").hide();\
	});\
\
    $("#change-my-pass").on("click", function () {\
    $(".alert").hide();\
      if ($("#srp_password_new_1")[0].value != $("#srp_password_new_2")[0].value) {\
        display_error();\
        return false;\
      }\
\
      var password1 = $("#srp_password_new_1")[0].value;\
      var password2 = $("#srp_password_new_2")[0].value;\
      if(password1.length < 12 || passwordCheck(password1) < 5)\
         {\
            if(password1.length == 0)\
            {\
              $("#erroruserpass_3").show();\
              $(".control-group").addClass("error");\
              return false;\
            }\
            $("#erroruserpass_2").show();\
            $("#change-my-pass").hide();\
			$("#cancel").hide();\
			$("#yes").show();\
			$("#no").show();\
			$("#insecure_question").show();\
			$(".control-group").addClass("error");\
         }\
	  else\
		{\
		$("#change-my-pass").hide();\
		$("#cancel").hide();\
		$("#updating").show();\
		change_pass()\
		}\
    });\
  })\
</script>\
</body>\
</html>\
'); 
