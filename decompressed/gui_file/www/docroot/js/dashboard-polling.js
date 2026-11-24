/* Limit dashboard reads and combine compatible polls. */
(function (window, $) {
    "use strict";
    var queue = [], timer = null, supported = true;
    var initialReads = [], pollingReads = [], activeReads = 0, pumpTimer = null;
    var maxActiveReads = 2;
    var routes = {
        "/ajax/cpuload.lua": "gateway", "/ajax/internet.lua": "wan",
        "/ajax/connected_device.lua": "devices", "/ajax/port_status.lua": "ports",
        "/ajax/mmpbx_status.lua": "telephony"
    };
    function moduleName(options) {
        var parts = options.url.split("?"), name = routes[parts[0]];
        if (!name || options.type !== "POST" || !options.data || options.data.length !== 1 ||
            options.data[0].name !== "CSRFtoken") return null;
        var query = parts.length > 1 ? parts[1].split("&") : [];
        for (var i = 0; i < query.length; i++) {
            // DSL driver RPCs can be slow on older firmware. Keep this read
            // independent so it cannot hold back every other dashboard card.
            if (query[i] === "datatype=xdsl" && name === "wan") return null;
            else if (query[i] === "datatype=wanstats" && name === "wan") name = "wanstats";
            else if (query[i] !== "auto_update=true") return null;
        }
        return name;
    }
    function failure(status, text, body, error) {
        return {status: status, statusText: text, responseText: body || "",
            getResponseHeader: function (name) {return name === "error-msg" ? error : null;}};
    }
    function pump() {
        pumpTimer = null;
        while (activeReads < maxActiveReads && (initialReads.length || pollingReads.length)) {
            var read = (initialReads.length ? initialReads : pollingReads).shift();
            read();
        }
    }
    function schedulePump() {
        if (pumpTimer === null) pumpTimer = window.setTimeout(pump, 0);
    }
    function read(options, initial) {
        var deferred = $.Deferred(), xhr;
        var reads = initial ? initialReads : pollingReads;
        function start() {
            activeReads++;
            xhr = $.ajax(options).always(function () {
                activeReads--;
                schedulePump();
            }).done(function () {
                deferred.resolveWith(this, arguments);
            }).fail(function () {
                deferred.rejectWith(this, arguments);
            });
        }
        var handle = deferred.promise({abort: function () {
            if (xhr) xhr.abort();
            else {
                var index = reads.indexOf(start);
                if (index !== -1) reads.splice(index, 1);
                deferred.reject(failure(0, "abort"), "abort");
            }
            return handle;
        }});
        reads.push(start);
        schedulePump();
        return handle;
    }
    function legacy(item) {
        if (item.aborted) return;
        var options = {};
        for (var key in item.options) if (Object.prototype.hasOwnProperty.call(item.options, key)) options[key] = item.options[key];
        // success is already registered on the child Deferred.
        delete options.success;
        item.legacy = read(options).done(function () {item.deferred.resolveWith(this, arguments);})
            .fail(function () {item.deferred.rejectWith(this, arguments);});
    }
    function flush() {
        timer = null;
        var items = queue; queue = [];
        items = items.filter(function (item) {return !item.aborted;});
        if (!items.length) return;
        if (!supported) {items.forEach(legacy); return;}
        var names = [], token = items[0].options.data[0].value;
        items = items.filter(function (item) {
            if (item.options.data[0].value !== token) {legacy(item); return false;}
            if (names.indexOf(item.name) < 0) names.push(item.name);
            return true;
        });
        var batch = read({url: "/ajax/dashboard_sync.lua?auto_update=true", type: "POST", dataType: "json", timeout: 8000,
            data: [{name: "CSRFtoken", value: token}, {name: "modules", value: names.join(",")}]
        });
        items.forEach(function (item) {
            item.abortBatch = function () {
                if (items.every(function (member) {return member.aborted;})) batch.abort();
            };
        });
        batch.done(function (data) {
            items.forEach(function (item) {
                if (item.aborted) return;
                var entry = data && data.modules && data.modules[item.name];
                if (entry && entry.status === 200 && entry.data && typeof entry.data === "object") {
                    item.deferred.resolve(entry.data);
                } else {
                    item.deferred.reject(failure(entry ? entry.status : 502, "Invalid dashboard response",
                        entry && entry.responseText, entry && entry.error));
                }
            });
        }).fail(function (xhr, status) {
            if (xhr.status === 403 || xhr.status === 404) {
                supported = false;
                items.forEach(legacy);
            } else {
                items.forEach(function (item) {if (!item.aborted) item.deferred.reject(xhr, status);});
            }
        });
    }
    window.modguiDashboardRequest = function (options) {
        var name = supported && moduleName(options);
        if (!name) return read(options);
        var deferred = $.Deferred();
        if (typeof options.success === "function") deferred.done(options.success);
        var item = {options: options, name: name, deferred: deferred, aborted: false};
        var handle = deferred.promise({abort: function () {
            item.aborted = true;
            if (item.legacy) item.legacy.abort();
            else if (item.abortBatch) item.abortBatch();
            deferred.reject(failure(0, "abort"), "abort");
            return handle;
        }});
        queue.push(item);
        if (timer === null) timer = window.setTimeout(flush, 25);
        return handle;
    };

    window.modguiDashboardRead = read;

    var cancelCardLoads;
    window.modguiAbortDashboardCards = function () {
        if (cancelCardLoads) cancelCardLoads();
        cancelCardLoads = null;
    };
    window.modguiLoadDashboardCards = function (row) {
        window.modguiAbortDashboardCards();
        var cancel = [];
        var stopped = false;
        $(row).children("[data-card-modal]").each(function () {
            var placeholder = $(this), request, retryTimer;
            var modal = placeholder.attr("data-card-modal");
            function current() {
                return !stopped && row.parentNode && placeholder[0].parentNode === row;
            }
            function load(retry) {
                if (!current()) return;
                request = read({url: "/ajax/get_card.lua", type: "GET", dataType: "html",
                    data: {modal: modal}, timeout: 8000}, true);
                request.done(function (html) {
                    if (!current()) return;
                    if (/\bid=["']sign-me-in["']/.test(html)) {
                        window.location.href = "/";
                        return;
                    }
                    if ($.trim(html)) placeholder.replaceWith(html);
                    else placeholder.remove();
                }).fail(function (xhr, status) {
                    if (!current() || status === "abort") return;
                    var timeout = status === "timeout" || xhr.status === 408 || xhr.status === 504;
                    if (!retry && (timeout || xhr.status === 0 || xhr.status === 502 || xhr.status === 503)) {
                        retryTimer = window.setTimeout(function () { load(true); }, 500);
                    } else {
                        showError(timeout);
                    }
                }).always(function () { request = null; });
            }
            function showError(timeout) {
                placeholder.find(".header-title p").text(row.getAttribute("data-card-error-title"));
                placeholder.find(".divtable").attr("role", "status")
                    .text(row.getAttribute(timeout ? "data-card-timeout" : "data-card-error"));
            }
            cancel.push(function () {
                window.clearTimeout(retryTimer);
                if (request) request.abort();
            });
            load(false);
        });
        cancelCardLoads = function () {
            stopped = true;
            cancel.forEach(function (abort) { abort(); });
        };
    };
}(window, jQuery));
