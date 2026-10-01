--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")

local session = ngx.ctx.session

local function is_datausage_enabled()
  local datausage_info = proxy.get("rpc.datausage.interface.")
  local datausage_interfaces = content_helper.convertResultToObject("rpc.datausage.interface.", datausage_info)
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
  <div class="span3">\
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
end
  ngx.print('\
\
<script>\
\
var params = [ { name: \'action\', value: "overview" }, tch.elementCSRFtoken() ];\
var data_usage = ');  ngx.print(datausage_enabled); ngx.print(';\
\
function updatelink(){\
  $.post("/ajax/datausage.lua",params, function(datausage) {\
    $("#downloadlink").text(get_bitrate(datausage.split(",")[0]));\
    $("#uploadlink").text(get_bitrate(datausage.split(",")[1]));\
  });\
}\
\
if (data_usage){\
  var stopUpdateLink = setInterval(updatelink, 3000);\
}\
</script>\
'); 