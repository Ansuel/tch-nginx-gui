--pretranslated: do not change this file

-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")

local header = '<span id="header_title">'..T"Executing"..'</span><span id="show_progress"></span>'

ngx.print('\
\
');  ngx.print(ui_helper.createHeader(header, false, false))   ngx.print('\
<div class="modal-body update">\
  <form class="form-horizontal" id="commandlogmodal" method="post" action="/modals/command-log-read-modal.lp">\
	')

local html = {}

html[#html + 1] = '<fieldset class="modal-body hide" id="upgrade-gui-bar" style="min-height: unset;">'
html[#html + 1] = '<div class="alert alert-info">'
html[#html + 1] = '<div><span id="update-text">'..T"Update in progress..."..'</span><span id="extracted_file" class="hide">0</span></div>'
html[#html + 1] = '  <div id="upgrade-gui-bar" class="progress progress-striped active">'
html[#html + 1] = '	<div class="bar bar-warning" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" >'
html[#html + 1] = '</div></div></div>'
html[#html + 1] = '</fieldset>'
html[#html + 1] = '<fieldset>'
html[#html + 1] = '<div style="white-space: pre-wrap" class="fake_console" data-bind="log_text: log">'
html[#html + 1] = '</div>'
html[#html + 1] = '</fieldset>'

ngx.print(html)

ngx.print('\
  </form>\
</div>\
  <script>\
	var CommandLogReadRefresh = function CommandLogReadRefresh(ElementBinding) {\
		$(".modal-footer,.modal-action-close").hide();\
		$.post("/ajax/commandlogread.lua?auto_update=true", [tch.elementCSRFtoken()], function (data) {\
			ElementBinding.log(data.log);\
		}, "json")\
			.done(function(data) {\
				var header_text = $("#header_title").text();\
				if (header_text != data.state) $("#header_title").text(data.state);\
				$("#show_progress").text($("#show_progress").text().replace(/[\\.]{10}/g, ""));\
				$("#show_progress").append(".");\
				if(data.state == "Complete"){\
					clearInterval(KoRequest.CommandLogReadInterval.interval);\
					$(".modal-footer").show();\
					$(".modal-footer,.modal-action-close").show();\
				}\
			})\
			.fail(function(data) {\
				if(data.status==200 && data.responseText.includes("sign-me-in")){\
					$(".modal-footer").show();\
					$(".modal-footer,.modal-action-close").show();\
					clearInterval(KoRequest.CommandLogReadInterval.interval);\
				}\
				$("#show_progress").append(\'<span style="color: red;">.</span>\');\
			});\
	}\
\
	new modgui.createAjaxUpdateCard("commandlogmodal",null,"CommandLogReadInterval",100,CommandLogReadRefresh);\
  </script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');
