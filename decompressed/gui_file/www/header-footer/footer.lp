--pretranslated: do not change this file

-- Enable localization

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local format = string.format

local cui = {
	timestamp = "uci.version.version.@version[0].timestamp",
	gui_version = "uci.env.var.gui_version",
}

content_helper.getExactContent(cui)

local year = cui.timestamp
local current_year = string.sub(year,1,4)

local lang_credit = ""

if tostring(gettext.language()) == "it-it" then
	lang_credit = "DarkNiko"
elseif tostring(gettext.language()) == "de-de" then
	lang_credit = "meyergru"
end

local html = {}

html[#html+1] =		'<div id="footer" class="row">'
html[#html+1] =			'<div class="copyright span12">'
html[#html+1] =				format('<p>&copy; Technicolor %s </p>', cui.gui_version)
html[#html+1] =				format('<p>GUI Version [ %s ] 2018 ',cui.gui_version)
							if session:hasAccess("/modals/changelog.lp") then
html[#html+1] =					'<a href data-toggle="modal" data-remote="modals/changelog.lp">Changelog</a>'
							end
html[#html+1] =				'</p>'
html[#html+1] =				'<p>Coded & Expanded by <font style="color:#0088cc;">Ansuel</font> && Unlock Utility by <font style="color:#0088cc;">ADeltaX</font>'
							if not ( tostring(gettext.language()) == "en-us" ) then
html[#html+1] =					' && Translated by <font style="color:#0088cc;">' .. lang_credit .. '</font>'
							end
html[#html+1] =				'</p>'
html[#html+1] =			'</div>'
html[#html+1] =		'</div>'

ngx.print(html)