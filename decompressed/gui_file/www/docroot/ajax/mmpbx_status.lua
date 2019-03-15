-- Enable localization
gettext.textdomain('webui-core')

local json = require("dkjson")
local ngx = ngx

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")

local mmpbxd_columns = {
    {--[2]
        header = T"Line Status",
        name = "sipRegisterState",
        param = "sipRegisterState",
        type = "text",
    },
    {--[3]
        header = T"Number",
        name = "uri",
        param = "uri",
        type = "text",
    },
    {--[4]
        header = T"Call State",
        name = "callState",
        param = "callState",
        type = "text",
    },
}

local mmpbxd_filter = function(data)
    if ( data.enable == "false" ) or ( data.sipRegisterState == "" ) then
        return false
    end
    if data.uri and data.uri:match("+") then
        data.uri = data.uri:sub(4)
    end

    if data.sipRegisterState then
        data.sipRegisterState =  data.sipRegisterState
        data.sipRegisterState = ui_helper.createSimpleLight(data.sipRegisterState=="Registered" and "1" or "0", T(data.sipRegisterState))
    end

    if data.callState then
        if ( data.callState == "MMPBX_CALLSTATE_IDLE" ) then
            data.callState =  T"Idle"
        elseif ( data.callState == "MMPBX_CALLSTATE_DIALING" ) then
            data.callState =  T"Dialing"
        elseif ( data.callState == "MMPBX_CALLSTATE_CALL_DELIVERED" ) then
            data.callState =  T"Delivered/In Progress"
        elseif ( data.callState == "MMPBX_CALLSTATE_CONNECTED" ) then
            data.callState =  T"In Progress/Connected"
        elseif ( data.callState == "MMPBX_CALLSTATE_ALERTING" ) then
            data.callState =  T"Ringing"
        end

        data.callState = ui_helper.createSimpleLight(data.callState==T"Idle" and "0" or "1", T(data.callState), nil, "fa fa-phone")
    end

    return true
end

local  mmpbxd_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "mmpbxd",
    basepath = "rpc.mmpbx.profile.",
}

local  mmpbxd_data = content_helper.loadTableData(mmpbxd_options.basepath, mmpbxd_columns ,  mmpbxd_filter , nil)

local mmpbx_table = ui_helper.createTable(mmpbxd_columns, mmpbxd_data, mmpbxd_options, nil, nil)

local mmpbx_string = {}

local function concat_table(mmpbx_table)
    for _ , table_string in pairs(mmpbx_table) do
        if type(table_string) == "table" then
            concat_table(table_string)
        elseif type(table_string) == "userdata" then
            mmpbx_string[#mmpbx_string+1] = string.untaint(table_string)
        else
            mmpbx_string[#mmpbx_string+1] = table_string
        end
    end
end

concat_table(mmpbx_table)

local data = {
    mmpbx_table = table.concat(mmpbx_string) or ""
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
    ngx.say(buffer)
else
    ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)
