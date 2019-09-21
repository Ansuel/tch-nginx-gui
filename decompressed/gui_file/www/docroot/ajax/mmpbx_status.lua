-- Enable localization
gettext.textdomain('webui-core')

local json = require("dkjson")
local proxy = require("datamodel")
local ngx = ngx

local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")
local untaint_mt = require("web.taint").untaint_mt

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

local content = {
    status = "rpc.mmpbx.state",
    emission = "rpc.mmpbx.dectemission.state",
}

content_helper.getExactContent(content)

local status_map = {
	STARTING = T"Starting",
	RUNNING = T"Running",
	STOPPING = T"Stopping",
	NA = T"Not Available",
}
setmetatable(status_map, untaint_mt)

local mmpbx_light = content.status == "NA" and "0" or "1"
local mmpbx_status = status_map[content.status] or content.status

local callStateMap = {
	MMPBX_CALLSTATE_IDLE = T"Idle",
	MMPBX_CALLSTATE_DIALING = T"Dialing",
	MMPBX_CALLSTATE_CALL_DELIVERED = T"Delivered/In Progress",
	MMPBX_CALLSTATE_CONNECTED = T"In Progress/Connected",
	MMPBX_CALLSTATE_ALERTING = T"Ringing"
}
setmetatable(callStateMap, untaint_mt)

local registrationStatusMap = {
	Registered = T"Registered",
	Registering = T"Registering"
}
setmetatable(registrationStatusMap, untaint_mt)

local failReasonMap = {
	MMPBX_REG_CLIENT_REASON_RESPONSE_REQUEST_FAILURE_RECVD = T"Registration refused",
	MMPBX_REG_CLIENT_REASON_NETWORK_ERROR = T"Network error",
	MMPBX_REG_CLIENT_REASON_TRANSACTION_TIMEOUT = T"Registration Timeout"
}
setmetatable(failReasonMap, untaint_mt)

local time_t = {}
local function convert2Sec(value)
    value = string.untaint(value)
    time_t.year, time_t.month, time_t.day, time_t.hour, time_t.min, time_t.sec = value:match("(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
    if time_t.year then
        return os.time(time_t)
    end
    return 0
end

local mmpbxd_filter = function(data)
    if ( data.enable == "false" ) or ( data.sipRegisterState == "" ) then
        return false
    end
    local originuri = data.uri
    if data.uri and data.uri:match("+") then
        data.uri = data.uri:sub(4)
    end

    local registerLight = "off"
	local registerState
    if data.sipRegisterState then
        registerState = registrationStatusMap[data.sipRegisterState] or data.sipRegisterState
        if data.sipRegisterState=="Registered" then
            registerLight="green"
        end
        if data.failReason ~= "" then
            registerLight="red"
            registerState = failReasonMap[data.failReason] or data.failReason
        end
        data.sipRegisterState = ui_helper.createSimpleLight(nil, registerState, { light = { class = registerLight } })
    end

    if data.callState then
        local statestr = callStateMap[data.callState] or data.callState
		
        if ( data.callState ~= "MMPBX_CALLSTATE_IDLE" ) then
            local pf_path = proxy.get("rpc.mmpbx.calllog.info.")
            local pf_data = content_helper.convertResultToObject("rpc.mmpbx.calllog.info.",pf_path)
            for i = #pf_data, 1, -1 do
                v = pf_data[i]
                if v.Localparty  == originuri then
                    statestr = statestr .. "\n" .. v.Remoteparty
                    if ( data.callState == "MMPBX_CALLSTATE_CONNECTED" ) then
                        local Duration = ""
                        if v.connectedTime ~= "0" then
                            local connectedTime = convert2Sec(v.connectedTime)
                            if v.endTime ~= '0' then
                                local endTime = convert2Sec(v.endTime)
                                Duration = post_helper.secondsToTimeShort(endTime - connectedTime)
                            else
                                Duration = post_helper.secondsToTimeShort(os.time() - connectedTime)
                            end
                        end
                        statestr =  statestr .. " " .. Duration
                    end
                    break
                end
            end
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
    mmpbx_status = ui_helper.createLabel(T"Service", ui_helper.createSimpleLight(mmpbx_light, mmpbx_status), basic),
    mmpbx_table = table.concat(mmpbx_string) or ""
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
    ngx.say(buffer)
else
    ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)
