<%
-- NG-78566
-- Enable localization
gettext.textdomain('webui-parental')

local triesbeforemsg = 3
local content_helper = require("web.content_helper")

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  gui_version = "uci.env.var.gui_version",
}
content_helper.getExactContent(cui)

%>
<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    <link href="/css/gw.css" rel="stylesheet">
    <link href="/css/responsive.css" rel="stylesheet">
	<link rel="shortcut icon"    type="image/x-icon"   href="/img/favicon.ico"    />
	<!-- <link href="/css/TIM.css" rel="stylesheet"> -->
		<link rel="stylesheet" href="/css/font-awesome.css">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-min.js" ></script>
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->
    <script src="/js/srp-min.js" ></script>
    <title><%= T"Parental Blocked" %></title>
</head>
<body>
  <div class="container">
    <div class="row">
      <div class="header span12">
        <a href="<%= cui.nsplink %>" target="_blank"><img src="/img/logo.gif"></a>
		<!-- <img class="timlogo" src="/img/TIM.png"> -->
      </div>
    </div>
    <div class="row">
      <div class="offset4 span4">
        <p><strong><%= T"Destination is blocked due to parental control." %></strong></p>
        <p><a href="http://<%=ngx.var.server_addr%>"><%= T"Continue to the main page." %></a></p>
      </div>
    </div>
    <div class="copyright span12">
			<p>&copy; Technicolor 2015</p>
			<p>Modified Ver. [ <%= cui.gui_version %> ]</p>
			<p>Coded & Expanded by <font style="color:#0088cc;">Ansuel</font> && Unlock Utility by <font style="color:#0088cc;">ADeltaX</font> && Translated by <font style="color:#0088cc;">DarkNiko</font></p>
		</div>
  </div>
</body>
</html>
