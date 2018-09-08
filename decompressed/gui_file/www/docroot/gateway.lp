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
local session = ngx.ctx.session

local lp = require("web.lp")

local cui = {
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_skin = "uci.env.var.gui_skin",
}
content_helper.getExactContent(cui)

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
	<script async src="/js/Chart.bundle.min.js"></script>\
	<script async src="/js/srp-min.js" ></script>');
	ngx.print('<script src="/js/jquery-migrate.js" ></script>')  -- Usefull to debug deprecated function from jquery update
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
	');
	lp.setpath("/www/header-footer/")
	lp.include("header.lp")
	ngx.print('\
	<div class="container">\
    <div id="card-row" class="row" style="z-index : 2;  position: relative;">\
	');
		lp.setpath("/www/cards/")
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
          $("#save-config").on("click", function(){\
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
    end
	lp.setpath("/www/header-footer/")
	lp.include("footer.lp")
	ngx.print('\
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
  $("a[href*=\'#\']").on("click", function(e) {\
    e.preventDefault();\
    $("html, body").animate({ scrollTop: $($(this).attr("href")).offset().top}, 500, "linear");\
  });\
});\
</script>\
');
