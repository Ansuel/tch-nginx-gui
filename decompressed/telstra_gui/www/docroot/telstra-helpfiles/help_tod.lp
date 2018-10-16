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
                <legend style="border-bottom: 0px; margin-top: 10px;">Time of Day </legend>\
            </div>\
            <div class="span7 container">\
                <div class="container span7">\
                    <h3>Create or change a Parental Control rule, for Time of Day Access Control</h3>\
\
                    <div class="container span7">\
                        <legend>Step 1:</legend>&nbsp;&nbsp;Click on \'Parental Control\' tab on the menu bar\
                    </div>\
\
                    <div class="container span7">\
                        <legend>Step 2:</legend>&nbsp;&nbsp;Identify the Device you want to change the time of day rule, click the pencil icon &nbsp;&nbsp;on the right end\
                    </div>\
\
                    <div class="container span7">\
                        <legend>Step 3:</legend>&nbsp;&nbsp;In the expended panel, you can:\
                        <ul>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Turn On/Off Time of Day Access Control</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Type the MAC address of the device</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Select the Mode from the drop down list</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Input the start time</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Input the end time</li>\
                            &nbsp;&nbsp;&nbsp;&nbsp;<li>Select the week days for this rule</li>\
                        </ul>\
                    </div>\
                    <div class="container span7">\
                        <legend>Step 4:</legend>&nbsp;&nbsp;You can either click the blue tick icon to save your changes, or click the red cross icon to abort this change\
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