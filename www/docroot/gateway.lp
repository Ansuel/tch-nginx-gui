<%
--NG-56120, NG-56248, NG-77544
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local web = require("web.web")

local cui = {
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_version = "uci.env.var.gui_version",
	outdated_ver = "uci.env.var.outdated_ver",
}
content_helper.getExactContent(cui)

if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  if post_args.do_signout then
    ngx.ctx.session:logout()
    -- Now we redirect to / until we find a better solution
    -- Otherwise, the current page might be rendered while the default user is not allowed to see it
    -- since the access was checked for the user "before" logging out
    -- TODO: find a more elegant solution, in session module?
    ngx.redirect("/");
  end
end
%>
<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
  <head>
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    <meta name="Advanced" content="<%= cui.advanced %>">
    <link href="/css/gw.css" rel="stylesheet">
	<link rel="shortcut icon"    type="image/x-icon"   href="/img/favicon.ico"    />
    <link href="/css/responsive.css" rel="stylesheet">
	<link rel="stylesheet" href="/css/font-awesome.css">
	<link rel="stylesheet" href="/css/color.css">
<!--	<link href="/css/TIM.css" rel="stylesheet"> -->
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-min.js" ></script>
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->
    <title><%= T"Gateway" %></title>
  </head>

<body>
    
 <div class="feedback"> 

  </div>
    <div class="container">
    <div class="row">
      <div class="header span12">
        <a href="<%= cui.nsplink %>" target="_blank"><img src="/img/logo.gif"></a>
	<!--	<img class="timlogo" src="/img/TIM.png">-->
        <%
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
		if cui.outdated_ver == "1" then
			html[#html + 1] = '<div class="btn" style="margin-right:10px" id="update">' 
			html[#html + 1] = '<a style="color:red" class="someInfos" rel="tooltip" data-placement="bottom" data-original-title="'
			html[#html + 1] = T"Go to the gateway tab and click on the Upgrade buttom, to autoupgrade to the new GUI."
			html[#html + 1] = '" href="https://www.ilpuntotecnicoeadsl.com/sblocco-smart-modem-evolution-dga4130-agtef" target="_blank">'
			html[#html + 1] = T"Upgrade Available" 
			html[#html + 1] = '</a>'
			html[#html + 1] = '</div>'
		else
			html[#html + 1] = '<div class="btn" style="margin-right:10px" id="update">' 
			html[#html + 1] = '<a style="color:red" href="https://www.ilpuntotecnicoeadsl.com/sblocco-smart-modem-evolution-dga4130-agtef" target="_blank">'
			html[#html + 1] = T"Check Upgrade" 
			html[#html + 1] = '</a></div>'
		end
        html[#html + 1] = '<div class="btn" style="margin-right:10px" id="wizard-btn" data-toggle="modal" data-remote="modals/wizard-modal.lp">' .. T"Setup Wizard" .. '</div>'
        if session:isdefaultuser() then
            html[#html + 1] = '<a href="login.lp" class="btn" id="signin">'
            html[#html + 1] = T"Sign in"
            html[#html + 1] = '</a>'
        else
            html[#html + 1] = [[          <div class="btn-group" id="logged" style="padding-right:10px">
                    <button class="btn"> ]]
            html[#html + 1] = session:getusername()
            html[#html + 1] = [[ </button>
                    <button class="btn dropdown-toggle" data-toggle="dropdown">
                      <span class="caret"></span>
                    </button>
                    <ul class="dropdown-menu pull-right">
                      <li><a tabindex="-1" href="/password.lp" id="changepass">]]
            html[#html + 1] = T"Profile Settings"
            html[#html + 1] = [[ </a></li><li class="divider"></li><li><a tabindex="-1" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]
			
        end
		
        html[#html + 1] = [[</div>]]

        html[#html + 1] = [[<div class="pull-right" style="padding-right:10px">]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language(),attri)
        html[#html + 1] = [[</div>]]

        ngx.print(html)
        %>
      </div>
    </div>
    <div class="row">
      <%
        local lp = require("web.lp")
        local cards = require("cards")
        for _,v in pairs(cards.cards()) do
          lp.include(v)
        end
      %>
    </div>
    <div class="row">
			<div class="copyright span12">
			<p>&copy; Technicolor 2015</p>
			<p>Modified Ver. [ <%= cui.gui_version %> ] 2017 <a href data-toggle="modal" data-remote="modals/changelog.lp">Changelog</a></p>
			<p>Coded & Expanded by <font style="color:#0088cc;">Ansuel</font> && Unlock Utility by <font style="color:#0088cc;">ADeltaX</font> && Translated by <font style="color:#0088cc;">DarkNiko</font></p>
		</div>
	</div>
  </div>
</body>
</html>
<script>
var processMsg='<%=T"Processing"%>';
var openMsg = '<%=T"Loading..."%>';
var waitMsg = '<%=T"Please wait..."%>';
var rebootMsg = '<%=T"Rebooting. Please wait..."%>';
var loginMsg ='<%=T"Login Expired. Reloading."%>';
function httpErrorMessage(err){
    switch(err.status){
        case 500:
            erromsg='<%=T"Internal Server Error occured, please contact administrator"%>'
            break;
        case 404:
            erromsg='<%=T"The requested file is not found! Please try again after some time"%>'
            break;
        case 503:
            erromsg='<%=T"The server is currently unavailable, Please try again after some time"%>'
            break;
        case 408:
            erromsg='<%=T"The server timed out waiting for the request"%>'
            break;
        default:
             erromsg='<%=T"The request could not be performed due to some error"%>'
    }
    window.setTimeout(function(){
      erromsg = '<div style="margin-left:35%;margin-top:9%;"><span class="alert-error">'+erromsg+'</span></div>';
      var ht = $('.modal-body').height();
      ht = toString(ht).match(/\d+/) > 230 ? ht:230;
      $('.modal-body').height(ht);
      var tab = $('.modal-body ul').html();
      if(tab != undefined)
        erromsg = '<ul class="nav nav-tabs">' + tab + '</ul>' + erromsg;
      $('.modal-body').html(erromsg);
    },400);
}
</script>
