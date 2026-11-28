--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")

local session = ngx.ctx.session

local function is_datausage_enabled()
  local ok, datausage_info = pcall(proxy.get, "uci.datausage.interface.")
  if not ok or type(datausage_info) ~= "table" then
    return false
  end
  local datausage_interfaces = content_helper.convertResultToObject("uci.datausage.interface.", datausage_info) or {}
  for _, interface in ipairs(datausage_interfaces) do
    if interface.enabled == "1" then
      return true
    end
  end
  return false
end

local datausage_enabled = is_datausage_enabled()
if session:hasAccess("/modals/datausage.lp") then

  local datausage_enabled_map = {
    ["0"] = T"Disabled",
    ["1"] = T"Enabled"
  }

  local datausage_attributes = {
    light = { id = "datausage_led" },
    span = { class = "span4",
    id = "datausage"}
  }

  local datausage_enabled_val = datausage_enabled and "1" or "0"
    ngx.print('\
\
  <div class="span3" id="datausage-card">\
    <div class="smallcard">\
      ');  ngx.print( ui_helper.createCardHeader(T"Data Usage", "modals/datausage.lp") ); ngx.print('\
      ');  if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
      <div class="content">\
      ');  else   ngx.print('\
      <div class="content card_bg" data-bg-text="&#xf080;">\
      ');  end   ngx.print('\
        <p class="subinfos">\
          ');  if datausage_enabled then  ngx.print('\
            ');  ngx.print( ui_helper.createSimpleLight(datausage_enabled_val, datausage_enabled_map[datausage_enabled_val], datausage_attributes)); ngx.print('\
            <br><i id="uploadlink"  style= "margin-left:20px;"class=\'icon-upload icon-large\'>0 bit/s</i><br>\
            <i id="downloadlink"  style= "margin-left:20px;" class=\'icon-download icon-large\'>0 bit/s</i>\
          ');  else  ngx.print('\
            ');  ngx.print( ui_helper.createSimpleLight(datausage_enabled_val, datausage_enabled_map[datausage_enabled_val], datausage_attributes)); ngx.print('\
          ');  end  ngx.print('\
        </p>\
      </div>\
    </div>\
  </div>\
');  
  if datausage_enabled then
    ngx.print([=[
<script>
$(function () {
    var card = document.getElementById("datausage-card");
    if (!card) return;
    var download = $(card).find("#downloadlink"), upload = $(card).find("#uploadlink");
    function refresh() {
        var send = window.modguiDashboardRead || $.ajax;
        return send({url: "/ajax/datausage.lua?auto_update=true", type: "POST", dataType: "text",
            data: [{name: "action", value: "overview"}, tch.elementCSRFtoken()], timeout: 8000
        }).done(function (data) {
            if (document.getElementById("datausage-card") !== card) return;
            var rates = data.split(",");
            if (rates.length !== 2 || !isFinite(rates[0]) || !isFinite(rates[1])) return;
            download.text(get_bitrate(rates[0]));
            upload.text(get_bitrate(rates[1]));
        });
    }
    modgui.createAjaxUpdateCard("datausage-card", null, "DataUsageCardInterval", 1000, refresh);
});
</script>
]=])
  end
end
