--pretranslated: do not change this file
 
local defuser = ngx.ctx.session:isdefaultuser() and "1" or "0"
  ngx.print('\
\
<div class="navbar navbar-inverse navbar-fixed-top">\
    <div class="navbar-inner">\
        <div class="container">\
            <ul class="nav pull-right">\
                <li>\
                   ');  
                   if defuser ~="1" then
                   ngx.print ('<a href="/" id="signout"><i class="icon-lock"></i> Logout</a> ')
                   end
                     ngx.print('\
                </li>\
                <li>\
                    <a href="#" onclick="javascript:window.open(\'/telstra-helpfiles/help_home.lp\', \'Help\', \'width=1050, height=600, top=50, left=150, scrollbars=yes, resizable=yes\')"><i class="icon-question-sign"></i></a>\
                </li>\
            </ul>\
        </div>\
    </div>\
</div>'); 