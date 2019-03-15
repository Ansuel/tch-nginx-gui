--pretranslated: do not change this file

gettext.textdomain('webui-core')

local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local assistance = require("web.assistance")
local uci_assistance = "uci.web.assistance."
local content_assistance = content_helper.convertResultToObject(uci_assistance .. "@.", proxy.get(uci_assistance))
local timeout = content_assistance[1].timeout
local secname = content_assistance[1].paramindex
local assistant = assistance.getAssistant(secname)
local gVChkbox = post_helper.getValidateCheckboxSwitch()
local format = string.format

local untaint = string.untaint

local mode_map = {
    { "0", T'Temporary' },
    { "1", T'Permanent'},
}

local user_map = {
    { "admin", T'Admin' },
    { "assist", T'Assistant'},
    { "guest", T'Guest'},
}

local srp_param_map = {
    srp_salt = "salt",
    srp_verifier = "verifier",
}

local function get_srp_from_uci(user)
    local srp_pair, user_map = {}, {}
    local cfg=proxy.get("uci.web.user.")
    local srp
    if cfg then
        for _, entry in ipairs(cfg) do
            local name = string.match(entry.path,"%.@([^.]*)%.")
            if name then
                if entry.param == "name" then
                    user_map[entry.value] = name
                elseif srp_param_map[entry.param] and entry.value ~= "" then
                    srp_pair[name] = srp_pair[name] or {}
                    srp_pair[name][srp_param_map[entry.param]] = entry.value
                end
            end
        end
        srp = srp_pair[user_map[user]]
        if srp and (not srp["salt"] or not srp["verifier"]) then
            srp = nil
        end
    end
    return srp, user_map[user]
end

local uci_assist_user = content_assistance[1].user
local uci_assist_srp, uci_assist_user_sec = get_srp_from_uci(uci_assist_user)

local state = assistant:enabled() and "1" or "0"
local error

local helpmsg={}
local content=nil
if ngx.var.request_method == "POST" then
    content = ngx.req.get_post_args()
    if content["action"]=="SAVE" then

        local convport = tonumber(content["port"])
        if content["ra_enabled"] == "1" and ( (content["random_port"] == "1") or (content["port"] == "") or
                ( convport~= nil and (convport > 0 ) and (convport < 65565 )))then --let's set the port before assist:enable
            if (content["random_port"] == "1") then
                proxy.set("uci.web.assistance.@remote.port" , "")
            else
                proxy.set("uci.web.assistance.@remote.port" , content["port"])
            end
            proxy.apply()
        end

        gVChkbox(content["ra_enabled"], content, "ra_enabled")
        local password = nil
        local newstate = content["ra_enabled"] or state
        if newstate=="1" then
            gVChkbox(content["random_psw"], content, "random_psw")
            if content["random_psw"] == "0" then
                -- the new setting is to use fixed password
                if content["salt"]=="" or not content["salt"]  then
                    if not uci_assist_srp then
                        -- return error if previous password is random and no password is given by user
                        helpmsg["password"]="Password is empty"
                    else
                        -- set password to false and use the existing password
                        password=uci_assist_srp
                        content["salt"] = nil
                        content["verifier"] = nil
                    end
                else
                    -- set password to the new salt and verifier
                    password = {
                        salt = content["salt"],
                        verifier = content["verifier"]
                    }
                end
            else
                -- remove password for user assist if random password mode is enabled
                content["salt"] = ""
                content["verifier"] = ""
            end
        else
            content["random_psw"] = uci_assist_srp and "0" or "1"
            content["mode"] = assistant:isPermanentMode() and "1" or "0"
            password = false
        end
        if next(helpmsg)==nil then
            if newstate=="1" then
                local assist_user_path_pattern = "uci.web.user.@%s.%s"
                local assistance_path_pattern = "uci.web.assistance.@%s.%s"
                local sets = {
                    [format(assist_user_path_pattern, uci_assist_user_sec, "srp_salt")] = content["salt"],
                    [format(assist_user_path_pattern, uci_assist_user_sec, "srp_verifier")] = content["verifier"],
                    [format(assistance_path_pattern, secname, "timeout")] = content["mode"] == "1" and "-1" or "",
                }
                proxy.set(sets)
                assistant._persistent = (content["mode"] == "1")
            end
            if type(password) == 'table' then
                password.salt = string.untaint(password.salt)
                password.verifier = string.untaint(password.verifier)
            end
            state = assistant:enabled() and "1" or "0"
            if state == "1" then
                --if already enabled disable to reload all config
                assistant:enable(false)
            end
            local ok, err = assistant:enable(newstate=="1", content["mode"] == "1", password)
            state = assistant:enabled() and "1" or "0"
            if not ok then
                error = err
            end
        else
            content["ra_enabled"] = newstate
        end
    end
end

local function validateEmptyString(value)
    if value == "" then
        return true
    end
    return nil, T"String must be empty or a port."
end

local mapValid = {
    port = post_helper.getOrValidation(post_helper.getValidateNumberInRange(0,65535),validateEmptyString),
    user =  post_helper.validateNonEmptyString,
}

local mapParams = {
    user = "uci.web.assistance.@remote.user",
    port = "uci.web.assistance.@remote.port",
}

local content2, helpmsg2 = post_helper.handleQuery(mapParams, mapValid)

if not content then
    content = {}
    content["ra_enabled"] = assistant:enabled() and "1" or "0"
    content["mode"] = (timeout == "-1") and "1" or "0"
    content["random_psw"] = uci_assist_srp and "0" or "1"
end

content["password"]=""
if content["random_psw"] == "1" and assistant:enabled() then
    content["password"] = assistant:password()
end

ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Assistance", false, false) ); ngx.print('\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/assistance-modal.lp">\
&nbsp\
');
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
ngx.print('\
<fieldset>\
  ');
if timeout == "-1" or timeout == "" then
    timeout = "30"
end
local infomessage = {
    alert = {
        class = "alert-info",
    }
}
local html={}
if assistant:enabled() then
    html[#html + 1] = ui_helper.createAlertBlock(string.format(T"<p>Remote assistance is currently enabled. </p><p>Click 'Apply' button with the 'Enabled' checkbox disabled to disable remote assistance on your gateway </p>"),infomessage)
else
    html[#html + 1] = ui_helper.createAlertBlock(string.format(T"<p>Remote assistance is currently disabled.</p><p> By clicking on the 'Apply' button with the 'Enabled' checkbox enabled your gateway will be accessible from your broadband connection. After %s minutes of inactivity, or on reboot, remote assistance will be automatically disabled for 'Temporary' mode. </p><p> Please provide the following parameters to your ISP:</p>", timeout ),infomessage)
end
local ra_enable_class = {
    input = {
        class = "monitor-changes",
    }
}
local ra_class_port_0 = {
    group = {
        class ="monitor-random_port monitor-0",
    }
}
local ra_class_port_1 = {
    group = {
        class ="monitor-random_port monitor-1",
    }
}
local ra_class_password_0 = {
    group = {
        class ="monitor-random_psw monitor-0",
    }
}
local ra_class_password_1 = {
    group = {
        class ="monitor-random_psw monitor-1",
    }
}

html[#html + 1] = ui_helper.createSwitch(T"Enabled", "ra_enabled", content["ra_enabled"], ra_enable_class)
html[#html + 1] = ui_helper.createInputSelect(T"Mode", "mode", mode_map, content["mode"])
html[#html + 1] = ui_helper.createLabel(T"Username", assistant:username())
html[#html + 1] = ui_helper.createSwitch(T"Use Random Port", "random_port", content2["port"]==assistant:port() and "0" or "1",ra_enable_class)
html[#html + 1] = ui_helper.createInputText(T"Port", "port" , content2["port"], ra_class_port_0, helpmsg2["port"])
html[#html + 1] = ui_helper.createLabel(T"Port", assistant:port(), ra_class_port_1)
local password = assistant:password()
html[#html + 1] = ui_helper.createSwitch(T"Use Random Password", "random_psw", content["random_psw"],ra_enable_class)
html[#html + 1] = ui_helper.createInputText(T"Password", "password", password, ra_class_password_0, helpmsg["password"])
html[#html + 1] = ui_helper.createLabel(T"Password", password, ra_class_password_1)
html[#html + 1] = ui_helper.createSimpleInputHidden("salt", "")
html[#html + 1] = ui_helper.createSimpleInputHidden("verifier", "")
html[#html + 1] = error and ui_helper.createLabel("Error", error) or ''
ngx.print(html)
ngx.print('\
\
</fieldset>\
</form>\
</div>\
\
'); ngx.print(ui_helper.createFooter()) ngx.print('\
\
<script type="text/javascript" >\
\
	$.getScript("/js/srp-min.js");\
\
	var oldhandler;\
	$.each($._data(document, "events"), function(i, event){\
		$.each(event, function(i, handler){\
			if(handler["selector"] == "#save-config"){\
				oldhandler = handler[\'handler\'];\
			}\
		});\
	});\
	$(document).off("click", "#save-config");\
    $("#save-config").on("click", function (event) {\
        var user = "'); ngx.print( assistant:username() ); ngx.print('";\
        var password = $(\'input[name="password"]\').val();\
		var port = $(\'input[name="port"]\').val();\
\
        if(password != "" ) {\
             var srp = new SRP();\
             srp.generateSaltAndVerifierTheCallback(user, password, function(salt, verifier) {\
                 $(\'input[name="salt"]\').val(salt);\
                 $(\'input[name="verifier"]\').val(verifier);\
                 $(\'input[name="password"]\').val(""); // clean that up no need to send it over the air\
				oldhandler();\
             });\
        } else oldhandler();\
    });\
</script>\
\
'); 