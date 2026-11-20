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
<style>#memory-card .card_bg::before,#memory-card .card_bg::after{transform:translateY(3px)}</style>\
<div class="span3" id="memory-card">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print( ui_helper.createCardHeader(T"Memory", modalPath, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf0a0;">\
      <div class="divtable" style="position: relative; top: -8px;">\
        <div style="line-height: 1.25; white-space: nowrap;">\
          <i class="fa fa-memory"></i>\
          <strong>RAM: <span data-bind="text: mem_used"></span> / <span data-bind="text: mem_total"></span></strong>\
          <div style="padding-left: 26px;">\
            <div><strong data-bind="text: mem_bar"></strong>    (<strong data-bind="text: mem_pct"></strong>)</div>\
            <div style="display: grid; grid-template-columns: auto auto; justify-content: start; column-gap: 10px; font-size: 13px;">\
              <span>');  ngx.print( T"Free" ); ngx.print(': <strong data-bind="text: mem_free"></strong></span>\
              <span>');  ngx.print( T"Cache" ); ngx.print(': <strong data-bind="text: mem_cache"></strong></span>\
              <span style="grid-column: 1 / -1;">');  ngx.print( T"Available" ); ngx.print(': <strong data-bind="text: mem_available"></strong></span>\
            </div>\
          </div>\
        </div>\
        <div style="line-height: 1.25; white-space: nowrap; margin-top: 4px;">\
          <i class="fa fa-hdd"></i>\
          <strong>');  ngx.print( T"Internal storage" ); ngx.print('</strong>\
          <div style="padding-left: 26px;">\
            <div><span>');  ngx.print( T"Available space" ); ngx.print(': <strong data-bind="text: storage_internal"></strong></span></div>\
            <div><span>USB: <strong data-bind="text: storage_usb"></strong></span></div>\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
<script>\
$(document).ready(function () {\
\tnew modgui.createAjaxUpdateCard("memory-card","/ajax/cpuload.lua","MemoryCardInterval",1000);\
})\
</script>\
');
