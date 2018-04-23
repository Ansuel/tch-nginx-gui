<%
-- Enable localization
-- NG-79256, on 29.11. change reverted back to original value, since generic Fix to come
-- NG-81922
gettext.textdomain("webui-voice")

local proxy = require ("datamodel")
local content_helper = require ("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
-- added because present in 7221 baseline
local message_helper = require("web.uimessage_helper")
local table, ipairs = table, ipairs

local sipnet_options={}
for i,v in ipairs(proxy.getPN("uci.mmpbxrvsipnet.network.", true)) do
    local sipnet = string.match(v.path, "uci%.mmpbxrvsipnet%.network%.@([^%.]+)%.")
    if sipnet then
        local sipnet_name = proxy.get(v.path .. "user_friendly_name")[1].value
        sipnet_options[#sipnet_options+1]={sipnet, sipnet_name}
    end
end

local devMap={}
local dev_config = { "mmpbxbrcmfxsdev", "mmpbxbrcmdectdev", "mmpbxrvsipdev",}

local function getDeviceFriendlyNames()
    local devpattern = "([^%._@]+_dev_%d+)"
    for _,v in pairs(dev_config) do
        local results = proxy.get("uci." .. v .. ".device.")
        if results then
            for _,vv in ipairs(results) do
                if vv.param == "user_friendly_name" then
                    local dev = vv.path:match(devpattern)
                    devMap[dev] = string.format("%s",vv.value)
                end
            end
        end
    end
end
getDeviceFriendlyNames()

-- sip columns
local sip_columns = {
    { --[1]
        header = "",
        name = "enable",
        param = "enabled",
        type = "switch",
        default = "1",
        attr = { switch = { ["data-placement"] = "right" } },
    },
    { --[2]
        header = T"SIP Profile",
        name = "profile",
        param = "paramindex",
        type = "label",
        readonly = true,
        attr = { input = { class="span1" } },
    },
    { --[3]
        header = T"UserName",
        name = "username",
        param = "user_name",
        type = "text",
        attr = { input = { class="span1" } },
    },
    { --[4]
        header = T"URI",
        name = "uri",
        param = "uri",
        type = "text",
        attr = { input = { class="span1" } },
    },
    { --[5]
        header = T"Password",
        name = "password",
        param = "password",
        type = "password",
        attr = { input = { class="span1" } },
    },
    { --[6]
        header = T"DisplayName",
        name = "displayName",
        param = "display_name",
        type = "text",
        attr = { input = { class="span1"} },
    },
    { --[7]
        header = T"SIP Network",
        name = "network",
        param = "network",
        type = "select",
        values = sipnet_options,
        attr = { select = { class="span2" } },
    },
    { --[8]
        header = T"Registered",
        name = "registerStatus",
        type = "light",
    },
    { --[9]
        header = T"Call Status",
        name = "callStatus",
        type = "light",
    },
}

local internal_columns = {
    { --[1]
        header = T"Internal Profile",
        name = "profile",
        param = "paramindex",
    },
    { --[2]
        header = T"Number",
        name = "number",
        param = "number",
    },
    { --[3]
        header = T"Port",
        name = "port",
        param = "port",
    },
    { --[4]
        header = T"Enabled",
        name = "enable",
        param = "enabled",
    },
}

-- Identify sip table column number
local scns = {
    ["enable"] = 1,
    ["profile"] = 2,
    ["username"] = 3,
    ["uri"] = 4,
    ["password"] = 5,
    ["displayName"] = 6,
    ["network"] = 7,
    ["register"] = 8,
    ["call"] = 9,
}

-- Identify internal table column number
local icns = {
    ["port"] = 3,
    ["enable"] = 4,
}

local pattern = "(([^%._@]+)_profile_(%d+))"
local function sort_func(a, b)
    local _, _, a_num = a.paramindex:match(pattern)
    local _, _, b_num = b.paramindex:match(pattern)
    if tonumber(a_num) < tonumber(b_num) then
       return true
    else
       return false
    end
end

local function validateUri(value, object, key)
    local post_args = ngx.req.get_post_args()
    local uri = string.format("%s", value)
    if #uri == 0 then
        return nil, T"Please set URI."
    end
    if string.find(uri, "%s") then
        return nil, "Invalid URI, space not allowed"
    end
    local i =1
    while post_args["isRowDeleted."..i] or post_args["isRowAdded."..i] do
	if (key ~= "uri."..i) and ((post_args["isRowDeleted."..i] == "0") or (post_args["isRowAdded."..i] == "1")) then
	   if post_args["uri."..i] == uri then
		return nil, T"This URI has already existed, please input one not existed."
	   end
	end
	i = i + 1
    end
    return true
end

local function validateNonspaceString(value, object, key)
    if value == "" then
        return nil, T"Please set value."
    end
    if string.find(string.format("%s", value), "%s") then
        return nil, T"Invalid value, space not allowed"
    end
    return true
end

local mask_password = "********"
local function validatePassword(value, object, key)
    local password = string.format("%s", value)
    if #password == 0 then
        return nil, T"Please set password."
    end
    if string.find(password, "%s") then
        return nil, "Invalid password, space not allowed"
    end
    if password == mask_password then
        object[key] = nil
    end
    return true
end

local function copyTable(orig)
    local copy
    if type(orig) == 'table' then
	copy = {}
	for i,v in ipairs(orig) do
		copy[i] = copyTable(v)
	end
    else
	copy = orig
    end
     return copy
end

local basepath = "rpc.mmpbx.sip_profile.@."
local sip_data,allowedIndexes = content_helper.loadTableData(basepath, sip_columns, nil, sort_func)

for _,v in pairs(sip_data) do
    v[scns["password"]] = mask_password
    local name = v[scns["profile"]]
    local states = {
        regstate  = "rpc.mmpbx.profile.@" .. name .. ".sipRegisterState",
        callstate  = "rpc.mmpbx.profile.@" .. name .. ".callState"
    }
    content_helper.getExactContent(states)

    local regstate, callstate = "0", "0"
    if states.regstate == "Registered" then
        regstate = "1"
    elseif states.regstate == "Registering" then
        regstate = "2"
    end
    if (regstate == "1" and states.callstate == "MMPBX_CALLSTATE_IDLE") then
        callstate = "1"
    end
    v[scns["register"]] = regstate
    v[scns["call"]] = callstate
end

-- Below table will be used for display, if validation in POST operation will fail then we will update below table for retaining the changes in display.
local sip_display_data = copyTable(sip_data)

local helpmsg = {}

if ngx.var.request_method == "POST" then
    local post_args = ngx.req.get_post_args()
    local sip_valid = {}
    local success = false
    local i = 1

    while post_args["isRowDeleted."..i] or post_args["isRowAdded."..i] do
		if ((post_args["isRowDeleted."..i] == "0") or (post_args["isRowAdded."..i] == "1"))  then
	    sip_valid["enable."..i] = post_helper.validateBoolean
	    sip_valid["uri."..i] = validateUri
	    if ((post_args["enable."..i] == "1") or (post_args["username."..i] ~= "")) then
		sip_valid["username."..i] = validateNonspaceString
	    end
	    if ((post_args["enable."..i] == "1") or (post_args["password."..i] ~= "")) then
		sip_valid["password."..i] = post_helper.getAndValidation(validatePassword,post_helper.getValidateStringLengthInRange(1,64))
	    end
	    if ((post_args["enable."..i] == "1") or (post_args["displayName."..i] ~= "")) then
			if (post_args["displayName."..i] ~= "") then
				sip_valid["displayName."..i] = validateNonspaceString
			end
	    end
	end
	i = i + 1
    end

    success, helpmsg = content_helper.validateObject(post_args, sip_valid)

    if success then
        local path = ""
	local base_path = "rpc.mmpbx.sip_profile."
	local content_set = {}
	local update = false
	i = 1
        while post_args["isRowDeleted."..i] or post_args["isRowAdded."..i] do
	    if post_args["isRowDeleted."..i] then
	        path = base_path.."@"..sip_data[i][scns["profile"]].."."
		if (post_args["isRowDeleted."..i] == "1") then	-- Existing profile deleted
			if proxy.del(path) then
			   update = true
			end
		else									-- Existing profile not deleted, checking for modification of fields
		    for _,v in ipairs(sip_columns) do
			if post_args[v.name.."."..i] then
			    if post_args[v.name.."."..i] ~= sip_data[i][scns[v.name]] then
				content_set[path..v.param] = post_args[v.name.."."..i]
			    end
			end
		    end
		end
	    elseif post_args["isRowAdded."..i]	then			--New Row added.
		if post_args["isRowAdded."..i] == "1" then	--Added row is not deleted
		    local new_profile = proxy.add(base_path)
		    path = base_path.."@"..new_profile.."."

		    for _,v in ipairs(sip_columns) do
			if post_args[v.name.."."..i] then
			    content_set[path..v.param] = post_args[v.name.."."..i]
			end
		    end
		    --For the newly added profile the port is common(common profile)
		    content_set[path.."port"] = "common"
		end
	    end
	    i = i + 1
	end

	if proxy.set(content_set) then
	    update = true
	end
	if update then
	    proxy.apply()
	    sip_data,allowedIndexes = content_helper.loadTableData(basepath, sip_columns, nil, sort_func)
	    sip_display_data = copyTable(sip_data)
	end
    else	-- Validation failed
	i = 1
	while post_args["isRowDeleted."..i] or post_args["isRowAdded."..i] do
	    if post_args["isRowDeleted."..i] then
		for _,v in ipairs(sip_columns) do
		    if  post_args[v.name.."."..i] then
			sip_display_data[i][scns[v.name]] = post_args[v.name.."."..i]
		    end
		end
	    elseif post_args["isRowAdded."..i] == "1" then
		sip_display_data[#sip_display_data + 1] = {"", "", "", "", "", "", "", "", ""}
		for _,v in ipairs(sip_columns) do
		    if  post_args[v.name.."."..i] then
			sip_display_data[#sip_display_data][scns[v.name]] = post_args[v.name.."."..i]
		    end
		end
	    end
	    i = i + 1
	end
        message_helper.pushMessage(T"Some parameters failed validation", "error")
    end
end


--Creating Table Header
local sip_table = { "<div class=\"control-group\"> <table id = \"sipProfileTable\" class=\"table table-striped\">",
			    "<thead><tr>"
			  }
for _,v in ipairs(sip_columns) do
    sip_table[#sip_table + 1] = string.format("<th>%s</th>", v.header)
end
--Column for delete button
sip_table[#sip_table + 1] = "<th></th>"

sip_table[#sip_table + 1] = "</tr></thead>"

local attrDelete = {
    button = {
        class = "btn-mini btn-danger btn-table-dlt tooltip-on",
        ["data-placement"] = "top",
        ["data-original-title"] = T"Delete",
    }
}
local attrCancel = {
    button = {
        class = "btn-mini btn-danger btn-table-cncl tooltip-on",
        ["data-placement"] = "top",
        ["data-original-title"] = T"Cancel",
    }
}

--Creating the table rows
sip_table[#sip_table + 1] = "<tbody>"
for i,v in ipairs(sip_display_data) do
    sip_table[#sip_table + 1] = "<tr>"
    for j,w in ipairs(v) do
        sip_table[#sip_table + 1] = "<td>"
	if sip_columns[j].type == "text" then
	    sip_table[#sip_table + 1] = ui_helper.createSimpleInputText(sip_columns[j].name.."."..i, w, sip_columns[j].attr,helpmsg[sip_columns[j].name.."."..i])
	elseif sip_columns[j].type == "switch" then
	    sip_table[#sip_table + 1] = ui_helper.createSimpleSwitch(sip_columns[j].name.."."..i, w, sip_columns[j].attr)
	elseif sip_columns[j].type == "select" then
		sip_table[#sip_table + 1] = ui_helper.createSimpleInputSelect(sip_columns[j].name.."."..i, sip_columns[j].values, w, sip_columns[j].attr)
	elseif sip_columns[j].type == "label" then
	    sip_table[#sip_table + 1] = w
        elseif sip_columns[j].type == "light" then
	    if w and w ~= "" then	-- if the row is newly added one then dont display the Registered & Call Status fields
	        sip_table[#sip_table + 1] = ui_helper.createSimpleLight(w, "", {})
	    end
        elseif sip_columns[j].type == "password" then
            sip_table[#sip_table + 1] = ui_helper.createSimpleInputPassword(sip_columns[j].name.."."..i, w or "", sip_columns[j].attr,helpmsg[sip_columns[j].name.."."..i])
	end
	sip_table[#sip_table + 1] = "</td>"
    end

    sip_table[#sip_table + 1] = "<td>"
    if v[scns["profile"]] and  v[scns["profile"]] ~= "" then
        sip_table[#sip_table + 1] = ui_helper.createSimpleButton("", "icon-remove-sign icon-large", attrDelete)
        sip_table[#sip_table + 1] = string.format("<input value=\"0\" name=\"isRowDeleted.%s\" type=\"hidden\">", i)
    else
        sip_table[#sip_table + 1] = ui_helper.createSimpleButton("", "icon-remove", attrCancel)
        sip_table[#sip_table + 1] = string.format("<input value=\"1\" name=\"isRowAdded.%s\" type=\"hidden\">", i)
    end
    sip_table[#sip_table + 1] = "</td>"

    sip_table[#sip_table + 1] = "</tr>"
end

sip_table[#sip_table + 1] = "</tbody></table>"

local buttonAttr = {
    button = {
        class = "btn-table-addrow"
    }
}

sip_table[#sip_table + 1] = '<center><div class="btn-group">'
sip_table[#sip_table + 1] = ui_helper.createSimpleButton(T"Create new","icon-plus-sign", buttonAttr)
sip_table[#sip_table + 1] = "</div></center>"

sip_table[#sip_table + 1] = "</div>"


local internal_options = {
    tableid = "internal_profile",
    basepath = "rpc.mmpbx.internal_profile.@.",
    canEdit = false,
    canAdd = false,
    canDelete = false,
    sorted = sort_func,
}

local internal_data, internal_helpmsg = post_helper.handleTableQuery(internal_columns, internal_options)

for _,v in pairs(internal_data) do
    v[icns["enable"]] = (v[icns["enable"]] == "1" and "Enabled") or "Disabled"
    local ports = string.format("%s", v[icns["port"]])
    ports = string.gsub(ports, "([^%,]+)", devMap)
    ports = string.gsub(ports, "(%,)", "<br>")
    v[icns["port"]] = ports
end

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
  <form class="form-horizontal" method="post" action="<%= uri %>">
    <%= ui_helper.createMessages(message_helper.popMessages()) %>
    <fieldset id="mmpbx-profile-tab">
      <legend><%= T"Telephone Numbers" %></legend>
      <% ngx.print(sip_table) %>
    </fieldset>
    <fieldset>
      <legend><%= T"Internal Telephone Numbers" %></legend>
      <%= ui_helper.createTable(internal_columns, internal_data, internal_options, nil, internal_helpmsg) %>
    </fieldset>
  </form>
</div>

<%= ui_helper.createFooter() %>

<script>
function addNewRow() {
    var noOfRows = $("#sipProfileTable tr").length;   // We will get the value as the number of present rows + 1, the extra 1 because of the <tr> used for tabel header. So no need to increment it.

    var EnableSW        = '<div class="control-group"><div class="switch switchOn" data-placement="right"><div class="switcher switcherOn" texton="ON" textoff="OFF" valon="1" valoff="0"></div><input value="1" name="enable.'+noOfRows+'" type="hidden"></input></div></div>';
    var UserName        = '<input class="edit-input  span1" type="text" name="username.'+noOfRows+'" value=""></input>';
    var uri             = '<input class="edit-input  span1" type="text" name="uri.'+noOfRows+'" value=""></input>';
    var Password        = '<input class="edit-input  span1" type="password" name="password.'+noOfRows+'" value=""></input>';
    var DisplayName     = '<input class="edit-input  span1" type="text" name="displayName.'+noOfRows+'" value=""></input>';
    var NetWork         = '<div class="control-group"><select class=" span2" name="network.'+noOfRows+'"><%for _,v in pairs(sipnet_options) do%><option value="<%=v[1]%>"><%=v[2]%></option><%end%></select></div>';

    var CancelBtn       = '<%=ui_helper.createSimpleButton("", "icon-remove", attrCancel)%>';
    CancelBtn           = CancelBtn  + '<input value="1" name="isRowAdded.'+noOfRows+'" type="hidden">';

    $('#sipProfileTable').append('<tr><td>'+EnableSW+'</td><td></td><td>'+UserName+'</td><td>'+uri+'</td><td>'+Password+'</td><td>'+DisplayName+'</td><td>'+NetWork+'</td><td></td><td></td><td>'+CancelBtn+'</td></tr>');

    //Enabling the Cancel action for newly added row
    $('.btn-table-cncl').click(function(){
	$(this).parent().parent().attr("style","display: none;");
	$(this).parent().children('input').val(0);
    });

    //Enabling tool tip for newly added row
    $('.tooltip-on').tooltip();
}

$(document).ready(function() {
    $('.switch, input[type="text"], input[type="password"]').change(function(){
        $('#modal-no-change').fadeOut(300);
        $('#modal-changes').delay(350).fadeIn(300);
    });
    $('.select').change(function(){
        $('#modal-no-change').fadeOut(300);
        $('#modal-changes').delay(350).fadeIn(300);
    });
    $('.btn-table-addrow').click(function(){
	addNewRow();
        $('#modal-no-change').fadeOut(300);
        $('#modal-changes').delay(350).fadeIn(300);
    });
    $('.btn-table-dlt').click(function(){
	$(this).parent().parent().attr("style","display: none;");
	$(this).parent().children('input').val(1);
        $('#modal-no-change').fadeOut(300);
        $('#modal-changes').delay(350).fadeIn(300);
    });
    $('.btn-table-cncl').click(function(){
	$(this).parent().parent().attr("style","display: none;");
	$(this).parent().children('input').val(0);
        $('#modal-no-change').fadeOut(300);
        $('#modal-changes').delay(350).fadeIn(300);
    });
    $(document).off("change")
});

$(function(){
    $('#sipProfileTable tbody tr').each (function() {
      var regstate_column = 7, callstate_column = 8;
      //Toolbox for column Registered
      var reg = $(this).find("td").eq(regstate_column).find("div");
      var reg_class = reg.attr("class");
      var reg_hint = "Unregistered";
      if (reg_class == "light green") {
        reg_hint = "Registered";
      }
      else if (reg_class == "light orange") {
        reg_hint = "Registering";
      }
      reg.attr({"class": "someInfos " + reg_class, "rel": "tooltip", "data-placement": "top", "data-original-title": reg_hint});

      //Toolbox for column State
      var call = $(this).find("td").eq(callstate_column).find("div");
      var call_class = call.attr("class");
      var call_hint = "Can't be used";
      if (call_class == "light green") {
        call_hint = "Can be used";
      }
      call.attr({"class": "someInfos " + call_class,"rel": "tooltip", "data-placement": "top", "data-original-title": call_hint});
    })
    $('.someInfos').tooltip();
});
</script>
