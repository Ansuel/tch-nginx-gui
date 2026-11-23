--pretranslated: do not change this file

gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local download = io.popen([[text=$(curl -kfLsS -m 5 https://raw.githubusercontent.com/Ansuel/tch-nginx-gui/master/CHANGELOG.md) && printf '%s' "$text"]])
local changelog = download and download:read("*a") or ""
if download then download:close() end

ngx.print(ui_helper.createHeader(T"Changelog", false, false))
ngx.print('<div class="modal-body no-save">')
if changelog ~= "" then
  ngx.print('<pre style="white-space:pre-wrap;overflow-wrap:break-word">', string.taint(changelog), '</pre>')
else
  ngx.print('<p>', T"Unable to download the changelog.", '</p>')
  ngx.print('<a target="_blank" rel="noopener noreferrer" href="https://github.com/Ansuel/tch-nginx-gui/blob/master/CHANGELOG.md">')
  ngx.print(T"View changelog on GitHub", '</a>')
end
ngx.print('</div>', ui_helper.createFooter())
