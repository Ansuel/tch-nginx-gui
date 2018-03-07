<%

-- Enable localization
-- NG-105177 [Workaround] TI [GUI] - Some of the tabs throws Internal server error
gettext.textdomain('webui-voice')

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require ("web.content_helper")
local message_helper = require("web.uimessage_helper")
local service_default = require("transformer.shared.servicedefault")
local append_service = service_default.services.append
local named_uci = service_default.services.named_service_section
local find, format, lower = string.find, string.format, string.lower
local remove, concat = table.remove, table.concat
local role = ngx.ctx.session:getrole()
local html_escape = require("web.web").html_escape
local session = ngx.ctx.session

local tech = false
if session:getrole() == "engineer" then
	tech = true
end

local services_with_dest = {
  ["WARMLINE"] = true,
  ["CFU"] = true,
  ["CFNR"] = true,
  ["CFBS"] = true,
}

local configfiles = {
    ["fxs"] = "mmpbxbrcmfxsdev",
    ["dect"] = "mmpbxbrcmdectdev",
    ["sipdev"] = "mmpbxrvsipdev",
}

local service_status_map = {
    ["0"] = T"Disabled",
    ["1"] = T"Enabled",
}

local function createAttributesString(attributes)
    local attr = {}

    for k,v in pairs(attributes) do
        attr[#attr + 1] = format('%s="%s"', k, html_escape(v))
    end
    return concat(attr, " ")
end

local function createSimpleCheckboxSwitch(name, value)
    local content = {}
    local defaults = {
        checkbox = {
            class = "checkbox"
        },
        input = {
            type = "checkbox",
            name = name,
            id = name
        }
    }
    local label = createAttributesString(defaults["checkbox"])
    local input = createAttributesString(defaults["input"])
    local checked = ""
    if value == "1" or value == true then
       checked = "checked"
       value = "1"
    else
       value = "0"
    end
    content[#content + 1] = format('<label %s>', label)
    content[#content + 1] = format('<input %s value="%s" %s> %s</label>', input, value, checked, "")
    return content
end

local device_types = {"fxs", "dect", "sipdev",}
local device_friendlynames = {}
local content_services = {}
local content_services_sorted = {}
local service_name = {}
local isNamedParam = nil

local function sorting(x,y)
    local cx = x:sub(1,1)
    local cy = y:sub(1,1)

    if cx == cy then
        return x < y
    end
    if cx == "f" then
        return true
    end
    if cx == "s" then
        if cy == "f" then
            return false
        else
            return true
        end
    end
    if cx == "i" then
        return false
    end
end

local function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iterator = function()   -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iterator
end

local services_base_path = "uci.mmpbx.service."

local function getService()
    local type, index, path = nil, 0, ""
    local content = {}
    local results = proxy.get(services_base_path)
    if results then
        for _,v in ipairs(results) do
              if (v.path:match("uci.mmpbx.service.@") ~= nil) then
                  isNamedParam = true
              else
                  isNamedParam = false
              end
              if path == "" or not (((v.path):gsub("%p", {["."] = "_", ["["] = "", ["]"] = ""})):match((path:gsub("%p", {["."] = "_", ["["] = "", ["]"] = ""})))) then
                if type then
                    for kk,vv in pairs(content) do
                        content_services[type][#content_services[type]][kk] = vv
                    end
                    if (not content_services[type][#content_services[type]]["profile"] and not content_services[type][#content_services[type]]["device"]) then    --if profile or devicenot available in the entry we can delete it.
                        remove(content_services[type],#content_services[type])
                    end
                end
                type = nil
                content = {}
                path = v.path
            end

            v.value = string.format("%s", v.value)
            if v.param == "type" then
                type = v.value
                if not content_services[type] then
                    content_services[type] = {}
                end
                content_services[type][#content_services[type] + 1] = {}
                content_services[type][#content_services[type]]["path"] = v.path
            elseif v.param == "value" then
                local t = nil
                if (v.path:gsub("%p", {["["] = "", ["]"] = ""}):match((path:gsub("%p", {["["] = "", ["]"] = ""}) .. "profile"))) then
                    t = "profile"
                elseif (v.path:gsub("%p", {["["] = "", ["]"] = ""}):match((path:gsub("%p", {["["] = "", ["]"] = ""}) .. "device"))) then
                    t = "device"
                end
                if t then
                    if not v.value:match("internal_profile_") then    --Remove internal profiles form profile list
                        if not content_services[type][#content_services[type]][t] then
                            content_services[type][#content_services[type]][t] = {}
                        end
                        index = #content_services[type][#content_services[type]][t]
                        content_services[type][#content_services[type]][t][index + 1] = v.value
                    end
                end
            else
                content[v.param] = v.value
            end
        end
        if type then
            for kk,vv in pairs(content) do
                content_services[type][#content_services[type]][kk] = vv
            end
        end
    end
end

local function sorting_device_table(x,y)
    -- Device type service sorting logic.
    -- The devices types in voice are FXS, DECT & SIPDEV
    -- We need to display the devices in FXS, SIPDEV, DECT order.
    -- For sorting we will take the first letter in the device names i.e. “f”, ”d” & “s” and sort them.
    local cx = x["name"]:sub(1,1)
    local cy = y["name"]:sub(1,1)

    if cx == cy then
        return x["name"] < y["name"]
    end
    if cx == "f" then
        return true
    end
    if cx == "s" then
        if cy == "f" then
            return false
        else
            return true
        end
    end
    if cx == "d" then
        return false
    end

    return true
end

local function sorting_profile_table(x,y)
    -- Profile type service sorting logic.
    -- The profile tyes are SIP & FXO.
    -- We need to disply the profiles in FXO, SIP order.
    return x["name"] < y["name"]
end

local scc_columns = {
    { header = T"Services", },
    { header = T"Register", },
    { header = T"Register & Activate", },
    { header = T"Activate", },
    { header = T"Deactivate", },
    { header = T"Deactivate & Erase", },
    { header = T"Interrogate", },
}

local scc_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "scc",
}

-- SCC column number
local scns = {
    ["service"] = 1,
    ["register"] = 2,
    ["register_activate"] = 3,
    ["activate"] = 4,
    ["deactivate"] = 5,
    ["deactivate_erase"] = 6,
    ["interrogate"] = 7,
}
-- for Service Code Command table
local scc_data = {}
local l = 1

local table_created = false
local related_to = nil

local function createSortedServicesList()
    for k,v in pairsByKeys(content_services) do
        if role ~= "admin" or k == "CALL_WAITING" or k == "WARMLINE"  then
            table_created = false
            for _,w in ipairs(v) do
                if w["provisioned"] == "1" then
                    related_to = nil
                    if w["profile"] then
                        related_to = "profile"
                    elseif w["device"] then
                        related_to = "device"
                    end

                    if not table_created then
                        scc_data[l] = {}
                        scc_data[l][scns["service"]] = k
                        scc_data[l][scns["register"]] = v["register"] or ""
                        scc_data[l][scns["register_activate"]] = v["register_activate"] or ""
                        scc_data[l][scns["activate"]] = v["activate"] or ""
                        scc_data[l][scns["deactivate"]] = v["deactivate"] or ""
                        scc_data[l][scns["deactivate_erase"]] = v["deactivate_erase"] or ""
                        scc_data[l][scns["interrogate"]] = v["interrogate"] or ""
                        l = l + 1
                        service_name[#service_name + 1] = {k, k}
                        content_services_sorted[k] = {}
                        table_created = true
                    end
                    if related_to then
                        for _,x in ipairs(w[related_to]) do
                            content_services_sorted[k][#content_services_sorted[k] + 1] = {}
                            content_services_sorted[k][#content_services_sorted[k]]["related_to"] = related_to
                            content_services_sorted[k][#content_services_sorted[k]]["name"] = x
                            content_services_sorted[k][#content_services_sorted[k]]["path"] = w["path"]
                            if w["activated"] then
                                content_services_sorted[k][#content_services_sorted[k]]["activated"] = w["activated"]
                            end
                            if services_with_dest[k] then
                                content_services_sorted[k][#content_services_sorted[k]]["destination"] = w["destination"]
                            end
                            if w["timeout"] then
                                content_services_sorted[k][#content_services_sorted[k]]["timeout"] = w["timeout"]
                            end
                            if w["cw_reject_persistency"] then
                                content_services_sorted[k][#content_services_sorted[k]]["cw_reject_persistency"] = w["cw_reject_persistency"]
                            end
                            if w["internal_transfer"] then
                                content_services_sorted[k][#content_services_sorted[k]]["internal_transfer"] = w["internal_transfer"]
                            end
                            if w["external_transfer"] then
                                content_services_sorted[k][#content_services_sorted[k]]["external_transfer"] = w["external_transfer"]
                            end
                        end
                    end
                end
            end
            if content_services_sorted[k] then
                if related_to == "device" then
                    table.sort(content_services_sorted[k], sorting_device_table)
                elseif related_to == "profile" then
                    table.sort(content_services_sorted[k], sorting_profile_table)
                end
            end
        end
    end
end

local function getSccEntry()
    local pattern, type, action = nil, nil, nil
    local index, path = 0, ""
    local results = proxy.get("uci.mmpbx.scc_entry.")
    if results then
        for _,v in ipairs(results) do
            if path == "" then
                path = v.path
            end

            if not v.path:match(path) then
                if type and action and pattern then
                    if not content_services[type] then
                        content_services[type] = {}
                    end
                    content_services[type][action] = pattern
                end
                pattern, type, action  = nil, nil, nil
                path = v.path
            end
            v.value = string.format("%s", v.value)
            if v.param == "pattern" then
                pattern = v.value
            elseif v.param == "service_type" then
                type = v.value
            elseif v.param == "action" then
                action = v.value
            end
        end
        if type and action and pattern then
            if not content_services[type] then
                content_services[type] = {}
            end
            content_services[type][action] = pattern
        end
    end
end

local function getDeviceFriendlyNames()
    local devpattern = "([^%._@]+_dev_%d+)"
    local results, dev = nil, ""
    for _,t in ipairs(device_types) do
        results = proxy.get("uci." .. configfiles[t] .. ".device.")
        if results then
            for _,v in ipairs(results) do
                if v.param == "user_friendly_name" then
                    dev = v.path:match(devpattern)
                    device_friendlynames[dev] = string.format("%s", v.value)
                end
            end
        end
    end
end

local function copyTable(orig)
    local copy
    if type(orig) == 'table' then
    copy = {}
    for i,v in pairs(orig) do
        copy[i] = copyTable(v)
    end
    else
    copy = orig
    end
     return copy
end

getService()
getSccEntry()
createSortedServicesList()
getDeviceFriendlyNames()

--Copy data for dispaly and modify
local content_services_display_data = copyTable(content_services_sorted)

local helpmsg = {}
local select_name = nil
local isAppendService = false

if ngx.req.get_method() == "POST" then
    local success = false
    local post_args = ngx.req.get_post_args()
    local mapValid = {}
    local vB = post_helper.validateBoolean

    select_name = string.format("%s", post_args["service_name"])

    -- For security, check for service type if HOLD skip POST processing
    if select_name ~= "HOLD" and select_name then
        isAppendService = (append_service[select_name] ~= nil)
	for i,v in ipairs(content_services_sorted[select_name]) do
            if tonumber(v["activated"]) then
                mapValid["activated_"..select_name.."_" ..i] = vB
            end
            if isAppendService then	--For append service only one row will be present.
                break
            end
        end

	success, helpmsg = content_helper.validateObject(post_args, mapValid)
	if success then
            mapValid = {}
            for i,v in ipairs(content_services_sorted[select_name]) do
                if post_args["activated_"..select_name.."_" ..i] == "1" then    --If the service is activated then only validate text fields.
		    if tonumber(v["cw_reject_persistency"]) then
                        mapValid["cw_reject_persistency_"..select_name.."_" ..i] = vB
                    end
                    if services_with_dest[select_name] then
                        mapValid["destination_"..select_name.."_" ..i] = post_helper.validatePositiveNum
                    end
                    if tonumber(v["timeout"]) then
                        mapValid["timeout_"..select_name.."_" ..i] = post_helper.validatePositiveNum
                    end
                end
                if isAppendService then	--For append service only one row will be present.
                    break
                end
	    end

	    success, helpmsg = content_helper.validateObject(post_args, mapValid)
            if success then
                local config_changed = false
                local apply_cahnges = false
                local content_set = {}
                for i,v in ipairs(content_services_sorted[select_name]) do
                    config_changed = false
                    if post_args["activated_"..select_name.."_" ..i] ~= v["activated"] then
                        v["activated"] = post_args["activated_"..select_name.."_" ..i]
                        config_changed = true
                    end
                    if tonumber(v["cw_reject_persistency"]) and post_args["cw_reject_persistency_"..select_name.."_" ..i] ~= v["cw_reject_persistency"] then
                        v["cw_reject_persistency"] = post_args["cw_reject_persistency_"..select_name.."_" ..i]
                        config_changed = true
                    end
                    if services_with_dest[select_name] and post_args["destination_"..select_name.."_" ..i] ~= v["destination"] then
                        v["destination"] = post_args["destination_"..select_name.."_" ..i]
                        config_changed = true
                    end
                    if tonumber(v["timeout"]) and post_args["timeout_"..select_name.."_" ..i] ~= v["timeout"] then
                        v["timeout"] = post_args["timeout_"..select_name.."_" ..i]
                        config_changed = true
                    end
                    if config_changed then
                        local results = proxy.get(v["path"]..v["related_to"]..".")
                        if (not isAppendService) and (#results > 1) then
                            -- if service is not in append, then new section will be added, to be backward compatible (old GUI behaviour)
                            for _,w in ipairs(results) do
                                if w["value"] == v["name"] then
                                    --Delete the device/profile from existing service section
                                    proxy.del(w["path"])
                                    local new_service_path
                                    if (isNamedParam == true) or (named_uci == true) then
                                        local section_name = format("service_%s_%s",lower(select_name), v["name"])
                                        local new_service = proxy.add(services_base_path, section_name)
                                        new_service_path = services_base_path.."@"..new_service.."."
                                    else
                                        local new_service = proxy.add(services_base_path)
                                        new_service_path = services_base_path..new_service.."."
                                    end
                                    content_set[new_service_path.."type"] = select_name
                                    content_set[new_service_path.."provisioned"] = "1"
                                    content_set[new_service_path.."activated"] =  v["activated"]
                                    if tonumber(v["internal_transfer"]) then
                                        content_set[new_service_path.."internal_transfer"] = v["internal_transfer"]
                                    end
                                    if tonumber(v["external_transfer"]) then
                                        content_set[new_service_path.."external_transfer"] = v["external_transfer"]
                                    end
                                    if tonumber(v["cw_reject_persistency"]) then
                                        content_set[new_service_path.."cw_reject_persistency"] =  v["cw_reject_persistency"]
                                    end
                                    if services_with_dest[select_name] then
                                        content_set[new_service_path.."destination"] =  v["destination"]
                                    end
                                    if tonumber(v["timeout"]) then
                                        content_set[new_service_path.."timeout"] =  v["timeout"]
                                    end
                                    local new_list = proxy.add(new_service_path..v["related_to"]..".")
                                    content_set[new_service_path..v["related_to"]..".@"..new_list..".value"] =  v["name"]

                                    v["path"] = new_service_path
                                    apply_cahnges = true
                                end
                            end
                        else
                            content_set[v["path"].."activated"] =  v["activated"]
                            if tonumber(v["cw_reject_persistency"]) then
                                content_set[v["path"].."cw_reject_persistency"] =  v["cw_reject_persistency"]
                            end
                            if services_with_dest[select_name] then
                                content_set[v["path"].."destination"] =  v["destination"]
                            end
                            if tonumber(v["timeout"]) then
                                content_set[v["path"].."timeout"] =  v["timeout"]
                            end
                            if tonumber(v["internal_transfer"]) then
                                content_set[v["path"].."internal_transfer"] = v["internal_transfer"]
                            end
                            if tonumber(v["external_transfer"]) then
                                content_set[v["path"].."external_transfer"] = v["external_transfer"]
                            end
                            apply_cahnges = true
		        end
		    end
                    if isAppendService then	--For append service only one row will be present.
                        break
                    end
	        end
		if apply_cahnges then
		    local ok, msg = proxy.set(content_set)
                    if  ok then
                        ok, msg = proxy.apply()
			if not ok then
		            ngx.log(ngx.ERR, "apply failed: " .. msg)
			    message_helper.pushMessage(T"Error while applying changes", "error")
			else
		            message_helper.pushMessage(T"Changes saved successfully", "success")
			end
			content_services_display_data[select_name] = copyTable(content_services_sorted[select_name])
		    else
			if type(msg) == "table" then
	                    ngx.log(ngx.ERR, "set failed: " .. msg[1].errmsg)
	                end
                        message_helper.pushMessage(T"Error while saving changes", "error")
                    end
		end
	    else
                for i,v in ipairs(content_services_display_data[select_name]) do
                    if post_args["activated_"..select_name.."_" ..i] ~= v["activated"] then
                        v["activated"] = post_args["activated_"..select_name.."_" ..i]
                    end
                    if tonumber(v["cw_reject_persistency"]) and post_args["cw_reject_persistency_"..select_name.."_" ..i] ~= v["cw_reject_persistency"] then
                        v["cw_reject_persistency"] = post_args["cw_reject_persistency_"..select_name.."_" ..i]
                    end
                    if services_with_dest[select_name] and post_args["destination_"..select_name.."_" ..i] ~= v["destination"] then
                        v["destination"] = post_args["destination_"..select_name.."_" ..i]
                    end
                    if tonumber(v["timeout"]) and post_args["timeout_"..select_name.."_" ..i] ~= v["timeout"] then
                        v["timeout"] = post_args["timeout_"..select_name.."_" ..i]
                    end
                    if isAppendService then	--For append service only one row will be present.
                        break
                    end
                end
	        message_helper.pushMessage(T"Some parameters failed validation", "error")
            end
	else
	    message_helper.pushMessage(T"Some parameters failed validation", "error")
	end
    end
end

-- for Service configuration
local html = {
    [1] = ""
}
local baseclass = "monitor-service_name"
local attribute = {}
local row_num = 0

local function addTableHeader(tableDate, serviceName)
    local tableFirstRow = tableDate[1]
    related_to = tableFirstRow["related_to"]
    --Creating Table Header
    html[#html + 1] =  '<div class="control-group monitor-service_name monitor-' .. serviceName ..'">'
    html[#html + 1] =  '<table class="table table-striped"><thead><tr>'
    if related_to == "profile"  then
        html[#html + 1] = format("<th>%s</th>", T"Profile")
    elseif related_to == "device" then
        html[#html + 1] = format("<th>%s</th>", T"Device")
    end
    if tonumber(tableFirstRow["activated"]) then
        html[#html + 1] = format("<th>%s</th>", T"Activate")
    end
    if tonumber(tableFirstRow["cw_reject_persistency"]) then
        html[#html + 1] = format("<th>%s</th>", T"CW Reject Persistency")
    end
    if services_with_dest[serviceName] then
        html[#html + 1] = format("<th>%s</th>", T"Destination No.")
    end
    if tonumber(tableFirstRow["timeout"]) then
        html[#html + 1] = format("<th>%s</th>", T"TimeOut")
    end
    html[#html + 1] =  "</tr></thead>"
end

local function addTableEnd()
    html[#html + 1] =  "</table>"
    html[#html + 1] =  "</div>"
end

local function addAddServiceInTable(serviceData, serviceName)
    html[#html + 1] = "<tbody>"

    for i,w in ipairs(serviceData) do
        related_to = w["related_to"]
        html[#html + 1] = "<tr>"

        html[#html + 1] = "<td>"
        if related_to == "device" then
            html[#html + 1] =  device_friendlynames[w["name"]]
        else
            html[#html + 1] =  w["name"]
        end
        html[#html + 1] = "</td>"

        if tonumber(w["activated"]) then
            html[#html + 1] = "<td>"
            if serviceName == "HOLD" then
                html[#html + 1] = service_status_map[w["activated"]]
            else
                html[#html + 1] =  createSimpleCheckboxSwitch("activated_"..serviceName.."_" ..i , w["activated"])
            end
            html[#html + 1] = "</td>"
        end
        if tonumber(w["cw_reject_persistency"]) then
            html[#html + 1] = "<td>"
            html[#html + 1] =  createSimpleCheckboxSwitch("cw_reject_persistency_"..serviceName.."_" ..i , w["cw_reject_persistency"])
            html[#html + 1] = "</td>"
        end
        if services_with_dest[serviceName] then
            html[#html + 1] = "<td>"
            html[#html + 1] =  ui_helper.createSimpleInputText("destination_"..serviceName.."_" ..i, w["destination"], nil, helpmsg["destination_"..serviceName.."_" ..i])
            html[#html + 1] = "</td>"
        end

        if tonumber(w["timeout"]) then
            html[#html + 1] = "<td>"
				if tech then
				html[#html + 1] =  ui_helper.createSimpleInputText("timeout_"..serviceName.."_" ..i, w["timeout"], nil, helpmsg["timeout_"..serviceName.."_" ..i])
				else
				html[#html + 1] =  format("<span class='span2 simple-desc'>%s</span>",w["timeout"])
				end
                html[#html + 1] = "</td>"
        end
        html[#html + 1] = "</tr>"
     end
     html[#html + 1] =  "</tbody>"
end

local function addAppendServiceInTable(serviceData, serviceName)
    local tableFirstRow = serviceData[1]
    related_to = tableFirstRow["related_to"]
    html[#html + 1] = "<tbody>"
    local displayData
    local deviceOrProfileName
    for _,w in ipairs(serviceData) do
        if related_to == "device" then
            deviceOrProfileName =  device_friendlynames[w["name"]]
        else
            deviceOrProfileName =  w["name"]
        end
        if displayData then
            displayData = displayData.."<br>"..deviceOrProfileName
        else
	    displayData = deviceOrProfileName
        end
    end
        html[#html + 1] = "<tr>"

        html[#html + 1] = "<td>"
        html[#html + 1] = displayData
        html[#html + 1] = "</td>"

        if tonumber(tableFirstRow["activated"]) then
            html[#html + 1] = '<td style="vertical-align:middle">'
            if serviceName == "HOLD" then
                html[#html + 1] = service_status_map[tableFirstRow["activated"]]
            else
                html[#html + 1] =  createSimpleCheckboxSwitch("activated_"..serviceName.."_" .."1" , tableFirstRow["activated"])
            end
            html[#html + 1] = "</td>"
        end
        if tonumber(tableFirstRow["cw_reject_persistency"]) then
            html[#html + 1] = '<td style="vertical-align:middle">'
            html[#html + 1] =  createSimpleCheckboxSwitch("cw_reject_persistency_"..serviceName.."_" .."1" , tableFirstRow["cw_reject_persistency"])
            html[#html + 1] = "</td>"
        end
        if services_with_dest[serviceName] then
            html[#html + 1] = '<td style="vertical-align:middle">'
            html[#html + 1] =  ui_helper.createSimpleInputText("destination_"..serviceName.."_" .."1", tableFirstRow["destination"], nil, helpmsg["destination_"..serviceName.."_" .."1"])
            html[#html + 1] = "</td>"
        end
        if tonumber(tableFirstRow["timeout"]) then
            html[#html + 1] = '<td style="vertical-align:middle">'
            html[#html + 1] =  ui_helper.createSimpleInputText("timeout_"..serviceName.."_" .."1", tableFirstRow["timeout"], nil, helpmsg["timeout_"..serviceName.."_" .."1"])
            html[#html + 1] = "</td>"
        end
        html[#html + 1] = "</tr>"
     html[#html + 1] =  "</tbody>"
end

for k,v in pairs(content_services_display_data) do
    isAppendService = (append_service[k] ~= nil)
    addTableHeader(v,k)
    if isAppendService then
        addAppendServiceInTable(v,k)
    else
        addAddServiceInTable(v,k)
    end
    addTableEnd()
end

attribute = {
    select = {
        class ="monitor-changes no-save",
    },
}

select_name = select_name or service_name[1]
html[1] = ui_helper.createInputSelect(T"Service Name", "service_name", service_name, select_name, attribute)

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

%>

<%= ui_helper.createHeader(T"Telephony", false, true) %>

<div class="modal-body update">
  <%
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal" method="post" action="<%= uri %>" >
  <%= ui_helper.createMessages(message_helper.popMessages()) %>
   <fieldset>
      <legend><%= T"Config VOIP Services" %></legend>
      <%
        ngx.print(html)
      %>
    </fieldset>
  </form>

  <fieldset>
    <legend><%= T"Service Code Command" %></legend>
    <%= ui_helper.createTable(scc_columns, scc_data, scc_options, nil, nil) %>
  </fieldset>
</div>

<%= ui_helper.createFooter() %>

<script>
$(document).ready(function() {
    $("#save-config").attr("id","save-form");
    $("#save-form").click(function(){
       //Keep data related to currently selected service & remove extra data which is not needed in the POST operation.
       var selected_service = $("#service_name").val();
       $('.modal form input').each(function(){
          if((this.name).indexOf(selected_service) < 0){	// textbox/checkbox name is not related to selected service.
             this.remove();
          }
       });
       $('.modal form input:checked[value="0"]').each(function(){
          $(this).val("1");
       });
       var form = $(".modal form");
       var params = form.serializeArray();
       $('.modal form input[type="checkbox"]:not(:checked)').each(function(){
          if(this.value == "1" || this.value == "0"){
             params.push({name: this.name, value:"0"});
          }
        });
        params.push({
          name : "action",
          value : "SAVE"
        }, {
          name : "fromModal",
          value : "YES"
        }, tch.elementCSRFtoken());
        var target = form.attr("action");
        tch.loadModal(target, params, function (){});
    });
    $('input[type="checkbox"]').change(function(){
        $('#modal-no-change').fadeOut(300);
        $('#modal-changes').delay(350).fadeIn(300);
        return false;	// For stoping the POST
    });
    $('input[type="text"]').change(function(){
        $('#modal-no-change').fadeOut(300);
        $('#modal-changes').delay(350).fadeIn(300);
    });
});
</script>
