<%
-- Enable localization
--NG-96261 VOIP WEB GUI: VoIP configuration changes applied event if not saved
--NG-97938 GUI Telephony - In/Out Mapping
gettext.textdomain('webui-voice')

local tinsert = table.insert

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local format = string.format
local concat = table.concat
local html_escape = require("web.web").html_escape

local devices = {}
local dev_config = { "mmpbxbrcmfxsdev", "mmpbxbrcmdectdev"}

local function getDeviceFriendlyNames()
    local devpattern = "([^%._@]+_dev_%d+)"
    for _,v in pairs(dev_config) do
        local results = proxy.get("uci." .. v .. ".device.")
        if results then
            for _,vv in ipairs(results) do
                if vv.param == "user_friendly_name" then
                    local dev = vv.path:match(devpattern)
                    devices[#devices + 1] = {dev, vv.value}
                end
            end
        end
    end
end
getDeviceFriendlyNames()

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

local order = {
    d = 1,
    f = 2,
}

table.sort(devices, function(a,b)
    local order_a = order[a[1]:sub(1,1)]
    local order_b = order[b[1]:sub(1,1)]
    if order_a < order_b or (order_a == order_b and a[1] < b[1]) then
        return true
    else
        return false
    end
end)

--Devices list incoming/outgoing
local incoming_outgoing_map_columns = {
    {
        header = T"Phone Number",
        name = "PhoneNumber",
        param = "PhoneNumber",
        type = "label",
        readonly = true,
        attr = { input = { class="span2" } },
    },
}

for _, dev in ipairs(devices) do
  incoming_outgoing_map_columns[#incoming_outgoing_map_columns + 1] = {
    header = dev[2],
    name = dev[1],
    param = dev[1],
    type = "checkboxswitch",
  }
end

local profilepattern = "sip_profile_(%d+)"
local a_num
local b_num
local function sort_func(a, b)
    a_num = a.paramindex:match(profilepattern)
    b_num = b.paramindex:match(profilepattern)
    return tonumber(a_num) < tonumber(b_num)
end


local function inoutcoming_map_filter(input)
	local mmpbx_profile = proxy.get("rpc.mmpbx.sip_profile.")
	local mmpbx_profile_data = content_helper.convertResultToObject("rpc.mmpbx.sip_profile.",mmpbx_profile)
	
	local number = input.PhoneNumber
	for i,v in pairs(mmpbx_profile_data) do
		if v.uri == number and v.enabled == "1" then
			return true
		end
	end
	
end
--Getting the current available incoming maps
local incoming_map_basepath = "rpc.mmpbx.sip_incomingmap.@."
local incoming_map_data, incoming_map_allowed_indexes = content_helper.loadTableData(incoming_map_basepath, incoming_outgoing_map_columns, inoutcoming_map_filter, sort_func)

--Getting the current available outgoing maps
local outgoing_map_basepath = "rpc.mmpbx.sip_outgoingmap.@."
local outgoing_map_data, outgoing_map_allowed_indexes = content_helper.loadTableData(outgoing_map_basepath, incoming_outgoing_map_columns, inoutcoming_map_filter, sort_func)

--POST for incoming & outgoing maps
if ngx.req.get_method() == "POST" then
    local success = false
    local post_args = ngx.req.get_post_args()

    local vB = post_helper.validateBoolean
    local incoming_outgoing_map_valid = {}

    for i in ipairs(incoming_map_allowed_indexes) do
        for _,w in ipairs(incoming_outgoing_map_columns) do
	    if w.type == "checkboxswitch" then
	        incoming_outgoing_map_valid["inc_"..w.name.."."..i] = vB
	    end
	end
    end

    for i in ipairs(outgoing_map_allowed_indexes) do
        for _,w in ipairs(incoming_outgoing_map_columns) do
	    if w.type == "checkboxswitch" then
	        incoming_outgoing_map_valid["outg_"..w.name.."."..i] = vB
	    end
	end
    end
    success = content_helper.validateObject(post_args, incoming_outgoing_map_valid)

    if success then
        local rpcpath = "rpc.mmpbx.sip_incomingmap.@"
	local path = ""
	local content_set = {}
        for i,v in ipairs(incoming_map_allowed_indexes) do
	    path = rpcpath..v.paramindex
            for j,w in ipairs(incoming_outgoing_map_columns) do
		if w.type == "checkboxswitch" then
		    if post_args["inc_"..w.name.."."..i] and  post_args["inc_"..w.name.."."..i] ~= incoming_map_data[i][j] then
		        content_set[path.."."..w.param] = post_args["inc_"..w.name.."."..i]
		    end
		end
	    end
        end

	rpcpath = "rpc.mmpbx.sip_outgoingmap.@"

	for i,v in ipairs(outgoing_map_allowed_indexes) do
	    path = rpcpath..v.paramindex
            for j,w in ipairs(incoming_outgoing_map_columns) do
		if w.type == "checkboxswitch" then
		    if post_args["outg_"..w.name.."."..i] and  post_args["outg_"..w.name.."."..i] ~= outgoing_map_data[i][j] then
		        content_set[path.."."..w.param] = post_args["outg_"..w.name.."."..i]
		    end
		end
	    end
        end
	-- if content_set is not empty then only set.
	if next(content_set) then
	    local ok, msg = proxy.set(content_set)
	    if ok then
	        ok, msg = proxy.apply()
	        if not ok then
	            ngx.log(ngx.ERR, "apply failed: " .. msg)
		    message_helper.pushMessage(T"Error while applying changes", "error")
	        else
	            message_helper.pushMessage(T"Changes saved successfully", "success")
	        end
	        incoming_map_data, incoming_map_allowed_indexes = content_helper.loadTableData(incoming_map_basepath, incoming_outgoing_map_columns, inoutcoming_map_filter, sort_func)		--Getting updated incoming maps
	        outgoing_map_data, outgoing_map_allowed_indexes = content_helper.loadTableData(outgoing_map_basepath, incoming_outgoing_map_columns, inoutcoming_map_filter, sort_func)	--Getting updated outgoing maps
	    else
	        if type(msg) == "table" then
	            ngx.log(ngx.ERR, "set failed: " .. msg[1].errmsg)
	        end
                message_helper.pushMessage(T"Error while saving changes", "error")
	    end
	end
    else
        message_helper.pushMessage(T"Some parameters failed validation", "error")
    end
end

--Creating Table Header for incoming maps
local incoming_map_table = { "<div class=\"control-group\"> <table class=\"table table-striped\">",
			    "<thead><tr>"
			  }
for _,v in ipairs(incoming_outgoing_map_columns) do
    incoming_map_table[#incoming_map_table + 1] = format("<th>%s</th>", v.header)
end
incoming_map_table[#incoming_map_table + 1] = "</tr></thead>"

--Creating the table rows
incoming_map_table[#incoming_map_table + 1] = "<tbody>"
for i,v in ipairs(incoming_map_data) do
    incoming_map_table[#incoming_map_table + 1] = "<tr>"
    for j,w in ipairs(v) do
        incoming_map_table[#incoming_map_table + 1] = "<td>"
	if incoming_outgoing_map_columns[j].type == "checkboxswitch" then
	    incoming_map_table[#incoming_map_table + 1] = createSimpleCheckboxSwitch("inc_"..incoming_outgoing_map_columns[j].name.."."..i, w)
	else
	    incoming_map_table[#incoming_map_table + 1] = w
	end
	incoming_map_table[#incoming_map_table + 1] = "</td>"
    end
    incoming_map_table[#incoming_map_table + 1] = "</tr>"
end
incoming_map_table[#incoming_map_table + 1] = "</tr></thead>"
incoming_map_table[#incoming_map_table + 1] = "</tbody></table>"
incoming_map_table[#incoming_map_table + 1] = "</div>"

--Creating Table Header for outgoing maps
local outgoing_map_table = { "<div class=\"control-group\"> <table class=\"table table-striped\">",
			    "<thead><tr>"
			  }
for _,v in ipairs(incoming_outgoing_map_columns) do
    outgoing_map_table[#outgoing_map_table + 1] = format("<th>%s</th>", v.header)
end
outgoing_map_table[#outgoing_map_table + 1] = "</tr></thead>"

--Creating the table rows
outgoing_map_table[#outgoing_map_table + 1] = "<tbody>"
for i,v in ipairs(outgoing_map_data) do
    outgoing_map_table[#outgoing_map_table + 1] = "<tr>"
    for j,w in ipairs(v) do
        outgoing_map_table[#outgoing_map_table + 1] = "<td>"
	if incoming_outgoing_map_columns[j].type == "checkboxswitch" then
	    outgoing_map_table[#outgoing_map_table + 1] = createSimpleCheckboxSwitch("outg_"..incoming_outgoing_map_columns[j].name.."."..i, w)
	else
	    outgoing_map_table[#outgoing_map_table + 1] = w
	end
	outgoing_map_table[#outgoing_map_table + 1] = "</td>"
    end
    outgoing_map_table[#outgoing_map_table + 1] = "</tr>"
end
outgoing_map_table[#outgoing_map_table + 1] = "</tr></thead>"
outgoing_map_table[#outgoing_map_table + 1] = "</tbody></table>"
outgoing_map_table[#outgoing_map_table + 1] = "</div>"

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
      <fieldset id ="mmpbx-incomingmap-tab">
      <legend><%= T"Incoming Maps" %></legend>
      <%
	ngx.print(incoming_map_table)
      %>

     </fieldset>

	<fieldset id ="mmpbx-outgoingmap-tab">
      <legend><%= T"Outgoing Maps" %></legend>
      <%
	ngx.print(outgoing_map_table)
      %>

    </fieldset>
  </form>
</div>

<%= ui_helper.createFooter() %>
<script>
$(document).ready(function() {
    $("#save-config").attr("id","save-form");
    $("#save-form").click(function(){
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
        var checkboxname = $(this).attr("name");
	var isSameOutMapselected = false
	var check = checkboxname.search("out")
	if(check != -1)
	{
	var numprofiles = <%=#outgoing_map_data %>;
	var devname = checkboxname.split(".")
	var tmpname = ""
	for(var i=1; i <= numprofiles; i++)
	{
	    tmpname = devname[0]+"."+i
	    $('input[type="checkbox"]').each(function(){
	        if($(this).attr("name") == tmpname)
		{
		    if(tmpname == checkboxname)
		    {
		        //if the same checkbox is selected by user for outgoing maps we should not save the changes.i
			if($(this).attr('checked'))
			{
			    isSameOutMapselected = true;
			}
			$(this).prop('checked', true);
		    }else
	            {
		        $(this).prop('checked', false);
		    }
		}
	    });
	}}
	if(!isSameOutMapselected)
	{
	    $('#modal-no-change').fadeOut(300);
            $('#modal-changes').delay(350).fadeIn(300);
	}
	return false;	// For stoping the POST
    });
});
</script>
