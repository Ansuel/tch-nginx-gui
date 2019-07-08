-- Copyright © 2015 Technicolor

---
-- A comprehensive network model for Device:2
--
-- @module models.device2.network
--
-- @usage
-- local nwmodel = require "transformer.shared.models.device2.network"

local require = require
local type = type
local tostring = tostring
local error = error
local ipairs = ipairs
local pairs = pairs
local unpack = unpack
local concat = table.concat
local insert = table.insert

local setmetatable = setmetatable
local rawget = rawget

local uciconfig = require("transformer.shared.models.uciconfig").Loader()
local dmordering = require "transformer.shared.models.dmordering"
local xdsl = require("transformer.shared.models.xdsl")

local ucihelper = require("transformer.mapper.ucihelper")
local get_from_uci = ucihelper.get_from_uci
local set_on_uci = ucihelper.set_on_uci
local delete_on_uci = ucihelper.delete_on_uci
local ethBinding = { config = "ethernet", sectionname = "", option = "", default = "" }

local M = {}

local function errorf(fmt, ...)
	error(fmt:format(...), 2)
end

-- This should be filled from the mappings using the register function
local dmPathMap = {
}

--- Valid type names.
--
-- This table is not exported but its fields are the
-- acceptable typeName values.
--
-- @table allTypes
local allTypes = {
	"IPInterface",  -- an IP interface
	"PPPInterface", -- a PPP interface
	"VLAN", -- a VLAN
	"EthLink", -- an Ethernet Link
	"Bridge", -- a bridge
	"BridgePort", -- a single port of a bridge
	"PTMLink", -- "a VDSL interface
	"ATMLink", -- an ADSL link
	"DSLChannel", -- a DSL channel
	"DSLLine", --a DSL line
	"GFASTLine", --a G.fast line
	"EthInterface", -- a physical Ethernet interface
	"WifiRadio", -- a wireless radio
	"WiFiSSID", -- an SSID
	"WiFiAP", -- an AccessPoint
	"GRE", -- a GRE tunnel
}

--- register a datamodel path for resolve
--
-- This function is meant to be called from a mapping file
-- to link an internal type to a datamodel path.
--
-- This makes the model agnostic to the actual datamodel path.
--
-- @param typeName an internal type name (from `allTypes`)
-- @param dmPath the datamodel path
-- @return the typeName if it exists (otherwise an exception is raised)
--
-- @usage
-- local nwmodel = require "transformer.shared.models.device2.network"
-- nwmodel.register("EthInterface", Mapping_.objectType.name)
--
function M.register(typeName, dmPath)
	if not dmPathMap[typeName] then
		dmPathMap[typeName] = dmPath
		return typeName
	else
		errorf("duplicate path mapping for %s->%s have %s", typeName, dmPath, dmPathMap[typeName])
	end
end

local load_model --forward declaration

--- Load the model
--
-- This call will create an in-memory representation of
-- the network config in uci.
--
-- This function will return the same object until the uci
-- config actually changes. So it is safe to call this multiple
-- times.
--
-- @return the model
function M.load()
	return load_model()
end

--- A network config model
--
-- This is the class the exposes the loaded model.
--
-- The model is composed of objects that have a type
-- and a name. The type is one of the names from `allTypes`
-- plus a few internal types that have no representation in the
-- Device:2 datamodel.
--
-- All objects in the model have a unique name.
--
-- @type Model
local Model = {}
Model.__index = Model

local function newModel()
	local obj = {
		all = {},
		typed = {
			loopback = {},
		},
		networks = {},
		key_aliases = {},
		key_ignore = {},
		_explicit_links = {},
	}
	for _, tp in ipairs(allTypes) do
		obj.typed[tp] = {}
	end
	return setmetatable(obj, Model)
end

local function verifyTypeAndName(model, objType, name)
	local list = model.typed[objType]
	local all = model.all
	if not list then
		errorf("Programming Error: Adding unknown type %s is not possible", objType)
	end
	if all[name] then
		errorf("Programming Error: Adding duplicate name %s (%s) is not possible", name, objType)
	end
	return list, all
end

local function newObject(objType, name)
	return {
		type = objType,
		name = name,
		lower = {},
	}
end

function Model:add(objType, name, position)
	local list, all = verifyTypeAndName(self, objType, name)
	local obj = newObject(objType, name)
	if position then
		insert(list, position, obj)
	else
		list[#list+1] = obj
	end
	list[name] = obj
	all[#all+1] = obj
	all[name] = obj

	return obj
end

local function addWithPlaceholder(model, typeName, name, placeholder)
	local placeholder_ignored = false
	local obj = model:get(typeName, name)
	if placeholder then
		-- request to create a placeholder object
		if not obj then
			obj = model:add(typeName, name)
			obj.placeholder = true
		else
			-- otherwise ignore the request, the object already exists
			placeholder_ignored = true
		end
	else
		-- request to create a real object
		if obj then
			-- but it exists already
			if obj.placeholder then
				-- but it was a placeholder, recycle it for the real thing
				obj.placeholder = nil
				-- remove the uci key of the placeholder as it is no longer relevant.
				obj.ucikey = nil
			else
				errorf("Adding duplicate %s object %s is not possible", typeName, name)
			end
		else
			obj = model:add(typeName, name)
		end
	end
	return obj, placeholder_ignored
end

local function raw_model_get(model, objType, name)
	local list
	if objType then
		list = model.typed[objType]
	else
		list = model.all
	end
	if list then
		return list[name]
	end
end

--- get a named object from the model
--
-- @param[opt] objType the typeName (from `allTypes`)
-- @param name the name of the object
--
-- @return the object or nil if not found
--
-- If the type is given the name must refer to an object
-- of the given type.
function Model:get(objType, name)
	if not name then
		name = objType
		objType = nil
	end
	local alias = self.key_aliases[name]
	if alias and (alias.master==name)then
		return raw_model_get(self, objType, alias.slave) or raw_model_get(self, objType, name)
	else
		return raw_model_get(self, objType, name)
	end
end

local keygetters = {
	__index = function(table)
		return rawget(table, "__default")
	end
}
setmetatable(keygetters, keygetters)

function keygetters.__default(model, typeName)
	local keys = {}
	for _, obj in ipairs(model.typed[typeName] or {}) do
		if not obj.hide_in_datamodel and (not model.key_ignore[obj.name]) then
			keys[#keys+1] = obj.name
		end
	end
	return keys
end

function keygetters.BridgePort(model, _, parentKey)
	local keys = {}
	local bridge = model:get("Bridge", parentKey)
	if bridge then
		for _, mbr in ipairs(bridge.members) do
			keys[#keys+1] = mbr
		end
	end
	return keys
end

--- get the object names for a given type
--
-- This is named `getKeys` as it is intended to be used
-- in the entries function of a mapping to return the transformer
-- keys.
--
-- @param typeName the type (from `allTypes`)
-- @param[opt] parentKey the name of the parent object. Needed for bridge ports.
-- @return a table that can be returned directly to transformer
--
-- @usage
-- local model -- cached for reuse in get/set/getall functions
-- function Mapping_.entries()
--   model = nwmodel.load()
--   return model:getKeys("IPInterface")
-- end
--
function Model:getKeys(typeName, parentKey)
	local keys = keygetters[typeName](self, typeName, parentKey)
	return dmordering.sort(keys, typeName)
end

--- get the keys for InterfaceStack.
--
-- This will a list of keys that can be used for
-- the InterfaceStack entries. Each key represents
-- a connection between two network objects in the
-- the model.
--
-- It will ensure the Higher and Lower layer objects
-- will actually resolve to something as empty values
-- are not allowed in the InterfaceStack.
--
-- @usage
-- Mapping_.entries = function()
--   model = nwmodel.load()
--   return model:getStackEntries()
-- end
--
-- @return a new table with the keys
function Model:getStackEntries()
	local stack = {}
	for _, typeName in ipairs(allTypes) do
		for _, obj in ipairs(self.typed[typeName]) do
			if dmPathMap[obj.type] then
				-- the HigherLayer of the entry may not be empty
				local allLower = obj.lower
				if allLower and (#allLower>0) then
					local upper = obj.name
					for _, lower in ipairs(allLower) do
						local lo = self:get(lower)
						if lo and dmPathMap[lo.type] then
							-- the LowerLayer of the entry may not be empty
							stack[#stack+1] = upper..'('..lower..')'
						end
					end
				end
			end
		end
	end
	return stack
end


--- Get the uci key from the transformer key.
--
-- The keys returned from `getKeys` do not reflect the
-- section name to use on uci. Use this function to find
-- out the correct uci section name.
--
-- @param key the key of the object as returned by `getKeys`
-- @return the uci section name
function Model:getUciKey(key)
	local obj = self.all[key]
	if obj then
		local ucikey = obj.ucikey
		if not ucikey then
			ucikey = obj.name:match(":(.+)") or obj.name
			obj.ucikey = ucikey
		end
		return ucikey
	end
end

--- Get the model key of the base object the key refers to
--
-- An interface may refer to another eg wan6.ifname='@wan'
-- so wan6 refers to wan. This function will return 'wan'
-- as that is the base object.
-- In case the interface does not refer another it will return
-- the key of the object. (The object is its own base)
--
-- @param key the key of the object as returned by `getKeys`
-- @return the base object key. This is not the uci section.
--   To get the uci section name use `getUciKey()` on the
--   result.
function Model:getBaseKey(key)
	local obj = self.all[key]
	if obj and obj.refers_to then
		obj = self.all[obj.refers_to]
		if obj and not obj.hide_in_datamodel then
			return obj.name
		end
	end
	return key
end

-- retrieve the Name property of the object
local function objGetName(obj)
	local name = obj._Name
	if not name then
		-- use the name property stripped off of its type prefix
		name = obj.name:match("[^:]*:(.*)") or obj.name
		obj._Name = name
	end
	return name
end

-- retrieve the device property of the given object
local function objGetDevice(obj)
	return obj.device or objGetName(obj)
end

--- Get the device name.
--
-- Most of the object in the model refer to a Linux
-- networking device. Use this function to find out the
-- name of this device.
--
-- In some cases the object does not refer to a device,
-- but this function will still return a bogus name.
--
-- @param key the key as returned by `getKeys`
-- @return the Linux device (which might not exists!)
function Model:getDevice(key)
	local obj = self:get(key)
	if obj then
		return objGetDevice(obj)
	end
end

--- Get the name of the associated interface.
--
-- @param key the key as returned by `getKeys`
-- @return the interface name
function Model:getInterface(key)
	local obj = self.all[key]
	if obj then
		return obj.interface or self:getUciKey(key)
	end
end

--- get the name of the object.
--
-- This will return the logical name of the object
-- that can be used as the value for a Device:2 Name parameter.
--
-- @param key the key as returned by `getKeys`
-- @return the logical name
function Model:getName(key)
	local obj = self.all[key]
	if obj then
		return objGetName(obj)
	end
end

--- Determine if the object is present.
--
-- If an object is not present there is no way
-- to retrieve run-time information from it.
--
-- @param key the key as returned by `getKeys`
-- @return true if the object is present, false if not.
function Model:getPresent(key)
	local obj = self:get(key)
	if obj then
		local present = obj.present
		if present==nil then --explicit check needed, no fn call if set to false!
			if obj._present then
				present = obj:_present()
			end
		end
		return (present==nil) and true or present, obj
	end
end

-- remove all non existing lower references
function Model:checkLower()
	for _, obj in ipairs(self.all) do
		if obj.lower then
			local realLower = {}
			for _, lowerName in ipairs(obj.lower) do
				local lower = self.all[lowerName]
				if lower then
					-- the object exists
					if lower.hide_in_datamodel and lower.linkto then
						-- but is is really a link to another
						lowerName = self.all[lower.linkto] and lower.linkto
					end
					realLower[#realLower+1] = lowerName
				end
			end
			obj.lower = realLower
		end
	end
end

function Model.setLower(obj, lowerName, ...)
	local lowerLayers = {}
	for _, name in ipairs{lowerName, ...} do
		lowerLayers[#lowerLayers+1] = name
	end
	obj.lower = lowerLayers
end

function Model:getLowerLayers(key)
	local lowerLayers = {}
	local present, obj = self:getPresent(key)
	if present and obj then
		for _, lowerName in ipairs(obj.lower) do
			local lower = self:get(lowerName)
			if lower then
				local dmPath = dmPathMap[lower.type]
				if dmPath then
					lowerLayers[#lowerLayers+1] = {dmPath, lowerName}
				end
			end
		end
	end
	return lowerLayers
end

--- get the lowerLayers
--
-- This will implement the LowerLayers Device:2 property
-- @usage
--  LowerLayers = function(mapping, param, key)
--    return model:getLowersLayerResolved(key, resolve)
--  end
--
-- @param key the key as returned by `getKeys`
-- @param resolve the transformer resolve function
-- @param[opt] separator the separator to use, defaults to a comma.
-- @return a string with the LowerLayers
function Model:getLowerLayersResolved(key, resolve, separator)
	if resolve then
		local lower = {}
		for _, layer in ipairs(self:getLowerLayers(key)) do
			-- if the lower name is the slave part of a key alias
			-- translate back to the key returned by getKeys.
			local lowerName = layer[2]
			local alias = self.key_aliases[lowerName]
			if alias and (alias.slave==lowerName) then
				lowerName = alias.master
			end
			lower[#lower+1] = resolve(layer[1], lowerName)
		end
		return concat(lower, separator or ",")
	end
	return ""
end

local function getStackRef(model, stackKey, getUpper, resolve)
	local upper, lower = stackKey:match("^(.*)%((.*)%)$")
	if not upper then
		--  this only happens if called with the wrong key
		return ""
	end
	local key = getUpper and upper or lower
	local obj = model:get(key)
	if not obj then
		-- wrong key provided
		return ""
	end
	local dmPath = dmPathMap[obj.type]
	if dmPath then
		return resolve(dmPath, key) or ""
	else
		return ""
	end
end

--- get the HigherLayer for an InterfaceStack entry.
--
-- @usage
-- Mapping_.get = {
--   HigherLayer = function(mapping, key)
--     return model:getStackHigherResolved(key, resolve)
--   end
-- }
--
-- @param stackKey a key value returned by `getStackEntries`
-- @param resolve the function to resolve the entry.
-- @return the resolved path of the Higher layer
function Model:getStackHigherResolved(stackKey, resolve)
	return getStackRef(self, stackKey, true, resolve)
end

--- get the LowerLayer for an InterfaceStack entry.
--
-- @usage
-- Mapping_.get = {
--   HigherLayer = function(mapping, key)
--     return model:getStackLowerResolved(key, resolve)
--   end
-- }
--
-- @param stackKey a key value returned by `getStackEntries`
-- @param resolve the function to resolve the entry.
-- @return the resolved path of the Lower layer
function Model:getStackLowerResolved(stackKey, resolve)
	return getStackRef(self, stackKey, false, resolve)
end

local function loadEthernet(model)
	local cfg = uciconfig:load("ethernet")
	local ports = cfg.port or {}
	for _, eth in ipairs(ports) do
		model:add("EthInterface", eth['.name'])
	end
	local mapping = cfg.mapping or {}
	for _, map in ipairs(mapping) do
		local port = map.port
		local eth = port and model:get("EthInterface", port)
		if eth and (map.wlan_remote=="1") then
			eth.hide_in_datamodel = true
			eth.wlan_remote = true
		end
	end
end

local function loadDsl(model)
	local cfg = uciconfig:load("xdsl")
	for _, dsl in ipairs(cfg.xdsl or {}) do
		local name = dsl[".name"]
		local line = model:add("DSLLine", "dsl:"..name)
		line.device = name
		local channel = model:add("DSLChannel", name)
		channel.device = name
		model.setLower(channel, line.name)
	end
end

local function loadGFast(model)
	local name = "fast0"
	local line = model:add("GFASTLine", "fast:"..name)
	line.device = name
end

local function xtmObjectPresent(obj)
	if obj.type == 'ATMLink' then
		return xdsl.isADSL()
	elseif obj.type == 'PTMLink' then
		return xdsl.isVDSL()
	end
end

local function loadXtm(model)
	local cfg = uciconfig:load("xtm")
	for _, atm in ipairs(cfg.atmdevice or {}) do
		local dev = model:add("ATMLink", atm[".name"])
		model.setLower(dev, "dsl0")
		dev._present = xtmObjectPresent
	end
	for _, ptm in ipairs(cfg.ptmdevice or {}) do
		local name = ptm['.name']
		local placeholder = ptm['.placeholder']
		if placeholder then
			name = ptm.uciname or name
		end
		local dev, placeholder_ignored = addWithPlaceholder(model, "PTMLink", name, placeholder)
		model.setLower(dev, "dsl0")
		if placeholder and not placeholder_ignored then
			dev.ucikey = ptm['.name']
			dev.present = false
		else
			-- presence is dynamic (not dependent on the actual config)
			dev.present = nil
			dev._present = xtmObjectPresent
		end
	end
end

local function getBridgeDevice(model, bridgeName, member)
	return model:get(member)
		 or model:get("vlan:"..member)
		 or model:get("vlan:"..bridgeName..':'..member)
		 or model:get("link:"..member)
end

local function getBridgeMembers(members)
	local mtp = type(members)
	if mtp == 'string' then
		-- members given as a regular option, blank separated
		local result = {}
		for member in members:gmatch("%S+") do
			result[#result+1] = member
		end
		return result
	elseif mtp == 'table' then
		-- members given as a list option
		return members
	end
	-- any other type should be impossible
	return {}
end

local function getBridgePortName(model, bridgeName, member, portbase)
	if not portbase then
		portbase = bridgeName
		local alias = model.key_aliases[bridgeName]
		if alias and alias.slave==bridgeName then
			-- make sure the ports have same names as the master
			portbase = alias.master or bridgeName
		end
	end
	return portbase..':'..member, portbase
end

local function create_bridge(model, name, members, placeholder)
	local bridge, placeholder_ignored = addWithPlaceholder(model, "Bridge", name, placeholder)
	if placeholder_ignored then
		-- the real brigde object already existed, nothing left to do
		local mgmt = model:get("BridgePort", name..':mgmt')
		return mgmt, bridge
	end
	local memberlist = {}
	bridge.members = memberlist

	-- a bridge can be created without members!!
	members = members or {}

	-- create management port
	local portname, portbase = getBridgePortName(model, name, "mgmt")
	local mgmt = addWithPlaceholder(model, "BridgePort", portname, placeholder)
	mgmt.management = true
	mgmt.device = name
	memberlist[#memberlist+1] = mgmt.name
	local mgmtLower = {}

	-- create members
	for _, member in ipairs(getBridgeMembers(members)) do
		local dev = getBridgeDevice(model, bridge.name, member)
		if dev and dev.wlan_remote then
			-- drop it, it will be added when the wireless is actually loaded
			dev = nil
			-- but remember the association
			-- note that we can have only one external wifi device.
			model.ext_wlan_bridge = bridge.name
		end
		if dev then
			portname = getBridgePortName(model, name, member, portbase)
			local m = addWithPlaceholder(model, "BridgePort", portname, placeholder)
			if placeholder then
				m.present = false
			else
				m.present = nil
			end
			model.setLower(m, dev.name)
			m.device = m.lower[1]
			memberlist[#memberlist+1] = m.name
			mgmtLower[#mgmtLower+1] = m.name
		end
	end

	model.setLower(mgmt, unpack(mgmtLower))
	return mgmt.name, bridge
end

local function map_explicit_link(model, linkedto, linkname)
	model._explicit_links[linkedto] = linkname
end

local function create_explicit_link_objects(model, sections)
	for _, link in ipairs(sections) do
		local linkname = "link:"..link['.name']
		local dev = model:add("EthLink", linkname)
		if link.linkedto then
			map_explicit_link(model, link.linkedto, linkname)
		end
		if link.ifname then
			model.setLower(dev, link.ifname)
			dev.device = link.ifname
		end
	end
end

local function explicit_link_for(model, section)
	return model._explicit_links[section]
end

function Model:explicit_link_for(section)
	return explicit_link_for(self, section)
end

local function create_device(model, s)
	local linkname
	-- add the link first
	if not s['.placeholder'] then
		linkname = explicit_link_for(model, s['.name'])
		if not linkname and (s.dev2_dynamic~="1") then
			linkname = "link:"..s['.name']
			local dev = model:add("EthLink", "link:"..s['.name'])
			if s.ifname then
				model.setLower(dev, s.ifname)
			end
			dev.device = s.name
		end
	else
		linkname = "link:"..s['.name']
	end

	local devtype = s.type or "8021q"
	if (devtype=="8021q") or (devtype=="8021ad") then
		-- create VLAN
		local vlan = model:add("VLAN", "vlan:"..s['.name'])
		vlan._Name = s['.name']
		if s.type then
			vlan.device = s.name
		end
		if s.ifname then
			model.setLower(vlan, linkname)
		elseif s.type then
			local lower = model:get(linkname)
			if lower then
				model.setLower(vlan, lower.name)
			end
		end
	elseif devtype == 'bridge' then
		create_bridge(model, s.name, s.ifname, s['.placeholder'])
	end
end

local function table_index(array, value)
	if array then
		for idx, entry in ipairs(array) do
			if entry==value then
				return idx
			end
		end
	end
	return 0
end

-- find the object with the given type that has the
-- the device property equal to devName
-- return the name and the object if found
-- otherwise return nil
local function findDevice(model, typeName, devName)
	for _, obj in ipairs(model.typed[typeName]) do
		if objGetDevice(obj)==devName then
			return obj.name, obj
		end
	end
end

local function getIPLowerLayer(model, lower_intf)
	if not lower_intf then
		return
	end
	local lower = findDevice(model, "VLAN", lower_intf)
	if not model:get("VLAN", lower) then
		lower = findDevice(model, "EthLink", lower_intf)
		if not lower then
			--find EthIntf base on lower layer
			for _, dev in ipairs(model.typed.EthLink or {}) do
				if table_index(dev.lower, lower_intf)>0 then
					lower = dev.name
					break
				end
			end
		end
		lower = lower or lower_intf
	end
	return lower
end

local function addTableEntry(tbl, entry)
	for _, v in ipairs(tbl) do
		if v==entry then
			-- already in
			return
		end
	end
	tbl[#tbl+1] = entry
end

local function connectsToDevice(model, obj, device)
	if not obj then return end
	if objGetDevice(obj)==device then
		return true
	else
		for _, name in ipairs(obj.lower) do
			local lower = model:get(name)
			if lower and connectsToDevice(model, lower, device) then
				return true
			end
		end
	end
end

local function addBridgePort(model, bridge, lower)
	local lower_dev = objGetDevice(lower)
	for _, mbr in ipairs(bridge.members) do
		if connectsToDevice(model, model:get(mbr), lower_dev) then
			-- already in (directly or indirectly)
			return
		end
	end
	local portname = getBridgePortName(model, bridge.name, lower_dev)
	local port = model:get(portname)
	if not port then
		port = model:add("BridgePort", portname)
		addTableEntry(bridge.members, portname)
	end
	if lower.device then
		port.device = lower.device
	end
	model.setLower(port, lower.name)
	local mgmt = model:get("BridgePort", bridge.name..':mgmt')
	if mgmt and mgmt.management then
		addTableEntry(mgmt.lower, portname)
	end
end

local function create_PPP_interface(model, name, placeholder)
	return addWithPlaceholder(model, "PPPInterface", name, placeholder)
end

local function createPPPInterface(model, s, lower)
	local proto = s.proto
	local name = s['.name']
	local ppp = create_PPP_interface(model, proto .. "-" .. name)
	ppp.proto = proto
	ppp.ucikey = name
	s.device = ppp.name
	if lower then
		model.setLower(ppp, lower)
	end
	return ppp.name
end

local function getDevice(devname, cfg)
	for _, dev in ipairs(cfg.device or {}) do
		if dev.name == devname then
			if dev.type then
				return dev
			else
				-- the device section exist but it is not valid
				-- no need to look further.
				return
			end
		end
	end
end

local function interface_has_ip_layer(s)
	if not s.proto then
		return false
	end
	if s.proto == 'none' then
		return false
	end
	if (s.proto=='static') and not s.ipaddr then
		return false
	end
	if s.proto:match('^gre') then
		return false
	end
	return true
end

local function createIntfLink(model, name, device, lower)
	local link = model:add("EthLink", "link:"..name, 1)
	link.device = device
	model.setLower(link, lower)
	return link.name
end

local function createIntfVlan(model, name, device, vid, lower)
	local vlan = model:add("VLAN", "vlan:"..name)
	vlan._Name = name
	vlan.device = device
	vlan.vid = vid
	model.setLower(vlan, lower)
	return vlan.name
end

local function createIntfLowerLayer(model, s, cfg, ifname)
	local lower
	ifname = ifname or s.ifname
	local linkname = explicit_link_for(model, s['.name'])
	if getDevice(ifname, cfg) then
		-- refers to device section, lower layer is from that device
		lower = getIPLowerLayer(model, ifname)
	elseif linkname then
		lower = linkname
	elseif ifname then
		-- refers to physical device, possibly with a VLAN reference.
		-- create the EthLink (and VLAN) ourselves
		local phys, vid = ifname:match("^([^.]+)%.(%d+)$")
		if not phys then
			phys = ifname
			vid = nil
		end
		if phys == "lo" then
			-- this is the loopback device, no lower layer should be created for it
			return
		end
		-- The link (and VLAN) will be named after the interface.
		-- The config is defined in the interface section so each interface gets its
		-- own link (and VLAN) instance even for the same physical device.
		local name = s['.name']
		local device = s.device or ifname
		-- create the Ethernet link
		lower = createIntfLink(model, name, device, phys)
		-- create the VLAN on top (if any)
		if vid then
			lower = createIntfVlan(model, name, device , vid, lower)
		end
	end
	return lower
end

local function fixup_gre_phys(intf, phys)
	if phys and intf and (intf.proto or ""):match("^gre") then
		return "gre-"..phys
	end
end

local function replaceAliasInterface(phys, cfg)
	local alias = phys:match("^@(.*)")
	if alias then
		local intf = cfg.interface[alias]
		if intf then
			-- in general just take the ifname of the referred to interface
			-- but gre tunnels are an exception
			phys = fixup_gre_phys(intf, alias) or phys
		else
			--referred to interface does not exist
			phys = ""
		end
	else
		phys = fixup_gre_phys(cfg.interface[phys], phys) or phys
	end
	return phys
end

local function ifname_to_device(ifname, cfg)
	if not ifname then
		return
	end
	local devices = cfg.device or {}
	if devices[ifname] then
		-- name refers to a device
		return ifname
	end
	if ifname:match("^@") then
		-- refers to interface
		local intfname = ifname:match("^@([^.]+)")
		local intf = cfg.interface[intfname]
		if intf then
			if intf.proto == "gretap" then
	return ifname:gsub("^@", "gre4t-")
			elseif intf.proto == "grev6tap" then
	return ifname:gsub("^@", "gre6t-")
			elseif intf.proto:match("^gre") then
	return ifname:gsub("^@", "")
			else
	return ifname_to_device(intf.ifname, cfg)
			end
		end
		return
	end
	return ifname:match("^([^.]+)")
end

local function createBridgeMembersLowerLayers(model, s, cfg)
	local members = getBridgeMembers(s.ifname or "")
	for i, mbr in ipairs(members) do
		local phys, vid = mbr:match("^([^.]+)%.(%d+)$")
		if phys then
			phys = replaceAliasInterface(phys, cfg)
			local name = 'br-'..s['.name']..':@'..tostring(i)
			local device = ifname_to_device(mbr, cfg) or mbr
			local lower = createIntfLink(model, name, device, phys)
			createIntfVlan(model, name, device, vid, lower)
			members[i]=name
		end
	end
	return members
end

local function createBridgeInterface(model, s, cfg)
	if s.auto=='0' then
		-- the interface is not enabled, the bridge should not be created.
		return
	end
	local ifname = createBridgeMembersLowerLayers(model, s, cfg)
	local name = s['.name']
	local bridgename = 'br-'..name
	local lower, bridge = create_bridge(model, bridgename, ifname)
	s.device = bridgename
	bridge.ucikey = name
	if interface_has_ip_layer(s) then
		local link = model:add("EthLink", "link:"..name, 1)
		link.ucikey = name
		link.device = bridge.name
		s.device = bridge.name
		model.setLower(link, lower)
		return link.name
	else
		local port = model:get(lower) -- the 'management' port
		-- but in this config it not a management port
		port.management = false
		port.lower = {}
	end
end

-- create_interface may be called recursively in handleAlias to
-- make sure the aliased interface is created before the alias
local create_interface

local function handleAliasInterface(model, s, cfg)
	local ifname = s.ifname
	-- the interface can only be aliased if the ifname option
	-- is a string. Not for a list.
	if type(ifname)=='string' then
		local lower
		local aliased = ifname:match("^@([^.]*)") -- it can contain a dotted vlan eg @gt1.1200
		if aliased then
			local intf = cfg.interface[aliased]
			if intf then
				local intfModel = raw_model_get(model, "IPInterface", intf['.name'])
				if not intfModel then
					intfModel = create_interface(model, intf, cfg)
				end
				if intf.type == 'bridge' then
					lower = 'link:'..intf['.name']
					s.device = lower
				else
					lower = intfModel.lower[1]
					s.device = aliased
				end
			else
				-- this is actually invalid config
				s.ifname = nil
			end
		end
		return lower, aliased
	end
end

function create_interface(model, s, cfg)
	local name = s['.name']
	local intf = raw_model_get(model, "IPInterface", name)
	if intf then
		-- already created
		return intf
	end
	local lower, referend = handleAliasInterface(model, s, cfg)
	if not lower then
		if s.type == 'bridge' then
			lower = createBridgeInterface(model, s, cfg)
		else
			lower = createIntfLowerLayer(model, s, cfg)
		end
	end
	if s.proto and s.proto:match('^ppp') then
					if not explicit_link_for(model, name) then
			lower = createPPPInterface(model, s, lower)
								end
	end
	intf = model:add("IPInterface", name)
	intf.device = s.device or s.ifname
	intf.refers_to = referend
	intf.has_ip_layer = interface_has_ip_layer(s)
	if not intf.has_ip_layer then
		intf.hide_in_datamodel = s.dev2_dynamic~="1"
	end
	local linkto = dmordering.linked("network.interface", name)
	if linkto then
		intf.hide_in_datamodel = true
		intf.linkto = linkto
	end
	model.setLower(intf, lower)
	return intf
end

local function create_gre_tunnel(model, s)
	local proto = s.proto or ""
	if proto:match("^gre") then
		local name = s['.name']
		local gre = model:add("GRE", "gre-"..name)
		gre.ucikey = name
		model.setLower(gre, s.tunlink)
	end
end

local function findNetworkBridge(model, network)
	local intf = model:get("IPInterface", network)
	while intf and (intf.type ~= "Bridge") do
		intf = model:get(intf.device)
	end
	return intf
end

local function create_explicit_ppp_objects(model, all_ppp)
	for _, pppcfg in ipairs(all_ppp) do
		if not pppcfg['.placeholder'] then
		-- a dynanmic one
			local ppp = create_PPP_interface(model, pppcfg['.name'])
			local lower = explicit_link_for(model, pppcfg['.name'])
			if lower then
				model.setLower(ppp, lower)
			end
			if pppcfg.linkedto then
				map_explicit_link(model, pppcfg.linkedto, ppp.name)
			end
		end
	end
end

local function loadNetwork(model)
	local cfg = uciconfig:load("network")

	create_explicit_link_objects(model, cfg.dev2_link or {})
				create_explicit_ppp_objects(model, cfg.ppp or {})

	for _, dev in ipairs(cfg.device or {}) do
		create_device(model, dev)
	end

	for _, intf in ipairs(cfg.interface or {}) do
		create_gre_tunnel(model, intf)
	end

	for _, intf in ipairs(cfg.interface or {}) do
		create_interface(model, intf, cfg)
	end

	for _, pppcfg in ipairs(cfg.ppp or {}) do
		local name = pppcfg.uciname or pppcfg['.name']
								local placeholder = pppcfg['.placeholder']
								if placeholder then
			local ppp, placeholder_ignored = create_PPP_interface(model, name, placeholder)
			if placeholder and not placeholder_ignored then
				ppp.ucikey = pppcfg['.name']
				if pppcfg.interface then
					ppp.interface = pppcfg.interface
				else
					ppp.interface = name:match("^[^-]+%-(.*)") or pppcfg['.name']
				end
				ppp.present = false
									end
		end
	end
end

local function findRemoteWLanInterface(model)
	for _, eth in ipairs(model.typed.EthInterface) do
		if eth.wlan_remote then
			return eth.name
		end
	end
end

local function addSSID(model, radio, name)
	local ssid = model:add('WiFiSSID', name)
	if radio.remote then
		ssid.device = radio.device
	else
		ssid.device = ssid.name
	end
	model.setLower(ssid, radio.name)
	return ssid
end

local function load_wifi_devices(model, cfg)
	for _, radioCfg in ipairs(cfg['wifi-device'] or {}) do
		local radio = model:add("WifiRadio", radioCfg['.name'])
		if radioCfg.type=='quantenna' then
			radio.remote = true
			radio.device = findRemoteWLanInterface(model)
		end
	end
end

local function load_wifi_ifaces(model, cfg)
	for _, ssidCfg in ipairs(cfg['wifi-iface'] or {}) do
		local radio = model:get('WifiRadio', ssidCfg.device)
		local bridge
		if radio.remote then
			if model.ext_wlan_bridge then
				bridge = model:get('Bridge', model.ext_wlan_bridge)
			end
		end
		if not bridge then
			bridge = findNetworkBridge(model, ssidCfg.network or 'lan')
		end
		local intf = ssidCfg.network and model:get("IPInterface", ssidCfg.network)
		if radio and bridge then
			local ssid = addSSID(model, radio, ssidCfg['.name'])
			addBridgePort(model, bridge, ssid)
		elseif radio and intf then
			addSSID(model, radio, ssidCfg['.name'])
		elseif ssidCfg['.placeholder'] then
			local ssid = model:add("WiFiSSID", ssidCfg['.name'])
			ssid.present = false
		end
	end
end

local function load_wifi_aps(model, cfg)
	for _, apCfg in ipairs(cfg['wifi-ap'] or {}) do
		local name = apCfg['.name']
		local placeholder = apCfg['.placeholder']
		if placeholder then
			name = apCfg.uciname or name
		end
		local ap = addWithPlaceholder(model, "WiFiAP", name, placeholder)
		ap.ucikey = apCfg['.name']
		local iface = apCfg.iface
		if iface then
			model.setLower(ap, iface)
		end
	end
end

local function load_wireless(model)
	local cfg = uciconfig:load("wireless")

	load_wifi_devices(model, cfg)
	load_wifi_ifaces(model, cfg)
	load_wifi_aps(model, cfg)
end

local function loadOrdering(model)
	local cfg = uciconfig:load("dmordering")
	local aliases = {}
	local ignore = {}
	for _, alias in ipairs(cfg.alias or {}) do
		local master = alias.master
		local slave = alias.slave
		if master and slave then
			aliases[master] = alias
			aliases[slave] = alias
			ignore[slave] = true
		end
	end
	model.key_aliases = aliases
	model.key_ignore = ignore

	local bridgeports = {}
	for _, bridge in ipairs(cfg.bridgeports or {}) do
		local name = bridge.name or bridge['.name']
		bridgeports[name] = bridge.port
	end

	return bridgeports
end

local function replaceObject(model, obj, otherName)
	local other = otherName and model:get(otherName)
	if not other or (obj.type ~= other.type) then
		return
	end
	-- erase obj but keep name
	for k in pairs(obj) do
		if k~='name' then
			obj[k] = nil
		end
	end
	-- set new values
	for k, v in pairs(other) do
		if k~='name' then
			obj[k] = v
		end
	end
end

local function fixupBridgePorts(model, bridgeports)
	for bridgeName, ports in pairs(bridgeports) do
		local bridge = model:get('Bridge', bridgeName)
		if bridge then
			-- create the correct portnames:
			local mgmt = getBridgePortName(model, bridge.name, 'mgmt')
			local portnames = {}
			local dropPort -- this was moved to mgmt
			for i, port in ipairs(ports) do
				if i==1 then
					-- the first port must always be named after mgmt port
					portnames[1] = mgmt
					dropPort = getBridgePortName(model, bridge.name, port)
				else
					portnames[i] = getBridgePortName(model, bridge.name, port)
				end
			end
			local currentMembers = {}
			for _, port in pairs(bridge.members) do
				if port~=dropPort then
					currentMembers[#currentMembers+1] = port
					currentMembers[port] = true
				end
			end
			local newMembers = {}
			for i, portName in ipairs(portnames) do
				local port = model:get('BridgePort', portName)
				if not port then
					port = addWithPlaceholder(model, "BridgePort", portName, true)
				elseif i==1 then
					-- handle the 'mgmt' port
					if not port.management and ports[1]~='-' then
						replaceObject(model, port, dropPort)
					end
				end
				newMembers[#newMembers+1] = portName
				currentMembers[portName] = nil
			end
			for _, portName in ipairs(currentMembers) do
				if currentMembers[portName] then
					newMembers[#newMembers+1] = portName
					currentMembers[portName] = nil
				end
			end
			bridge.members = newMembers
		end
	end
end

local current_model

load_model = function()
	if not current_model or uciconfig:config_changed() then
		local model = newModel()
		-- first load the aliases and orderings. Some load functions require them to
		-- be already set up in order o create the correct keys.
		local bridgeports = loadOrdering(model)
		model:add("loopback", "lo")
		loadEthernet(model)
		loadDsl(model)
		loadGFast(model)
		loadXtm(model)
		loadNetwork(model)
		load_wireless(model)
		fixupBridgePorts(model, bridgeports)
		model:checkLower()
		current_model = model
	end
	return current_model
end

function M.invalidate()
	current_model = nil
end

-- Function to get the ShapingRate value from the ethernet config
local function getEthUciValue(devName, option, default)
	ethBinding.sectionname = devName
	ethBinding.option = option
	ethBinding.default = default
	return get_from_uci(ethBinding) or ""
end

-- Function to set the ShapingRate value in the ethernet config
local function setEthUciValue(value, sectionName, option)
	ethBinding.sectionname = sectionName
	ethBinding.option = option
	set_on_uci(ethBinding, value, commitapply)
end

function M.getShapingRate(devName, key)
	local trafficDesc = getEthUciValue(devName, "td", "")
	if trafficDesc ~= "" then
		local value = getEthUciValue(trafficDesc, "max_bit_rate", "")
		return value ~= "" and tostring(tonumber(value) * 1000) or "-1"
	end
	return "-1"
end

local function remove_trafficdesc_section(devName, td_name)
	ethBinding.sectionname = td_name
	ethBinding.option = nil
	delete_on_uci(ethBinding, commitapply)
	setEthUciValue("", devName, "td")
	return true
end

-- Function to set the ShapingRate value
local function shaping_set(devName, shapingValue)
	setEthUciValue(shapingValue.max_bit_rate, devName, "max_bit_rate")
	setEthUciValue(shapingValue.max_burst_size, devName, "max_burst_size")
	setEthUciValue(shapingValue.rate, devName, "rate")
	setEthUciValue(shapingValue.ratio, devName, "ratio")
	return true
end

function M.setShapingRate(value, key, devName)
	value = tonumber(value)
	local max_burst_size = "2000"
	if value then
		local trafficdesc = getEthUciValue(devName, "td", "")
		local new_td_name = "td" .. devName
		if trafficdesc ~= "" then
			max_burst_size = getEthUciValue(trafficdesc, "max_burst_size", "2000")
		end
		if trafficdesc == "" and value == -1 then
			return true
		elseif value == 0 then
			return nil, "Not supported"
		elseif trafficdesc == "" and (value > -1) and (value <= 100) then
			set_on_uci(ethBinding, new_td_name, commitapply)
			setEthUciValue("trafficdesc", new_td_name)
			return shaping_set(new_td_name, { max_bit_rate = value, max_burst_size = max_burst_size, rate = "", ratio = "enabled", })
		elseif trafficdesc == "" and (value > 100) then
			if value < 1000 then
	return nil, "Absolute value should be at least 1000 bps"
			end
			set_on_uci(ethBinding, new_td_name, commitapply)
			setEthUciValue("trafficdesc", new_td_name)
			return shaping_set(new_td_name, { max_bit_rate = value/1000, max_burst_size = max_burst_size, rate = "enabled", ratio = "" })
		elseif trafficdesc ~= "" and value == -1 then
			return remove_trafficdesc_section(devName, trafficdesc)
		elseif trafficdesc ~= "" and (value > -1) and (value <= 100) then
			return shaping_set(new_td_name, { max_bit_rate = value, max_burst_size = max_burst_size, rate = "", ratio = "" })
		elseif trafficdesc ~= "" and (value > 100) then
			if value < 1000 then
	return nil, "Absolute value should be at least 1000 bps"
			end
			return shaping_set(new_td_name, { max_bit_rate = value/1000, max_burst_size = max_burst_size, rate = "enabled", ratio = "" })
		end
	end
	return nil,"Not supported"
end

return M
