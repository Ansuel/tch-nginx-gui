--NG-94758 GUI: Mobile card and modal are not completely translated
local intl = require("web.intl")
local function log_gettext_error(msg)
	ngx.log(ngx.NOTICE, msg)
end

local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext

gettext.textdomain('webui-mobiled')

local M = {}

function M.get_params()
    gettext.language(ngx.header['Content-Language'])
    return {
        modal_title = T"Mobile",
        card_title = T"Mobile"
    }
end

return M
