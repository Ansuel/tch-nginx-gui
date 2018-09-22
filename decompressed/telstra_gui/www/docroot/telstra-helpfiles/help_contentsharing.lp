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
                <legend style="border-bottom: 0px; margin-top: 10px;">Content Sharing</legend>\
            </div>\
            <div class="span7 container">\
                <div class="container span7">\
                    <h3>Change your DLNA Media Server details</h3> \
                    <div class="container span7">\
                        <legend>Step 1:</legend>&nbsp;&nbsp;Click on \'Content Sharing\' tab on the menu bar\
                    </div>\
                    <div class="container span7">\
                        <legend>Step 2:</legend>&nbsp;&nbsp;Click the switch you can turn on/off the DLNA server\
                    </div>                                     \
                    <div class="container span7">\
                        <legend>Step 3:</legend>&nbsp;&nbsp;You can also change the server name by enter a new name in the \'Media Server Name\' \
                    </div>\
 \
                    <div class="container span7">\
                        <legend>Step 4:</legend>&nbsp;&nbsp;Click on \'Save\' button to save your configuration\
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