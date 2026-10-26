--pretranslated: do not change this file
 
    --NG-8926:After Signing in on the advaned user page you should be redirected to the Advance GUI
    --user clicked the signin in advanced ui,
    --so need to redirect to to "/gateway.lp" previously stored in lasturi
    local lasturi = ngx.ctx.session:retrieve("lasturi")
    if lasturi ~= nil then
        --Redirect to lasturi only once (after authentication).
        ngx.ctx.session:store("lasturi", nil)
        ngx.redirect(lasturi)
    end

    local lp = require("web.lp")
    lp.setpath("/www/telstra-snippets/")
    lp.include("header.lp")
    lp.include("navbar.lp")
    lp.include("menubar.lp")
    lp.include("message.lp")
    lp.include("networkmap.lp")
    lp.include("footer.lp")
  ngx.print('\
'); 