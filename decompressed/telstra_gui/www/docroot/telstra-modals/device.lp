--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/telstra-snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")

-- Localization
gettext.textdomain('webui-telstra')
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local gVCS = post_helper.getValidateCheckboxSwitch()
local gVIES = post_helper.getValidateInEnumSelect
local vNES = post_helper.validateNonEmptyString
local uriargs = ngx.req.get_uri_args()

local devicedesc
local devicemac
local tickedstate

-- only get the mac address when URI contains the mac
if not (uriargs["mac"] == nil and uriargs["ticked"] == nil and uriargs["wireless"] == nil) then
	if uriargs.wireless == "1" then
		devicedesc = "WiFi"
	else
		devicedesc = "Ethernet/Wired"
	end
	devicemac = uriargs.mac
	tickedstate = uriargs.ticked
end


local dcols = {
    {--[1]
        param = "IPAddress",
        type = "text",
    },
    {--[2]
        param = "MACAddress",
        type = "text",
    },
}
-- Load all known network devices

local devices, indexes = content_helper.loadTableData("sys.hosts.host.", dcols)

local deviceip, deviceindex
for k,v in ipairs(devices) do
    if v[2] == devicemac then
        deviceip = v[1]
        deviceindex = indexes[k].paramindex
        break
    end
end

local devtypes = {
    { "", T"Generic"},
    { "Desktop", T"Desktop"},
    { "GS", T"GS"},
    { "IPDECT", T"IPDECT"},
    { "Laptop", T"Laptop"},
    { "PDA", T"PDA"},
    { "Phone", T"Phone"},
    { "STB", T"STB"},
    { "Tablet", T"Tablet"},
    { "Mass Storage", T"Mass Storage"},
}

local mapParams = {
  HostName = "sys.hosts.host." .. deviceindex .. ".HostName",
  DevType = "sys.hosts.host." .. deviceindex .. ".HostType",
}

local mapValid = {
  HostName = function(value, object, key)
    local result, msg = vNES(value)
    if not result then
        return result, msg
    end
    if string.match(value, "|") then
        return nil, "'|' is not allowed"
    end
    if value == "unknown-" .. devicemac then
        object[key] = ""
    end
    return true
  end,
  DevType = gVIES(devtypes),
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
if content.HostName == "" and not helpmsg.HostName then
    content.HostName = "unknown-" .. devicemac
end
 -- Templates for pre-defined rules
local knownapps = require("pfwd_helper")

-- triggered only on a POST with action
local listid
local pfwbasepath = "uci.firewall.userredirect."

if ngx.req.get_method() == "POST" then
	local args = ngx.req.get_post_args()
	if not (args["tableid"] == nil and args["TABLE-NEW-LIST"] == nil and args["listid"] == nil) then
		listid = args["listid"]
	end

	for k,v in ipairs(knownapps) do
		listid = tonumber(listid)
		if k == listid then
			local index = proxy.add(pfwbasepath)
			if index ~= nil then
				proxy.set(pfwbasepath .. index .. ".name", v["values"].name)
				proxy.set(pfwbasepath .. index .. ".enabled", "1")
				proxy.set(pfwbasepath .. index .. ".src_dport", v["values"].wanport)
				proxy.set(pfwbasepath .. index .. ".dest_port", v["values"].lanport)
				proxy.set(pfwbasepath .. index .. ".dest_ip", deviceip)
				proxy.set(pfwbasepath .. index .. ".target", "DNAT")
				proxy.set(pfwbasepath .. index .. ".src", "wan")
				proxy.set(pfwbasepath .. index .. ".family", "ipv4")
				proxy.set(pfwbasepath .. index .. ".dest", "lan")
				local protoindex = proxy.add(pfwbasepath .. index .. ".proto.")
				if protoindex ~= nil then
					proxy.set(pfwbasepath .. index .. ".proto" .. ".@" .. protoindex .. ".value", v["values"].protocol)
				end
			end
		end
	end
end

------------------------------------------
---  start processing for port-forwarding part
------------------------------------------

-- Firewall forwarding rules , only show the common rule name
local pfw_columns = {
    {
        header = "",
        name = "enabled",
        param = "enabled",
        type = "checkboxswitch",
        default = "1",
        attr = { switch = { ["data-placement"] = "right"} },
    },
    {
		header = "",
        name = "name",
        param = "name",
        type = "text",
        attr = { input = { class="span2" } },
    },
}

local pfw_options = {
    tableid = "portforwarding",
    basepath = "uci.firewall.userredirect.",
	createMsg = T"Add new port mapping",
    newList = knownapps,
	canDelete = true,
    canEdit = false,
	canAdd = false,
}

local pfw_attributes = {
	table = {
		style="margin:0px 0px 0px 50px; width:90%;",
	},
}

local pfw_valid = {
    enabled = gVCS,
}

-- Warning, this uses transformer paths. So use correct naming
local pfw_defaultObject = {
}

-- Remove rule that is not belogs to this lan host
local function pfw_filter(data)
    if data.dest_ip == deviceip then
        return true
    end
		return false
end

local pfw_data, pfw_helpmsg = post_helper.handleTableQuery(pfw_columns, pfw_options, pfw_filter, pfw_defaultObject, pfw_valid)

---------------------------------------------------------------------
--------- End of port-forwarding processing
----------------------------------------------------------------------

-- keep the old uri
local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

  ngx.print('\
<div class="container toplevel">\
	<div class="row">\
		<div class="span11">\
			<form id="deviceForm" class="form-horizontal" method="post" action="');  ngx.print( uri ); ngx.print('">\
				<div class="span5">\
					');  
					  ngx.print(ui_helper.createMessages(message_helper.popMessages()), string.format('<img src="/img/telstra/dev_laptop%s.gif">', tickedstate))
					  ngx.print('\
					');  
					  local html = {}
					  html[#html + 1] = ui_helper.createInputText(T"Device Name", "HostName", content.HostName, nil, helpmsg.HostName)
					  html[#html + 1] = ui_helper.createInputSelect(T"Device Type", "DevType", devtypes, content.DevType, nil, helpmsg.DevType)
					  ngx.print(html)
					  lp.include("save.lp")
					  ngx.print('\
				</div>\
				<div class="span5">\
					<div class="span5 container">\
						<fieldset>\
							<legend>');  ngx.print(devicedesc)   ngx.print('</legend>\
							');  
							  local html = {}
							  html[#html + 1] = ui_helper.createLabel(T"LAN IP", deviceip, attributes)
							  ngx.print(html)
							  ngx.print('\
						</fieldset>\
					</div>\
					<div class="span5 container">\
						<fieldset>\
							<legend>');  ngx.print( T"Services" ); ngx.print('</legend>\
							');  
								local html = {}
								html[#html + 1] = ui_helper.createLabel(T"Port Forwarding", "", attributes)
								html[#html + 1] = ui_helper.createTable(pfw_columns, pfw_data, pfw_options, pfw_attributes, pfw_helpmsg)
								ngx.print(html)
							  ngx.print('\
							');  
								local html = {}
								html[#html + 1] = '<div class="btn-group" style="margin:0px 0px 0px 120px;"><div class="btn btn-table"><i class="icon-plus-sign"></i> Add new port mapping</div>'
								html[#html + 1] = '<div tabindex="-1" data-toggle="dropdown" class="btn dropdown-toggle">'
								html[#html + 1] = '<span class="caret"></span></div>'
								html[#html + 1] = '<ul class="dropdown-menu">'
								for k,v in ipairs(knownapps) do
									html[#html + 1] = string.format('<li><a data-listid=%d class="btnaddservice" href="#">%s</a></li>', k, v["values"].name)
								end
								html[#html + 1] = '</ul></div>'
								ngx.print(html)
							  ngx.print('\
						</fieldset>\
					</div>\
				</div>\
			</form>\
		</div>\
	</div>\
</div>\
\
<script type="text/javascript">\
    $(document).on("click", ".btnaddservice", function() {\
		var target = $("form").attr("action");\
		var table = $(this).closest("table");\
		var id = table.attr("id");\
		var line = $(this).closest("tr");\
		var index = line.index();\
		var params = line.find(":input").serializeArray();\
		var add_params = table.find(".additional-edit :input").serializeArray();\
		params = params.concat(add_params);\
		params.push({\
			name : "tableid",\
			value : id\
		});\
		params.push({\
			name : "stateid",\
			value : table.attr("data-stateid")\
		});\
		params.push({\
			name : "action",\
			value : "SAVE"\
		});\
		params.push({\
			name : "index",\
			value : index + 1\
		});\
        params.push({\
            name : "listid",\
            value : $(this).attr("data-listid")\
        });\
		params.push(tch.elementCSRFtoken());\
		tch.postParams(target, params);\
\
	});\
\
</script>\
');  
lp.include("footer.lp")
  ngx.print('\
\
'); 