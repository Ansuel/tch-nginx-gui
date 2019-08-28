--pretranslated: do not change this file

-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")

ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Executing", false, false))   ngx.print('\
<div class="modal-body update">\
  <form class="form-horizontal" id="commandlogmodal" method="post" action="/modals/command-log-read-modal.lp">\
	<fieldset>\
	  <div style="white-space: pre-wrap" class="fake_console" data-bind="log_text: log">\
	  </div>\
	</fieldset>\
  </form>\
</div>\
  <script>\
	var CommandLogReadRefresh = function CommandLogReadRefresh(ElementBinding) {\
		$(".modal-footer,.modal-action-close").hide();\
		$.post("/ajax/commandlogread.lua?auto_update=true", [tch.elementCSRFtoken()], function (data) {\
			ElementBinding.log(data.log);\
		}, "json")\
			.done(function(data) {\
				if(!$("#show_progress").length){\
					$(".modal-header-title").find("h2").append($(\'<span id="show_progress">+</span>\'));\
				}\
				$("#show_progress").text($("#show_progress").text().replace(/[\\+]{10}/g, ""));\
				$("#show_progress").append("+");\
				if(data.state == "Complete"){\
					$(".modal-header-title").find("h2").text("Complete")\
					clearInterval(KoRequest.CommandLogReadInterval)\
					$(".modal-footer").show();\
					$(".modal-footer,.modal-action-close").show();\
				} else {\
					$(".modal-footer,.modal-action-close").hide();\
				}\
			})\
			.fail(function(data) {\
				connectionissue = 1;\
				if(data.status==200 && data.responseText.includes("sign-me-in")){\
					if(!$("#popUp").is(":visible"))\
						tch.showProgress(loginMsg);\
					window.location.href = "/";\
				}\
				if(!$("#popUp").is(":visible"))\
					tch.showProgress(connectionLost + " " + data.statusText);\
			});\
	}\
\
	new modgui.createAjaxUpdateCard("commandlogmodal",null,"CommandLogReadInterval",100,CommandLogReadRefresh);\
  </script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');
