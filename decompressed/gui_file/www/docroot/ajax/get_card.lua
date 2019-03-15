local ngx = ngx

local session = ngx.ctx.session
local cards = require("cards")
local lp = require("web.lp")

local modal

if ngx.req.get_method() == "GET" then
	modal = ngx.req.get_uri_args().modal or false
end

local data = {
	card_string = res or ""
}

if not session:hasAccess(modal) then
	ngx.status = 403
else
	lp.include(cards.get_card_from_modal(modal))
end
ngx.exit(ngx.HTTP_OK)

--/ajax/get_card.lua?modal=/modals/gateway-modal.lp