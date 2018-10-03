/*

$.Link (part of noUiSlider) - WTFPL 
$.fn.noUiSlider - WTFPL - refreshless.com/nouislider/ */
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
        this.$element = a(c).on("click.dismiss.modal", '[data-dismiss\x3d"modal"]', a.proxy(this.hide, this));
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
                    c.$element.on("focus").trigger("shown")
                }) : c.$element.on("focus").trigger("shown")
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
                c.$element[0] !== a.target && !c.$element.has(a.target).length && c.$element.trigger("focus")
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
                this.$backdrop.on("click", "static" == this.options.backdrop ? a.proxy(this.$element[0].focus, this.$element[0]) : a.proxy(this.hide, this));
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
                r(c), k = g.hasClass("open"), u(), k || g.toggleClass("open"), c.trigger("focus"), !1
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
            a("#" + g).on("load", function() {
                var g, d = this.contentWindow.document.body.innerHTML;
                try {
                    g = JSON.parse(d)
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
            u.on("submit", function(a) {
                a.stopPropagation()
            }).trigger("submit")
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
        d.trigger("change");
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
            $('.error input:not([type\x3d"hidden"])').first().trigger("focus")
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
    a.on("click", function() {
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
    a.on("click", function() {
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
                    d.trigger("blur")
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
            fa.trigger("focus")
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