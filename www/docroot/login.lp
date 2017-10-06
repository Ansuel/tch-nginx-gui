<%
--NG-58110
--NG-78957
-- Enable localization

gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local triesbeforemsg = 3
local content_helper = require("web.content_helper")

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "getcsrf" then
  ngx.print(ngx.ctx.session:getCSRFtoken())
  ngx.exit(ngx.HTTP_OK)
end

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  gui_version = "uci.env.var.gui_version",
}
content_helper.getExactContent(cui)
local users = content_helper.getMatchedContent("uci.web.user.")
local userNames = ""
local legacySalts = ""

local httpi = proxy.get("rpc.network.interface.@wan.up")[1].value
local httpi_wwan = proxy.get("rpc.network.interface.@wwan.up")[1].value
local wan_sensing = proxy.get("uci.wansensing.global.enable")[1].value


for _, v in ipairs(users) do
  if v.legacy_salt ~= "" then
    userNames = userNames .. v.name ..","
    legacySalts = legacySalts .. v.legacy_salt .. ","
  end
end

%>
<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    <link href="/css/gw.css" rel="stylesheet">
	<link rel="stylesheet" href="/css/font-awesome.css">
    <link href="/css/responsive.css" rel="stylesheet">
	<link rel="shortcut icon"    type="image/x-icon"   href="/img/favicon.ico"    />
	<link rel="stylesheet" href="/css/color.css">
<!--	<link href="/css/TIM.css" rel="stylesheet">-->
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-min.js" ></script>
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->
    <script src="/js/srp-min.js" ></script>
    <title><%= T"Login" %></title>
</head>

<body>
  <div class="container">
        <div class="logo-technicolor">
	<a href="<%= cui.nsplink %>" target="_blank"><img src="/img/logo.gif"></a>
<!-- <img class="timlogo" src="/img/TIM.png">-->
	</div>
	<div class="row">
      <div class="offset4 span4">
        <div class="login">
        <form class="form-horizontal">
          <fieldset>
                <h2><%= T"Sign in" %></h2> 
                <% if httpi=='0' and httpi_wwan=='0' then  %>				
                <div id="httpi" class="alert alert-error ">
					<% if httpi=='0' and httpi_wwan=='0' and wan_sensing=='1' then  %>
						<strong><%= T"You don't have internet access at this time" %></strong>
					<% end %>
					<% if httpi=='0' and httpi_wwan=='0' and wan_sensing=='0' then  %>
						<strong><%= T"Your modem is in bridge mode. It only connect to DSLAM and nothings else." %></strong>
					<% end %>
                </div>
                <% end %>
            <div id="erroruserpass" class="alert alert-error hide">
               <strong><%= T"Invalid Username or Password" %></strong>
            </div>
            <div class="control-group">
                <label for="srp_username"><div class="label-icon">
                    <i class="icon-user icon-large"></i>
                </div></label>
                <input class="span3" type="text" placeholder="<%= T"Your username" %>" id="srp_username" value="<%= cui.defaultuser %>" autofocus><br><br>
            </div>
            <div class="control-group">
                <label for="srp_password"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>
                <input class="span3" type="password" placeholder="<%= T"Your password" %>" id="srp_password"><br><br>
            </div>
            <!-- HIDE WARNING - NOT NOT USED IN DEFAULT CUSTO
            <div id="defaultpassword" class="alert alert-info hide">
                <%= T"If you haven't changed it, the default password can be found on the sticker under your gateway (it's called <strong>\"access code\"</strong>)" %>
            </div>
            -->
            <div class="pull-right">
                <a href="/" id="cancel" class="btn btn-primary btn-large"><%= T"Cancel" %></a>
                &nbsp;
                <div id="sign-me-in" class="btn btn-primary btn-large"><%= T"Sign in" %></div>
			</div>
          </fieldset>
        </form>
      </div>
      </div>
    </div>
    <div class="row">
		<div class="copyright span12">
			<p>&copy; Technicolor 2015</p>
			<p>Modified Ver. [ <%= cui.gui_version %> ]</p>
			<p>Coded & Expanded by <font style="color:#0088cc;">Ansuel</font> && Unlock Utility by <font style="color:#0088cc;">ADeltaX</font> && Translated by <font style="color:#0088cc;">DarkNiko</font></p>
		</div>
	</div>
  </div>
<script>
$(document).ready(
  function() {
    var triesbeforemsg = <%= triesbeforemsg %>;
    var tries = 0;
    var password = "";
    
    // Set the focus on the first input field
    $('form:first *:input[type!=hidden]:first').focus();
    // Handle press of enter. Could be handled by adding a hidden input submit but
    // this requires a lot of css tweaking to get it right since display:none does
    // not work on every browser. So go for the js way
    $('form input').keydown(function(e) {
        if(e.which == 13 || e.which == 10) {
            e.preventDefault();
            $("#sign-me-in").click();
        }
    });

    $("#sign-me-in").on("click", function () {
      $(this).text('<%= T"Verifying" %>');
	  $("#cancel").hide();
      password = $("#srp_password")[0].value;

      //If the user has option legacy_salt, do migration
      var legacySalts = "<%= legacySalts %>";
      var userNames = "<%= userNames %>";
      var inputUsername = $("#srp_username")[0].value;
      var index = -1;
      var userNameArray = userNames.split(",")
      var legacySaltArray = legacySalts.split(",")

      for (var i = 0; i < userNameArray.length - 1; i ++)
      {
         if ( inputUsername == userNameArray[i] )
         {
           index = i;
         }
      }
      if (index >= 0)
      {
          //alert(legacySaltArray[index]);
          var hashObj = new jsSHA((legacySaltArray[index]+tch.stringToHex(password)), "HEX");
          password = hashObj.getHash("SHA-1", "HEX");
      }
      
      var srp = new SRP();
      srp.success = function() {
        // If we showed the login page using an internal redirect (detected
        // by checking if the URL ends with "/login.lp") then we simply
        // have to reload the page to get the actual page content now that
        // we're logged in.
        // Otherwise we explicitly go back to the main page.
        if (window.location.pathname.search(/\/login\.lp$/) == -1){
  		    var curl = window.location.href
          window.location.href = curl.substring(0,curl.indexOf("#"));
        }else
          window.location = "/";
      }
      srp.error_message = function(err) {
      if(err == 403){
        $.get("login.lp", {action:"getcsrf"}, function (data){
          $('meta[name=CSRFtoken]').attr('content', data);
          srp.identify("/authenticate", $("#srp_username")[0].value, password);
        });
      }else{
        $("#sign-me-in").text('<%= T"Sign in" %>');
        $("#erroruserpass").show();
		$("#cancel").show();
        $(".control-group").addClass("error");
      }
        tries++;
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {
            $("#defaultpassword").show();
        }
      }
      srp.identify("/authenticate", $("#srp_username")[0].value, password);
    });
  })

</script>
</body>
</html>
