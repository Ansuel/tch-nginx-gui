--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/telstra-snippets/")
lp.include("header.lp")
lp.include("help_menubar.lp")
  ngx.print('\
\
<div class="container toplevel" style="width:830px">\
    <div class="row">\
        <div class="span11">\
            <div class="span3 help-block">\
                <legend style="border-bottom: 0px; margin-top: 10px;">WI-FI</legend>\
            </div>\
            <div class="span7 container">\
                <div class="container span7">\
                    <h3>Change your Wi-Fi details on your T-Gateway</h3> \
                    <div class="container span7">\
                        <legend>Step 1:</legend>&nbsp;&nbsp;Click on \'Wi-Fi\' tab on the menu bar\
                    </div>\
                                      \
                    <div class="container span7">\
                        <legend>Step 2:</legend>&nbsp;&nbsp;Select the Wi-Fi interface you want to change by clicking corresponding tab\
                    </div>\
                    <div class="container span7">\
                        <legend>Step 3:</legend>&nbsp;&nbsp;Make changes to:\
                        <ul>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Wi-Fi Channel</li> \
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Wi-Fi Channel Width</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Turn On/Off Wi-Fi</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Network Name (SSID) field</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Security Mode</li> \
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Network Key</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Turn On/Off WPS</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>WPS Device PIN code</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Enable/Disable Band Steering(Please make sure the Wi-Fi is turned on for both the 2.4G and the 5G bands)</li>\
                        </ul>\
                    </div>\
                    <div class="container span7">\
                        <legend>Step 4:</legend>&nbsp;&nbsp;Click on \'Save\' button to save your configuration\
                    </div>\
                </div>\
            </div>\
        </div>\
    </div>\
</div>\
\
');  
lp.include("footer.lp")
  ngx.print('\
\
\
'); 