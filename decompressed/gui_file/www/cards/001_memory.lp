--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")

-- All data resides on the card and updates automatically (using the same data as the
-- /ajax/cpuload.lua endpoint employed by the Modem card)
local modalPath = nil
local session = ngx.ctx.session

if session and session:hasAccess("/modals/memory-modal.lp") then
   modalPath = "/modals/memory-modal.lp"
end

ngx.print('\
\
<div class="span3" id="memory-card">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print( ui_helper.createCardHeader("Memoria", modalPath, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf538;">\
      <div class="divtable">\
        <div style="line-height: 1.45; white-space: nowrap;">\
          <i class="fa fa-memory"></i>\
          <strong>RAM: <span data-bind="text: mem_used"></span> / <span data-bind="text: mem_total"></span></strong>\
          <div style="padding-left: 26px;">\
            <div><strong data-bind="text: mem_bar"></strong>    (<strong data-bind="text: mem_pct"></strong>)</div>\
            <div style="display: grid; grid-template-columns: 1fr 1fr; column-gap: 8px;">\
              <span>Libera: <strong data-bind="text: mem_free"></strong></span><br>\
              <span>Disponibile: <strong data-bind="text: mem_available"></strong></span><br>\
              <span>Cache: <strong data-bind="text: mem_cache"></strong></span>\
            </div>\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
<script>\
$(document).ready(function () {\
\tnew modgui.createAjaxUpdateCard("memory-card","/ajax/cpuload.lua","MemoryCardInterval",5000);\
})\
</script>\
');
