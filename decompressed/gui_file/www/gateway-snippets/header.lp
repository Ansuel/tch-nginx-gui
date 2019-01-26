--pretranslated: do not change this file

-- Enable localization

gettext.textdomain('webui-core')
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local format = string.format
local session = ngx.ctx.session
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')
local web = require("web.web")

local cui = {
	nsplink = "uci.web.uiconfig.@uidefault.nsplink",
	gui_skin = "uci.env.var.gui_skin",
	gui_version = "uci.env.var.gui_version",
	outdated_ver = "uci.env.var.outdated_ver",
	amule_webui = "uci.env.var.amule_webui",
	aria2_webui = "uci.env.var.aria2_webui",
	luci_webui = "uci.env.var.luci_webui",
    transmission_webui = "uci.env.var.transmission_webui",
	blacklist_application = "uci.env.var.blacklist_app",
	new_ver = "uci.env.var.new_ver",
	autoupgrade_hour= "uci.env.var.autoupgrade_hour",
	autoupgrade_view = "uci.env.var.autoupgradeview",
	firstpage = "uci.env.var.firstpage",
	randomcolor = "uci.env.var.randomcolor",
}

content_helper.getExactContent(cui)

local pageselector = {}

if cui.firstpage == "stats" then
	pageselector.page = "cards.lp"
	pageselector.text = T"Cards"
	pageselector.otherpage = "stats.lp"
	pageselector.othertext = T"Stats"
else
	pageselector.page = "stats.lp"
	pageselector.text = T"Stats"
	pageselector.otherpage = "cards.lp"
	pageselector.othertext = T"Cards"
end

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
  if post_args.action == "checkver" then
	return apply("checkver")
  end
  if post_args.action == "autoupgrade_view" then
	proxy.set("uci.env.var.autoupgradeview", "none")
	proxy.apply()
  end
  if post_args.do_signout then
    session:logout()
    -- Now we redirect to / until we find a better solution
    -- Otherwise, the current page might be rendered while the default user is not allowed to see it
    -- since the access was checked for the user "before" logging out
    -- TODO: find a more elegant solution, in session module?
    ngx.redirect("/");
  end
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
<div class="gateway_bg" data-bg-text="&#xf0ac;"></div>\
	<div class="header" id="headertab">\
	<div class="row" style="z-index : 3;  position: relative;" >\
		<div class="header-logo">\
        <a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank">\
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
		');
		
        local html = {}

		html[#html + 1] = [[<div class="header-button">]]
		if web.isDemoBuild() then
			html[#html + 1] = [[ <div class="pull-right" style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px; padding-left: 7px;padding-right: 7px"> ]]
				html[#html + 1] = [[ <a style="color:red" class="someInfos" rel="tooltip" data-placement="bottom" data-original-title=" ]] 
				html[#html + 1] = T"Don't report any bug, this is a custom gui! Some bugs could not be related to the current beta firmware."
				html[#html + 1] = [[ " href="https://plus.google.com/u/0/communities/108761366800436892116" target="_blank">BETA BUILD</a> ]]
			html[#html + 1] = [[ </div> ]]
		end
		
		if not ( session:getusername() == "guest" ) then
			if cui.outdated_ver == "1" then
				html[#html + 1] = '<div class="header-sub-button">'
				html[#html + 1] = '<div id="upgradebtn" class="btn someInfos"'
				if not ( cui.gui_skin == "Fritz" ) then
					html[#html + 1] = 'rel="tooltip" data-placement="bottom" data-original-title="'
					html[#html + 1] = T"Go to the gateway tab and click on the Upgrade button, to autoupgrade to the new GUI."
					html[#html + 1] = '" '
				end
				html[#html + 1] = 'data-toggle="modal" data-remote="modals/gateway-modal.lp?action=manualguiupgrade">'
				html[#html + 1] = '<span>'
				html[#html + 1] = T"Upgrade"
				html[#html + 1] = '</span>'
				html[#html + 1] = '</div>'
				html[#html + 1] = '</div>'
			end
			html[#html + 1] = '<div class="header-sub-button">'
			html[#html + 1] = '<div class="btn" id="wizard-btn" data-toggle="modal" data-remote="modals/wizard-modal.lp">' .. T"Setup Wizard" .. '</div>'
			html[#html + 1] = '</div>'
			html[#html + 1] = '<div class="header-sub-button">'
			html[#html + 1] =   '<div class="btn" id="swtichbuttom">' 
			html[#html + 1] =     '<span id="refresh-cards"></span>'
			html[#html + 1] =     '<span id="cards-text">' .. pageselector.text .. '</span>'
			html[#html + 1] =   '</div>'
			html[#html + 1] = '</div>'
        end
			html[#html + 1] = '<div class="header-sub-button">'
			html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language())
			html[#html + 1] = '</div>'
		html[#html + 1] = '<div class="header-sub-button">'
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
				if cui.luci_webui == "1" then
					html[#html + 1] = [[ <li><a tabindex="-1" target="_blank" href="/"
									onclick="javascript:event.target.port=9080;event.target.protocol='http'"> ]]
					html[#html + 1] = T"Luci WebUI"
					html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
				end
				if cui.amule_webui == "1" then
				html[#html + 1] = [[ <li><a tabindex="-1" target="_blank" href="/"
								onclick="javascript:event.target.port=4711;event.target.protocol='http'"> ]]
				html[#html + 1] = T"aMule Webui"
				html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
				end
				if cui.aria2_webui == "1" then
				html[#html + 1] = [[ <li><a tabindex="-1" target="_blank" href="/aria"> ]]
				html[#html + 1] = T"Aria2 Webui"
				html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
				end
				if cui.transmission_webui == "1" then
					html[#html + 1] = [[ <li><a tabindex="-1" target="_blank" href="/"
								onclick="javascript:event.target.port=9091;event.target.protocol='http'"> ]]
				html[#html + 1] = T"Transmission Webui"
				html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
				end
			end
            html[#html + 1] = [[ <li><a tabindex="-1" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]
			
        end
		html[#html + 1] =   "</div>"
        html[#html + 1] =  "</div>"
		html[#html + 1] = "</div>"
		if cui.outdated_ver == "1" then
			local alert_success = {
				alert = {
					class = "alert",
					id = "upgrade-alert"
				},
			}
			html[#html + 1] = ui_helper.createAlertBlock(string.format(T"Upgrade available! Version: <strong>%s</strong>",cui.new_ver),alert_success)
		end
		local autoupgrade_view = cui.autoupgrade_view
		if not ( autoupgrade_view == "none" ) and not ( autoupgrade_view == "" ) then
			local alert_success = {
				alert = {
					class = "alert-success",
					id = "upgrade-alert"
				},
			}
			if autoupgrade_view == "auto" then
				html[#html + 1] = ui_helper.createAlertBlock(string.format(T("The modem has been upgraded automatically at <strong>%s:00</strong>" .. 
							" to version <strong>%s</strong> successfully"),cui.autoupgrade_hour, cui.gui_version),alert_success)
			else
				html[#html + 1] = ui_helper.createAlertBlock(string.format(T"The modem has been upgraded to version <strong>%s</strong> successfully",cui.gui_version),alert_success)
			end
		end
		if not session:isdefaultuser() and not session:retrieve("password_reminder_shown") and session:getusername() ~= assistant:username() then
			local result = content_helper.getMatchedContent("uci.web.user.", {name = session.getusername()})
				if result and result[1].password_reminder ~= "0" then
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
					html[#html + 1] = '\
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
					'  
				end
			session:store("password_reminder_shown", true)
		end
		html[#html + 1] = '<a href="#footer" id="scroll-down" class="scroll-down" address="true"></a>'
		html[#html + 1] = '<a href="#headertab" id="scroll-up"class="scroll-up hide" address="true"></a>'
ngx.print(html)
ngx.print('\
</div>\
<script>\
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
function checkupdate() {\
	post("checkver");\
	 var processMsg = "');  ngx.print(T'Checking...'); ngx.print('";\
	 tch.showProgress(processMsg);\
	 setTimeout(function(){location.reload();}, 4000);\
}\
var KoRequest = [];\
$(function() {\
'); if cui.randomcolor == "1" then ngx.print('\
   setInterval(function() {\
      var colorR = Math.floor((Math.random() * 256));\
      var colorG = Math.floor((Math.random() * 256));\
      var colorB = Math.floor((Math.random() * 256));\
	  $(":root").get(0).style.setProperty("--first-color-accent", "rgb(" + colorR + "," + colorG + "," + colorB + ")");\
	  $(":root").get(0).style.setProperty("--first-color-accent-50", "rgba(" + colorR + "," + colorG + "," + colorB + ", 0.5)");\
	  $(":root").get(0).style.setProperty("--first-color-accent-80", "rgba(" + colorR + "," + colorG + "," + colorB + ", 0.8)");\
	}, 750);')
end ngx.print('\
  var pathname = document.location.pathname;\
  var page = "'); ngx.print(pageselector.page); ngx.print ('";\
  var text = "'); ngx.print(pageselector.text); ngx.print ('";\
  if (pathname == "/stats.lp") {\
  	page = "cards.lp";\
  	text = "'); ngx.print(T"Cards"); ngx.print ('";\
	$("#cards-text").text(text);\
  } else if (pathname == "/cards.lp") {\
  	page = "stats.lp";\
  	text = "'); ngx.print(T"Stats"); ngx.print ('";\
	$("#cards-text").text(text);\
  }\
  $("#swtichbuttom").on("click", function() {\
    var pathname = document.location.pathname;\
	var text = "'); ngx.print(pageselector.othertext); ngx.print ('";\
	if (pathname == "/stats.lp") {\
		page = "cards.lp";\
	} else if (pathname == "/cards.lp") {\
		page = "stats.lp";\
	}\
	window.location.replace(page);\
	$("#refresh-cards").show().css("margin-right","5px").addClass("fa fa-sync fa-spin");\
	KoRequest.forEach(function(element) {\
		clearInterval(element);\
	});\
	KoRequest = [];\
  });\
\
\
  $("#update").on("click", function() {\
     checkupdate();\
     });\
  $("#upgradebtn").on("hover",\
	function() {\
		$("#upgradebtn").css("color","white");\
	},\
	function() {\
		$("#upgradebtn").css("color","orangered");\
	}\
  );\
  '); 
  if not ( autoupgrade_view == "none" ) and not ( autoupgrade_view == "" ) then
    ngx.print('\
  post("autoupgrade_view");\
    ');
  end
  ngx.print('\
  ko.bindingHandlers.text = {\
		init: function(element, valueAccessor) {\
        $(element).text(ko.unwrap(valueAccessor()));\
    },\
    update: function(element, valueAccessor) {\
        var value = ko.unwrap(valueAccessor());\
        if (value != $(element).text() ) {\
			if ( ! $(element).hasClass("hide") ) {\
				$(element).fadeOut(function() {\
					$(this).text(value).fadeIn();\
				});\
			} else {\
				$(element).text(value);\
			}\
		}\
    }\
  };\
  ko.bindingHandlers.html = {\
		init: function(element, valueAccessor) {\
        $(element).html(ko.unwrap(valueAccessor()));\
    },\
    update: function(element, valueAccessor) {\
        var value = ko.unwrap(valueAccessor());\
        if (value != $(element).html() ) {\
			if ( ! $(element).hasClass("hide") ) {\
				$(element).fadeOut(function() {\
					$(this).html(value).fadeIn();\
				});\
			} else {\
				$(element).html(value);\
			}\
		}\
    }\
  };\
});\
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