var KoRequest = {};

function get_bitrate(b){b*=8;return 1E9<b?(b=(b/1E9).toFixed(1),b+" Gbit/s"):1E6<b?(b/=1E6,b=b.toFixed(1),b+" Mbit/s"):1E3<b?(b/=1E3,b=b.toFixed(1),b+" Kbit/s"):b+" bit/s"}

var modgui = modgui || {};
!function (module) {

	function standardCloseAction() {
		tch.showProgress(waitMsg);
		window.location.reload(true);
	}
	var commandRequestInProgress = false;
	function postAction(action, logModal, customCloseAction, customTarget) {
		if (logModal && commandRequestInProgress) return false;
		var onClose = ( typeof customCloseAction === "function" ) && customCloseAction || function() {
			tch.showProgress(waitMsg);
			window.location.reload(true);
		}

		var target = customTarget ? customTarget : $(".modal form").attr("action");
		function showStartError(data) {
			if (!logModal) return;
			var message = data && typeof data.error === "string" ? data.error : "Unable to start command.";
			$("#command-start-error").remove();
			$("<div>").attr({id: "command-start-error", role: "alert"})
				.addClass("alert alert-error").text(message).prependTo(".modal .modal-body");
		}
		if (logModal) {
			commandRequestInProgress = true;
			$("#command-start-error").remove();
		}
		$.post(
			target, {
				action: action,
				CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
			},
			null,
			"json"
		).done(function(data) {
			if (!logModal) return;
			if (!data || (data.success !== true && data.success !== "true")) {
				showStartError(data);
				return;
			}
			// Start polling only after the server has accepted the new command
			// and cleared the shared result of the previous command.
			clearKoInterval();
			$(window).one('shown.bs.modal', function() {
				$(".modal-backdrop").unbind();
				$("#close-config,.modal-action-close").unbind( "click" );
				$("#close-config,.modal-action-close").on("click", function() {
					onClose();
				});
			});
			tch.openModal("/modals/command-log-read-modal.lp");
		}).fail(function(request) {
			showStartError(request.responseJSON);
		}).always(function() {
			if (logModal) commandRequestInProgress = false;
		});
		return false;
	}

	function createAjaxUpdateCard(CardIdRefresh, ajaxLink, IntervalVar, RefreshTime, CustomRefreshFunction, deferFirstRefresh) {
        var element = document.getElementById(CardIdRefresh);
        if (!element) return;
        var previous = KoRequest[IntervalVar];
        if (previous && previous.element === element) return;

        var ElementBinding = {};
        var ElementBindingList = [];
        $("#" + CardIdRefresh).find("[data-bind]").each(function () {
            var observable = $(this).data("bind").split(":")[1].trim();
            ElementBindingList.push(observable);
            ElementBinding[observable] = ko.observable();
        });

        var registration = {};
        var custom = typeof CustomRefreshFunction === "function";
        var pending = false;
        var request = null;
        var failures = 0;
        var retryAt = 0;
        function isCurrent() {
            return document.getElementById(CardIdRefresh) === element && KoRequest[IntervalVar] === registration;
        }
        function abort() {
            if (request) request.abort();
        }
        function applyBindings() {
            if (!ko.dataFor(element)) ko.applyBindings(ElementBinding, element);
        }
        function track(handle) {
            if (!handle || typeof handle.always !== "function") return;
            pending = true;
            request = handle;
            handle.done(function () {
                failures = 0;
                retryAt = 0;
            }).fail(function (xhr, status) {
                if (!isCurrent() || status === "abort" || (xhr && xhr.statusText === "abort")) return;
                failures = Math.min(failures + 1, 4);
                retryAt = Date.now() + Math.max(RefreshTime, Math.min(30000, RefreshTime * Math.pow(2, failures)));
            }).always(function () {
                pending = false;
                request = null;
            });
        }
        var AjaxRefresh = custom ? function (binding) {
            track(CustomRefreshFunction(binding));
        } : function () {
            var separator = ajaxLink.indexOf("?") === -1 ? "?" : "&";
            var send = typeof window.modguiDashboardRequest === "function" ? window.modguiDashboardRequest : $.ajax;
            track(send({
                url: ajaxLink + separator + "auto_update=true",
                type: "POST",
                data: [tch.elementCSRFtoken()],
                dataType: "json",
                timeout: 8000,
                success: function (data) {
                    if (!isCurrent() || !data || typeof data !== "object") return;
                    for (var i = 0; i < ElementBindingList.length; i++) {
                        var key = ElementBindingList[i];
                        if (data[key] !== undefined) ElementBinding[key](data[key]);
                    }
                    // Keep server-rendered values visible until the first valid poll.
                    applyBindings();
                }
            }).fail(function (data) {
                if (isCurrent() && data.status === 200 && typeof data.responseText === "string" &&
                    /\bid=["']sign-me-in["']/.test(data.responseText)) {
                    window.location.href = "/";
                }
            }));
        };
        function refresh(binding) {
            if (!isCurrent()) {
                clearInterval(registration.interval);
                abort();
                if (KoRequest[IntervalVar] === registration) delete KoRequest[IntervalVar];
                return;
            }
            if (!document.hidden && !pending && Date.now() >= retryAt) AjaxRefresh(binding);
        }
        registration.element = element;
        registration.function = refresh;
        registration.binding = ElementBinding;
        registration.refreshTime = RefreshTime;
        registration.abort = abort;
        KoRequest[IntervalVar] = registration;
        if (previous) {
            clearInterval(previous.interval);
            if (typeof previous.abort === "function") previous.abort();
        }
        if (!deferFirstRefresh) refresh(ElementBinding);
        if (custom) applyBindings();
        registration.interval = setInterval(refresh, RefreshTime, ElementBinding);
    }

	function linkCheckUpdate() {
		var target = "/modals/modgui-modal.lp?auto_update=true";
		$(".check_update").off("click.guiUpdate").on("click.guiUpdate", function (e) {
			e.preventDefault();
			e.stopPropagation();
			if ($(this).attr("id") === "btn-check-update") return postAction("checkver", 1, null, target);
			if (KoRequest.CheckVer) return false;
			var link = $(this);
			var registration = {};
			var pending = false;
			var deadline = Date.now() + 90000;
			KoRequest.CheckVer = registration;
			$(".check_update_error").remove();
			$(".check_update_spinner").addClass("fa-spin");
			function finish(error) {
				if (KoRequest.CheckVer !== registration) return;
				clearInterval(registration.interval);
				KoRequest.CheckVer = null;
				$(".check_update_spinner").removeClass("fa-spin");
				if (error) $("<span>").addClass("check_update_error text-error").attr("role", "alert").text(error).appendTo(link.parent());
			}
			function poll() {
				if (KoRequest.CheckVer !== registration) return;
				if (Date.now() > deadline) { finish("Update check timed out. Please retry."); return; }
				if (pending) return;
				pending = true;
				$.ajax({url: target, type: "POST",
					data: {action: "get_update_status", CSRFtoken: $("meta[name=CSRFtoken]").attr("content")}, dataType: "json", timeout: 8000
				}).done(function (data) {
					if (KoRequest.CheckVer !== registration) return;
					if (data.state === "Error") { finish(data.log || "Update check failed. Please retry."); return; }
					if (data.state !== "Complete") return;
					if (!data.new_version_text) { finish("Unable to read update result. Please retry."); return; }
					var version = data.new_version_text;
					var outdated = version !== "Unknown";
					$(".gui_version_status").removeClass("yellow green").addClass(outdated ? "yellow" : "green");
					$(".gui_version_status_text").text(function () {
						if (!outdated) return gui_var.gui_updated;
						var label = this.getAttribute("data-available-version");
						return label ? label.replace("%s", function () { return version; }) : gui_var.gui_outdated;
					});
					$(".upgrade_gui,#upgradebtn,#upgrade-alert").toggleClass("hide", !outdated);
					$("#new-version-text").text(version);
					finish();
				}).fail(function (request) {
					finish(request.responseJSON && request.responseJSON.error || "Unable to check updates. Please retry.");
				}).always(function () { pending = false; });
			}
			$.ajax({url: target, type: "POST", dataType: "json", timeout: 10000,
				data: {action: "checkver", CSRFtoken: $("meta[name=CSRFtoken]").attr("content")}
			}).done(function (data) {
				if (KoRequest.CheckVer !== registration) return;
				if (!data || (data.success !== true && data.success !== "true")) { finish(data && data.error || "Unable to start update check."); return; }
				registration.interval = setInterval(poll, 1000);
				poll();
			}).fail(function (request) { finish(request.responseJSON && request.responseJSON.error || "Unable to start update check."); });
			return false;
		});
		$(".upgrade_gui").off("click.guiUpdate").on("click.guiUpdate", function (e) {
			e.preventDefault();
			e.stopPropagation();
			return postAction("system_upgrade_gui", 1, null, target);
		});
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
			var registration = KoRequest[interval];
			clearInterval(registration.interval);
			if (registration.abort) registration.abort();
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
		$.ajax({
			url: "/modals/modgui-modal.lp?auto_update=true",
			method: 'POST',
			data: {
				action: 'getVendor',
				mac: mac,
				CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
			},
			error: function() {
				div.removeClass("fa fa-sync fa-spin");
				div.text('Error');
			},
			success: function (data) {
				div.removeClass("fa fa-sync fa-spin");
				div.text(data || 'Unknown');
			}
		});
	}

    // Share resource samples when switching between the dashboard and statistics.
    var resourceSamples = [], lastFetch = 0;
    var lifetime = 600;
    var liveWindow = 20;
    var liveDelay = 2;
    var historyInterval = 9000; // The router collects a historical sample every nine seconds.
    var serverTime, clockAt;

    function initResourceCharts(cardId, compact) {
        var card = document.getElementById(cardId);
        if (!card || typeof Chart !== "function") return;

        function element(id) {
            return card.querySelector('[data-resource="' + id + '"]');
        }

        var range = !compact && element("chart-range");
        function clock() {
            return window.performance ? window.performance.now() : Date.now();
        }

        function isLive() {
            return compact || (range && range.value === "live");
        }

        function moveAxis(graph) {
            var end = serverTime + Math.max(0, clock() - clockAt) / 1000 - liveDelay;
            var ticks = graph.options.scales.xAxes[0].ticks;
            ticks.min = end - liveWindow;
            ticks.max = end;
        }

        function series(label, color, key) {
            if (!compact) element(key).style.backgroundColor = color;
            return {label: label, borderColor: color, backgroundColor: color + (compact ? "66" : "40"),
                borderWidth: compact ? 1 : 2, pointBackgroundColor: color,
                pointRadius: compact ? 0 : 2.5,
                fill: "origin",
                lineTension: 0, data: []};
        }

        function chart(id, datasets, format, maximum, tickFormat) {
            var color = window.getComputedStyle(card).color;
            return new Chart(element(id), {
                type: "line",
                data: {datasets: datasets},
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    animation: {duration: 0},
                    events: compact ? [] : Chart.defaults.global.events,
                    legend: {display: false},
                    scales: {
                        xAxes: [{
                            type: "linear",
                            display: !compact,
                            afterBuildTicks: function (scale) {
                                var bounds = scale.options.ticks;
                                if (bounds.min === undefined) return;
                                if (isLive()) {
                                    var step = scale.maxWidth >= 320 ? 5 : 10;
                                    var labels = [];
                                    for (var time = Math.ceil((bounds.min + 1) / step) * step; time <= bounds.max - 1; time += step) {
                                        labels.push(time);
                                    }
                                    return labels;
                                }
                                var span = bounds.max - bounds.min;
                                var labelSpace = span < 300 ? 68 : 50;
                                var count = Math.min(5, span + 1,
                                    Math.max(1, Math.floor((scale.maxWidth - 48) / labelSpace)));
                                var labels = [bounds.min];
                                for (var i = 1; i < count; i++) {
                                    labels.push(bounds.min + Math.round(i * span / (count - 1)));
                                }
                                return labels;
                            },
                            ticks: {
                                fontColor: color, autoSkip: false, maxRotation: 0,
                                callback: function (value) {
                                    var bounds = this.options.ticks;
                                    if (bounds.min === undefined) return "";
                                    var clock = {hour: "2-digit", minute: "2-digit", hourCycle: "h23"};
                                    if (bounds.max - bounds.min < 300) clock.second = "2-digit";
                                    return new Date(value * 1000).toLocaleTimeString([], clock);
                                }
                            }
                        }],
                        yAxes: [{display: !compact, ticks: {min: 0, max: maximum, fontColor: color, callback: tickFormat || format}}]
                    },
                    tooltips: {enabled: !compact, mode: "index", intersect: false, callbacks: {
                        title: function (items, data) {
                            if (!items.length) return "";
                            var item = items[0];
                            return new Date(data.datasets[item.datasetIndex].data[item.index].x * 1000).toLocaleTimeString();
                        },
                        label: function (item, data) {
                            return data.datasets[item.datasetIndex].label + " " + format(item.yLabel);
                        }
                    }}
                }
            });
        }

        function percentage(value) {
            return Number(value.toFixed(1)) + "%";
        }

        function reading(value, format) {
            return typeof value === "number" ? format(value) : "–";
        }

        function compactBitrate(bytes) {
            var bits = Math.round(bytes * 8);
            if (bits < 1000) return bits + " bit/s";
            var kilobits = Math.round(bits / 1000);
            if (kilobits < 1000) return kilobits + " Kbit/s";
            return bits <= 1000000 ? "1.0 Mbit/s" : get_bitrate(bytes);
        }

        function update(graph, samples, fields) {
            var first, last;
            graph.data.datasets.forEach(function (dataset, index) {
                var field = fields[index], previous;
                dataset.data = [];
                samples.forEach(function (sample, position) {
                    var value = sample[field];
                    if (typeof value !== "number") {
                        // Archived metrics can be sparse. CPU and WAN also lack a rate
                        // on the first live sample, which only establishes the baseline.
                        if (sample.historical || (!compact && previous && previous.historical) ||
                            (position > 0 && samples[position - 1].historical)) return;
                        dataset.data.push({x: sample.time, y: null});
                        previous = undefined;
                        return;
                    }
                    // Keep missing intervals visible without inventing measurements.
                    var gap = previous && previous.historical ? 660 : (isLive() ? 6 : 20);
                    var archiveTransition = !compact && previous && previous.historical && !sample.historical;
                    if (previous && sample.time - previous.time > gap && !archiveTransition) {
                        dataset.data.push({x: previous.time + 1, y: null});
                    }
                    dataset.data.push({x: sample.time, y: value});
                    if (first === undefined || sample.time < first) first = sample.time;
                    if (last === undefined || sample.time > last) last = sample.time;
                    previous = sample;
                });
            });
            if (isLive()) {
                moveAxis(graph);
            } else if (!compact) {
                var ticks = graph.options.scales.xAxes[0].ticks;
                ticks.min = first;
                ticks.max = last;
            }
            graph.update();
        }

        var usage = chart("resource-chart", [series("CPU", "#3487c9", "cpu-key"),
            series("RAM", "#ad68bd", "ram-key")], percentage, 100);
        var traffic = chart("wan-chart", [series(element("traffic-download-label").textContent, "#379962", "rx-key"),
            series(element("traffic-upload-label").textContent, "#df7951", "tx-key")], get_bitrate, undefined, compactBitrate);
        var trafficFields = compact ? ["lan_rx", "lan_tx"] : ["rx", "tx"];
        var interfaceField = compact ? "lan" : "interface";
        var renderedDevice, renderedHistory, scrollTimer;

        function render() {
            if (resourceSamples === renderedHistory) return;
            renderedHistory = resourceSamples;
            var latest = resourceSamples[resourceSamples.length - 1];
            if (!latest) return;
            var device = latest[interfaceField];
            element("resource-cpu").textContent = reading(latest.cpu, percentage);
            $(element("traffic-unavailable")).toggleClass("hide", !!device);
            $(element("wan-chart-frame")).toggleClass("hide", !device);
            if (device && device !== renderedDevice) traffic.resize();
            renderedDevice = device;

            var received = latest[trafficFields[0]], sent = latest[trafficFields[1]];
            var download = reading(received, get_bitrate), upload = reading(sent, get_bitrate);
            if (compact) {
                element("wan-chart").setAttribute("aria-label", "br-lan RX " + download + " · TX " + upload);
            } else {
                element("resource-ram").textContent = reading(latest.ram, percentage);
                $(element("historical-source")).toggleClass("hide", isLive() || !resourceSamples[0].historical);
                element("traffic-interface").textContent = device || "";
                $(element("traffic-reading")).toggleClass("hide", !device);
                element("traffic-download").textContent = download;
                element("traffic-upload").textContent = upload;
            }

            var shown = resourceSamples;
            if (isLive()) {
                shown = resourceSamples.filter(function (sample) {
                    return !sample.historical && latest.time - sample.time <= liveWindow + 6;
                });
            }
            var start = shown.length;
            if (device) {
                while (start > 0 && shown[start - 1][interfaceField] === device) start--;
            }
            update(usage, shown, ["cpu", "ram"]);
            update(traffic, shown.slice(start), trafficFields);
            if (compact) {
                var scale = traffic.scales["y-axis-0"];
                element("traffic-scale").textContent = typeof received === "number" && scale ?
                    reading(scale.max, compactBitrate) : "–";
            }
        }

        if (range) {
            $(range).on("change", function () {
                renderedHistory = undefined;
                render();
                updateScrolling();
            });
        }
        function stopScrolling() {
            clearInterval(scrollTimer);
            scrollTimer = undefined;
        }
        function scroll() {
            if (document.getElementById(cardId) !== card) {
                stopScrolling();
                return;
            }
            if (document.hidden) return;
            moveAxis(usage);
            usage.update();
            if (renderedDevice) {
                moveAxis(traffic);
                traffic.update();
            }
        }
        function updateScrolling() {
            if (!isLive()) stopScrolling();
            else if (scrollTimer === undefined && serverTime !== undefined) scrollTimer = setInterval(scroll, 40);
        }

        if (window.MutationObserver) {
            var observer = new MutationObserver(function () {
                if (document.getElementById(cardId) === card) return;
                observer.disconnect();
                stopScrolling();
                usage.destroy();
                traffic.destroy();
            });
            observer.observe(document.body, {childList: true, subtree: true});
        }

        var nextHistoryRead = 0;
        function refresh() {
            var live = isLive();
            if (!live && clock() < nextHistoryRead) return;
            var latest = resourceSamples[resourceSamples.length - 1];
            var after = latest && latest.time;
            var send = window.modguiDashboardRead || $.ajax;
            return send({
                url: "/ajax/traffic_graph.lua?source=wan&resources=history&auto_update=true" +
                    (live ? "&live=3" : "") +
                    (after === undefined ? "" : "&after=" + after),
                type: "POST",
                data: [tch.elementCSRFtoken()],
                dataType: "json",
                timeout: 8000,
                success: function (data) {
                    if (document.getElementById(cardId) !== card || !data || !Array.isArray(data.samples)) return;
                    var received = clock();
                    nextHistoryRead = live ? 0 : received + historyInterval;
                    // Keep the scrolling clock independent of individual responses.
                    // Correct it only after a large clock change or a long interruption.
                    if (typeof data.now === "number" &&
                        (serverTime === undefined || Math.abs(data.now - serverTime - (received - clockAt) / 1000) > 2)) {
                        serverTime = data.now;
                        clockAt = received;
                    }
                    lastFetch = Date.now();
                    var current = resourceSamples[resourceSamples.length - 1];
                    if (data.replace && after === (current && current.time)) {
                        resourceSamples = data.samples;
                    } else if (!data.replace && data.samples.length) {
                        var fresh = data.samples.filter(function (sample) { return !current || sample.time > current.time; });
                        if (fresh.length) resourceSamples = resourceSamples.concat(fresh);
                    }
                    if (resourceSamples !== renderedHistory) {
                        var last = resourceSamples[resourceSamples.length - 1];
                        if (last) resourceSamples = resourceSamples.slice(-600).filter(function (sample) {
                            return last.time - sample.time < (sample.historical ? 3600 : lifetime);
                        });
                    }
                    render();
                    updateScrolling();
                }
            });
        }

        if (Date.now() - lastFetch >= lifetime * 1000) resourceSamples = [];
        render();
        updateScrolling();
        module.createAjaxUpdateCard(cardId, null, cardId + "ChartsInterval", 1000, refresh);
    }

    module.initResourceCharts = initResourceCharts;
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

	var switchingView = false;
	$("#switchViewButton").on("click", function () {
		if (switchingView) return;
		switchingView = true;
		var pathname = document.location.pathname;
		var text = gui_var.pageselector_othertext;
		var view = gui_var.pageselector_text;
		var page = gui_var.pageselector_page;
		var previousText = $("#cards-text").text();

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
		$.ajax({url: page + "?contentonly=true", timeout: 15000}).done(function (data) {
			if (/\bid=["']sign-me-in["']/.test(data)) {
				window.location.href = "/";
				return;
			}
			if (window.modguiAbortDashboardCards) window.modguiAbortDashboardCards();
			modgui.clearKoInterval();
			KoRequest = {};
			$(".dynamic-content").replaceWith(data);
			$("#cards-text").text(text);
			window.history.pushState("gateway", "Gateway - "+view, page);
			document.title = "Gateway - "+view;
			$("#switchViewButton").trigger("switchcard");
		}).fail(function () {
			$("#cards-text").text(previousText);
		}).always(function () {
			switchingView = false;
			$("#refresh-cards").hide();
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
