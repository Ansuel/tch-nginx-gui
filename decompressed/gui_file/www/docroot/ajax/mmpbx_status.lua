-- Enable localization
gettext.textdomain('webui-core')

local json = require("dkjson")
local proxy = require("datamodel")
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
    local originuri = data.uri
    if data.uri and data.uri:match("+") then
        data.uri = data.uri:sub(4)
    end

    if data.sipRegisterState then
        data.sipRegisterState =  data.sipRegisterState
        data.sipRegisterState = ui_helper.createSimpleLight(data.sipRegisterState=="Registered" and "1" or "0", T(data.sipRegisterState))
    end

    if data.callState then
        local statestr = data.callState
        if ( data.callState == "MMPBX_CALLSTATE_IDLE" ) then
            statestr =  T"Idle"
        elseif ( data.callState == "MMPBX_CALLSTATE_DIALING" ) then
            statestr =  T"Dialing"
        elseif ( data.callState == "MMPBX_CALLSTATE_CALL_DELIVERED" ) then
            statestr =  T"Delivered/In Progress"
        elseif ( data.callState == "MMPBX_CALLSTATE_CONNECTED" ) then
            statestr =  T"In Progress/Connected"
        elseif ( data.callState == "MMPBX_CALLSTATE_ALERTING" ) then
            statestr =  T"Ringing"
        end

        if ( data.callState ~= "MMPBX_CALLSTATE_IDLE" ) then

            local Remoteparty
            local pf_path = proxy.get("rpc.mmpbx.calllog.info.")
            local pf_data = content_helper.convertResultToObject("rpc.mmpbx.calllog.info.",pf_path)
            for _,v in ipairs(pf_data) do
                if v.Localparty  == originuri then
                    Remoteparty = v.Remoteparty
                end
            end

            statestr = statestr .. " " .. Remoteparty
        end

        data.callState = ui_helper.createSimpleLight(data.callState == "MMPBX_CALLSTATE_IDLE" and "0" or "1", statestr, nil, "fa fa-phone")
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
