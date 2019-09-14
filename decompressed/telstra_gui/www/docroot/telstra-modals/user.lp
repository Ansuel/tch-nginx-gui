--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/telstra-snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")

-- Localization
gettext.textdomain('webui-telstra')
--
local session = ngx.ctx.session
local dm = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local username = session:getusername()

local assistance = require("web.assistance")
local assistant = assistance.getAssistant("remote")

if ngx.req.get_method() == "POST" and assistant:username() ~= username then
  local args = ngx.req.get_post_args()
  local rc = true
  if args.salt and args.verifier then
    rc = session:changePassword(args.salt, args.verifier)
    --if the user is default_user with role:admin and the legacy_salt is not null, reset it to null
    local legacy_salt = dm.get("uci.web.user.@usr_admin.legacy_salt")
    if legacy_salt and legacy_salt[1].value and ("admin" == session:getrole()) and (username == dm.get("uci.web.user.@usr_admin.name")[1].value) then
      dm.set("uci.web.user.@usr_admin.legacy_salt", "")
      dm.apply()
    end
  end
  if rc then
    if #args.default_user == 2 then
      session:toggleDefaultUser(true)
      dm.set("uci.web.uiconfig.@uidefault.defaultuser", username)
    else
      session:toggleDefaultUser(false)
      dm.set("uci.web.uiconfig.@uidefault.defaultuser", "")
    end
  end
  if rc then
    message_helper.pushMessage(T"Changes saved successfully", "success")
  else
    message_helper.pushMessage(T"Something went wrong; please try again", "error")
  end
end
  ngx.print('\
\
<div class="container">\
<div class="row">\
<div class="span11">\
\
<form class="form-horizontal" method="post" action="user.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"User Settings" ); ngx.print('</legend>\
');  
  local defuser_attribs = {
    input = {
      class = "monitor-changes monitor-default_user monitor-1 monitor-0",
      id = "defuser"
    }
  }
  local alert_attribs = {
    alert = {
        class = "alert-error monitor-default_user monitor-1"
    }
  }
  local password_attribs = {
    input = {
      maxlength= "64",
      class = "monitor-changes",
      id = "new_password"
    }
  }
  local dummy_password = "********"
  local defuser = session:isdefaultuser() and "1" or "0"
  ngx.print(ui_helper.createLabel(T"Current User", username))
  -- Assist user can't be default user because the assist user must have a password
  if assistant:username() ~= username then
    ngx.print(
      ui_helper.createAlertBlock(T"When Default User is on, there is no login required to access the Web Interface. This is not recommended.", alert_attribs),
      ui_helper.createCheckboxSwitch(T"Default User", "default_user", defuser, defuser_attribs),
      ui_helper.createInputPassword(T"Password", "new_password", dummy_password, password_attribs)
    )
    password_attribs.input.id = nil
    ngx.print(ui_helper.createInputPassword(T"Confirm Password", "confirm_password", dummy_password, password_attribs))
  end
  ngx.print('\
</fieldset>\
<div id="form-changes" class="hide">\
    <div id="cancel-config" class="btn btn-large">Cancel</div>\
    <div id="save-user-config" class="btn btn-primary btn-large">Save</div>\
</div>\
\
</form>\
\
</div>\
</div>\
</div>\
\
<script src="/js/srp-min.js" ></script>\
<script type="text/javascript">\
(function() {\
  function clear_error_password()\
  {\
    var upass = $(\'input[name="new_password"],input[name="confirm_password"]\');\
    upass.closest(".control-group").removeClass("error");\
    upass.first().next().remove();\
  }\
  function display_error_password(msg)\
  {\
    var upass = $(\'input[name="new_password"],input[name="confirm_password"]\');\
    upass.addClass("error");\
    upass.closest(".control-group").addClass("error");\
    upass.first().after(\'<span class="help-inline">\' + msg + \'</span>\');\
  }\
  function display_alert()\
  {\
    $(\'.alert\').detach();\
    $(\'.form-horizontal\').before(\'<div class="alert alert-error">Some parameters failed validation</div>\');\
  }\
  function sendData(salt, verifier)\
  {\
    // don\'t send passwords over\
    $(\'input[name="new_password"]\').val("");\
    $(\'input[name="confirm_password"]\').val("");\
    var form = $("form");\
    form.append($("<input>", {\
      "name": "CSRFtoken",\
      "value": $("meta[name=CSRFtoken]").attr("content"),\
      "type": "hidden"\
    }));\
    if (typeof salt !== "undefined") {\
      form.append($("<input>", {\
        "name": "salt",\
        "value": salt,\
        "type": "hidden"\
      })).append($("<input>", {\
        "name": "verifier",\
        "value": verifier,\
        "type": "hidden"\
      }));\
    }\
    form.submit();\
  }\
\
  $(document).on("click", "#save-user-config", function() {\
    clear_error_password();\
    var password = $(\'input[name="new_password"]\').val();\
    var password2 = $(\'input[name="confirm_password"]\').val();\
\
    if (password.length < 12) {\
      display_error_password("Minimum 12 Characters");\
      display_alert();\
    }\
    else if (password !== password2) {\
      display_error_password("Passwords do not match");\
      display_alert();\
    }\
    else if (password == "********") {\
      sendData();\
    }\
    else {\
      var srp = new SRP();\
      var username = "');  ngx.print( username ); ngx.print('";\
      srp.generateSaltAndVerifierTheCallback(username, password, function(salt, verifier) {\
        sendData(salt, verifier);\
      });\
    }\
  });\
  $(document).on("change", "#new_password", function() {\
    var $defuser = $("#defuser");\
    if ($defuser.prop("checked")) {\
      $defuser.click();\
    }\
  });\
}());\
</script>\
\
');  
lp.include("footer.lp")
  ngx.print('\
'); 
