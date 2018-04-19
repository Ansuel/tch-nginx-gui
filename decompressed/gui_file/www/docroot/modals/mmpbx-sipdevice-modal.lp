<%

-- Enable localization
gettext.textdomain('webui-voice')


local tinsert = table.insert

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")

-- SIP Networks
local sipdev_columns = {
  {
    header = T"Sip Device",
    name = "device",
    param = "user_friendly_name",
    type = "text",
    attr = { input = { class="span2", } },
  },
  {
    header = T"User Name",
    name = "user_name",
    param = "user_name",
    type = "text",
    attr = { input = { class="span2", } },
  },
  {
    header = T"Uri",
    name = "uri",
    param = "uri",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Mapping Status",
    name = "mappingstatus",
    param = "mappingStatus",
    type = "text",
    attr = { input = { class='span2'} },
  },
  { -- one fake parameter "paramindex", use to index sip_dev_n
    header = T"sipindex",
    name = "device",
    param = "paramindex",
    type = "text",
  },
}

local sipdev_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "sipdev",
    basepath = "uci.mmpbxrvsipdev.device.",
    sorted = "user_friendly_name",
}


local sipdev_data, sipdev_helpmsg = post_helper.handleTableQuery(sipdev_columns, sipdev_options, nil, nil, nil)

-- use column_paramindex to mark the location id of paramindex in table sipdev_columns
local column_paramindex = 5
local sipdevpro_data = {}

for i=1, #sipdev_data do
    sipdevpro_data = proxy.get("rpc.mmpbx.device." .. sipdev_data[i][column_paramindex] .. ".profileUsable")
    sipdev_data[i][column_paramindex - 1] = sipdevpro_data[1].value
    -- set table's last column to nil
    sipdev_data[i][column_paramindex] = nil
end
sipdev_columns[column_paramindex] = nil

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
	<fieldset id="mmpbx-sipdevice-tab">
	    <legend><%= T"Sip Device" %></legend>
	    <%=ui_helper.createTable(sipdev_columns, sipdev_data, sipdev_options, nil, sipdev_helpmsg)%>
        </fieldset>
    </form>
</div>

<%= ui_helper.createFooter() %>
