--pretranslated: do not change this file
 
local string = string
local table = { insert = table.insert }
local ngx, type, istainted = ngx, type, string.istainted

-- Enable localization
gettext.textdomain('webui-mobiled')

local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local gAV = post_helper.getAndValidation

local interfaces_basepath = "uci.network.interface.@."
local interfaces_columns = {
	{
		header = T"Linked Profile",
		name = "profile",
		param = "profile",
		type = "label"
	}
}

local function interfaces_filter(data)
	if data.proto ~= "mobiled" then return false end
	return true
end

local interfaces_data = content_helper.loadTableData(interfaces_basepath, interfaces_columns, interfaces_filter)

local profileid_used = {}
for _,v in ipairs(interfaces_data) do
	profileid_used[v[1]] = true
end

local maxAPNSize = 103
local maxFieldSize = 127

local function isValidAPN(value)
	if type(value) ~= "string" and not istainted(value) then
		return nil, T"Received an invalid string"
	end

	if string.len(value) == 0 then
		return true
	end

	if string.len(value) > maxAPNSize then
		return nil, string.format(T"The maximum APN size is %d characters", maxAPNSize)
	end

	return post_helper.validateStringIsDomainName(value)
end

local pdptypes = {
	{ "ipv4",   T"IPv4" },
	{ "ipv6",   T"IPv6" },
	{ "ipv4v6", T"IPv4v6" }
}

local authtypes = {
	{ "none", T"None" },
	{ "pap",   T"PAP" },
	{ "chap",   T"CHAP" }
}

local profile_valid = {
	["apn"] = isValidAPN,
       	["name"] = gAV(post_helper.getValidateStringLengthInRange(1, maxFieldSize), post_helper.isSpaceInString),
	["username"] = gAV(post_helper.getValidateStringLengthInRange(0, maxFieldSize), post_helper.isSpaceInString),
	["password"] = gAV(post_helper.getValidationPassword(post_helper.getValidateStringLengthInRange(0, maxFieldSize)), post_helper.isSpaceInString),
	["pdptype"] = post_helper.getValidateInEnumSelect(pdptypes)
}

local function profile_filter(data)
	if(data.id == "") then
		return { canEdit = true, canDelete = true }
	end
	if(data.visible ~= "1") then
		return false
	end
	if (data.editable == "1") then
		if profileid_used[data.id] then
			return { canEdit = true, canDelete = false }
		else
			return { canEdit = true, canDelete = true }
		end
	end
	return { canEdit = false, canDelete = false }
end

local params = utils.get_params()

local profile_columns = {
	{
		header = T"Name",
		name = "name",
		param = "name",
		type = "text",
                unique = true,
		attr = { input = { class="span2", maxlength="127" } }
	},
	{
		header = T"APN",
		name = "apn",
		param = "apn",
		type = "text",
		attr = { input = { class="span2", maxlength="127" } }
	},
	{
		header = T"PDP Type",
		name = "pdptype",
		param = "pdptype",
		default = "ipv4",
		type = "select",
		values = pdptypes,
		attr = { select = { class="span2" } }
	},
	{
		header = T"Username",
		name = "username",
		param = "username",
		type = "text",
		attr = { input = { class="span2", maxlength="127" } }
	},
	{
		header = T"Password",
		name = "password",
		param = "password",
		type = "text",
		attr = { input = { class="span2", maxlength="127" } }
	},
	{
		header = T"Authentication Type",
		name = "authentication",
		param = "authentication",
		default = "none",
		type = "select",
		values = authtypes,
		attr = { select = { class="span2" } }
	}
}

local profile_options = {
	tableid = "lte_profiles",
	basepath = "uci.mobiled.profile.@.",
	canAdd = true,
	canDelete = true,
	createMsg = T"Add new profile",
	minEntries = 1
}

local reuse_profiles
local uci_path = utils.get_uci_device_path()
if not string.match(uci_path, "device_defaults") then
	local info = {
		reuse_profiles = uci_path .. "reuse_profiles"
	}
	content_helper.getExactContent(info)
	if info then
		reuse_profiles = info.reuse_profiles
	end
end

if reuse_profiles == "1" then
	profile_options = {
		tableid = "lte_profiles",
		basepath = "rpc.mobiled.device.@1.profile.@.",
		canAdd = false,
		canDelete = false
	}
end

local profile_data, profile_helpmsg = post_helper.handleTableQuery(profile_columns, profile_options, profile_filter, nil, profile_valid)
--[[
for k,v in ipairs(profile_data) do
	if v[5] ~= "" then
		v[5] = "********"
	end
end
]]
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(params.modal_title, false, true, nil) ); ngx.print('\
\
<div class="modal-body update" id="lte-body">\
	<form class="form-horizontal" method="post" action="modals/lte-profiles.lp">\
		');  
			local lp = require("web.lp")
			lp.setpath("/www/snippets/")
			lp.include("tabs-mobiled.lp")

			local html = {}
			table.insert(html, "<fieldset><legend>" .. T"Profiles" .. "</legend>")
			table.insert(html, ui_helper.createTable(profile_columns, profile_data, profile_options, nil, profile_helpmsg))
			table.insert(html, "</fieldset>")
			ngx.print(html)
		  ngx.print('\
	</form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 