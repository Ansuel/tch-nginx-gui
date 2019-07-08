local ui_helper = require("web.ui_helper")

local M = {}

function M.createModalTab(items) 
	
	local uri = ngx.var.uri
	
	local tabs = {}
	local session = ngx.ctx.session
	for _,v in ipairs(items) do
		if session:hasAccess("/modals/" .. v[1]) then
			local active = nil
			if uri == ("/modals/" .. v[1]) then
				active = "active"
			end
	
			local tab = {
				desc = v[2],
				active = active,
				target = "/modals/" .. v[1]
			}
			table.insert(tabs, tab)
		end
	end
	
	ngx.print(ui_helper.createModalTabs(tabs))
	
end

return M