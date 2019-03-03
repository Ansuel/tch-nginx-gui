--pretranslated: do not change this file

local content_helper = require("web.content_helper")

local cui = {
	randomcolor = "uci.modgui.gui.randomcolor",
}

content_helper.getExactContent(cui)

ngx.print('\
<script>\
$(document).ready(function(){\
  ko.bindingHandlers.text = {\
		init: function(element, valueAccessor) {\
        $(element).text(ko.unwrap(valueAccessor()));\
    },\
    update: function(element, valueAccessor) {\
        var value = ko.unwrap(valueAccessor());\
        if (value != $(element).text() ) {\
			if ( ! $(element).hasClass("hide") ) {\
				$(element).fadeOut(function() {\
					$(this).text(value).fadeIn();\
				});\
			} else {\
				$(element).text(value);\
			}\
		}\
    }\
  };\
  ko.bindingHandlers.html = {\
		init: function(element, valueAccessor) {\
        $(element).html(ko.unwrap(valueAccessor()));\
    },\
    update: function(element, valueAccessor) {\
        var value = ko.unwrap(valueAccessor());\
        if (value != $(element).html() ) {\
			if ( ! $(element).hasClass("hide") ) {\
				$(element).fadeOut(function() {\
					$(this).html(value).fadeIn();\
				});\
			} else {\
				$(element).html(value);\
			}\
		}\
    }\
  };\
});\
</script>\
');