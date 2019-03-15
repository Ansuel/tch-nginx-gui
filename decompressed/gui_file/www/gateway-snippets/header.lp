--pretranslated: do not change this file

-- Enable localization

gettext.textdomain('webui-core')
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format
local session = ngx.ctx.session
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')

local function apply(action)
  proxy.set("rpc.system.modgui.scriptRequest.state","Requested")
  proxy.set("rpc.system.modgui.utility." .. action, "1")
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
      proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  if post_args.action == "checkver" then
  return apply("checkver")
  end
  if post_args.action == "autoupgrade_view" then
  proxy.set("uci.modgui.gui.autoupgradeview", "none")
  proxy.apply()
  end
  if post_args.do_signout then
    session:logout()
    -- Now we redirect to / until we find a better solution
    -- Otherwise, the current page might be rendered while the default user is not allowed to see it
    -- since the access was checked for the user "before" logging out
    -- TODO: find a more elegant solution, in session module?
    ngx.redirect("/");
  end
  if post_args.passwordchange == "dontremind" then
    local result = content_helper.getMatchedContent("uci.web.user.", {name = session:getusername()})
    if result and #result > 0 then
      if proxy.set(result[1].path .. "password_reminder", "0") then
        proxy.apply()
      end
    end
  end
end

local cui = {
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  gui_skin = "uci.modgui.gui.gui_skin",
  gui_version = "uci.modgui.gui.gui_version",
  outdated_ver = "uci.modgui.gui.outdated_ver",
  amule_webui = "uci.modgui.app.amule_webui",
  aria2_webui = "uci.modgui.app.aria2_webui",
  luci_webui = "uci.modgui.app.luci_webui",
  transmission_webui = "uci.modgui.app.transmission_webui",
  blacklist_application = "uci.modgui.app.blacklist_app",
  new_ver = "uci.modgui.gui.new_ver",
  autoupgrade_hour= "uci.modgui.gui.autoupgrade_hour",
  autoupgrade_view = "uci.modgui.gui.autoupgradeview",
  firstpage = "uci.modgui.gui.firstpage",
  randomcolor = "uci.modgui.gui.randomcolor",
  gui_animation = "uci.modgui.gui.gui_animation",
}

content_helper.getExactContent(cui)

local pageselector = {}

if cui.firstpage == "stats" then
  pageselector.page = "cards.lp"
  pageselector.text = T"Cards"
  pageselector.otherpage = "stats.lp"
  pageselector.othertext = T"Stats"
else
  pageselector.page = "stats.lp"
  pageselector.text = T"Stats"
  pageselector.otherpage = "cards.lp"
  pageselector.othertext = T"Cards"
end

ngx.print('\
<div class="gateway_bg" data-bg-text="&#xf0ac;"></div>\
  <div class="header" id="headertab">\
  <div class="row" style="z-index : 3;  position: relative;" >\
    <div class="header-logo">\
        <a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank">\
      <picture>');

    if cui.gui_skin == "TIM" then
      ngx.print('<img width="168px" height="39px" src="/img/TIM.png">');
    elseif cui.gui_skin == "Fritz" or string.match(cui.gui_skin, "[dD][aA][rR][kK]") then
      ngx.print('<source srcset="/img/logo_white.webp" type="image/webp">\
        <source srcset="/img/logo_white.png" type="image/png">\
        <img width="131px" height="50px" src="/img/logo_white.png">');
    else
      ngx.print('<source srcset="/img/logo.webp" type="image/webp">\
        <source srcset="/img/logo.png" type="image/png">\
        <img width="131px" height="50px" src="/img/logo.png">');
    end
    ngx.print('  </picture>\
    </a>\
    </div>\
    ');

        local html = {}

    html[#html + 1] = [[<div class="header-button">]]
    if not ( session:getusername() == "guest" ) then
      html[#html + 1] = '<div class="header-sub-button">'
      local hideUpdateButton = ""
      if cui.outdated_ver == "0" then
        hideUpdateButton = "hide"
      end
      html[#html + 1] = '<div id="upgradebtn" class="btn someInfos '.. hideUpdateButton  ..'"'
      if not ( cui.gui_skin == "Fritz" ) then
        html[#html + 1] = ' rel="tooltip" data-placement="bottom" data-original-title="'
        html[#html + 1] = T"Go to the gateway tab and click on the Update button, to autoupgrade to the new GUI."
        html[#html + 1] = '" '
      end
      html[#html + 1] = 'data-toggle="modal" data-remote="modals/modgui-modal.lp?action=manualguiupgrade">'
      html[#html + 1] = '<span>'
      html[#html + 1] = T"Update"
      html[#html + 1] = '</span>'
      html[#html + 1] = '</div>'
      html[#html + 1] = '</div>'
      html[#html + 1] = '<div class="header-sub-button">'
      html[#html + 1] = '<div class="btn" id="wizard-btn" data-toggle="modal" data-remote="modals/wizard-modal.lp">' .. T"Setup Wizard" .. '</div>'
      html[#html + 1] = '</div>'
      html[#html + 1] = '<div class="header-sub-button">'
      html[#html + 1] =   '<div class="btn" id="swtichbuttom">'
      html[#html + 1] =     '<span id="refresh-cards"></span>'
      html[#html + 1] =     '<span id="cards-text">' .. pageselector.text .. '</span>'
      html[#html + 1] =   '</div>'
      html[#html + 1] = '</div>'
        end
      html[#html + 1] = '<div class="header-sub-button">'
      html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language())
      html[#html + 1] = '</div>'
    html[#html + 1] = '<div class="header-sub-button">'
    if session:isdefaultuser() then
            html[#html + 1] = '<a href="login.lp" class="btn" id="signin">'
            html[#html + 1] = T"Sign in"
            html[#html + 1] = '</a>'
        else
            html[#html + 1] = [[          <div class="btn-group" id="logged">
                    <button class="btn"> ]]
            html[#html + 1] = session:getusername()
            html[#html + 1] = [[ </button>
                    <button class="btn dropdown-toggle" data-toggle="dropdown"><span class="caret"></span> ]]
      html[#html + 1] = T"Advanced "
            html[#html + 1] = [[
                    </button>
                    <ul class="dropdown-menu pull-right"> ]]
            if session:getusername() ~= assistant:username() then
                html[#html + 1] = [[ <li><a tabindex="-1" href="/password.lp" id="changepass"> ]]
                html[#html + 1] = T"Profile Settings"
                html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
            end
        html[#html + 1] = [[ <li><a tabindex="-1" href="https://www.ilpuntotecnicoeadsl.com/forum/index.php/topic,77325.0.html" target="_blank"> ]]
        html[#html + 1] = T"Support Forum"
        html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
        html[#html + 1] = [[ <li><a tabindex="-1" href="https://github.com/Ansuel/tch-nginx-gui" target="_blank"> ]]
        html[#html + 1] = T"Github GUI"
        html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
      if not ( session:getusername() == "guest" ) then
        if cui.luci_webui == "1" then
          html[#html + 1] = [[ <li><a tabindex="-1" target="_blank" href="/"
                  onclick="javascript:event.target.port=9080;event.target.protocol='http'"> ]]
          html[#html + 1] = T"Luci WebUI"
          html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
        end
        if cui.amule_webui == "1" then
        html[#html + 1] = [[ <li><a tabindex="-1" target="_blank" href="/"
                onclick="javascript:event.target.port=4711;event.target.protocol='http'"> ]]
        html[#html + 1] = T"aMule Webui"
        html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
        end
        if cui.aria2_webui == "1" then
        html[#html + 1] = [[ <li><a tabindex="-1" target="_blank" href="/aria"> ]]
        html[#html + 1] = T"Aria2 Webui"
        html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
        end
        if cui.transmission_webui == "1" then
          html[#html + 1] = [[ <li><a tabindex="-1" target="_blank" href="/"
                onclick="javascript:event.target.port=9091;event.target.protocol='http'"> ]]
        html[#html + 1] = T"Transmission Webui"
        html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
        end
      end
            html[#html + 1] = [[ <li><a tabindex="-1" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]

        end
    html[#html + 1] =   "</div>"
        html[#html + 1] =  "</div>"
    html[#html + 1] = "</div>"

    local alert_outdated_ver = {
      alert = {
        class = "alert",
        id = "upgrade-alert"
      },
    }
    if cui.outdated_ver == "0" then
      alert_outdated_ver.alert.class = "alert hide"
    end
    html[#html + 1] = ui_helper.createAlertBlock(format(T'Update available! Version: <strong id="new-version-text">%s</strong>',cui.new_ver),alert_outdated_ver)

    local autoupgrade_view = cui.autoupgrade_view
    if not ( autoupgrade_view == "none" ) and not ( autoupgrade_view == "" ) then
      local alert_upgrade_success = {
        alert = {
          class = "alert-success",
          id = "upgrade-alert"
        },
      }
      local upgrade_text = format(T"The modem has been updated to version <strong>%s</strong> successfully",cui.gui_version)
      if autoupgrade_view == "auto" then
        upgrade_text = format(T("The modem has been updated automatically at <strong>%s:00</strong>" ..
              " to version <strong>%s</strong> successfully"),cui.autoupgrade_hour, cui.gui_version)
      end

      html[#html + 1] = ui_helper.createAlertBlock(upgrade_text,alert_upgrade_success)
    end
    if not session:isdefaultuser() and not session:retrieve("password_reminder_shown") and session:getusername() ~= assistant:username() then
      local result = content_helper.getMatchedContent("uci.web.user.", {name = session.getusername()})
        if result and result[1].password_reminder ~= "0" then
          html[#html + 1] = '<div class="modal fade in" id="password_reminder">'
          html[#html + 1] = ui_helper.createHeader(T"Change Password")
          html[#html + 1] = '<div class="modal-body update">'
          html[#html + 1] = '<form class="form-horizontal" method="post" action="gateway.lp">'
          html[#html + 1] = ui_helper.createSimpleInputHidden("CSRFtoken", session:getCSRFtoken())
          html[#html + 1] = '<fieldset>'
          local attr = {radio = {style = "display: block"}}
          html[#html + 1] = ui_helper.createInputRadio("", "passwordchange", {{"now", T"Now"},{"remindlater", T"Remind me later"},{"dontremind", T"Do not remind me again"}},nil,attr)
          html[#html + 1] = '</fieldset>'
          html[#html + 1] = '</form>'
          html[#html + 1] = '</div>'
          html[#html + 1] = ui_helper.createFooter()
          html[#html + 1] = '</div>'
          html[#html + 1] = '\
          <script>\
            $("#password_reminder").modal();\
            $("#save-config").on("click", function(){\
            var value = $("input[name=passwordchange]:checked").val();\
            if(value == "now"){\
              window.location = "/password.lp";\
            }else if(value == "remindlater"){\
              $("#password_reminder").modal(\'hide\');\
            }else if(value == "dontremind"){\
              $("#password_reminder form").submit();\
            }\
            return false;\
            });\
          </script>\
          '
        end
      session:store("password_reminder_shown", true)
    end
    html[#html + 1] = '<a href="#footer" id="scroll-down" class="scroll-down" address="true"></a>'
    html[#html + 1] = '<a href="#headertab" id="scroll-up"class="scroll-up hide" address="true"></a>'
ngx.print(html)
ngx.print('\
</div>\
<script>\
\
  var gui_var = {\
	randomcolor : "'); ngx.print(cui.randomcolor or "0"); ngx.print ('",\
    gui_animation : "'); ngx.print(cui.gui_animation or "1"); ngx.print ('",\
	stats_text : "'); ngx.print(T"Stats"); ngx.print ('",\
	cards_text : "'); ngx.print(T"Cards"); ngx.print ('",\
	pageselector_page : "'); ngx.print(pageselector.page); ngx.print ('",\
	pageselector_text : "'); ngx.print(pageselector.text); ngx.print ('",\
	pageselector_othertext : "'); ngx.print(pageselector.othertext); ngx.print ('",\
	autoupgradeview : "'); ngx.print(autoupgrade_view or "none"); ngx.print ('",\
	gui_outdated : "'); ngx.print(T"GUI is outdated"); ngx.print('",\
	gui_updated : "'); ngx.print(T"GUI is updated"); ngx.print('",\
  };\
\
</script>\
<script src="/js/shared-script.js?version='); ngx.print(cui.gui_version); ngx.print('" ></script>\
');