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
                <legend style="border-bottom: 0px; margin-top: 10px;">BroadBand</legend>\
            </div>\
            <div class="span7 container">\
                <div class="container span7">\
                    <h3>Change or Set up your Broadband Connection details on your gateway</h3> \
                    <div class="container span7">\
                        <legend>Step 1:</legend>&nbsp;&nbsp;Click on \'Broadband\' tab on the menu bar\
                    </div>\
                    \
                    <div class="container span7">\
                        <legend>Step 2:</legend>&nbsp;&nbsp;In the \'PPPoE Settings\' area, enter in: \
                        <ul>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>\'Username\' is your FULL BigPond email address</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>\'Password\' is your chosen or supplied password at sign up</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>\'Confirm Password\' your chosen or supplied password at sign up</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Click on \'Save\' button to save your configuration</li>\
                        </ul>\
                    </div>    \
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