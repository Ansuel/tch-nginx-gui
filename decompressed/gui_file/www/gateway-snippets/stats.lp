--pretranslated: do not change this file
 
-- Enable localization

local content_helper = require("web.content_helper")
local session = ngx.ctx.session

local lp = require("web.lp")

local cui = {
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_skin = "uci.env.var.gui_skin",
}
content_helper.getExactContent(cui)

ngx.print('\
<div id="dynamic-content" class="container">\
<div class="row" style="z-index : 2;  position: relative;">\
')
lp.setpath("/www/info-cards/")
       local cards = require("cards")
	cards.setpath("/www/info-cards/")
       for _,v in pairs(cards.cards()) do
         lp.include(v)
       end
ngx.print('</div>\
<script>\
AOS.init();\
\
$(document).ready(function () {\
	$("#refresh-cards").hide();\
});\
window.onscroll = function() {scrollFunction()};\
\
function scrollFunction() {\
if (document.body.scrollTop > 60 || document.documentElement.scrollTop > 60) {\
        $("#scroll-up").removeClass("hide");\
		$("#scroll-down").addClass("hide");\
    } else {\
        $("#scroll-up").addClass("hide");\
		$("#scroll-down").removeClass("hide");\
    }\
}\
\
$(function() {\
  $("a[href*=\'#\']").on("click", function(e) {\
    e.preventDefault();\
    $("html, body").animate({ scrollTop: $($(this).attr("href")).offset().top}, 500, "linear");\
  });\
});\
</script>\
')