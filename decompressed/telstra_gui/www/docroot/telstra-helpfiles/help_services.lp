--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/telstra-snippets/")
  ngx.print('\
\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
    <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <link href="/css/gw-telstra.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-telstra-min.js" ></script>\
    <title>');  ngx.print( T"Telstra Gateway" ); ngx.print('</title>\
\
    <style type="text/css">\
        .service_legend { \
            border-bottom: 0px; \
            margin-bottom: 1px; \
            font-size: 20px; \
            line-height: 33px;\
        }\
        a:link {\
            color: #333333;\
        }\
        a:hover {\
            color: #3399cc;\
        }\
        a:active {\
            color: #4d234d;\
        }\
        li a.selected {\
            font-size: 23px;\
            color: #3B3B3B;        \
        }\
    \
    </style> \
    \
    </head>\
    <body>\
');  
lp.include("help_menubar.lp")
  ngx.print('\
\
\
<div class="container toplevel" style="width:830px">\
    <div class="row">\
        <div class="span11">\
            <div class="span3 help-block">\
                <legend class="legend service_legend" style=" margin-top: 10px;">\
                    <a href="javascript:void(0)" onclick="show(\'help_dyndns.lp\')">Dynamic DNS </a>\
                </legend>\
               <legend class="legend service_legend">\
                    <a href="javascript:void(0)" onclick="show(\'help_portforwarding.lp\')";>Port Forwarding </a>\
                </legend>\
               <legend class="legend service_legend">\
                    <a href="javascript:void(0)" onclick="show(\'help_remoteaccess.lp\')";> Remote Web Access</a>\
                </legend>\
               <legend class="legend service_legend">\
                    <a href="javascript:void(0)" onclick="show(\'help_traffic.lp\')";> Traffic Monitor</a>\
                </legend>\
            </div>\
            <div class="span7 container">\
                <div id="disply_div" class="container span7">\
                    <br>\
                    <p>In this section you will be able to create/change/delete/view services that belong to:</p>\
                    <ul>\
                        <li>Dynamic DNS</li>\
                        <li>Port Forwarding</li>\
                        <li>Remote Web Access</li>\
                        <li>Traffic Monitor</li>\
                    </ul>\
                </div>\
            </div>\
        </div>\
    </div>\
</div>\
\
<script language="javascript" type="text/javascript">\
\
function show(which) {\
    document.getElementById(\'disply_div\').innerHtml = $(\'#disply_div\').load(which);\
    return false;\
}\
    \
</script>\
\
');  
lp.include("footer.lp")
  ngx.print('\
\
\
'); 