--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-nfc')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local datamodel = require("datamodel")
local variant = datamodel.get("uci.env.var.prod_friendly_name")[1].value or ""

if ( variant == "DJN2130" ) or ( variant == "Technicolor TG800vac" ) then
  local content_nfc = {
    enabled = "rpc.nfc.enabled",
  }
  content_helper.getExactContent(content_nfc)
  
  local nfclight = "0"
  local nfc_enabled = T"NFC Disabled"
  
  if content_nfc["enabled"] == "true" then
    nfclight = "1"
    nfc_enabled = T"NFC Enabled"
  end
  
  local modalPath = nil
  local session = ngx.ctx.session
  if session:hasAccess("/modals/nfc-modal.lp") then
      modalPath = "/modals/nfc-modal.lp"
  end
    ngx.print('\
  \
  <div class="span3">\
    <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
      ');  ngx.print(ui_helper.createCardHeader(T"NFC", modalPath, nil, nil) ); ngx.print('\
      <div class="content card_bg" data-bg-text="&#xf09e;">\
  	  <div class="divtable">\
          ');  ngx.print( ui_helper.createSimpleLight(nfclight, nfc_enabled, nil,"fa-rss") ); ngx.print('\
        </div>\
  	</div>\
    </div>\
  </div>\
  ');
end