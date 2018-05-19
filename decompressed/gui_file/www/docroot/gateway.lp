--pretranslated: do not change this file
 
-- Enable localization
--NG-56120, NG-56248, NG-77544
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local web = require("web.web")
local session = ngx.ctx.session
local proxy = require("datamodel")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')

local cui = {
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	timestamp = "uci.version.version.@version[0].timestamp",
	gui_version = "uci.env.var.gui_version",
	outdated_ver = "uci.env.var.outdated_ver",
	gui_skin = "uci.env.var.gui_skin",
	luci_webui = "uci.env.var.luci_webui",										 
    aria2_webui = "uci.env.var.aria2_webui",
    transmission_webui = "uci.env.var.transmission_webui",
	blacklist_application = "uci.env.var.blacklist_app",
	new_ver = "uci.env.var.new_ver",
}
content_helper.getExactContent(cui)

local year= cui.timestamp
local current_year = (string.sub(year,1,4))

local function apply(action)
  proxy.set("rpc.system." .. action, "1")
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  if post_args.passwordchange == "dontremind" then
    local result = content_helper.getMatchedContent("uci.web.user.", {name = session:getusername()})
    if result and #result > 0 then
      if proxy.set(result[1].path .. "password_reminder", "0") then
        proxy.apply()
      end
    end
  end
  if post_args.action == "checkver" then
	return apply("checkver")
  end
  if post_args.do_signout then
    session:logout()
    -- Now we redirect to / until we find a better solution
    -- Otherwise, the current page might be rendered while the default user is not allowed to see it
    -- since the access was checked for the user "before" logging out
    -- TODO: find a more elegant solution, in session module?
    ngx.redirect("/");
  end
end
ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( session:getCSRFtoken() ); ngx.print('">\
    <meta name="Advanced" content="');  ngx.print( cui.advanced ); ngx.print('">\
    <link href="/css/gw.css" rel="stylesheet">\
	<link rel="shortcut icon"    type="image/x-icon"   href="/img/favicon.ico"    />\
    <link href="/css/responsive.css" rel="stylesheet">\
	<link rel="stylesheet" href="/css/font-awesome.css">\
	<!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
	<link rel="stylesheet" href="/css/aos.css" >\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <title>');  ngx.print( T"Gateway" ); ngx.print('</title>\
	<script src="/js/main-min.js" ></script>\
	<script src="js/knockout-min.js"></script>\
	<script src="/js/aos.js"></script>\
	<script async src="/js/graphic-min.js"></script>\
	<script async src="/js/Chart.min.js"></script>\
	<script async src="/js/srp-min.js" ></script>');
	ngx.print('<link rel="stylesheet" href="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/style.css">');
local script_file_presence = io.open(string.format("/www/docroot/theme/%s/script.js",cui.gui_skin),"r")
if script_file_presence then
	ngx.print('<script src="/theme/');  ngx.print( cui.gui_skin ); ngx.print('/script.js"></script>');
end
  ngx.print('</head>\
'); ngx.print('\
<body>\
\
 <div class="feedback">\
\
  </div>\
    <a href="#footer" id="scroll-down" class="scroll-down" address="true"></a>\
	<a href="#headertab" id="scroll-up"class="scroll-up hide" address="true"></a>\
    <div class="container">\
	<div class="gateway_bg" data-bg-text="&#xf0ac;"></div>\
    <div class="row" style="z-index : 3;  position: relative;" >\
\
      <div class="header span12" id="headertab">\
        <a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank">\
		  <picture>');
		  
		if cui.gui_skin == "TIM" then
			ngx.print('<img width="168px" height="39px" src="/img/TIM.png">');
		elseif cui.gui_skin == "Fritz" then
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
\
		');
		
        local session = ngx.ctx.session
		local attri ={ select = {style ="width:auto; padding-top:7px; padding-bottom:7px; margin:auto; height: 36px"}}
        local html = {}

        html[#html + 1] = [[<div class="pull-right" style="padding-right:10px">]]
		if web.isDemoBuild() then
			html[#html + 1] = [[ <div class="pull-right" style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px; padding-left: 7px;padding-right: 7px"> ]]
				html[#html + 1] = [[ <a style="color:red" class="someInfos" rel="tooltip" data-placement="bottom" data-original-title=" ]] 
				html[#html + 1] = T"Don't report any bug, this is a custom gui! Some bugs could not be related to the current beta firmware."
				html[#html + 1] = [[ " href="https://plus.google.com/u/0/communities/108761366800436892116" target="_blank">BETA BUILD</a> ]]
			html[#html + 1] = [[ </div> ]]
		end
		if not ( session:getusername() == "guest" ) then
			if cui.outdated_ver == "1" then
				html[#html + 1] = '<div id="upgradebtn" class="btn someInfos" style="margin-right:10px; color:orangered" '
				if not ( cui.gui_skin == "Fritz" ) then
					html[#html + 1] = 'rel="tooltip" data-placement="bottom" data-original-title="'
					html[#html + 1] = T"Go to the gateway tab and click on the Upgrade button, to autoupgrade to the new GUI."
					html[#html + 1] = '" '
				end
				html[#html + 1] = 'data-toggle="modal" data-remote="modals/gateway-modal.lp">'
				html[#html + 1] = '<span>'
				html[#html + 1] = T"Upgrade Available" 
				html[#html + 1] = " <strong>( "
				html[#html + 1] = cui.new_ver
				html[#html + 1] = " )</strong>" 
				html[#html + 1] = '</span>'
				html[#html + 1] = '</div>'
			end
			html[#html + 1] = '<div class="btn" style="margin-right:10px" id="wizard-btn" data-toggle="modal" data-remote="modals/wizard-modal.lp">' .. T"Setup Wizard" .. '</div>'
        end
		if session:isdefaultuser() then
            html[#html + 1] = '<a href="login.lp" class="btn" id="signin">'
            html[#html + 1] = T"Sign in"
            html[#html + 1] = '</a>'
        else
            html[#html + 1] = [[          <div class="btn-group" id="logged">
                    <button class="btn"> ]]
            html[#html + 1] = session:getusername()
            html[#html + 1] = [[ </button>
                    <button class="btn dropdown-toggle" data-toggle="dropdown"><span class="caret"></span> ]]
			html[#html + 1] = T"Advanced "		
            html[#html + 1] = [[
                    </button>
                    <ul class="dropdown-menu pull-right"> ]]
            if session:getusername() ~= assistant:username() then
                html[#html + 1] = [[ <li><a tabindex="-1" href="/password.lp" id="changepass"> ]]
                html[#html + 1] = T"Profile Settings"
                html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
            end
				html[#html + 1] = [[ <li><a tabindex="-1" href="https://www.ilpuntotecnicoeadsl.com/forum/index.php/topic,77325.0.html" target="_blank"> ]]
				html[#html + 1] = T"Support Forum"
				html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
				html[#html + 1] = [[ <li><a tabindex="-1" href="https://github.com/Ansuel/tch-nginx-gui" target="_blank"> ]]
				html[#html + 1] = T"Github Gui"
				html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
			if not ( session:getusername() == "guest" ) then
				html[#html + 1] = [[ <li><a style="cursor: pointer;" tabindex="-1" id="update"> ]]
				html[#html + 1] = T"Check Upgrade" 
				html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
				if cui.aria2_webui == "1" then
				html[#html + 1] = [[ <li><a tabindex="-1" target="_blank" href="/aria"> ]]
				html[#html + 1] = T"Aria2 Webui"
				html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
				end
				if cui.luci_webui == "1" then
				html[#html + 1] = [[ <li><a tabindex="-1" target="_blank" href="/" 
									onclick="javascript:event.target.port=9080"> ]]
				html[#html + 1] = T"Luci Webui"
				html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
				end
				if cui.transmission_webui == "1" then
				html[#html + 1] = [[ <li><a tabindex="-1" target="_blank" href="/transmission/web/"> ]]
				html[#html + 1] = T"Transmission Webui"
				html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
				end
			end
            html[#html + 1] = [[ <li><a tabindex="-1" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]
			
        end
		
        html[#html + 1] = [[</div>]]

        html[#html + 1] = [[<div class="pull-right" style="padding-right:10px">]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language(),attri)
        html[#html + 1] = [[</div>]]

        ngx.print(html)
        ngx.print('\
      </div>\
	</div>\
    <div class="row" style="z-index : 2;  position: relative;">\
	');
        local lp = require("web.lp")
        local cards = require("cards")
        for _,v in pairs(cards.cards()) do
          lp.include(v)
        end
        ngx.print('\
    </div>\
    ');  if not session:isdefaultuser() and not session:retrieve("password_reminder_shown") and session:getusername() ~= assistant:username() then
      local result = content_helper.getMatchedContent("uci.web.user.", {name = session.getusername()})
      if result and result[1].password_reminder ~= "0" then
        html = {}
        html[#html + 1] = '<div class="modal fade in" id="password_reminder">'
        html[#html + 1] = ui_helper.createHeader(T"Change Password")
        html[#html + 1] = '<div class="modal-body update">'
        html[#html + 1] = '<form class="form-horizontal" method="post" action="gateway.lp">'
        html[#html + 1] = ui_helper.createSimpleInputHidden("CSRFtoken", session:getCSRFtoken())
        html[#html + 1] = '<fieldset>'
        local attr = {radio = {style = "display: block"}}
        html[#html + 1] = ui_helper.createInputRadio("", "passwordchange", {{"now", T"Now"},{"remindlater", T"Remind me later"},{"dontremind", T"Do not remind me again"}},nil,attr)
        html[#html + 1] = '</fieldset>'
        html[#html + 1] = '</form>'
        html[#html + 1] = '</div>'
        html[#html + 1] = ui_helper.createFooter()
        html[#html + 1] = '</div>'
        ngx.print(html)  ngx.print('\
        <script>\
          $("#password_reminder").modal();\
          $("#save-config").click(function(){\
            var value = $("input[name=passwordchange]:checked").val();\
            if(value == "now"){\
               window.location = "/password.lp";\
            }else if(value == "remindlater"){\
               $("#password_reminder").modal(\'hide\');\
            }else if(value == "dontremind"){\
               $("#password_reminder form").submit();\
            }\
            return false;\
          });\
        </script>\
      ');  end
      session:store("password_reminder_shown", true)
    end  ngx.print('\
    <div id="footer" class="row">\
			<div class="copyright span12">\
			<p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p>\
			<p>GUI Version [ '); ngx.print( cui.gui_version ); ngx.print(' ] 2018 <a href data-toggle="modal" data-remote="modals/changelog.lp">Changelog</a></p>\
			<p>Coded & Expanded by <font style="color:#0088cc;">Ansuel</font> && Unlock Utility by <font style="color:#0088cc;">ADeltaX</font>');
			local lang_credit = ""
			if not ( tostring(gettext.language()) == "en-us" ) then
				if tostring(gettext.language()) == "it-it" then
					lang_credit = "DarkNiko"
				elseif tostring(gettext.language()) == "de-de" then
					lang_credit = "meyergru"
				end
				ngx.print(' && Translated by <font style="color:#0088cc;">' .. lang_credit .. '</font>')
			end
			ngx.print('</p>\
		</div>\
	</div>\
  </div>\
</body>\
</html>\
<script>\
AOS.init();\
var processMsg=\'');  ngx.print(T"Processing"); ngx.print('\';\
var openMsg = \'');  ngx.print(T"Loading..."); ngx.print('\';\
var waitMsg = \'');  ngx.print(T"Please wait..."); ngx.print('\';\
var loginMsg =\'');  ngx.print(T"Login Expired. Reloading."); ngx.print('\';\
var okButton = \'');  ngx.print(T"Ok"); ngx.print('\';\
var cancelButton = \'');  ngx.print(T"Cancel"); ngx.print('\';\
function httpErrorMessage(err){\
    switch(err.status){\
        case 500:\
            erromsg=\'');  ngx.print(T"Internal Server Error occured, please contact administrator"); ngx.print('\'\
            break;\
        case 404:\
            erromsg=\'');  ngx.print(T"The requested file is not found! Please try again after some time"); ngx.print('\'\
            break;\
        case 503:\
            erromsg=\'');  ngx.print(T"The server is currently unavailable, Please try again after some time"); ngx.print('\'\
            break;\
        case 408:\
            erromsg=\'');  ngx.print(T"The server timed out waiting for the request"); ngx.print('\'\
            break;\
        default:\
             erromsg=\'');  ngx.print(T"The request could not be performed due to some error"); ngx.print('\'\
    }\
    window.setTimeout(function(){\
      erromsg = \'<div style="margin-left:35%;margin-top:9%;"><span class="alert-error">\'+erromsg+\'</span></div>\';\
      var ht = $(\'.modal-body\').height();\
      ht = toString(ht).match(/\\d+/) > 230 ? ht:230;\
      $(\'.modal-body\').height(ht);\
      var tab = $(\'.modal-body ul\').html();\
      if(tab != undefined)\
        erromsg = \'<ul class="nav nav-tabs">\' + tab + \'</ul>\' + erromsg;\
      $(\'.modal-body\').html(erromsg);\
    },400);\
}\
\
window.onscroll = function() {scrollFunction()};\
\
function scrollFunction() {\
if (document.body.scrollTop > 60 || document.documentElement.scrollTop > 60) {\
        $("#scroll-up").removeClass("hide");\
		$("#scroll-down").addClass("hide");\
    } else {\
        $("#scroll-up").addClass("hide");\
		$("#scroll-down").removeClass("hide");\
    }\
}\
\
$(function() {\
  $("a[href*=#]").on("click", function(e) {\
    e.preventDefault();\
    $("html, body").animate({ scrollTop: $($(this).attr("href")).offset().top}, 500, "linear");\
  });\
\
  var target = $(".modal form").attr("action");\
\
  function post(action) {\
    $.post(\
      target,\
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      null,\
      "json"\
    );\
    return false;\
  }\
\
  $("#update").click(function() {\
     post("checkver");\
	 setTimeout(function(){location.reload();}, 4000);\
     });\
  $("#upgradebtn").hover(\
	function() {\
		$("#upgradebtn").css("color","white");\
	},\
	function() {\
		$("#upgradebtn").css("color","orangered");\
	}\
  );\
});\
</script>\
');
