--pretranslated: do not change this file

-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")

local rows = {}
local f = io.open("/proc/meminfo", "r")
if f then
	for line in f:lines() do
		local key, value = line:match("^([%w_%(%)]+):%s+(%d+)")
		if key then
			rows[#rows + 1] = { key = key, kb = tonumber(value) }
		end
	end
	f:close()
end

ngx.print('\
');  ngx.print( ui_helper.createHeader("Memoria", false, false) ); ngx.print('\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/memory-modal.lp">\
  </form>\
  <fieldset>\
    <legend>Dettaglio memoria</legend>\
    ');

local html = {}
if #rows == 0 then
	html[#html + 1] = '<div class="alert alert-error">/proc/meminfo non leggibile</div>'
else
	html[#html + 1] = '<table class="table table-striped table-bordered"><thead><tr><th>Voce</th><th>kB</th><th>MB</th></tr></thead><tbody>'
	for i = 1, #rows do
		html[#html + 1] = string.format('<tr><td>%s</td><td>%d</td><td>%.1f</td></tr>', rows[i].key, rows[i].kb, rows[i].kb / 1024)
	end
	html[#html + 1] = '</tbody></table>'
end
ngx.print(html)

ngx.print('\
  </fieldset>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');
