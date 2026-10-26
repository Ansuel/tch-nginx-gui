function checkArrowDirection() {
	if (($('#cardrow').scrollTop() + $("#cardrow").height() + 100) >= $('#cardrow')[0].scrollHeight) {
		$("#scroll-down").toggle();
		$("#scroll-up").toggle();
	} else if ($('#cardrow').scrollTop() - 210 <= 0) {
		$("#scroll-down").toggle();
		$("#scroll-up").toggle();
	}
}

function ScrollCardRow(direction) {
	if (direction == "down") {
		$('#cardrow').stop().animate({
			scrollTop: $('#cardrow').scrollTop() + 210
		}, 500, 'swing');
	} else if (direction == "up") {
		$('#cardrow').stop().animate({
			scrollTop: $('#cardrow').scrollTop() - 210
		}, 500, 'swing');
	}
	checkArrowDirection();
	if ( gui_var.gui_animation == "1" ) {
		AOS.refresh();
	}
}
var ScrollInterval;

function checkSCroll(div) {
	pos = div.offset().top;
	cardrow_scroll = $('#cardrow').scrollTop();
	checkArrowDirection();
	if (cardrow_scroll > 0 && pos < 200) {
		$('#cardrow').stop().animate({
			scrollTop: cardrow_scroll - 50
		}, 500, 'swing');
		if (pos < 10) {
			clearInterval(ScrollInterval);
			return;
		}
	} else {
		if (pos < 400) {
			clearInterval(ScrollInterval);
			return;
		}
		$('#cardrow').stop().animate({
			scrollTop: cardrow_scroll + 50
		}, 500, 'swing');
	}
}

function checkMenuHideShow() {
	if ($('.header-logo').is(":visible")) {
		if (window.matchMedia("(max-width: 50rem)").matches) {
			$(".modal-backdrop").remove();
		}
		$('.header-logo').hide('fast');
		$('#cardrow').hide('fast');
		$('#footer').hide('fast');
		$('.header-slider-icon').css('left', '20px');
		$('.header-button').css('width', 'calc( 100% - 2rem)');
		$('#scroll-down').css('display', 'none');
		$('#scroll-up').css('display', 'none');
		$('#infocardrow').css('width', '100%');
		$('#infocardrow').css('left', '0px');
	} else {
		if (window.matchMedia("(max-width: 50rem)").matches) {
			$("body").append('<div class="modal-backdrop fade in mobile-menu-overlay"></div>');
		}
		$('.header-logo').show('fast');
		$('#cardrow').show('fast');
		$('#footer').show('fast');
		$('.header-slider-icon').css('left', '');
		$('.header-button').css('width', '');
		$('#scroll-down').css('display', '');
		$('#scroll-up').css('display', '');
		$('#infocardrow').css('width', '');
		$('#infocardrow').css('left', '');
	}
}
var FocussedCard, CloneFocussedCard;
$(document).ready(function() {
	$(document).on('touchstart click', '#cardrow > .span3 > .smallcard', function(e) {
        if (window.matchMedia("(max-width: 50rem)").matches) {
            e.stopPropagation();
        }
        FocussedCard = $(this);
        CloneFocussedCard = FocussedCard.clone();
	});
	$(document).on("click", "#cardrow > .span3 > .smallcard > .header > .header-title", function(e) {
		e.stopImmediatePropagation();
	});
	$(".header-logo").after('<div class="header-slider-icon">☰</div>')
	$(document).on("click", ".mobile-menu-overlay", function() {
		checkMenuHideShow();
	});
	$(document).on('click', '.header-slider-icon', function() {
		checkMenuHideShow();
	});
	$(document).on('mouseover', '#cardrow .span3 .smallcard', function() {
		var div = $(this);
		ScrollInterval = setInterval(checkSCroll(div), 500);
		if ( gui_var.gui_animation == "1" ) {
			AOS.refresh();
		}
	});
	if (window.matchMedia("(max-width: 50rem)").matches) {
		$("#cardrow").on("scroll", function() {
			if ( gui_var.gui_animation == "1" ) {
				AOS.refresh();
			}
		})
	}
	$(window).on('shown.bs.modal', function() {
		$("#infocardrow").hide();
		if(!CloneFocussedCard) return;
		if (window.matchMedia("(max-width: 50rem)").matches) {
			if ($('.header-logo').is(":visible")) {
				checkMenuHideShow();
			}
		} else {
			FocussedCard.removeClass("hovered");
			CloneFocussedCard.addClass("hovered");
			$("body").append(CloneFocussedCard);
			$("body").css("overflow", "hidden");
            $("#cardrow").css("z-index", "1039");
            $(".header-logo").css("z-index", "1039");
            $("#footer").css("z-index", "1038");
		}
	});
	$(window).on('hide.bs.modal', function() {
		$("#infocardrow").show();
		if(CloneFocussedCard) {
			CloneFocussedCard.remove();
			CloneFocussedCard = null;
		}
		$("body").css("overflow", "initial");
		$("#cardrow").css("z-index", "1052");
		$(".header-logo").css("z-index", "1052");
		$("#footer").css("z-index", "1051");
	});
	$("#scroll-down").removeAttr("href").on("click", function() {
		ScrollCardRow("down");
	});
	$("#scroll-up").removeAttr("href").on("click", function() {
		ScrollCardRow("up");
	});
	var rowToLoad, presentRow;
	if ($("#cardrow").length) {
		rowToLoad = "stats"
		presentRow = $("#cardrow");
	} else {
		rowToLoad = "cards"
		presentRow = $("#infocardrow");
	};
	$.ajax({
		url: "/" + rowToLoad + ".lp?contentonly=true",
		success: function(data) {
			presentRow.after(data);
			$(".chartjs-render-monitor").each(function() {
				eval($(this).attr('id')).options.scales.yAxes[0].ticks.fontColor =
				'#ffffff';
			})
		},
		dataType: 'html'
	});
});
