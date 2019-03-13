<%
-- Enable localization
gettext.textdomain('webui-wizard')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local wizard_helper = require("wizard")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local user_path = "uci.web.user.@usr_admin."
local vWEP = post_helper.validateWEP
local gVSLIR = post_helper.getValidateStringLengthInRange
local match = string.match

local mapParams = {
  web_username = user_path .. "name",
  web_password = user_path .."name",
  srp_salt = user_path .."srp_salt",
  srp_verifier = user_path .. "srp_verifier",
}

local function clearPassword(value, object, key)
    if object["action"] == "VALIDATE" or object["action"] == "SAVE" then
        local userData = {
            web_username = user_path .. "name",
            srp_salt = user_path .."srp_salt",
        }
        content_helper.getExactContent(userData)
        if userData.web_username ~= object.web_username and userData.srp_salt == object.srp_salt then
            return nil, T"Please set the new password for new user."
        end
    end

    object[key] = nil
    return true
end

local mapValid = {
    web_username = vNES,
    web_password = clearPassword,
    srp_salt = gVSLIR(8,8),
    srp_verifier = gVSLIR(512,512),
}

local content, helpmsg = wizard_helper.handleQuery(mapParams, mapValid)

if ngx.var.request_method == "POST" and ngx.var.content_type and match(ngx.var.content_type, "application/x%-www%-form%-urlencoded") then
    if content["action"] == "SAVE" and not helpmsg["web_username"] and not helpmsg["web_password"]
        and not helpmsg["srp_salt"] and not helpmsg["srp_verifier"] then
       ngx.ctx.session:reloadAllUsers()
    end
end
%>
<div class='wizard-card'>
    <fieldset>
      <%="<legend></legend>"%>
      <%='<h4>' .. T"Router Security" .. '</h4>'%>
      <%
        local html = {}
        local info_attr = {
            alert = {
                class = "alert-info"
            },
         }
        html[#html+1] = ui_helper.createAlertBlock(T"In the next pages you will use the quick set-up guide to personalise your Router. Please enter a username and password to be used to gain access to your Router Management Console. It is recommended that you choose a unique password for added security.", info_attr)
        html[#html+1] = ui_helper.createMessages(message_helper.popMessages())
        html[#html+1] = ui_helper.createInputText(T"Desired Username:", "web_username", content["web_username"], nil, helpmsg["web_username"])
        html[#html+1] = ui_helper.createInputPassword(T"Desired Password:", "web_password", "",nil, helpmsg["web_password"])
        html[#html+1] = ui_helper.createInputPassword(T"Retype Password:", "web_password2", "",nil, helpmsg["web_password"])
        local srp_class = {
            group = { class = "hide" }
        }
        html[#html+1] = ui_helper.createInputText("", "srp_salt", content["srp_salt"], srp_class, helpmsg["srp_salt"])
        html[#html+1] = ui_helper.createInputText("", "srp_verifier", content["srp_verifier"], srp_class, helpmsg["srp_verifier"])
        html[#html+1] = ui_helper.createAlertBlock("<strong>" .. T"Remember to make a note of your username and password" .."</strong>", info_attr)
        ngx.print(html)
      %>
    </fieldset>
</div>
<div class='wizard-confirm'>
    <fieldset>
      <%
        local html = {}
        html[#html+1] = ui_helper.createLabel(T"Desired Username:", content["web_username"])
        html[#html+1] = ui_helper.createLabel(T"Desired Password:", "********")
        ngx.print(html)
      %>
    </fieldset>
</div>
<script type="text/javascript">
(function() {
	
	$.getScript("/js/srp-min.js");
	
    function clear_error(id)
    {
        var upass = $('.modal input[name='+id+']');
        upass.removeClass("tooltip-on error");
        upass.closest(".control-group").removeClass("error");
        upass.first().next().remove();
    }

    function display_error(id,msg)
    {
        var upass = $('.modal input[name='+id+']');
        upass.addClass("error");
        upass.closest(".control-group").addClass("error");
        upass.first().after('<span class="help-inline">' + msg + '</span>');
    }

    function display_alert()
    {
        $('.alert-error').detach();
        var upass = $('.modal input[name="web_username"]');
        upass.closest(".control-group").before('<div class="alert alert-error">T"Some parameters failed validation"</div>');
    }

    $("#wizard-next").on("click", function(){
        if ($('input[name="web_username"]').is(":visible")) {
            clear_error("web_username");
            clear_error("web_password");
            clear_error("web_password2");

            var user = $('input[name="web_username"]').val();
            var password = $('input[name="web_password"]').val();
            var password2 = $('input[name="web_password2"]').val();
            var salt = $('input[name="srp_salt"]').val();
            var verifier = $('input[name="srp_verifier"]').val();
            var validated = true;
            if(password !== password2) {
                display_error("web_password2","<%= T'Passwords do not match' %>");
                validated = false;
            }

            if(user == "") {
                display_error("web_username","<%= T'Username can not be empty' %>");
                validated = false;
            }

            if (password == "") {
                if (verifier.length != 512 || salt.length != 8) {
                    display_error("web_password","<%= T'You must fill your password' %>");
                    display_error("web_password2","<%= T'You must fill your password' %>");
                    validated = false
                }
            }

            if (validated) {
                if (password == "") {
                    tch.nextWizardCard(1);
                } else
                {
                    var srp = new SRP();
                    srp.generateSaltAndVerifierTheCallback(user, password, function(salt, verifier) {
                        $('input[name="srp_salt"]').val(salt);
                        $('input[name="srp_verifier"]').val(verifier);
                        $('input[name="web_password"]').val(""); // clean that up no need to send it over the air
                        $('input[name="web_password2"]').val("");
                        tch.nextWizardCard(1);
                    });
                }
            } else {
                display_alert();
            }
            return false;
        }
        return
    });

    $("#wizard-previous").on("click", function(){
        if ($('input[name="web_username"]').is(":visible")) {
            $('input[name="web_password"]').val('');
            $('input[name="web_password2"]').val('');
            tch.nextWizardCard(-1);
            return false;
        }
    });
});
</script>
