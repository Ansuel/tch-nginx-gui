--pretranslated: do not change this file

local ui_helper = require("web.ui_helper")

ngx.print(ui_helper.createHeader("Changelog", false, false)) 

ngx.print('\
<div class="modal-body no-save fake_console">\
  <fieldset>\
    <form class="form-horizontal" method="post" action="modals/changelog.lp">\
    ');
	  local html = {}

	  html[#html + 1] = '<fieldset style="white-space: pre-wrap" >'
	  html[#html + 1] = 'This is directly downloaded from https://raw.githubusercontent.com/Ansuel/tch-nginx-gui/master/CHANGELOG.md'
	  html[#html + 1] = '<div id="changelog_div">'
	  html[#html + 1] = '</div>'
	  html[#html + 1] = '</fieldset>'
	
	ngx.print(html)
	
ngx.print('\
	</form>\
	<script>\
		tch.showProgress(openMsg);\
		$.ajax({\
		url:"/get_changelog?" + Math.random().toString(36).substr(2, 5)})\
			.done(function(data) {\
				$("#changelog_div").text(data);\
			})\
			.fail(function(data) {\
				$("#changelog_div").text("Can\'t load remote changelog!");\
			});\
		tch.removeProgress();\
</script>\
  </fieldset>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 
