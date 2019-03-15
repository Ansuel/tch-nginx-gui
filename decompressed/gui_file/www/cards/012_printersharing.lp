--pretranslated: do not change this file
 
local istainted = string.istainted

-- Enable localization
gettext.textdomain('webui-printersharing')

local proxy = require("datamodel")
local match = string.match
local ui_helper = require("web.ui_helper")
local attributes = { span = { class = "span4" } }
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local modalPath = nil
if session:hasAccess("/modals/printersharing-modal.lp") then
  modalPath = "/modals/printersharing-modal.lp"

local  printer_info =  proxy.get("sys.usb.device.")

local content = {
  printersharing_enabled = "uci.printersharing.config.enabled"
}
content_helper.getExactContent(content)

local printersharing_state = T"Printer Sharing disabled"
if content["printersharing_enabled"] == "1" then
  printersharing_state = T"Printer Sharing enabled"
end

local pathIndexList = {}
  ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print(ui_helper.createCardHeader(T"Printer Sharing", modalPath, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf02f;">\
	  <div class="divtable">\
      ');  ngx.print(ui_helper.createSimpleLight(content["printersharing_enabled"], printersharing_state, attributes,"fa fa-print")); ngx.print('\
      ');  for _,v in ipairs(printer_info) do
        local pathIndex = match(v.path, "^sys%.usb%.device%.(%d+)%.interface%.%d+%.")
	if pathIndex then
          if v.param == "bInterfaceClass" and v.value == "07" then -- bInterfaceClass value "07" indicates printer device
            pathIndexList[pathIndex] = true
          end
        end
      end  ngx.print('\
      ');  for i,v in pairs(pathIndexList) do
        local printerDetails = {
          manufacturer = "sys.usb.device."..i..".manufacturer",
          product = "sys.usb.device."..i..".product",
        }content_helper.getExactContent(printerDetails)
        ngx.print('\
        <p class="subinfos">\
	<div class="light green" id="PrinterSharing_LED_Id"></div>\
	  ');  ngx.print(printerDetails["product"]); ngx.print('\
          ');  ngx.print(printerDetails["manufacturer"]); ngx.print('\
        </p>\
      ');  end   ngx.print('\
	  </div>\
    </div>\
  </div>\
</div>\
\
');  
end
  ngx.print('\
'); 
