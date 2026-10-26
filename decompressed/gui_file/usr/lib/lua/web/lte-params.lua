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
       card_title = T"Mobile",
       modal_title = T"Mobile",
    }
end
return M
