/*

$.Link (part of noUiSlider) - WTFPL 
$.fn.noUiSlider - WTFPL - refreshless.com/nouislider/ */
(function(a, u) {
    "object" === typeof module && "object" === typeof module.exports ? module.exports = a.document ? u(a, !0) : function(a) {
        if (!a.document) throw Error("jQuery requires a window with a document");
        return u(a)
    } : u(a)
})("undefined" !== typeof window ? window : this, function(a, u) {
    function r(b) {
        var f = b.length,
            l = e.type(b);
        return "function" === l || e.isWindow(b) ? !1 : 1 === b.nodeType && f ? !0 : "array" === l || 0 === f || "number" === typeof f && 0 < f && f - 1 in b
    }

    function c(b, f, l) {
        if (e.isFunction(f)) return e.grep(b, function(b, e) {
            return !!f.call(b,
                e, b) !== l
        });
        if (f.nodeType) return e.grep(b, function(b) {
            return b === f !== l
        });
        if ("string" === typeof f) {
            if (ya.test(f)) return e.filter(f, b, l);
            f = e.filter(f, b)
        }
        return e.grep(b, function(b) {
            return 0 <= e.inArray(b, f) !== l
        })
    }

    function g(b, f) {
        do b = b[f]; while (b && 1 !== b.nodeType);
        return b
    }

    function k(b) {
        var f = Ua[b] = {};
        e.each(b.match(ja) || [], function(b, e) {
            f[e] = !0
        });
        return f
    }

    function d() {
        L.addEventListener ? (L.removeEventListener("DOMContentLoaded", n, !1), a.removeEventListener("load", n, !1)) : (L.detachEvent("onreadystatechange",
            n), a.detachEvent("onload", n))
    }

    function n() {
        if (L.addEventListener || "load" === event.type || "complete" === L.readyState) d(), e.ready()
    }

    function B(b, f, l) {
        if (void 0 === l && 1 === b.nodeType)
            if (l = "data-" + f.replace(fa, "-$1").toLowerCase(), l = b.getAttribute(l), "string" === typeof l) {
                try {
                    l = "true" === l ? !0 : "false" === l ? !1 : "null" === l ? null : +l + "" === l ? +l : ua.test(l) ? e.parseJSON(l) : l
                } catch (y) {}
                e.data(b, f, l)
            } else l = void 0;
        return l
    }

    function C(b) {
        for (var f in b)
            if (!("data" === f && e.isEmptyObject(b[f])) && "toJSON" !== f) return !1;
        return !0
    }

    function w(b, f, l, y) {
        if (e.acceptData(b)) {
            var a = e.expando,
                q = b.nodeType,
                c = q ? e.cache : b,
                d = q ? b[a] : b[a] && a;
            if (d && c[d] && (y || c[d].data) || !(void 0 === l && "string" === typeof f)) {
                d || (d = q ? b[a] = aa.pop() || e.guid++ : a);
                c[d] || (c[d] = q ? {} : {
                    toJSON: e.noop
                });
                if ("object" === typeof f || "function" === typeof f) y ? c[d] = e.extend(c[d], f) : c[d].data = e.extend(c[d].data, f);
                b = c[d];
                y || (b.data || (b.data = {}), b = b.data);
                void 0 !== l && (b[e.camelCase(f)] = l);
                "string" === typeof f ? (l = b[f], null == l && (l = b[e.camelCase(f)])) : l = b;
                return l
            }
        }
    }

    function x(b, f, l) {
        if (e.acceptData(b)) {
            var y,
                a, q = b.nodeType,
                c = q ? e.cache : b,
                d = q ? b[e.expando] : e.expando;
            if (c[d]) {
                if (f && (y = l ? c[d] : c[d].data)) {
                    e.isArray(f) ? f = f.concat(e.map(f, e.camelCase)) : f in y ? f = [f] : (f = e.camelCase(f), f = f in y ? [f] : f.split(" "));
                    for (a = f.length; a--;) delete y[f[a]];
                    if (l ? !C(y) : !e.isEmptyObject(y)) return
                }
                if (!l && (delete c[d].data, !C(c[d]))) return;
                q ? e.cleanData([b], !0) : E.deleteExpando || c != c.window ? delete c[d] : c[d] = null
            }
        }
    }

    function z() {
        return !0
    }

    function D() {
        return !1
    }

    function t() {
        try {
            return L.activeElement
        } catch (b) {}
    }

    function s(b) {
        var f =
            ab.split("|");
        b = b.createDocumentFragment();
        if (b.createElement)
            for (; f.length;) b.createElement(f.pop());
        return b
    }

    function h(b, f) {
        var l, y, a = 0,
            q = typeof b.getElementsByTagName !== H ? b.getElementsByTagName(f || "*") : typeof b.querySelectorAll !== H ? b.querySelectorAll(f || "*") : void 0;
        if (!q) {
            q = [];
            for (l = b.childNodes || b; null != (y = l[a]); a++) !f || e.nodeName(y, f) ? q.push(y) : e.merge(q, h(y, f))
        }
        return void 0 === f || f && e.nodeName(b, f) ? e.merge([b], q) : q
    }

    function F(b) {
        Ea.test(b.type) && (b.defaultChecked = b.checked)
    }

    function I(b, f) {
        return e.nodeName(b,
            "table") && e.nodeName(11 !== f.nodeType ? f : f.firstChild, "tr") ? b.getElementsByTagName("tbody")[0] || b.appendChild(b.ownerDocument.createElement("tbody")) : b
    }

    function p(b) {
        b.type = (null !== e.find.attr(b, "type")) + "/" + b.type;
        return b
    }

    function A(b) {
        var f = gb.exec(b.type);
        f ? b.type = f[1] : b.removeAttribute("type");
        return b
    }

    function J(b, f) {
        for (var l, y = 0; null != (l = b[y]); y++) e._data(l, "globalEval", !f || e._data(f[y], "globalEval"))
    }

    function M(b, f) {
        if (1 === f.nodeType && e.hasData(b)) {
            var l, y, a;
            y = e._data(b);
            var q = e._data(f, y),
                c = y.events;
            if (c)
                for (l in delete q.handle, q.events = {}, c) {
                    y = 0;
                    for (a = c[l].length; y < a; y++) e.event.add(f, l, c[l][y])
                }
            q.data && (q.data = e.extend({}, q.data))
        }
    }

    function O(b, f) {
        var l, y = e(f.createElement(b)).appendTo(f.body),
            Q = a.getDefaultComputedStyle && (l = a.getDefaultComputedStyle(y[0])) ? l.display : e.css(y[0], "display");
        y.detach();
        return Q
    }

    function V(b) {
        var f = L,
            l = Ab[b];
        if (!l) {
            l = O(b, f);
            if ("none" === l || !l) bb = (bb || e("\x3ciframe frameborder\x3d'0' width\x3d'0' height\x3d'0'/\x3e")).appendTo(f.documentElement), f = (bb[0].contentWindow ||
                bb[0].contentDocument).document, f.write(), f.close(), l = O(b, f), bb.detach();
            Ab[b] = l
        }
        return l
    }

    function m(b, f) {
        return {
            get: function() {
                var e = b();
                if (null != e)
                    if (e) delete this.get;
                    else return (this.get = f).apply(this, arguments)
            }
        }
    }

    function v(b, f) {
        if (f in b) return f;
        for (var e = f.charAt(0).toUpperCase() + f.slice(1), y = f, a = Bb.length; a--;)
            if (f = Bb[a] + e, f in b) return f;
        return y
    }

    function N(b, f) {
        for (var l, y, a, c = [], d = 0, m = b.length; d < m; d++)
            if (y = b[d], y.style)
                if (c[d] = e._data(y, "olddisplay"), l = y.style.display, f) !c[d] && "none" ===
                    l && (y.style.display = ""), "" === y.style.display && pa(y) && (c[d] = e._data(y, "olddisplay", V(y.nodeName)));
                else if (a = pa(y), l && "none" !== l || !a) e._data(y, "olddisplay", a ? l : e.css(y, "display"));
        for (d = 0; d < m; d++)
            if (y = b[d], y.style && (!f || "none" === y.style.display || "" === y.style.display)) y.style.display = f ? c[d] || "" : "none";
        return b
    }

    function G(b, f, e) {
        return (b = Ob.exec(f)) ? Math.max(0, b[1] - (e || 0)) + (b[2] || "px") : f
    }

    function ha(b, f, l, y, a) {
        f = l === (y ? "border" : "content") ? 4 : "width" === f ? 1 : 0;
        for (var c = 0; 4 > f; f += 2) "margin" === l && (c += e.css(b,
            l + va[f], !0, a)), y ? ("content" === l && (c -= e.css(b, "padding" + va[f], !0, a)), "margin" !== l && (c -= e.css(b, "border" + va[f] + "Width", !0, a))) : (c += e.css(b, "padding" + va[f], !0, a), "padding" !== l && (c += e.css(b, "border" + va[f] + "Width", !0, a)));
        return c
    }

    function qa(b, f, l) {
        var y = !0,
            a = "width" === f ? b.offsetWidth : b.offsetHeight,
            c = Fa(b),
            d = E.boxSizing && "border-box" === e.css(b, "boxSizing", !1, c);
        if (0 >= a || null == a) {
            a = Oa(b, f, c);
            if (0 > a || null == a) a = b.style[f];
            if (hb.test(a)) return a;
            y = d && (E.boxSizingReliable() || a === b.style[f]);
            a = parseFloat(a) ||
                0
        }
        return a + ha(b, f, l || (d ? "border" : "content"), y, c) + "px"
    }

    function R(b, f, e, a, c) {
        return new R.prototype.init(b, f, e, a, c)
    }

    function S() {
        setTimeout(function() {
            Va = void 0
        });
        return Va = e.now()
    }

    function T(b, f) {
        var e, a = {
                height: b
            },
            c = 0;
        for (f = f ? 1 : 0; 4 > c; c += 2 - f) e = va[c], a["margin" + e] = a["padding" + e] = b;
        f && (a.opacity = a.width = b);
        return a
    }

    function X(b, f, e) {
        for (var a, c = (cb[f] || []).concat(cb["*"]), q = 0, d = c.length; q < d; q++)
            if (a = c[q].call(e, f, b)) return a
    }

    function W(b, f) {
        var l, a, c, q, d;
        for (l in b)
            if (a = e.camelCase(l), c = f[a], q = b[l],
                e.isArray(q) && (c = q[1], q = b[l] = q[0]), l !== a && (b[a] = q, delete b[l]), (d = e.cssHooks[a]) && "expand" in d)
                for (l in q = d.expand(q), delete b[a], q) l in b || (b[l] = q[l], f[l] = c);
            else f[a] = c
    }

    function Y(b, f, l) {
        var a, c = 0,
            q = ib.length,
            d = e.Deferred().always(function() {
                delete m.elem
            }),
            m = function() {
                if (a) return !1;
                for (var f = Va || S(), f = Math.max(0, h.startTime + h.duration - f), e = 1 - (f / h.duration || 0), l = 0, c = h.tweens.length; l < c; l++) h.tweens[l].run(e);
                d.notifyWith(b, [h, e, f]);
                if (1 > e && c) return f;
                d.resolveWith(b, [h]);
                return !1
            },
            h = d.promise({
                elem: b,
                props: e.extend({}, f),
                opts: e.extend(!0, {
                    specialEasing: {}
                }, l),
                originalProperties: f,
                originalOptions: l,
                startTime: Va || S(),
                duration: l.duration,
                tweens: [],
                createTween: function(f, l) {
                    var a = e.Tween(b, h.opts, f, l, h.opts.specialEasing[f] || h.opts.easing);
                    h.tweens.push(a);
                    return a
                },
                stop: function(f) {
                    var e = 0,
                        l = f ? h.tweens.length : 0;
                    if (a) return this;
                    for (a = !0; e < l; e++) h.tweens[e].run(1);
                    f ? d.resolveWith(b, [h, f]) : d.rejectWith(b, [h, f]);
                    return this
                }
            });
        l = h.props;
        for (W(l, h.opts.specialEasing); c < q; c++)
            if (f = ib[c].call(h, b, l, h.opts)) return f;
        e.map(l, X, h);
        e.isFunction(h.opts.start) && h.opts.start.call(b, h);
        e.fx.timer(e.extend(m, {
            elem: b,
            anim: h,
            queue: h.opts.queue
        }));
        return h.progress(h.opts.progress).done(h.opts.done, h.opts.complete).fail(h.opts.fail).always(h.opts.always)
    }

    function Ba(b) {
        return function(f, l) {
            "string" !== typeof f && (l = f, f = "*");
            var a, c = 0,
                q = f.toLowerCase().match(ja) || [];
            if (e.isFunction(l))
                for (; a = q[c++];) "+" === a.charAt(0) ? (a = a.slice(1) || "*", (b[a] = b[a] || []).unshift(l)) : (b[a] = b[a] || []).push(l)
        }
    }

    function Pa(b, f, l, a) {
        function c(h) {
            var m;
            q[h] = !0;
            e.each(b[h] || [], function(b, e) {
                var h = e(f, l, a);
                if ("string" === typeof h && !d && !q[h]) return f.dataTypes.unshift(h), c(h), !1;
                if (d) return !(m = h)
            });
            return m
        }
        var q = {},
            d = b === rb;
        return c(f.dataTypes[0]) || !q["*"] && c("*")
    }

    function Ga(b, f) {
        var l, a, c = e.ajaxSettings.flatOptions || {};
        for (a in f) void 0 !== f[a] && ((c[a] ? b : l || (l = {}))[a] = f[a]);
        l && e.extend(!0, b, l);
        return b
    }

    function ka(b, f, l, a) {
        var c;
        if (e.isArray(f)) e.each(f, function(f, e) {
            l || Pb.test(b) ? a(b, e) : ka(b + "[" + ("object" === typeof e ? f : "") + "]", e, l, a)
        });
        else if (!l &&
            "object" === e.type(f))
            for (c in f) ka(b + "[" + c + "]", f[c], l, a);
        else a(b, f)
    }

    function Wa() {
        try {
            return new a.XMLHttpRequest
        } catch (b) {}
    }

    function ca(b) {
        return e.isWindow(b) ? b : 9 === b.nodeType ? b.defaultView || b.parentWindow : !1
    }
    var aa = [],
        P = aa.slice,
        ma = aa.concat,
        ga = aa.push,
        Xa = aa.indexOf,
        ba = {},
        na = ba.toString,
        da = ba.hasOwnProperty,
        E = {},
        e = function(b, f) {
            return new e.fn.init(b, f)
        },
        Ha = /^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g,
        Ya = /^-ms-/,
        ea = /-([\da-z])/gi,
        Ca = function(b, f) {
            return f.toUpperCase()
        };
    e.fn = e.prototype = {
        jquery: "1.11.1",
        constructor: e,
        selector: "",
        length: 0,
        toArray: function() {
            return P.call(this)
        },
        get: function(b) {
            return null != b ? 0 > b ? this[b + this.length] : this[b] : P.call(this)
        },
        pushStack: function(b) {
            b = e.merge(this.constructor(), b);
            b.prevObject = this;
            b.context = this.context;
            return b
        },
        each: function(b, f) {
            return e.each(this, b, f)
        },
        map: function(b) {
            return this.pushStack(e.map(this, function(f, e) {
                return b.call(f, e, f)
            }))
        },
        slice: function() {
            return this.pushStack(P.apply(this, arguments))
        },
        first: function() {
            return this.eq(0)
        },
        last: function() {
            return this.eq(-1)
        },
        eq: function(b) {
            var f = this.length;
            b = +b + (0 > b ? f : 0);
            return this.pushStack(0 <= b && b < f ? [this[b]] : [])
        },
        end: function() {
            return this.prevObject || this.constructor(null)
        },
        push: ga,
        sort: aa.sort,
        splice: aa.splice
    };
    e.extend = e.fn.extend = function() {
        var b, f, l, a, c, q = arguments[0] || {},
            d = 1,
            h = arguments.length,
            m = !1;
        "boolean" === typeof q && (m = q, q = arguments[d] || {}, d++);
        "object" !== typeof q && !e.isFunction(q) && (q = {});
        d === h && (q = this, d--);
        for (; d < h; d++)
            if (null != (c = arguments[d]))
                for (a in c) b = q[a], l = c[a], q !== l && (m && l && (e.isPlainObject(l) ||
                    (f = e.isArray(l))) ? (f ? (f = !1, b = b && e.isArray(b) ? b : []) : b = b && e.isPlainObject(b) ? b : {}, q[a] = e.extend(m, b, l)) : void 0 !== l && (q[a] = l));
        return q
    };
    e.extend({
        expando: "jQuery" + ("1.11.1" + Math.random()).replace(/\D/g, ""),
        isReady: !0,
        error: function(b) {
            throw Error(b);
        },
        noop: function() {},
        isFunction: function(b) {
            return "function" === e.type(b)
        },
        isArray: Array.isArray || function(b) {
            return "array" === e.type(b)
        },
        isWindow: function(b) {
            return null != b && b == b.window
        },
        isNumeric: function(b) {
            return !e.isArray(b) && 0 <= b - parseFloat(b)
        },
        isEmptyObject: function(b) {
            for (var f in b) return !1;
            return !0
        },
        isPlainObject: function(b) {
            var f;
            if (!b || "object" !== e.type(b) || b.nodeType || e.isWindow(b)) return !1;
            try {
                if (b.constructor && !da.call(b, "constructor") && !da.call(b.constructor.prototype, "isPrototypeOf")) return !1
            } catch (l) {
                return !1
            }
            if (E.ownLast)
                for (f in b) return da.call(b, f);
            for (f in b);
            return void 0 === f || da.call(b, f)
        },
        type: function(b) {
            return null == b ? b + "" : "object" === typeof b || "function" === typeof b ? ba[na.call(b)] || "object" : typeof b
        },
        globalEval: function(b) {
            b && e.trim(b) && (a.execScript || function(b) {
                a.eval.call(a,
                    b)
            })(b)
        },
        camelCase: function(b) {
            return b.replace(Ya, "ms-").replace(ea, Ca)
        },
        nodeName: function(b, f) {
            return b.nodeName && b.nodeName.toLowerCase() === f.toLowerCase()
        },
        each: function(b, f, e) {
            var a, c = 0,
                q = b.length;
            a = r(b);
            if (e)
                if (a)
                    for (; c < q && !(a = f.apply(b[c], e), !1 === a); c++);
                else
                    for (c in b) {
                        if (a = f.apply(b[c], e), !1 === a) break
                    } else if (a)
                        for (; c < q && !(a = f.call(b[c], c, b[c]), !1 === a); c++);
                    else
                        for (c in b)
                            if (a = f.call(b[c], c, b[c]), !1 === a) break;
            return b
        },
        trim: function(b) {
            return null == b ? "" : (b + "").replace(Ha, "")
        },
        makeArray: function(b,
            f) {
            var l = f || [];
            null != b && (r(Object(b)) ? e.merge(l, "string" === typeof b ? [b] : b) : ga.call(l, b));
            return l
        },
        inArray: function(b, f, e) {
            var a;
            if (f) {
                if (Xa) return Xa.call(f, b, e);
                a = f.length;
                for (e = e ? 0 > e ? Math.max(0, a + e) : e : 0; e < a; e++)
                    if (e in f && f[e] === b) return e
            }
            return -1
        },
        merge: function(b, f) {
            for (var e = +f.length, a = 0, c = b.length; a < e;) b[c++] = f[a++];
            if (e !== e)
                for (; void 0 !== f[a];) b[c++] = f[a++];
            b.length = c;
            return b
        },
        grep: function(b, f, e) {
            for (var a = [], c = 0, q = b.length, d = !e; c < q; c++) e = !f(b[c], c), e !== d && a.push(b[c]);
            return a
        },
        map: function(b,
            f, e) {
            var a, c = 0,
                q = b.length,
                d = [];
            if (r(b))
                for (; c < q; c++) a = f(b[c], c, e), null != a && d.push(a);
            else
                for (c in b) a = f(b[c], c, e), null != a && d.push(a);
            return ma.apply([], d)
        },
        guid: 1,
        proxy: function(b, f) {
            var l, a;
            "string" === typeof f && (a = b[f], f = b, b = a);
            if (e.isFunction(b)) return l = P.call(arguments, 2), a = function() {
                return b.apply(f || this, l.concat(P.call(arguments)))
            }, a.guid = b.guid = b.guid || e.guid++, a
        },
        now: function() {
            return +new Date
        },
        support: E
    });
																									   
												  
	   
    e.each("Boolean Number String Function Array Date RegExp Object Error".split(" "),
        function(b, f) {
            ba["[object " + f + "]"] = f.toLowerCase()
        });
    var la = function(b) {
        function f(b, f, e, l) {
            var a, c, y, q, d;
            (f ? f.ownerDocument || f : x) !== r && Z(f);
            f = f || r;
            e = e || [];
            if (!b || "string" !== typeof b) return e;
            if (1 !== (q = f.nodeType) && 9 !== q) return [];
            if (w && !l) {
                if (a = na.exec(b))
                    if (y = a[1])
                        if (9 === q)
                            if ((c = f.getElementById(y)) && c.parentNode) {
                                if (c.id === y) return e.push(c), e
                            } else return e;
                else {
                    if (f.ownerDocument && (c = f.ownerDocument.getElementById(y)) && Ra(f, c) && c.id === y) return e.push(c), e
                } else {
                    if (a[2]) return Aa.apply(e, f.getElementsByTagName(b)),
                        e;
                    if ((y = a[3]) && N.getElementsByClassName && f.getElementsByClassName) return Aa.apply(e, f.getElementsByClassName(y)), e
                }
                if (N.qsa && (!C || !C.test(b))) {
                    c = a = R;
                    y = f;
                    d = 9 === q && b;
                    if (1 === q && "object" !== f.nodeName.toLowerCase()) {
                        q = V(b);
                        (a = f.getAttribute("id")) ? c = a.replace(ra, "\\$\x26"): f.setAttribute("id", c);
                        c = "[id\x3d'" + c + "'] ";
                        for (y = q.length; y--;) q[y] = c + v(q[y]);
                        y = la.test(b) && p(f.parentNode) || f;
                        d = q.join(",")
                    }
                    if (d) try {
                        return Aa.apply(e, y.querySelectorAll(d)), e
                    } catch (Q) {} finally {
                        a || f.removeAttribute("id")
                    }
                }
            }
            return T(b.replace(za,
                "$1"), f, e, l)
        }

        function e() {
            function b(e, l) {
                f.push(e + " ") > A.cacheLength && delete b[f.shift()];
                return b[e + " "] = l
            }
            var f = [];
            return b
        }

        function a(b) {
            b[R] = !0;
            return b
        }

        function c(b) {
            var f = r.createElement("div");
            try {
                return !!b(f)
            } catch (e) {
                return !1
            } finally {
                f.parentNode && f.parentNode.removeChild(f)
            }
        }

        function q(b, f) {
            for (var e = b.split("|"), l = b.length; l--;) A.attrHandle[e[l]] = f
        }

        function d(b, f) {
            var e = f && b,
                l = e && 1 === b.nodeType && 1 === f.nodeType && (~f.sourceIndex || K) - (~b.sourceIndex || K);
            if (l) return l;
            if (e)
                for (; e = e.nextSibling;)
                    if (e ===
                        f) return -1;
            return b ? 1 : -1
        }

        function h(b) {
            return function(f) {
                return "input" === f.nodeName.toLowerCase() && f.type === b
            }
        }

        function m(b) {
            return function(f) {
                var e = f.nodeName.toLowerCase();
                return ("input" === e || "button" === e) && f.type === b
            }
        }

        function g(b) {
            return a(function(f) {
                f = +f;
                return a(function(e, l) {
                    for (var a, c = b([], e.length, f), y = c.length; y--;)
                        if (e[a = c[y]]) e[a] = !(l[a] = e[a])
                })
            })
        }

        function p(b) {
            return b && typeof b.getElementsByTagName !== La && b
        }

        function n() {}

        function v(b) {
            for (var f = 0, e = b.length, l = ""; f < e; f++) l += b[f].value;
            return l
        }

        function k(b, f, e) {
            var l = f.dir,
                a = e && "parentNode" === l,
                c = Ba++;
            return f.first ? function(f, e, c) {
                for (; f = f[l];)
                    if (1 === f.nodeType || a) return b(f, e, c)
            } : function(f, e, y) {
                var q, d, Q = [z, c];
                if (y)
                    for (; f = f[l];) {
                        if ((1 === f.nodeType || a) && b(f, e, y)) return !0
                    } else
                        for (; f = f[l];)
                            if (1 === f.nodeType || a) {
                                d = f[R] || (f[R] = {});
                                if ((q = d[l]) && q[0] === z && q[1] === c) return Q[2] = q[2];
                                d[l] = Q;
                                if (Q[2] = b(f, e, y)) return !0
                            }
            }
        }

        function s(b) {
            return 1 < b.length ? function(f, e, l) {
                for (var a = b.length; a--;)
                    if (!b[a](f, e, l)) return !1;
                return !0
            } : b[0]
        }

        function F(b,
            f, e, l, a) {
            for (var c, y = [], q = 0, d = b.length, Q = null != f; q < d; q++)
                if (c = b[q])
                    if (!e || e(c, l, a)) y.push(c), Q && f.push(q);
            return y
        }

        function I(b, e, l, c, q, d) {
            c && !c[R] && (c = I(c));
            q && !q[R] && (q = I(q, d));
            return a(function(a, y, d, Q) {
                var h, m, g = [],
                    p = [],
                    v = y.length,
                    n;
                if (!(n = a)) {
                    n = e || "*";
                    for (var U = d.nodeType ? [d] : d, k = [], s = 0, I = U.length; s < I; s++) f(n, U[s], k);
                    n = k
                }
                n = b && (a || !e) ? F(n, g, b, d, Q) : n;
                U = l ? q || (a ? b : v || c) ? [] : y : n;
                l && l(n, U, d, Q);
                if (c) {
                    h = F(U, p);
                    c(h, [], d, Q);
                    for (d = h.length; d--;)
                        if (m = h[d]) U[p[d]] = !(n[p[d]] = m)
                }
                if (a) {
                    if (q || b) {
                        if (q) {
                            h = [];
                            for (d =
                                U.length; d--;)
                                if (m = U[d]) h.push(n[d] = m);
                            q(null, U = [], h, Q)
                        }
                        for (d = U.length; d--;)
                            if ((m = U[d]) && -1 < (h = q ? da.call(a, m) : g[d])) a[h] = !(y[h] = m)
                    }
                } else U = F(U === y ? U.splice(v, U.length) : U), q ? q(null, y, U, Q) : Aa.apply(y, U)
            })
        }

        function O(b) {
            var f, e, l, a = b.length,
                c = A.relative[b[0].type];
            e = c || A.relative[" "];
            for (var y = c ? 1 : 0, q = k(function(b) {
                    return b === f
                }, e, !0), d = k(function(b) {
                    return -1 < da.call(f, b)
                }, e, !0), Q = [function(b, e, l) {
                    return !c && (l || e !== X) || ((f = e).nodeType ? q(b, e, l) : d(b, e, l))
                }]; y < a; y++)
                if (e = A.relative[b[y].type]) Q = [k(s(Q),
                    e)];
                else {
                    e = A.filter[b[y].type].apply(null, b[y].matches);
                    if (e[R]) {
                        for (l = ++y; l < a && !A.relative[b[l].type]; l++);
                        return I(1 < y && s(Q), 1 < y && v(b.slice(0, y - 1).concat({
                            value: " " === b[y - 2].type ? "*" : ""
                        })).replace(za, "$1"), e, y < l && O(b.slice(y, l)), l < a && O(b = b.slice(l)), l < a && v(b))
                    }
                    Q.push(e)
                }
            return s(Q)
        }

        function M(b, e) {
            var l = 0 < e.length,
                c = 0 < b.length,
                q = function(a, y, q, d, Q) {
                    var h, m, g, p = 0,
                        U = "0",
                        n = a && [],
                        v = [],
                        k = X,
                        s = a || c && A.find.TAG("*", Q),
                        I = z += null == k ? 1 : Math.random() || 0.1,
                        N = s.length;
                    for (Q && (X = y !== r && y); U !== N && null != (h = s[U]); U++) {
                        if (c &&
                            h) {
                            for (m = 0; g = b[m++];)
                                if (g(h, y, q)) {
                                    d.push(h);
                                    break
                                }
                            Q && (z = I)
                        }
                        l && ((h = !g && h) && p--, a && n.push(h))
                    }
                    p += U;
                    if (l && U !== p) {
                        for (m = 0; g = e[m++];) g(n, v, y, q);
                        if (a) {
                            if (0 < p)
                                for (; U--;) !n[U] && !v[U] && (v[U] = Pa.call(d));
                            v = F(v)
                        }
                        Aa.apply(d, v);
                        Q && (!a && 0 < v.length && 1 < p + e.length) && f.uniqueSort(d)
                    }
                    Q && (z = I, X = k);
                    return n
                };
            return l ? a(q) : q
        }
        var t, N, A, B, G, V, E, T, X, D, W, Z, r, u, w, C, J, ha, Ra, R = "sizzle" + -new Date,
            x = b.document,
            z = 0,
            Ba = 0,
            S = e(),
            Y = e(),
            H = e(),
            qa = function(b, f) {
                b === f && (W = !0);
                return 0
            },
            La = "undefined",
            K = -2147483648,
            L = {}.hasOwnProperty,
            ea = [],
            Pa = ea.pop,
            mb = ea.push,
            Aa = ea.push,
            P = ea.slice,
            da = ea.indexOf || function(b) {
                for (var f = 0, e = this.length; f < e; f++)
                    if (this[f] === b) return f;
                return -1
            },
            ia = "(?:\\\\.|[\\w-]|[^\\x00-\\xa0])+".replace("w", "w#"),
            gb = "\\[[\\x20\\t\\r\\n\\f]*((?:\\\\.|[\\w-]|[^\\x00-\\xa0])+)(?:[\\x20\\t\\r\\n\\f]*([*^$|!~]?\x3d)[\\x20\\t\\r\\n\\f]*(?:'((?:\\\\.|[^\\\\'])*)'|\"((?:\\\\.|[^\\\\\"])*)\"|(" + ia + "))|)[\\x20\\t\\r\\n\\f]*\\]",
            ga = ":((?:\\\\.|[\\w-]|[^\\x00-\\xa0])+)(?:\\((('((?:\\\\.|[^\\\\'])*)'|\"((?:\\\\.|[^\\\\\"])*)\")|((?:\\\\.|[^\\\\()[\\]]|" +
            gb + ")*)|.*)\\)|)",
            za = RegExp("^[\\x20\\t\\r\\n\\f]+|((?:^|[^\\\\])(?:\\\\.)*)[\\x20\\t\\r\\n\\f]+$", "g"),
            Ga = /^[\x20\t\r\n\f]*,[\x20\t\r\n\f]*/,
            Ha = /^[\x20\t\r\n\f]*([>+~]|[\x20\t\r\n\f])[\x20\t\r\n\f]*/,
            ca = RegExp("\x3d[\\x20\\t\\r\\n\\f]*([^\\]'\"]*?)[\\x20\\t\\r\\n\\f]*\\]", "g"),
            tb = RegExp(ga),
            ma = RegExp("^" + ia + "$"),
            aa = {
                ID: /^#((?:\\.|[\w-]|[^\x00-\xa0])+)/,
                CLASS: /^\.((?:\\.|[\w-]|[^\x00-\xa0])+)/,
                TAG: RegExp("^(" + "(?:\\\\.|[\\w-]|[^\\x00-\\xa0])+".replace("w", "w*") + ")"),
                ATTR: RegExp("^" + gb),
                PSEUDO: RegExp("^" +
                    ga),
                CHILD: RegExp("^:(only|first|last|nth|nth-last)-(child|of-type)(?:\\([\\x20\\t\\r\\n\\f]*(even|odd|(([+-]|)(\\d*)n|)[\\x20\\t\\r\\n\\f]*(?:([+-]|)[\\x20\\t\\r\\n\\f]*(\\d+)|))[\\x20\\t\\r\\n\\f]*\\)|)", "i"),
                bool: RegExp("^(?:checked|selected|async|autofocus|autoplay|controls|defer|disabled|hidden|ismap|loop|multiple|open|readonly|required|scoped)$", "i"),
                needsContext: RegExp("^[\\x20\\t\\r\\n\\f]*[\x3e+~]|:(even|odd|eq|gt|lt|nth|first|last)(?:\\([\\x20\\t\\r\\n\\f]*((?:-\\d)?\\d*)[\\x20\\t\\r\\n\\f]*\\)|)(?\x3d[^-]|$)",
                    "i")
            },
            Ca = /^(?:input|select|textarea|button)$/i,
            Ya = /^h\d$/i,
            ka = /^[^{]+\{\s*\[native \w/,
            na = /^(?:#([\w-]+)|(\w+)|\.([\w-]+))$/,
            la = /[+~]/,
            ra = /'|\\/g,
            ba = RegExp("\\\\([\\da-f]{1,6}[\\x20\\t\\r\\n\\f]?|([\\x20\\t\\r\\n\\f])|.)", "ig"),
            ta = function(b, f, e) {
                b = "0x" + f - 65536;
                return b !== b || e ? f : 0 > b ? String.fromCharCode(b + 65536) : String.fromCharCode(b >> 10 | 55296, b & 1023 | 56320)
            };
        try {
            Aa.apply(ea = P.call(x.childNodes), x.childNodes), ea[x.childNodes.length].nodeType
        } catch (Fa) {
            Aa = {
                apply: ea.length ? function(b, f) {
                    mb.apply(b, P.call(f))
                } : function(b, f) {
                    for (var e = b.length, l = 0; b[e++] = f[l++];);
                    b.length = e - 1
                }
            }
        }
        N = f.support = {};
        G = f.isXML = function(b) {
            return (b = b && (b.ownerDocument || b).documentElement) ? "HTML" !== b.nodeName : !1
        };
        Z = f.setDocument = function(b) {
            var f = b ? b.ownerDocument || b : x;
            b = f.defaultView;
            if (f === r || 9 !== f.nodeType || !f.documentElement) return r;
            r = f;
            u = f.documentElement;
            w = !G(f);
            b && b !== b.top && (b.addEventListener ? b.addEventListener("unload", function() {
                Z()
            }, !1) : b.attachEvent && b.attachEvent("onunload", function() {
                Z()
            }));
            N.attributes = c(function(b) {
                b.className =
                    "i";
                return !b.getAttribute("className")
            });
            N.getElementsByTagName = c(function(b) {
                b.appendChild(f.createComment(""));
                return !b.getElementsByTagName("*").length
            });
            N.getElementsByClassName = ka.test(f.getElementsByClassName) && c(function(b) {
                b.innerHTML = "\x3cdiv class\x3d'a'\x3e\x3c/div\x3e\x3cdiv class\x3d'a i'\x3e\x3c/div\x3e";
                b.firstChild.className = "i";
                return 2 === b.getElementsByClassName("i").length
            });
            N.getById = c(function(b) {
                u.appendChild(b).id = R;
                return !f.getElementsByName || !f.getElementsByName(R).length
            });
            N.getById ? (A.find.ID = function(b, f) {
                if (typeof f.getElementById !== La && w) {
                    var e = f.getElementById(b);
                    return e && e.parentNode ? [e] : []
                }
            }, A.filter.ID = function(b) {
                var f = b.replace(ba, ta);
                return function(b) {
                    return b.getAttribute("id") === f
                }
            }) : (delete A.find.ID, A.filter.ID = function(b) {
                var f = b.replace(ba, ta);
                return function(b) {
                    return (b = typeof b.getAttributeNode !== La && b.getAttributeNode("id")) && b.value === f
                }
            });
            A.find.TAG = N.getElementsByTagName ? function(b, f) {
                    if (typeof f.getElementsByTagName !== La) return f.getElementsByTagName(b)
                } :
                function(b, f) {
                    var e, l = [],
                        a = 0,
                        c = f.getElementsByTagName(b);
                    if ("*" === b) {
                        for (; e = c[a++];) 1 === e.nodeType && l.push(e);
                        return l
                    }
                    return c
                };
            A.find.CLASS = N.getElementsByClassName && function(b, f) {
                if (typeof f.getElementsByClassName !== La && w) return f.getElementsByClassName(b)
            };
            J = [];
            C = [];
            if (N.qsa = ka.test(f.querySelectorAll)) c(function(b) {
                b.innerHTML = "\x3cselect msallowclip\x3d''\x3e\x3coption selected\x3d''\x3e\x3c/option\x3e\x3c/select\x3e";
                b.querySelectorAll("[msallowclip^\x3d'']").length && C.push("[*^$]\x3d[\\x20\\t\\r\\n\\f]*(?:''|\"\")");
                b.querySelectorAll("[selected]").length || C.push("\\[[\\x20\\t\\r\\n\\f]*(?:value|checked|selected|async|autofocus|autoplay|controls|defer|disabled|hidden|ismap|loop|multiple|open|readonly|required|scoped)");
                b.querySelectorAll(":checked").length || C.push(":checked")
            }), c(function(b) {
                var e = f.createElement("input");
                e.setAttribute("type", "hidden");
                b.appendChild(e).setAttribute("name", "D");
                b.querySelectorAll("[name\x3dd]").length && C.push("name[\\x20\\t\\r\\n\\f]*[*^$|!~]?\x3d");
                b.querySelectorAll(":enabled").length ||
                    C.push(":enabled", ":disabled");
                b.querySelectorAll("*,:x");
                C.push(",.*:")
            });
            (N.matchesSelector = ka.test(ha = u.matches || u.webkitMatchesSelector || u.mozMatchesSelector || u.oMatchesSelector || u.msMatchesSelector)) && c(function(b) {
                N.disconnectedMatch = ha.call(b, "div");
                ha.call(b, "[s!\x3d'']:x");
                J.push("!\x3d", ga)
            });
            C = C.length && RegExp(C.join("|"));
            J = J.length && RegExp(J.join("|"));
            Ra = (b = ka.test(u.compareDocumentPosition)) || ka.test(u.contains) ? function(b, f) {
                var e = 9 === b.nodeType ? b.documentElement : b,
                    l = f && f.parentNode;
                return b === l || !(!l || !(1 === l.nodeType && (e.contains ? e.contains(l) : b.compareDocumentPosition && b.compareDocumentPosition(l) & 16)))
            } : function(b, f) {
                if (f)
                    for (; f = f.parentNode;)
                        if (f === b) return !0;
                return !1
            };
            qa = b ? function(b, e) {
                if (b === e) return W = !0, 0;
                var l = !b.compareDocumentPosition - !e.compareDocumentPosition;
                if (l) return l;
                l = (b.ownerDocument || b) === (e.ownerDocument || e) ? b.compareDocumentPosition(e) : 1;
                return l & 1 || !N.sortDetached && e.compareDocumentPosition(b) === l ? b === f || b.ownerDocument === x && Ra(x, b) ? -1 : e === f || e.ownerDocument ===
                    x && Ra(x, e) ? 1 : D ? da.call(D, b) - da.call(D, e) : 0 : l & 4 ? -1 : 1
            } : function(b, e) {
                if (b === e) return W = !0, 0;
                var l, a = 0;
                l = b.parentNode;
                var c = e.parentNode,
                    y = [b],
                    q = [e];
                if (!l || !c) return b === f ? -1 : e === f ? 1 : l ? -1 : c ? 1 : D ? da.call(D, b) - da.call(D, e) : 0;
                if (l === c) return d(b, e);
                for (l = b; l = l.parentNode;) y.unshift(l);
                for (l = e; l = l.parentNode;) q.unshift(l);
                for (; y[a] === q[a];) a++;
                return a ? d(y[a], q[a]) : y[a] === x ? -1 : q[a] === x ? 1 : 0
            };
            return f
        };
        f.matches = function(b, e) {
            return f(b, null, null, e)
        };
        f.matchesSelector = function(b, e) {
            (b.ownerDocument || b) !== r &&
                Z(b);
            e = e.replace(ca, "\x3d'$1']");
            if (N.matchesSelector && w && (!J || !J.test(e)) && (!C || !C.test(e))) try {
                var l = ha.call(b, e);
                if (l || N.disconnectedMatch || b.document && 11 !== b.document.nodeType) return l
            } catch (a) {}
            return 0 < f(e, r, null, [b]).length
        };
        f.contains = function(b, f) {
            (b.ownerDocument || b) !== r && Z(b);
            return Ra(b, f)
        };
        f.attr = function(b, f) {
            (b.ownerDocument || b) !== r && Z(b);
            var e = A.attrHandle[f.toLowerCase()],
                e = e && L.call(A.attrHandle, f.toLowerCase()) ? e(b, f, !w) : void 0;
            return void 0 !== e ? e : N.attributes || !w ? b.getAttribute(f) :
                (e = b.getAttributeNode(f)) && e.specified ? e.value : null
        };
        f.error = function(b) {
            throw Error("Syntax error, unrecognized expression: " + b);
        };
        f.uniqueSort = function(b) {
            var f, e = [],
                l = 0,
                a = 0;
            W = !N.detectDuplicates;
            D = !N.sortStable && b.slice(0);
            b.sort(qa);
            if (W) {
                for (; f = b[a++];) f === b[a] && (l = e.push(a));
                for (; l--;) b.splice(e[l], 1)
            }
            D = null;
            return b
        };
        B = f.getText = function(b) {
            var f, e = "",
                l = 0;
            if (f = b.nodeType)
                if (1 === f || 9 === f || 11 === f) {
                    if ("string" === typeof b.textContent) return b.textContent;
                    for (b = b.firstChild; b; b = b.nextSibling) e +=
                        B(b)
                } else {
                    if (3 === f || 4 === f) return b.nodeValue
                }
            else
                for (; f = b[l++];) e += B(f);
            return e
        };
        A = f.selectors = {
            cacheLength: 50,
            createPseudo: a,
            match: aa,
            attrHandle: {},
            find: {},
            relative: {
                "\x3e": {
                    dir: "parentNode",
                    first: !0
                },
                " ": {
                    dir: "parentNode"
                },
                "+": {
                    dir: "previousSibling",
                    first: !0
                },
                "~": {
                    dir: "previousSibling"
                }
            },
            preFilter: {
                ATTR: function(b) {
                    b[1] = b[1].replace(ba, ta);
                    b[3] = (b[3] || b[4] || b[5] || "").replace(ba, ta);
                    "~\x3d" === b[2] && (b[3] = " " + b[3] + " ");
                    return b.slice(0, 4)
                },
                CHILD: function(b) {
                    b[1] = b[1].toLowerCase();
                    "nth" === b[1].slice(0,
                        3) ? (b[3] || f.error(b[0]), b[4] = +(b[4] ? b[5] + (b[6] || 1) : 2 * ("even" === b[3] || "odd" === b[3])), b[5] = +(b[7] + b[8] || "odd" === b[3])) : b[3] && f.error(b[0]);
                    return b
                },
                PSEUDO: function(b) {
                    var f, e = !b[6] && b[2];
                    if (aa.CHILD.test(b[0])) return null;
                    if (b[3]) b[2] = b[4] || b[5] || "";
                    else if (e && tb.test(e) && (f = V(e, !0)) && (f = e.indexOf(")", e.length - f) - e.length)) b[0] = b[0].slice(0, f), b[2] = e.slice(0, f);
                    return b.slice(0, 3)
                }
            },
            filter: {
                TAG: function(b) {
                    var f = b.replace(ba, ta).toLowerCase();
                    return "*" === b ? function() {
                        return !0
                    } : function(b) {
                        return b.nodeName &&
                            b.nodeName.toLowerCase() === f
                    }
                },
                CLASS: function(b) {
                    var f = S[b + " "];
                    return f || (f = RegExp("(^|[\\x20\\t\\r\\n\\f])" + b + "([\\x20\\t\\r\\n\\f]|$)")) && S(b, function(b) {
                        return f.test("string" === typeof b.className && b.className || typeof b.getAttribute !== La && b.getAttribute("class") || "")
                    })
                },
                ATTR: function(b, e, l) {
                    return function(a) {
                        a = f.attr(a, b);
                        if (null == a) return "!\x3d" === e;
                        if (!e) return !0;
                        a += "";
                        return "\x3d" === e ? a === l : "!\x3d" === e ? a !== l : "^\x3d" === e ? l && 0 === a.indexOf(l) : "*\x3d" === e ? l && -1 < a.indexOf(l) : "$\x3d" === e ? l && a.slice(-l.length) ===
                            l : "~\x3d" === e ? -1 < (" " + a + " ").indexOf(l) : "|\x3d" === e ? a === l || a.slice(0, l.length + 1) === l + "-" : !1
                    }
                },
                CHILD: function(b, f, e, l, a) {
                    var c = "nth" !== b.slice(0, 3),
                        y = "last" !== b.slice(-4),
                        q = "of-type" === f;
                    return 1 === l && 0 === a ? function(b) {
                        return !!b.parentNode
                    } : function(f, e, d) {
                        var Q, h, m, g, p;
                        e = c !== y ? "nextSibling" : "previousSibling";
                        var U = f.parentNode,
                            n = q && f.nodeName.toLowerCase();
                        d = !d && !q;
                        if (U) {
                            if (c) {
                                for (; e;) {
                                    for (h = f; h = h[e];)
                                        if (q ? h.nodeName.toLowerCase() === n : 1 === h.nodeType) return !1;
                                    p = e = "only" === b && !p && "nextSibling"
                                }
                                return !0
                            }
                            p = [y ? U.firstChild : U.lastChild];
                            if (y && d) {
                                d = U[R] || (U[R] = {});
                                Q = d[b] || [];
                                g = Q[0] === z && Q[1];
                                m = Q[0] === z && Q[2];
                                for (h = g && U.childNodes[g]; h = ++g && h && h[e] || (m = g = 0) || p.pop();)
                                    if (1 === h.nodeType && ++m && h === f) {
                                        d[b] = [z, g, m];
                                        break
                                    }
                            } else if (d && (Q = (f[R] || (f[R] = {}))[b]) && Q[0] === z) m = Q[1];
                            else
                                for (; h = ++g && h && h[e] || (m = g = 0) || p.pop();)
                                    if ((q ? h.nodeName.toLowerCase() === n : 1 === h.nodeType) && ++m)
                                        if (d && ((h[R] || (h[R] = {}))[b] = [z, m]), h === f) break;
                            m -= a;
                            return m === l || 0 === m % l && 0 <= m / l
                        }
                    }
                },
                PSEUDO: function(b, e) {
                    var l, c = A.pseudos[b] || A.setFilters[b.toLowerCase()] ||
                        f.error("unsupported pseudo: " + b);
                    return c[R] ? c(e) : 1 < c.length ? (l = [b, b, "", e], A.setFilters.hasOwnProperty(b.toLowerCase()) ? a(function(b, f) {
                        for (var l, a = c(b, e), y = a.length; y--;) l = da.call(b, a[y]), b[l] = !(f[l] = a[y])
                    }) : function(b) {
                        return c(b, 0, l)
                    }) : c
                }
            },
            pseudos: {
                not: a(function(b) {
                    var f = [],
                        e = [],
                        l = E(b.replace(za, "$1"));
                    return l[R] ? a(function(b, f, e, a) {
                        a = l(b, null, a, []);
                        for (var c = b.length; c--;)
                            if (e = a[c]) b[c] = !(f[c] = e)
                    }) : function(b, a, c) {
                        f[0] = b;
                        l(f, null, c, e);
                        return !e.pop()
                    }
                }),
                has: a(function(b) {
                    return function(e) {
                        return 0 <
                            f(b, e).length
                    }
                }),
                contains: a(function(b) {
                    return function(f) {
                        return -1 < (f.textContent || f.innerText || B(f)).indexOf(b)
                    }
                }),
                lang: a(function(b) {
                    ma.test(b || "") || f.error("unsupported lang: " + b);
                    b = b.replace(ba, ta).toLowerCase();
                    return function(f) {
                        var e;
                        do
                            if (e = w ? f.lang : f.getAttribute("xml:lang") || f.getAttribute("lang")) return e = e.toLowerCase(), e === b || 0 === e.indexOf(b + "-"); while ((f = f.parentNode) && 1 === f.nodeType);
                        return !1
                    }
                }),
                target: function(f) {
                    var e = b.location && b.location.hash;
                    return e && e.slice(1) === f.id
                },
                root: function(b) {
                    return b ===
                        u
                },
                focus: function(b) {
                    return b === r.activeElement && (!r.hasFocus || r.hasFocus()) && !(!b.type && !b.href && !~b.tabIndex)
                },
                enabled: function(b) {
                    return !1 === b.disabled
                },
                disabled: function(b) {
                    return !0 === b.disabled
                },
                checked: function(b) {
                    var f = b.nodeName.toLowerCase();
                    return "input" === f && !!b.checked || "option" === f && !!b.selected
                },
                selected: function(b) {
                    b.parentNode && b.parentNode.selectedIndex;
                    return !0 === b.selected
                },
                empty: function(b) {
                    for (b = b.firstChild; b; b = b.nextSibling)
                        if (6 > b.nodeType) return !1;
                    return !0
                },
                parent: function(b) {
                    return !A.pseudos.empty(b)
                },
                header: function(b) {
                    return Ya.test(b.nodeName)
                },
                input: function(b) {
                    return Ca.test(b.nodeName)
                },
                button: function(b) {
                    var f = b.nodeName.toLowerCase();
                    return "input" === f && "button" === b.type || "button" === f
                },
                text: function(b) {
                    var f;
                    return "input" === b.nodeName.toLowerCase() && "text" === b.type && (null == (f = b.getAttribute("type")) || "text" === f.toLowerCase())
                },
                first: g(function() {
                    return [0]
                }),
                last: g(function(b, f) {
                    return [f - 1]
                }),
                eq: g(function(b, f, e) {
                    return [0 > e ? e + f : e]
                }),
                even: g(function(b, f) {
                    for (var e = 0; e < f; e += 2) b.push(e);
                    return b
                }),
                odd: g(function(b, f) {
                    for (var e = 1; e < f; e += 2) b.push(e);
                    return b
                }),
                lt: g(function(b, f, e) {
                    for (f = 0 > e ? e + f : e; 0 <= --f;) b.push(f);
                    return b
                }),
                gt: g(function(b, f, e) {
                    for (e = 0 > e ? e + f : e; ++e < f;) b.push(e);
                    return b
                })
            }
        };
        A.pseudos.nth = A.pseudos.eq;
        for (t in {
                radio: !0,
                checkbox: !0,
                file: !0,
                password: !0,
                image: !0
            }) A.pseudos[t] = h(t);
        for (t in {
                submit: !0,
                reset: !0
            }) A.pseudos[t] = m(t);
        n.prototype = A.filters = A.pseudos;
        A.setFilters = new n;
        V = f.tokenize = function(b, e) {
            var l, a, c, y, q, d, Q;
            if (q = Y[b + " "]) return e ? 0 : q.slice(0);
            q = b;
            d = [];
            for (Q = A.preFilter; q;) {
                if (!l ||
                    (a = Ga.exec(q))) a && (q = q.slice(a[0].length) || q), d.push(c = []);
                l = !1;
                if (a = Ha.exec(q)) l = a.shift(), c.push({
                    value: l,
                    type: a[0].replace(za, " ")
                }), q = q.slice(l.length);
                for (y in A.filter)
                    if ((a = aa[y].exec(q)) && (!Q[y] || (a = Q[y](a)))) l = a.shift(), c.push({
                        value: l,
                        type: y,
                        matches: a
                    }), q = q.slice(l.length);
                if (!l) break
            }
            return e ? q.length : q ? f.error(b) : Y(b, d).slice(0)
        };
        E = f.compile = function(b, f) {
            var e, l = [],
                a = [],
                c = H[b + " "];
            if (!c) {
                f || (f = V(b));
                for (e = f.length; e--;) c = O(f[e]), c[R] ? l.push(c) : a.push(c);
                c = H(b, M(a, l));
                c.selector = b
            }
            return c
        };
        T = f.select = function(b, f, e, l) {
            var a, c, y, q, d = "function" === typeof b && b,
                Q = !l && V(b = d.selector || b);
            e = e || [];
            if (1 === Q.length) {
                c = Q[0] = Q[0].slice(0);
                if (2 < c.length && "ID" === (y = c[0]).type && N.getById && 9 === f.nodeType && w && A.relative[c[1].type]) {
                    if (f = (A.find.ID(y.matches[0].replace(ba, ta), f) || [])[0]) d && (f = f.parentNode);
                    else return e;
                    b = b.slice(c.shift().value.length)
                }
                for (a = aa.needsContext.test(b) ? 0 : c.length; a--;) {
                    y = c[a];
                    if (A.relative[q = y.type]) break;
                    if (q = A.find[q])
                        if (l = q(y.matches[0].replace(ba, ta), la.test(c[0].type) &&
                                p(f.parentNode) || f)) {
                            c.splice(a, 1);
                            b = l.length && v(c);
                            if (!b) return Aa.apply(e, l), e;
                            break
                        }
                }
            }(d || E(b, Q))(l, f, !w, e, la.test(b) && p(f.parentNode) || f);
            return e
        };
        N.sortStable = R.split("").sort(qa).join("") === R;
        N.detectDuplicates = !!W;
        Z();
        N.sortDetached = c(function(b) {
            return b.compareDocumentPosition(r.createElement("div")) & 1
        });
        c(function(b) {
            b.innerHTML = "\x3ca href\x3d'#'\x3e\x3c/a\x3e";
            return "#" === b.firstChild.getAttribute("href")
        }) || q("type|href|height|width", function(b, f, e) {
            if (!e) return b.getAttribute(f, "type" ===
                f.toLowerCase() ? 1 : 2)
        });
        (!N.attributes || !c(function(b) {
            b.innerHTML = "\x3cinput/\x3e";
            b.firstChild.setAttribute("value", "");
            return "" === b.firstChild.getAttribute("value")
        })) && q("value", function(b, f, e) {
            if (!e && "input" === b.nodeName.toLowerCase()) return b.defaultValue
        });
        c(function(b) {
            return null == b.getAttribute("disabled")
        }) || q("checked|selected|async|autofocus|autoplay|controls|defer|disabled|hidden|ismap|loop|multiple|open|readonly|required|scoped", function(b, f, e) {
            var l;
            if (!e) return !0 === b[f] ? f.toLowerCase() :
                (l = b.getAttributeNode(f)) && l.specified ? l.value : null
        });
        return f
    }(a);
    e.find = la;
    e.expr = la.selectors;
    e.expr[":"] = e.expr.pseudos;
    e.unique = la.uniqueSort;
    e.text = la.getText;
    e.isXMLDoc = la.isXML;
    e.contains = la.contains;
    var ra = e.expr.match.needsContext,
        za = /^<(\w+)\s*\/?>(?:<\/\1>|)$/,
        ya = /^.[^:#\[\.,]*$/;
    e.filter = function(b, f, l) {
        var a = f[0];
        l && (b = ":not(" + b + ")");
        return 1 === f.length && 1 === a.nodeType ? e.find.matchesSelector(a, b) ? [a] : [] : e.find.matches(b, e.grep(f, function(b) {
            return 1 === b.nodeType
        }))
    };
    e.fn.extend({
        find: function(b) {
            var f,
                l = [],
                a = this,
                c = a.length;
            if ("string" !== typeof b) return this.pushStack(e(b).filter(function() {
                for (f = 0; f < c; f++)
                    if (e.contains(a[f], this)) return !0
            }));
            for (f = 0; f < c; f++) e.find(b, a[f], l);
            l = this.pushStack(1 < c ? e.unique(l) : l);
            l.selector = this.selector ? this.selector + " " + b : b;
            return l
        },
        filter: function(b) {
            return this.pushStack(c(this, b || [], !1))
        },
        not: function(b) {
            return this.pushStack(c(this, b || [], !0))
        },
        is: function(b) {
            return !!c(this, "string" === typeof b && ra.test(b) ? e(b) : b || [], !1).length
        }
    });
    var wa, L = a.document,
        Ia = /^(?:\s*(<[\w\W]+>)[^>]*|#([\w-]*))$/;
    (e.fn.init = function(b, f) {
        var l, a;
        if (!b) return this;
        if ("string" === typeof b) {
            if ((l = "\x3c" === b.charAt(0) && "\x3e" === b.charAt(b.length - 1) && 3 <= b.length ? [null, b, null] : Ia.exec(b)) && (l[1] || !f)) {
                if (l[1]) {
                    if (f = f instanceof e ? f[0] : f, e.merge(this, e.parseHTML(l[1], f && f.nodeType ? f.ownerDocument || f : L, !0)), za.test(l[1]) && e.isPlainObject(f))
                        for (l in f)
                            if (e.isFunction(this[l])) this[l](f[l]);
                            else this.attr(l, f[l])
                } else {
                    if ((a = L.getElementById(l[2])) && a.parentNode) {
                        if (a.id !== l[2]) return wa.find(b);
                        this.length = 1;
                        this[0] =
                            a
                    }
                    this.context = L;
                    this.selector = b
                }
                return this
            }
            return !f || f.jquery ? (f || wa).find(b) : this.constructor(f).find(b)
        }
        if (b.nodeType) return this.context = this[0] = b, this.length = 1, this;
        if (e.isFunction(b)) return "undefined" !== typeof wa.ready ? wa.ready(b) : b(e);
        void 0 !== b.selector && (this.selector = b.selector, this.context = b.context);
        return e.makeArray(b, this)
    }).prototype = e.fn;
    wa = e(L);
    var sa = /^(?:parents|prev(?:Until|All))/,
        xa = {
            children: !0,
            contents: !0,
            next: !0,
            prev: !0
        };
    e.extend({
        dir: function(b, f, l) {
            var a = [];
            for (b = b[f]; b &&
                9 !== b.nodeType && (void 0 === l || 1 !== b.nodeType || !e(b).is(l));) 1 === b.nodeType && a.push(b), b = b[f];
            return a
        },
        sibling: function(b, f) {
            for (var e = []; b; b = b.nextSibling) 1 === b.nodeType && b !== f && e.push(b);
            return e
        }
    });
    e.fn.extend({
        has: function(b) {
            var f, l = e(b, this),
                a = l.length;
            return this.filter(function() {
                for (f = 0; f < a; f++)
                    if (e.contains(this, l[f])) return !0
            })
        },
        closest: function(b, f) {
            for (var l, a = 0, c = this.length, q = [], d = ra.test(b) || "string" !== typeof b ? e(b, f || this.context) : 0; a < c; a++)
                for (l = this[a]; l && l !== f; l = l.parentNode)
                    if (11 >
                        l.nodeType && (d ? -1 < d.index(l) : 1 === l.nodeType && e.find.matchesSelector(l, b))) {
                        q.push(l);
                        break
                    }
            return this.pushStack(1 < q.length ? e.unique(q) : q)
        },
        index: function(b) {
            return !b ? this[0] && this[0].parentNode ? this.first().prevAll().length : -1 : "string" === typeof b ? e.inArray(this[0], e(b)) : e.inArray(b.jquery ? b[0] : b, this)
        },
        add: function(b, f) {
            return this.pushStack(e.unique(e.merge(this.get(), e(b, f))))
        },
        addBack: function(b) {
            return this.add(null == b ? this.prevObject : this.prevObject.filter(b))
        }
    });
    e.each({
        parent: function(b) {
            return (b =
                b.parentNode) && 11 !== b.nodeType ? b : null
        },
        parents: function(b) {
            return e.dir(b, "parentNode")
        },
        parentsUntil: function(b, f, l) {
            return e.dir(b, "parentNode", l)
        },
        next: function(b) {
            return g(b, "nextSibling")
        },
        prev: function(b) {
            return g(b, "previousSibling")
        },
        nextAll: function(b) {
            return e.dir(b, "nextSibling")
        },
        prevAll: function(b) {
            return e.dir(b, "previousSibling")
        },
        nextUntil: function(b, f, l) {
            return e.dir(b, "nextSibling", l)
        },
        prevUntil: function(b, f, l) {
            return e.dir(b, "previousSibling", l)
        },
        siblings: function(b) {
            return e.sibling((b.parentNode || {}).firstChild, b)
        },
        children: function(b) {
            return e.sibling(b.firstChild)
        },
        contents: function(b) {
            return e.nodeName(b, "iframe") ? b.contentDocument || b.contentWindow.document : e.merge([], b.childNodes)
        }
    }, function(b, f) {
        e.fn[b] = function(l, a) {
            var c = e.map(this, f, l);
            "Until" !== b.slice(-5) && (a = l);
            a && "string" === typeof a && (c = e.filter(a, c));
            1 < this.length && (xa[b] || (c = e.unique(c)), sa.test(b) && (c = c.reverse()));
            return this.pushStack(c)
        }
    });
    var ja = /\S+/g,
        Ua = {};
    e.Callbacks = function(b) {
        b = "string" === typeof b ? Ua[b] || k(b) : e.extend({},
            b);
        var f, l, a, c, q, d, h = [],
            m = !b.once && [],
            g = function(e) {
                l = b.memory && e;
                a = !0;
                q = d || 0;
                d = 0;
                c = h.length;
                for (f = !0; h && q < c; q++)
                    if (!1 === h[q].apply(e[0], e[1]) && b.stopOnFalse) {
                        l = !1;
                        break
                    }
                f = !1;
                h && (m ? m.length && g(m.shift()) : l ? h = [] : p.disable())
            },
            p = {
                add: function() {
                    if (h) {
                        var a = h.length;
                        (function Qb(f) {
                            e.each(f, function(f, l) {
                                var a = e.type(l);
                                "function" === a ? (!b.unique || !p.has(l)) && h.push(l) : l && (l.length && "string" !== a) && Qb(l)
                            })
                        })(arguments);
                        f ? c = h.length : l && (d = a, g(l))
                    }
                    return this
                },
                remove: function() {
                    h && e.each(arguments, function(b,
                        l) {
                        for (var a; - 1 < (a = e.inArray(l, h, a));) h.splice(a, 1), f && (a <= c && c--, a <= q && q--)
                    });
                    return this
                },
                has: function(b) {
                    return b ? -1 < e.inArray(b, h) : !(!h || !h.length)
                },
                empty: function() {
                    h = [];
                    c = 0;
                    return this
                },
                disable: function() {
                    h = m = l = void 0;
                    return this
                },
                disabled: function() {
                    return !h
                },
                lock: function() {
                    m = void 0;
                    l || p.disable();
                    return this
                },
                locked: function() {
                    return !m
                },
                fireWith: function(b, e) {
                    if (h && (!a || m)) e = e || [], e = [b, e.slice ? e.slice() : e], f ? m.push(e) : g(e);
                    return this
                },
                fire: function() {
                    p.fireWith(this, arguments);
                    return this
                },
                fired: function() {
                    return !!a
                }
            };
        return p
    };
    e.extend({
        Deferred: function(b) {
            var f = [
                    ["resolve", "done", e.Callbacks("once memory"), "resolved"],
                    ["reject", "fail", e.Callbacks("once memory"), "rejected"],
                    ["notify", "progress", e.Callbacks("memory")]
                ],
                l = "pending",
                a = {
                    state: function() {
                        return l
                    },
                    always: function() {
                        c.done(arguments).fail(arguments);
                        return this
                    },
                    then: function() {
                        var b = arguments;
                        return e.Deferred(function(l) {
                            e.each(f, function(f, d) {
                                var h = e.isFunction(b[f]) && b[f];
                                c[d[1]](function() {
                                    var b = h && h.apply(this, arguments);
                                    if (b && e.isFunction(b.promise)) b.promise().done(l.resolve).fail(l.reject).progress(l.notify);
                                    else l[d[0] + "With"](this === a ? l.promise() : this, h ? [b] : arguments)
                                })
                            });
                            b = null
                        }).promise()
                    },
                    promise: function(b) {
                        return null != b ? e.extend(b, a) : a
                    }
                },
                c = {};
            a.pipe = a.then;
            e.each(f, function(b, e) {
                var d = e[2],
                    h = e[3];
                a[e[1]] = d.add;
                h && d.add(function() {
                    l = h
                }, f[b ^ 1][2].disable, f[2][2].lock);
                c[e[0]] = function() {
                    c[e[0] + "With"](this === c ? a : this, arguments);
                    return this
                };
                c[e[0] + "With"] = d.fireWith
            });
            a.promise(c);
            b && b.call(c, c);
            return c
        },
        when: function(b) {
            var f = 0,
                l = P.call(arguments),
                a = l.length,
                c = 1 !== a || b && e.isFunction(b.promise) ? a : 0,
                q = 1 === c ? b : e.Deferred(),
                d = function(b, f, e) {
                    return function(l) {
                        f[b] = this;
                        e[b] = 1 < arguments.length ? P.call(arguments) : l;
                        e === h ? q.notifyWith(f, e) : --c || q.resolveWith(f, e)
                    }
                },
                h, m, g;
            if (1 < a) {
                h = Array(a);
                m = Array(a);
                for (g = Array(a); f < a; f++) l[f] && e.isFunction(l[f].promise) ? l[f].promise().done(d(f, g, l)).fail(q.reject).progress(d(f, m, h)) : --c
            }
            c || q.resolveWith(g, l);
            return q.promise()
        }
    });
    var Ja;
    e.fn.ready = function(b) {
        e.ready.promise().done(b);
        return this
    };
    e.extend({
        isReady: !1,
        readyWait: 1,
        holdReady: function(b) {
            b ? e.readyWait++ : e.ready(!0)
        },
        ready: function(b) {
            if (!(!0 === b ? --e.readyWait : e.isReady)) {
                if (!L.body) return setTimeout(e.ready);
                e.isReady = !0;
                !0 !== b && 0 < --e.readyWait || (Ja.resolveWith(L, [e]), e.fn.triggerHandler && (e(L).triggerHandler("ready"), e(L).off("ready")))
            }
        }
    });
    e.ready.promise = function(b) {
        if (!Ja)
            if (Ja = e.Deferred(), "complete" === L.readyState) setTimeout(e.ready);
            else if (L.addEventListener) L.addEventListener("DOMContentLoaded", n, !1), a.addEventListener("load",
            n, !1);
        else {
            L.attachEvent("onreadystatechange", n);
            a.attachEvent("onload", n);
            var f = !1;
            try {
                f = null == a.frameElement && L.documentElement
            } catch (l) {}
            f && f.doScroll && function Q() {
                if (!e.isReady) {
                    try {
                        f.doScroll("left")
                    } catch (b) {
                        return setTimeout(Q, 50)
                    }
                    d();
                    e.ready()
                }
            }()
        }
        return Ja.promise(b)
    };
    var H = "undefined",
        Za;
    for (Za in e(E)) break;
    E.ownLast = "0" !== Za;
    E.inlineBlockNeedsLayout = !1;
    e(function() {
        var b, f, e;
        if ((f = L.getElementsByTagName("body")[0]) && f.style) {
            b = L.createElement("div");
            e = L.createElement("div");
            e.style.cssText =
                "position:absolute;border:0;width:0;height:0;top:0;left:-9999px";
            f.appendChild(e).appendChild(b);
            if (typeof b.style.zoom !== H && (b.style.cssText = "display:inline;margin:0;border:0;padding:1px;width:1px;zoom:1", E.inlineBlockNeedsLayout = b = 3 === b.offsetWidth)) f.style.zoom = 1;
            f.removeChild(e)
        }
    });
    (function() {
        var b = L.createElement("div");
        if (null == E.deleteExpando) {
            E.deleteExpando = !0;
            try {
                delete b.test
            } catch (f) {
                E.deleteExpando = !1
            }
        }
    })();
    e.acceptData = function(b) {
        var f = e.noData[(b.nodeName + " ").toLowerCase()],
            l = +b.nodeType ||
            1;
        return 1 !== l && 9 !== l ? !1 : !f || !0 !== f && b.getAttribute("classid") === f
    };
    var ua = /^(?:\{[\w\W]*\}|\[[\w\W]*\])$/,
        fa = /([A-Z])/g;
    e.extend({
        cache: {},
        noData: {
            "applet ": !0,
            "embed ": !0,
            "object ": "clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"
        },
        hasData: function(b) {
            b = b.nodeType ? e.cache[b[e.expando]] : b[e.expando];
            return !!b && !C(b)
        },
        data: function(b, f, e) {
            return w(b, f, e)
        },
        removeData: function(b, f) {
            return x(b, f)
        },
        _data: function(b, f, e) {
            return w(b, f, e, !0)
        },
        _removeData: function(b, f) {
            return x(b, f, !0)
        }
    });
    e.fn.extend({
        data: function(b,
            f) {
            var l, a, c, q = this[0],
                d = q && q.attributes;
            if (void 0 === b) {
                if (this.length && (c = e.data(q), 1 === q.nodeType && !e._data(q, "parsedAttrs"))) {
                    for (l = d.length; l--;) d[l] && (a = d[l].name, 0 === a.indexOf("data-") && (a = e.camelCase(a.slice(5)), B(q, a, c[a])));
                    e._data(q, "parsedAttrs", !0)
                }
                return c
            }
            return "object" === typeof b ? this.each(function() {
                e.data(this, b)
            }) : 1 < arguments.length ? this.each(function() {
                e.data(this, b, f)
            }) : q ? B(q, b, e.data(q, b)) : void 0
        },
        removeData: function(b) {
            return this.each(function() {
                e.removeData(this, b)
            })
        }
    });
    e.extend({
        queue: function(b,
            f, l) {
            var a;
            if (b) return f = (f || "fx") + "queue", a = e._data(b, f), l && (!a || e.isArray(l) ? a = e._data(b, f, e.makeArray(l)) : a.push(l)), a || []
        },
        dequeue: function(b, f) {
            f = f || "fx";
            var l = e.queue(b, f),
                a = l.length,
                c = l.shift(),
                q = e._queueHooks(b, f),
                d = function() {
                    e.dequeue(b, f)
                };
            "inprogress" === c && (c = l.shift(), a--);
            c && ("fx" === f && l.unshift("inprogress"), delete q.stop, c.call(b, d, q));
            !a && q && q.empty.fire()
        },
        _queueHooks: function(b, f) {
            var l = f + "queueHooks";
            return e._data(b, l) || e._data(b, l, {
                empty: e.Callbacks("once memory").add(function() {
                    e._removeData(b,
                        f + "queue");
                    e._removeData(b, l)
                })
            })
        }
    });
    e.fn.extend({
        queue: function(b, f) {
            var l = 2;
            "string" !== typeof b && (f = b, b = "fx", l--);
            return arguments.length < l ? e.queue(this[0], b) : void 0 === f ? this : this.each(function() {
                var l = e.queue(this, b, f);
                e._queueHooks(this, b);
                "fx" === b && "inprogress" !== l[0] && e.dequeue(this, b)
            })
        },
        dequeue: function(b) {
            return this.each(function() {
                e.dequeue(this, b)
            })
        },
        clearQueue: function(b) {
            return this.queue(b || "fx", [])
        },
        promise: function(b, f) {
            var l, a = 1,
                c = e.Deferred(),
                q = this,
                d = this.length,
                h = function() {
                    --a ||
                        c.resolveWith(q, [q])
                };
            "string" !== typeof b && (f = b, b = void 0);
            for (b = b || "fx"; d--;)
                if ((l = e._data(q[d], b + "queueHooks")) && l.empty) a++, l.empty.add(h);
            h();
            return c.promise(f)
        }
    });
    var K = /[+-]?(?:\d*\.|)\d+(?:[eE][+-]?\d+|)/.source,
        va = ["Top", "Right", "Bottom", "Left"],
        pa = function(b, f) {
            b = f || b;
            return "none" === e.css(b, "display") || !e.contains(b.ownerDocument, b)
        },
        oa = e.access = function(b, f, l, a, c, q, d) {
            var h = 0,
                m = b.length,
                g = null == l;
            if ("object" === e.type(l))
                for (h in c = !0, l) e.access(b, f, h, l[h], !0, q, d);
            else if (void 0 !== a && (c = !0, e.isFunction(a) || (d = !0), g && (d ? (f.call(b, a), f = null) : (g = f, f = function(b, f, a) {
                    return g.call(e(b), a)
                })), f))
                for (; h < m; h++) f(b[h], l, d ? a : a.call(b[h], h, f(b[h], l)));
            return c ? b : g ? f.call(b) : m ? f(b[0], l) : q
        },
        Ea = /^(?:checkbox|radio)$/i;
    (function() {
        var b = L.createElement("input"),
            f = L.createElement("div"),
            e = L.createDocumentFragment();
        f.innerHTML = "  \x3clink/\x3e\x3ctable\x3e\x3c/table\x3e\x3ca href\x3d'/a'\x3ea\x3c/a\x3e\x3cinput type\x3d'checkbox'/\x3e";
        E.leadingWhitespace = 3 === f.firstChild.nodeType;
        E.tbody = !f.getElementsByTagName("tbody").length;
        E.htmlSerialize = !!f.getElementsByTagName("link").length;
        E.html5Clone = "\x3c:nav\x3e\x3c/:nav\x3e" !== L.createElement("nav").cloneNode(!0).outerHTML;
        b.type = "checkbox";
        b.checked = !0;
        e.appendChild(b);
        E.appendChecked = b.checked;
        f.innerHTML = "\x3ctextarea\x3ex\x3c/textarea\x3e";
        E.noCloneChecked = !!f.cloneNode(!0).lastChild.defaultValue;
        e.appendChild(f);
        f.innerHTML = "\x3cinput type\x3d'radio' checked\x3d'checked' name\x3d't'/\x3e";
        E.checkClone = f.cloneNode(!0).cloneNode(!0).lastChild.checked;
        E.noCloneEvent = !0;
        f.attachEvent && (f.attachEvent("onclick", function() {
            E.noCloneEvent = !1
        }), f.cloneNode(!0).click());
        if (null == E.deleteExpando) {
            E.deleteExpando = !0;
            try {
                delete f.test
            } catch (a) {
                E.deleteExpando = !1
            }
        }
    })();
    (function() {
        var b, f, e = L.createElement("div");
        for (b in {
                submit: !0,
                change: !0,
                focusin: !0
            })
            if (f = "on" + b, !(E[b + "Bubbles"] = f in a)) e.setAttribute(f, "t"), E[b + "Bubbles"] = !1 === e.attributes[f].expando
    })();
    var Qa = /^(?:input|select|textarea)$/i,
        Ka = /^key/,
        Da = /^(?:mouse|pointer|contextmenu)|click/,
        jb = /^(?:focusinfocus|focusoutblur)$/,
        db = /^([^.]*)(?:\.(.+)|)$/;
    e.event = {
        global: {},
        add: function(b, f, a, c, d) {
            var q, h, m, g, p, n, v, k, s;
            if (m = e._data(b)) {
                a.handler && (g = a, a = g.handler, d = g.selector);
                a.guid || (a.guid = e.guid++);
                if (!(h = m.events)) h = m.events = {};
                if (!(p = m.handle)) p = m.handle = function(b) {
                    return typeof e !== H && (!b || e.event.triggered !== b.type) ? e.event.dispatch.apply(p.elem, arguments) : void 0
                }, p.elem = b;
                f = (f || "").match(ja) || [""];
                for (m = f.length; m--;)
                    if (q = db.exec(f[m]) || [], k = n = q[1], s = (q[2] || "").split(".").sort(), k) {
                        q = e.event.special[k] || {};
                        k = (d ?
                            q.delegateType : q.bindType) || k;
                        q = e.event.special[k] || {};
                        n = e.extend({
                            type: k,
                            origType: n,
                            data: c,
                            handler: a,
                            guid: a.guid,
                            selector: d,
                            needsContext: d && e.expr.match.needsContext.test(d),
                            namespace: s.join(".")
                        }, g);
                        if (!(v = h[k]))
                            if (v = h[k] = [], v.delegateCount = 0, !q.setup || !1 === q.setup.call(b, c, s, p)) b.addEventListener ? b.addEventListener(k, p, !1) : b.attachEvent && b.attachEvent("on" + k, p);
                        q.add && (q.add.call(b, n), n.handler.guid || (n.handler.guid = a.guid));
                        d ? v.splice(v.delegateCount++, 0, n) : v.push(n);
                        e.event.global[k] = !0
                    }
                b = null
            }
        },
        remove: function(b, f, a, c, d) {
            var q, h, m, g, p, n, v, k, s, F, I, N = e.hasData(b) && e._data(b);
            if (N && (n = N.events)) {
                f = (f || "").match(ja) || [""];
                for (p = f.length; p--;)
                    if (m = db.exec(f[p]) || [], s = I = m[1], F = (m[2] || "").split(".").sort(), s) {
                        v = e.event.special[s] || {};
                        s = (c ? v.delegateType : v.bindType) || s;
                        k = n[s] || [];
                        m = m[2] && RegExp("(^|\\.)" + F.join("\\.(?:.*\\.|)") + "(\\.|$)");
                        for (g = q = k.length; q--;)
                            if (h = k[q], (d || I === h.origType) && (!a || a.guid === h.guid) && (!m || m.test(h.namespace)) && (!c || c === h.selector || "**" === c && h.selector)) k.splice(q, 1),
                                h.selector && k.delegateCount--, v.remove && v.remove.call(b, h);
                        g && !k.length && ((!v.teardown || !1 === v.teardown.call(b, F, N.handle)) && e.removeEvent(b, s, N.handle), delete n[s])
                    } else
                        for (s in n) e.event.remove(b, s + f[p], a, c, !0);
                e.isEmptyObject(n) && (delete N.handle, e._removeData(b, "events"))
            }
        },
        trigger: function(b, f, l, c) {
            var d, q, h, m, g, p, n = [l || L],
                v = da.call(b, "type") ? b.type : b;
            g = da.call(b, "namespace") ? b.namespace.split(".") : [];
            h = d = l = l || L;
            if (!(3 === l.nodeType || 8 === l.nodeType) && !jb.test(v + e.event.triggered))
                if (0 <= v.indexOf(".") &&
                    (g = v.split("."), v = g.shift(), g.sort()), q = 0 > v.indexOf(":") && "on" + v, b = b[e.expando] ? b : new e.Event(v, "object" === typeof b && b), b.isTrigger = c ? 2 : 3, b.namespace = g.join("."), b.namespace_re = b.namespace ? RegExp("(^|\\.)" + g.join("\\.(?:.*\\.|)") + "(\\.|$)") : null, b.result = void 0, b.target || (b.target = l), f = null == f ? [b] : e.makeArray(f, [b]), g = e.event.special[v] || {}, c || !(g.trigger && !1 === g.trigger.apply(l, f))) {
                    if (!c && !g.noBubble && !e.isWindow(l)) {
                        m = g.delegateType || v;
                        jb.test(m + v) || (h = h.parentNode);
                        for (; h; h = h.parentNode) n.push(h),
                            d = h;
                        if (d === (l.ownerDocument || L)) n.push(d.defaultView || d.parentWindow || a)
                    }
                    for (p = 0;
                        (h = n[p++]) && !b.isPropagationStopped();)
                        if (b.type = 1 < p ? m : g.bindType || v, (d = (e._data(h, "events") || {})[b.type] && e._data(h, "handle")) && d.apply(h, f), (d = q && h[q]) && d.apply && e.acceptData(h)) b.result = d.apply(h, f), !1 === b.result && b.preventDefault();
                    b.type = v;
                    if (!c && !b.isDefaultPrevented() && (!g._default || !1 === g._default.apply(n.pop(), f)) && e.acceptData(l) && q && l[v] && !e.isWindow(l)) {
                        (d = l[q]) && (l[q] = null);
                        e.event.triggered = v;
                        try {
                            l[v]()
                        } catch (k) {}
                        e.event.triggered =
                            void 0;
                        d && (l[q] = d)
                    }
                    return b.result
                }
        },
        dispatch: function(b) {
            b = e.event.fix(b);
            var f, a, c, d, q = [],
                h = P.call(arguments);
            f = (e._data(this, "events") || {})[b.type] || [];
            var m = e.event.special[b.type] || {};
            h[0] = b;
            b.delegateTarget = this;
            if (!(m.preDispatch && !1 === m.preDispatch.call(this, b))) {
                q = e.event.handlers.call(this, b, f);
                for (f = 0;
                    (c = q[f++]) && !b.isPropagationStopped();) {
                    b.currentTarget = c.elem;
                    for (d = 0;
                        (a = c.handlers[d++]) && !b.isImmediatePropagationStopped();)
                        if (!b.namespace_re || b.namespace_re.test(a.namespace))
                            if (b.handleObj =
                                a, b.data = a.data, a = ((e.event.special[a.origType] || {}).handle || a.handler).apply(c.elem, h), void 0 !== a && !1 === (b.result = a)) b.preventDefault(), b.stopPropagation()
                }
                m.postDispatch && m.postDispatch.call(this, b);
                return b.result
            }
        },
        handlers: function(b, f) {
            var a, c, d, q, h = [],
                m = f.delegateCount,
                g = b.target;
            if (m && g.nodeType && (!b.button || "click" !== b.type))
                for (; g != this; g = g.parentNode || this)
                    if (1 === g.nodeType && (!0 !== g.disabled || "click" !== b.type)) {
                        d = [];
                        for (q = 0; q < m; q++) c = f[q], a = c.selector + " ", void 0 === d[a] && (d[a] = c.needsContext ?
                            0 <= e(a, this).index(g) : e.find(a, this, null, [g]).length), d[a] && d.push(c);
                        d.length && h.push({
                            elem: g,
                            handlers: d
                        })
                    }
            m < f.length && h.push({
                elem: this,
                handlers: f.slice(m)
            });
            return h
        },
        fix: function(b) {
            if (b[e.expando]) return b;
            var f, a, c;
            f = b.type;
            var d = b,
                q = this.fixHooks[f];
            q || (this.fixHooks[f] = q = Da.test(f) ? this.mouseHooks : Ka.test(f) ? this.keyHooks : {});
            c = q.props ? this.props.concat(q.props) : this.props;
            b = new e.Event(d);
            for (f = c.length; f--;) a = c[f], b[a] = d[a];
            b.target || (b.target = d.srcElement || L);
            3 === b.target.nodeType && (b.target =
                b.target.parentNode);
            b.metaKey = !!b.metaKey;
            return q.filter ? q.filter(b, d) : b
        },
        props: "altKey bubbles cancelable ctrlKey currentTarget eventPhase metaKey relatedTarget shiftKey target timeStamp view which".split(" "),
        fixHooks: {},
        keyHooks: {
            props: ["char", "charCode", "key", "keyCode"],
            filter: function(b, f) {
                null == b.which && (b.which = null != f.charCode ? f.charCode : f.keyCode);
                return b
            }
        },
        mouseHooks: {
            props: "button buttons clientX clientY fromElement offsetX offsetY pageX pageY screenX screenY toElement".split(" "),
            filter: function(b,
                f) {
                var e, a, c = f.button,
                    d = f.fromElement;
                null == b.pageX && null != f.clientX && (e = b.target.ownerDocument || L, a = e.documentElement, e = e.body, b.pageX = f.clientX + (a && a.scrollLeft || e && e.scrollLeft || 0) - (a && a.clientLeft || e && e.clientLeft || 0), b.pageY = f.clientY + (a && a.scrollTop || e && e.scrollTop || 0) - (a && a.clientTop || e && e.clientTop || 0));
                !b.relatedTarget && d && (b.relatedTarget = d === b.target ? f.toElement : d);
                !b.which && void 0 !== c && (b.which = c & 1 ? 1 : c & 2 ? 3 : c & 4 ? 2 : 0);
                return b
            }
        },
        special: {
            load: {
                noBubble: !0
            },
            focus: {
                trigger: function() {
                    if (this !==
                        t() && this.focus) try {
                        return this.focus(), !1
                    } catch (b) {}
                },
                delegateType: "focusin"
            },
            blur: {
                trigger: function() {
                    if (this === t() && this.blur) return this.blur(), !1
                },
                delegateType: "focusout"
            },
            click: {
                trigger: function() {
                    if (e.nodeName(this, "input") && "checkbox" === this.type && this.click) return this.click(), !1
                },
                _default: function(b) {
                    return e.nodeName(b.target, "a")
                }
            },
            beforeunload: {
                postDispatch: function(b) {
                    void 0 !== b.result && b.originalEvent && (b.originalEvent.returnValue = b.result)
                }
            }
        },
        simulate: function(b, f, a, c) {
            b = e.extend(new e.Event,
                a, {
                    type: b,
                    isSimulated: !0,
                    originalEvent: {}
                });
            c ? e.event.trigger(b, null, f) : e.event.dispatch.call(f, b);
            b.isDefaultPrevented() && a.preventDefault()
        }
    };
    e.removeEvent = L.removeEventListener ? function(b, f, e) {
        b.removeEventListener && b.removeEventListener(f, e, !1)
    } : function(b, f, e) {
        f = "on" + f;
        b.detachEvent && (typeof b[f] === H && (b[f] = null), b.detachEvent(f, e))
    };
    e.Event = function(b, f) {
        if (!(this instanceof e.Event)) return new e.Event(b, f);
        b && b.type ? (this.originalEvent = b, this.type = b.type, this.isDefaultPrevented = b.defaultPrevented ||
            void 0 === b.defaultPrevented && !1 === b.returnValue ? z : D) : this.type = b;
        f && e.extend(this, f);
        this.timeStamp = b && b.timeStamp || e.now();
        this[e.expando] = !0
    };
    e.Event.prototype = {
        isDefaultPrevented: D,
        isPropagationStopped: D,
        isImmediatePropagationStopped: D,
        preventDefault: function() {
            var b = this.originalEvent;
            this.isDefaultPrevented = z;
            b && (b.preventDefault ? b.preventDefault() : b.returnValue = !1)
        },
        stopPropagation: function() {
            var b = this.originalEvent;
            this.isPropagationStopped = z;
            b && (b.stopPropagation && b.stopPropagation(), b.cancelBubble = !0)
        },
        stopImmediatePropagation: function() {
            var b = this.originalEvent;
            this.isImmediatePropagationStopped = z;
            b && b.stopImmediatePropagation && b.stopImmediatePropagation();
            this.stopPropagation()
        }
    };
    e.each({
        mouseenter: "mouseover",
        mouseleave: "mouseout",
        pointerenter: "pointerover",
        pointerleave: "pointerout"
    }, function(b, f) {
        e.event.special[b] = {
            delegateType: f,
            bindType: f,
            handle: function(b) {
                var a, c = b.relatedTarget,
                    d = b.handleObj;
                if (!c || c !== this && !e.contains(this, c)) b.type = d.origType, a = d.handler.apply(this, arguments),
                    b.type = f;
                return a
            }
        }
    });
    E.submitBubbles || (e.event.special.submit = {
        setup: function() {
            if (e.nodeName(this, "form")) return !1;
            e.event.add(this, "click._submit keypress._submit", function(b) {
                b = b.target;
                if ((b = e.nodeName(b, "input") || e.nodeName(b, "button") ? b.form : void 0) && !e._data(b, "submitBubbles")) e.event.add(b, "submit._submit", function(b) {
                    b._submit_bubble = !0
                }), e._data(b, "submitBubbles", !0)
            })
        },
        postDispatch: function(b) {
            b._submit_bubble && (delete b._submit_bubble, this.parentNode && !b.isTrigger && e.event.simulate("submit",
                this.parentNode, b, !0))
        },
        teardown: function() {
            if (e.nodeName(this, "form")) return !1;
            e.event.remove(this, "._submit")
        }
    });
    E.changeBubbles || (e.event.special.change = {
        setup: function() {
            if (Qa.test(this.nodeName)) {
                if ("checkbox" === this.type || "radio" === this.type) e.event.add(this, "propertychange._change", function(b) {
                    "checked" === b.originalEvent.propertyName && (this._just_changed = !0)
                }), e.event.add(this, "click._change", function(b) {
                    this._just_changed && !b.isTrigger && (this._just_changed = !1);
                    e.event.simulate("change", this,
                        b, !0)
                });
                return !1
            }
            e.event.add(this, "beforeactivate._change", function(b) {
                b = b.target;
                Qa.test(b.nodeName) && !e._data(b, "changeBubbles") && (e.event.add(b, "change._change", function(b) {
                    this.parentNode && (!b.isSimulated && !b.isTrigger) && e.event.simulate("change", this.parentNode, b, !0)
                }), e._data(b, "changeBubbles", !0))
            })
        },
        handle: function(b) {
            var f = b.target;
            if (this !== f || b.isSimulated || b.isTrigger || "radio" !== f.type && "checkbox" !== f.type) return b.handleObj.handler.apply(this, arguments)
        },
        teardown: function() {
            e.event.remove(this,
                "._change");
            return !Qa.test(this.nodeName)
        }
    });
    E.focusinBubbles || e.each({
        focus: "focusin",
        blur: "focusout"
    }, function(b, f) {
        var a = function(b) {
            e.event.simulate(f, b.target, e.event.fix(b), !0)
        };
        e.event.special[f] = {
            setup: function() {
                var c = this.ownerDocument || this,
                    d = e._data(c, f);
                d || c.addEventListener(b, a, !0);
                e._data(c, f, (d || 0) + 1)
            },
            teardown: function() {
                var c = this.ownerDocument || this,
                    d = e._data(c, f) - 1;
                d ? e._data(c, f, d) : (c.removeEventListener(b, a, !0), e._removeData(c, f))
            }
        }
    });
    e.fn.extend({
        on: function(b, f, a, c, d) {
            var q,
                h;
            if ("object" === typeof b) {
                "string" !== typeof f && (a = a || f, f = void 0);
                for (q in b) this.on(q, f, a, b[q], d);
                return this
            }
            null == a && null == c ? (c = f, a = f = void 0) : null == c && ("string" === typeof f ? (c = a, a = void 0) : (c = a, a = f, f = void 0));
            if (!1 === c) c = D;
            else if (!c) return this;
            1 === d && (h = c, c = function(b) {
                e().off(b);
                return h.apply(this, arguments)
            }, c.guid = h.guid || (h.guid = e.guid++));
            return this.each(function() {
                e.event.add(this, b, c, a, f)
            })
        },
        one: function(b, f, e, a) {
            return this.on(b, f, e, a, 1)
        },
        off: function(b, f, a) {
            var c;
            if (b && b.preventDefault &&
                b.handleObj) return c = b.handleObj, e(b.delegateTarget).off(c.namespace ? c.origType + "." + c.namespace : c.origType, c.selector, c.handler), this;
            if ("object" === typeof b) {
                for (c in b) this.off(c, f, b[c]);
                return this
            }
            if (!1 === f || "function" === typeof f) a = f, f = void 0;
            !1 === a && (a = D);
            return this.each(function() {
                e.event.remove(this, b, a, f)
            })
        },
        trigger: function(b, f) {
            return this.each(function() {
                e.event.trigger(b, f, this)
            })
        },
        triggerHandler: function(b, f) {
            var a = this[0];
            if (a) return e.event.trigger(b, f, a, !0)
        }
    });
    var ab = "abbr|article|aside|audio|bdi|canvas|data|datalist|details|figcaption|figure|footer|header|hgroup|mark|meter|nav|output|progress|section|summary|time|video",
        sb = / jQuery\d+="(?:null|\d+)"/g,
        eb = RegExp("\x3c(?:" + ab + ")[\\s/\x3e]", "i"),
        fb = /^\s+/,
        kb = /<(?!area|br|col|embed|hr|img|input|link|meta|param)(([\w:]+)[^>]*)\/>/gi,
        lb = /<([\w:]+)/,
        Z = /<tbody/i,
        Ra = /<|&#?\w+;/,
        La = /<(?:script|style|link)/i,
        Aa = /checked\s*(?:[^=]|=\s*.checked.)/i,
        mb = /^$|\/(?:java|ecma)script/i,
        gb = /^true\/(.*)/,
        tb = /^\s*<!(?:\[CDATA\[|--)|(?:\]\]|--)>\s*$/g,
        ia = {
            option: [1, "\x3cselect multiple\x3d'multiple'\x3e", "\x3c/select\x3e"],
            legend: [1, "\x3cfieldset\x3e", "\x3c/fieldset\x3e"],
            area: [1, "\x3cmap\x3e",
                "\x3c/map\x3e"
            ],
            param: [1, "\x3cobject\x3e", "\x3c/object\x3e"],
            thead: [1, "\x3ctable\x3e", "\x3c/table\x3e"],
            tr: [2, "\x3ctable\x3e\x3ctbody\x3e", "\x3c/tbody\x3e\x3c/table\x3e"],
            col: [2, "\x3ctable\x3e\x3ctbody\x3e\x3c/tbody\x3e\x3ccolgroup\x3e", "\x3c/colgroup\x3e\x3c/table\x3e"],
            td: [3, "\x3ctable\x3e\x3ctbody\x3e\x3ctr\x3e", "\x3c/tr\x3e\x3c/tbody\x3e\x3c/table\x3e"],
            _default: E.htmlSerialize ? [0, "", ""] : [1, "X\x3cdiv\x3e", "\x3c/div\x3e"]
        },
        ta = s(L).appendChild(L.createElement("div"));
    ia.optgroup = ia.option;
    ia.tbody =
        ia.tfoot = ia.colgroup = ia.caption = ia.thead;
    ia.th = ia.td;
    e.extend({
        clone: function(b, f, a) {
            var c, d, q, m, g, v = e.contains(b.ownerDocument, b);
            E.html5Clone || e.isXMLDoc(b) || !eb.test("\x3c" + b.nodeName + "\x3e") ? q = b.cloneNode(!0) : (ta.innerHTML = b.outerHTML, ta.removeChild(q = ta.firstChild));
            if ((!E.noCloneEvent || !E.noCloneChecked) && (1 === b.nodeType || 11 === b.nodeType) && !e.isXMLDoc(b)) {
                c = h(q);
                g = h(b);
                for (m = 0; null != (d = g[m]); ++m)
                    if (c[m]) {
                        var n = c[m],
                            k = void 0,
                            s = void 0,
                            F = void 0;
                        if (1 === n.nodeType) {
                            k = n.nodeName.toLowerCase();
                            if (!E.noCloneEvent &&
                                n[e.expando]) {
                                F = e._data(n);
                                for (s in F.events) e.removeEvent(n, s, F.handle);
                                n.removeAttribute(e.expando)
                            }
                            if ("script" === k && n.text !== d.text) p(n).text = d.text, A(n);
                            else if ("object" === k) n.parentNode && (n.outerHTML = d.outerHTML), E.html5Clone && (d.innerHTML && !e.trim(n.innerHTML)) && (n.innerHTML = d.innerHTML);
                            else if ("input" === k && Ea.test(d.type)) n.defaultChecked = n.checked = d.checked, n.value !== d.value && (n.value = d.value);
                            else if ("option" === k) n.defaultSelected = n.selected = d.defaultSelected;
                            else if ("input" === k || "textarea" ===
                                k) n.defaultValue = d.defaultValue
                        }
                    }
            }
            if (f)
                if (a) {
                    g = g || h(b);
                    c = c || h(q);
                    for (m = 0; null != (d = g[m]); m++) M(d, c[m])
                } else M(b, q);
            c = h(q, "script");
            0 < c.length && J(c, !v && h(b, "script"));
            return q
        },
        buildFragment: function(b, f, a, c) {
            for (var d, q, m, g, p, n, v = b.length, k = s(f), I = [], N = 0; N < v; N++)
                if ((q = b[N]) || 0 === q)
                    if ("object" === e.type(q)) e.merge(I, q.nodeType ? [q] : q);
                    else if (Ra.test(q)) {
                m = m || k.appendChild(f.createElement("div"));
                g = (lb.exec(q) || ["", ""])[1].toLowerCase();
                n = ia[g] || ia._default;
                m.innerHTML = n[1] + q.replace(kb, "\x3c$1\x3e\x3c/$2\x3e") +
                    n[2];
                for (d = n[0]; d--;) m = m.lastChild;
                !E.leadingWhitespace && fb.test(q) && I.push(f.createTextNode(fb.exec(q)[0]));
                if (!E.tbody)
                    for (d = (q = "table" === g && !Z.test(q) ? m.firstChild : "\x3ctable\x3e" === n[1] && !Z.test(q) ? m : 0) && q.childNodes.length; d--;) e.nodeName(p = q.childNodes[d], "tbody") && !p.childNodes.length && q.removeChild(p);
                e.merge(I, m.childNodes);
                for (m.textContent = ""; m.firstChild;) m.removeChild(m.firstChild);
                m = k.lastChild
            } else I.push(f.createTextNode(q));
            m && k.removeChild(m);
            E.appendChecked || e.grep(h(I, "input"),
                F);
            for (N = 0; q = I[N++];)
                if (!(c && -1 !== e.inArray(q, c)) && (b = e.contains(q.ownerDocument, q), m = h(k.appendChild(q), "script"), b && J(m), a))
                    for (d = 0; q = m[d++];) mb.test(q.type || "") && a.push(q);
            return k
        },
        cleanData: function(b, f) {
            for (var a, c, d, q, h = 0, m = e.expando, g = e.cache, p = E.deleteExpando, n = e.event.special; null != (a = b[h]); h++)
                if (f || e.acceptData(a))
                    if (q = (d = a[m]) && g[d]) {
                        if (q.events)
                            for (c in q.events) n[c] ? e.event.remove(a, c) : e.removeEvent(a, c, q.handle);
                        g[d] && (delete g[d], p ? delete a[m] : typeof a.removeAttribute !== H ? a.removeAttribute(m) :
                            a[m] = null, aa.push(d))
                    }
        }
    });
    e.fn.extend({
        text: function(b) {
            return oa(this, function(b) {
                return void 0 === b ? e.text(this) : this.empty().append((this[0] && this[0].ownerDocument || L).createTextNode(b))
            }, null, b, arguments.length)
        },
        append: function() {
            return this.domManip(arguments, function(b) {
                (1 === this.nodeType || 11 === this.nodeType || 9 === this.nodeType) && I(this, b).appendChild(b)
            })
        },
        prepend: function() {
            return this.domManip(arguments, function(b) {
                if (1 === this.nodeType || 11 === this.nodeType || 9 === this.nodeType) {
                    var f = I(this,
                        b);
                    f.insertBefore(b, f.firstChild)
                }
            })
        },
        before: function() {
            return this.domManip(arguments, function(b) {
                this.parentNode && this.parentNode.insertBefore(b, this)
            })
        },
        after: function() {
            return this.domManip(arguments, function(b) {
                this.parentNode && this.parentNode.insertBefore(b, this.nextSibling)
            })
        },
        remove: function(b, f) {
            for (var a, c = b ? e.filter(b, this) : this, d = 0; null != (a = c[d]); d++) !f && 1 === a.nodeType && e.cleanData(h(a)), a.parentNode && (f && e.contains(a.ownerDocument, a) && J(h(a, "script")), a.parentNode.removeChild(a));
            return this
        },
        empty: function() {
            for (var b, f = 0; null != (b = this[f]); f++) {
                for (1 === b.nodeType && e.cleanData(h(b, !1)); b.firstChild;) b.removeChild(b.firstChild);
                b.options && e.nodeName(b, "select") && (b.options.length = 0)
            }
            return this
        },
        clone: function(b, f) {
            b = null == b ? !1 : b;
            f = null == f ? b : f;
            return this.map(function() {
                return e.clone(this, b, f)
            })
        },
        html: function(b) {
            return oa(this, function(b) {
                var a = this[0] || {},
                    c = 0,
                    d = this.length;
                if (void 0 === b) return 1 === a.nodeType ? a.innerHTML.replace(sb, "") : void 0;
                if ("string" === typeof b && !La.test(b) && (E.htmlSerialize ||
                        !eb.test(b)) && (E.leadingWhitespace || !fb.test(b)) && !ia[(lb.exec(b) || ["", ""])[1].toLowerCase()]) {
                    b = b.replace(kb, "\x3c$1\x3e\x3c/$2\x3e");
                    try {
                        for (; c < d; c++) a = this[c] || {}, 1 === a.nodeType && (e.cleanData(h(a, !1)), a.innerHTML = b);
                        a = 0
                    } catch (q) {}
                }
                a && this.empty().append(b)
            }, null, b, arguments.length)
        },
        replaceWith: function() {
            var b = arguments[0];
            this.domManip(arguments, function(f) {
                b = this.parentNode;
                e.cleanData(h(this));
                b && b.replaceChild(f, this)
            });
            return b && (b.length || b.nodeType) ? this : this.remove()
        },
        detach: function(b) {
            return this.remove(b, !0)
        },
        domManip: function(b, f) {
            b = ma.apply([], b);
            var a, c, d, q, m = 0,
                g = this.length,
                n = this,
                v = g - 1,
                k = b[0],
                s = e.isFunction(k);
            if (s || 1 < g && "string" === typeof k && !E.checkClone && Aa.test(k)) return this.each(function(e) {
                var a = n.eq(e);
                s && (b[0] = k.call(this, e, a.html()));
                a.domManip(b, f)
            });
            if (g && (q = e.buildFragment(b, this[0].ownerDocument, !1, this), a = q.firstChild, 1 === q.childNodes.length && (q = a), a)) {
                d = e.map(h(q, "script"), p);
                for (c = d.length; m < g; m++) a = q, m !== v && (a = e.clone(a, !0, !0), c && e.merge(d, h(a, "script"))), f.call(this[m], a, m);
                if (c) {
                    q = d[d.length - 1].ownerDocument;
                    e.map(d, A);
                    for (m = 0; m < c; m++)
                        if (a = d[m], mb.test(a.type || "") && !e._data(a, "globalEval") && e.contains(q, a)) a.src ? e._evalUrl && e._evalUrl(a.src) : e.globalEval((a.text || a.textContent || a.innerHTML || "").replace(tb, ""))
                }
                q = a = null
            }
            return this
        }
    });
    e.each({
        appendTo: "append",
        prependTo: "prepend",
        insertBefore: "before",
        insertAfter: "after",
        replaceAll: "replaceWith"
    }, function(b, f) {
        e.fn[b] = function(b) {
            for (var a = 0, c = [], d = e(b), h = d.length - 1; a <= h; a++) b = a === h ? this : this.clone(!0), e(d[a])[f](b),
                ga.apply(c, b.get());
            return this.pushStack(c)
        }
    });
    var bb, Ab = {};
    (function() {
        var b;
        E.shrinkWrapBlocks = function() {
            if (null != b) return b;
            b = !1;
            var f, e, a;
            if ((e = L.getElementsByTagName("body")[0]) && e.style) return f = L.createElement("div"), a = L.createElement("div"), a.style.cssText = "position:absolute;border:0;width:0;height:0;top:0;left:-9999px", e.appendChild(a).appendChild(f), typeof f.style.zoom !== H && (f.style.cssText = "-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;display:block;margin:0;border:0;padding:1px;width:1px;zoom:1",
                f.appendChild(L.createElement("div")).style.width = "5px", b = 3 !== f.offsetWidth), e.removeChild(a), b
        }
    })();
    var Cb = /^margin/,
        hb = RegExp("^(" + K + ")(?!px)[a-z%]+$", "i"),
        Fa, Oa, Rb = /^(top|right|bottom|left)$/;
    a.getComputedStyle ? (Fa = function(b) {
        return b.ownerDocument.defaultView.getComputedStyle(b, null)
    }, Oa = function(b, f, a) {
        var c, d, q = b.style;
        d = (a = a || Fa(b)) ? a.getPropertyValue(f) || a[f] : void 0;
        a && ("" === d && !e.contains(b.ownerDocument, b) && (d = e.style(b, f)), hb.test(d) && Cb.test(f) && (b = q.width, f = q.minWidth, c = q.maxWidth, q.minWidth =
            q.maxWidth = q.width = d, d = a.width, q.width = b, q.minWidth = f, q.maxWidth = c));
        return void 0 === d ? d : d + ""
    }) : L.documentElement.currentStyle && (Fa = function(b) {
        return b.currentStyle
    }, Oa = function(b, f, e) {
        var a, c, d, h = b.style;
        d = (e = e || Fa(b)) ? e[f] : void 0;
        null == d && (h && h[f]) && (d = h[f]);
        if (hb.test(d) && !Rb.test(f)) {
            e = h.left;
            if (c = (a = b.runtimeStyle) && a.left) a.left = b.currentStyle.left;
            h.left = "fontSize" === f ? "1em" : d;
            d = h.pixelLeft + "px";
            h.left = e;
            c && (a.left = c)
        }
        return void 0 === d ? d : d + "" || "auto"
    });
    (function() {
        function b() {
            var b, f, e, c;
            if ((f = L.getElementsByTagName("body")[0]) && f.style) {
                b = L.createElement("div");
                e = L.createElement("div");
                e.style.cssText = "position:absolute;border:0;width:0;height:0;top:0;left:-9999px";
                f.appendChild(e).appendChild(b);
                b.style.cssText = "-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box;display:block;margin-top:1%;top:1%;border:1px;padding:1px;width:4px;position:absolute";
                d = h = !1;
                m = !0;
                a.getComputedStyle && (d = "1%" !== (a.getComputedStyle(b, null) || {}).top, h = "4px" === (a.getComputedStyle(b,
                    null) || {
                    width: "4px"
                }).width, c = b.appendChild(L.createElement("div")), c.style.cssText = b.style.cssText = "-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;display:block;margin:0;border:0;padding:0", c.style.marginRight = c.style.width = "0", b.style.width = "1px", m = !parseFloat((a.getComputedStyle(c, null) || {}).marginRight));
                b.innerHTML = "\x3ctable\x3e\x3ctr\x3e\x3ctd\x3e\x3c/td\x3e\x3ctd\x3et\x3c/td\x3e\x3c/tr\x3e\x3c/table\x3e";
                c = b.getElementsByTagName("td");
                c[0].style.cssText =
                    "margin:0;border:0;padding:0;display:none";
                if (q = 0 === c[0].offsetHeight) c[0].style.display = "", c[1].style.display = "none", q = 0 === c[0].offsetHeight;
                f.removeChild(e)
            }
        }
        var f, c, d, h, q, m;
        f = L.createElement("div");
        f.innerHTML = "  \x3clink/\x3e\x3ctable\x3e\x3c/table\x3e\x3ca href\x3d'/a'\x3ea\x3c/a\x3e\x3cinput type\x3d'checkbox'/\x3e";
        if (c = (c = f.getElementsByTagName("a")[0]) && c.style) c.cssText = "float:left;opacity:.5", E.opacity = "0.5" === c.opacity, E.cssFloat = !!c.cssFloat, f.style.backgroundClip = "content-box", f.cloneNode(!0).style.backgroundClip =
            "", E.clearCloneStyle = "content-box" === f.style.backgroundClip, E.boxSizing = "" === c.boxSizing || "" === c.MozBoxSizing || "" === c.WebkitBoxSizing, e.extend(E, {
                reliableHiddenOffsets: function() {
                    null == q && b();
                    return q
                },
                boxSizingReliable: function() {
                    null == h && b();
                    return h
                },
                pixelPosition: function() {
                    null == d && b();
                    return d
                },
                reliableMarginRight: function() {
                    null == m && b();
                    return m
                }
            })
    })();
    e.swap = function(b, f, e, a) {
        var c, d = {};
        for (c in f) d[c] = b.style[c], b.style[c] = f[c];
        e = e.apply(b, a || []);
        for (c in f) b.style[c] = d[c];
        return e
    };
    var ub =
        /alpha\([^)]*\)/i,
        Sb = /opacity\s*=\s*([^)]*)/,
        Tb = /^(none|table(?!-c[ea]).+)/,
        Ob = RegExp("^(" + K + ")(.*)$", "i"),
        Ub = RegExp("^([+-])\x3d(" + K + ")", "i"),
        Vb = {
            position: "absolute",
            visibility: "hidden",
            display: "block"
        },
        Db = {
            letterSpacing: "0",
            fontWeight: "400"
        },
        Bb = ["Webkit", "O", "Moz", "ms"];
    e.extend({
        cssHooks: {
            opacity: {
                get: function(b, f) {
                    if (f) {
                        var e = Oa(b, "opacity");
                        return "" === e ? "1" : e
                    }
                }
            }
        },
        cssNumber: {
            columnCount: !0,
            fillOpacity: !0,
            flexGrow: !0,
            flexShrink: !0,
            fontWeight: !0,
            lineHeight: !0,
            opacity: !0,
            order: !0,
            orphans: !0,
            widows: !0,
            zIndex: !0,
            zoom: !0
        },
        cssProps: {
            "float": E.cssFloat ? "cssFloat" : "styleFloat"
        },
        style: function(b, f, a, c) {
            if (b && !(3 === b.nodeType || 8 === b.nodeType || !b.style)) {
                var d, h, m, g = e.camelCase(f),
                    n = b.style;
                f = e.cssProps[g] || (e.cssProps[g] = v(n, g));
                m = e.cssHooks[f] || e.cssHooks[g];
                if (void 0 !== a) {
                    h = typeof a;
                    if ("string" === h && (d = Ub.exec(a))) a = (d[1] + 1) * d[2] + parseFloat(e.css(b, f)), h = "number";
                    if (!(null == a || a !== a))
                        if ("number" === h && !e.cssNumber[g] && (a += "px"), !E.clearCloneStyle && ("" === a && 0 === f.indexOf("background")) && (n[f] = "inherit"), !m || !("set" in m) || void 0 !== (a = m.set(b, a, c))) try {
                            n[f] = a
                        } catch (p) {}
                } else return m && "get" in m && void 0 !== (d = m.get(b, !1, c)) ? d : n[f]
            }
        },
        css: function(b, f, a, c) {
            var d, h;
            h = e.camelCase(f);
            f = e.cssProps[h] || (e.cssProps[h] = v(b.style, h));
            (h = e.cssHooks[f] || e.cssHooks[h]) && "get" in h && (d = h.get(b, !0, a));
            void 0 === d && (d = Oa(b, f, c));
            "normal" === d && f in Db && (d = Db[f]);
            return "" === a || a ? (b = parseFloat(d), !0 === a || e.isNumeric(b) ? b || 0 : d) : d
        }
    });
    e.each(["height", "width"], function(b, f) {
        e.cssHooks[f] = {
            get: function(b, a, c) {
                if (a) return Tb.test(e.css(b,
                    "display")) && 0 === b.offsetWidth ? e.swap(b, Vb, function() {
                    return qa(b, f, c)
                }) : qa(b, f, c)
            },
            set: function(b, a, c) {
                var d = c && Fa(b);
                return G(b, a, c ? ha(b, f, c, E.boxSizing && "border-box" === e.css(b, "boxSizing", !1, d), d) : 0)
            }
        }
    });
    E.opacity || (e.cssHooks.opacity = {
        get: function(b, f) {
            return Sb.test((f && b.currentStyle ? b.currentStyle.filter : b.style.filter) || "") ? 0.01 * parseFloat(RegExp.$1) + "" : f ? "1" : ""
        },
        set: function(b, f) {
            var a = b.style,
                c = b.currentStyle,
                d = e.isNumeric(f) ? "alpha(opacity\x3d" + 100 * f + ")" : "",
                h = c && c.filter || a.filter || "";
            a.zoom = 1;
            if ((1 <= f || "" === f) && "" === e.trim(h.replace(ub, "")) && a.removeAttribute)
                if (a.removeAttribute("filter"), "" === f || c && !c.filter) return;
            a.filter = ub.test(h) ? h.replace(ub, d) : h + " " + d
        }
    });
    e.cssHooks.marginRight = m(E.reliableMarginRight, function(b, f) {
        if (f) return e.swap(b, {
            display: "inline-block"
        }, Oa, [b, "marginRight"])
    });
    e.each({
        margin: "",
        padding: "",
        border: "Width"
    }, function(b, f) {
        e.cssHooks[b + f] = {
            expand: function(e) {
                var a = 0,
                    c = {};
                for (e = "string" === typeof e ? e.split(" ") : [e]; 4 > a; a++) c[b + va[a] + f] = e[a] || e[a - 2] || e[0];
                return c
            }
        };
        Cb.test(b) || (e.cssHooks[b + f].set = G)
    });
    e.fn.extend({
        css: function(b, f) {
            return oa(this, function(b, f, a) {
                var c, d = {},
                    h = 0;
                if (e.isArray(f)) {
                    a = Fa(b);
                    for (c = f.length; h < c; h++) d[f[h]] = e.css(b, f[h], !1, a);
                    return d
                }
                return void 0 !== a ? e.style(b, f, a) : e.css(b, f)
            }, b, f, 1 < arguments.length)
        },
        show: function() {
            return N(this, !0)
        },
        hide: function() {
            return N(this)
        },
        toggle: function(b) {
            return "boolean" === typeof b ? b ? this.show() : this.hide() : this.each(function() {
                pa(this) ? e(this).show() : e(this).hide()
            })
        }
    });
    e.Tween = R;
    R.prototype = {
        constructor: R,
        init: function(b, f, a, c, d, h) {
            this.elem = b;
            this.prop = a;
            this.easing = d || "swing";
            this.options = f;
            this.start = this.now = this.cur();
            this.end = c;
            this.unit = h || (e.cssNumber[a] ? "" : "px")
        },
        cur: function() {
            var b = R.propHooks[this.prop];
            return b && b.get ? b.get(this) : R.propHooks._default.get(this)
        },
        run: function(b) {
            var f, a = R.propHooks[this.prop];
            this.pos = this.options.duration ? f = e.easing[this.easing](b, this.options.duration * b, 0, 1, this.options.duration) : f = b;
            this.now = (this.end - this.start) * f + this.start;
            this.options.step &&
                this.options.step.call(this.elem, this.now, this);
            a && a.set ? a.set(this) : R.propHooks._default.set(this);
            return this
        }
    };
    R.prototype.init.prototype = R.prototype;
    R.propHooks = {
        _default: {
            get: function(b) {
                if (null != b.elem[b.prop] && (!b.elem.style || null == b.elem.style[b.prop])) return b.elem[b.prop];
                b = e.css(b.elem, b.prop, "");
                return !b || "auto" === b ? 0 : b
            },
            set: function(b) {
                if (e.fx.step[b.prop]) e.fx.step[b.prop](b);
                else b.elem.style && (null != b.elem.style[e.cssProps[b.prop]] || e.cssHooks[b.prop]) ? e.style(b.elem, b.prop, b.now +
                    b.unit) : b.elem[b.prop] = b.now
            }
        }
    };
    R.propHooks.scrollTop = R.propHooks.scrollLeft = {
        set: function(b) {
            b.elem.nodeType && b.elem.parentNode && (b.elem[b.prop] = b.now)
        }
    };
    e.easing = {
        linear: function(b) {
            return b
        },
        swing: function(b) {
            return 0.5 - Math.cos(b * Math.PI) / 2
        }
    };
    e.fx = R.prototype.init;
    e.fx.step = {};
    var Va, nb, Wb = /^(?:toggle|show|hide)$/,
        Eb = RegExp("^(?:([+-])\x3d|)(" + K + ")([a-z%]*)$", "i"),
        Xb = /queueHooks$/,
        ib = [function(b, f, a) {
            var c, d, h, m, g, n, p = this,
                v = {},
                k = b.style,
                s = b.nodeType && pa(b),
                F = e._data(b, "fxshow");
            a.queue || (m = e._queueHooks(b,
                "fx"), null == m.unqueued && (m.unqueued = 0, g = m.empty.fire, m.empty.fire = function() {
                m.unqueued || g()
            }), m.unqueued++, p.always(function() {
                p.always(function() {
                    m.unqueued--;
                    e.queue(b, "fx").length || m.empty.fire()
                })
            }));
            if (1 === b.nodeType && ("height" in f || "width" in f)) a.overflow = [k.overflow, k.overflowX, k.overflowY], n = e.css(b, "display"), d = "none" === n ? e._data(b, "olddisplay") || V(b.nodeName) : n, "inline" === d && "none" === e.css(b, "float") && (!E.inlineBlockNeedsLayout || "inline" === V(b.nodeName) ? k.display = "inline-block" : k.zoom =
                1);
            a.overflow && (k.overflow = "hidden", E.shrinkWrapBlocks() || p.always(function() {
                k.overflow = a.overflow[0];
                k.overflowX = a.overflow[1];
                k.overflowY = a.overflow[2]
            }));
            for (c in f)
                if (d = f[c], Wb.exec(d)) {
                    delete f[c];
                    h = h || "toggle" === d;
                    if (d === (s ? "hide" : "show"))
                        if ("show" === d && F && void 0 !== F[c]) s = !0;
                        else continue;
                    v[c] = F && F[c] || e.style(b, c)
                } else n = void 0;
            if (e.isEmptyObject(v)) {
                if ("inline" === ("none" === n ? V(b.nodeName) : n)) k.display = n
            } else
                for (c in F ? "hidden" in F && (s = F.hidden) : F = e._data(b, "fxshow", {}), h && (F.hidden = !s),
                    s ? e(b).show() : p.done(function() {
                        e(b).hide()
                    }), p.done(function() {
                        var f;
                        e._removeData(b, "fxshow");
                        for (f in v) e.style(b, f, v[f])
                    }), v) f = X(s ? F[c] : 0, c, p), c in F || (F[c] = f.start, s && (f.end = f.start, f.start = "width" === c || "height" === c ? 1 : 0))
        }],
        cb = {
            "*": [function(b, f) {
                var a = this.createTween(b, f),
                    c = a.cur(),
                    d = Eb.exec(f),
                    h = d && d[3] || (e.cssNumber[b] ? "" : "px"),
                    m = (e.cssNumber[b] || "px" !== h && +c) && Eb.exec(e.css(a.elem, b)),
                    g = 1,
                    n = 20;
                if (m && m[3] !== h) {
                    h = h || m[3];
                    d = d || [];
                    m = +c || 1;
                    do g = g || ".5", m /= g, e.style(a.elem, b, m + h); while (g !== (g =
                            a.cur() / c) && 1 !== g && --n)
                }
                d && (m = a.start = +m || +c || 0, a.unit = h, a.end = d[1] ? m + (d[1] + 1) * d[2] : +d[2]);
                return a
            }]
        };
    e.Animation = e.extend(Y, {
        tweener: function(b, f) {
            e.isFunction(b) ? (f = b, b = ["*"]) : b = b.split(" ");
            for (var a, c = 0, d = b.length; c < d; c++) a = b[c], cb[a] = cb[a] || [], cb[a].unshift(f)
        },
        prefilter: function(b, f) {
            f ? ib.unshift(b) : ib.push(b)
        }
    });
    e.speed = function(b, f, a) {
        var c = b && "object" === typeof b ? e.extend({}, b) : {
            complete: a || !a && f || e.isFunction(b) && b,
            duration: b,
            easing: a && f || f && !e.isFunction(f) && f
        };
        c.duration = e.fx.off ? 0 : "number" ===
            typeof c.duration ? c.duration : c.duration in e.fx.speeds ? e.fx.speeds[c.duration] : e.fx.speeds._default;
        if (null == c.queue || !0 === c.queue) c.queue = "fx";
        c.old = c.complete;
        c.complete = function() {
            e.isFunction(c.old) && c.old.call(this);
            c.queue && e.dequeue(this, c.queue)
        };
        return c
    };
    e.fn.extend({
        fadeTo: function(b, f, e, a) {
            return this.filter(pa).css("opacity", 0).show().end().animate({
                opacity: f
            }, b, e, a)
        },
        animate: function(b, f, a, c) {
            var d = e.isEmptyObject(b),
                h = e.speed(f, a, c);
            f = function() {
                var f = Y(this, e.extend({}, b), h);
                (d || e._data(this,
                    "finish")) && f.stop(!0)
            };
            f.finish = f;
            return d || !1 === h.queue ? this.each(f) : this.queue(h.queue, f)
        },
        stop: function(b, f, a) {
            var c = function(b) {
                var f = b.stop;
                delete b.stop;
                f(a)
            };
            "string" !== typeof b && (a = f, f = b, b = void 0);
            f && !1 !== b && this.queue(b || "fx", []);
            return this.each(function() {
                var f = !0,
                    d = null != b && b + "queueHooks",
                    h = e.timers,
                    m = e._data(this);
                if (d) m[d] && m[d].stop && c(m[d]);
                else
                    for (d in m) m[d] && (m[d].stop && Xb.test(d)) && c(m[d]);
                for (d = h.length; d--;)
                    if (h[d].elem === this && (null == b || h[d].queue === b)) h[d].anim.stop(a), f = !1, h.splice(d, 1);
                (f || !a) && e.dequeue(this, b)
            })
        },
        finish: function(b) {
            !1 !== b && (b = b || "fx");
            return this.each(function() {
                var f, a = e._data(this),
                    c = a[b + "queue"];
                f = a[b + "queueHooks"];
                var d = e.timers,
                    h = c ? c.length : 0;
                a.finish = !0;
                e.queue(this, b, []);
                f && f.stop && f.stop.call(this, !0);
                for (f = d.length; f--;) d[f].elem === this && d[f].queue === b && (d[f].anim.stop(!0), d.splice(f, 1));
                for (f = 0; f < h; f++) c[f] && c[f].finish && c[f].finish.call(this);
                delete a.finish
            })
        }
    });
    e.each(["toggle", "show", "hide"], function(b, f) {
        var a = e.fn[f];
        e.fn[f] = function(b,
            e, c) {
            return null == b || "boolean" === typeof b ? a.apply(this, arguments) : this.animate(T(f, !0), b, e, c)
        }
    });
    e.each({
        slideDown: T("show"),
        slideUp: T("hide"),
        slideToggle: T("toggle"),
        fadeIn: {
            opacity: "show"
        },
        fadeOut: {
            opacity: "hide"
        },
        fadeToggle: {
            opacity: "toggle"
        }
    }, function(b, f) {
        e.fn[b] = function(b, e, a) {
            return this.animate(f, b, e, a)
        }
    });
    e.timers = [];
    e.fx.tick = function() {
        var b, f = e.timers,
            a = 0;
        for (Va = e.now(); a < f.length; a++) b = f[a], !b() && f[a] === b && f.splice(a--, 1);
        f.length || e.fx.stop();
        Va = void 0
    };
    e.fx.timer = function(b) {
        e.timers.push(b);
        b() ? e.fx.start() : e.timers.pop()
    };
    e.fx.interval = 13;
    e.fx.start = function() {
        nb || (nb = setInterval(e.fx.tick, e.fx.interval))
    };
    e.fx.stop = function() {
        clearInterval(nb);
        nb = null
    };
    e.fx.speeds = {
        slow: 600,
        fast: 200,
        _default: 400
    };
    e.fn.delay = function(b, f) {
        b = e.fx ? e.fx.speeds[b] || b : b;
        return this.queue(f || "fx", function(f, e) {
            var a = setTimeout(f, b);
            e.stop = function() {
                clearTimeout(a)
            }
        })
    };
    (function() {
        var b, f, e, a, c;
        f = L.createElement("div");
        f.setAttribute("className", "t");
        f.innerHTML = "  \x3clink/\x3e\x3ctable\x3e\x3c/table\x3e\x3ca href\x3d'/a'\x3ea\x3c/a\x3e\x3cinput type\x3d'checkbox'/\x3e";
        a = f.getElementsByTagName("a")[0];
        e = L.createElement("select");
        c = e.appendChild(L.createElement("option"));
        b = f.getElementsByTagName("input")[0];
        a.style.cssText = "top:1px";
        E.getSetAttribute = "t" !== f.className;
        E.style = /top/.test(a.getAttribute("style"));
        E.hrefNormalized = "/a" === a.getAttribute("href");
        E.checkOn = !!b.value;
        E.optSelected = c.selected;
        E.enctype = !!L.createElement("form").enctype;
        e.disabled = !0;
        E.optDisabled = !c.disabled;
        b = L.createElement("input");
        b.setAttribute("value", "");
        E.input = "" === b.getAttribute("value");
        b.value = "t";
        b.setAttribute("type", "radio");
        E.radioValue = "t" === b.value
    })();
    var Yb = /\r/g;
    e.fn.extend({
        val: function(b) {
            var f, a, c, d = this[0];
            if (arguments.length) return c = e.isFunction(b), this.each(function(a) {
                if (1 === this.nodeType && (a = c ? b.call(this, a, e(this).val()) : b, null == a ? a = "" : "number" === typeof a ? a += "" : e.isArray(a) && (a = e.map(a, function(b) {
                        return null == b ? "" : b + ""
                    })), f = e.valHooks[this.type] || e.valHooks[this.nodeName.toLowerCase()], !f || !("set" in f) || void 0 === f.set(this, a, "value"))) this.value = a
            });
            if (d) {
                if ((f =
                        e.valHooks[d.type] || e.valHooks[d.nodeName.toLowerCase()]) && "get" in f && void 0 !== (a = f.get(d, "value"))) return a;
                a = d.value;
                return "string" === typeof a ? a.replace(Yb, "") : null == a ? "" : a
            }
        }
    });
    e.extend({
        valHooks: {
            option: {
                get: function(b) {
                    var f = e.find.attr(b, "value");
                    return null != f ? f : e.trim(e.text(b))
                }
            },
            select: {
                get: function(b) {
                    for (var f, a = b.options, c = b.selectedIndex, d = (b = "select-one" === b.type || 0 > c) ? null : [], h = b ? c + 1 : a.length, m = 0 > c ? h : b ? c : 0; m < h; m++)
                        if (f = a[m], (f.selected || m === c) && (E.optDisabled ? !f.disabled : null === f.getAttribute("disabled")) &&
                            (!f.parentNode.disabled || !e.nodeName(f.parentNode, "optgroup"))) {
                            f = e(f).val();
                            if (b) return f;
                            d.push(f)
                        }
                    return d
                },
                set: function(b, f) {
                    for (var a, c, d = b.options, h = e.makeArray(f), m = d.length; m--;)
                        if (c = d[m], 0 <= e.inArray(e.valHooks.option.get(c), h)) try {
                            c.selected = a = !0
                        } catch (g) {
                            c.scrollHeight
                        } else c.selected = !1;
                    a || (b.selectedIndex = -1);
                    return d
                }
            }
        }
    });
    e.each(["radio", "checkbox"], function() {
        e.valHooks[this] = {
            set: function(b, f) {
                if (e.isArray(f)) return b.checked = 0 <= e.inArray(e(b).val(), f)
            }
        };
        E.checkOn || (e.valHooks[this].get =
            function(b) {
                return null === b.getAttribute("value") ? "on" : b.value
            })
    });
    var $a, Fb, Ma = e.expr.attrHandle,
        vb = /^(?:checked|selected)$/i,
        Sa = E.getSetAttribute,
        ob = E.input;
    e.fn.extend({
        attr: function(b, f) {
            return oa(this, e.attr, b, f, 1 < arguments.length)
        },
        removeAttr: function(b) {
            return this.each(function() {
                e.removeAttr(this, b)
            })
        }
    });
    e.extend({
        attr: function(b, f, a) {
            var c, d, h = b.nodeType;
            if (b && !(3 === h || 8 === h || 2 === h)) {
                if (typeof b.getAttribute === H) return e.prop(b, f, a);
                if (1 !== h || !e.isXMLDoc(b)) f = f.toLowerCase(), c = e.attrHooks[f] ||
                    (e.expr.match.bool.test(f) ? Fb : $a);
                if (void 0 !== a)
                    if (null === a) e.removeAttr(b, f);
                    else {
                        if (c && "set" in c && void 0 !== (d = c.set(b, a, f))) return d;
                        b.setAttribute(f, a + "");
                        return a
                    }
                else {
                    if (c && "get" in c && null !== (d = c.get(b, f))) return d;
                    d = e.find.attr(b, f);
                    return null == d ? void 0 : d
                }
            }
        },
        removeAttr: function(b, f) {
            var a, c, d = 0,
                h = f && f.match(ja);
            if (h && 1 === b.nodeType)
                for (; a = h[d++];) c = e.propFix[a] || a, e.expr.match.bool.test(a) ? ob && Sa || !vb.test(a) ? b[c] = !1 : b[e.camelCase("default-" + a)] = b[c] = !1 : e.attr(b, a, ""), b.removeAttribute(Sa ?
                    a : c)
        },
        attrHooks: {
            type: {
                set: function(b, f) {
                    if (!E.radioValue && "radio" === f && e.nodeName(b, "input")) {
                        var a = b.value;
                        b.setAttribute("type", f);
                        a && (b.value = a);
                        return f
                    }
                }
            }
        }
    });
    Fb = {
        set: function(b, f, a) {
            !1 === f ? e.removeAttr(b, a) : ob && Sa || !vb.test(a) ? b.setAttribute(!Sa && e.propFix[a] || a, a) : b[e.camelCase("default-" + a)] = b[a] = !0;
            return a
        }
    };
    e.each(e.expr.match.bool.source.match(/\w+/g), function(b, f) {
        var a = Ma[f] || e.find.attr;
        Ma[f] = ob && Sa || !vb.test(f) ? function(b, f, e) {
            var c, d;
            e || (d = Ma[f], Ma[f] = c, c = null != a(b, f, e) ? f.toLowerCase() :
                null, Ma[f] = d);
            return c
        } : function(b, f, a) {
            if (!a) return b[e.camelCase("default-" + f)] ? f.toLowerCase() : null
        }
    });
    if (!ob || !Sa) e.attrHooks.value = {
        set: function(b, f, a) {
            if (e.nodeName(b, "input")) b.defaultValue = f;
            else return $a && $a.set(b, f, a)
        }
    };
    Sa || ($a = {
        set: function(b, f, a) {
            var e = b.getAttributeNode(a);
            e || b.setAttributeNode(e = b.ownerDocument.createAttribute(a));
            e.value = f += "";
            if ("value" === a || f === b.getAttribute(a)) return f
        }
    }, Ma.id = Ma.name = Ma.coords = function(b, f, a) {
        var e;
        if (!a) return (e = b.getAttributeNode(f)) && "" !==
            e.value ? e.value : null
    }, e.valHooks.button = {
        get: function(b, f) {
            var a = b.getAttributeNode(f);
            if (a && a.specified) return a.value
        },
        set: $a.set
    }, e.attrHooks.contenteditable = {
        set: function(b, f, a) {
            $a.set(b, "" === f ? !1 : f, a)
        }
    }, e.each(["width", "height"], function(b, f) {
        e.attrHooks[f] = {
            set: function(b, a) {
                if ("" === a) return b.setAttribute(f, "auto"), a
            }
        }
    }));
    E.style || (e.attrHooks.style = {
        get: function(b) {
            return b.style.cssText || void 0
        },
        set: function(b, f) {
            return b.style.cssText = f + ""
        }
    });
    var Zb = /^(?:input|select|textarea|button|object)$/i,
        $b = /^(?:a|area)$/i;
    e.fn.extend({
        prop: function(b, f) {
            return oa(this, e.prop, b, f, 1 < arguments.length)
        },
        removeProp: function(b) {
            b = e.propFix[b] || b;
            return this.each(function() {
                try {
                    this[b] = void 0, delete this[b]
                } catch (f) {}
            })
        }
    });
    e.extend({
        propFix: {
            "for": "htmlFor",
            "class": "className"
        },
        prop: function(b, f, a) {
            var c, d, h;
            h = b.nodeType;
            if (b && !(3 === h || 8 === h || 2 === h)) {
                if (h = 1 !== h || !e.isXMLDoc(b)) f = e.propFix[f] || f, d = e.propHooks[f];
                return void 0 !== a ? d && "set" in d && void 0 !== (c = d.set(b, a, f)) ? c : b[f] = a : d && "get" in d && null !== (c = d.get(b,
                    f)) ? c : b[f]
            }
        },
        propHooks: {
            tabIndex: {
                get: function(b) {
                    var f = e.find.attr(b, "tabindex");
                    return f ? parseInt(f, 10) : Zb.test(b.nodeName) || $b.test(b.nodeName) && b.href ? 0 : -1
                }
            }
        }
    });
    E.hrefNormalized || e.each(["href", "src"], function(b, f) {
        e.propHooks[f] = {
            get: function(b) {
                return b.getAttribute(f, 4)
            }
        }
    });
    E.optSelected || (e.propHooks.selected = {
        get: function(b) {
            if (b = b.parentNode) b.selectedIndex, b.parentNode && b.parentNode.selectedIndex;
            return null
        }
    });
    e.each("tabIndex readOnly maxLength cellSpacing cellPadding rowSpan colSpan useMap frameBorder contentEditable".split(" "),
        function() {
            e.propFix[this.toLowerCase()] = this
        });
    E.enctype || (e.propFix.enctype = "encoding");
    var wb = /[\t\r\n\f]/g;
    e.fn.extend({
        addClass: function(b) {
            var f, a, c, d, h, m = 0,
                g = this.length;
            f = "string" === typeof b && b;
            if (e.isFunction(b)) return this.each(function(a) {
                e(this).addClass(b.call(this, a, this.className))
            });
            if (f)
                for (f = (b || "").match(ja) || []; m < g; m++)
                    if (a = this[m], c = 1 === a.nodeType && (a.className ? (" " + a.className + " ").replace(wb, " ") : " ")) {
                        for (h = 0; d = f[h++];) 0 > c.indexOf(" " + d + " ") && (c += d + " ");
                        c = e.trim(c);
                        a.className !==
                            c && (a.className = c)
                    }
            return this
        },
        removeClass: function(b) {
            var a, c, d, h, m, g = 0,
                n = this.length;
            a = 0 === arguments.length || "string" === typeof b && b;
            if (e.isFunction(b)) return this.each(function(a) {
                e(this).removeClass(b.call(this, a, this.className))
            });
            if (a)
                for (a = (b || "").match(ja) || []; g < n; g++)
                    if (c = this[g], d = 1 === c.nodeType && (c.className ? (" " + c.className + " ").replace(wb, " ") : "")) {
                        for (m = 0; h = a[m++];)
                            for (; 0 <= d.indexOf(" " + h + " ");) d = d.replace(" " + h + " ", " ");
                        d = b ? e.trim(d) : "";
                        c.className !== d && (c.className = d)
                    }
            return this
        },
        toggleClass: function(b, a) {
            var c = typeof b;
            return "boolean" === typeof a && "string" === c ? a ? this.addClass(b) : this.removeClass(b) : e.isFunction(b) ? this.each(function(c) {
                e(this).toggleClass(b.call(this, c, this.className, a), a)
            }) : this.each(function() {
                if ("string" === c)
                    for (var a, f = 0, d = e(this), h = b.match(ja) || []; a = h[f++];) d.hasClass(a) ? d.removeClass(a) : d.addClass(a);
                else if (c === H || "boolean" === c) this.className && e._data(this, "__className__", this.className), this.className = this.className || !1 === b ? "" : e._data(this, "__className__") ||
                    ""
            })
        },
        hasClass: function(b) {
            b = " " + b + " ";
            for (var a = 0, e = this.length; a < e; a++)
                if (1 === this[a].nodeType && 0 <= (" " + this[a].className + " ").replace(wb, " ").indexOf(b)) return !0;
            return !1
        }
    });
    e.each("blur focus focusin focusout load resize scroll unload click dblclick mousedown mouseup mousemove mouseover mouseout mouseenter mouseleave change select submit keydown keypress keyup error contextmenu".split(" "), function(b, a) {
        e.fn[a] = function(b, e) {
            return 0 < arguments.length ? this.on(a, null, b, e) : this.trigger(a)
        }
    });
    e.fn.extend({
        hover: function(b,
            a) {
            return this.mouseenter(b).mouseleave(a || b)
        },
        bind: function(b, a, e) {
            return this.on(b, null, a, e)
        },
        unbind: function(b, a) {
            return this.off(b, null, a)
        },
        delegate: function(b, a, e, c) {
            return this.on(a, b, e, c)
        },
        undelegate: function(b, a, e) {
            return 1 === arguments.length ? this.off(b, "**") : this.off(a, b || "**", e)
        }
    });
    var xb = e.now(),
        yb = /\?/,
        ac = /(,)|(\[|{)|(}|])|"(?:[^"\\\r\n]|\\["\\\/bfnrt]|\\u[\da-fA-F]{4})*"\s*:?|true|false|null|-?(?!0\d)\d+(?:\.\d+|)(?:[eE][+-]?\d+|)/g;
    e.parseJSON = function(b) {
        if (a.JSON && a.JSON.parse) return a.JSON.parse(b +
            "");
        var f, c = null,
            d = e.trim(b + "");
        return d && !e.trim(d.replace(ac, function(b, a, e, d) {
            f && a && (c = 0);
            if (0 === c) return b;
            f = e || a;
            c += !d - !e;
            return ""
        })) ? Function("return " + d)() : e.error("Invalid JSON: " + b)
    };
    e.parseXML = function(b) {
        var f, c;
        if (!b || "string" !== typeof b) return null;
        try {
            a.DOMParser ? (c = new DOMParser, f = c.parseFromString(b, "text/xml")) : (f = new ActiveXObject("Microsoft.XMLDOM"), f.async = "false", f.loadXML(b))
        } catch (d) {
            f = void 0
        }(!f || !f.documentElement || f.getElementsByTagName("parsererror").length) && e.error("Invalid XML: " +
            b);
        return f
    };
    var Ta, Na, bc = /#.*$/,
        Gb = /([?&])_=[^&]*/,
        cc = /^(.*?):[ \t]*([^\r\n]*)\r?$/mg,
        dc = /^(?:GET|HEAD)$/,
        ec = /^\/\//,
        Hb = /^([\w.+-]+:)(?:\/\/(?:[^\/?#]*@|)([^\/?#:]*)(?::(\d+)|)|)/,
        Ib = {},
        rb = {},
        Jb = "*/".concat("*");
    try {
        Na = location.href
    } catch (lc) {
        Na = L.createElement("a"), Na.href = "", Na = Na.href
    }
    Ta = Hb.exec(Na.toLowerCase()) || [];
    e.extend({
        active: 0,
        lastModified: {},
        etag: {},
        ajaxSettings: {
            url: Na,
            type: "GET",
            isLocal: /^(?:about|app|app-storage|.+-extension|file|res|widget):$/.test(Ta[1]),
            global: !0,
            processData: !0,
            async: !0,
            contentType: "application/x-www-form-urlencoded; charset\x3dUTF-8",
            accepts: {
                "*": Jb,
                text: "text/plain",
                html: "text/html",
                xml: "application/xml, text/xml",
                json: "application/json, text/javascript"
            },
            contents: {
                xml: /xml/,
                html: /html/,
                json: /json/
            },
            responseFields: {
                xml: "responseXML",
                text: "responseText",
                json: "responseJSON"
            },
            converters: {
                "* text": String,
                "text html": !0,
                "text json": e.parseJSON,
                "text xml": e.parseXML
            },
            flatOptions: {
                url: !0,
                context: !0
            }
        },
        ajaxSetup: function(b, a) {
            return a ? Ga(Ga(b, e.ajaxSettings), a) :
                Ga(e.ajaxSettings, b)
        },
        ajaxPrefilter: Ba(Ib),
        ajaxTransport: Ba(rb),
        ajax: function(b, a) {
            function c(b, a, f, d) {
                var h, l, k, t;
                t = a;
                if (2 !== B) {
                    B = 2;
                    n && clearTimeout(n);
                    v = void 0;
                    g = d || "";
                    G.readyState = 0 < b ? 4 : 0;
                    d = 200 <= b && 300 > b || 304 === b;
                    if (f) {
                        k = s;
                        for (var M = G, y, V, E, T, D = k.contents, X = k.dataTypes;
                            "*" === X[0];) X.shift(), void 0 === V && (V = k.mimeType || M.getResponseHeader("Content-Type"));
                        if (V)
                            for (T in D)
                                if (D[T] && D[T].test(V)) {
                                    X.unshift(T);
                                    break
                                }
                        if (X[0] in f) E = X[0];
                        else {
                            for (T in f) {
                                if (!X[0] || k.converters[T + " " + X[0]]) {
                                    E = T;
                                    break
                                }
                                y ||
                                    (y = T)
                            }
                            E = E || y
                        }
                        E ? (E !== X[0] && X.unshift(E), k = f[E]) : k = void 0
                    }
                    a: {
                        f = s;y = k;V = G;E = d;
                        var r, Z, W, M = {},
                            D = f.dataTypes.slice();
                        if (D[1])
                            for (Z in f.converters) M[Z.toLowerCase()] = f.converters[Z];
                        for (T = D.shift(); T;)
                            if (f.responseFields[T] && (V[f.responseFields[T]] = y), !W && (E && f.dataFilter) && (y = f.dataFilter(y, f.dataType)), W = T, T = D.shift())
                                if ("*" === T) T = W;
                                else if ("*" !== W && W !== T) {
                            Z = M[W + " " + T] || M["* " + T];
                            if (!Z)
                                for (r in M)
                                    if (k = r.split(" "), k[1] === T && (Z = M[W + " " + k[0]] || M["* " + k[0]])) {
                                        !0 === Z ? Z = M[r] : !0 !== M[r] && (T = k[0], D.unshift(k[1]));
                                        break
                                    }
                            if (!0 !== Z)
                                if (Z && f["throws"]) y = Z(y);
                                else try {
                                    y = Z(y)
                                } catch (u) {
                                    k = {
                                        state: "parsererror",
                                        error: Z ? u : "No conversion from " + W + " to " + T
                                    };
                                    break a
                                }
                        }
                        k = {
                            state: "success",
                            data: y
                        }
                    }
                    if (d) s.ifModified && ((t = G.getResponseHeader("Last-Modified")) && (e.lastModified[m] = t), (t = G.getResponseHeader("etag")) && (e.etag[m] = t)), 204 === b || "HEAD" === s.type ? t = "nocontent" : 304 === b ? t = "notmodified" : (t = k.state, h = k.data, l = k.error, d = !l);
                    else if (l = t, b || !t) t = "error", 0 > b && (b = 0);
                    G.status = b;
                    G.statusText = (a || t) + "";
                    d ? N.resolveWith(F, [h, t, G]) : N.rejectWith(F, [G, t, l]);
                    G.statusCode(O);
                    O = void 0;
                    p && I.trigger(d ? "ajaxSuccess" : "ajaxError", [G, s, d ? h : l]);
                    A.fireWith(F, [G, t]);
                    p && (I.trigger("ajaxComplete", [G, s]), --e.active || e.event.trigger("ajaxStop"))
                }
            }
            "object" === typeof b && (a = b, b = void 0);
            a = a || {};
            var d, h, m, g, n, p, v, k, s = e.ajaxSetup({}, a),
                F = s.context || s,
                I = s.context && (F.nodeType || F.jquery) ? e(F) : e.event,
                N = e.Deferred(),
                A = e.Callbacks("once memory"),
                O = s.statusCode || {},
                t = {},
                M = {},
                B = 0,
                V = "canceled",
                G = {
                    readyState: 0,
                    getResponseHeader: function(b) {
                        var a;
                        if (2 === B) {
                            if (!k)
                                for (k = {}; a =
                                    cc.exec(g);) k[a[1].toLowerCase()] = a[2];
                            a = k[b.toLowerCase()]
                        }
                        return null == a ? null : a
                    },
                    getAllResponseHeaders: function() {
                        return 2 === B ? g : null
                    },
                    setRequestHeader: function(b, a) {
                        var e = b.toLowerCase();
                        B || (b = M[e] = M[e] || b, t[b] = a);
                        return this
                    },
                    overrideMimeType: function(b) {
                        B || (s.mimeType = b);
                        return this
                    },
                    statusCode: function(b) {
                        var a;
                        if (b)
                            if (2 > B)
                                for (a in b) O[a] = [O[a], b[a]];
                            else G.always(b[G.status]);
                        return this
                    },
                    abort: function(b) {
                        b = b || V;
                        v && v.abort(b);
                        c(0, b);
                        return this
                    }
                };
            N.promise(G).complete = A.add;
            G.success = G.done;
            G.error = G.fail;
            s.url = ((b || s.url || Na) + "").replace(bc, "").replace(ec, Ta[1] + "//");
            s.type = a.method || a.type || s.method || s.type;
            s.dataTypes = e.trim(s.dataType || "*").toLowerCase().match(ja) || [""];
            null == s.crossDomain && (d = Hb.exec(s.url.toLowerCase()), s.crossDomain = !(!d || !(d[1] !== Ta[1] || d[2] !== Ta[2] || (d[3] || ("http:" === d[1] ? "80" : "443")) !== (Ta[3] || ("http:" === Ta[1] ? "80" : "443")))));
            s.data && (s.processData && "string" !== typeof s.data) && (s.data = e.param(s.data, s.traditional));
            Pa(Ib, s, a, G);
            if (2 === B) return G;
            (p = s.global) &&
            0 === e.active++ && e.event.trigger("ajaxStart");
            s.type = s.type.toUpperCase();
            s.hasContent = !dc.test(s.type);
            m = s.url;
            s.hasContent || (s.data && (m = s.url += (yb.test(m) ? "\x26" : "?") + s.data, delete s.data), !1 === s.cache && (s.url = Gb.test(m) ? m.replace(Gb, "$1_\x3d" + xb++) : m + (yb.test(m) ? "\x26" : "?") + "_\x3d" + xb++));
            s.ifModified && (e.lastModified[m] && G.setRequestHeader("If-Modified-Since", e.lastModified[m]), e.etag[m] && G.setRequestHeader("If-None-Match", e.etag[m]));
            (s.data && s.hasContent && !1 !== s.contentType || a.contentType) &&
            G.setRequestHeader("Content-Type", s.contentType);
            G.setRequestHeader("Accept", s.dataTypes[0] && s.accepts[s.dataTypes[0]] ? s.accepts[s.dataTypes[0]] + ("*" !== s.dataTypes[0] ? ", " + Jb + "; q\x3d0.01" : "") : s.accepts["*"]);
            for (h in s.headers) G.setRequestHeader(h, s.headers[h]);
            if (s.beforeSend && (!1 === s.beforeSend.call(F, G, s) || 2 === B)) return G.abort();
            V = "abort";
            for (h in {
                    success: 1,
                    error: 1,
                    complete: 1
                }) G[h](s[h]);
            if (v = Pa(rb, s, a, G)) {
                G.readyState = 1;
                p && I.trigger("ajaxSend", [G, s]);
                s.async && 0 < s.timeout && (n = setTimeout(function() {
                        G.abort("timeout")
                    },
                    s.timeout));
                try {
                    B = 1, v.send(t, c)
                } catch (E) {
                    if (2 > B) c(-1, E);
                    else throw E;
                }
            } else c(-1, "No Transport");
            return G
        },
        getJSON: function(b, a, c) {
            return e.get(b, a, c, "json")
        },
        getScript: function(b, a) {
            return e.get(b, void 0, a, "script")
        }
    });
    e.each(["get", "post"], function(b, a) {
        e[a] = function(b, c, d, h) {
            e.isFunction(c) && (h = h || d, d = c, c = void 0);
            return e.ajax({
                url: b,
                type: a,
                dataType: h,
                data: c,
                success: d
            })
        }
    });
    e.each("ajaxStart ajaxStop ajaxComplete ajaxError ajaxSuccess ajaxSend".split(" "), function(b, a) {
        e.fn[a] = function(b) {
            return this.on(a,
                b)
        }
    });
    e._evalUrl = function(b) {
        return e.ajax({
            url: b,
            type: "GET",
            dataType: "script",
            async: !1,
            global: !1,
            "throws": !0
        })
    };
    e.fn.extend({
        wrapAll: function(b) {
            if (e.isFunction(b)) return this.each(function(a) {
                e(this).wrapAll(b.call(this, a))
            });
            if (this[0]) {
                var a = e(b, this[0].ownerDocument).eq(0).clone(!0);
                this[0].parentNode && a.insertBefore(this[0]);
                a.map(function() {
                    for (var b = this; b.firstChild && 1 === b.firstChild.nodeType;) b = b.firstChild;
                    return b
                }).append(this)
            }
            return this
        },
        wrapInner: function(b) {
            return e.isFunction(b) ?
                this.each(function(a) {
                    e(this).wrapInner(b.call(this, a))
                }) : this.each(function() {
                    var a = e(this),
                        c = a.contents();
                    c.length ? c.wrapAll(b) : a.append(b)
                })
        },
        wrap: function(b) {
            var a = e.isFunction(b);
            return this.each(function(c) {
                e(this).wrapAll(a ? b.call(this, c) : b)
            })
        },
        unwrap: function() {
            return this.parent().each(function() {
                e.nodeName(this, "body") || e(this).replaceWith(this.childNodes)
            }).end()
        }
    });
    e.expr.filters.hidden = function(b) {
        return 0 >= b.offsetWidth && 0 >= b.offsetHeight || !E.reliableHiddenOffsets() && "none" === (b.style &&
            b.style.display || e.css(b, "display"))
    };
    e.expr.filters.visible = function(b) {
        return !e.expr.filters.hidden(b)
    };
    var fc = /%20/g,
        Pb = /\[\]$/,
        Kb = /\r?\n/g,
        gc = /^(?:submit|button|image|reset|file)$/i,
        hc = /^(?:input|select|textarea|keygen)/i;
    e.param = function(b, a) {
        var c, d = [],
            h = function(b, a) {
                a = e.isFunction(a) ? a() : null == a ? "" : a;
                d[d.length] = encodeURIComponent(b) + "\x3d" + encodeURIComponent(a)
            };
        void 0 === a && (a = e.ajaxSettings && e.ajaxSettings.traditional);
        if (e.isArray(b) || b.jquery && !e.isPlainObject(b)) e.each(b, function() {
            h(this.name,
                this.value)
        });
        else
            for (c in b) ka(c, b[c], a, h);
        return d.join("\x26").replace(fc, "+")
    };
    e.fn.extend({
        serialize: function() {
            return e.param(this.serializeArray())
        },
        serializeArray: function() {
            return this.map(function() {
                var b = e.prop(this, "elements");
                return b ? e.makeArray(b) : this
            }).filter(function() {
                var b = this.type;
                return this.name && !e(this).is(":disabled") && hc.test(this.nodeName) && !gc.test(b) && (this.checked || !Ea.test(b))
            }).map(function(b, a) {
                var c = e(this).val();
                return null == c ? null : e.isArray(c) ? e.map(c, function(b) {
                    return {
                        name: a.name,
                        value: b.replace(Kb, "\r\n")
                    }
                }) : {
                    name: a.name,
                    value: c.replace(Kb, "\r\n")
                }
            }).get()
        }
    });
    e.ajaxSettings.xhr = void 0 !== a.ActiveXObject ? function() {
        var b;
        if (!(b = !this.isLocal && /^(get|post|head|put|delete|options)$/i.test(this.type) && Wa())) a: {
            try {
                b = new a.ActiveXObject("Microsoft.XMLHTTP");
                break a
            } catch (e) {}
            b = void 0
        }
        return b
    } : Wa;
    var ic = 0,
        pb = {},
        qb = e.ajaxSettings.xhr();
    if (a.ActiveXObject) e(a).on("unload", function() {
        for (var b in pb) pb[b](void 0, !0)
    });
    E.cors = !!qb && "withCredentials" in qb;
    (qb = E.ajax = !!qb) && e.ajaxTransport(function(b) {
        if (!b.crossDomain ||
            E.cors) {
            var a;
            return {
                send: function(c, d) {
                    var h, m = b.xhr(),
                        g = ++ic;
                    m.open(b.type, b.url, b.async, b.username, b.password);
                    if (b.xhrFields)
                        for (h in b.xhrFields) m[h] = b.xhrFields[h];
                    b.mimeType && m.overrideMimeType && m.overrideMimeType(b.mimeType);
                    !b.crossDomain && !c["X-Requested-With"] && (c["X-Requested-With"] = "XMLHttpRequest");
                    for (h in c) void 0 !== c[h] && m.setRequestHeader(h, c[h] + "");
                    m.send(b.hasContent && b.data || null);
                    a = function(c, h) {
                        var l, n, s;
                        if (a && (h || 4 === m.readyState))
                            if (delete pb[g], a = void 0, m.onreadystatechange =
                                e.noop, h) 4 !== m.readyState && m.abort();
                            else {
                                s = {};
                                l = m.status;
                                "string" === typeof m.responseText && (s.text = m.responseText);
                                try {
                                    n = m.statusText
                                } catch (p) {
                                    n = ""
                                }!l && b.isLocal && !b.crossDomain ? l = s.text ? 200 : 404 : 1223 === l && (l = 204)
                            }
                        s && d(l, n, s, m.getAllResponseHeaders())
                    };
                    b.async ? 4 === m.readyState ? setTimeout(a) : m.onreadystatechange = pb[g] = a : a()
                },
                abort: function() {
                    a && a(void 0, !0)
                }
            }
        }
    });
    e.ajaxSetup({
        accepts: {
            script: "text/javascript, application/javascript, application/ecmascript, application/x-ecmascript"
        },
        contents: {
            script: /(?:java|ecma)script/
        },
        converters: {
            "text script": function(b) {
                e.globalEval(b);
                return b
            }
        }
    });
    e.ajaxPrefilter("script", function(b) {
        void 0 === b.cache && (b.cache = !1);
        b.crossDomain && (b.type = "GET", b.global = !1)
    });
    e.ajaxTransport("script", function(b) {
        if (b.crossDomain) {
            var a, c = L.head || e("head")[0] || L.documentElement;
            return {
                send: function(e, d) {
                    a = L.createElement("script");
                    a.async = !0;
                    b.scriptCharset && (a.charset = b.scriptCharset);
                    a.src = b.url;
                    a.onload = a.onreadystatechange = function(b, e) {
                        if (e || !a.readyState || /loaded|complete/.test(a.readyState)) a.onload =
                            a.onreadystatechange = null, a.parentNode && a.parentNode.removeChild(a), a = null, e || d(200, "success")
                    };
                    c.insertBefore(a, c.firstChild)
                },
                abort: function() {
                    if (a) a.onload(void 0, !0)
                }
            }
        }
    });
    var Lb = [],
        zb = /(=)\?(?=&|$)|\?\?/;
    e.ajaxSetup({
        jsonp: "callback",
        jsonpCallback: function() {
            var b = Lb.pop() || e.expando + "_" + xb++;
            this[b] = !0;
            return b
        }
    });
    e.ajaxPrefilter("json jsonp", function(b, f, c) {
        var d, h, m, g = !1 !== b.jsonp && (zb.test(b.url) ? "url" : "string" === typeof b.data && !(b.contentType || "").indexOf("application/x-www-form-urlencoded") &&
            zb.test(b.data) && "data");
        if (g || "jsonp" === b.dataTypes[0]) return d = b.jsonpCallback = e.isFunction(b.jsonpCallback) ? b.jsonpCallback() : b.jsonpCallback, g ? b[g] = b[g].replace(zb, "$1" + d) : !1 !== b.jsonp && (b.url += (yb.test(b.url) ? "\x26" : "?") + b.jsonp + "\x3d" + d), b.converters["script json"] = function() {
                m || e.error(d + " was not called");
                return m[0]
            }, b.dataTypes[0] = "json", h = a[d], a[d] = function() {
                m = arguments
            }, c.always(function() {
                a[d] = h;
                b[d] && (b.jsonpCallback = f.jsonpCallback, Lb.push(d));
                m && e.isFunction(h) && h(m[0]);
                m = h = void 0
            }),
            "script"
    });
    e.parseHTML = function(b, a, c) {
        if (!b || "string" !== typeof b) return null;
        "boolean" === typeof a && (c = a, a = !1);
        a = a || L;
        var d = za.exec(b);
        c = !c && [];
        if (d) return [a.createElement(d[1])];
        d = e.buildFragment([b], a, c);
        c && c.length && e(c).remove();
        return e.merge([], d.childNodes)
    };
    var Mb = e.fn.load;
    e.fn.load = function(b, a, c) {
        if ("string" !== typeof b && Mb) return Mb.apply(this, arguments);
        var d, h, m, g = this,
            n = b.indexOf(" ");
        0 <= n && (d = e.trim(b.slice(n, b.length)), b = b.slice(0, n));
        e.isFunction(a) ? (c = a, a = void 0) : a && "object" === typeof a &&
            (m = "POST");
        0 < g.length && e.ajax({
            url: b,
            type: m,
            dataType: "html",
            data: a
        }).done(function(b) {
            h = arguments;
            g.html(d ? e("\x3cdiv\x3e").append(e.parseHTML(b)).find(d) : b)
        }).complete(c && function(b, a) {
            g.each(c, h || [b.responseText, a, b])
        });
        return this
    };
    e.expr.filters.animated = function(b) {
        return e.grep(e.timers, function(a) {
            return b === a.elem
        }).length
    };
    var Nb = a.document.documentElement;
    e.offset = {
        setOffset: function(b, a, c) {
            var d, h, m, g = e.css(b, "position"),
                n = e(b),
                s = {};
            "static" === g && (b.style.position = "relative");
            m = n.offset();
            h = e.css(b, "top");
            d = e.css(b, "left");
            ("absolute" === g || "fixed" === g) && -1 < e.inArray("auto", [h, d]) ? (d = n.position(), h = d.top, d = d.left) : (h = parseFloat(h) || 0, d = parseFloat(d) || 0);
            e.isFunction(a) && (a = a.call(b, c, m));
            null != a.top && (s.top = a.top - m.top + h);
            null != a.left && (s.left = a.left - m.left + d);
            "using" in a ? a.using.call(b, s) : n.css(s)
        }
    };
    e.fn.extend({
        offset: function(b) {
            if (arguments.length) return void 0 === b ? this : this.each(function(a) {
                e.offset.setOffset(this, b, a)
            });
            var a, c, d = {
                    top: 0,
                    left: 0
                },
                h = (c = this[0]) && c.ownerDocument;
            if (h) {
                a = h.documentElement;
                if (!e.contains(a, c)) return d;
                typeof c.getBoundingClientRect !== H && (d = c.getBoundingClientRect());
                c = ca(h);
                return {
                    top: d.top + (c.pageYOffset || a.scrollTop) - (a.clientTop || 0),
                    left: d.left + (c.pageXOffset || a.scrollLeft) - (a.clientLeft || 0)
                }
            }
        },
        position: function() {
            if (this[0]) {
                var b, a, c = {
                        top: 0,
                        left: 0
                    },
                    d = this[0];
                "fixed" === e.css(d, "position") ? a = d.getBoundingClientRect() : (b = this.offsetParent(), a = this.offset(), e.nodeName(b[0], "html") || (c = b.offset()), c.top += e.css(b[0], "borderTopWidth", !0), c.left +=
                    e.css(b[0], "borderLeftWidth", !0));
                return {
                    top: a.top - c.top - e.css(d, "marginTop", !0),
                    left: a.left - c.left - e.css(d, "marginLeft", !0)
                }
            }
        },
        offsetParent: function() {
            return this.map(function() {
                for (var b = this.offsetParent || Nb; b && !e.nodeName(b, "html") && "static" === e.css(b, "position");) b = b.offsetParent;
                return b || Nb
            })
        }
    });
    e.each({
        scrollLeft: "pageXOffset",
        scrollTop: "pageYOffset"
    }, function(b, a) {
        var c = /Y/.test(a);
        e.fn[b] = function(d) {
            return oa(this, function(b, d, h) {
                var m = ca(b);
                if (void 0 === h) return m ? a in m ? m[a] : m.document.documentElement[d] :
                    b[d];
                m ? m.scrollTo(!c ? h : e(m).scrollLeft(), c ? h : e(m).scrollTop()) : b[d] = h
            }, b, d, arguments.length, null)
        }
    });
    e.each(["top", "left"], function(b, a) {
        e.cssHooks[a] = m(E.pixelPosition, function(b, c) {
            if (c) return c = Oa(b, a), hb.test(c) ? e(b).position()[a] + "px" : c
        })
    });
    e.each({
        Height: "height",
        Width: "width"
    }, function(b, a) {
        e.each({
            padding: "inner" + b,
            content: a,
            "": "outer" + b
        }, function(c, d) {
            e.fn[d] = function(d, h) {
                var m = arguments.length && (c || "boolean" !== typeof d),
                    g = c || (!0 === d || !0 === h ? "margin" : "border");
                return oa(this, function(a,
                    f, c) {
                    return e.isWindow(a) ? a.document.documentElement["client" + b] : 9 === a.nodeType ? (f = a.documentElement, Math.max(a.body["scroll" + b], f["scroll" + b], a.body["offset" + b], f["offset" + b], f["client" + b])) : void 0 === c ? e.css(a, f, g) : e.style(a, f, c, g)
                }, a, m ? d : void 0, m, null)
            }
        })
    });
    e.fn.size = function() {
        return this.length
    };
    e.fn.andSelf = e.fn.addBack;
    "function" === typeof define && define.amd && define("jquery", [], function() {
        return e
    });
    var jc = a.jQuery,
        kc = a.$;
    e.noConflict = function(b) {
        a.$ === e && (a.$ = kc);
        b && a.jQuery === e && (a.jQuery =
            jc);
        return e
    };
    typeof u === H && (a.jQuery = a.$ = e);
    return e
});
(function(a) {
    "function" === typeof define && define.amd ? "undefined" !== typeof jQuery ? define(["jquery"], a) : define([], a) : "undefined" !== typeof jQuery ? a(jQuery) : a()
})(function(a, u) {
    function r(a, c) {
        for (var d = decodeURI(a), d = z[c ? "strict" : "loose"].exec(d), g = {
                attr: {},
                param: {},
                seg: {}
            }, n = 14; n--;) g.attr[w[n]] = d[n] || "";
        g.param.query = k(g.attr.query);
        g.param.fragment = k(g.attr.fragment);
        g.seg.path = g.attr.path.replace(/^\/+|\/+$/g, "").split("/");
        g.seg.fragment = g.attr.fragment.replace(/^\/+|\/+$/g, "").split("/");
        g.attr.base =
            g.attr.host ? (g.attr.protocol ? g.attr.protocol + "://" + g.attr.host : g.attr.host) + (g.attr.port ? ":" + g.attr.port : "") : "";
        return g
    }

    function c(a) {
        a = a.tagName;
        return "undefined" !== typeof a ? C[a.toLowerCase()] : a
    }

    function g(a, c, d, k) {
        var I = a.shift();
        if (I) {
            var p = c[d] = c[d] || [];
            if ("]" == I)
                if (n(p)) "" != k && p.push(k);
                else if ("object" == typeof p) {
                c = a = p;
                d = [];
                for (prop in c) c.hasOwnProperty(prop) && d.push(prop);
                a[d.length] = k
            } else c[d] = [c[d], k];
            else {
                ~I.indexOf("]") && (I = I.substr(0, I.length - 1));
                if (!D.test(I) && n(p))
                    if (0 == c[d].length) p =
                        c[d] = {};
                    else {
                        var p = {},
                            A;
                        for (A in c[d]) p[A] = c[d][A];
                        c[d] = p
                    }
                g(a, p, I, k)
            }
        } else n(c[d]) ? c[d].push(k) : c[d] = "object" == typeof c[d] ? k : "undefined" == typeof c[d] ? k : [c[d], k]
    }

    function k(a) {
        return d(String(a).split(/&|;/), function(a, c) {
            try {
                c = decodeURIComponent(c.replace(/\+/g, " "))
            } catch (d) {}
            var k = c.indexOf("\x3d"),
                p;
            a: {
                for (var A = c.length, t, M = 0; M < A; ++M)
                    if (t = c[M], "]" == t && (p = !1), "[" == t && (p = !0), "\x3d" == t && !p) {
                        p = M;
                        break a
                    }
                p = void 0
            }
            A = c.substr(0, p || k);
            p = c.substr(p || k, c.length);
            p = p.substr(p.indexOf("\x3d") + 1, p.length);
            "" == A && (A = c, p = "");
            k = A;
            A = p;
            if (~k.indexOf("]")) {
                var O = k.split("[");
                g(O, a, "base", A)
            } else {
                if (!D.test(k) && n(a.base)) {
                    p = {};
                    for (O in a.base) p[O] = a.base[O];
                    a.base = p
                }
                O = a.base;
                p = O[k];
                u === p ? O[k] = A : n(p) ? p.push(A) : O[k] = [p, A]
            }
            return a
        }, {
            base: {}
        }).base
    }

    function d(a, c, d) {
        for (var g = 0, n = a.length >> 0; g < n;) g in a && (d = c.call(u, d, a[g], g, a)), ++g;
        return d
    }

    function n(a) {
        return "[object Array]" === Object.prototype.toString.call(a)
    }

    function B(a, c) {
        1 === arguments.length && !0 === a && (c = !0, a = u);
        a = a || window.location.toString();
        return {
            data: r(a,
                c || !1),
            attr: function(a) {
                a = x[a] || a;
                return "undefined" !== typeof a ? this.data.attr[a] : this.data.attr
            },
            param: function(a) {
                return "undefined" !== typeof a ? this.data.param.query[a] : this.data.param.query
            },
            fparam: function(a) {
                return "undefined" !== typeof a ? this.data.param.fragment[a] : this.data.param.fragment
            },
            segment: function(a) {
                if ("undefined" === typeof a) return this.data.seg.path;
                a = 0 > a ? this.data.seg.path.length + a : a - 1;
                return this.data.seg.path[a]
            },
            fsegment: function(a) {
                if ("undefined" === typeof a) return this.data.seg.fragment;
                a = 0 > a ? this.data.seg.fragment.length + a : a - 1;
                return this.data.seg.fragment[a]
            }
        }
    }
    var C = {
            a: "href",
            img: "src",
            form: "action",
            base: "href",
            script: "src",
            iframe: "src",
            link: "href"
        },
        w = "source protocol authority userInfo user password host port relative path directory file query fragment".split(" "),
        x = {
            anchor: "fragment"
        },
        z = {
            strict: /^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*):?([^:@]*))?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/,
            loose: /^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*):?([^:@]*))?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/
        },
        D = /^[0-9]+$/;
    "undefined" !== typeof a ? (a.fn.url = function(d) {
        var g = "";
        this.length && (g = a(this).attr(c(this[0])) || "");
        return B(g, d)
    }, a.url = B) : window.purl = B
});
var $Apprise = null,
    $overlay = null,
    $body = null,
    $window = null,
    $cA = null,
    AppriseQueue = [];
$(function() {
    $Apprise = $('\x3cdiv class\x3d"apprise"\x3e');
    $overlay = $('\x3cdiv class\x3d"apprise-overlay"\x3e');
    $body = $("body");
    $window = $(window);
    $body.append($overlay.css("opacity", ".94")).append($Apprise)
});

function Apprise(a, u) {
    if (void 0 === a || !a) return !1;
    var r = this,
        c = $('\x3cdiv class\x3d"apprise-inner"\x3e'),
        g = $('\x3cdiv class\x3d"apprise-buttons"\x3e'),
        k = $('\x3cinput type\x3d"text"\x3e'),
        d = {
            animation: 700,
            buttons: {
                confirm: {
                    action: function() {
                        r.dissapear()
                    },
                    className: null,
                    id: "confirm",
                    text: "Ok"
                }
            },
            input: !1,
            override: !0
        };
    $.extend(d, u);
    "close" == a ? $cA.dissapear() : $Apprise.is(":visible") ? AppriseQueue.push({
        text: a,
        options: d
    }) : (this.adjustWidth = function() {
            var a = $window.width(),
                c = "20%",
                d = "40%";
            800 >= a ? (c = "90%",
                d = "5%") : 1400 >= a && 800 < a ? (c = "70%", d = "15%") : 1800 >= a && 1400 < a ? (c = "50%", d = "25%") : 2200 >= a && 1800 < a && (c = "30%", d = "35%");
            $Apprise.css("width", c).css("left", d)
        }, this.dissapear = function() {
            $Apprise.animate({
                top: "-100%"
            }, d.animation, function() {
                $overlay.fadeOut(300);
                $Apprise.hide();
                $window.unbind("beforeunload");
                $window.unbind("keydown");
                AppriseQueue[0] && (Apprise(AppriseQueue[0].text, AppriseQueue[0].options), AppriseQueue.splice(0, 1))
		  
								   
											 
																																																												  
		  
										 
				
																						
												   
						
									  
						 
							   
												   
				  
						   
            })
        }, this.keyPress = function() {
            $window.bind("keydown", function(a) {
                27 === a.keyCode ? d.buttons.cancel ?
                    $("#apprise-btn-" + d.buttons.cancel.id).trigger("click") : r.dissapear() : 13 === a.keyCode && (d.buttons.confirm ? $("#apprise-btn-" + d.buttons.confirm.id).trigger("click") : r.dissapear())
            })
        }, $.each(d.buttons, function(a, c) {
            if (c) {
                var d = $('\x3cbutton id\x3d"apprise-btn-' + c.id + '"\x3e').append(c.text);
                c.className && d.addClass(c.className);
                g.append(d);
                d.on("click", function() {
                    var a = {
                        clicked: c,
                        input: k.val() ? k.val() : null
                    };
                    c.action(a)
                })
            }
        }), d.override && $window.bind("beforeunload", function(a) {
            return "An alert requires attention"
        }),
        r.adjustWidth(), $window.resize(function() {
            r.adjustWidth()
        }), $Apprise.html("").append(c.append('\x3cdiv class\x3d"apprise-content"\x3e' + a + "\x3c/div\x3e")).append(g), $cA = this, d.input && c.find(".apprise-content").append($('\x3cdiv class\x3d"apprise-input"\x3e').append(k)), $overlay.fadeIn(300), $Apprise.show().animate({
            top: "20%"
        }, d.animation, function() {
            r.keyPress()
        }), d.input && k.focus())
}! function(a) {
    a(function() {
        var u = a.support,
            r;
        a: {
            r = document.createElement("bootstrap");
            var c = {
                    WebkitTransition: "webkitTransitionEnd",
                    MozTransition: "transitionend",
                    OTransition: "oTransitionEnd otransitionend",
                    transition: "transitionend"
                },
                g;
            for (g in c)
                if (void 0 !== r.style[g]) {
                    r = c[g];
                    break a
                }
            r = void 0
        }
        u.transition = r && {
            end: r
        }
    })
}(window.jQuery);
! function(a) {
    var u = function(c) {
        a(c).on("click", '[data-dismiss\x3d"alert"]', this.close)
    };
    u.prototype.close = function(c) {
        function g() {
            n.trigger("closed").remove()
        }
        var k = a(this),
            d = k.attr("data-target"),
            n;
        d || (d = (d = k.attr("href")) && d.replace(/.*(?=#[^\s]*$)/, ""));
        n = a(d);
        c && c.preventDefault();
        n.length || (n = k.hasClass("alert") ? k : k.parent());
        n.trigger(c = a.Event("close"));
        c.isDefaultPrevented() || (n.removeClass("in"), a.support.transition && n.hasClass("fade") ? n.on(a.support.transition.end, g) : g())
    };
    var r = a.fn.alert;
    a.fn.alert = function(c) {
        return this.each(function() {
            var g = a(this),
                k = g.data("alert");
            k || g.data("alert", k = new u(this));
            "string" == typeof c && k[c].call(g)
        })
    };
    a.fn.alert.Constructor = u;
    a.fn.alert.noConflict = function() {
        a.fn.alert = r;
        return this
    };
    a(document).on("click.alert.data-api", '[data-dismiss\x3d"alert"]', u.prototype.close)
}(window.jQuery);
! function(a) {
    var u = function(c, g) {
        this.options = g;
        this.$element = a(c).delegate('[data-dismiss\x3d"modal"]', "click.dismiss.modal", a.proxy(this.hide, this));
        this.options.remote && this.$element.find(".modal-body").load(this.options.remote)
    };
    u.prototype = {
        constructor: u,
        toggle: function() {
            return this[!this.isShown ? "show" : "hide"]()
        },
        show: function() {
            var c = this,
                g = a.Event("show");
            this.$element.trigger(g);
            !this.isShown && !g.isDefaultPrevented() && (this.isShown = !0, this.escape(), this.backdrop(function() {
                var g = a.support.transition &&
                    c.$element.hasClass("fade");
                c.$element.parent().length || c.$element.appendTo(document.body);
                c.$element.show();
                g && c.$element[0].offsetWidth;
                c.$element.addClass("in").attr("aria-hidden", !1);
                c.enforceFocus();
                g ? c.$element.one(a.support.transition.end, function() {
                    c.$element.focus().trigger("shown")
                }) : c.$element.focus().trigger("shown")
            }))
        },
        hide: function(c) {
            c && c.preventDefault();
            c = a.Event("hide");
            this.$element.trigger(c);
            this.isShown && !c.isDefaultPrevented() && (this.isShown = !1, this.escape(), a(document).off("focusin.modal"),
                this.$element.removeClass("in").attr("aria-hidden", !0), a.support.transition && this.$element.hasClass("fade") ? this.hideWithTransition() : this.hideModal())
        },
        enforceFocus: function() {
            var c = this;
            a(document).on("focusin.modal", function(a) {
                c.$element[0] !== a.target && !c.$element.has(a.target).length && c.$element.focus()
            })
        },
        escape: function() {
            var a = this;
            if (this.isShown && this.options.keyboard) this.$element.on("keyup.dismiss.modal", function(g) {
                27 == g.which && a.hide()
            });
            else this.isShown || this.$element.off("keyup.dismiss.modal")
        },
        hideWithTransition: function() {
            var c = this,
                g = setTimeout(function() {
                    c.$element.off(a.support.transition.end);
                    c.hideModal()
                }, 500);
            this.$element.one(a.support.transition.end, function() {
                clearTimeout(g);
                c.hideModal()
            })
        },
        hideModal: function() {
            var a = this;
            this.$element.hide();
            this.backdrop(function() {
                a.removeBackdrop();
                a.$element.trigger("hidden")
            })
        },
        removeBackdrop: function() {
            this.$backdrop && this.$backdrop.remove();
            this.$backdrop = null
        },
        backdrop: function(c) {
            var g = this.$element.hasClass("fade") ? "fade" : "";
            if (this.isShown &&
                this.options.backdrop) {
                var k = a.support.transition && g;
                this.$backdrop = a('\x3cdiv class\x3d"modal-backdrop ' + g + '" /\x3e').appendTo(document.body);
                this.$backdrop.click("static" == this.options.backdrop ? a.proxy(this.$element[0].focus, this.$element[0]) : a.proxy(this.hide, this));
                k && this.$backdrop[0].offsetWidth;
                this.$backdrop.addClass("in");
                c && (k ? this.$backdrop.one(a.support.transition.end, c) : c())
            } else !this.isShown && this.$backdrop ? (this.$backdrop.removeClass("in"), a.support.transition && this.$element.hasClass("fade") ?
                this.$backdrop.one(a.support.transition.end, c) : c()) : c && c()
        }
    };
    var r = a.fn.modal;
    a.fn.modal = function(c) {
        return this.each(function() {
            var g = a(this),
                k = g.data("modal"),
                d = a.extend({}, a.fn.modal.defaults, g.data(), "object" == typeof c && c);
            k || g.data("modal", k = new u(this, d));
            if ("string" == typeof c) k[c]();
            else d.show && k.show()
        })
    };
    a.fn.modal.defaults = {
        backdrop: !0,
        keyboard: !0,
        show: !0
    };
    a.fn.modal.Constructor = u;
    a.fn.modal.noConflict = function() {
        a.fn.modal = r;
        return this
    };
    a(document).on("click.modal.data-api", '[data-toggle\x3d"modal"]',
        function(c) {
            var g = a(this),
                k = g.attr("href"),
                d = a(g.attr("data-target") || k && k.replace(/.*(?=#[^\s]+$)/, "")),
                k = d.data("modal") ? "toggle" : a.extend({
                    remote: !/#/.test(k) && k
                }, d.data(), g.data());
            c.preventDefault();
            d.modal(k).one("hide", function() {
                g.focus()
            })
        })
	  
}(window.jQuery);
! function(a) {
    function u() {
        a(c).each(function() {
            r(a(this)).removeClass("open")
        })
    }

    function r(c) {
        var g = c.attr("data-target");
        g || (g = (g = c.attr("href")) && /#/.test(g) && g.replace(/.*(?=#[^\s]*$)/, ""));
        g = g && a(g);
        if (!g || !g.length) g = c.parent();
        return g
    }
    var c = "[data-toggle\x3ddropdown]",
        g = function(c) {
            var g = a(c).on("click.dropdown.data-api", this.toggle);
            a("html").on("click.dropdown.data-api", function() {
                g.parent().removeClass("open")
            })
        };
    g.prototype = {
        constructor: g,
        toggle: function(c) {
            c = a(this);
            var g, k;
            if (!c.is(".disabled, :disabled")) return g =
                r(c), k = g.hasClass("open"), u(), k || g.toggleClass("open"), c.focus(), !1
        },
        keydown: function(d) {
            var g, k, u;
            if (/(38|40|27)/.test(d.keyCode) && (g = a(this), d.preventDefault(), d.stopPropagation(), !g.is(".disabled, :disabled"))) {
                k = r(g);
                u = k.hasClass("open");
                if (!u || u && 27 == d.keyCode) return 27 == d.which && k.find(c).focus(), g.click();
                g = a("[role\x3dmenu] li:not(.divider):visible a", k);
                g.length && (k = g.index(g.filter(":focus")), 38 == d.keyCode && 0 < k && k--, 40 == d.keyCode && k < g.length - 1 && k++, ~k || (k = 0), g.eq(k).focus())
            }
        }
    };
    var k = a.fn.dropdown;
    a.fn.dropdown = function(c) {
        return this.each(function() {
            var k = a(this),
                B = k.data("dropdown");
            B || k.data("dropdown", B = new g(this));
            "string" == typeof c && B[c].call(k)
        })
    };
    a.fn.dropdown.Constructor = g;
    a.fn.dropdown.noConflict = function() {
        a.fn.dropdown = k;
        return this
    };
    a(document).on("click.dropdown.data-api", u).on("click.dropdown.data-api", ".dropdown form", function(a) {
        a.stopPropagation()
    }).on("click.dropdown-menu", function(a) {
        a.stopPropagation()
    }).on("click.dropdown.data-api", c, g.prototype.toggle).on("keydown.dropdown.data-api",
        c + ", [role\x3dmenu]", g.prototype.keydown)
}(window.jQuery);
! function(a) {
    function u(c, g) {
        var k = a.proxy(this.process, this),
            d = a(c).is("body") ? a(window) : a(c),
            n;
        this.options = a.extend({}, a.fn.scrollspy.defaults, g);
        this.$scrollElement = d.on("scroll.scroll-spy.data-api", k);
        this.selector = (this.options.target || (n = a(c).attr("href")) && n.replace(/.*(?=#[^\s]+$)/, "") || "") + " .nav li \x3e a";
        this.$body = a("body");
        this.refresh();
        this.process()
    }
    u.prototype = {
        constructor: u,
        refresh: function() {
            var c = this;
            this.offsets = a([]);
            this.targets = a([]);
            this.$body.find(this.selector).map(function() {
                var g =
                    a(this),
                    g = g.data("target") || g.attr("href"),
                    k = /^#\w/.test(g) && a(g);
                return k && k.length && [
                    [k.position().top + (!a.isWindow(c.$scrollElement.get(0)) && c.$scrollElement.scrollTop()), g]
                ] || null
            }).sort(function(a, c) {
                return a[0] - c[0]
            }).each(function() {
                c.offsets.push(this[0]);
                c.targets.push(this[1])
            })
        },
        process: function() {
            var a = this.$scrollElement.scrollTop() + this.options.offset,
                g = (this.$scrollElement[0].scrollHeight || this.$body[0].scrollHeight) - this.$scrollElement.height(),
                k = this.offsets,
                d = this.targets,
                n = this.activeTarget,
                B;
            if (a >= g) return n != (B = d.last()[0]) && this.activate(B);
            for (B = k.length; B--;) n != d[B] && a >= k[B] && (!k[B + 1] || a <= k[B + 1]) && this.activate(d[B])
        },
        activate: function(c) {
            this.activeTarget = c;
            a(this.selector).parent(".active").removeClass("active");
            c = a(this.selector + '[data-target\x3d"' + c + '"],' + this.selector + '[href\x3d"' + c + '"]').parent("li").addClass("active");
            c.parent(".dropdown-menu").length && (c = c.closest("li.dropdown").addClass("active"));
            c.trigger("activate")
        }
    };
    var r = a.fn.scrollspy;
    a.fn.scrollspy = function(c) {
        return this.each(function() {
            var g =
                a(this),
                k = g.data("scrollspy"),
                d = "object" == typeof c && c;
            k || g.data("scrollspy", k = new u(this, d));
            if ("string" == typeof c) k[c]()
        })
    };
    a.fn.scrollspy.Constructor = u;
    a.fn.scrollspy.defaults = {
        offset: 10
    };
    a.fn.scrollspy.noConflict = function() {
        a.fn.scrollspy = r;
        return this
    };
    a(window).on("load", function() {
        a('[data-spy\x3d"scroll"]').each(function() {
            var c = a(this);
            c.scrollspy(c.data())
        })
    })
}(window.jQuery);
! function(a) {
    var u = function(c) {
        this.element = a(c)
    };
    u.prototype = {
        constructor: u,
        show: function() {
            var c = this.element,
                g = c.closest("ul:not(.dropdown-menu)"),
                k = c.attr("data-target"),
                d, n;
            k || (k = (k = c.attr("href")) && k.replace(/.*(?=#[^\s]*$)/, ""));
            c.parent("li").hasClass("active") || (d = g.find(".active:last a")[0], n = a.Event("show", {
                relatedTarget: d
            }), c.trigger(n), n.isDefaultPrevented() || (k = a(k), this.activate(c.parent("li"), g), this.activate(k, k.parent(), function() {
                c.trigger({
                    type: "shown",
                    relatedTarget: d
                })
            })))
        },
        activate: function(c,
            g, k) {
            function d() {
                n.removeClass("active").find("\x3e .dropdown-menu \x3e .active").removeClass("active");
                c.addClass("active");
                B ? (c[0].offsetWidth, c.addClass("in")) : c.removeClass("fade");
                c.parent(".dropdown-menu") && c.closest("li.dropdown").addClass("active");
                k && k()
            }
            var n = g.find("\x3e .active"),
                B = k && a.support.transition && n.hasClass("fade");
            B ? n.one(a.support.transition.end, d) : d();
            n.removeClass("in")
        }
    };
    var r = a.fn.tab;
    a.fn.tab = function(c) {
        return this.each(function() {
            var g = a(this),
                k = g.data("tab");
            k || g.data("tab",
                k = new u(this));
            if ("string" == typeof c) k[c]()
        })
    };
    a.fn.tab.Constructor = u;
    a.fn.tab.noConflict = function() {
        a.fn.tab = r;
        return this
    };
    a(document).on("click.tab.data-api", '[data-toggle\x3d"tab"], [data-toggle\x3d"pill"]', function(c) {
        c.preventDefault();
        a(this).tab("show")
    })
}(window.jQuery);
! function(a) {
    var u = function(a, g) {
        this.init("tooltip", a, g)
    };
    u.prototype = {
        constructor: u,
        init: function(c, g, k) {
            var d;
            this.type = c;
            this.$element = a(g);
            this.options = this.getOptions(k);
            this.enabled = !0;
            g = this.options.trigger.split(" ");
            for (k = g.length; k--;)
                if (d = g[k], "click" == d) this.$element.on("click." + this.type, this.options.selector, a.proxy(this.toggle, this));
                else "manual" != d && (c = "hover" == d ? "mouseenter" : "focus", d = "hover" == d ? "mouseleave" : "blur", this.$element.on(c + "." + this.type, this.options.selector, a.proxy(this.enter,
                    this)), this.$element.on(d + "." + this.type, this.options.selector, a.proxy(this.leave, this)));
            this.options.selector ? this._options = a.extend({}, this.options, {
                trigger: "manual",
                selector: ""
            }) : this.fixTitle()
        },
        getOptions: function(c) {
            c = a.extend({}, a.fn[this.type].defaults, this.$element.data(), c);
            c.delay && "number" == typeof c.delay && (c.delay = {
                show: c.delay,
                hide: c.delay
            });
            return c
        },
        enter: function(c) {
            var g = a.fn[this.type].defaults,
                k = {},
                d;
            this._options && a.each(this._options, function(a, c) {
                g[a] != c && (k[a] = c)
            }, this);
            d =
                a(c.currentTarget)[this.type](k).data(this.type);
            if (!d.options.delay || !d.options.delay.show) return d.show();
            clearTimeout(this.timeout);
            d.hoverState = "in";
            this.timeout = setTimeout(function() {
                "in" == d.hoverState && d.show()
            }, d.options.delay.show)
        },
        leave: function(c) {
            var g = a(c.currentTarget)[this.type](this._options).data(this.type);
            this.timeout && clearTimeout(this.timeout);
            if (!g.options.delay || !g.options.delay.hide) return g.hide();
            g.hoverState = "out";
            this.timeout = setTimeout(function() {
                "out" == g.hoverState &&
                    g.hide()
            }, g.options.delay.hide)
        },
        show: function() {
            var c, g, k, d, n;
            g = a.Event("show");
            if (this.hasContent() && this.enabled && (this.$element.trigger(g), !g.isDefaultPrevented())) {
                c = this.tip();
                this.setContent();
                this.options.animation && c.addClass("fade");
                d = "function" == typeof this.options.placement ? this.options.placement.call(this, c[0], this.$element[0]) : this.options.placement;
                c.detach().css({
                    top: 0,
                    left: 0,
                    display: "block"
                });
                this.options.container ? c.appendTo(this.options.container) : c.insertAfter(this.$element);
                g =
                    this.getPosition();
                k = c[0].offsetWidth;
                c = c[0].offsetHeight;
                switch (d) {
                    case "bottom":
                        n = {
                            top: g.top + g.height,
                            left: g.left + g.width / 2 - k / 2
                        };
                        break;
                    case "top":
                        n = {
                            top: g.top - c,
                            left: g.left + g.width / 2 - k / 2
                        };
                        break;
                    case "left":
                        n = {
                            top: g.top + g.height / 2 - c / 2,
                            left: g.left - k
                        };
                        break;
                    case "right":
                        n = {
                            top: g.top + g.height / 2 - c / 2,
                            left: g.left + g.width
                        }
                }
                this.applyPlacement(n, d);
                this.$element.trigger("shown")
            }
        },
        applyPlacement: function(a, g) {
            var k = this.tip(),
                d = k[0].offsetWidth,
                n = k[0].offsetHeight,
                B, r, u;
            k.offset(a).addClass(g).addClass("in");
            B = k[0].offsetWidth;
            r = k[0].offsetHeight;
            "top" == g && r != n && (a.top = a.top + n - r, u = !0);
            "bottom" == g || "top" == g ? (n = 0, 0 > a.left && (n = -2 * a.left, a.left = 0, k.offset(a), B = k[0].offsetWidth), this.replaceArrow(n - d + B, B, "left")) : this.replaceArrow(r - n, r, "top");
            u && k.offset(a)
        },
        replaceArrow: function(a, g, k) {
            this.arrow().css(k, a ? 50 * (1 - a / g) + "%" : "")
        },
        setContent: function() {
            var a = this.tip(),
                g = this.getTitle();
            a.find(".tooltip-inner")[this.options.html ? "html" : "text"](g);
            a.removeClass("fade in top bottom left right")
        },
        hide: function() {
            function c() {
                var c =
                    setTimeout(function() {
                        g.off(a.support.transition.end).detach()
                    }, 500);
                g.one(a.support.transition.end, function() {
                    clearTimeout(c);
                    g.detach()
                })
            }
            var g = this.tip(),
                k = a.Event("hide");
            this.$element.trigger(k);
            if (!k.isDefaultPrevented()) return g.removeClass("in"), a.support.transition && this.$tip.hasClass("fade") ? c() : g.detach(), this.$element.trigger("hidden"), this
        },
        fixTitle: function() {
            var a = this.$element;
            if (a.attr("title") || "string" != typeof a.attr("data-original-title")) a.attr("data-original-title", a.attr("title") ||
                "").attr("title", "")
        },
        hasContent: function() {
            return this.getTitle()
        },
        getPosition: function() {
            var c = this.$element[0];
            return a.extend({}, "function" == typeof c.getBoundingClientRect ? c.getBoundingClientRect() : {
                width: c.offsetWidth,
                height: c.offsetHeight
            }, this.$element.offset())
        },
        getTitle: function() {
            var a = this.$element,
                g = this.options;
            return a.attr("data-original-title") || ("function" == typeof g.title ? g.title.call(a[0]) : g.title)
        },
        tip: function() {
            return this.$tip = this.$tip || a(this.options.template)
        },
        arrow: function() {
            return this.$arrow =
                this.$arrow || this.tip().find(".tooltip-arrow")
        },
        validate: function() {
            this.$element[0].parentNode || (this.hide(), this.options = this.$element = null)
        },
        enable: function() {
            this.enabled = !0
        },
        disable: function() {
            this.enabled = !1
        },
        toggleEnabled: function() {
            this.enabled = !this.enabled
        },
        toggle: function(c) {
            c = c ? a(c.currentTarget)[this.type](this._options).data(this.type) : this;
            c.tip().hasClass("in") ? c.hide() : c.show()
        },
        destroy: function() {
            this.hide().$element.off("." + this.type).removeData(this.type)
        }
    };
    var r = a.fn.tooltip;
    a.fn.tooltip = function(c) {
        return this.each(function() {
            var g = a(this),
                k = g.data("tooltip"),
                d = "object" == typeof c && c;
            k || g.data("tooltip", k = new u(this, d));
            if ("string" == typeof c) k[c]()
        })
    };
    a.fn.tooltip.Constructor = u;
    a.fn.tooltip.defaults = {
        animation: !0,
        placement: "top",
        selector: !1,
        template: '\x3cdiv class\x3d"tooltip"\x3e\x3cdiv class\x3d"tooltip-arrow"\x3e\x3c/div\x3e\x3cdiv class\x3d"tooltip-inner"\x3e\x3c/div\x3e\x3c/div\x3e',
        trigger: "hover focus",
        title: "",
        delay: 0,
        html: !1,
        container: !1
    };
    a.fn.tooltip.noConflict =
        function() {
            a.fn.tooltip = r;
            return this
        }
}(window.jQuery);
! function(a) {
    var u = function(a, g) {
        this.init("popover", a, g)
    };
    u.prototype = a.extend({}, a.fn.tooltip.Constructor.prototype, {
        constructor: u,
        setContent: function() {
            var a = this.tip(),
                g = this.getTitle(),
                k = this.getContent();
            a.find(".popover-title")[this.options.html ? "html" : "text"](g);
            a.find(".popover-content")[this.options.html ? "html" : "text"](k);
            a.removeClass("fade top bottom left right in")
        },
        hasContent: function() {
            return this.getTitle() || this.getContent()
        },
        getContent: function() {
            var a = this.$element,
                g = this.options;
            return ("function" == typeof g.content ? g.content.call(a[0]) : g.content) || a.attr("data-content")
        },
        tip: function() {
            this.$tip || (this.$tip = a(this.options.template));
            return this.$tip
        },
        destroy: function() {
            this.hide().$element.off("." + this.type).removeData(this.type)
        }
    });
    var r = a.fn.popover;
    a.fn.popover = function(c) {
        return this.each(function() {
            var g = a(this),
                k = g.data("popover"),
                d = "object" == typeof c && c;
            k || g.data("popover", k = new u(this, d));
            if ("string" == typeof c) k[c]()
        })
    };
    a.fn.popover.Constructor = u;
    a.fn.popover.defaults =
        a.extend({}, a.fn.tooltip.defaults, {
            placement: "right",
            trigger: "click",
            content: "",
            template: '\x3cdiv class\x3d"popover"\x3e\x3cdiv class\x3d"arrow"\x3e\x3c/div\x3e\x3ch3 class\x3d"popover-title"\x3e\x3c/h3\x3e\x3cdiv class\x3d"popover-content"\x3e\x3c/div\x3e\x3c/div\x3e'
        });
    a.fn.popover.noConflict = function() {
        a.fn.popover = r;
        return this
    }
}(window.jQuery);
! function(a) {
    var u = function(c, g) {
        this.$element = a(c);
        this.options = a.extend({}, a.fn.button.defaults, g)
    };
    u.prototype.setState = function(a) {
        var g = this.$element,
            k = g.data(),
            d = g.is("input") ? "val" : "html";
        a += "Text";
        k.resetText || g.data("resetText", g[d]());
        g[d](k[a] || this.options[a]);
        setTimeout(function() {
            "loadingText" == a ? g.addClass("disabled").attr("disabled", "disabled") : g.removeClass("disabled").removeAttr("disabled")
        }, 0)
    };
    u.prototype.toggle = function() {
        var a = this.$element.closest('[data-toggle\x3d"buttons-radio"]');
        a && a.find(".active").removeClass("active");
        this.$element.toggleClass("active")
    };
    var r = a.fn.button;
    a.fn.button = function(c) {
        return this.each(function() {
            var g = a(this),
                k = g.data("button"),
                d = "object" == typeof c && c;
            k || g.data("button", k = new u(this, d));
            "toggle" == c ? k.toggle() : c && k.setState(c)
        })
    };
    a.fn.button.defaults = {
        loadingText: "loading..."
    };
    a.fn.button.Constructor = u;
    a.fn.button.noConflict = function() {
        a.fn.button = r;
        return this
    };
    a(document).on("click.button.data-api", "[data-toggle^\x3dbutton]", function(c) {
        c =
            a(c.target);
        c.hasClass("btn") || (c = c.closest(".btn"));
        c.button("toggle")
    })
}(window.jQuery);
! function(a) {
    var u = function(c, g) {
        this.$element = a(c);
        this.options = a.extend({}, a.fn.collapse.defaults, g);
        this.options.parent && (this.$parent = a(this.options.parent));
        this.options.toggle && this.toggle()
    };
    u.prototype = {
        constructor: u,
        dimension: function() {
            return this.$element.hasClass("width") ? "width" : "height"
        },
        show: function() {
            var c, g, k, d;
            if (!this.transitioning && !this.$element.hasClass("in")) {
                c = this.dimension();
                g = a.camelCase(["scroll", c].join("-"));
                if ((k = this.$parent && this.$parent.find("\x3e .accordion-group \x3e .in")) &&
                    k.length) {
                    if ((d = k.data("collapse")) && d.transitioning) return;
                    k.collapse("hide");
                    d || k.data("collapse", null)
                }
                this.$element[c](0);
                this.transition("addClass", a.Event("show"), "shown");
                a.support.transition && this.$element[c](this.$element[0][g])
            }
        },
        hide: function() {
            var c;
            !this.transitioning && this.$element.hasClass("in") && (c = this.dimension(), this.reset(this.$element[c]()), this.transition("removeClass", a.Event("hide"), "hidden"), this.$element[c](0))
        },
        reset: function(a) {
            var g = this.dimension();
            this.$element.removeClass("collapse")[g](a ||
                "auto")[0].offsetWidth;
            this.$element[null !== a ? "addClass" : "removeClass"]("collapse");
            return this
        },
        transition: function(c, g, k) {
            var d = this,
                n = function() {
                    "show" == g.type && d.reset();
                    d.transitioning = 0;
                    d.$element.trigger(k)
                };
            this.$element.trigger(g);
            g.isDefaultPrevented() || (this.transitioning = 1, this.$element[c]("in"), a.support.transition && this.$element.hasClass("collapse") ? this.$element.one(a.support.transition.end, n) : n())
        },
        toggle: function() {
            this[this.$element.hasClass("in") ? "hide" : "show"]()
        }
    };
    var r = a.fn.collapse;
    a.fn.collapse = function(c) {
        return this.each(function() {
            var g = a(this),
                k = g.data("collapse"),
                d = a.extend({}, a.fn.collapse.defaults, g.data(), "object" == typeof c && c);
            k || g.data("collapse", k = new u(this, d));
            if ("string" == typeof c) k[c]()
        })
    };
    a.fn.collapse.defaults = {
        toggle: !0
    };
    a.fn.collapse.Constructor = u;
    a.fn.collapse.noConflict = function() {
        a.fn.collapse = r;
        return this
    };
    a(document).on("click.collapse.data-api", "[data-toggle\x3dcollapse]", function(c) {
        var g = a(this),
            k;
        c = g.attr("data-target") || c.preventDefault() || (k =
            g.attr("href")) && k.replace(/.*(?=#[^\s]+$)/, "");
        k = a(c).data("collapse") ? "toggle" : g.data();
        g[a(c).hasClass("in") ? "addClass" : "removeClass"]("collapsed");
        a(c).collapse(k)
    })
}(window.jQuery);
! function(a) {
    var u = function(c, g) {
        this.$element = a(c);
        this.$indicators = this.$element.find(".carousel-indicators");
        this.options = g;
        "hover" == this.options.pause && this.$element.on("mouseenter", a.proxy(this.pause, this)).on("mouseleave", a.proxy(this.cycle, this))
    };
    u.prototype = {
        cycle: function(c) {
            c || (this.paused = !1);
            this.interval && clearInterval(this.interval);
            this.options.interval && !this.paused && (this.interval = setInterval(a.proxy(this.next, this), this.options.interval));
            return this
        },
        getActiveIndex: function() {
            this.$active =
                this.$element.find(".item.active");
            this.$items = this.$active.parent().children();
            return this.$items.index(this.$active)
        },
        to: function(c) {
            var g = this.getActiveIndex(),
                k = this;
            if (!(c > this.$items.length - 1 || 0 > c)) return this.sliding ? this.$element.one("slid", function() {
                k.to(c)
            }) : g == c ? this.pause().cycle() : this.slide(c > g ? "next" : "prev", a(this.$items[c]))
        },
        pause: function(c) {
            c || (this.paused = !0);
            this.$element.find(".next, .prev").length && a.support.transition.end && (this.$element.trigger(a.support.transition.end),
                this.cycle(!0));
            clearInterval(this.interval);
            this.interval = null;
            return this
        },
        next: function() {
            if (!this.sliding) return this.slide("next")
        },
        prev: function() {
            if (!this.sliding) return this.slide("prev")
        },
        slide: function(c, g) {
            var k = this.$element.find(".item.active"),
                d = g || k[c](),
                n = this.interval,
                B = "next" == c ? "left" : "right",
                r = "next" == c ? "first" : "last",
                u = this;
            this.sliding = !0;
            n && this.pause();
            d = d.length ? d : this.$element.find(".item")[r]();
            r = a.Event("slide", {
                relatedTarget: d[0],
                direction: B
            });
            if (!d.hasClass("active")) {
                this.$indicators.length &&
                    (this.$indicators.find(".active").removeClass("active"), this.$element.one("slid", function() {
                        var c = a(u.$indicators.children()[u.getActiveIndex()]);
                        c && c.addClass("active")
                    }));
                if (a.support.transition && this.$element.hasClass("slide")) {
                    this.$element.trigger(r);
                    if (r.isDefaultPrevented()) return;
                    d.addClass(c);
                    d[0].offsetWidth;
                    k.addClass(B);
                    d.addClass(B);
                    this.$element.one(a.support.transition.end, function() {
                        d.removeClass([c, B].join(" ")).addClass("active");
                        k.removeClass(["active", B].join(" "));
                        u.sliding = !1;
                        setTimeout(function() {
                            u.$element.trigger("slid")
                        }, 0)
                    })
                } else {
                    this.$element.trigger(r);
                    if (r.isDefaultPrevented()) return;
                    k.removeClass("active");
                    d.addClass("active");
                    this.sliding = !1;
                    this.$element.trigger("slid")
                }
                n && this.cycle();
                return this
            }
        }
    };
    var r = a.fn.carousel;
    a.fn.carousel = function(c) {
        return this.each(function() {
            var g = a(this),
                k = g.data("carousel"),
                d = a.extend({}, a.fn.carousel.defaults, "object" == typeof c && c),
                n = "string" == typeof c ? c : d.slide;
            k || g.data("carousel", k = new u(this, d));
            if ("number" == typeof c) k.to(c);
            else if (n) k[n]();
            else d.interval && k.pause().cycle()
        })
    };
    a.fn.carousel.defaults = {
        interval: 5E3,
        pause: "hover"
    };
    a.fn.carousel.Constructor = u;
    a.fn.carousel.noConflict = function() {
        a.fn.carousel = r;
        return this
    };
    a(document).on("click.carousel.data-api", "[data-slide], [data-slide-to]", function(c) {
        var g = a(this),
            k, d = a(g.attr("data-target") || (k = g.attr("href")) && k.replace(/.*(?=#[^\s]+$)/, ""));
        k = a.extend({}, d.data(), g.data());
        var n;
        d.carousel(k);
        (n = g.attr("data-slide-to")) && d.data("carousel").pause().to(n).cycle();
        c.preventDefault()
    })
}(window.jQuery);
! function(a) {
    var u = function(c, g) {
        this.$element = a(c);
        this.options = a.extend({}, a.fn.typeahead.defaults, g);
        this.matcher = this.options.matcher || this.matcher;
        this.sorter = this.options.sorter || this.sorter;
        this.highlighter = this.options.highlighter || this.highlighter;
        this.updater = this.options.updater || this.updater;
        this.source = this.options.source;
        this.$menu = a(this.options.menu);
        this.shown = !1;
        this.listen()
    };
    u.prototype = {
        constructor: u,
        select: function() {
            var a = this.$menu.find(".active").attr("data-value");
            this.$element.val(this.updater(a)).change();
            return this.hide()
        },
        updater: function(a) {
            return a
        },
        show: function() {
            if (0 < this.$element.closest(".modal").length) {
                var c = a.extend({}, this.$element.offset(), {
                    height: this.$element[0].offsetHeight
                });
                this.$menu.insertAfter(this.$element).css({
                    top: 0,
                    left: 0,
                    position: "fixed"
                }).offset({
                    top: c.top + c.height,
                    left: c.left
                }).show()
            } else c = a.extend({}, this.$element.position(), {
                height: this.$element[0].offsetHeight
            }), this.$menu.insertAfter(this.$element).css({
                top: c.top + c.height,
                left: c.left
            }).show();
            this.shown = !0;
            return this
        },
        hide: function() {
            this.$menu.hide();
            this.shown = !1;
            return this
        },
        lookup: function(c) {
            this.query = this.$element.val();
            return !this.query || this.query.length < this.options.minLength ? this.shown ? this.hide() : this : (c = a.isFunction(this.source) ? this.source(this.query, a.proxy(this.process, this)) : this.source) ? this.process(c) : this
        },
        process: function(c) {
            var g = this;
            c = a.grep(c, function(a) {
                return g.matcher(a)
            });
            c = this.sorter(c);
            return !c.length ? this.shown ? this.hide() : this : this.render(c.slice(0, this.options.items)).show()
        },
        matcher: function(a) {
            return ~a.toLowerCase().indexOf(this.query.toLowerCase())
        },
        sorter: function(a) {
            for (var g = [], k = [], d = [], n; n = a.shift();) n.toLowerCase().indexOf(this.query.toLowerCase()) ? ~n.indexOf(this.query) ? k.push(n) : d.push(n) : g.push(n);
            return g.concat(k, d)
        },
        highlighter: function(a) {
            var g = this.query.replace(/[\-\[\]{}()*+?.,\\\^$|#\s]/g, "\\$\x26");
            return a.replace(RegExp("(" + g + ")", "ig"), function(a, c) {
                return "\x3cstrong\x3e" + c + "\x3c/strong\x3e"
            })
        },
        render: function(c) {
            var g = this;
            c = a(c).map(function(c,
                d) {
                c = a(g.options.item).attr("data-value", d);
                c.find("a").html(g.highlighter(d));
                return c[0]
            });
            c.first().addClass("active");
            this.$menu.html(c);
            return this
        },
        next: function(c) {
            c = this.$menu.find(".active").removeClass("active").next();
            c.length || (c = a(this.$menu.find("li")[0]));
            c.addClass("active")
        },
        prev: function(a) {
            a = this.$menu.find(".active").removeClass("active").prev();
            a.length || (a = this.$menu.find("li").last());
            a.addClass("active")
        },
        listen: function() {
            this.$element.on("focus", a.proxy(this.focus, this)).on("blur",
                a.proxy(this.blur, this)).on("keypress", a.proxy(this.keypress, this)).on("keyup", a.proxy(this.keyup, this));
            if (this.eventSupported("keydown")) this.$element.on("keydown", a.proxy(this.keydown, this));
            this.$menu.on("click", a.proxy(this.click, this)).on("mouseenter", "li", a.proxy(this.mouseenter, this)).on("mouseleave", "li", a.proxy(this.mouseleave, this))
        },
        eventSupported: function(a) {
            var g = a in this.$element;
            g || (this.$element.setAttribute(a, "return;"), g = "function" === typeof this.$element[a]);
            return g
        },
        move: function(a) {
            if (this.shown) {
                switch (a.keyCode) {
                    case 9:
                    case 13:
                    case 27:
                        a.preventDefault();
                        break;
                    case 38:
                        a.preventDefault();
                        this.prev();
                        break;
                    case 40:
                        a.preventDefault(), this.next()
                }
                a.stopPropagation()
            }
        },
        keydown: function(c) {
            this.suppressKeyPressRepeat = ~a.inArray(c.keyCode, [40, 38, 9, 13, 27]);
            this.move(c)
        },
        keypress: function(a) {
            this.suppressKeyPressRepeat || this.move(a)
        },
        keyup: function(a) {
            switch (a.keyCode) {
                case 40:
                case 38:
                case 16:
                case 17:
                case 18:
                    break;
                case 9:
                case 13:
                    if (!this.shown) return;
                    this.select();
                    break;
                case 27:
                    if (!this.shown) return;
                    this.hide();
                    break;
                default:
                    this.lookup()
            }
            a.stopPropagation();
            a.preventDefault()
        },
        focus: function(a) {
            this.focused = !0
        },
        blur: function(a) {
            this.focused = !1;
            !this.mousedover && this.shown && this.hide()
        },
        click: function(a) {
            a.stopPropagation();
            a.preventDefault();
            this.select();
            this.$element.focus()
        },
        mouseenter: function(c) {
            this.mousedover = !0;
            this.$menu.find(".active").removeClass("active");
            a(c.currentTarget).addClass("active")
        },
        mouseleave: function(a) {
            this.mousedover = !1;
            !this.focused && this.shown && this.hide()
        }
    };
    var r = a.fn.typeahead;
    a.fn.typeahead = function(c) {
        return this.each(function() {
            var g =
                a(this),
                k = g.data("typeahead"),
                d = "object" == typeof c && c;
            k || g.data("typeahead", k = new u(this, d));
            if ("string" == typeof c) k[c]()
        })
    };
    a.fn.typeahead.defaults = {
        source: [],
        items: 8,
        menu: '\x3cul class\x3d"typeahead dropdown-menu"\x3e\x3c/ul\x3e',
        item: '\x3cli\x3e\x3ca href\x3d"#"\x3e\x3c/a\x3e\x3c/li\x3e',
        minLength: 1
    };
    a.fn.typeahead.Constructor = u;
    a.fn.typeahead.noConflict = function() {
        a.fn.typeahead = r;
        return this
    };
    a(document).on("focus.typeahead.data-api", '[data-provide\x3d"typeahead"]', function(c) {
        c = a(this);
        c.data("typeahead") ||
            c.typeahead(c.data())
    })
}(window.jQuery);
(function(a) {
    function u(a, c, g) {
        if ((a[c] || a[g]) && a[c] === a[g]) throw Error("(Link) '" + c + "' can't match '" + g + "'.'");
    }

    function r(c) {
        void 0 === c && (c = {});
        if ("object" !== typeof c) throw Error("(Format) 'format' option must be an object.");
        var n = {};
        a(g).each(function(a, g) {
            if (void 0 === c[g]) n[g] = k[a];
            else if (typeof c[g] === typeof k[a]) {
                if ("decimals" === g && (0 > c[g] || 7 < c[g])) throw Error("(Format) 'format.decimals' option must be between 0 and 7.");
                n[g] = c[g]
            } else throw Error("(Format) 'format." + g + "' must be a " + typeof k[a] +
                ".");
        });
        u(n, "mark", "thousand");
        u(n, "prefix", "negative");
        u(n, "prefix", "negativeBefore");
        this.settings = n
    }

    function c(d, g) {
        "object" !== typeof d && a.error("(Link) Initialize with an object.");
        return new c.prototype.init(d.target || function() {}, d.method, d.format || {}, g)
    }
    var g = "decimals mark thousand prefix postfix encoder decoder negative negativeBefore to from".split(" "),
        k = [2, ".", "", "", "", function(a) {
            return a
        }, function(a) {
            return a
        }, "-", "", function(a) {
            return a
        }, function(a) {
            return a
        }];
    r.prototype.v = function(a) {
        return this.settings[a]
    };
    r.prototype.to = function(a) {
        function c(a) {
            return a.split("").reverse().join("")
        }
        a = this.v("encoder")(a);
        var g = this.v("decimals"),
            k = "",
            r = "",
            u = "",
            z = "";
        0 === parseFloat(a.toFixed(g)) && (a = "0");
        0 > a && (k = this.v("negative"), r = this.v("negativeBefore"));
        a = Math.abs(a).toFixed(g).toString();
        a = a.split(".");
        this.v("thousand") ? (u = c(a[0]).match(/.{1,3}/g), u = c(u.join(c(this.v("thousand"))))) : u = a[0];
        this.v("mark") && 1 < a.length && (z = this.v("mark") + a[1]);
        return this.v("to")(r + this.v("prefix") + k + u + z + this.v("postfix"))
    };
									
					   
																	
		 
			  
												  
							  
						 
																	 
											
															 
																								
																																		   
												 
								
	  
    r.prototype.from =
        function(a) {
            function c(a) {
                return a.replace(/[\-\/\\\^$*+?.()|\[\]{}]/g, "\\$\x26")
            }
            var g;
            if (null === a || void 0 === a) return !1;
            a = this.v("from")(a);
            a = a.toString();
            g = a.replace(RegExp("^" + c(this.v("negativeBefore"))), "");
            a !== g ? (a = g, g = "-") : g = "";
            a = a.replace(RegExp("^" + c(this.v("prefix"))), "");
            this.v("negative") && (g = "", a = a.replace(RegExp("^" + c(this.v("negative"))), "-"));
            a = a.replace(RegExp(c(this.v("postfix")) + "$"), "").replace(RegExp(c(this.v("thousand")), "g"), "").replace(this.v("mark"), ".");
            a = this.v("decoder")(parseFloat(g +
                a));
            return isNaN(a) ? !1 : a
        };
    c.prototype.setTooltip = function(c, g) {
        this.method = g || "html";
        this.el = a(c.replace("-tooltip-", "") || "\x3cdiv/\x3e")[0]
    };
    c.prototype.setHidden = function(a) {
        this.method = "val";
        this.el = document.createElement("input");
        this.el.name = a;
        this.el.type = "hidden"
    };
    c.prototype.setField = function(c) {
        function g(a, c, d) {
            return [d ? a : c, d ? c : a]
        }
        var k = this;
        this.method = "val";
        this.target = c.on("change", function(c) {
            k.obj.val(g(null, a(c.target).val(), k.N), {
                link: k,
                set: !0
            })
        })
    };
    c.prototype.init = function(c, g, k,
        r) {
        this.formatting = k;
        this.update = !r;
        if ("string" === typeof c && 0 === c.indexOf("-tooltip-")) this.setTooltip(c, g);
        else if ("string" === typeof c && 0 !== c.indexOf("-")) this.setHidden(c);
        else if ("function" === typeof c) this.target = !1, this.method = c;
        else {
            if (c instanceof a || a.zepto && a.zepto.isZ(c)) {
                if (!g) {
                    if (c.is("input, select, textarea")) {
                        this.setField(c);
                        return
                    }
                    g = "html"
                }
                if ("function" === typeof g || "string" === typeof g && c[g]) {
                    this.method = g;
                    this.target = c;
                    return
                }
            }
            throw new RangeError("(Link) Invalid Link.");
        }
    };
											  
									   
																																					   
												  
	  
    c.prototype.write =
        function(a, c, g, k) {
            if (!(this.update && !1 === k))
                if (this.actual = a, this.saved = a = this.format(a), "function" === typeof this.method) this.method.call(this.target[0] || g[0], a, c, g);
                else this.target[this.method](a, c, g)
        };
    c.prototype.setFormatting = function(c) {
        this.formatting = new r(a.extend({}, c, this.formatting instanceof r ? this.formatting.settings : this.formatting))
    };
    c.prototype.setObject = function(a) {
        this.obj = a
    };
    c.prototype.setIndex = function(a) {
        this.N = a
    };
    c.prototype.format = function(a) {
        return this.formatting.to(a)
    };
    c.prototype.getValue = function(a) {
        return this.formatting.from(a)
    };
    c.prototype.init.prototype = c.prototype;
    a.Link = c
})(window.jQuery || window.Zepto);
(function(a) {
    function u(a) {
        return Math.max(Math.min(a, 100), 0)
    }

    function r(a) {
        return "number" === typeof a && !isNaN(a) && isFinite(a)
    }

    function c(a, c, d) {
        a.addClass(c);
        setTimeout(function() {
            a.removeClass(c)
        }, d)
    }

    function g(a, c) {
        return 100 * c / (a[1] - a[0])
    }

    function k(a, c) {
        if (c >= a.xVal.slice(-1)[0]) return 100;
        for (var d = 1, h, m, k; c >= a.xVal[d];) d++;
        h = a.xVal[d - 1];
        m = a.xVal[d];
        k = a.xPct[d - 1];
        d = a.xPct[d];
        h = [h, m];
        h = g(h, 0 > h[0] ? c + Math.abs(h[0]) : c - h[0]);
        return k + h / (100 / (d - k))
    }

    function d(a, c) {
        if (100 <= c) return a.xVal.slice(-1)[0];
        for (var d = 1, h, m, g; c >= a.xPct[d];) d++;
        h = a.xVal[d - 1];
        m = a.xVal[d];
        g = a.xPct[d - 1];
        h = [h, m];
        return (c - g) * (100 / (a.xPct[d] - g)) * (h[1] - h[0]) / 100 + h[0]
    }

    function n(a, c) {
        for (var d = 1, h;
            (a.dir ? 100 - c : c) >= a.xPct[d];) d++;
        return a.snap ? (h = a.xPct[d - 1], d = a.xPct[d], c - h > (d - h) / 2 ? d : h) : !a.xSteps[d - 1] ? c : a.xPct[d - 1] + Math.round((c - a.xPct[d - 1]) / a.xSteps[d - 1]) * a.xSteps[d - 1]
    }

    function B(a, c) {
        if (!r(c)) throw Error("noUiSlider: 'step' is not numeric.");
        a.xSteps[0] = c
    }

    function C(c, d) {
        if ("object" !== typeof d || a.isArray(d)) throw Error("noUiSlider: 'range' is not an object.");
        if (void 0 === d.min || void 0 === d.max) throw Error("noUiSlider: Missing 'min' or 'max' in 'range'.");
        a.each(d, function(d, h) {
            var m;
            "number" === typeof h && (h = [h]);
            if (!a.isArray(h)) throw Error("noUiSlider: 'range' contains invalid value.");
            m = "min" === d ? 0 : "max" === d ? 100 : parseFloat(d);
            if (!r(m) || !r(h[0])) throw Error("noUiSlider: 'range' value isn't numeric.");
            c.xPct.push(m);
            c.xVal.push(h[0]);
            m ? c.xSteps.push(isNaN(h[1]) ? !1 : h[1]) : isNaN(h[1]) || (c.xSteps[0] = h[1])
        });
        a.each(c.xSteps, function(a, d) {
            if (!d) return !0;
            c.xSteps[a] =
                g([c.xVal[a], c.xVal[a + 1]], d) / (100 / (c.xPct[a + 1] - c.xPct[a]))
        })
    }

    function w(c, d) {
        "number" === typeof d && (d = [d]);
        if (!a.isArray(d) || !d.length || 2 < d.length) throw Error("noUiSlider: 'start' option is incorrect.");
        c.handles = d.length;
        c.start = d
    }

    function x(a, c) {
        a.snap = c;
        if ("boolean" !== typeof c) throw Error("noUiSlider: 'snap' option must be a boolean.");
    }

    function z(a, c) {
        if ("lower" === c && 1 === a.handles) a.connect = 1;
        else if ("upper" === c && 1 === a.handles) a.connect = 2;
        else if (!0 === c && 2 === a.handles) a.connect = 3;
        else if (!1 ===
            c) a.connect = 0;
        else throw Error("noUiSlider: 'connect' option doesn't match handle count.");
    }

    function D(a, c) {
        switch (c) {
            case "horizontal":
                a.ort = 0;
                break;
            case "vertical":
                a.ort = 1;
                break;
            default:
                throw Error("noUiSlider: 'orientation' option is invalid.");
        }
    }

    function t(a, c) {
        if (2 < a.xPct.length) throw Error("noUiSlider: 'margin' option is only supported on linear sliders.");
        a.margin = g(a.xVal, c);
        if (!r(c)) throw Error("noUiSlider: 'margin' option must be numeric.");
    }

    function s(a, c) {
        switch (c) {
            case "ltr":
                a.dir = 0;
                break;
            case "rtl":
                a.dir = 1;
                a.connect = [0, 2, 1, 3][a.connect];
                break;
            default:
                throw Error("noUiSlider: 'direction' option was not recognized.");
        }
    }

    function h(a, c) {
        if ("string" !== typeof c) throw Error("noUiSlider: 'behaviour' must be a string containing options.");
        var d = 0 <= c.indexOf("tap"),
            h = 0 <= c.indexOf("extend"),
            m = 0 <= c.indexOf("drag"),
            g = 0 <= c.indexOf("fixed"),
            k = 0 <= c.indexOf("snap");
        a.events = {
            tap: d || k,
            extend: h,
            drag: m,
            fixed: g,
            snap: k
        }
    }

    function F(c, d, h) {
        c.ser = [d.lower, d.upper];
        c.formatting = d.format;
        a.each(c.ser,
            function(c, m) {
                if (!a.isArray(m)) throw Error("noUiSlider: 'serialization." + (!c ? "lower" : "upper") + "' must be an array.");
                a.each(m, function() {
                    if (!(this instanceof a.Link)) throw Error("noUiSlider: 'serialization." + (!c ? "lower" : "upper") + "' can only contain Link instances.");
                    this.setIndex(c);
                    this.setObject(h);
                    this.setFormatting(d.format)
                })
            });
        c.dir && 1 < c.handles && c.ser.reverse()
    }

    function I(c, d) {
        var m = {
                xPct: [],
                xVal: [],
                xSteps: [!1],
                margin: 0
            },
            g;
        g = {
            step: {
                r: !1,
                t: B
            },
            start: {
                r: !0,
                t: w
            },
            connect: {
                r: !0,
                t: z
            },
            direction: {
                r: !0,
                t: s
            },
            range: {
                r: !0,
                t: C
            },
            snap: {
                r: !1,
                t: x
            },
            orientation: {
                r: !1,
                t: D
            },
            margin: {
                r: !1,
                t: t
            },
            behaviour: {
                r: !0,
                t: h
            },
            serialization: {
                r: !0,
                t: F
            }
        };
        c = a.extend({
            connect: !1,
            direction: "ltr",
            behaviour: "tap",
            orientation: "horizontal"
        }, c);
        c.serialization = a.extend({
            lower: [],
            upper: [],
            format: {}
        }, c.serialization);
        a.each(g, function(a, h) {
            if (void 0 === c[a]) {
                if (h.r) throw Error("noUiSlider: '" + a + "' is required.");
                return !0
            }
            h.t(m, c[a], d)
        });
        m.style = m.ort ? "top" : "left";
        return m
    }

    function p(c, d) {
        var h = a("\x3cdiv\x3e\x3cdiv/\x3e\x3c/div\x3e").addClass(S[2]),
            m = ["-lower", "-upper"];
        c.dir && m.reverse();
        h.children().addClass(S[3] + " " + S[3] + m[d]);
        return h
    }

    function A(c, d) {
        d.el && (d = new a.Link({
            target: a(d.el).clone().appendTo(c),
            method: d.method,
            format: d.formatting
        }, !0));
        return d
    }

    function J(c, d) {
        var h, m = [];
        for (h = 0; h < c.handles; h++) {
            var g = m,
                k = h,
                p = c.ser[h],
                v = d[h].children(),
                s = c.formatting,
                n = void 0,
                N = [],
                n = new a.Link({}, !0);
            n.setFormatting(s);
            N.push(n);
            for (n = 0; n < p.length; n++) N.push(A(v, p[n]));
            g[k] = N
        }
        return m
    }

    function M(a, c, d) {
        switch (a) {
            case 1:
                c.addClass(S[7]);
                d[0].addClass(S[6]);
                break;
            case 3:
                d[1].addClass(S[6]);
            case 2:
                d[0].addClass(S[7]);
            case 0:
                c.addClass(S[6])
        }
    }

    function O(a, c) {
        var d, h = [];
        for (d = 0; d < a.handles; d++) h.push(p(a, d).appendTo(c));
        return h
    }

    function V(c, d) {
        d.addClass([S[0], S[8 + c.dir], S[4 + c.ort]].join(" "));
        return a("\x3cdiv/\x3e").appendTo(d).addClass(S[1])
    }

    function m(h, m, g) {
        function p() {
            return w[["width", "height"][m.ort]]()
        }

        function v(a) {
            var e, c = [D.val()];
            for (e = 0; e < a.length; e++) D.trigger(a[e], c)
        }

        function s(c, e, h) {
            var g = c[0] !== x[0][0] ? 1 : 0,
                k = B[0] + m.margin,
                p = B[1] - m.margin;
            h && 1 < x.length && (e = g ? Math.max(e, k) : Math.min(e, p));
            100 > e && (e = n(m, e));
            e = u(parseFloat(e.toFixed(7)));
            if (e === B[g]) return 1 === x.length ? !1 : e === k || e === p ? 0 : !1;
            c.css(m.style, e + "%");
            c.is(":first-child") && c.toggleClass(S[17], 50 < e);
            B[g] = e;
            m.dir && (e = 100 - e);
            a(z[g]).each(function() {
                this.write(d(m, e), c.children(), D)
            });
            return !0
        }

        function N(a, e, d) {
            d || c(D, S[14], 300);
            s(a, e, !1);
            v(["slide", "set", "change"])
        }

        function F(a, e, c, d) {
            a = a.replace(/\s/g, ".nui ") + ".nui";
            return e.on(a, function(a) {
                var e = D.attr("disabled");
                if (D.hasClass(S[14]) ||
                    !(void 0 === e || null === e)) return !1;
                a.preventDefault();
                var e = 0 === a.type.indexOf("touch"),
                    h = 0 === a.type.indexOf("mouse"),
                    g = 0 === a.type.indexOf("pointer"),
                    k, p, v = a;
                0 === a.type.indexOf("MSPointer") && (g = !0);
                a.originalEvent && (a = a.originalEvent);
                e && (k = a.changedTouches[0].pageX, p = a.changedTouches[0].pageY);
                if (h || g) !g && void 0 === window.pageXOffset && (window.pageXOffset = document.documentElement.scrollLeft, window.pageYOffset = document.documentElement.scrollTop), k = a.clientX + window.pageXOffset, p = a.clientY + window.pageYOffset;
                v.points = [k, p];
                v.cursor = h;
                a = v;
                a.calcPoint = a.points[m.ort];
                c(a, d)
            })
        }

        function I(a, e) {
            var c = e.handles || x,
                d, h = !1,
                h = 100 * (a.calcPoint - e.start) / p(),
                m = c[0][0] !== x[0][0] ? 1 : 0;
            var g = e.positions;
            d = h + g[0];
            h += g[1];
            1 < c.length ? (0 > d && (h += Math.abs(d)), 100 < h && (d -= h - 100), d = [u(d), u(h)]) : d = [d, h];
            h = s(c[0], d[m], 1 === c.length);
            1 < c.length && (h = s(c[1], d[m ? 0 : 1], !1) || h);
            h && v(["slide"])
        }

        function A(c) {
            a("." + S[15]).removeClass(S[15]);
            c.cursor && a("body").css("cursor", "").off(".nui");
            ha.off(".nui");
            D.removeClass(S[12]);
            v(["set", "change"])
        }

        function G(c, e) {
            1 === e.handles.length && e.handles[0].children().addClass(S[15]);
            c.stopPropagation();
            F(R.move, ha, I, {
                start: c.calcPoint,
                handles: e.handles,
                positions: [B[0], B[x.length - 1]]
            });
            F(R.end, ha, A, null);
            c.cursor && (a("body").css("cursor", a(c.target).css("cursor")), 1 < x.length && D.addClass(S[12]), a("body").on("selectstart.nui", !1))
        }

        function t(c) {
            var e = c.calcPoint,
                d = 0;
            c.stopPropagation();
            a.each(x, function() {
                d += this.offset()[m.style]
            });
            d = e < d / 2 || 1 === x.length ? 0 : 1;
            e -= w.offset()[m.style];
            e = 100 * e / p();
            N(x[d], e,
                m.events.snap);
            m.events.snap && G(c, {
                handles: [x[d]]
            })
        }

        function r(a) {
            var e = (a = a.calcPoint < w.offset()[m.style]) ? 0 : 100;
            a = a ? 0 : x.length - 1;
            N(x[a], e, !1)
        }
        var D = a(h),
            B = [-1, -1],
            w, z, x;
        if (D.hasClass(S[0])) throw Error("Slider was already initialized.");
        w = V(m, D);
        x = O(m, w);
        z = J(m, x);
        M(m.connect, D, x);
        (function(a) {
            var e;
            if (!a.fixed)
                for (e = 0; e < x.length; e++) F(R.start, x[e].children(), G, {
                    handles: [x[e]]
                });
            a.tap && F(R.start, w, t, {
                handles: x
            });
            a.extend && (D.addClass(S[16]), a.tap && F(R.start, D, r, {
                handles: x
            }));
            a.drag && (e = w.find("." +
                S[7]).addClass(S[10]), a.fixed && (e = e.add(w.children().not(e).children())), F(R.start, e, G, {
                handles: x
            }))
        })(m.events);
        h.vSet = function() {
            var d = Array.prototype.slice.call(arguments, 0),
                e, h, g, p, n, N, F = a.isArray(d[0]) ? d[0] : [d[0]];
            "object" === typeof d[1] ? (e = d[1].set, h = d[1].link, g = d[1].update, p = d[1].animate) : !0 === d[1] && (e = !0);
            m.dir && 1 < m.handles && F.reverse();
            p && c(D, S[14], 300);
            d = 1 < x.length ? 3 : 1;
            1 === F.length && (d = 1);
            for (n = 0; n < d; n++) p = h || z[n % 2][0], p = p.getValue(F[n % 2]), !1 !== p && (p = k(m, p), m.dir && (p = 100 - p), !0 !== s(x[n % 2],
                p, !0) && a(z[n % 2]).each(function(a) {
                if (!a) return N = this.actual, !0;
                this.write(N, x[n % 2].children(), D, g)
            }));
            !0 === e && v(["set"]);
            return this
        };
        h.vGet = function() {
            var a, e = [];
            for (a = 0; a < m.handles; a++) e[a] = z[a][0].saved;
            return 1 === e.length ? e[0] : m.dir ? e.reverse() : e
        };
        h.destroy = function() {
            a.each(z, function() {
                a.each(this, function() {
                    this.target && this.target.off(".nui")
                })
            });
            a(this).off(".nui").removeClass(S.join(" ")).empty();
            return g
        };
        D.val(m.start)
    }

    function v(a) {
        if (!this.length) throw Error("noUiSlider: Can't initialize slider on empty selection.");
        var c = I(a, this);
        return this.each(function() {
            m(this, c, a)
        })
    }

    function N(c) {
        return this.each(function() {
            var d = a(this).val(),
                h = this.destroy(),
                m = a.extend({}, h, c);
            a(this).noUiSlider(m);
            h.start === m.start && a(this).val(d)
        })
    }

    function G() {
        return this[0][!arguments.length ? "vGet" : "vSet"].apply(this[0], arguments)
    }
    var ha = a(document),
        qa = a.fn.val,
        R = window.navigator.pointerEnabled ? {
            start: "pointerdown",
            move: "pointermove",
            end: "pointerup"
        } : window.navigator.msPointerEnabled ? {
            start: "MSPointerDown",
            move: "MSPointerMove",
            end: "MSPointerUp"
        } : {
            start: "mousedown touchstart",
            move: "mousemove touchmove",
            end: "mouseup touchend"
        },
        S = "noUi-target noUi-base noUi-origin noUi-handle noUi-horizontal noUi-vertical noUi-background noUi-connect noUi-ltr noUi-rtl noUi-dragable  noUi-state-drag  noUi-state-tap noUi-active noUi-extended noUi-stacking".split(" ");
    a.fn.val = function() {
        var c = arguments,
            d = a(this[0]);
        return !arguments.length ? (d.hasClass(S[0]) ? G : qa).call(d) : this.each(function() {
            (a(this).hasClass(S[0]) ? G : qa).apply(a(this), c)
        })
    };
    a.noUiSlider = {
        Link: a.Link
    };
    a.fn.noUiSlider = function(a, c) {
        return (c ? N : v).call(this, a)
    }
})(window.jQuery || window.Zepto);
(function(a, u) {
    var r = /[<>&\r\n"']/gm,
        c = {
            "\x3c": "lt;",
            "\x3e": "gt;",
            "\x26": "amp;",
            "\r": "#13;",
            "\n": "#10;",
            '"': "quot;",
            "'": "apos;"
        };
    a.extend({
        fileDownload: function(g, k) {
            function d() {
                if (-1 != document.cookie.indexOf(w.cookieName + "\x3d" + w.cookieValue)) F.onSuccess(g), document.cookie = w.cookieName + "\x3d; expires\x3d" + (new Date(1E3)).toUTCString() + "; path\x3d" + w.cookiePath, B(!1);
                else {
                    if (p || I) try {
                        var c = p ? p.document : n(I);
                        if (c && null != c.body && c.body.innerHTML.length) {
                            var h = !0;
                            if (A && A.length) {
                                var k = a(c.body).contents().first();
                                k.length && k[0] === A[0] && (h = !1)
                            }
                            if (h) {
                                F.onFail(c.body.innerHTML, g);
                                B(!0);
                                return
                            }
                        }
                    } catch (m) {
                        F.onFail("", g);
                        B(!0);
                        return
                    }
                    setTimeout(d, w.checkInterval)
                }
            }

            function n(a) {
                a = a[0].contentWindow || a[0].contentDocument;
                a.document && (a = a.document);
                return a
            }

            function B(a) {
                setTimeout(function() {
                    p && (t && p.close(), D && (p.focus(), a && p.close()))
                }, 0)
            }

            function C(a) {
                return a.replace(r, function(a) {
                    return "\x26" + c[a]
                })
            }
            var w = a.extend({
                    preparingMessageHtml: null,
                    failMessageHtml: null,
                    androidPostUnsupportedMessageHtml: "Unfortunately your Android browser doesn't support this type of file download. Please try again with a different browser.",
                    dialogOptions: {
                        modal: !0
                    },
                    prepareCallback: function(a) {},
                    successCallback: function(a) {},
                    failCallback: function(a, c) {},
                    httpMethod: "GET",
                    data: null,
                    checkInterval: 100,
                    cookieName: "fileDownload",
                    cookieValue: "true",
                    cookiePath: "/",
                    popupWindowTitle: "Initiating file download...",
                    encodeHTMLEntities: !0
                }, k),
                x = new a.Deferred,
                z = (navigator.userAgent || navigator.vendor || u.opera).toLowerCase(),
                D, t, s;
            /ip(ad|hone|od)/.test(z) ? D = !0 : -1 !== z.indexOf("android") ? t = !0 : s = /avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|playbook|silk|iemobile|iris|kindle|lge |maemo|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i.test(z) ||
                /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|e\-|e\/|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(di|rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|xda(\-|2|g)|yas\-|your|zeto|zte\-/i.test(z.substr(0,
                    4));
            z = w.httpMethod.toUpperCase();
            if (t && "GET" !== z) return a().dialog ? a("\x3cdiv\x3e").html(w.androidPostUnsupportedMessageHtml).dialog(w.dialogOptions) : alert(w.androidPostUnsupportedMessageHtml), x.reject();
            var h = null,
                F = {
                    onPrepare: function(c) {
                        w.preparingMessageHtml ? h = a("\x3cdiv\x3e").html(w.preparingMessageHtml).dialog(w.dialogOptions) : w.prepareCallback && w.prepareCallback(c)
                    },
                    onSuccess: function(a) {
                        h && h.dialog("close");
                        w.successCallback(a);
                        x.resolve(a)
                    },
                    onFail: function(c, d) {
                        h && h.dialog("close");
                        w.failMessageHtml &&
                            a("\x3cdiv\x3e").html(w.failMessageHtml).dialog(w.dialogOptions);
                        w.failCallback(c, d);
                        x.reject(c, d)
                    }
                };
            F.onPrepare(g);
            null !== w.data && "string" !== typeof w.data && (w.data = a.param(w.data));
            var I, p, A;
            if ("GET" === z) null !== w.data && (-1 !== g.indexOf("?") ? "\x26" !== g.substring(g.length - 1) && (g += "\x26") : g += "?", g += w.data), D || t ? (p = u.open(g), p.document.title = w.popupWindowTitle, u.focus()) : s ? u.location(g) : I = a("\x3ciframe\x3e").hide().prop("src", g).appendTo("body");
            else {
                var J = "";
                null !== w.data && a.each(w.data.replace(/\+/g,
                    " ").split("\x26"), function() {
                    var a = this.split("\x3d"),
                        c = w.encodeHTMLEntities ? C(decodeURIComponent(a[0])) : decodeURIComponent(a[0]);
                    c && (a = w.encodeHTMLEntities ? C(decodeURIComponent(a[1])) : decodeURIComponent(a[1]), J += '\x3cinput type\x3d"hidden" name\x3d"' + c + '" value\x3d"' + a + '" /\x3e')
                });
                s ? (A = a("\x3cform\x3e").appendTo("body"), A.hide().prop("method", w.httpMethod).prop("action", g).html(J)) : (D ? (p = u.open("about:blank"), p.document.title = w.popupWindowTitle, s = p.document, u.focus()) : (I = a("\x3ciframe style\x3d'display: none' src\x3d'about:blank'\x3e\x3c/iframe\x3e").appendTo("body"),
                    s = n(I)), s.write("\x3chtml\x3e\x3chead\x3e\x3c/head\x3e\x3cbody\x3e\x3cform method\x3d'" + w.httpMethod + "' action\x3d'" + g + "'\x3e" + J + "\x3c/form\x3e" + w.popupWindowTitle + "\x3c/body\x3e\x3c/html\x3e"), A = a(s).find("form"));
                A.submit()
            }
            setTimeout(d, w.checkInterval);
            return x.promise()
        }
    })
})(jQuery, this);
(function(a) {
    a.extend({
        fileUpload: function(u, r) {
            var c = a.extend({
                    params: {},
                    completeCallback: function() {}
                }, r),
                g = "ajaxUploader-iframe-" + Math.round((new Date).getTime() / 1E3);
            a("body").after('\x3ciframe width\x3d"0" height\x3d"0" style\x3d"display:none;" name\x3d"' + g + '" id\x3d"' + g + '"/\x3e');
            a("#" + g).load(function() {
                var g, d = this.contentWindow.document.body.innerHTML;
                try {
                    g = a.parseJSON(d)
                } catch (n) {
                    g = d
                }
                d = u.children("input[type\x3d'hidden']");
                for (key in c.params) d.remove("input[name\x3d'" + key + "']");
                u.removeAttr("target");
                c.completeCallback(u, g)
            });
            u.attr("target", g);
            u.prepend(function() {
                var a, d = "";
                for (a in c.params) {
                    var g = c.params[a];
                    "function" === typeof g && (g = g());
                    d += '\x3cinput type\x3d"hidden" name\x3d"' + a + '" value\x3d"' + g + '" /\x3e'
                }
                return d
            });
            u.submit(function(a) {
                a.stopPropagation()
            }).submit()
        }
    })
})(jQuery);
var tch = tch || {};
(function(a) {
	count = 0		 

    function u() {
        I && (window.clearTimeout(I), I = void 0);
        p && (window.clearTimeout(p), p = void 0)
    }

    function r(a, d, g) {
        $.isFunction(d) && (g = d, d = void 0);
        if (null == d || 1 > d.length || "REFRESH" != d[0].value) $(window).scrollTop(0), h(waitMsg);
        var m = $(".modal-action-advanced:first").is(":visible");
        u();
        $.ajaxSetup({
            beforeSend: function(a) {
                $.xhrPool.push(a)
            }
        });
        $(".modal").load(a, d, function(a, d, k) {
            $.xhrPool = [];
            F();
            403 === k.status || 0 < $("#sign-me-in").length ? (h(loginMsg), window.location = "/login.lp") : (("error" === d || "timeout" ===
                d) && httpErrorMessage(k), c(), m && C(), $.isFunction(g) && g(a, d, k))
        })
    }

    function c() {
        "1" === $("meta[name\x3dAdvanced]").attr("content") && ($(".advanced.hide").removeClass("hide"), $(".modal-action-advanced").parent().remove());
		wz();	 
        $(".tooltip-on").tooltip();
        $(".monitor-changes").each(function() {
            w(this, !0)
        });
        n();
        d();
        if (0 < $(".modal-header[data-autorefresh]").length) {
            var a = parseInt($(".modal-header").attr("data-autorefresh"), 10);
            !isNaN(a) && 0 < a && (I = window.setTimeout(function() {
                g()
            }, 1E3 * a))
        }
        0 < $(".modal-body [data-ajaxrefresh]").length &&
            (p = window.setTimeout(function() {
                k()
            }, 1E3))
    }

    function g() {
        var a = [{
                name: "operation",
                value: "REFRESH"
            }, B()],
            c = $(".modal form").attr("action"),
            d = $(".modal-body").scrollTop();
        r(c, a, function() {
            d && $(".modal-body").scrollTop(d)
        })
    }

    function k() {
        var a = [{
            name: "action",
            value: "AJAX-GET"
        }, B()];
        a.push({
            name: "auto_update",
            value: "true"
        });
        var c = $(".modal form").attr("action"),
            d = $(".modal-body [data-ajaxrefresh]"),
            h = {},
            g = !1;
        A += 1;
        d.each(function() {
            var c = $(this),
                d = parseInt(c.attr("data-ajaxrefresh"), 10);
            if (0 === A % d && (d = c.attr("name") ||
                    c.attr("id"))) h[d] = c, a.push({
                name: "requested_params",
                value: d
            }), g = !0
        });
        g ? $.post(c + "?auto_update\x3dtrue", a, function(a) {
            if ("string" === typeof a) try {
                a = JSON.parse(a)
            } catch (c) {
                return
            }
            for (var d in a)
                if (a.hasOwnProperty(d)) {
                    var g = a[d],
                        s = h[d];
                    s && (s.attr("name") === d ? s.val(g) : s.html(g))
                }
            p = window.setTimeout(function() {
                k();
                $(".monitor-changes").each(function() {
                    w(this, !0)
                })
            }, 1E3)
        }).fail(function(a) {}) : p = window.setTimeout(function() {
            k()
        }, 1E3)
    }

    function wz() {
        var a = $(".modal-body .wizard").first();
        if (0 !== a.length) {
            var c = 0,
                d = 0,
                h = a.attr("card-previous");
            void 0 != h && (c = +h, d = +a.attr("card-action"));
            h = a.find(".wizard-card");
            if (0 === h.eq(c).find(".error").length && 1 === d || -1 === d) c += d, 0 === h.eq(c).find(".error").length && $(".alert-error").detach();
            a.attr("card-previous", c);
            h.hide();
            c < h.length ? ($(".wizard-confirm").hide(), h.eq(c).show(), $("#wizard-complete").hide(), 0 === c && $("#wizard-previous").hide()) : $("#wizard-next").hide()
        }
    }				   
	
    function d() {
        $(".modal-body .typeahead").each(function(a, c) {
            var d = $(c),
                h = d.data("values"),
                g = [];
            $.each(h, function(a) {
                g.push(a)
            });
            d.typeahead({
                source: g,
                updater: function(a) {
                    return h.hasOwnProperty(a) ? h[a] : a
                }
            })
        })
    }

    function n() {
        $(".noUiSlider.slider-select").each(function() {
            var a = $(this),
                c = a.children("select"),
                d = c.find("option").length,
                h = c.prop("selectedIndex"),
                g = a.next(".noUiSlider-text");
            a.noUiSlider({
                start: h,
                range: {
                    min: 0,
                    max: d - 1
                },
                step: 1
            });
            a.on("set", function() {
                var a = $(this),
                    c = a.children("select"),
                    d = a.next(".noUiSlider-text");
                c.prop("selectedIndex", a.val());
                c.change();
                d.text(c.children("option:selected").text())
            });
            g.text(c.children("option:selected").text())
        })
    }

    function B() {
        return {
            name: "CSRFtoken",
            value: $("meta[name\x3dCSRFtoken]").attr("content")
        }
    }

    function C() {
        "1" !== $("meta[name\x3dAdvanced]").attr("content") && ($(".modal-action-advanced").toggle(), $(".modal-body .advanced").toggle())
    }

    function w(a, c) {
        var d = c ? 0 : 400,
            h = $(a),
            g = h.val(),
            k = h.attr("name"),
            p = h.attr("type"),
            h = h.prop("checked");
        !("radio" === p && !0 !== h) && !("checkbox" === p && "_TRUE_" !== g && !0 !== h) && ("checkbox" === p && "_TRUE_" === g && (g = !0 === h ? 1 : 0), p = $(".monitor-" +
            k + ":not(.monitor-" + g + ")"), g = $(".monitor-" + k + ".monitor-" + g), h = "monitor-hidden-" + k, k = "monitor-show-" + k, p.addClass(h), p.removeClass(k), p.filter(':not(.monitor-default-show[class*\x3d"monitor-show-"])').hide(d), g.removeClass(h), g.addClass(k), g.filter('.monitor-default-show,:not([class*\x3d"monitor-hidden-"])').show(d))
    }

    function x(a, c) {
        var d = $(".modal form").attr("action"),
            h = $(c).closest("table"),
            g = h.attr("id"),
            k = $(c).closest("tr").index(),
            p = h.find(".line-edit :input").serializeArray(),
            s = h.find(".additional-edit :input").serializeArray();
        if (("TABLE-MODIFY" == a || "TABLE-CANCEL" == a) && 0 < s.length) k -= 2;
        p = p.concat(s);
        p.push({
            name: "tableid",
            value: g
        });
        p.push({
            name: "stateid",
            value: h.attr("data-stateid")
        });
        p.push({
            name: "action",
            value: a
        });
        p.push({
            name: "index",
            value: k + 1
        });
        p.push(B());
        r(d, p, function() {
            D(g, k)
        })
    }

    function z(a, c) {
        var d = $(".modal form").attr("action"),
            h = $(c).closest("center").prev(),
            g = h.attr("id"),
            k = [];
        k.push({
            name: "tableid",
            value: g
        });
        k.push({
            name: "stateid",
            value: h.attr("data-stateid")
        });
        k.push({
            name: "action",
            value: a
        });
        k.push({
            name: "index",
            value: -1
        });
        k.push({
            name: "listid",
            value: $(c).attr("data-listid")
        });
        k.push(B());
        r(d, k, function() {
            D(g, -1)
        })
    }

    function D(a, c) {
        var d = $("#" + a),
            h = d.find("tr").eq(c);
        0 === h.length && (h = d.find("tr").last());
        0 < h.length && $(".modal-body").scrollTop(h.position().top)
    }

    function t(a, d) {
        if (!J) {
            J = !0;
            $(".modal").remove();
            try {
                h(openMsg)
            } catch (g) {
                J = !1;
                return
            }
            $.get(a, function(a) {
                var g = $(a);
                0 < g.find("#sign-me-in").length ? (h(loginMsg), window.location = "/login.lp") : ("1" === $("meta[name\x3dAdvanced]").attr("content") && (g.find(".advanced.hide").removeClass("hide"),
                    g.find(".modal-action-advanced").parent().remove()), $('\x3cdiv class\x3d"modal fade" id\x3d"' + d + '"\x3e' + a + "\x3c/div\x3e").modal(), F(), J = !1, c())
            }).fail(function(a) {
                J = !1;
                if (403 === a.status) h(loginMsg), window.location = "/login.lp";
                else {
                    $(".header-title").filter('[data-id\x3d"' + d + '"]').children().html();
                    $(c).modal();
                    var c = '\x3cdiv class\x3d"modal fade" id\x3d"' + d + '"\x3e\x3c/div\x3e';
                    httpErrorMessage(a)
                }
            })
        }
    }

    function wa(a) {
        var c = $(".wizard");
        if ("true" !== c.attr("button-clicked")) {
            c.attr("button-clicked", "true");
            V && clearTimeout(V);
            V = setTimeout(function() {
                c.attr("button-clicked", "")
            }, 1E3);
            var d = c.attr("card-previous"),
                h = $(".modal form"),
                g = h.serializeArray();
            g.push({
                name: "wizardCardPrevious",
                value: d
            }, {
                name: "wizardCardAction",
                value: a
            }, {
                name: "action",
                value: "VALIDATE"
            }, B());
            a = h.attr("action");
            r(a, g, function() {
                $('.error input:not([type\x3d"hidden"])').first().focus()
            })
        }
    }

    function s() {
        var a = $(this).closest("table"),
            c = $(this).parents(".modal-body.no-save");
        0 === a.length &&
            0 === c.length && ($("#modal-no-change").fadeOut(300), $("#modal-changes").delay(350).fadeIn(300))
    }

    function h(a) {
        var c = '\x3cdiv class\x3d"header"\x3e\x3cdiv data-toggle\x3d"modal" class\x3d"header-title pull-left"\x3e\x3cp\x3e' + processMsg + "\x3c/p\x3e\x3c/div\x3e\x3c/div\x3e";
        $("body").append('\x3cdiv class\x3d"popUpBG"\x3e\x3c/div\x3e');
        $("body").append('\x3cdiv id\x3d"popUp"  class\x3d"popUp smallcard span3"\x3e' + c + '\x3cdiv id\x3d"Poptxt" class\x3d"content"\x3e\x3c/div\x3e');
        var d = a + '\x3cbr/\x3e\x3cdiv id\x3d"spinner" class\x3d"spinner" align\x3d"center"\x3e\x3cdiv class\x3d"spinner3"\x3e\x3cdiv class\x3d"rect1"\x3e\x3c/div\x3e\x3cdiv class\x3d"rect2"\x3e\x3c/div\x3e\x3cdiv class\x3d"rect3"\x3e\x3c/div\x3e\x3cdiv class\x3d"rect4"\x3e\x3c/div\x3e\x3cdiv class\x3d"rect5"\x3e\x3c/div\x3e\x3c/div\x3e\x3c/div\x3e',
            h = $(document).height();
        a = $(window).height();
        c = $(window).scrollTop();
        $("#Poptxt").html(d);
        $(".popUpBG").css("height", h);
        d = $(".smallcard .header").css("background-color");
        $(".spinner3 div").css("background-color", d);
        10 < c && $("#popUp").css("top", 0.4 * a + c)
    }

    function F() {
        $(".popUpBG").remove();
        $("#popUp").remove()
    }
    var I, p;
    $.xhrPool = [];
    var A = 0;
    $(document).on("change", '.header input[type\x3d"hidden"]', function() {
        h(waitMsg);
        var a = $(this).serializeArray();
        a.push({
            name: "action",
            value: "SAVE"
        }, B());
        var c = $(this).closest(".header").children(".header-title").attr("data-remote");
        $.post(c, a, function() {
            window.location.reload(!0)
        }).fail(function(a) {
            if (403 === a.status || 0 < $("#sign-me-in").length) window.location = "/login.lp"
        })
    });
    $(document).on("click", ".btn[data-name][data-value]:not(.disabled):not(.custom-handler)", function() {
        var a = [],
            c = $(this).attr("data-name"),
            d = $(this).attr("data-value");
        "action" !== c && a.push({
            name: "action",
            value: "SAVE"
        });
        a.push({
            name: $(this).attr("data-name"),
            value: $(this).attr("data-value")
        }, B());
        c = $('.modal-body [data-for~\x3d"' + d + '"]').serializeArray();
        $.each(c,
            function(c, d) {
                a.push(d)
            });
        c = $(".modal form").attr("action");
        r(c, a, function() {
            0 < $(".error").closest(".advanced.hide").length && C();
            $('.error input:not([type\x3d"hidden"])').first().focus()
        })
    });
    $(document).on("click", ".switch:not(.disabled)", function() {
        var a = $(this).children(".switcher");
        a.toggleClass("switcherOn");
        var c = a.attr("valOn") || "1",
            a = a.attr("valOff") || "0";
        $(this).toggleClass("switchOn");
        var d = $(this).children("input"),
            h = d.val();
        d.val(h === c ? a : c);
        d.change();
        return !1
    });
																  
		   
	   
    $(document).on("click",
        ".modal-action-advanced",
        function() {
            C()
        });
    $(document).on("click", ".modal-action-refresh", function() {
        var a = $(".modal form").attr("action"),
            c = $(".modal-body").scrollTop();
        r(a, function() {
            $(".modal-body").scrollTop(c)
        })
    });
    $(document).on("click", "div[data-value\x3d'CONNECT']", function() {
        var a = $(".modal form").attr("action"),
            c = $(".modal-body").scrollTop();
        r(a, function() {
            $(".modal-body").scrollTop(c)
        })
    });
    $(document).on("click", 'input[type\x3d"password"]', function() {
        "********" == $(this).val() && $(this).select()
    });
    $(document).on("change", "select.monitor-changes", function() {
        w(this)
    });
    $(document).on("change", 'input[type\x3d"hidden"].monitor-changes', function() {
        w(this)
    });
    $(document).on("click", 'input[type\x3d"radio"].monitor-changes', function() {
        w(this)
    });
    $(document).on("click", 'input[type\x3d"checkbox"].monitor-changes', function() {
        w(this)
    });
    $(document).on("click", ".btn-table-new-list:not(.disabled)", function() {
        z("TABLE-NEW-LIST", this)
    });
    $(document).on("click", ".btn-table-new:not(.disabled)", function() {
        z("TABLE-NEW",
            this)
    });
    $(document).on("click", "table .btn-table-add:not(.disabled)", function() {
        x("TABLE-ADD", this)
    });
    $(document).on("click", "table .btn-table-delete:not(.disabled)", function() {
        x("TABLE-DELETE", this)
    });
    $(document).on("click", "table .btn-table-edit:not(.disabled)", function() {
        x("TABLE-EDIT", this)
    });
    $(document).on("click", "table .btn-table-modify:not(.disabled)", function() {
        x("TABLE-MODIFY", this)
    });
    $(document).on("click", "table .btn-table-cancel:not(.disabled)", function() {
        x("TABLE-CANCEL", this)
    });
																				  
																								  
	   
    $(document).on("change",
        'table .switch input[type\x3d"hidden"]',
        function() {
            0 === $(this).closest("table").find(".btn-table-cancel").length && x("TABLE-MODIFY", this)
        });
    $(document).on("change", "table .checkbox", function() {
        0 === $(this).closest("table").find(".btn-table-cancel").length && x("TABLE-MODIFY", this)
    });
    $(document).on("click", "#signout", function(a) {
        a.preventDefault();
        a = $("\x3cform\x3e", {
            action: "/",
            method: "post"
        }).append($("\x3cinput\x3e", {
            name: "do_signout",
            value: "1",
            type: "hidden"
        })).append($("\x3cinput\x3e", {
            name: "CSRFtoken",
            value: $("meta[name\x3dCSRFtoken]").attr("content"),
            type: "hidden"
        }));
        $("body").append(a);
        a.submit()
    });
    $(document).on("shown", ".modal", function(a) {
        $(a.target).hasClass("modal") && c()
    });
    $(document).on("hide", ".modal", function(a) {
        $(a.target).hasClass("modal") && u()
    });
    $(document).on("hidden", ".modal", function(a) {
		$(a.target).hasClass("modal")
        if (count > 0) {
            window.location.reload(!0)
        }
    });
    var J = !1;
    $(document).on("click touchend", '[data-toggle\x3d"modal"]', function(a) {
        a.preventDefault();
        a = $(this).attr("data-remote");
        var c =
            $(this).attr("data-id");
        t(a, c)
    });
    $(document).on("click touchend", ".smallcard", function(a) {
        if (767 < window.innerWidth) {
            a.preventDefault();
            var c = $(a.currentTarget).find('[data-toggle\x3d"modal"]');
            a = c.attr("data-remote");
            c = c.attr("data-id");
            a && t(a, c)
        }
    });
    $(document).on("click", "#save-config", function() {
		count = count + 1				 
        var a = $(".modal form"),
            c = a.serializeArray();
        c.push({
            name: "action",
            value: "SAVE"
        }, {
            name: "fromModal",
            value: "YES"
        }, B());
        a = a.attr("action");
        r(a, c, function() {
            var a = $(".error");
            0 < a.length && ($("#modal-no-change").hide(),
                $("#modal-changes").show());
            var c = $(".modal-action-advanced:first").is(":visible");
            0 < a.closest(".advanced").length && !c && C();
            $('.error input:not([type\x3d"hidden"])').first().focus()
        })
    });
	var V = null;
    $(document).on("click", "#wizard-next", function() {
        wa(1)
    });
    $(document).on("click", "#wizard-previous", function() {
        wa(-1)
    });
    $(document).on("click", "#wizard-complete", function() {
        $(".loading-wrapper").removeClass("hide");
        $(".btn").hide();
        var a = $(".wizard").attr("card-previous"),
            c = $(".modal form"),
            d = c.serializeArray();
        d.push({
            name: "wizardCardPrevious",
            value: a
        }, {
            name: "action",
            value: "SAVE"
        }, B());
        a = c.attr("action");
        r(a, d, function() {
            0 === $(".error").length ? ($(".loading-wrapper").removeClass("hide"), $(".btn").hide(), window.location.reload(!0)) : $('.error input:not([type\x3d"hidden"])').first().focus()
        })
    }); 
    $(document).on("click", ".nav a", function() {
        var a = $(this),
            c = a.attr("data-remote");
        $(".nav li").each(function() {
            $(this).removeClass("active")
        });
        a.parent().addClass("active");
        $.xhrPool.abortAll = function() {
            $(this).each(function(a, c) {
                c.abort()
            })
        };
        0 < $.xhrPool.length && $.xhrPool.abortAll();
        r(c)
    });
    $(document).on("keydown",
        ".modal input:not(.no-save):not(.disabled)", s);
    $(document).on("change", ".modal select:not(.no-save):not(.disabled)", s);
    $(document).on("click", ".modal .switch:not(.no-save):not(.disabled)", s);
    $(document).on("click", '.modal input[type\x3d"checkbox"]:not(.no-save):not(.disabled)', s);
    $(document).on("click", '.modal input[type\x3d"radio"]:not(.no-save):not(.disabled)', s);
    a.loadModal = r;
    a.modalLoaded = c;
    a.refreshModal = g;
    a.elementCSRFtoken = B;
    a.switchAdvanced = C;
    a.monitorHandler = w;
    a.modalgotchanges = s;
    a.setCookie =
        function(a, c, d) {
            var h = new Date;
            h.setDate(h.getDate() + d);
            c = encodeURIComponent(c) + (null === d ? "" : "; expires\x3d" + h.toUTCString());
            document.cookie = a + "\x3d" + c
        };
    a.scrollRowIntoView = D;
    a.removeProgress = F;
    a.showProgress = h;
    a.stringToHex = function(a) {
        return a.replace(/./g, function(a) {
            return (new Number(a.charCodeAt(0))).toString(16)
        })
    }
	a.nextWizardCard = wa				 
})(tch);
$(document).ready(function() {
    var a = $(".someInfos");
    a.click(function() {
        a.tooltip("hide")
    });
    a.tooltip();
    $(".tooltip-on").tooltip();
    $('select[name\x3d"webui_language"]').on("change", function() {
        tch.setCookie("webui_language", $(this).val(), 30);
        location.reload(!0)
    });
    1 < window.location.hash.length && ($('div[data-id\x3d"' + window.location.hash.substring(1) + '"]').click(), window.location.hash = "")
});

$(document).ready(function() {
    var a = $(".smallsomeInfos");
    a.click(function() {
        a.tooltip("hide")
    });
    a.tooltip();
    $(".tooltip-on").tooltip();
    $('select[name\x3d"webui_language"]').on("change", function() {
        tch.setCookie("webui_language", $(this).val(), 30);
        location.reload(!0)
    });
    1 < window.location.hash.length && ($('div[data-id\x3d"' + window.location.hash.substring(1) + '"]').click(), window.location.hash = "")
});

function confirmationDialogue(a, u) {
    var r = '\x3cdiv class\x3d"header"\x3e\x3cdiv data-toggle\x3d"modal" class\x3d"header-title pull-left"\x3e\x3cp\x3e' + u + "\x3c/p\x3e\x3c/div\x3e\x3c/div\x3e";
    $("body").append('\x3cdiv class\x3d"popUpBG"\x3e\x3c/div\x3e');
    $("body").append('\x3cdiv id\x3d"popUp"  class\x3d"popUp smallcard popUp-modal"\x3e' + r + '\x3cdiv id\x3d"Poptxt" class\x3d"content"\x3e\x3c/div\x3e');
    var c = a + '\x3cbr/\x3e\x3cdiv class \x3d "pull-center"\x3e\x3cdiv id\x3d"ok" class\x3d "btn btn-primary btn-large ' +
        u + '" align\x3d"center"\x3e' + okButton + '\x3c/div\x3e\x3cdiv id\x3d"cancel" class\x3d"btn btn-primary btn-large" align\x3d"center"\x3e' + cancelButton + "\x3c/div\x3e\x3c/div\x3e",
        g = $(document).height(),
        r = $(window).height(),
        k = $(window).scrollTop();
    $("#Poptxt").html(c);
    $(".popUpBG").css("height", g);
    c = $(".header .settings").css("background-color");
    $(".spinner3 div").css("background-color", c);
    10 < k && $("#popUp").css("top", 0.4 * r + k)
}
var qrcode = function() {
    function a(c, d) {
        if ("undefined" == typeof c.length) throw Error(c.length + "/" + d);
        var k = function() {
                for (var a = 0; a < c.length && 0 == c[a];) a += 1;
                for (var h = Array(c.length - a + d), g = 0; g < c.length - a; g += 1) h[g] = c[g + a];
                return h
            }(),
            h = {
                getAt: function(a) {
                    return k[a]
                },
                getLength: function() {
                    return k.length
                },
                multiply: function(c) {
                    for (var d = Array(h.getLength() + c.getLength() - 1), k = 0; k < h.getLength(); k += 1)
                        for (var s = 0; s < c.getLength(); s += 1) d[k + s] ^= g.gexp(g.glog(h.getAt(k)) + g.glog(c.getAt(s)));
                    return a(d, 0)
                },
                mod: function(c) {
                    if (0 >
                        h.getLength() - c.getLength()) return h;
                    for (var d = g.glog(h.getAt(0)) - g.glog(c.getAt(0)), k = Array(h.getLength()), s = 0; s < h.getLength(); s += 1) k[s] = h.getAt(s);
                    for (s = 0; s < c.getLength(); s += 1) k[s] ^= g.gexp(g.glog(c.getAt(s)) + d);
                    return a(k, 0).mod(c)
                }
            };
        return h
    }
    var u = function(g, t) {
        var s = r[t],
            h = null,
            F = 0,
            I = null,
            p = [],
            A = {},
            u = function(n, A) {
                for (var m = F = 4 * g + 17, v = Array(m), t = 0; t < m; t += 1) {
                    v[t] = Array(m);
                    for (var G = 0; G < m; G += 1) v[t][G] = null
                }
                h = v;
                B(0, 0);
                B(F - 7, 0);
                B(0, F - 7);
                m = c.getPatternPosition(g);
                for (v = 0; v < m.length; v += 1)
                    for (t = 0; t <
                        m.length; t += 1) {
                        var G = m[v],
                            r = m[t];
                        if (null == h[G][r])
                            for (var u = -2; 2 >= u; u += 1)
                                for (var w = -2; 2 >= w; w += 1) h[G + u][r + w] = -2 == u || 2 == u || -2 == w || 2 == w || 0 == u && 0 == w ? !0 : !1
                    }
                for (m = 8; m < F - 8; m += 1) null == h[m][6] && (h[m][6] = 0 == m % 2);
                for (m = 8; m < F - 8; m += 1) null == h[6][m] && (h[6][m] = 0 == m % 2);
                m = c.getBCHTypeInfo(s << 3 | A);
                for (v = 0; 15 > v; v += 1) t = !n && 1 == (m >> v & 1), 6 > v ? h[v][8] = t : 8 > v ? h[v + 1][8] = t : h[F - 15 + v][8] = t;
                for (v = 0; 15 > v; v += 1) t = !n && 1 == (m >> v & 1), 8 > v ? h[8][F - v - 1] = t : 9 > v ? h[8][15 - v - 1 + 1] = t : h[8][15 - v - 1] = t;
                h[F - 8][8] = !n;
                if (7 <= g) {
                    m = c.getBCHTypeNumber(g);
                    for (v =
                        0; 18 > v; v += 1) t = !n && 1 == (m >> v & 1), h[Math.floor(v / 3)][v % 3 + F - 8 - 3] = t;
                    for (v = 0; 18 > v; v += 1) t = !n && 1 == (m >> v & 1), h[v % 3 + F - 8 - 3][Math.floor(v / 3)] = t
                }
                if (null == I) {
                    m = k.getRSBlocks(g, s);
                    v = d();
                    for (t = 0; t < p.length; t += 1) G = p[t], v.put(G.getMode(), 4), v.put(G.getLength(), c.getLengthInBits(G.getMode(), g)), G.write(v);
                    for (t = G = 0; t < m.length; t += 1) G += m[t].dataCount;
                    if (v.getLengthInBits() > 8 * G) throw Error("code length overflow. (" + v.getLengthInBits() + "\x3e" + 8 * G + ")");
                    for (v.getLengthInBits() + 4 <= 8 * G && v.put(0, 4); 0 != v.getLengthInBits() % 8;) v.putBit(!1);
                    for (; !(v.getLengthInBits() >= 8 * G);) {
                        v.put(236, 8);
                        if (v.getLengthInBits() >= 8 * G) break;
                        v.put(17, 8)
                    }
                    for (var x = 0, G = t = 0, r = Array(m.length), u = Array(m.length), w = 0; w < m.length; w += 1) {
                        var J = m[w].dataCount,
                            z = m[w].totalCount - J,
                            t = Math.max(t, J),
                            G = Math.max(G, z);
                        r[w] = Array(J);
                        for (var C = 0; C < r[w].length; C += 1) r[w][C] = 255 & v.getBuffer()[C + x];
                        x += J;
                        C = c.getErrorCorrectPolynomial(z);
                        J = a(r[w], C.getLength() - 1).mod(C);
                        u[w] = Array(C.getLength() - 1);
                        for (C = 0; C < u[w].length; C += 1) z = C + J.getLength() - u[w].length, u[w][C] = 0 <= z ? J.getAt(z) : 0
                    }
                    for (C =
                        v = 0; C < m.length; C += 1) v += m[C].totalCount;
                    v = Array(v);
                    for (C = x = 0; C < t; C += 1)
                        for (w = 0; w < m.length; w += 1) C < r[w].length && (v[x] = r[w][C], x += 1);
                    for (C = 0; C < G; C += 1)
                        for (w = 0; w < m.length; w += 1) C < u[w].length && (v[x] = u[w][C], x += 1);
                    I = v
                }
                m = I;
                v = -1;
                t = F - 1;
                G = 7;
                r = 0;
                u = c.getMaskFunction(A);
                for (w = F - 1; 0 < w; w -= 2)
                    for (6 == w && (w -= 1);;) {
                        for (C = 0; 2 > C; C += 1) null == h[t][w - C] && (x = !1, r < m.length && (x = 1 == (m[r] >>> G & 1)), u(t, w - C) && (x = !x), h[t][w - C] = x, G -= 1, -1 == G && (r += 1, G = 7));
                        t += v;
                        if (0 > t || F <= t) {
                            t -= v;
                            v = -v;
                            break
                        }
                    }
            },
            B = function(a, c) {
                for (var d = -1; 7 >= d; d += 1)
                    if (!(-1 >=
                            a + d || F <= a + d))
                        for (var g = -1; 7 >= g; g += 1) - 1 >= c + g || F <= c + g || (h[a + d][c + g] = 0 <= d && 6 >= d && (0 == g || 6 == g) || 0 <= g && 6 >= g && (0 == d || 6 == d) || 2 <= d && 4 >= d && 2 <= g && 4 >= g ? !0 : !1)
            };
        A.addData = function(a) {
            a = n(a);
            p.push(a);
            I = null
        };
        A.isDark = function(a, c) {
            if (0 > a || F <= a || 0 > c || F <= c) throw Error(a + "," + c);
            return h[a][c]
        };
        A.getModuleCount = function() {
            return F
        };
        A.make = function() {
            for (var a = 0, d = 0, h = 0; 8 > h; h += 1) {
                u(!0, h);
                var g = c.getLostPoint(A);
                if (0 == h || a > g) a = g, d = h
            }
            u(!1, d)
        };
        A.createTableTag = function(a, c) {
            a = a || 2;
            var d;
            d = '\x3ctable style\x3d" border-width: 0px; border-style: none;';
            d += " border-collapse: collapse;";
            d += " padding: 0px; margin: " + ("undefined" == typeof c ? 4 * a : c) + "px;";
            d += '"\x3e';
            d += "\x3ctbody\x3e";
            for (var h = 0; h < A.getModuleCount(); h += 1) {
                d += "\x3ctr\x3e";
                for (var g = 0; g < A.getModuleCount(); g += 1) d += '\x3ctd style\x3d"', d += " border-width: 0px; border-style: none;", d += " border-collapse: collapse;", d += " padding: 0px; margin: 0px;", d += " width: " + a + "px;", d += " height: " + a + "px;", d += " background-color: ", d += A.isDark(h, g) ? "#000000" : "#ffffff", d += ";", d += '"/\x3e';
                d += "\x3c/tr\x3e"
            }
            d +=
                "\x3c/tbody\x3e";
            return d += "\x3c/table\x3e"
        };
        A.createImgTag = function(a, c) {
            a = a || 2;
            c = "undefined" == typeof c ? 4 * a : c;
            var d = A.getModuleCount() * a + 2 * c,
                h = c,
                g = d - c;
            return z(d, d, function(c, d) {
                return h <= c && c < g && h <= d && d < g ? A.isDark(Math.floor((d - h) / a), Math.floor((c - h) / a)) ? 0 : 1 : 1
            })
        };
        return A
    };
    u.stringToBytes = function(a) {
        for (var c = [], d = 0; d < a.length; d += 1) {
            var h = a.charCodeAt(d);
            c.push(h & 255)
        }
        return c
    };
    u.createStringToBytes = function(a, c) {
        var d = function() {
            for (var d = w(a), g = function() {
                    var a = d.read();
                    if (-1 == a) throw Error();
                    return a
                }, k = 0, p = {};;) {
                var s = d.read();
                if (-1 == s) break;
                var n = g(),
                    r = g(),
                    u = g(),
                    s = String.fromCharCode(s << 8 | n);
                p[s] = r << 8 | u;
                k += 1
            }
            if (k != c) throw Error(k + " !\x3d " + c);
            return p
        }();
        return function(a) {
            for (var c = [], g = 0; g < a.length; g += 1) {
                var k = a.charCodeAt(g);
                128 > k ? c.push(k) : (k = d[a.charAt(g)], "number" == typeof k ? (k & 255) == k ? c.push(k) : (c.push(k >>> 8), c.push(k & 255)) : c.push(63))
            }
            return c
        }
    };
    var r = {
            L: 1,
            M: 0,
            Q: 3,
            H: 2
        },
        c = function() {
            var c = [
                    [],
                    [6, 18],
                    [6, 22],
                    [6, 26],
                    [6, 30],
                    [6, 34],
                    [6, 22, 38],
                    [6, 24, 42],
                    [6, 26, 46],
                    [6, 28, 50],
                    [6, 30, 54],
                    [6, 32, 58],
                    [6, 34, 62],
                    [6, 26, 46, 66],
                    [6, 26, 48, 70],
                    [6, 26, 50, 74],
                    [6, 30, 54, 78],
                    [6, 30, 56, 82],
                    [6, 30, 58, 86],
                    [6, 34, 62, 90],
                    [6, 28, 50, 72, 94],
                    [6, 26, 50, 74, 98],
                    [6, 30, 54, 78, 102],
                    [6, 28, 54, 80, 106],
                    [6, 32, 58, 84, 110],
                    [6, 30, 58, 86, 114],
                    [6, 34, 62, 90, 118],
                    [6, 26, 50, 74, 98, 122],
                    [6, 30, 54, 78, 102, 126],
                    [6, 26, 52, 78, 104, 130],
                    [6, 30, 56, 82, 108, 134],
                    [6, 34, 60, 86, 112, 138],
                    [6, 30, 58, 86, 114, 142],
                    [6, 34, 62, 90, 118, 146],
                    [6, 30, 54, 78, 102, 126, 150],
                    [6, 24, 50, 76, 102, 128, 154],
                    [6, 28, 54, 80, 106, 132, 158],
                    [6, 32, 58, 84, 110, 136, 162],
                    [6, 26, 54, 82, 110, 138, 166],
                    [6,
                        30, 58, 86, 114, 142, 170
                    ]
                ],
                d = {},
                k = function(a) {
                    for (var c = 0; 0 != a;) c += 1, a >>>= 1;
                    return c
                };
            d.getBCHTypeInfo = function(a) {
                for (var c = a << 10; 0 <= k(c) - k(1335);) c ^= 1335 << k(c) - k(1335);
                return (a << 10 | c) ^ 21522
            };
            d.getBCHTypeNumber = function(a) {
                for (var c = a << 12; 0 <= k(c) - k(7973);) c ^= 7973 << k(c) - k(7973);
                return a << 12 | c
            };
            d.getPatternPosition = function(a) {
                return c[a - 1]
            };
            d.getMaskFunction = function(a) {
                switch (a) {
                    case 0:
                        return function(a, c) {
                            return 0 == (a + c) % 2
                        };
                    case 1:
                        return function(a, c) {
                            return 0 == a % 2
                        };
                    case 2:
                        return function(a, c) {
                            return 0 ==
                                c % 3
                        };
                    case 3:
                        return function(a, c) {
                            return 0 == (a + c) % 3
                        };
                    case 4:
                        return function(a, c) {
                            return 0 == (Math.floor(a / 2) + Math.floor(c / 3)) % 2
                        };
                    case 5:
                        return function(a, c) {
                            return 0 == a * c % 2 + a * c % 3
                        };
                    case 6:
                        return function(a, c) {
                            return 0 == (a * c % 2 + a * c % 3) % 2
                        };
                    case 7:
                        return function(a, c) {
                            return 0 == (a * c % 3 + (a + c) % 2) % 2
                        };
                    default:
                        throw Error("bad maskPattern:" + a);
                }
            };
            d.getErrorCorrectPolynomial = function(c) {
                for (var d = a([1], 0), k = 0; k < c; k += 1) d = d.multiply(a([1, g.gexp(k)], 0));
                return d
            };
            d.getLengthInBits = function(a, c) {
                if (1 <= c && 10 > c) switch (a) {
                    case 1:
                        return 10;
                    case 2:
                        return 9;
                    case 4:
                        return 8;
                    case 8:
                        return 8;
                    default:
                        throw Error("mode:" + a);
                } else if (27 > c) switch (a) {
                    case 1:
                        return 12;
                    case 2:
                        return 11;
                    case 4:
                        return 16;
                    case 8:
                        return 10;
                    default:
                        throw Error("mode:" + a);
                } else if (41 > c) switch (a) {
                    case 1:
                        return 14;
                    case 2:
                        return 13;
                    case 4:
                        return 16;
                    case 8:
                        return 12;
                    default:
                        throw Error("mode:" + a);
                } else throw Error("type:" + c);
            };
            d.getLostPoint = function(a) {
                for (var c = a.getModuleCount(), d = 0, g = 0; g < c; g += 1)
                    for (var k = 0; k < c; k += 1) {
                        for (var s = 0, n = a.isDark(g, k), t = -1; 1 >= t; t += 1)
                            if (!(0 >
                                    g + t || c <= g + t))
                                for (var r = -1; 1 >= r; r += 1) 0 > k + r || c <= k + r || 0 == t && 0 == r || n == a.isDark(g + t, k + r) && (s += 1);
                        5 < s && (d += 3 + s - 5)
                    }
                for (g = 0; g < c - 1; g += 1)
                    for (k = 0; k < c - 1; k += 1)
                        if (s = 0, a.isDark(g, k) && (s += 1), a.isDark(g + 1, k) && (s += 1), a.isDark(g, k + 1) && (s += 1), a.isDark(g + 1, k + 1) && (s += 1), 0 == s || 4 == s) d += 3;
                for (g = 0; g < c; g += 1)
                    for (k = 0; k < c - 6; k += 1) a.isDark(g, k) && (!a.isDark(g, k + 1) && a.isDark(g, k + 2) && a.isDark(g, k + 3) && a.isDark(g, k + 4) && !a.isDark(g, k + 5) && a.isDark(g, k + 6)) && (d += 40);
                for (k = 0; k < c; k += 1)
                    for (g = 0; g < c - 6; g += 1) a.isDark(g, k) && (!a.isDark(g + 1, k) && a.isDark(g +
                        2, k) && a.isDark(g + 3, k) && a.isDark(g + 4, k) && !a.isDark(g + 5, k) && a.isDark(g + 6, k)) && (d += 40);
                for (k = s = 0; k < c; k += 1)
                    for (g = 0; g < c; g += 1) a.isDark(g, k) && (s += 1);
                a = Math.abs(100 * s / c / c - 50) / 5;
                return d + 10 * a
            };
            return d
        }(),
        g = function() {
            for (var a = Array(256), c = Array(256), d = 0; 8 > d; d += 1) a[d] = 1 << d;
            for (d = 8; 256 > d; d += 1) a[d] = a[d - 4] ^ a[d - 5] ^ a[d - 6] ^ a[d - 8];
            for (d = 0; 255 > d; d += 1) c[a[d]] = d;
            return {
                glog: function(a) {
                    if (1 > a) throw Error("glog(" + a + ")");
                    return c[a]
                },
                gexp: function(c) {
                    for (; 0 > c;) c += 255;
                    for (; 256 <= c;) c -= 255;
                    return a[c]
                }
            }
        }(),
        k = function() {
            var a = [
                    [1, 26, 19],
                    [1, 26, 16],
                    [1, 26, 13],
                    [1, 26, 9],
                    [1, 44, 34],
                    [1, 44, 28],
                    [1, 44, 22],
                    [1, 44, 16],
                    [1, 70, 55],
                    [1, 70, 44],
                    [2, 35, 17],
                    [2, 35, 13],
                    [1, 100, 80],
                    [2, 50, 32],
                    [2, 50, 24],
                    [4, 25, 9],
                    [1, 134, 108],
                    [2, 67, 43],
                    [2, 33, 15, 2, 34, 16],
                    [2, 33, 11, 2, 34, 12],
                    [2, 86, 68],
                    [4, 43, 27],
                    [4, 43, 19],
                    [4, 43, 15],
                    [2, 98, 78],
                    [4, 49, 31],
                    [2, 32, 14, 4, 33, 15],
                    [4, 39, 13, 1, 40, 14],
                    [2, 121, 97],
                    [2, 60, 38, 2, 61, 39],
                    [4, 40, 18, 2, 41, 19],
                    [4, 40, 14, 2, 41, 15],
                    [2, 146, 116],
                    [3, 58, 36, 2, 59, 37],
                    [4, 36, 16, 4, 37, 17],
                    [4, 36, 12, 4, 37, 13],
                    [2, 86, 68, 2, 87, 69],
                    [4, 69, 43, 1, 70, 44],
                    [6, 43, 19, 2, 44, 20],
                    [6,
                        43, 15, 2, 44, 16
                    ]
                ],
                c = function(a, c) {
                    var d = {};
                    d.totalCount = a;
                    d.dataCount = c;
                    return d
                },
                d = {},
                g = function(c, d) {
                    switch (d) {
                        case r.L:
                            return a[4 * (c - 1) + 0];
                        case r.M:
                            return a[4 * (c - 1) + 1];
                        case r.Q:
                            return a[4 * (c - 1) + 2];
                        case r.H:
                            return a[4 * (c - 1) + 3]
                    }
                };
            d.getRSBlocks = function(a, d) {
                var k = g(a, d);
                if ("undefined" == typeof k) throw Error("bad rs block @ typeNumber:" + a + "/errorCorrectLevel:" + d);
                for (var s = k.length / 3, n = [], r = 0; r < s; r += 1)
                    for (var u = k[3 * r + 0], w = k[3 * r + 1], m = k[3 * r + 2], v = 0; v < u; v += 1) n.push(c(w, m));
                return n
            };
            return d
        }(),
        d = function() {
            var a = [],
                c = 0,
                d = {
                    getBuffer: function() {
                        return a
                    },
                    getAt: function(c) {
                        return 1 == (a[Math.floor(c / 8)] >>> 7 - c % 8 & 1)
                    },
                    put: function(a, c) {
                        for (var g = 0; g < c; g += 1) d.putBit(1 == (a >>> c - g - 1 & 1))
                    },
                    getLengthInBits: function() {
                        return c
                    },
                    putBit: function(d) {
                        var g = Math.floor(c / 8);
                        a.length <= g && a.push(0);
                        d && (a[g] |= 128 >>> c % 8);
                        c += 1
                    }
                };
            return d
        },
        n = function(a) {
            var c = u.stringToBytes(a);
            return {
                getMode: function() {
                    return 4
                },
                getLength: function(a) {
                    return c.length
                },
                write: function(a) {
                    for (var d = 0; d < c.length; d += 1) a.put(c[d], 8)
                }
            }
        },
        B = function() {
            var a = [],
                c = {
                    writeByte: function(c) {
                        a.push(c & 255)
                    },
                    writeShort: function(a) {
                        c.writeByte(a);
                        c.writeByte(a >>> 8)
                    },
                    writeBytes: function(a, d, g) {
                        d = d || 0;
                        g = g || a.length;
                        for (var k = 0; k < g; k += 1) c.writeByte(a[k + d])
                    },
                    writeString: function(a) {
                        for (var d = 0; d < a.length; d += 1) c.writeByte(a.charCodeAt(d))
                    },
                    toByteArray: function() {
                        return a
                    },
                    toString: function() {
                        var c;
                        c = "[";
                        for (var d = 0; d < a.length; d += 1) 0 < d && (c += ","), c += a[d];
                        return c + "]"
                    }
                };
            return c
        },
        C = function() {
            var a = 0,
                c = 0,
                d = 0,
                g = "",
                k = {},
                n = function(a) {
                    if (!(0 > a)) {
                        if (26 > a) return 65 + a;
                        if (52 >
                            a) return 97 + (a - 26);
                        if (62 > a) return 48 + (a - 52);
                        if (62 == a) return 43;
                        if (63 == a) return 47
                    }
                    throw Error("n:" + a);
                };
            k.writeByte = function(k) {
                a = a << 8 | k & 255;
                c += 8;
                for (d += 1; 6 <= c;) g += String.fromCharCode(n(a >>> c - 6 & 63)), c -= 6
            };
            k.flush = function() {
                0 < c && (g += String.fromCharCode(n(a << 6 - c & 63)), c = a = 0);
                if (0 != d % 3)
                    for (var k = 3 - d % 3, r = 0; r < k; r += 1) g += "\x3d"
            };
            k.toString = function() {
                return g
            };
            return k
        },
        w = function(a) {
            var c = 0,
                d = 0,
                g = 0,
                k = function(a) {
                    if (65 <= a && 90 >= a) return a - 65;
                    if (97 <= a && 122 >= a) return a - 97 + 26;
                    if (48 <= a && 57 >= a) return a - 48 + 52;
                    if (43 == a) return 62;
                    if (47 == a) return 63;
                    throw Error("c:" + a);
                };
            return {
                read: function() {
                    for (; 8 > g;) {
                        if (c >= a.length) {
                            if (0 == g) return -1;
                            throw Error("unexpected end of file./" + g);
                        }
                        var n = a.charAt(c);
                        c += 1;
                        if ("\x3d" == n) return g = 0, -1;
                        n.match(/^\s$/) || (d = d << 6 | k(n.charCodeAt(0)), g += 6)
                    }
                    n = d >>> g - 8 & 255;
                    g -= 8;
                    return n
                }
            }
        },
        x = function(a, c) {
            var d = Array(a * c),
                g = function(a) {
                    var c = 0,
                        d = 0;
                    return {
                        write: function(g, h) {
                            if (0 != g >>> h) throw Error("length over");
                            for (; 8 <= c + h;) a.writeByte(255 & (g << c | d)), h -= 8 - c, g >>>= 8 - c, c = d = 0;
                            d |= g << c;
                            c += h
                        },
                        flush: function() {
                            0 < c && a.writeByte(d)
                        }
                    }
                },
                k = function() {
                    var a = {},
                        c = 0,
                        d = {
                            add: function(g) {
                                if (d.contains(g)) throw Error("dup key:" + g);
                                a[g] = c;
                                c += 1
                            },
                            size: function() {
                                return c
                            },
                            indexOf: function(c) {
                                return a[c]
                            },
                            contains: function(c) {
                                return "undefined" != typeof a[c]
                            }
                        };
                    return d
                };
            return {
                setPixel: function(c, g, h) {
                    d[g * a + c] = h
                },
                write: function(n) {
                    n.writeString("GIF87a");
                    n.writeShort(a);
                    n.writeShort(c);
                    n.writeByte(128);
                    n.writeByte(0);
                    n.writeByte(0);
                    n.writeByte(0);
                    n.writeByte(0);
                    n.writeByte(0);
                    n.writeByte(255);
                    n.writeByte(255);
                    n.writeByte(255);
                    n.writeString(",");
                    n.writeShort(0);
                    n.writeShort(0);
                    n.writeShort(a);
                    n.writeShort(c);
                    n.writeByte(0);
                    var p;
                    p = 3;
                    for (var r = k(), u = 0; 4 > u; u += 1) r.add(String.fromCharCode(u));
                    r.add(String.fromCharCode(4));
                    r.add(String.fromCharCode(5));
                    var u = B(),
                        w = g(u);
                    w.write(4, p);
                    for (var x = 0, C = String.fromCharCode(d[x]), x = x + 1; x < d.length;) {
                        var m = String.fromCharCode(d[x]),
                            x = x + 1;
                        r.contains(C + m) ? C += m : (w.write(r.indexOf(C), p), 4095 > r.size() && (r.size() == 1 << p && (p += 1), r.add(C + m)), C = m)
                    }
                    w.write(r.indexOf(C), p);
                    w.write(5,
                        p);
                    w.flush();
                    p = u.toByteArray();
                    n.writeByte(2);
                    for (r = 0; 255 < p.length - r;) n.writeByte(255), n.writeBytes(p, r, 255), r += 255;
                    n.writeByte(p.length - r);
                    n.writeBytes(p, r, p.length - r);
                    n.writeByte(0);
                    n.writeString(";")
                }
            }
        },
        z = function(a, c, d, g) {
            for (var k = x(a, c), n = 0; n < c; n += 1)
                for (var p = 0; p < a; p += 1) k.setPixel(p, n, d(p, n));
            d = B();
            k.write(d);
            k = C();
            d = d.toByteArray();
            for (n = 0; n < d.length; n += 1) k.writeByte(d[n]);
            k.flush();
            d = '\x3cimg src\x3d"';
            d += "data:image/gif;base64,";
            d += k;
            d += '"';
            d += ' width\x3d"';
            d += a;
            d += '"';
            d += ' height\x3d"';
            d += c;
            d += '"';
            g && (d += ' alt\x3d"', d += g, d += '"');
            return d += "/\x3e"
        };
    return u
}();
(function(a) {
    function u(d, m) {
        function v(a, c, e) {
            a.stopPropagation();
            a.preventDefault();
            if (!ea && !s(c) && !c.hasClass("dwa")) {
                ea = !0;
                var d = c.find(".dw-ul");
                u(d);
                clearInterval(ja);
                ja = setInterval(function() {
                    e(d)
                }, K.delay);
                e(d)
            }
        }

        function s(c) {
            return a.isArray(K.readonly) ? (c = a(".dwwl", P).index(c), K.readonly[c]) : K.readonly
        }

        function r(c) {
            var e = '\x3cdiv class\x3d"dw-bf"\x3e';
            c = Qa[c];
            c = c.values ? c : k(c);
            var d = 1,
                g = c.labels || [],
                h = c.values,
                m = c.keys || h;
            a.each(h, function(a, c) {
                0 == d % 20 && (e += '\x3c/div\x3e\x3cdiv class\x3d"dw-bf"\x3e');
                e += '\x3cdiv role\x3d"option" aria-selected\x3d"false" class\x3d"dw-li dw-v" data-val\x3d"' + m[a] + '"' + (g[a] ? ' aria-label\x3d"' + g[a] + '"' : "") + ' style\x3d"height:' + ca + "px;line-height:" + ca + 'px;"\x3e\x3cdiv class\x3d"dw-i"\x3e' + c + "\x3c/div\x3e\x3c/div\x3e";
                d++
            });
            return e += "\x3c/div\x3e"
        }

        function u(c) {
            L = a(".dw-li", c).index(a(".dw-v", c).eq(0));
            Ia = a(".dw-li", c).index(a(".dw-v", c).eq(-1));
            xa = a(".dw-ul", P).index(c)
        }

        function C(a) {
            var c = K.headerText;
            return c ? "function" === typeof c ? c.call(ua, a) : c.replace(/\{value\}/i,
                a) : ""
        }

        function z() {
            H.temp = Ka && null !== H.val && H.val != fa.val() || null === H.values ? K.parseValue(fa.val() || "", H) : H.values.slice(0);
            ka()
        }

        function S(c) {
            var e = window.getComputedStyle ? getComputedStyle(c[0]) : c[0].style,
                d;
            h ? (a.each(["t", "webkitT", "MozT", "OT", "msT"], function(a, c) {
                if (void 0 !== e[c + "ransform"]) return d = e[c + "ransform"], !1
            }), d = d.split(")")[0].split(", "), c = d[13] || d[5]) : c = e.top.replace("px", "");
            return Math.round(Wa - c / ca)
        }

        function T(a, c) {
            clearTimeout(pa[c]);
            delete pa[c];
            a.closest(".dwwl").removeClass("dwa")
        }

        function X(a, c, e, d, g) {
            var k = (Wa - e) * ca,
                m = a[0].style;
            k == Ea[c] && pa[c] || (d && k != Ea[c] && Y("onAnimStart", [P, c, d]), Ea[c] = k, m[I + "Transition"] = "all " + (d ? d.toFixed(3) : 0) + "s ease-out", h ? m[I + "Transform"] = "translate3d(0," + k + "px,0)" : m.top = k + "px", pa[c] && T(a, c), d && g && (a.closest(".dwwl").addClass("dwa"), pa[c] = setTimeout(function() {
                T(a, c)
            }, 1E3 * d)), oa[c] = e)
        }

        function W(c, e, d, g, h) {
            !1 !== Y("validate", [P, e, c]) && (a(".dw-ul", P).each(function(d) {
                    var k = a(this),
                        m = a('.dw-li[data-val\x3d"' + H.temp[d] + '"]', k),
                        n = a(".dw-li", k),
                        p = n.index(m),
                        s = n.length,
                        v = d == e || void 0 === e;
                    if (!m.hasClass("dw-v")) {
                        for (var r = m, t = 0, u = 0; 0 <= p - t && !r.hasClass("dw-v");) t++, r = n.eq(p - t);
                        for (; p + u < s && !m.hasClass("dw-v");) u++, m = n.eq(p + u);
                        (u < t && u && 2 !== g || !t || 0 > p - t || 1 == g) && m.hasClass("dw-v") ? p += u : (m = r, p -= t)
                    }
                    if (!m.hasClass("dw-sel") || v) H.temp[d] = m.attr("data-val"), a(".dw-sel", k).removeClass("dw-sel"), K.multiple || (a(".dw-sel", k).removeAttr("aria-selected"), m.attr("aria-selected", "true")), m.addClass("dw-sel"), X(k, d, p, v ? c : 0.1, v ? h : !1)
                }), aa = K.formatResult(H.temp), "inline" ==
                K.display ? ka(d, 0, !0) : a(".dwv", P).html(C(aa)), d && Y("onChange", [aa]))
        }

        function Y(c, e) {
            var d;
            e.push(H);
            a.each([Ha.defaults, va, m], function(a, g) {
                g[c] && (d = g[c].apply(ua, e))
            });
            return d
        }

        function Ba(c, e, d, g, h) {
            e = Math.max(L, Math.min(e, Ia));
            var k = a(".dw-li", c).eq(e),
                m = void 0 === h ? e : h,
                n = xa,
                p = g ? e == m ? 0.1 : Math.abs((e - m) * K.timeUnit) : 0;
            H.temp[n] = k.attr("data-val");
            X(c, n, e, p, h);
            setTimeout(function() {
                W(p, n, !0, d, void 0 !== h)
            }, 10)
        }

        function Pa(a) {
            var c = oa[xa] + 1;
            Ba(a, c > Ia ? L : c, 1, !0)
        }

        function Ga(a) {
            var c = oa[xa] - 1;
            Ba(a, c < L ?
                Ia : c, 2, !0)
        }

        function ka(a, c, e, d) {
            Da && !e && W(c);
            aa = K.formatResult(H.temp);
            d || (H.values = H.temp.slice(0), H.val = aa);
            a && Ka && fa.val(aa).trigger("change")
        }
        var Wa, ca, aa, P, ma, ga, Xa, ba, na, da, E, e, Ha, Ya, ea, Ca, la, ra, za, ya, wa, L, Ia, sa, xa, ja, Ua, Ja, H = this,
            Za = a.mobiscroll,
            ua = d,
            fa = a(ua),
            K = p({}, O),
            va = {},
            pa = {},
            oa = {},
            Ea = {},
            Qa = [],
            Ka = fa.is("input"),
            Da = !1,
            jb = function(e) {
                c(e) && (!n && !s(this) && !ea) && (e.preventDefault(), n = !0, Ca = "clickpick" != K.mode, sa = a(".dw-ul", this), u(sa), wa = (la = void 0 !== pa[xa]) ? S(sa) : oa[xa], ra = g(e, "Y"), za = new Date,
                    ya = ra, X(sa, xa, wa, 0.001), Ca && sa.closest(".dwwl").addClass("dwa"), a(document).on(J, db).on(M, ab))
            },
            db = function(a) {
                Ca && (a.preventDefault(), a.stopPropagation(), ya = g(a, "Y"), X(sa, xa, Math.max(L - 1, Math.min(wa + (ra - ya) / ca, Ia + 1))));
                la = !0
            },
            ab = function(c) {
                var e = new Date - za;
                c = Math.max(L - 1, Math.min(wa + (ra - ya) / ca, Ia + 1));
                var d, g = sa.offset().top;
                300 > e ? (e = (ya - ra) / e, d = e * e / K.speedUnit, 0 > ya - ra && (d = -d)) : d = ya - ra;
                e = Math.round(wa - d / ca);
                if (!d && !la) {
                    var g = Math.floor((ya - g) / ca),
                        h = a(".dw-li", sa).eq(g);
                    d = Ca;
                    !1 !== Y("onValueTap", [h]) ? e = g : d = !0;
                    d && (h.addClass("dw-hl"), setTimeout(function() {
                        h.removeClass("dw-hl")
                    }, 200))
                }
                Ca && Ba(sa, e, 0, !0, Math.round(c));
                n = !1;
                sa = null;
                a(document).off(J, db).off(M, ab)
            },
            sb = function(e) {
                var d = a(this);
                a(document).on(M, eb);
                d.hasClass("dwb-d") || d.addClass("dwb-a");
                setTimeout(function() {
                    d.blur()
                }, 10);
                d.hasClass("dwwb") && c(e) && v(e, d.closest(".dwwl"), d.hasClass("dwwbp") ? Pa : Ga)
            },
            eb = function(c) {
                ea && (clearInterval(ja), ea = !1);
                a(document).off(M, eb);
                a(".dwb-a", P).removeClass("dwb-a")
            },
            fb = function(c) {
                38 == c.keyCode ?
                    v(c, a(this), Ga) : 40 == c.keyCode && v(c, a(this), Pa)
            },
            kb = function(a) {
                ea && (clearInterval(ja), ea = !1)
            },
            lb = function(c) {
                if (!s(this)) {
                    c.preventDefault();
                    c = c.originalEvent || c;
                    c = c.wheelDelta ? c.wheelDelta / 120 : c.detail ? -c.detail / 3 : 0;
                    var e = a(".dw-ul", this);
                    u(e);
                    Ba(e, Math.round(oa[xa] - c), 0 > c ? 1 : 2)
                }
            };
        H.position = function(c) {
            if (!("inline" == K.display || ma === a(window).width() && Xa === a(window).height() && c || !1 === Y("onPosition", [P]))) {
                var e, d, g, h, k, m, n, p, v, s = 0,
                    r = 0;
                c = a(window).scrollTop();
                h = a(".dwwr", P);
                var t = a(".dw", P),
                    u = {};
                k = void 0 === K.anchor ? fa : K.anchor;
                ma = a(window).width();
                Xa = a(window).height();
                ga = (ga = window.innerHeight) || Xa;
                /modal|bubble/.test(K.display) && (a(".dwc", P).each(function() {
                    e = a(this).outerWidth(!0);
                    s += e;
                    r = e > r ? e : r
                }), e = s > ma ? r : s, h.width(e).css("white-space", s > ma ? "" : "nowrap"));
                ba = t.outerWidth();
                na = t.outerHeight(!0);
                da = na <= ga && ba <= ma;
                "modal" == K.display ? (d = (ma - ba) / 2, g = c + (ga - na) / 2) : "bubble" == K.display ? (v = !0, p = a(".dw-arrw-i", P), d = k.offset(), m = d.top, n = d.left, h = k.outerWidth(), k = k.outerHeight(), d = n - (t.outerWidth(!0) -
                    h) / 2, d = d > ma - ba ? ma - (ba + 20) : d, d = 0 <= d ? d : 20, g = m - na, g < c || m > c + ga ? (t.removeClass("dw-bubble-top").addClass("dw-bubble-bottom"), g = m + k) : t.removeClass("dw-bubble-bottom").addClass("dw-bubble-top"), p = p.outerWidth(), h = n + h / 2 - (d + (ba - p) / 2), a(".dw-arr", P).css({
                    left: Math.max(0, Math.min(h, p))
                })) : (u.width = "100%", "top" == K.display ? g = c : "bottom" == K.display && (g = c + ga - na));
                u.top = 0 > g ? 0 : g;
                u.left = d;
                t.css(u);
                a(".dw-persp", P).height(0).height(g + na > a(document).height() ? g + na : a(document).height());
                v && (g + na > c + ga || m > c + ga) && a(window).scrollTop(g +
                    na - ga)
            }
        };
        H.enable = function() {
            K.disabled = !1;
            Ka && fa.prop("disabled", !1)
        };
        H.disable = function() {
            K.disabled = !0;
            Ka && fa.prop("disabled", !0)
        };
        H.setValue = function(c, e, d, g) {
            H.temp = a.isArray(c) ? c.slice(0) : K.parseValue.call(ua, c + "", H);
            ka(e, d, !1, g)
        };
        H.getValue = function() {
            return H.values
        };
        H.getValues = function() {
            var a = [],
                c;
            for (c in H._selectedValues) a.push(H._selectedValues[c]);
            return a
        };
        H.changeWheel = function(c, e) {
            if (P) {
                var d = 0,
                    g = c.length;
                a.each(K.wheels, function(h, k) {
                    a.each(k, function(h, k) {
                        if (-1 < a.inArray(d, c) &&
                            (Qa[d] = k, a(".dw-ul", P).eq(d).html(r(d)), g--, !g)) return H.position(), W(e, void 0, !0), !1;
                        d++
                    });
                    if (!g) return !1
                })
            }
        };
        H.isVisible = function() {
            return Da
        };
        H.tap = function(a, c) {
            var e, d;
            if (K.tap) a.on("touchstart.dw", function(a) {
                a.preventDefault();
                e = g(a, "X");
                d = g(a, "Y")
            }).on("touchend.dw", function(a) {
                20 > Math.abs(g(a, "X") - e) && 20 > Math.abs(g(a, "Y") - d) && c.call(this, a);
                B = !0;
                setTimeout(function() {
                    B = !1
                }, 300)
            });
            a.on("click.dw", function(a) {
                B || c.call(this, a)
            })
        };
        H.show = function(c) {
            if (K.disabled || Da) return !1;
            "top" == K.display &&
                (E = "slidedown");
            "bottom" == K.display && (E = "slideup");
            z();
            Y("onBeforeShow", []);
            var d, g = 0,
                h = "";
            E && !c && (h = "dw-" + E + " dw-in");
            var k = '\x3cdiv role\x3d"dialog" class\x3d"' + K.theme + " dw-" + K.display + (F ? " dw" + F : "") + '"\x3e' + ("inline" == K.display ? '\x3cdiv class\x3d"dw dwbg dwi"\x3e\x3cdiv class\x3d"dwwr"\x3e' : '\x3cdiv class\x3d"dw-persp"\x3e\x3cdiv class\x3d"dwo"\x3e\x3c/div\x3e\x3cdiv class\x3d"dw dwbg ' + h + '"\x3e\x3cdiv class\x3d"dw-arrw"\x3e\x3cdiv class\x3d"dw-arrw-i"\x3e\x3cdiv class\x3d"dw-arr"\x3e\x3c/div\x3e\x3c/div\x3e\x3c/div\x3e\x3cdiv class\x3d"dwwr"\x3e\x3cdiv aria-live\x3d"assertive" class\x3d"dwv' +
                (K.headerText ? "" : " dw-hidden") + '"\x3e\x3c/div\x3e') + '\x3cdiv class\x3d"dwcc"\x3e';
            a.each(K.wheels, function(c, e) {
                k += '\x3cdiv class\x3d"dwc' + ("scroller" != K.mode ? " dwpm" : " dwsc") + (K.showLabel ? "" : " dwhl") + '"\x3e\x3cdiv class\x3d"dwwc dwrc"\x3e\x3ctable cellpadding\x3d"0" cellspacing\x3d"0"\x3e\x3ctr\x3e';
                a.each(e, function(a, c) {
                    Qa[g] = c;
                    d = void 0 !== c.label ? c.label : a;
                    k += '\x3ctd\x3e\x3cdiv class\x3d"dwwl dwrc dwwl' + g + '"\x3e' + ("scroller" != K.mode ? '\x3cdiv class\x3d"dwb-e dwwb dwwbp" style\x3d"height:' + ca + "px;line-height:" +
                        ca + 'px;"\x3e\x3cspan\x3e+\x3c/span\x3e\x3c/div\x3e\x3cdiv class\x3d"dwb-e dwwb dwwbm" style\x3d"height:' + ca + "px;line-height:" + ca + 'px;"\x3e\x3cspan\x3e\x26ndash;\x3c/span\x3e\x3c/div\x3e' : "") + '\x3cdiv class\x3d"dwl"\x3e' + d + '\x3c/div\x3e\x3cdiv tabindex\x3d"0" aria-live\x3d"off" aria-label\x3d"' + d + '" role\x3d"listbox" class\x3d"dwww"\x3e\x3cdiv class\x3d"dww" style\x3d"height:' + K.rows * ca + "px;min-width:" + K.width + 'px;"\x3e\x3cdiv class\x3d"dw-ul"\x3e';
                    k += r(g);
                    k += '\x3c/div\x3e\x3cdiv class\x3d"dwwol"\x3e\x3c/div\x3e\x3c/div\x3e\x3cdiv class\x3d"dwwo"\x3e\x3c/div\x3e\x3c/div\x3e\x3cdiv class\x3d"dwwol"\x3e\x3c/div\x3e\x3c/div\x3e\x3c/td\x3e';
                    g++
                });
                k += "\x3c/tr\x3e\x3c/table\x3e\x3c/div\x3e\x3c/div\x3e"
            });
            k += "\x3c/div\x3e" + ("inline" != K.display ? '\x3cdiv class\x3d"dwbc' + (K.button3 ? " dwbc-p" : "") + '"\x3e\x3cspan class\x3d"dwbw dwb-s"\x3e\x3cspan class\x3d"dwb dwb-e" role\x3d"button" tabindex\x3d"0"\x3e' + K.setText + "\x3c/span\x3e\x3c/span\x3e" + (K.button3 ? '\x3cspan class\x3d"dwbw dwb-n"\x3e\x3cspan class\x3d"dwb dwb-e" role\x3d"button" tabindex\x3d"0"\x3e' + K.button3Text + "\x3c/span\x3e\x3c/span\x3e" : "") + '\x3cspan class\x3d"dwbw dwb-c"\x3e\x3cspan class\x3d"dwb dwb-e" role\x3d"button" tabindex\x3d"0"\x3e' +
                K.cancelText + "\x3c/span\x3e\x3c/span\x3e\x3c/div\x3e\x3c/div\x3e" : "") + "\x3c/div\x3e\x3c/div\x3e\x3c/div\x3e";
            P = a(k);
            W();
            Y("onMarkupReady", [P]);
            "inline" != K.display ? (P.appendTo("body"), E && !c && (P.addClass("dw-trans"), setTimeout(function() {
                P.removeClass("dw-trans").find(".dw").removeClass(h)
            }, 350))) : fa.is("div") ? fa.html(P) : P.insertAfter(fa);
            Y("onMarkupInserted", [P]);
            Da = !0;
            Ha.init(P, H);
            if ("inline" != K.display) {
                H.tap(a(".dwb-s span", P), function() {
                    H.select()
                });
                H.tap(a(".dwb-c span", P), function() {
                    H.cancel()
                });
                K.button3 && H.tap(a(".dwb-n span", P), K.button3);
                a(window).on("keydown.dw", function(a) {
                    13 == a.keyCode ? H.select() : 27 == a.keyCode && H.cancel()
                });
                if (K.scrollLock) P.on("touchmove touchstart", function(a) {
                    da && a.preventDefault()
                });
                a("input,select,button").each(function() {
                    this.disabled || (a(this).attr("autocomplete") && a(this).data("autocomplete", a(this).attr("autocomplete")), a(this).addClass("dwtd").prop("disabled", !0).attr("autocomplete", "off"))
                });
                H.position();
                a(window).on("orientationchange.dw resize.dw scroll.dw",
                    function(a) {
                        clearTimeout(e);
                        e = setTimeout(function() {
                            var c = "scroll" == a.type;
                            (c && da || !c) && H.position(!c)
                        }, 100)
                    });
                H.alert(K.ariaDesc)
            }
            a(".dwwl", P).on("DOMMouseScroll mousewheel", lb).on(A, jb).on("keydown", fb).on("keyup", kb);
            P.on(A, ".dwb-e", sb).on("keydown", ".dwb-e", function(c) {
                32 == c.keyCode && (c.preventDefault(), c.stopPropagation(), a(this).click())
            });
            Y("onShow", [P, aa])
        };
        H.hide = function(c, e) {
            if (!Da || !1 === Y("onClose", [aa, e])) return !1;
            a(".dwtd").each(function() {
                a(this).prop("disabled", !1).removeClass("dwtd");
                a(this).data("autocomplete") ? a(this).attr("autocomplete", a(this).data("autocomplete")) : a(this).removeAttr("autocomplete")
            });
            P && ("inline" != K.display && E && !c ? (P.addClass("dw-trans").find(".dw").addClass("dw-" + E + " dw-out"), setTimeout(function() {
                P.remove();
                P = null
            }, 350)) : (P.remove(), P = null), a(window).off(".dw"));
            Ea = {};
            Da = !1;
            Ja = !0;
            fa.focus()
        };
        H.select = function() {
            !1 !== H.hide(!1, "set") && (ka(!0, 0, !0), Y("onSelect", [H.val]))
        };
        H.alert = function(a) {
            x.text(a);
            clearTimeout(w);
            w = setTimeout(function() {
                x.text("")
            }, 5E3)
        };
        H.cancel = function() {
            !1 !== H.hide(!1, "cancel") && Y("onCancel", [H.val])
        };
        H.init = function(a) {
            Ha = p({
                defaults: {},
                init: t
            }, Za.themes[a.theme || K.theme]);
            Ya = Za.i18n[a.lang || K.lang];
            p(m, a);
            p(K, Ha.defaults, Ya, m);
            H.settings = K;
            fa.off(".dw");
            if (a = Za.presets[K.preset]) va = a.call(ua, H), p(K, va, m);
            Wa = Math.floor(K.rows / 2);
            ca = K.height;
            E = K.animate;
            Da && H.hide();
            if ("inline" == K.display) H.show();
            else {
                z();
                if (Ka && (void 0 === Ua && (Ua = ua.readOnly), ua.readOnly = !0, K.showOnFocus)) fa.on("focus.dw", function() {
                    Ja || H.show();
                    Ja = !1
                });
                K.showOnTap &&
                    H.tap(fa, function() {
                        H.show()
                    })
            }
        };
        H.trigger = function(a, c) {
            return Y(a, c)
        };
        H.option = function(a, c) {
            var e = {};
            "object" === typeof a ? e = a : e[a] = c;
            H.init(e)
        };
        H.destroy = function() {
            H.hide();
            fa.off(".dw");
            delete D[ua.id];
            Ka && (ua.readOnly = Ua)
        };
        H.getInst = function() {
            return H
        };
        H.values = null;
        H.val = null;
        H.temp = null;
        H._selectedValues = {};
        H.init(m)
    }

    function r(a) {
        for (var c in a)
            if (void 0 !== s[a[c]]) return !0;
        return !1
    }

    function c(a) {
        if ("touchstart" === a.type) C = !0;
        else if (C) return C = !1;
        return !0
    }

    function g(a, c) {
        var d = a.originalEvent,
            g = a.changedTouches;
        return g || d && d.changedTouches ? d ? d.changedTouches[0]["page" + c] : g[0]["page" + c] : a["page" + c]
    }

    function k(c) {
        var d = {
            values: [],
            keys: []
        };
        a.each(c, function(a, c) {
            d.keys.push(a);
            d.values.push(c)
        });
        return d
    }

    function d(a, c, d) {
        var g = a;
        if ("object" === typeof c) return a.each(function() {
            this.id || (z += 1, this.id = "mobiscroll" + z);
            D[this.id] = new u(this, c)
        });
        "string" === typeof c && a.each(function() {
            var a;
            if ((a = D[this.id]) && a[c])
                if (a = a[c].apply(this, Array.prototype.slice.call(d, 1)), void 0 !== a) return g = a, !1
        });
        return g
    }
    var n, B, C, w, x, z = (new Date).getTime(),
        D = {},
        t = function() {},
        s = document.createElement("modernizr").style,
        h = r(["perspectiveProperty", "WebkitPerspective", "MozPerspective", "OPerspective", "msPerspective"]),
        F = function() {
            var a = ["Webkit", "Moz", "O", "ms"],
                c;
            for (c in a)
                if (r([a[c] + "Transform"])) return "-" + a[c].toLowerCase();
            return ""
        }(),
        I = F.replace(/^\-/, "").replace("moz", "Moz"),
        p = a.extend,
        A = "touchstart mousedown",
        J = "touchmove mousemove",
        M = "touchend mouseup",
        O = {
            width: 70,
            height: 40,
            rows: 3,
            delay: 300,
            disabled: !1,
            readonly: !1,
            showOnFocus: !0,
            showOnTap: !0,
            showLabel: !0,
            wheels: [],
            theme: "",
            headerText: "{value}",
            display: "modal",
            mode: "scroller",
            preset: "",
            lang: "en-US",
            setText: "Set",
            cancelText: "Cancel",
            ariaDesc: "Select a value",
            scrollLock: !0,
            tap: !0,
            speedUnit: 0.0012,
            timeUnit: 0.1,
            formatResult: function(a) {
                return a.join(" ")
            },
            parseValue: function(c, d) {
                var g = c.split(" "),
                    h = [],
                    n = 0,
                    p;
                a.each(d.settings.wheels, function(c, d) {
                    a.each(d, function(c, d) {
                        d = d.values ? d : k(d);
                        p = d.keys || d.values; - 1 !== a.inArray(g[n], p) ? h.push(g[n]) : h.push(p[0]);
                        n++
                    })
                });
                return h
            }
        };
    a(function() {
        x = a('\x3cdiv class\x3d"dw-hidden" role\x3d"alert"\x3e\x3c/div\x3e').appendTo("body")
    });
    a(document).on("mouseover mouseup mousedown click", function(a) {
        if (B) return a.stopPropagation(), a.preventDefault(), !1
    });
    a.fn.mobiscroll = function(c) {
        p(this, a.mobiscroll.shorts);
        return d(this, c, arguments)
    };
    a.mobiscroll = a.mobiscroll || {
        setDefaults: function(a) {
            p(O, a)
        },
        presetShort: function(a) {
            this.shorts[a] = function(c) {
                return d(this, p(c, {
                    preset: a
                }), arguments)
            }
        },
        has3d: h,
        shorts: {},
        presets: {},
        themes: {},
        i18n: {}
    };
    a.scroller = a.scroller || a.mobiscroll;
    a.fn.scroller = a.fn.scroller || a.fn.mobiscroll
})(jQuery);
(function(a) {
    var u = a.mobiscroll,
        r = new Date,
        c = {
            dateFormat: "mm/dd/yy",
            dateOrder: "mmddy",
            timeWheels: "hhiiA",
            timeFormat: "hh:ii A",
            startYear: r.getFullYear() - 100,
            endYear: r.getFullYear() + 1,
            monthNames: "January February March April May June July August September October November December".split(" "),
            monthNamesShort: "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split(" "),
            dayNames: "Sunday Monday Tuesday Wednesday Thursday Friday Saturday".split(" "),
            dayNamesShort: "Sun Mon Tue Wed Thu Fri Sat".split(" "),
            shortYearCutoff: "+10",
            monthText: "Month",
            dayText: "Day",
            yearText: "Year",
            hourText: "Hours",
            minuteText: "Minutes",
            secText: "Seconds",
            ampmText: "\x26nbsp;",
            nowText: "Now",
            showNow: !1,
            stepHour: 1,
            stepMinute: 1,
            stepSecond: 1,
            separator: " "
        },
        g = function(g) {
            function d(a, c, d) {
                return void 0 !== M[c] ? +a[M[c]] : void 0 !== d ? d : R[O[c]] ? R[O[c]]() : O[c](R)
            }

            function n(a, c, d, g) {
                a.push({
                    values: d,
                    keys: c,
                    label: g
                })
            }

            function r(a, c) {
                return Math.floor(a / c) * c
            }

            function C(a) {
                var c = d(a, "h", 0);
                return new Date(d(a, "y"), d(a, "m"), d(a, "d", 1), d(a, "a") ?
                    c + 12 : c, d(a, "i", 0), d(a, "s", 0))
            }
            var w = a(this),
                x = {},
                z;
            if (w.is("input")) {
                switch (w.attr("type")) {
                    case "date":
                        z = "yy-mm-dd";
                        break;
                    case "datetime":
                        z = "yy-mm-ddTHH:ii:ssZ";
                        break;
                    case "datetime-local":
                        z = "yy-mm-ddTHH:ii:ss";
                        break;
                    case "month":
                        z = "yy-mm";
                        x.dateOrder = "mmyy";
                        break;
                    case "time":
                        z = "HH:ii:ss"
                }
                var D = w.attr("min"),
                    w = w.attr("max");
                D && (x.minDate = u.parseDate(z, D));
                w && (x.maxDate = u.parseDate(z, w))
            }
            var t, s, h, F, I, D = a.extend({}, g.settings),
                p = a.extend(g.settings, c, x, D),
                A = 0,
                w = [],
                J = [],
                M = {},
                O = {
                    y: "getFullYear",
                    m: "getMonth",
                    d: "getDate",
                    h: function(a) {
                        a = a.getHours();
                        a = ha && 12 <= a ? a - 12 : a;
                        return r(a, S)
                    },
                    i: function(a) {
                        return r(a.getMinutes(), T)
                    },
                    s: function(a) {
                        return r(a.getSeconds(), X)
                    },
                    a: function(a) {
                        return G && 11 < a.getHours() ? 1 : 0
                    }
                },
                V = p.preset,
                m = p.dateOrder,
                v = p.timeWheels,
                N = m.match(/D/),
                G = v.match(/a/i),
                ha = v.match(/h/),
                qa = "datetime" == V ? p.dateFormat + p.separator + p.timeFormat : "time" == V ? p.timeFormat : p.dateFormat,
                R = new Date,
                S = p.stepHour,
                T = p.stepMinute,
                X = p.stepSecond,
                W = p.minDate || new Date(p.startYear, 0, 1),
                Y = p.maxDate || new Date(p.endYear,
                    11, 31, 23, 59, 59);
            z = z || qa;
            if (V.match(/date/i)) {
                a.each(["y", "m", "d"], function(a, c) {
                    t = m.search(RegExp(c, "i")); - 1 < t && J.push({
                        o: t,
                        v: c
                    })
                });
                J.sort(function(a, c) {
                    return a.o > c.o ? 1 : -1
                });
                a.each(J, function(a, c) {
                    M[c.v] = a
                });
                D = [];
                for (x = 0; 3 > x; x++)
                    if (x == M.y) {
                        A++;
                        h = [];
                        s = [];
                        F = W.getFullYear();
                        I = Y.getFullYear();
                        for (t = F; t <= I; t++) s.push(t), h.push(m.match(/yy/i) ? t : (t + "").substr(2, 2));
                        n(D, s, h, p.yearText)
                    } else if (x == M.m) {
                    A++;
                    h = [];
                    s = [];
                    for (t = 0; 12 > t; t++) F = m.replace(/[dy]/gi, "").replace(/mm/, 9 > t ? "0" + (t + 1) : t + 1).replace(/m/, t + 1),
                        s.push(t), h.push(F.match(/MM/) ? F.replace(/MM/, '\x3cspan class\x3d"dw-mon"\x3e' + p.monthNames[t] + "\x3c/span\x3e") : F.replace(/M/, '\x3cspan class\x3d"dw-mon"\x3e' + p.monthNamesShort[t] + "\x3c/span\x3e"));
                    n(D, s, h, p.monthText)
                } else if (x == M.d) {
                    A++;
                    h = [];
                    s = [];
                    for (t = 1; 32 > t; t++) s.push(t), h.push(m.match(/dd/i) && 10 > t ? "0" + t : t);
                    n(D, s, h, p.dayText)
                }
                w.push(D)
            }
            if (V.match(/time/i)) {
                J = [];
                a.each(["h", "i", "s", "a"], function(a, c) {
                    a = v.search(RegExp(c, "i")); - 1 < a && J.push({
                        o: a,
                        v: c
                    })
                });
                J.sort(function(a, c) {
                    return a.o > c.o ? 1 : -1
                });
                a.each(J, function(a, c) {
                    M[c.v] = A + a
                });
                D = [];
                for (x = A; x < A + 4; x++)
                    if (x == M.h) {
                        A++;
                        h = [];
                        s = [];
                        for (t = 0; t < (ha ? 12 : 24); t += S) s.push(t), h.push(ha && 0 == t ? 12 : v.match(/hh/i) && 10 > t ? "0" + t : t);
                        n(D, s, h, p.hourText)
                    } else if (x == M.i) {
                    A++;
                    h = [];
                    s = [];
                    for (t = 0; 60 > t; t += T) s.push(t), h.push(v.match(/ii/) && 10 > t ? "0" + t : t);
                    n(D, s, h, p.minuteText)
                } else if (x == M.s) {
                    A++;
                    h = [];
                    s = [];
                    for (t = 0; 60 > t; t += X) s.push(t), h.push(v.match(/ss/) && 10 > t ? "0" + t : t);
                    n(D, s, h, p.secText)
                } else x == M.a && (A++, s = v.match(/A/), n(D, [0, 1], s ? ["AM", "PM"] : ["am", "pm"], p.ampmText));
                w.push(D)
            }
            g.setDate =
                function(a, c, d, h) {
                    for (var m in M) g.temp[M[m]] = a[O[m]] ? a[O[m]]() : O[m](a);
                    g.setValue(g.temp, c, d, h)
                };
            g.getDate = function(a) {
                return C(a ? g.temp : g.values)
            };
            return {
                button3Text: p.showNow ? p.nowText : void 0,
                button3: p.showNow ? function() {
                    g.setDate(new Date, !1, 0.3, !0)
                } : void 0,
                wheels: w,
                headerText: function(a) {
                    return u.formatDate(qa, C(g.temp), p)
                },
                formatResult: function(a) {
                    return u.formatDate(z, C(a), p)
                },
                parseValue: function(a) {
                    var c = new Date,
                        d, g = [];
                    try {
                        c = u.parseDate(z, a, p)
                    } catch (h) {}
                    for (d in M) g[M[d]] = c[O[d]] ? c[O[d]]() :
                        O[d](c);
                    return g
                },
                validate: function(c, h) {
                    var n = g.temp,
                        s = {
                            y: W.getFullYear(),
                            m: 0,
                            d: 1,
                            h: 0,
                            i: 0,
                            s: 0,
                            a: 0
                        },
                        v = {
                            y: Y.getFullYear(),
                            m: 11,
                            d: 31,
                            h: r(ha ? 11 : 23, S),
                            i: r(59, T),
                            s: r(59, X),
                            a: 1
                        },
                        t = !0,
                        u = !0;
                    a.each("ymdahis".split(""), function(g, h) {
                        if (void 0 !== M[h]) {
                            var k = s[h],
                                r = v[h],
                                w = 31,
                                G = d(n, h),
                                x = a(".dw-ul", c).eq(M[h]),
                                B, e;
                            "d" == h && (B = d(n, "y"), e = d(n, "m"), r = w = 32 - (new Date(B, e, 32)).getDate(), N && a(".dw-li", x).each(function() {
                                var c = a(this),
                                    d = c.data("val"),
                                    g = (new Date(B, e, d)).getDay(),
                                    d = m.replace(/[my]/gi, "").replace(/dd/, 10 >
                                        d ? "0" + d : d).replace(/d/, d);
                                a(".dw-i", c).html(d.match(/DD/) ? d.replace(/DD/, '\x3cspan class\x3d"dw-day"\x3e' + p.dayNames[g] + "\x3c/span\x3e") : d.replace(/D/, '\x3cspan class\x3d"dw-day"\x3e' + p.dayNamesShort[g] + "\x3c/span\x3e"))
                            }));
                            t && W && (k = W[O[h]] ? W[O[h]]() : O[h](W));
                            u && Y && (r = Y[O[h]] ? Y[O[h]]() : O[h](Y));
                            if ("y" != h) {
                                var C = a(".dw-li", x).index(a('.dw-li[data-val\x3d"' + k + '"]', x)),
                                    z = a(".dw-li", x).index(a('.dw-li[data-val\x3d"' + r + '"]', x));
                                a(".dw-li", x).removeClass("dw-v").slice(C, z + 1).addClass("dw-v");
                                "d" == h && a(".dw-li",
                                    x).removeClass("dw-h").slice(w).addClass("dw-h")
                            }
                            G < k && (G = k);
                            G > r && (G = r);
                            t && (t = G == k);
                            u && (u = G == r);
                            if (p.invalid && "d" == h) {
                                var A = [];
                                p.invalid.dates && a.each(p.invalid.dates, function(a, c) {
                                    c.getFullYear() == B && c.getMonth() == e && A.push(c.getDate() - 1)
                                });
                                if (p.invalid.daysOfWeek) {
                                    var D = (new Date(B, e, 1)).getDay(),
                                        F;
                                    a.each(p.invalid.daysOfWeek, function(a, c) {
                                        for (F = c - D; F < w; F += 7) 0 <= F && A.push(F)
                                    })
                                }
                                p.invalid.daysOfMonth && a.each(p.invalid.daysOfMonth, function(a, c) {
                                    c = (c + "").split("/");
                                    c[1] ? c[0] - 1 == e && A.push(c[1] - 1) : A.push(c[0] -
                                        1)
                                });
                                a.each(A, function(c, e) {
                                    a(".dw-li", x).eq(e).removeClass("dw-v")
                                })
                            }
                            n[M[h]] = G
                        }
                    })
                }
            }
        };
    a.each(["date", "time", "datetime"], function(a, c) {
        u.presets[c] = g;
        u.presetShort(c)
    });
    u.formatDate = function(g, d, n) {
        if (!d) return null;
        n = a.extend({}, c, n);
        var r = function(a) {
                for (var c = 0; x + 1 < g.length && g.charAt(x + 1) == a;) c++, x++;
                return c
            },
            u = function(a, c, d) {
                c = "" + c;
                if (r(a))
                    for (; c.length < d;) c = "0" + c;
                return c
            },
            w = function(a, c, d, g) {
                return r(a) ? g[c] : d[c]
            },
            x, z = "",
            D = !1;
        for (x = 0; x < g.length; x++)
            if (D) "'" == g.charAt(x) && !r("'") ? D = !1 : z += g.charAt(x);
            else switch (g.charAt(x)) {
                case "d":
                    z += u("d", d.getDate(), 2);
                    break;
                case "D":
                    z += w("D", d.getDay(), n.dayNamesShort, n.dayNames);
                    break;
                case "o":
                    z += u("o", (d.getTime() - (new Date(d.getFullYear(), 0, 0)).getTime()) / 864E5, 3);
                    break;
                case "m":
                    z += u("m", d.getMonth() + 1, 2);
                    break;
                case "M":
                    z += w("M", d.getMonth(), n.monthNamesShort, n.monthNames);
                    break;
                case "y":
                    z += r("y") ? d.getFullYear() : (10 > d.getYear() % 100 ? "0" : "") + d.getYear() % 100;
                    break;
                case "h":
                    var t = d.getHours(),
                        z = z + u("h", 12 < t ? t - 12 : 0 == t ? 12 : t, 2);
                    break;
                case "H":
                    z += u("H", d.getHours(),
                        2);
                    break;
                case "i":
                    z += u("i", d.getMinutes(), 2);
                    break;
                case "s":
                    z += u("s", d.getSeconds(), 2);
                    break;
                case "a":
                    z += 11 < d.getHours() ? "pm" : "am";
                    break;
                case "A":
                    z += 11 < d.getHours() ? "PM" : "AM";
                    break;
                case "'":
                    r("'") ? z += "'" : D = !0;
                    break;
                default:
                    z += g.charAt(x)
            }
        return z
    };
    u.parseDate = function(g, d, n) {
        var r = new Date;
        if (!g || !d) return r;
        d = "object" == typeof d ? d.toString() : d + "";
        var u = a.extend({}, c, n),
            w = u.shortYearCutoff;
        n = r.getFullYear();
        var x = r.getMonth() + 1,
            z = r.getDate(),
            D = -1,
            t = r.getHours(),
            r = r.getMinutes(),
            s = 0,
            h = -1,
            F = !1,
            I = function(a) {
                (a =
                    M + 1 < g.length && g.charAt(M + 1) == a) && M++;
                return a
            },
            p = function(a) {
                I(a);
                a = RegExp("^\\d{1," + ("@" == a ? 14 : "!" == a ? 20 : "y" == a ? 4 : "o" == a ? 3 : 2) + "}");
                a = d.substr(J).match(a);
                if (!a) return 0;
                J += a[0].length;
                return parseInt(a[0], 10)
            },
            A = function(a, c, g) {
                a = I(a) ? g : c;
                for (c = 0; c < a.length; c++)
                    if (d.substr(J, a[c].length).toLowerCase() == a[c].toLowerCase()) return J += a[c].length, c + 1;
                return 0
            },
            J = 0,
            M;
        for (M = 0; M < g.length; M++)
            if (F) "'" == g.charAt(M) && !I("'") ? F = !1 : J++;
            else switch (g.charAt(M)) {
                case "d":
                    z = p("d");
                    break;
                case "D":
                    A("D", u.dayNamesShort,
                        u.dayNames);
                    break;
                case "o":
                    D = p("o");
                    break;
                case "m":
                    x = p("m");
                    break;
                case "M":
                    x = A("M", u.monthNamesShort, u.monthNames);
                    break;
                case "y":
                    n = p("y");
                    break;
                case "H":
                    t = p("H");
                    break;
                case "h":
                    t = p("h");
                    break;
                case "i":
                    r = p("i");
                    break;
                case "s":
                    s = p("s");
                    break;
                case "a":
                    h = A("a", ["am", "pm"], ["am", "pm"]) - 1;
                    break;
                case "A":
                    h = A("A", ["am", "pm"], ["am", "pm"]) - 1;
                    break;
                case "'":
                    I("'") ? J++ : F = !0;
                    break;
                default:
                    J++
            }
        100 > n && (n += (new Date).getFullYear() - (new Date).getFullYear() % 100 + (n <= ("string" != typeof w ? w : (new Date).getFullYear() % 100 +
            parseInt(w, 10)) ? 0 : -100));
        if (-1 < D) {
            x = 1;
            z = D;
            do {
                u = 32 - (new Date(n, x - 1, 32)).getDate();
                if (z <= u) break;
                x++;
                z -= u
            } while (1)
        }
        t = new Date(n, x - 1, z, -1 == h ? t : h && 12 > t ? t + 12 : !h && 12 == t ? 0 : t, r, s);
        if (t.getFullYear() != n || t.getMonth() + 1 != x || t.getDate() != z) throw "Invalid date";
        return t
    }
})(jQuery);
(function(a) {
    var u = a.mobiscroll,
        r = {
            invalid: [],
            showInput: !0,
            inputClass: ""
        },
        c = function(c) {
            function k(c, g, h, k) {
                for (var n = 0; n < g;) {
                    var p = a(".dwwl" + n, c),
                        r = d(k, n, h);
                    a.each(r, function(c, d) {
                        a('.dw-li[data-val\x3d"' + d + '"]', p).removeClass("dw-v")
                    });
                    n++
                }
            }

            function d(a, c, d) {
                for (var g = 0, h, k = []; g < c;) {
                    var n = a[g];
                    for (h in d)
                        if (d[h].key == n) {
                            d = d[h].children;
                            break
                        }
                    g++
                }
                for (g = 0; g < d.length;) d[g].invalid && k.push(d[g].key), g++;
                return k
            }

            function n(a, c) {
                for (var d = []; a;) d[--a] = !0;
                d[c] = !1;
                return d
            }

            function u(a, c, d) {
                var g = 0,
                    h,
                    k, n = [],
                    p = J;
                if (c)
                    for (h = 0; h < c; h++) n[h] = [{}];
                for (; g < a.length;) {
                    h = n;
                    c = g;
                    for (var r = p, s = {
                            keys: [],
                            values: [],
                            label: M[g]
                        }, t = 0; t < r.length;) s.values.push(r[t].value), s.keys.push(r[t].key), t++;
                    h[c] = [s];
                    h = 0;
                    for (c = void 0; h < p.length && void 0 === c;) {
                        if (p[h].key == a[g] && (void 0 !== d && g <= d || void 0 === d)) c = h;
                        h++
                    }
                    if (void 0 !== c && p[c].children) g++, p = p[c].children;
                    else if ((k = C(p)) && k.children) g++, p = k.children;
                    else break
                }
                return n
            }

            function C(a, c) {
                if (!a) return !1;
                for (var d = 0, g; d < a.length;)
                    if (!(g = a[d++]).invalid) return c ? d - 1 : g;
                return !1
            }

            function w(c, d) {
                a(".dwc", c).css("display", "").slice(d).hide()
            }

            function x(a, c) {
                var d = [],
                    g = J,
                    h = 0,
                    k = !1,
                    n, p;
                if (void 0 !== a[h] && h <= c) {
                    k = 0;
                    n = a[h];
                    for (p = void 0; k < g.length && void 0 === p;) g[k].key == a[h] && !g[k].invalid && (p = k), k++
                } else p = C(g, !0), n = g[p].key;
                k = void 0 !== p ? g[p].children : !1;
                for (d[h] = n; k;) {
                    g = g[p].children;
                    h++;
                    if (void 0 !== a[h] && h <= c) {
                        k = 0;
                        n = a[h];
                        for (p = void 0; k < g.length && void 0 === p;) g[k].key == a[h] && !g[k].invalid && (p = k), k++
                    } else p = C(g, !0), p = !1 === p ? void 0 : p, n = g[p].key;
                    k = void 0 !== p && C(g[p].children) ? g[p].children :
                        !1;
                    d[h] = n
                }
                return {
                    lvl: h + 1,
                    nVector: d
                }
            }

            function z(c) {
                var d = [];
                I = I > p++ ? I : p;
                c.children("li").each(function(c) {
                    var g = a(this),
                        h = g.clone();
                    h.children("ul,ol").remove();
                    var h = h.html().replace(/^\s\s*/, "").replace(/\s\s*$/, ""),
                        k = g.data("invalid") ? !0 : !1;
                    c = {
                        key: g.data("val") || c,
                        value: h,
                        invalid: k,
                        children: null
                    };
                    g = g.children("ul,ol");
                    g.length && (c.children = z(g));
                    d.push(c)
                });
                p--;
                return d
            }
            var D = a.extend({}, c.settings),
                t = a.extend(c.settings, r, D),
                D = a(this),
                s, h, F = this.id + "_dummy",
                I = 0,
                p = 0,
                A = {},
                J = t.wheelArray || z(D),
                M =
                function(a) {
                    var c = [],
                        d;
                    for (d = 0; d < a; d++) c[d] = t.labels && t.labels[d] ? t.labels[d] : d;
                    return c
                }(I),
                O = [],
                V = function(a) {
                    for (var c = [], d, g = !0, h = 0; g;)
                        if (d = C(a), c[h++] = d.key, g = d.children) a = d.children;
                    return c
                }(J),
                V = u(V, I);
            a("#" + F).remove();
            t.showInput && (s = a('\x3cinput type\x3d"text" id\x3d"' + F + '" value\x3d"" class\x3d"' + t.inputClass + '" readonly /\x3e').insertBefore(D), c.settings.anchor = s, t.showOnFocus && s.focus(function() {
                c.show()
            }), t.showOnTap && c.tap(s, function() {
                c.show()
            }));
            t.wheelArray || D.hide().closest(".ui-field-contain").trigger("create");
            return {
                width: 50,
                wheels: V,
                headerText: !1,
                onBeforeShow: function(a) {
                    a = c.temp;
                    O = a.slice(0);
                    c.settings.wheels = u(a, I, I);
                    h = !0
                },
                onSelect: function(a, c) {
                    s && s.val(a)
                },
                onChange: function(a, c) {
                    s && "inline" == t.display && s.val(a)
                },
                onClose: function() {
                    s && s.blur()
                },
                onShow: function(c) {
                    a(".dwwl", c).on("mousedown touchstart", function() {
                        clearTimeout(A[a(".dwwl", c).index(this)])
                    })
                },
                validate: function(a, d, p) {
                    var r = c.temp;
                    if (void 0 !== d && O[d] != r[d] || void 0 === d && !h) {
                        c.settings.wheels = u(r, null, d);
                        var s = [],
                            t = (d || 0) + 1,
                            z = x(r, d);
                        void 0 !==
                            d && (c.temp = z.nVector.slice(0));
                        for (; t < z.lvl;) s.push(t++);
                        w(a, z.lvl);
                        O = c.temp.slice(0);
                        if (s.length) return h = !0, c.settings.readonly = n(I, d), clearTimeout(A[d]), A[d] = setTimeout(function() {
                            c.changeWheel(s);
                            c.settings.readonly = !1
                        }, 1E3 * p), !1;
                        k(a, z.lvl, J, c.temp)
                    } else z = x(r, r.length), k(a, z.lvl, J, r), w(a, z.lvl);
                    h = !1
                }
            }
        };
    a.each(["list", "image", "treelist"], function(a, k) {
        u.presets[k] = c;
        u.presetShort(k)
    })
})(jQuery);
(function(a) {
    var u = {
        inputClass: "",
        invalid: [],
        rtl: !1,
        group: !1,
        groupLabel: "Groups"
    };
    a.mobiscroll.presetShort("select");
    a.mobiscroll.presets.select = function(r) {
        function c() {
            var c, d = 0,
                g = [],
                k = [],
                p = [
                    []
                ];
            n.group ? (n.rtl && (d = 1), a("optgroup", B).each(function(c) {
                g.push(a(this).attr("label"));
                k.push(c)
            }), p[d] = [{
                values: g,
                keys: k,
                label: n.groupLabel
            }], c = x, d += n.rtl ? -1 : 1) : c = B;
            g = [];
            k = [];
            a("option", c).each(function() {
                var c = a(this).attr("value");
                g.push(a(this).text());
                k.push(c);
                a(this).prop("disabled") && F.push(c)
            });
            p[d] = [{
                values: g,
                keys: k,
                label: h
            }];
            return p
        }

        function g(a, c) {
            var d = [];
            if (C) {
                var g = [],
                    h = 0;
                for (h in r._selectedValues) g.push(p[h]), d.push(h);
                O.val(g.join(", "))
            } else O.val(a), d = c ? r.values[J] : null;
            c && (t = !0, B.val(d).trigger("change"))
        }

        function k(a) {
            if (C && a.hasClass("dw-v") && a.closest(".dw").find(".dw-ul").index(a.closest(".dw-ul")) == J) {
                var c = a.attr("data-val");
                a.hasClass("dw-msel") ? (a.removeClass("dw-msel").removeAttr("aria-selected"), delete r._selectedValues[c]) : (a.addClass("dw-msel").attr("aria-selected", "true"),
                    r._selectedValues[c] = c);
                "inline" == n.display && g(c, !0);
                return !1
            }
        }
        var d = a.extend({}, r.settings),
            n = a.extend(r.settings, u, d),
            B = a(this),
            C = B.prop("multiple"),
            d = this.id + "_dummy",
            w = C ? B.val() ? B.val()[0] : a("option", B).attr("value") : B.val(),
            x = B.find('option[value\x3d"' + w + '"]').parent(),
            z = x.index() + "",
            D = z,
            t;
        a('label[for\x3d"' + this.id + '"]').attr("for", d);
        var s = a('label[for\x3d"' + d + '"]'),
            h = void 0 !== n.label ? n.label : s.length ? s.text() : B.attr("name"),
            F = [],
            I = [],
            p = {},
            A, J, M, O, V = n.readonly;
        n.group && !a("optgroup", B).length &&
            (n.group = !1);
        n.invalid.length || (n.invalid = F);
        n.group ? n.rtl ? (A = 1, J = 0) : (A = 0, J = 1) : (A = -1, J = 0);
        a("#" + d).remove();
        O = a('\x3cinput type\x3d"text" id\x3d"' + d + '" class\x3d"' + n.inputClass + '" readonly /\x3e').insertBefore(B);
        a("option", B).each(function() {
            p[a(this).attr("value")] = a(this).text()
        });
        n.showOnFocus && O.focus(function() {
            r.show()
        });
        n.showOnTap && r.tap(O, function() {
            r.show()
        });
        d = B.val() || [];
        s = 0;
        for (s; s < d.length; s++) r._selectedValues[d[s]] = d[s];
        g(p[w]);
        B.off(".dwsel").on("change.dwsel", function() {
            t || r.setValue(C ?
                B.val() || [] : [B.val()], !0);
            t = !1
        }).hide().closest(".ui-field-contain").trigger("create");
        r._setValue || (r._setValue = r.setValue);
        r.setValue = function(d, h, k, s, u) {
            var t = a.isArray(d) ? d[0] : d;
            w = void 0 !== t ? t : a("option", B).attr("value");
            if (C) {
                r._selectedValues = {};
                t = 0;
                for (t; t < d.length; t++) r._selectedValues[d[t]] = d[t]
            }
            n.group ? (x = B.find('option[value\x3d"' + w + '"]').parent(), D = x.index(), d = n.rtl ? [w, x.index()] : [x.index(), w], D !== z && (n.wheels = c(), r.changeWheel([J]), z = D + "")) : d = [w];
            r._setValue(d, h, k, s, u);
            h && (h = C ? !0 : w !==
                B.val(), g(p[w], h))
        };
        r.getValue = function(a) {
            return (a ? r.temp : r.values)[J]
        };
        return {
            width: 50,
            wheels: void 0,
            headerText: !1,
            multiple: C,
            anchor: O,
            formatResult: function(a) {
                return p[a[J]]
            },
            parseValue: function() {
                var c = B.val() || [],
                    d = 0;
                if (C) {
                    r._selectedValues = {};
                    for (d; d < c.length; d++) r._selectedValues[c[d]] = c[d]
                }
                w = C ? B.val() ? B.val()[0] : a("option", B).attr("value") : B.val();
                x = B.find('option[value\x3d"' + w + '"]').parent();
                D = x.index();
                z = D + "";
                return n.group && n.rtl ? [w, D] : n.group ? [D, w] : [w]
            },
            validate: function(d, g, h) {
                if (void 0 ===
                    g && C) {
                    var k = r._selectedValues,
                        p = 0;
                    a(".dwwl" + J + " .dw-li", d).removeClass("dw-msel").removeAttr("aria-selected");
                    for (p in k) a(".dwwl" + J + ' .dw-li[data-val\x3d"' + k[p] + '"]', d).addClass("dw-msel").attr("aria-selected", "true")
                }
                if (g === A)
                    if (D = r.temp[A], D !== z) {
                        if (x = B.find("optgroup").eq(D), D = x.index(), w = (w = x.find("option").eq(0).val()) || B.val(), n.wheels = c(), n.group) return r.temp = n.rtl ? [w, D] : [D, w], n.readonly = [n.rtl, !n.rtl], clearTimeout(M), M = setTimeout(function() {
                            r.changeWheel([J]);
                            n.readonly = V;
                            z = D + ""
                        }, 1E3 * h), !1
                    } else n.readonly = V;
                else w = r.temp[J];
                var s = a(".dw-ul", d).eq(J);
                a.each(n.invalid, function(c, d) {
                    a('.dw-li[data-val\x3d"' + d + '"]', s).removeClass("dw-v")
                })
            },
            onBeforeShow: function(a) {
                n.wheels = c();
                n.group && (r.temp = n.rtl ? [w, x.index()] : [x.index(), w])
            },
            onMarkupReady: function(c) {
                a(".dwwl" + A, c).on("mousedown touchstart", function() {
                    clearTimeout(M)
                });
                if (C) {
                    c.addClass("dwms");
                    a(".dwwl", c).eq(J).addClass("dwwms").attr("aria-multiselectable", "true");
                    a(".dwwl", c).on("keydown", function(c) {
                        32 == c.keyCode && (c.preventDefault(),
                            c.stopPropagation(), k(a(".dw-sel", this)))
                    });
                    I = {};
                    for (var d in r._selectedValues) I[d] = r._selectedValues[d]
                }
            },
            onValueTap: k,
            onSelect: function(a) {
                g(a, !0);
                n.group && (r.values = null)
            },
            onCancel: function() {
                n.group && (r.values = null);
                if (C) {
                    r._selectedValues = {};
                    for (var a in I) r._selectedValues[a] = I[a]
                }
            },
            onChange: function(a) {
                "inline" == n.display && !C && (O.val(a), t = !0, B.val(r.temp[J]).trigger("change"))
            },
            onClose: function() {
                O.blur()
            }
        }
    }
})(jQuery);
(function(a) {
    var u = {
        defaults: {
            dateOrder: "Mddyy",
            mode: "mixed",
            rows: 5,
            width: 70,
            height: 36,
            showLabel: !1,
            useShortLabels: !0
        }
    };
    a.mobiscroll.themes["android-ics"] = u;
    a.mobiscroll.themes["android-ics light"] = u
})(jQuery);