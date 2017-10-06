
local require = require
local tonumber = tonumber
local popen = io.popen
local pcall = pcall

local ubus

local M = {}

local xdsl_mode = "NONE"

local function getXdslMode()
    local dsl_supported, dsl = pcall(require,"transformer.shared.xdslctl")
    local line
    if dsl_supported then
        line = dsl.infoValue('tpstc')
    end

	if not line then
		return "NONE"
	end

	return line:match("%S+") or "NONE"
end

local listener
local function update_mode(mode)
	if mode~=xdsl_mode then
		xdsl_mode, mode = mode, xdsl_mode
		if listener then
			pcall(listener, xdsl_mode, mode)
		end
	end
end

local function xdsl_listener(event)
	if tonumber(event.statuscode)~=5 then
		update_mode("NONE")
	else
		update_mode(getXdslMode())
	end
end

local function start_listening()
	if not ubus then
		ubus = require("transformer.mapper.ubus").connect()
		ubus:listen({xdsl=xdsl_listener})
		xdsl_mode = getXdslMode()
	end
end

function M.mode()
	start_listening()
	return xdsl_mode
end

function M.isADSL()
	start_listening()
	return xdsl_mode=='ATM'
end

function M.isVDSL()
	start_listening()
	return xdsl_mode=='PTM'
end

function M.main()
	if not ubus then
		local uloop = require 'uloop'
		uloop.init()
		listener = function(new, old)
			print("xdsl changed from "..old.." to "..new)
		end
		start_listening()
		print("current mode is "..xdsl_mode)
		uloop.run()
	end
end

return M
