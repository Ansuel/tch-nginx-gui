var KoRequest = {};
var connectionissue = 0;

var modgui = modgui || {};
!function (module) {

	function standardCloseAction() {
		tch.showProgress(waitMsg);
		window.location.reload(true);
	}
	function postAction(action, logModal, customCloseAction, customTarget) {
		var onClose = ( typeof customCloseAction === "function" ) && customCloseAction || function() {
			tch.showProgress(waitMsg);
			window.location.reload(true);
		}

		var target = customTarget ? customTarget : $(".modal form").attr("action");
		$.post(
			target, {
				action: action,
				CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
			},
			null,
			"json"
		);
		if(logModal){
			clearKoInterval();
			$(window).on('shown.bs.modal', function() {
				$(".modal-backdrop").unbind();
				$("#close-config,.modal-action-close").unbind( "click" );
				$("#close-config,.modal-action-close").on("click", function() {
					onClose();
				});
			});
			tch.openModal("/modals/command-log-read-modal.lp");
		}
		return false;
	}

	function createAjaxUpdateCard(CardIdRefresh, ajaxLink, IntervalVar, RefreshTime, CustomRefreshFunction) {

		var element = document.getElementById(CardIdRefresh);
		if (!element) return ;

		var ElementBinding = {};
		var ElementBindingList = [];
		var ObserveElement;
		$("#" + CardIdRefresh).find("[data-bind]").each(function () {
			ObserveElement = $(this).data("bind").split(":")[1].trim();
			ElementBindingList.push(ObserveElement);
			ElementBinding[ObserveElement] = ko.observable();
		});

		var arrayLength = ElementBindingList.length;

		var AjaxRefresh = ( typeof CustomRefreshFunction === "function" ) && CustomRefreshFunction || function() {
			var updateLink = "auto_update=true";
			if ( /[a-z]+=[a-z]+/.test(ajaxLink) ) {
				updateLink = "&" + updateLink;
			} else {
				updateLink = "?" + updateLink;
			};
			$.post(ajaxLink + updateLink, [tch.elementCSRFtoken()], function (data) {
				for (var i = 0; i < arrayLength; i++) {
					if (data[ElementBindingList[i]] != undefined) {
						ElementBinding[ElementBindingList[i]](data[ElementBindingList[i]]);
					}
				}
			}, "json")
				.done(function(data) {
					if(connectionissue==1) {
						if ($("#popUp").is(":visible"))
							tch.removeProgress();
						connectionissue = 0;
					}
				})
				.fail(function(data) {
					connectionissue = 1;
					switch (data.status) {
						case 200:
							if(data.responseText.indexOf("sign-me-in") !== -1 ) {
								if(!$("#popUp").is(":visible"))
									tch.showProgress(loginMsg);
								window.location.href = "/";
							}
							break;
						case 500:
							window.location.href = "/error.lp?status="+data.status+"&err="+data.getResponseHeader("error-msg");
							break;
						default:
							if(!$("#popUp").is(":visible"))
								tch.showProgress(connectionLost + " " + data.statusText);
					}
				});
		};

		AjaxRefresh(ElementBinding);

		if (!ko.dataFor(element))
			ko.applyBindings(ElementBinding, element);
		KoRequest[IntervalVar] = {
			interval : setInterval(AjaxRefresh,RefreshTime,ElementBinding),
			function : AjaxRefresh,
			binding : ElementBinding,
			refreshTime: RefreshTime,
		};
	}

	function linkCheckUpdate() {
		$(".check_update").on("click", function (e) {
			e.stopPropagation();
			if(KoRequest.CheckVer) return;
			postAction("checkver", null, null, '/modals/modgui-modal.lp?auto_update=true');
			$(".check_update_spinner").addClass("fa-spin");
				KoRequest.CheckVer = {
					interval : setInterval(function () {
						$.ajax({
							url:"/ajax/commandlogread.lua?auto_update=true",
							data: [tch.elementCSRFtoken()],
							type: "POST",
							dataType: "json",
							timeout: 500,
							success: function (data) {
								if (data.state == "Checking") {
									if (data.new_version_text) {
										if (data.new_version_text == "Unknown") {
											$(".gui_version_status").removeClass("yellow");
											$(".gui_version_status").addClass("green");
											$(".gui_version_status_text").text(gui_var.gui_updated);
											$("#upgrade-alert").addClass("hide");
										} else {
											$(".gui_version_status").removeClass("green");
											$(".gui_version_status").addClass("yellow");
											$("#upgradebtn").removeClass("hide");
											$(".gui_version_status_text").text(gui_var.gui_outdated);
											$("#upgrade-alert").removeClass("hide");
											$("#new-version-text").text(data.new_version_text);
										}
									}
								} else if (data.state == "Complete") {
									$(".gui_version_status_text").parent().fadeOut().fadeIn();
									$(".check_update_spinner").removeClass("fa-spin");
									clearInterval(KoRequest.CheckVer.interval);
									KoRequest.CheckVer = null;
								}
							}
						})
					}, "500")
				}
		})
	};

	function freshStyle(stylesheet) {
		$("#theme_skin").attr("href", "/theme/" + stylesheet);
	}

	function scrollFunction() {
		if (document.body.scrollTop > 60 || document.documentElement.scrollTop > 60) {
			$("#scroll-up").removeClass("hide");
			$("#scroll-down").addClass("hide");
		} else {
			$("#scroll-up").addClass("hide");
			$("#scroll-down").removeClass("hide");
		}
	}

	function clearKoInterval() {
		Object.keys(KoRequest).forEach(function(interval) {
			if(KoRequest[interval])
				clearInterval(KoRequest[interval].interval);
		});
	}

	function restartKoInterval() {
		Object.keys(KoRequest).forEach(function(interval) {
			if(KoRequest[interval])
				KoRequest[interval].interval = setInterval(KoRequest[interval].function,KoRequest[interval].refreshTime,KoRequest[interval].binding);
		});
	}

	// Resolve mac to vendor
	// Take mac and the JQuery div object to put the vendor
	function getVendorFromMac(mac, div) {
		div.addClass("fa fa-sync fa-spin");
		$.post(
			'/modals/modgui-modal.lp?auto_update=true', {
				action: 'getVendor',
				mac: mac,
				CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
			},
			null,
			"json"
		);
		$.ajax({
			url: "/get_vendor?auto_update=true",
			dataType: 'json',
			error: function() {
				div.removeClass("fa fa-sync fa-spin");
				div.text('Error');
			},
			success: function (data) {
				div.removeClass("fa fa-sync fa-spin");
				div.text(data.company || 'Unknown');
			}
		});
	}

	module.postAction = postAction,
	module.createAjaxUpdateCard = createAjaxUpdateCard,
	module.linkCheckUpdate = linkCheckUpdate,
	module.freshStyle = freshStyle,
	module.scrollFunction = scrollFunction,
	module.clearKoInterval = clearKoInterval,
	module.restartKoInterval = restartKoInterval,
	module.getVendorFromMac = getVendorFromMac
}
(modgui);

window.onscroll = function () {
	modgui.scrollFunction()
};

$(function () {
	$("a[href*=\'#\']").on("click", function (e) {
		e.preventDefault();
		$("html, body").animate({
			scrollTop: $($(this).attr("href")).offset().top
		}, 500, "linear");
	});

	$(document).on('mouseenter', 'td[data-toggle="tooltip_mac"]', function () {
		var elem = this;
		var mac = $(elem).children("#mac_data").text();
		$(elem).append('<div class="tooltip bottom fade in"><div class="tooltip-arrow"></div><div class="tooltip-inner">'+
		mac+'</br>'+
		'<div data-type="vendor"></div>'
		+'</div></div>');
		modgui.getVendorFromMac(mac,$(elem).children('.tooltip').children('.tooltip-inner').children('div[data-type="vendor"]'));
	}).on('mouseleave', 'td[data-toggle="tooltip_mac"]', function () {
		$('.tooltip').remove();
	});

	if (gui_var.randomcolor == "1") {
		setInterval(function () {
			var colorR = Math.floor((Math.random() * 256));
			var colorG = Math.floor((Math.random() * 256));
			var colorB = Math.floor((Math.random() * 256));
			$(":root").get(0).style.setProperty("--first-color-accent", "rgb(" + colorR + "," + colorG + "," + colorB + ")");
			$(":root").get(0).style.setProperty("--first-color-accent-50", "rgba(" + colorR + "," + colorG + "," + colorB + ", 0.5)");
			$(":root").get(0).style.setProperty("--first-color-accent-80", "rgba(" + colorR + "," + colorG + "," + colorB + ", 0.8)");
		}, 750);
	}

	var pathname = document.location.pathname;
	var page = gui_var.pageselector_page;
	var text = gui_var.pageselector_text;

	if (pathname == "/stats.lp") {
		$("#cards-text").text(gui_var.cards_text);
		document.title = "Gateway - "+gui_var.stats_text;
	} else if (pathname == "/cards.lp") {
		$("#cards-text").text(gui_var.stats_text);
		document.title = "Gateway - "+gui_var.cards_text;
	} else if (pathname == "/" ) {
		document.title = "Gateway - "+gui_var.pageselector_othertext;
	}

	$("#switchViewButton").on("click", function () {
		var pathname = document.location.pathname;
		var text = gui_var.pageselector_othertext;
		var view = gui_var.pageselector_text;

		if (pathname == "/stats.lp") {
			page = "cards.lp";
			text = gui_var.stats_text;
			view = gui_var.cards_text;
		} else if (pathname == "/cards.lp") {
			page = "stats.lp";
			text = gui_var.cards_text;
			view = gui_var.stats_text;
		}

		$("#cards-text").text(openMsg);
		$("#refresh-cards").show();
		$("#refresh-cards").css("margin-right", "5px");
		$("#refresh-cards").addClass("fa fa-sync fa-spin");
		modgui.clearKoInterval();
		KoRequest = {};

		$.get(page + "?contentonly=true").done(function (data) {
			$(".dynamic-content").replaceWith(data);
			$("#cards-text").text(text);
			$("#refresh-cards").hide();
			window.history.pushState("gateway", "Gateway - "+view, page);
			document.title = "Gateway - "+view;
			$("#switchViewButton").trigger("switchcard");
		});
	});
	$("#upgradebtn").on("hover",
		function () {
			$("#upgradebtn").css("color", "white");
		},
		function () {
			$("#upgradebtn").css("color", "orangered");
		}
	);

	if ((gui_var.autoupgradeview != "") && (gui_var.autoupgradeview != "none")) {
		modgui.postAction("autoupgrade_view");
	};

	if ( gui_var.gui_animation == "1" ) {
		AOS.init();
	};
});

$(document).ready(function () {
	ko.bindingHandlers.text = {
		init: function (element, valueAccessor) {
			$(element).text(ko.unwrap(valueAccessor()));
		},
		update: function (element, valueAccessor) {
			var value = ko.unwrap(valueAccessor());
			if (value != $(element).text()) {
				if (!$(element).hasClass("hide") && gui_var.gui_animation == "1") {
					$(element).fadeOut(function () {
						$(this).text(value).fadeIn();
					});
				} else {
					$(element).text(value);
				}
			}
		}
	};
	ko.bindingHandlers.log_text = {
		init: function (element, valueAccessor) {
			$(element).text(ko.unwrap(valueAccessor()));
		},
		update: function (element, valueAccessor) {
			var value = ko.unwrap(valueAccessor());
			$(element).text(value);
			$(element).parent().parent().parent().scrollTop($(element).parent().parent().parent()[0].scrollHeight);
		}
	};
	ko.bindingHandlers.html = {
		init: function (element, valueAccessor) {
			$(element).html(ko.unwrap(valueAccessor()));
		},
		update: function (element, valueAccessor) {
			var value = ko.unwrap(valueAccessor());
			if (value != $(element).html()) {
				if (!$(element).hasClass("hide") && gui_var.gui_animation == "1") {
					$(element).fadeOut(function () {
						$(this).html(value).fadeIn();
					});
				} else {
					$(element).html(value);
				}
			}
		}
	};
});
