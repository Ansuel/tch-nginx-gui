--pretranslated: do not change this file
 
local table = table
local utils = require("web.lte-utils")
local device_capabilities = utils.getContent("rpc.mobiled.device.@1.capabilities.")

local ngx = ngx

gettext.textdomain('webui-mobiled')

local ui_helper = require("web.ui_helper")
local ipairs, string = ipairs, string
local tinsert = table.insert

local items = {
	{"lte-modal.lp", T"Configuration"},
	{"lte-sim.lp", T"SIM"},
	{"lte-doctor.lp", T"LTE Doctor"},
	{"lte-profiles.lp", T"Profiles"}
}

-- #NG-93140 only show in case session has access (Engineer in case of TI)
if device_capabilities.sms_reading == "true" and ngx.ctx.session:hasAccess("/ajax/sms.lua") then
	table.insert(items, {"lte-sms.lp", T"SMS"})
end

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
	uri = uri .. "?" .. ngx.var.args
end

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
        tinsert(tabs, tab)
    end
end

ngx.print(ui_helper.createModalTabs(tabs))
  ngx.print('\
'); 