--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ok_em, easymesh_helper = pcall(require, "easymesh_helper")
if ok_em and easymesh_helper and easymesh_helper.is_supported and not easymesh_helper.is_supported() then
    return
end

local format = string.format
local tonumber = tonumber
local table = table
local ui_helper = require("web.ui_helper")
local postHelper = require("web.post_helper")
local content_helper = require("web.content_helper")
local has_variant, variant_helper = pcall(require, "variant_helper")
local variantHelper = nil
if has_variant then
    variantHelper = postHelper.getVariant(variant_helper, "ExtenderPage", "extenderConfig")
end
local proxy = require("datamodel")
local format, find, sub, match = string.format, string.find, string.sub, string.match

local content = {
  count = "rpc.multiap.ExtenderNumberOfEntries",
  agentState = "uci.multiap.agent.enabled",
  controllerState = "uci.multiap.controller.enabled"
}
local ok = pcall(content_helper.getExactContent, content)
if not ok then
  -- multiap datamodel not available on this device
  content.count = "0"
  content.agentState = "0"
  content.controllerState = "0"
end
local getState = content.agentState == "1" and true or false
if has_variant and postHelper.getVariantValue(variantHelper, "extenderInfo") then
  getState = content.agentState == "1" and content.controllerState == "1" and true or false
end

local easyMeshState = getState and T"Enabled" or T"Disabled"
local statusLed = getState and "light green" or "light off"
local nExt = tonumber(content["count"]) or 0
local modalPath = nil
local switchName = nil
local modal_link = ""
local session = ngx.ctx.session
if session:hasAccess("/modals/easy-mesh-configuration.lp") then
  modalPath = "/modals/easy-mesh-configuration.lp"
  modal_link='class="modal-link" data-toggle="modal" data-remote="/modals/easy-mesh-configuration.lp" data-id="easy-mesh-configuration"'
elseif not session:isdefaultuser() then
  return
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print( ui_helper.createCardHeader(T"EasyMesh", modalPath, switchName, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf542;">\
      <div class="divtable" style="position: relative; z-index: 20;">\
        <div id="easy_mesh">\
          ');
          ngx.print(ui_helper.createSimpleLight(getState and "1" or "0", format("EasyMesh %s", easyMeshState)))
          if getState then
            ngx.print(
              '<p class="subinfos">',
              format( N('<strong id="Ext_Count" %1$s>%2$d Extender</strong> connected',
                        '<strong id="Ext_Count" %1$s>%2$d Extenders</strong> connected', nExt),
                        modal_link, nExt),
              '</p>'
            )
          end
          ngx.print('\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
'); 