--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/telstra-snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
  ngx.print('\
\
');  
gettext.textdomain('webui-telstra')

local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")

local assistance = require("web.assistance")
local path = proxy.get("uci.web.assistance.")[1].path
local _, _, secname = string.find(path, "web%.assistance%.@([^%.]*)%.")
local assistant = assistance.getAssistant(secname)
local gVChkbox = post_helper.getValidateCheckboxSwitch()

local state = assistant:enabled() and "1" or "0"
local error

local mode_map = {
    { "0", T'Temporary' },
    { "1", T'Permanent'},
}

local mode_map2 = {
    ["0"]= T'Temporary',
    ["1"]= T'Permanent',
}

local checkbox_map = {
    ["0"]= T'No',
    ["1"]= T'Yes',
}

message_helper.popMessages()
local helpmsg={}
local content=nil
if ngx.var.request_method == "POST" then
    content = ngx.req.get_post_args()
    if content["action"]=="SAVE" then
        gVChkbox(content["ra_enabled"], content, "ra_enabled")
        local password = nil
        local newstate = content["ra_enabled"] or state
        if newstate~=state and newstate=="1" then
            content["mode"] = string.untaint(content["mode"])
            gVChkbox(content["random_psw"], content, "random_psw")
            if content["random_psw"] == "0" then
                -- the new setting is to use fixed password
                content["salt"] =string.untaint(content["salt"])
                content["verifier"] =string.untaint(content["verifier"])
                if content["salt"]=="" or not content["salt"] then
                    if assistant:isRandomPassword() then
                       -- return error if previous password is random and no password is given by user
                       helpmsg["password"]="Password is empty"
                    else
                       -- set password to false and use the existing password
                       password=false
                    end
                 else
                    -- set password to the new salt and verifier
                    password=password or {}
                    password["salt"]=content["salt"]
                    password["verifier"] = content["verifier"]
                end
            end
        else
           content["random_psw"] = assistant:isRandomPassword() and "1" or "0"
           content["mode"] = assistant:isPermanentMode() and "1" or "0"
           password = false
        end
        if next(helpmsg)==nil then
           local ok, err = assistant:enable(newstate=="1", content["mode"] == "1", password)
           state = assistant:enabled() and "1" or "0"
           if not ok then
              error = err
           end
           message_helper.pushMessage(T"Changes saved successfully", "success")
        else
           content["ra_enabled"] = newstate
           message_helper.pushMessage(T"Some parameters failed validation", "error")
        end
    end
end

---End of POST query processing

if not content then
   content = {}
   content["ra_enabled"] = assistant:enabled() and "1" or "0"
   content["mode"] = assistant:isPermanentMode() and "1" or "0"
   content["random_psw"] = assistant:isRandomPassword() and "1" or "0"
end
--clear all srp info
content["salt"] = ""
content["verifier"]=""

content["password"]=""
if content["random_psw"] == "1" and assistant:enabled() then
   content["password"] = assistant:password()
end

local timeout = proxy.get(path .. "timeout")[1].value
if timeout == "" then
  timeout = "30"
end

local wan_intf = proxy.get(path .. "interface")[1].value
if wan_intf == "" then
  wan_intf = "wan"
end

local wanip = proxy.get("rpc.network.interface.@" .. wan_intf .. ".ipaddr")[1].value
  ngx.print('\
\
<div class="container">\
\
');  lp.include("tabs-services.lp")   ngx.print('\
\
<div class="row">\
<div class="span11">\
\
<form class="form-horizontal" method="post" action="remoteaccess.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
<fieldset>\
');  
local infomessage = {
  alert = {
    class = "alert-info",
  }
}
local html = {}
local info=""
if wanip == "" then
  html[#html + 1] = ui_helper.createAlertBlock(T"Before being able to allow your technical support to connect to your Technicolor Gateway you must make sure WAN connection is up.", infomessage)
else
  if assistant:enabled() then
    info = string.format("<p>Remote access is currently enabled. </p><p>Click 'Apply' button with the 'Enabled' checkbox disabled to disable remote assistance on your gateway </p>")
  else
    info = string.format("<p>Remote assistance is currently disabled.</p><p> By clicking on the 'Apply' button with the 'Enabled' checkbox enabled your gateway will be accessible from your broadband connection. After %s minutes of inactivity, or on reboot, remote assistance will be automatically disabled. </p><p> Please provide the following parameters to your ISP:</p>", timeout)
  end
  html[#html + 1] = ui_helper.createAlertBlock(T(info), infomessage)
  local ra_enable_class = {
      input = {
         class = "monitor-changes",
      }
  }
  local ra_cfg_class = {
      group = {
         class ="monitor-ra_enabled monitor-1",
      }
  }
  local ra_class = {
      group = {
         class ="monitor-ra_enabled monitor-0",
      }
  }
  html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enabled", "ra_enabled", content["ra_enabled"], ra_enable_class)
  local port = assistant:port()
  if assistant:enabled() then
    local url = ""
    if port ~= nil and port ~= "" then
      url = "https://" .. wanip .. ":" .. port
    end
    html[#html + 1] = ui_helper.createLabel(T"URL", url)
    html[#html+1] = ui_helper.createLabel(T"Mode", mode_map2[content["mode"]])
  else
    html[#html + 1] = ui_helper.createInputRadio(T"Mode", "mode", mode_map, content["mode"],ra_cfg_class)
    html[#html+1] = ui_helper.createLabel(T"Mode", mode_map2[content["mode"]],ra_class)
  end

  html[#html+1] = ui_helper.createLabel(T"Username", assistant:username())
  if assistant:enabled() then
     html[#html + 1] = ui_helper.createLabel(T"Use Random Password", checkbox_map[content["random_psw"]])
     html[#html + 1] = ui_helper.createLabel(T"Password", assistant:password())
     html[#html + 1] = error and ui_helper.createLabel("Error", error) or ''
  else
     html[#html + 1] = ui_helper.createCheckboxSwitch(T"Use Random Password", "random_psw", content["random_psw"],ra_cfg_class)
     html[#html + 1] = ui_helper.createLabel(T"Use Random Password", checkbox_map[content["random_psw"]],ra_class)
     html[#html + 1] = ui_helper.createInputText(T"Password", "password", content["password"], ra_cfg_class, helpmsg["password"])
     html[#html + 1] = ui_helper.createLabel(T"Password", assistant:password(),ra_class)
     html[#html + 1] = ui_helper.createSimpleInputHidden("salt", content["salt"])
     html[#html + 1] = ui_helper.createSimpleInputHidden("verifier", content["verifier"])
  end
end

ngx.print(html)
  ngx.print('\
</fieldset>\
</form>\
\
<div id="form-changes" class="hide">\
    <div id="cancel-config" class="btn btn-large">Cancel</div>\
    <div id="save-assistance-config" class="btn btn-primary btn-large">Apply</div>\
</div>\
\
</div>\
</div>\
</div>\
\
');  
lp.include("footer.lp")
  ngx.print('\
\
<script src="/js/srp-min.js" ></script>\
<script type="text/javascript" >\
    $("#save-assistance-config").click(function () {\
        function sendData()\
        {\
            var form = $("form");\
            var params = form.serializeArray();\
            params.push({\
                 name : "action",\
                 value : "SAVE"\
            }, tch.elementCSRFtoken());\
            var target = form.attr("action");\
            tch.postParams(target,params);\
        };\
\
        var user = "');  ngx.print(assistant:username()); ngx.print('";\
        var password = $(\'input[name="password"]\').val();\
\
        if(password != "" && password != undefined) {\
             var srp = new SRP();\
             srp.generateSaltAndVerifierTheCallback(user, password, function(salt, verifier) {\
                 $(\'input[name="salt"]\').val(salt);\
                 $(\'input[name="verifier"]\').val(verifier);\
                 $(\'input[name="password"]\').val(""); // clean that up no need to send it over the air\
                 sendData();\
                 return;\
             });\
        }\
        else {\
             sendData();\
             return;\
        }\
    });\
</script>\
'); 