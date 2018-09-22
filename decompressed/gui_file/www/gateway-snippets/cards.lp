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
 <div class="feedback">\
\
  </div>\
    <a href="#footer" id="scroll-down" class="scroll-down" address="true"></a>\
	<a href="#headertab" id="scroll-up"class="scroll-up hide" address="true"></a>\
	<div id="dynamic-content">\
      <div id="cardrow" class="row">\
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
	  ngx.print('\
	</div>\
<script>\
AOS.init();\
$(document).ready(function () {\
	$("#refresh-cards").hide();\
});\
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
