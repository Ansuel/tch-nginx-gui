--NG-70591 GUI : Unable to configure infinite lease time (-1) from GUI but data model allows
local intl = require("web.intl")
local function log_gettext_error(msg)
    ngx.log(ngx.NOTICE, msg)
end
local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext
local N = gettext.ngettext

local function setlanguage()
    gettext.language(ngx.header['Content-Language'])
end

gettext.textdomain('webui-tim')

local M = {}

function M.ethtrans()
	setlanguage()
    return {
				eth_infinit = T"infinite"
			}
end

return M
