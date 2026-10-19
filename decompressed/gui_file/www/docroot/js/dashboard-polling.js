/* Combine due card reads without sharing data across sessions or caching it. */
(function (window, $) {
    "use strict";
    var queue = [], timer = null, supported = true;
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
            else if (query[i] !== "auto_update=true") return null;
        }
        return name;
    }
    function failure(status, text, body, error) {
        return {status: status, statusText: text, responseText: body || "",
            getResponseHeader: function (name) {return name === "error-msg" ? error : null;}};
    }
    function legacy(item) {
        if (item.aborted) return;
        var options = {};
        for (var key in item.options) if (Object.prototype.hasOwnProperty.call(item.options, key)) options[key] = item.options[key];
        // success is already registered on the child Deferred.
        delete options.success;
        item.legacy = $.ajax(options).done(function (data) {item.deferred.resolve(data);})
            .fail(function (xhr) {item.deferred.reject(xhr);});
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
        $.ajax({url: "/ajax/dashboard_sync.lua?auto_update=true", type: "POST", dataType: "json", timeout: 8000,
            data: [{name: "CSRFtoken", value: token}, {name: "modules", value: names.join(",")}]
        }).done(function (data) {
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
        }).fail(function (xhr) {
            if (xhr.status === 403 || xhr.status === 404) {
                supported = false;
                items.forEach(legacy);
            } else {
                items.forEach(function (item) {if (!item.aborted) item.deferred.reject(xhr);});
            }
        });
    }
    window.modguiDashboardRequest = function (options) {
        var name = supported && moduleName(options);
        if (!name) return $.ajax(options);
        var deferred = $.Deferred();
        if (typeof options.success === "function") deferred.done(options.success);
        var item = {options: options, name: name, deferred: deferred, aborted: false};
        var handle = deferred.promise({abort: function () {
            item.aborted = true;
            if (item.legacy) item.legacy.abort();
            deferred.reject(failure(0, "abort"));
            return handle;
        }});
        queue.push(item);
        if (timer === null) timer = window.setTimeout(flush, 25);
        return handle;
    };
}(window, jQuery));
