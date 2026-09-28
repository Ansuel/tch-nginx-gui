--pretranslated: do not change this file
gettext.textdomain('webui-dumaos')

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")

local map_params = {
  enabled = "rpc.dumaos.enabled",
  status = "rpc.dumaos.status",
}
local validation = {
  enabled = post_helper.validateBoolean,
}
local content = post_helper.handleQuery(map_params, validation)
local running = content.status == "1"

ngx.print(ui_helper.createHeader(T"DumaOS"))
ngx.print('<div class="modal-body update"><form class="form-horizontal" method="post" action="modals/dumaos-modal.lp">')
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
ngx.print('<fieldset><legend>', T"Service", '</legend>')
ngx.print(ui_helper.createSwitch(T"DumaOS service", "enabled", content.enabled))
ngx.print('<p><strong>', T"Status", ':</strong> ', running and T"Running" or T"Stopped", '</p>')
ngx.print('<p>', T"Stopping DumaOS disables its applications and traffic classification until the service is enabled again.", '</p>')
ngx.print('<p><a class="btn" target="_blank" rel="noopener" href="/desktop/">', T"Open interface", '</a></p>')
ngx.print('</fieldset></form></div>')
ngx.print(ui_helper.createFooter())
