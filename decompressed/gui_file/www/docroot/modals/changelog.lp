--pretranslated: do not change this file

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")

local function call_popen(cmd)

	local handle = io.popen(cmd)
	local result = handle:read("*a")
	handle:close()

	return result
end

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
      html[#html + 1] = call_popen("curl -m 2 https://raw.githubusercontent.com/Ansuel/tch-nginx-gui/master/CHANGELOG.md")
	  html[#html + 1] = '</div>'
	  html[#html + 1] = '</fieldset>'

	ngx.print(html)

ngx.print('\
	</form>\
  </fieldset>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');
