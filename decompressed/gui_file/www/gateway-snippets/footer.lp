--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local format = string.format

local cui = {
	timestamp = "uci.version.version.@version[0].timestamp",
	gui_version = "rpc.system.modgui.gui_version",
	friendly_product_name = "uci.env.var.prod_friendly_name",
	provisioning_code = "uci.env.var.provisioning_code",
}

content_helper.getExactContent(cui)

local year = cui.timestamp
local current_year = string.sub(year,1,4)

if cui.friendly_product_name then
	if cui.provisioning_code == "Telstra" then
		cui.friendly_product_name = cui.friendly_product_name:gsub("Technicolor", cui.provisioning_code)  -- Change Telstra
	elseif friendly_product_name == "AGHP" then
		cui.friendly_product_name = "AGTHP" -- Wrong product name by telecom!
	end
end

local lang_credit = ""

if tostring(gettext.language()) == "it-it" then
	lang_credit = "DarkNiko, bovirus"
elseif tostring(gettext.language()) == "de-de" then
	lang_credit = "meyergru"
end

local html = {}

html[#html+1] =		'<div id="footer" class="row">'
html[#html+1] =			'<div class="copyright">'
html[#html+1] =				format('<p>&copy; Technicolor %s</p>', current_year)
html[#html+1] =				format(T'<p>%s GUI Version ', cui.friendly_product_name)
if session:hasAccess("/modals/changelog.lp") then
	html[#html+1] =					format('<a href data-toggle="modal" data-remote="modals/changelog.lp">%s</a>', cui.gui_version)
else
	html[#html+1] =					format('%s', cui.gui_version)
end
html[#html+1] =				'</p>'
html[#html+1] =				T'<p>Coded & Expanded by <font style="color:#0088cc;">Ansuel</font> and <a href="https://github.com/Ansuel/tch-nginx-gui/graphs/contributors">these GitHub users.</a><br/>Unlock Utility by <font style="color:#0088cc;">ADeltaX</font>'

if not ( tostring(gettext.language()) == "en-us" ) then
	html[#html+1] =			format(T' && Translated by <font style="color:#0088cc;">%s</font>',lang_credit)
end
html[#html+1] =				'</p>'
html[#html+1] =			'</div>'
html[#html+1] =		'</div>'

ngx.print(html)

ngx.print('\
<script>\
var processMsg=\'');  ngx.print(T"Processing"); ngx.print('\';\
var openMsg = \'');  ngx.print(T"Loading..."); ngx.print('\';\
var waitMsg = \'');  ngx.print(T"Please wait..."); ngx.print('\';\
var okButton = \'');  ngx.print(T"Ok"); ngx.print('\';\
var cancelButton = \'');  ngx.print(T"Cancel"); ngx.print('\';\
function httpErrorMessage(err, modal, status){\
	var message;\
	switch(status === "timeout" ? 408 : err && err.status){\
		case 500:\
			message=\'');  ngx.print(T"Internal Server Error occured, please contact administrator"); ngx.print('\';\
			break;\
		case 404:\
			message=\'');  ngx.print(T"The requested file is not found! Please try again after some time"); ngx.print('\';\
			break;\
		case 503:\
			message=\'');  ngx.print(T"The server is currently unavailable, Please try again after some time"); ngx.print('\';\
			break;\
		case 408:\
			message=\'');  ngx.print(T"The server timed out waiting for the request"); ngx.print('\';\
			break;\
		default:\
			message=\'');  ngx.print(T"The request could not be performed due to some error"); ngx.print('\';\
	};\
	var body = modal.find(".modal-body").first();\
	if (!body.length) body = $("<div>").addClass("modal-body").appendTo(modal);\
	body.children(".modal-load-error").remove();\
	$("<div>").addClass("alert alert-error modal-load-error").attr("role", "alert").text(message).prependTo(body);\
	body.scrollTop(0);\
}\
</script>\
');
