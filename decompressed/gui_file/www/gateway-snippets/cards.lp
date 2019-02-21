--pretranslated: do not change this file

local lp = require("web.lp")

ngx.print('\
 <div class="feedback">\
\
  </div>\
	<div id="dynamic-content">\
      <div id="cardrow" class="row">\
	  ');
		lp.setpath("/www/gateway-snippets/")
		lp.include("js-after-header.lp")
	  	lp.setpath("/www/cards/")
          local cards = require("cards")
          for _,v in pairs(cards.cards()) do
			lp.include(v)
          end
          ngx.print('\
      </div>\
	</div>\
<script>\
AOS.init();\
$(document).ready(function () {\
	$("#refresh-cards").hide();\
});\
</script>\
');
