local ngx = ngx

local session = ngx.ctx.session
local cards = require("cards")
local lp = require("web.lp")

local modal

if ngx.req.get_method() == "GET" then
	modal = ngx.req.get_uri_args().modal or false
end

local card = cards.get_card_from_modal(modal) or nil

if not card then
	ngx.status = 403
else
	lp.include(card)
end
ngx.exit(ngx.HTTP_OK)