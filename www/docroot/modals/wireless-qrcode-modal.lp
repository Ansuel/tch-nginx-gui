--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local untaint_mt = require("web.taint").untaint_mt

local getargs = ngx.req.get_uri_args()
local getiface = string.format("%s",getargs.iface or "")
local getap = string.format("%s",getargs.ap or "")
local ifacepath = "uci.wireless.wifi-iface.@"
local appath = "uci.wireless.wifi-ap.@"

local secmodes = setmetatable({
     ["none"] =  "nopass" ,
     ["wpa2-psk"] = "WPA",
     ["wpa-wpa2-psk"] = "WPA",
     ["wpa2"] = "WPA",
     ["wpa-wpa2"] =  "WPA",
     ["wep"] =  "WEP",
}, untaint_mt )

local content = {
    ssid = ifacepath .. getiface .. ".ssid",
    secmode = appath .. getap .. ".security_mode",
    wepkey = appath .. getap .. ".wep_key",
    wpakey = appath .. getap .. ".wpa_psk_key",
    public = appath .. getap .. ".public",
}
content_helper.getExactContent(content)

local keypassphrases = setmetatable({
    ["none"] = "" ,
    ["wpa2-psk"] = content.wpakey,
    ["wpa-wpa2-psk"] = content.wpakey,
    ["wep"] = content.wepkey,
}, untaint_mt )

-- QR-Code escape function for SSID and PSK strings
-- the following characters needs to be escaped with a backslash (\): backslash (\), single-quote ('), double-quote ("),
-- dot (.), colon (:), comma (,), and semicolon (;)
-- we have the lua and the JavaScript escaping to pass as well, that's way you see so many backslashes
local qrcode_escape_entities = {  ["\\"] = "\\\\", ["\'"] = "\\'", ['"'] = '\\"',
                    ["."] = "\\.", [":"] = "\\:", [","] = "\\,", [";"] = "\\;" }
local javascript_escape_entities = {  ["\\"] = "\\\\", ["\'"] = "\\'", ['"'] = '\\"'}

--Use WLAN configuratin to compose a string: "WIFI:T:WEP;S:mynetwork;P:mypassword;;"
--These parameters are needed: SSID, Security Mode and password
local wlanconfstr = ""
if content.ssid then
    local mode =  secmodes[content.secmode]
    local password = keypassphrases[content.secmode]
    local ssid = content.ssid
    local public = content.public
    --qr code escaping of dynamic data
    ssid = ssid:gsub('[\\\'".:,;]', qrcode_escape_entities)
    password = password:gsub('[\\\'".:,;]', qrcode_escape_entities)

    local hidden = ";H:false;;"
    if public == "0" then
        hidden = ";H:true;;"
    end

    if mode == "nopass" then
        wlanconfstr  = "WIFI:T:" .. mode .. ";S:" .. ssid .. hidden
    else
        wlanconfstr  = "WIFI:T:" .. mode .. ";S:" .. ssid .. ";P:" .. password .. hidden
    end

    --javascript escaping of special characters
    wlanconfstr = string.untaint(wlanconfstr:gsub('[\\\'"]', javascript_escape_entities))
end
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Wi-Fi QR Code", false, false) ); ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/wireless-qrcode-modal.lp">\
   <fieldset>\
        <center>\
            <div id="qrcode"></div>\
        <center>\
    </fieldset>\
    </form>\
</div>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
\
<script>\
$(function(){\
    var wlanconfstr = "');  ngx.print(wlanconfstr); ngx.print('";\
    var typeNumber = 8;\
    var errorCorrectLevel = \'M\';\
    var qr = qrcode(typeNumber, errorCorrectLevel);\
    qr.addData(wlanconfstr);\
\
    qr.make();\
    qr.createImgTag(typeNumber);\
    var html = qr.createTableTag(typeNumber);\
    $("#qrcode").html(html)\
  });\
</script>\
'); 