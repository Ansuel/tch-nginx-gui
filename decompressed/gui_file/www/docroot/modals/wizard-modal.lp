--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-wizard')

local ui_helper = require("web.ui_helper")
local format = string.format
local proxy = require("datamodel")

local card_previous
local card_action
if ngx.var.request_method == "POST" then
    local args = ngx.req.get_post_args()
    card_previous = args.wizardCardPrevious
    card_action = args.wizardCardAction
end

ngx.print('\
');ngx.print( ui_helper.createHeader(T"Setup Wizard") ); ngx.print('\
<div class="loading-wrapper hide"><img src="/img/spinner.gif"></div>\
<div class="modal-body update">\
	<form class="form-horizontal" method="post" action="modals/wizard-modal.lp">\
		')
        ngx.print(format("<div class='wizard' card-previous=%s card-action=%s>", card_previous or "0", card_action or "0"))
            local lp = require("web.lp")
            lp.setpath("/www/wizard-cards/")
            local wizard = require("wizard")
            wizard.setpath("/www/wizard-cards")
            for _,v in pairs(wizard.cards()) do
                lp.include(v)
            end
        
		ngx.print('\
        </div>\
	</form>\
</div>\
'); ngx.print( wizard.createFooter() ); ngx.print('\
<script type="text/javascript">\
$(document).ready(function () {\
    var total_cards = $(".wizard-card").length + 1;\
    $(".wizard-card").each(function(i) {\
       $(this).find("legend").text( "'); ngx.print( T"Step " ); ngx.print('" + (i+1) + "'); ngx.print( T" of " ); ngx.print('" + total_cards);\
    });\
    $(".wizard-confirm").first().find("legend").text("'); ngx.print( T"Step " ); ngx.print('"  + total_cards + "'); ngx.print( T" of " ); ngx.print('" + total_cards);\
})\
\
</script>\
')

uci_path = "uci.system.system.@system[0].wizard_accessed"
local result = proxy.get(uci_path)
if result and result[1].value ~= "1" then
  proxy.set(uci_path, "1")
end
