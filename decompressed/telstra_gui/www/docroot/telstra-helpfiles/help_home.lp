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
                <legend style="border-bottom: 0px; margin-top: 10px;">Home Page</legend>\
            </div>\
            <div class="span7 container">\
                <div class="container span7">\
                    <br/>\
                    <p>Welcome to your Telstra T-Gateway Web Interface. The following pages will provide you an overview of what the various options in the T-Gateway Web Interface can do for you and your service.  The Web Interface is split up into the following section:</p>\
                    <p>&nbsp;&nbsp;<b><u>- Main Navigation Menu</u></b></p>\
                    <p>&nbsp;&nbsp;<b><u>- Dynamic Status Notification Bar</u></b></p>\
                    <p>&nbsp;&nbsp;<b><u>- Main Configuration screen</u></b></p>\
                    <br/>\
                    <H3>Help content by Category for \'Basic View\'</H3>\
                    \
                    <div class="container span7">\
                        <ul>\
                            <a href="/telstra-helpfiles/help_home.lp"><legend> Home </legend> </a>\
                            <ul><li>This area of the Gateway Web Interface will give you the status of your Broadband connection, Home Network and provide assurance steps, in the event of any issues</li></ul>\
                        </ul>\
                    </div>\
\
                    <div class="container span7">\
                        <ul>\
                            <a href="/telstra-helpfiles/help_broadband.lp"><legend>Broadband</legend></a>\
                            <ul><li>In this section you will be able to find your \'Internet Connection Information\' and/or configure your \'Internet Connection Settings\'</li></ul>\
                        </ul>\
                    </div>\
                    <div class="container span7">\
                    <ul>\
                        <a href="/telstra-helpfiles/help_wifi.lp"><legend>Wi-Fi</legend></a>\
                        <ul>\
                        <li>In this section you will be able find and change all your Wi-Fi home networking related information for your \'Main WLAN\', \'Guest1 WLAN\' and \'Guest2 WLAN\' both for 2.4G Hz and 5G Hz Radio Frequency</li>\
                        <li>Settings that you can change include:</li>\
                            <ul>\
                                <li>Wi-Fi Channel</li>\
                                <li>Wi-Fi Channel Width</li>                            \
                                <li>Turn On/Off Wi-Fi</li>\
                                <li>Network Name or also called \'SSID\'</li>\
                                <li>Wi-Fi Security Mode</li>\
                                <li>Network Key</li>\
                                <li>Turn On/Off WPS</li>\
                                <li>WPS Device PIN code</li>\
                                <li>Enable/Disable Band Steering(Please make sure the WiFi is turned on for both the 2.4G and the 5G bands)</li>\
                            </ul>\
                        </ul>\
                    </ul>\
                    </div>  \
                    <div class="container span7">\
                    <ul>\
                        <a href="/telstra-helpfiles/help_contentsharing.lp"><legend>Content Sharing</legend></a>\
                        <ul>\
                        <li>In this section you will be able to find out and change details around your DLNA Media Server. Furthermore you can:</li>\
                            <ul>\
                                <li>Turn On/Off Media Server</li>\
                                <li>Change your Media Server name</li>\
                            </ul>\
                        </ul>\
                    </ul>\
                    </div>\
\
                    <div class="container span7">\
                    <ul>\
                    <a href="/telstra-helpfiles/help_tod.lp"><legend>Parental Control</legend></a>\
                        <ul>\
                        <li>In this section you will be able to create/change/delete/view any parental control types as:</li>\
                            <ul>\
                                <li>Time of Day Access Control</li>\
                            </ul>\
                        </ul>\
                    </ul>\
                    </div>\
\
                    <div class="container span7">\
                    <ul>\
                    <a href="/telstra-helpfiles/help_services.lp"><legend>Services</legend></a>\
                        <ul>\
                        <li>In this section you will be able to create/change/delete/view services that belong to:</li>\
                            <ul>\
                                <li>Dynamic DNS</li>\
                                <li>Port Forwarding</li>\
                                <li>Remote Web Access</li>\
                                <li>Traffic Monitor</li>\
                            </ul>\
                        </ul>\
                    </ul>\
                    </div>\
                    \
                    <div class="container span7">\
                    <ul>\
                        <a href="/telstra-helpfiles/help_usersetting.lp"><legend>User Settings</legend></a>\
                        <ul><li>In this section you will be able to change/view settings that are related to user that is accessing the T-Gateway Web Management Interface</li></ul>\
                    </ul>\
                    </div>\
                   \
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