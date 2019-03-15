/*

$.Link (part of noUiSlider) - WTFPL
$.fn.noUiSlider - WTFPL - refreshless.com/nouislider/ */
!function (t) {
	"function" == typeof define && define.amd ? "undefined" != typeof jQuery ? define(["jquery"], t) : define([], t) : "undefined" != typeof jQuery ? t(jQuery) : t()
}
(function (t, e) {
	function n(t) {
		return function (t, n, i) {
			for (var o = 0, a = t.length >> 0; o < a; )
				o in t && (i = n.call(e, i, t[o], o, t)), ++o;
			return i
		}
		(String(t).split(/&|;/), function (t, n) {
			try {
				n = decodeURIComponent(n.replace(/\+/g, " "))
			} catch (t) {}
			var o,
			a = n.indexOf("=");
			t: {
				for (var r, s = n.length, l = 0; l < s; ++l)
					if (r = n[l], "]" == r && (o = !1), "[" == r && (o = !0), "=" == r && !o) {
						o = l;
						break t
					}
				o = void 0
			}
			if (s = n.substr(0, o || a), o = (o = n.substr(o || a, n.length)).substr(o.indexOf("=") + 1, o.length), "" == s && (s = n, o = ""), a = s, s = o, ~a.indexOf("]")) {
				var c = a.split("[");
				!function t(e, n, o, a) {
					var r = e.shift();
					if (r) {
						var s = n[o] = n[o] || [];
						if ("]" == r)
							if (i(s))
								"" != a && s.push(a);
							else if ("object" == typeof s) {
								n = e = s,
								o = [];
								for (prop in n)
									n.hasOwnProperty(prop) && o.push(prop);
								e[o.length] = a
							} else
								n[o] = [n[o], a];
						else {
							if (~r.indexOf("]") && (r = r.substr(0, r.length - 1)), !d.test(r) && i(s))
								if (0 == n[o].length)
									s = n[o] = {};
								else {
									var l;
									s = {};
									for (l in n[o])
										s[l] = n[o][l];
									n[o] = s
								}
							t(e, s, r, a)
						}
					} else
						i(n[o]) ? n[o].push(a) : n[o] = "object" == typeof n[o] ? a : void 0 === n[o] ? a : [n[o], a]
				}
				(c, t, "base", s)
			} else {
				if (!d.test(a) && i(t.base)) {
					o = {};
					for (c in t.base)
						o[c] = t.base[c];
					t.base = o
				}
				o = (c = t.base)[a],
				e === o ? c[a] = s : i(o) ? o.push(s) : c[a] = [o, s]
			}
			return t
		}, {
			base: {}
		}).base
	}
	function i(t) {
		return "[object Array]" === Object.prototype.toString.call(t)
	}
	function o(t, i) {
		return 1 === arguments.length && !0 === t && (i = !0, t = e), {
			data: function (t, e) {
				for (var i = decodeURI(t), o = (i = l[e ? "strict" : "loose"].exec(i), {
						attr: {},
						param: {},
						seg: {}
					}), a = 14; a--; )
					o.attr[r[a]] = i[a] || "";
				return o.param.query = n(o.attr.query),
				o.param.fragment = n(o.attr.fragment),
				o.seg.path = o.attr.path.replace(/^\/+|\/+$/g, "").split("/"),
				o.seg.fragment = o.attr.fragment.replace(/^\/+|\/+$/g, "").split("/"),
				o.attr.base = o.attr.host ? (o.attr.protocol ? o.attr.protocol + "://" + o.attr.host : o.attr.host) + (o.attr.port ? ":" + o.attr.port : "") : "",
				o
			}
			(t = t || window.location.toString(), i || !1),
			attr: function (t) {
				return void 0 !== (t = s[t] || t) ? this.data.attr[t] : this.data.attr
			},
			param: function (t) {
				return void 0 !== t ? this.data.param.query[t] : this.data.param.query
			},
			fparam: function (t) {
				return void 0 !== t ? this.data.param.fragment[t] : this.data.param.fragment
			},
			segment: function (t) {
				return void 0 === t ? this.data.seg.path : (t = 0 > t ? this.data.seg.path.length + t : t - 1, this.data.seg.path[t])
			},
			fsegment: function (t) {
				return void 0 === t ? this.data.seg.fragment : (t = 0 > t ? this.data.seg.fragment.length + t : t - 1, this.data.seg.fragment[t])
			}
		}
	}
	var a = {
		a: "href",
		img: "src",
		form: "action",
		base: "href",
		script: "src",
		iframe: "src",
		link: "href"
	},
	r = "source protocol authority userInfo user password host port relative path directory file query fragment".split(" "),
	s = {
		anchor: "fragment"
	},
	l = {
		strict: /^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*):?([^:@]*))?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/,
		loose: /^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*):?([^:@]*))?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/
	},
	d = /^[0-9]+$/;
	void 0 !== t ? (t.fn.url = function (e) {
		var n,
		i = "";
		return this.length && (i = t(this).attr(void 0 !== (n = (n = this[0]).tagName) ? a[n.toLowerCase()] : n) || ""),
		o(i, e)
	}, t.url = o) : window.purl = o
});
var $Apprise = null, $overlay = null, $body = null, $window = null, $cA = null, AppriseQueue = [];
function Apprise(t, e) {
	if (void 0 === t || !t)
		return !1;
	var n = this,
	i = $('<div class="apprise-inner">'),
	o = $('<div class="apprise-buttons">'),
	a = $('<input type="text">'),
	r = {
		animation: 700,
		buttons: {
			confirm: {
				action: function () {
					n.dissapear()
				},
				className: null,
				id: "confirm",
				text: "Ok"
			}
		},
		input: !1,
		override: !0
	};
	$.extend(r, e),
	"close" == t ? $cA.dissapear() : $Apprise.is(":visible") ? AppriseQueue.push({
		text: t,
		options: r
	}) : (this.adjustWidth = function () {
		var t = $window.width(),
		e = "20%",
		n = "40%";
		800 >= t ? (e = "90%", n = "5%") : 1400 >= t && 800 < t ? (e = "70%", n = "15%") : 1800 >= t && 1400 < t ? (e = "50%", n = "25%") : 2200 >= t && 1800 < t && (e = "30%", n = "35%"),
		$Apprise.css("width", e).css("left", n)
	}, this.dissapear = function () {
		$Apprise.animate({
			top: "-100%"
		}, r.animation, function () {
			$overlay.fadeOut(300),
			$Apprise.hide(),
			$window.unbind("beforeunload"),
			$window.unbind("keydown"),
			AppriseQueue[0] && (Apprise(AppriseQueue[0].text, AppriseQueue[0].options), AppriseQueue.splice(0, 1))
		})
	}, this.keyPress = function () {
		$window.bind("keydown", function (t) {
			27 === t.keyCode ? r.buttons.cancel ? $("#apprise-btn-" + r.buttons.cancel.id).trigger("click") : n.dissapear() : 13 === t.keyCode && (r.buttons.confirm ? $("#apprise-btn-" + r.buttons.confirm.id).trigger("click") : n.dissapear())
		})
	}, $.each(r.buttons, function (t, e) {
			if (e) {
				var n = $('<button id="apprise-btn-' + e.id + '">').append(e.text);
				e.className && n.addClass(e.className),
				o.append(n),
				n.on("click", function () {
					var t = {
						clicked: e,
						input: a.val() ? a.val() : null
					};
					e.action(t)
				})
			}
		}), r.override && $window.bind("beforeunload", function (t) {
			return "An alert requires attention"
		}), n.adjustWidth(), $window.resize(function () {
			n.adjustWidth()
		}), $Apprise.html("").append(i.append('<div class="apprise-content">' + t + "</div>")).append(o), $cA = this, r.input && i.find(".apprise-content").append($('<div class="apprise-input">').append(a)), $overlay.fadeIn(300), $Apprise.show().animate({
			top: "20%"
		}, r.animation, function () {
			n.keyPress()
		}), r.input && a.focus())
}
$(function () {
	$Apprise = $('<div class="apprise">'),
	$overlay = $('<div class="apprise-overlay">'),
	$body = $("body"),
	$window = $(window),
	$body.append($overlay.css("opacity", ".94")).append($Apprise)
}), function (t) {
	t(function () {
		var e,
		n = t.support;
		t: {
			e = document.createElement("bootstrap");
			var i,
			o = {
				WebkitTransition: "webkitTransitionEnd",
				MozTransition: "transitionend",
				OTransition: "oTransitionEnd otransitionend",
				transition: "transitionend"
			};
			for (i in o)
				if (void 0 !== e.style[i]) {
					e = o[i];
					break t
				}
			e = void 0
		}
		n.transition = e && {
			end: e
		}
	})
}
(window.jQuery), function (t) {
	var e = function (e) {
		t(e).on("click", '[data-dismiss="alert"]', this.close)
	};
	e.prototype.close = function (e) {
		function n() {
			i.trigger("closed").remove()
		}
		var i,
		o = t(this),
		a = o.attr("data-target");
		a || (a = (a = o.attr("href")) && a.replace(/.*(?=#[^\s]*$)/, "")),
		i = t(a),
		e && e.preventDefault(),
		i.length || (i = o.hasClass("alert") ? o : o.parent()),
		i.trigger(e = t.Event("close")),
		e.isDefaultPrevented() || (i.removeClass("in"), t.support.transition && i.hasClass("fade") ? i.on(t.support.transition.end, n) : n())
	};
	var n = t.fn.alert;
	t.fn.alert = function (n) {
		return this.each(function () {
			var i = t(this),
			o = i.data("alert");
			o || i.data("alert", o = new e(this)),
			"string" == typeof n && o[n].call(i)
		})
	},
	t.fn.alert.Constructor = e,
	t.fn.alert.noConflict = function () {
		return t.fn.alert = n,
		this
	},
	t(document).on("click.alert.data-api", '[data-dismiss="alert"]', e.prototype.close)
}
(window.jQuery), function (t) {
	var e = function (e, n) {
		this.options = n,
		this.$element = t(e).on("click.dismiss.modal", '[data-dismiss="modal"]', t.proxy(this.hide, this)),
		this.options.remote && this.$element.find(".modal-body").load(this.options.remote)
	};
	e.prototype = {
		constructor: e,
		toggle: function () {
			return this[this.isShown ? "hide" : "show"]()
		},
		show: function () {
			var e = this,
			n = t.Event("show");
			this.$element.trigger(n),
			!this.isShown && !n.isDefaultPrevented() && (this.isShown = !0, this.escape(), this.backdrop(function () {
					var n = t.support.transition && e.$element.hasClass("fade");
					e.$element.parent().length || e.$element.appendTo(document.body),
					e.$element.show(),
					n && e.$element[0].offsetWidth,
					e.$element.addClass("in").attr("aria-hidden", !1),
					e.enforceFocus(),
					n ? e.$element.one(t.support.transition.end, function () {
						e.$element.on("focus").trigger("shown")
					}) : e.$element.on("focus").trigger("shown")
				}))
		},
		hide: function (e) {
			e && e.preventDefault(),
			e = t.Event("hide"),
			this.$element.trigger(e),
			this.isShown && !e.isDefaultPrevented() && (this.isShown = !1, this.escape(), t(document).off("focusin.modal"), this.$element.removeClass("in").attr("aria-hidden", !0), t.support.transition && this.$element.hasClass("fade") ? this.hideWithTransition() : this.hideModal())
		},
		enforceFocus: function () {
			var e = this;
			t(document).on("focusin.modal", function (t) {
				e.$element[0] !== t.target && !e.$element.has(t.target).length && e.$element.trigger("focus")
			})
		},
		escape: function () {
			var t = this;
			this.isShown && this.options.keyboard ? this.$element.on("keyup.dismiss.modal", function (e) {
				27 == e.which && t.hide()
			}) : this.isShown || this.$element.off("keyup.dismiss.modal")
		},
		hideWithTransition: function () {
			var e = this,
			n = setTimeout(function () {
					e.$element.off(t.support.transition.end),
					e.hideModal()
				}, 500);
			this.$element.one(t.support.transition.end, function () {
				clearTimeout(n),
				e.hideModal()
			})
		},
		hideModal: function () {
			var t = this;
			this.$element.hide(),
			this.backdrop(function () {
				t.removeBackdrop(),
				t.$element.trigger("hidden")
			})
		},
		removeBackdrop: function () {
			this.$backdrop && this.$backdrop.remove(),
			this.$backdrop = null
		},
		backdrop: function (e) {
			var n = this.$element.hasClass("fade") ? "fade" : "";
			if (this.isShown && this.options.backdrop) {
				var i = t.support.transition && n;
				this.$backdrop = t('<div class="modal-backdrop ' + n + '" />').appendTo(document.body),
				this.$backdrop.on("click", "static" == this.options.backdrop ? t.proxy(this.$element[0].focus, this.$element[0]) : t.proxy(this.hide, this)),
				i && this.$backdrop[0].offsetWidth,
				this.$backdrop.addClass("in"),
				e && (i ? this.$backdrop.one(t.support.transition.end, e) : e())
			} else !this.isShown && this.$backdrop ? (this.$backdrop.removeClass("in"), t.support.transition && this.$element.hasClass("fade") ? this.$backdrop.one(t.support.transition.end, e) : e()) : e && e()
		}
	};
	var n = t.fn.modal;
	t.fn.modal = function (n) {
		return this.each(function () {
			var i = t(this),
			o = i.data("modal"),
			a = t.extend({}, t.fn.modal.defaults, i.data(), "object" == typeof n && n);
			o || i.data("modal", o = new e(this, a)),
			"string" == typeof n ? o[n]() : a.show && o.show()
		})
	},
	t.fn.modal.defaults = {
		backdrop: !0,
		keyboard: !0,
		show: !0
	},
	t.fn.modal.Constructor = e,
	t.fn.modal.noConflict = function () {
		return t.fn.modal = n,
		this
	},
	t(document).on("click.modal.data-api", '[data-toggle="modal"]', function (e) {
		var n = t(this),
		i = n.attr("href"),
		o = t(n.attr("data-target") || i && i.replace(/.*(?=#[^\s]+$)/, ""));
		i = o.data("modal") ? "toggle" : t.extend({
				remote: !/#/.test(i) && i
			}, o.data(), n.data());
		e.preventDefault(),
		o.modal(i).one("hide", function () {
			n.focus()
		})
	})
}
(window.jQuery), function (t) {
	function e() {
		t(i).each(function () {
			n(t(this)).removeClass("open")
		})
	}
	function n(e) {
		var n = e.attr("data-target");
		return n || (n = (n = e.attr("href")) && /#/.test(n) && n.replace(/.*(?=#[^\s]*$)/, "")),
		(n = n && t(n)) && n.length || (n = e.parent()),
		n
	}
	var i = "[data-toggle=dropdown]",
	o = function (e) {
		var n = t(e).on("click.dropdown.data-api", this.toggle);
		t("html").on("click.dropdown.data-api", function () {
			n.parent().removeClass("open")
		})
	};
	o.prototype = {
		constructor: o,
		toggle: function (i) {
			var o,
			a;
			if (!(i = t(this)).is(".disabled, :disabled"))
				return o = n(i), a = o.hasClass("open"), e(), a || o.toggleClass("open"), i.trigger("focus"), !1
		},
		keydown: function (e) {
			var o,
			a,
			r;
			if (/(38|40|27)/.test(e.keyCode) && (o = t(this), e.preventDefault(), e.stopPropagation(), !o.is(".disabled, :disabled"))) {
				if (!(r = (a = n(o)).hasClass("open")) || r && 27 == e.keyCode)
					return 27 == e.which && a.find(i).focus(), o.click();
				(o = t("[role=menu] li:not(.divider):visible a", a)).length && (a = o.index(o.filter(":focus")), 38 == e.keyCode && 0 < a && a--, 40 == e.keyCode && a < o.length - 1 && a++, ~a || (a = 0), o.eq(a).focus())
			}
		}
	};
	var a = t.fn.dropdown;
	t.fn.dropdown = function (e) {
		return this.each(function () {
			var n = t(this),
			i = n.data("dropdown");
			i || n.data("dropdown", i = new o(this)),
			"string" == typeof e && i[e].call(n)
		})
	},
	t.fn.dropdown.Constructor = o,
	t.fn.dropdown.noConflict = function () {
		return t.fn.dropdown = a,
		this
	},
	t(document).on("click.dropdown.data-api", e).on("click.dropdown.data-api", ".dropdown form", function (t) {
		t.stopPropagation()
	}).on("click.dropdown-menu", function (t) {
		t.stopPropagation()
	}).on("click.dropdown.data-api", i, o.prototype.toggle).on("keydown.dropdown.data-api", i + ", [role=menu]", o.prototype.keydown)
}
(window.jQuery), function (t) {
	function e(e, n) {
		var i,
		o = t.proxy(this.process, this),
		a = t(e).is("body") ? t(window) : t(e);
		this.options = t.extend({}, t.fn.scrollspy.defaults, n),
		this.$scrollElement = a.on("scroll.scroll-spy.data-api", o),
		this.selector = (this.options.target || (i = t(e).attr("href")) && i.replace(/.*(?=#[^\s]+$)/, "") || "") + " .nav li > a",
		this.$body = t("body"),
		this.refresh(),
		this.process()
	}
	e.prototype = {
		constructor: e,
		refresh: function () {
			var e = this;
			this.offsets = t([]),
			this.targets = t([]),
			this.$body.find(this.selector).map(function () {
				var n = (n = t(this)).data("target") || n.attr("href"),
				i = /^#\w/.test(n) && t(n);
				return i && i.length && [[i.position().top + (!t.isWindow(e.$scrollElement.get(0)) && e.$scrollElement.scrollTop()), n]] || null
			}).sort(function (t, e) {
				return t[0] - e[0]
			}).each(function () {
				e.offsets.push(this[0]),
				e.targets.push(this[1])
			})
		},
		process: function () {
			var t,
			e = this.$scrollElement.scrollTop() + this.options.offset,
			n = (this.$scrollElement[0].scrollHeight || this.$body[0].scrollHeight) - this.$scrollElement.height(),
			i = this.offsets,
			o = this.targets,
			a = this.activeTarget;
			if (e >= n)
				return a != (t = o.last()[0]) && this.activate(t);
			for (t = i.length; t--; )
				a != o[t] && e >= i[t] && (!i[t + 1] || e <= i[t + 1]) && this.activate(o[t])
		},
		activate: function (e) {
			this.activeTarget = e,
			t(this.selector).parent(".active").removeClass("active"),
			(e = t(this.selector + '[data-target="' + e + '"],' + this.selector + '[href="' + e + '"]').parent("li").addClass("active")).parent(".dropdown-menu").length && (e = e.closest("li.dropdown").addClass("active")),
			e.trigger("activate")
		}
	};
	var n = t.fn.scrollspy;
	t.fn.scrollspy = function (n) {
		return this.each(function () {
			var i = t(this),
			o = i.data("scrollspy"),
			a = "object" == typeof n && n;
			o || i.data("scrollspy", o = new e(this, a)),
			"string" == typeof n && o[n]()
		})
	},
	t.fn.scrollspy.Constructor = e,
	t.fn.scrollspy.defaults = {
		offset: 10
	},
	t.fn.scrollspy.noConflict = function () {
		return t.fn.scrollspy = n,
		this
	},
	t(window).on("load", function () {
		t('[data-spy="scroll"]').each(function () {
			var e = t(this);
			e.scrollspy(e.data())
		})
	})
}
(window.jQuery), function (t) {
	var e = function (e) {
		this.element = t(e)
	};
	e.prototype = {
		constructor: e,
		show: function () {
			var e,
			n,
			i = this.element,
			o = i.closest("ul:not(.dropdown-menu)"),
			a = i.attr("data-target");
			a || (a = (a = i.attr("href")) && a.replace(/.*(?=#[^\s]*$)/, "")),
			i.parent("li").hasClass("active") || (e = o.find(".active:last a")[0], n = t.Event("show", {
						relatedTarget: e
					}), i.trigger(n), n.isDefaultPrevented() || (a = t(a), this.activate(i.parent("li"), o), this.activate(a, a.parent(), function () {
						i.trigger({
							type: "shown",
							relatedTarget: e
						})
					})))
		},
		activate: function (e, n, i) {
			function o() {
				a.removeClass("active").find("> .dropdown-menu > .active").removeClass("active"),
				e.addClass("active"),
				r ? (e[0].offsetWidth, e.addClass("in")) : e.removeClass("fade"),
				e.parent(".dropdown-menu") && e.closest("li.dropdown").addClass("active"),
				i && i()
			}
			var a = n.find("> .active"),
			r = i && t.support.transition && a.hasClass("fade");
			r ? a.one(t.support.transition.end, o) : o(),
			a.removeClass("in")
		}
	};
	var n = t.fn.tab;
	t.fn.tab = function (n) {
		return this.each(function () {
			var i = t(this),
			o = i.data("tab");
			o || i.data("tab", o = new e(this)),
			"string" == typeof n && o[n]()
		})
	},
	t.fn.tab.Constructor = e,
	t.fn.tab.noConflict = function () {
		return t.fn.tab = n,
		this
	},
	t(document).on("click.tab.data-api", '[data-toggle="tab"], [data-toggle="pill"]', function (e) {
		e.preventDefault(),
		t(this).tab("show")
	})
}
(window.jQuery), function (t) {
	var e = function (t, e) {
		this.init("tooltip", t, e)
	};
	e.prototype = {
		constructor: e,
		init: function (e, n, i) {
			var o;
			for (this.type = e, this.$element = t(n), this.options = this.getOptions(i), this.enabled = !0, i = (n = this.options.trigger.split(" ")).length; i--; )
				o = n[i], "click" == o ? this.$element.on("click." + this.type, this.options.selector, t.proxy(this.toggle, this)) : "manual" != o && (e = "hover" == o ? "mouseenter" : "focus", o = "hover" == o ? "mouseleave" : "blur", this.$element.on(e + "." + this.type, this.options.selector, t.proxy(this.enter, this)), this.$element.on(o + "." + this.type, this.options.selector, t.proxy(this.leave, this)));
			this.options.selector ? this._options = t.extend({}, this.options, {
					trigger: "manual",
					selector: ""
				}) : this.fixTitle()
		},
		getOptions: function (e) {
			return (e = t.extend({}, t.fn[this.type].defaults, this.$element.data(), e)).delay && "number" == typeof e.delay && (e.delay = {
					show: e.delay,
					hide: e.delay
				}),
			e
		},
		enter: function (e) {
			var n,
			i = t.fn[this.type].defaults,
			o = {};
			if (this._options && t.each(this._options, function (t, e) {
					i[t] != e && (o[t] = e)
				}, this), !(n = t(e.currentTarget)[this.type](o).data(this.type)).options.delay || !n.options.delay.show)
				return n.show();
			clearTimeout(this.timeout),
			n.hoverState = "in",
			this.timeout = setTimeout(function () {
					"in" == n.hoverState && n.show()
				}, n.options.delay.show)
		},
		leave: function (e) {
			var n = t(e.currentTarget)[this.type](this._options).data(this.type);
			if (this.timeout && clearTimeout(this.timeout), !n.options.delay || !n.options.delay.hide)
				return n.hide();
			n.hoverState = "out",
			this.timeout = setTimeout(function () {
					"out" == n.hoverState && n.hide()
				}, n.options.delay.hide)
		},
		show: function () {
			var e,
			n,
			i,
			o,
			a;
			if (n = t.Event("show"), this.hasContent() && this.enabled && (this.$element.trigger(n), !n.isDefaultPrevented())) {
				switch (e = this.tip(), this.setContent(), this.options.animation && e.addClass("fade"), o = "function" == typeof this.options.placement ? this.options.placement.call(this, e[0], this.$element[0]) : this.options.placement, e.detach().css({
						top: 0,
						left: 0,
						display: "block"
					}), this.options.container ? e.appendTo(this.options.container) : e.insertAfter(this.$element), n = this.getPosition(), i = e[0].offsetWidth, e = e[0].offsetHeight, o) {
				case "bottom":
					a = {
						top: n.top + n.height,
						left: n.left + n.width / 2 - i / 2
					};
					break;
				case "top":
					a = {
						top: n.top - e,
						left: n.left + n.width / 2 - i / 2
					};
					break;
				case "left":
					a = {
						top: n.top + n.height / 2 - e / 2,
						left: n.left - i
					};
					break;
				case "right":
					a = {
						top: n.top + n.height / 2 - e / 2,
						left: n.left + n.width
					}
				}
				this.applyPlacement(a, o),
				this.$element.trigger("shown")
			}
		},
		applyPlacement: function (t, e) {
			var n,
			i,
			o,
			a = this.tip(),
			r = a[0].offsetWidth,
			s = a[0].offsetHeight;
			a.offset(t).addClass(e).addClass("in"),
			n = a[0].offsetWidth,
			i = a[0].offsetHeight,
			"top" == e && i != s && (t.top = t.top + s - i, o = !0),
			"bottom" == e || "top" == e ? (s = 0, 0 > t.left && (s = -2 * t.left, t.left = 0, a.offset(t), n = a[0].offsetWidth), this.replaceArrow(s - r + n, n, "left")) : this.replaceArrow(i - s, i, "top"),
			o && a.offset(t)
		},
		replaceArrow: function (t, e, n) {
			this.arrow().css(n, t ? 50 * (1 - t / e) + "%" : "")
		},
		setContent: function () {
			var t = this.tip(),
			e = this.getTitle();
			t.find(".tooltip-inner")[this.options.html ? "html" : "text"](e),
			t.removeClass("fade in top bottom left right")
		},
		hide: function () {
			var e,
			n = this.tip(),
			i = t.Event("hide");
			if (this.$element.trigger(i), !i.isDefaultPrevented())
				return n.removeClass("in"), t.support.transition && this.$tip.hasClass("fade") ? (e = setTimeout(function () {
							n.off(t.support.transition.end).detach()
						}, 500), n.one(t.support.transition.end, function () {
						clearTimeout(e),
						n.detach()
					})) : n.detach(), this.$element.trigger("hidden"), this
		},
		fixTitle: function () {
			var t = this.$element;
			(t.attr("title") || "string" != typeof t.attr("data-original-title")) && t.attr("data-original-title", t.attr("title") || "").attr("title", "")
		},
		hasContent: function () {
			return this.getTitle()
		},
		getPosition: function () {
			var e = this.$element[0];
			return t.extend({}, "function" == typeof e.getBoundingClientRect ? e.getBoundingClientRect() : {
				width: e.offsetWidth,
				height: e.offsetHeight
			}, this.$element.offset())
		},
		getTitle: function () {
			var t = this.$element,
			e = this.options;
			return t.attr("data-original-title") || ("function" == typeof e.title ? e.title.call(t[0]) : e.title)
		},
		tip: function () {
			return this.$tip = this.$tip || t(this.options.template)
		},
		arrow: function () {
			return this.$arrow = this.$arrow || this.tip().find(".tooltip-arrow")
		},
		validate: function () {
			this.$element[0].parentNode || (this.hide(), this.options = this.$element = null)
		},
		enable: function () {
			this.enabled = !0
		},
		disable: function () {
			this.enabled = !1
		},
		toggleEnabled: function () {
			this.enabled = !this.enabled
		},
		toggle: function (e) {
			(e = e ? t(e.currentTarget)[this.type](this._options).data(this.type) : this).tip().hasClass("in") ? e.hide() : e.show()
		},
		destroy: function () {
			this.hide().$element.off("." + this.type).removeData(this.type)
		}
	};
	var n = t.fn.tooltip;
	t.fn.tooltip = function (n) {
		return this.each(function () {
			var i = t(this),
			o = i.data("tooltip"),
			a = "object" == typeof n && n;
			o || i.data("tooltip", o = new e(this, a)),
			"string" == typeof n && o[n]()
		})
	},
	t.fn.tooltip.Constructor = e,
	t.fn.tooltip.defaults = {
		animation: !0,
		placement: "top",
		selector: !1,
		template: '<div class="tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>',
		trigger: "hover focus",
		title: "",
		delay: 0,
		html: !1,
		container: !1
	},
	t.fn.tooltip.noConflict = function () {
		return t.fn.tooltip = n,
		this
	}
}
(window.jQuery), function (t) {
	var e = function (t, e) {
		this.init("popover", t, e)
	};
	e.prototype = t.extend({}, t.fn.tooltip.Constructor.prototype, {
			constructor: e,
			setContent: function () {
				var t = this.tip(),
				e = this.getTitle(),
				n = this.getContent();
				t.find(".popover-title")[this.options.html ? "html" : "text"](e),
				t.find(".popover-content")[this.options.html ? "html" : "text"](n),
				t.removeClass("fade top bottom left right in")
			},
			hasContent: function () {
				return this.getTitle() || this.getContent()
			},
			getContent: function () {
				var t = this.$element,
				e = this.options;
				return ("function" == typeof e.content ? e.content.call(t[0]) : e.content) || t.attr("data-content")
			},
			tip: function () {
				return this.$tip || (this.$tip = t(this.options.template)),
				this.$tip
			},
			destroy: function () {
				this.hide().$element.off("." + this.type).removeData(this.type)
			}
		});
	var n = t.fn.popover;
	t.fn.popover = function (n) {
		return this.each(function () {
			var i = t(this),
			o = i.data("popover"),
			a = "object" == typeof n && n;
			o || i.data("popover", o = new e(this, a)),
			"string" == typeof n && o[n]()
		})
	},
	t.fn.popover.Constructor = e,
	t.fn.popover.defaults = t.extend({}, t.fn.tooltip.defaults, {
			placement: "right",
			trigger: "click",
			content: "",
			template: '<div class="popover"><div class="arrow"></div><h3 class="popover-title"></h3><div class="popover-content"></div></div>'
		}),
	t.fn.popover.noConflict = function () {
		return t.fn.popover = n,
		this
	}
}
(window.jQuery), function (t) {
	var e = function (e, n) {
		this.$element = t(e),
		this.options = t.extend({}, t.fn.button.defaults, n)
	};
	e.prototype.setState = function (t) {
		var e = this.$element,
		n = e.data(),
		i = e.is("input") ? "val" : "html";
		t += "Text",
		n.resetText || e.data("resetText", e[i]()),
		e[i](n[t] || this.options[t]),
		setTimeout(function () {
			"loadingText" == t ? e.addClass("disabled").attr("disabled", "disabled") : e.removeClass("disabled").removeAttr("disabled")
		}, 0)
	},
	e.prototype.toggle = function () {
		var t = this.$element.closest('[data-toggle="buttons-radio"]');
		t && t.find(".active").removeClass("active"),
		this.$element.toggleClass("active")
	};
	var n = t.fn.button;
	t.fn.button = function (n) {
		return this.each(function () {
			var i = t(this),
			o = i.data("button"),
			a = "object" == typeof n && n;
			o || i.data("button", o = new e(this, a)),
			"toggle" == n ? o.toggle() : n && o.setState(n)
		})
	},
	t.fn.button.defaults = {
		loadingText: "loading..."
	},
	t.fn.button.Constructor = e,
	t.fn.button.noConflict = function () {
		return t.fn.button = n,
		this
	},
	t(document).on("click.button.data-api", "[data-toggle^=button]", function (e) {
		(e = t(e.target)).hasClass("btn") || (e = e.closest(".btn")),
		e.button("toggle")
	})
}
(window.jQuery), function (t) {
	var e = function (e, n) {
		this.$element = t(e),
		this.options = t.extend({}, t.fn.collapse.defaults, n),
		this.options.parent && (this.$parent = t(this.options.parent)),
		this.options.toggle && this.toggle()
	};
	e.prototype = {
		constructor: e,
		dimension: function () {
			return this.$element.hasClass("width") ? "width" : "height"
		},
		show: function () {
			var e,
			n,
			i,
			o;
			if (!this.transitioning && !this.$element.hasClass("in")) {
				if (e = this.dimension(), n = t.camelCase(["scroll", e].join("-")), (i = this.$parent && this.$parent.find("> .accordion-group > .in")) && i.length) {
					if ((o = i.data("collapse")) && o.transitioning)
						return;
					i.collapse("hide"),
					o || i.data("collapse", null)
				}
				this.$element[e](0),
				this.transition("addClass", t.Event("show"), "shown"),
				t.support.transition && this.$element[e](this.$element[0][n])
			}
		},
		hide: function () {
			var e;
			!this.transitioning && this.$element.hasClass("in") && (e = this.dimension(), this.reset(this.$element[e]()), this.transition("removeClass", t.Event("hide"), "hidden"), this.$element[e](0))
		},
		reset: function (t) {
			var e = this.dimension();
			return this.$element.removeClass("collapse")[e](t || "auto")[0].offsetWidth,
			this.$element[null !== t ? "addClass" : "removeClass"]("collapse"),
			this
		},
		transition: function (e, n, i) {
			var o = this,
			a = function () {
				"show" == n.type && o.reset(),
				o.transitioning = 0,
				o.$element.trigger(i)
			};
			this.$element.trigger(n),
			n.isDefaultPrevented() || (this.transitioning = 1, this.$element[e]("in"), t.support.transition && this.$element.hasClass("collapse") ? this.$element.one(t.support.transition.end, a) : a())
		},
		toggle: function () {
			this[this.$element.hasClass("in") ? "hide" : "show"]()
		}
	};
	var n = t.fn.collapse;
	t.fn.collapse = function (n) {
		return this.each(function () {
			var i = t(this),
			o = i.data("collapse"),
			a = t.extend({}, t.fn.collapse.defaults, i.data(), "object" == typeof n && n);
			o || i.data("collapse", o = new e(this, a)),
			"string" == typeof n && o[n]()
		})
	},
	t.fn.collapse.defaults = {
		toggle: !0
	},
	t.fn.collapse.Constructor = e,
	t.fn.collapse.noConflict = function () {
		return t.fn.collapse = n,
		this
	},
	t(document).on("click.collapse.data-api", "[data-toggle=collapse]", function (e) {
		var n,
		i = t(this);
		e = i.attr("data-target") || e.preventDefault() || (n = i.attr("href")) && n.replace(/.*(?=#[^\s]+$)/, ""),
		n = t(e).data("collapse") ? "toggle" : i.data(),
		i[t(e).hasClass("in") ? "addClass" : "removeClass"]("collapsed"),
		t(e).collapse(n)
	})
}
(window.jQuery), function (t) {
	var e = function (e, n) {
		this.$element = t(e),
		this.$indicators = this.$element.find(".carousel-indicators"),
		this.options = n,
		"hover" == this.options.pause && this.$element.on("mouseenter", t.proxy(this.pause, this)).on("mouseleave", t.proxy(this.cycle, this))
	};
	e.prototype = {
		cycle: function (e) {
			return e || (this.paused = !1),
			this.interval && clearInterval(this.interval),
			this.options.interval && !this.paused && (this.interval = setInterval(t.proxy(this.next, this), this.options.interval)),
			this
		},
		getActiveIndex: function () {
			return this.$active = this.$element.find(".item.active"),
			this.$items = this.$active.parent().children(),
			this.$items.index(this.$active)
		},
		to: function (e) {
			var n = this.getActiveIndex(),
			i = this;
			if (!(e > this.$items.length - 1 || 0 > e))
				return this.sliding ? this.$element.one("slid", function () {
					i.to(e)
				}) : n == e ? this.pause().cycle() : this.slide(e > n ? "next" : "prev", t(this.$items[e]))
		},
		pause: function (e) {
			return e || (this.paused = !0),
			this.$element.find(".next, .prev").length && t.support.transition.end && (this.$element.trigger(t.support.transition.end), this.cycle(!0)),
			clearInterval(this.interval),
			this.interval = null,
			this
		},
		next: function () {
			if (!this.sliding)
				return this.slide("next")
		},
		prev: function () {
			if (!this.sliding)
				return this.slide("prev")
		},
		slide: function (e, n) {
			var i = this.$element.find(".item.active"),
			o = n || i[e](),
			a = this.interval,
			r = "next" == e ? "left" : "right",
			s = "next" == e ? "first" : "last",
			l = this;
			if (this.sliding = !0, a && this.pause(), o = o.length ? o : this.$element.find(".item")[s](), s = t.Event("slide", {
						relatedTarget: o[0],
						direction: r
					}), !o.hasClass("active")) {
				if (this.$indicators.length && (this.$indicators.find(".active").removeClass("active"), this.$element.one("slid", function () {
							var e = t(l.$indicators.children()[l.getActiveIndex()]);
							e && e.addClass("active")
						})), t.support.transition && this.$element.hasClass("slide")) {
					if (this.$element.trigger(s), s.isDefaultPrevented())
						return;
					o.addClass(e),
					o[0].offsetWidth,
					i.addClass(r),
					o.addClass(r),
					this.$element.one(t.support.transition.end, function () {
						o.removeClass([e, r].join(" ")).addClass("active"),
						i.removeClass(["active", r].join(" ")),
						l.sliding = !1,
						setTimeout(function () {
							l.$element.trigger("slid")
						}, 0)
					})
				} else {
					if (this.$element.trigger(s), s.isDefaultPrevented())
						return;
					i.removeClass("active"),
					o.addClass("active"),
					this.sliding = !1,
					this.$element.trigger("slid")
				}
				return a && this.cycle(),
				this
			}
		}
	};
	var n = t.fn.carousel;
	t.fn.carousel = function (n) {
		return this.each(function () {
			var i = t(this),
			o = i.data("carousel"),
			a = t.extend({}, t.fn.carousel.defaults, "object" == typeof n && n),
			r = "string" == typeof n ? n : a.slide;
			o || i.data("carousel", o = new e(this, a)),
			"number" == typeof n ? o.to(n) : r ? o[r]() : a.interval && o.pause().cycle()
		})
	},
	t.fn.carousel.defaults = {
		interval: 5e3,
		pause: "hover"
	},
	t.fn.carousel.Constructor = e,
	t.fn.carousel.noConflict = function () {
		return t.fn.carousel = n,
		this
	},
	t(document).on("click.carousel.data-api", "[data-slide], [data-slide-to]", function (e) {
		var n,
		i,
		o = t(this),
		a = t(o.attr("data-target") || (n = o.attr("href")) && n.replace(/.*(?=#[^\s]+$)/, ""));
		n = t.extend({}, a.data(), o.data()),
		a.carousel(n),
		(i = o.attr("data-slide-to")) && a.data("carousel").pause().to(i).cycle(),
		e.preventDefault()
	})
}
(window.jQuery), function (t) {
	var e = function (e, n) {
		this.$element = t(e),
		this.options = t.extend({}, t.fn.typeahead.defaults, n),
		this.matcher = this.options.matcher || this.matcher,
		this.sorter = this.options.sorter || this.sorter,
		this.highlighter = this.options.highlighter || this.highlighter,
		this.updater = this.options.updater || this.updater,
		this.source = this.options.source,
		this.$menu = t(this.options.menu),
		this.shown = !1,
		this.listen()
	};
	e.prototype = {
		constructor: e,
		select: function () {
			var t = this.$menu.find(".active").attr("data-value");
			return this.$element.val(this.updater(t)).change(),
			this.hide()
		},
		updater: function (t) {
			return t
		},
		show: function () {
			if (0 < this.$element.closest(".modal").length) {
				var e = t.extend({}, this.$element.offset(), {
						height: this.$element[0].offsetHeight
					});
				this.$menu.insertAfter(this.$element).css({
					top: 0,
					left: 0,
					position: "fixed"
				}).offset({
					top: e.top + e.height,
					left: e.left
				}).show()
			} else
				e = t.extend({}, this.$element.position(), {
						height: this.$element[0].offsetHeight
					}), this.$menu.insertAfter(this.$element).css({
					top: e.top + e.height,
					left: e.left
				}).show();
			return this.shown = !0,
			this
		},
		hide: function () {
			return this.$menu.hide(),
			this.shown = !1,
			this
		},
		lookup: function (e) {
			return this.query = this.$element.val(),
			!this.query || this.query.length < this.options.minLength ? this.shown ? this.hide() : this : (e = t.isFunction(this.source) ? this.source(this.query, t.proxy(this.process, this)) : this.source) ? this.process(e) : this
		},
		process: function (e) {
			var n = this;
			return e = t.grep(e, function (t) {
					return n.matcher(t)
				}),
			(e = this.sorter(e)).length ? this.render(e.slice(0, this.options.items)).show() : this.shown ? this.hide() : this
		},
		matcher: function (t) {
			return ~t.toLowerCase().indexOf(this.query.toLowerCase())
		},
		sorter: function (t) {
			for (var e, n = [], i = [], o = []; e = t.shift(); )
				e.toLowerCase().indexOf(this.query.toLowerCase()) ? ~e.indexOf(this.query) ? i.push(e) : o.push(e) : n.push(e);
			return n.concat(i, o)
		},
		highlighter: function (t) {
			var e = this.query.replace(/[\-\[\]{}()*+?.,\\\^$|#\s]/g, "\\$&");
			return t.replace(RegExp("(" + e + ")", "ig"), function (t, e) {
				return "<strong>" + e + "</strong>"
			})
		},
		render: function (e) {
			var n = this;
			return (e = t(e).map(function (e, i) {
						return (e = t(n.options.item).attr("data-value", i)).find("a").html(n.highlighter(i)),
						e[0]
					})).first().addClass("active"),
			this.$menu.html(e),
			this
		},
		next: function (e) {
			(e = this.$menu.find(".active").removeClass("active").next()).length || (e = t(this.$menu.find("li")[0])),
			e.addClass("active")
		},
		prev: function (t) {
			(t = this.$menu.find(".active").removeClass("active").prev()).length || (t = this.$menu.find("li").last()),
			t.addClass("active")
		},
		listen: function () {
			this.$element.on("focus", t.proxy(this.focus, this)).on("blur", t.proxy(this.blur, this)).on("keypress", t.proxy(this.keypress, this)).on("keyup", t.proxy(this.keyup, this)),
			this.eventSupported("keydown") && this.$element.on("keydown", t.proxy(this.keydown, this)),
			this.$menu.on("click", t.proxy(this.click, this)).on("mouseenter", "li", t.proxy(this.mouseenter, this)).on("mouseleave", "li", t.proxy(this.mouseleave, this))
		},
		eventSupported: function (t) {
			var e = t in this.$element;
			return e || (this.$element.setAttribute(t, "return;"), e = "function" == typeof this.$element[t]),
			e
		},
		move: function (t) {
			if (this.shown) {
				switch (t.keyCode) {
				case 9:
				case 13:
				case 27:
					t.preventDefault();
					break;
				case 38:
					t.preventDefault(),
					this.prev();
					break;
				case 40:
					t.preventDefault(),
					this.next()
				}
				t.stopPropagation()
			}
		},
		keydown: function (e) {
			this.suppressKeyPressRepeat = ~t.inArray(e.keyCode, [40, 38, 9, 13, 27]),
			this.move(e)
		},
		keypress: function (t) {
			this.suppressKeyPressRepeat || this.move(t)
		},
		keyup: function (t) {
			switch (t.keyCode) {
			case 40:
			case 38:
			case 16:
			case 17:
			case 18:
				break;
			case 9:
			case 13:
				if (!this.shown)
					return;
				this.select();
				break;
			case 27:
				if (!this.shown)
					return;
				this.hide();
				break;
			default:
				this.lookup()
			}
			t.stopPropagation(),
			t.preventDefault()
		},
		focus: function (t) {
			this.focused = !0
		},
		blur: function (t) {
			this.focused = !1,
			!this.mousedover && this.shown && this.hide()
		},
		click: function (t) {
			t.stopPropagation(),
			t.preventDefault(),
			this.select(),
			this.$element.focus()
		},
		mouseenter: function (e) {
			this.mousedover = !0,
			this.$menu.find(".active").removeClass("active"),
			t(e.currentTarget).addClass("active")
		},
		mouseleave: function (t) {
			this.mousedover = !1,
			!this.focused && this.shown && this.hide()
		}
	};
	var n = t.fn.typeahead;
	t.fn.typeahead = function (n) {
		return this.each(function () {
			var i = t(this),
			o = i.data("typeahead"),
			a = "object" == typeof n && n;
			o || i.data("typeahead", o = new e(this, a)),
			"string" == typeof n && o[n]()
		})
	},
	t.fn.typeahead.defaults = {
		source: [],
		items: 8,
		menu: '<ul class="typeahead dropdown-menu"></ul>',
		item: '<li><a href="#"></a></li>',
		minLength: 1
	},
	t.fn.typeahead.Constructor = e,
	t.fn.typeahead.noConflict = function () {
		return t.fn.typeahead = n,
		this
	},
	t(document).on("focus.typeahead.data-api", '[data-provide="typeahead"]', function (e) {
		(e = t(this)).data("typeahead") || e.typeahead(e.data())
	})
}
(window.jQuery), function (t) {
	function e(t, e, n) {
		if ((t[e] || t[n]) && t[e] === t[n])
			throw Error("(Link) '" + e + "' can't match '" + n + "'.'")
	}
	function n(n) {
		if (void 0 === n && (n = {}), "object" != typeof n)
			throw Error("(Format) 'format' option must be an object.");
		var i = {};
		t(o).each(function (t, e) {
			if (void 0 === n[e])
				i[e] = a[t];
			else {
				if (typeof n[e] != typeof a[t])
					throw Error("(Format) 'format." + e + "' must be a " + typeof a[t] + ".");
				if ("decimals" === e && (0 > n[e] || 7 < n[e]))
					throw Error("(Format) 'format.decimals' option must be between 0 and 7.");
				i[e] = n[e]
			}
		}),
		e(i, "mark", "thousand"),
		e(i, "prefix", "negative"),
		e(i, "prefix", "negativeBefore"),
		this.settings = i
	}
	function i(e, n) {
		return "object" != typeof e && t.error("(Link) Initialize with an object."),
		new i.prototype.init(e.target || function () {}, e.method, e.format || {}, n)
	}
	var o = "decimals mark thousand prefix postfix encoder decoder negative negativeBefore to from".split(" "),
	a = [2, ".", "", "", "", function (t) {
			return t
		}, function (t) {
			return t
		}, "-", "", function (t) {
			return t
		}, function (t) {
			return t
		}
	];
	n.prototype.v = function (t) {
		return this.settings[t]
	},
	n.prototype.to = function (t) {
		function e(t) {
			return t.split("").reverse().join("")
		}
		t = this.v("encoder")(t);
		var n = this.v("decimals"),
		i = "",
		o = "",
		a = "",
		r = "";
		return 0 === parseFloat(t.toFixed(n)) && (t = "0"),
		0 > t && (i = this.v("negative"), o = this.v("negativeBefore")),
		t = (t = Math.abs(t).toFixed(n).toString()).split("."),
		this.v("thousand") ? a = e((a = e(t[0]).match(/.{1,3}/g)).join(e(this.v("thousand")))) : a = t[0],
		this.v("mark") && 1 < t.length && (r = this.v("mark") + t[1]),
		this.v("to")(o + this.v("prefix") + i + a + r + this.v("postfix"))
	},
	n.prototype.from = function (t) {
		function e(t) {
			return t.replace(/[\-\/\\\^$*+?.()|\[\]{}]/g, "\\$&")
		}
		var n;
		return null !== t && void 0 !== t && ((t = (t = this.v("from")(t)).toString()) !== (n = t.replace(RegExp("^" + e(this.v("negativeBefore"))), "")) ? (t = n, n = "-") : n = "", t = t.replace(RegExp("^" + e(this.v("prefix"))), ""), this.v("negative") && (n = "", t = t.replace(RegExp("^" + e(this.v("negative"))), "-")), t = t.replace(RegExp(e(this.v("postfix")) + "$"), "").replace(RegExp(e(this.v("thousand")), "g"), "").replace(this.v("mark"), "."), t = this.v("decoder")(parseFloat(n + t)), !isNaN(t) && t)
	},
	i.prototype.setTooltip = function (e, n) {
		this.method = n || "html",
		this.el = t(e.replace("-tooltip-", "") || "<div/>")[0]
	},
	i.prototype.setHidden = function (t) {
		this.method = "val",
		this.el = document.createElement("input"),
		this.el.name = t,
		this.el.type = "hidden"
	},
	i.prototype.setField = function (e) {
		var n = this;
		this.method = "val",
		this.target = e.on("change", function (e) {
				var i,
				o,
				a;
				n.obj.val((i = null, o = t(e.target).val(), [(a = n.N) ? i : o, a ? o : i]), {
					link: n,
					set: !0
				})
			})
	},
	i.prototype.init = function (e, n, i, o) {
		if (this.formatting = i, this.update = !o, "string" == typeof e && 0 === e.indexOf("-tooltip-"))
			this.setTooltip(e, n);
		else if ("string" == typeof e && 0 !== e.indexOf("-"))
			this.setHidden(e);
		else {
			if ("function" != typeof e) {
				if (e instanceof t || t.zepto && t.zepto.isZ(e)) {
					if (!n) {
						if (e.is("input, select, textarea"))
							return void this.setField(e);
						n = "html"
					}
					if ("function" == typeof n || "string" == typeof n && e[n])
						return this.method = n, void(this.target = e)
				}
				throw new RangeError("(Link) Invalid Link.")
			}
			this.target = !1,
			this.method = e
		}
	},
	i.prototype.write = function (t, e, n, i) {
		this.update && !1 === i || (this.actual = t, this.saved = t = this.format(t), "function" == typeof this.method ? this.method.call(this.target[0] || n[0], t, e, n) : this.target[this.method](t, e, n))
	},
	i.prototype.setFormatting = function (e) {
		this.formatting = new n(t.extend({}, e, this.formatting instanceof n ? this.formatting.settings : this.formatting))
	},
	i.prototype.setObject = function (t) {
		this.obj = t
	},
	i.prototype.setIndex = function (t) {
		this.N = t
	},
	i.prototype.format = function (t) {
		return this.formatting.to(t)
	},
	i.prototype.getValue = function (t) {
		return this.formatting.from(t)
	},
	i.prototype.init.prototype = i.prototype,
	t.Link = i
}
(window.jQuery || window.Zepto), function (t) {
	function e(t) {
		return Math.max(Math.min(t, 100), 0)
	}
	function n(t) {
		return "number" == typeof t && !isNaN(t) && isFinite(t)
	}
	function i(t, e, n) {
		t.addClass(e),
		setTimeout(function () {
			t.removeClass(e)
		}, n)
	}
	function o(t, e) {
		return 100 * e / (t[1] - t[0])
	}
	function a(t, e) {
		if (e >= t.xVal.slice(-1)[0])
			return 100;
		for (var n, i, a, r = 1; e >= t.xVal[r]; )
			r++;
		return n = t.xVal[r - 1],
		i = t.xVal[r],
		a = t.xPct[r - 1],
		r = t.xPct[r],
		a + (n = o(n = [n, i], 0 > n[0] ? e + Math.abs(n[0]) : e - n[0])) / (100 / (r - a))
	}
	function r(t, e) {
		if (!n(e))
			throw Error("noUiSlider: 'step' is not numeric.");
		t.xSteps[0] = e
	}
	function s(e, i) {
		if ("object" != typeof i || t.isArray(i))
			throw Error("noUiSlider: 'range' is not an object.");
		if (void 0 === i.min || void 0 === i.max)
			throw Error("noUiSlider: Missing 'min' or 'max' in 'range'.");
		t.each(i, function (i, o) {
			var a;
			if ("number" == typeof o && (o = [o]), !t.isArray(o))
				throw Error("noUiSlider: 'range' contains invalid value.");
			if (!n(a = "min" === i ? 0 : "max" === i ? 100 : parseFloat(i)) || !n(o[0]))
				throw Error("noUiSlider: 'range' value isn't numeric.");
			e.xPct.push(a),
			e.xVal.push(o[0]),
			a ? e.xSteps.push(!isNaN(o[1]) && o[1]) : isNaN(o[1]) || (e.xSteps[0] = o[1])
		}),
		t.each(e.xSteps, function (t, n) {
			if (!n)
				return !0;
			e.xSteps[t] = o([e.xVal[t], e.xVal[t + 1]], n) / (100 / (e.xPct[t + 1] - e.xPct[t]))
		})
	}
	function l(e, n) {
		if ("number" == typeof n && (n = [n]), !t.isArray(n) || !n.length || 2 < n.length)
			throw Error("noUiSlider: 'start' option is incorrect.");
		e.handles = n.length,
		e.start = n
	}
	function d(t, e) {
		if (t.snap = e, "boolean" != typeof e)
			throw Error("noUiSlider: 'snap' option must be a boolean.")
	}
	function c(t, e) {
		if ("lower" === e && 1 === t.handles)
			t.connect = 1;
		else if ("upper" === e && 1 === t.handles)
			t.connect = 2;
		else if (!0 === e && 2 === t.handles)
			t.connect = 3;
		else {
			if (!1 !== e)
				throw Error("noUiSlider: 'connect' option doesn't match handle count.");
			t.connect = 0
		}
	}
	function u(t, e) {
		switch (e) {
		case "horizontal":
			t.ort = 0;
			break;
		case "vertical":
			t.ort = 1;
			break;
		default:
			throw Error("noUiSlider: 'orientation' option is invalid.")
		}
	}
	function h(t, e) {
		if (2 < t.xPct.length)
			throw Error("noUiSlider: 'margin' option is only supported on linear sliders.");
		if (t.margin = o(t.xVal, e), !n(e))
			throw Error("noUiSlider: 'margin' option must be numeric.")
	}
	function f(t, e) {
		switch (e) {
		case "ltr":
			t.dir = 0;
			break;
		case "rtl":
			t.dir = 1,
			t.connect = [0, 2, 1, 3][t.connect];
			break;
		default:
			throw Error("noUiSlider: 'direction' option was not recognized.")
		}
	}
	function p(t, e) {
		if ("string" != typeof e)
			throw Error("noUiSlider: 'behaviour' must be a string containing options.");
		var n = 0 <= e.indexOf("tap"),
		i = 0 <= e.indexOf("extend"),
		o = 0 <= e.indexOf("drag"),
		a = 0 <= e.indexOf("fixed"),
		r = 0 <= e.indexOf("snap");
		t.events = {
			tap: n || r,
			extend: i,
			drag: o,
			fixed: a,
			snap: r
		}
	}
	function m(e, n, i) {
		e.ser = [n.lower, n.upper],
		e.formatting = n.format,
		t.each(e.ser, function (e, o) {
			if (!t.isArray(o))
				throw Error("noUiSlider: 'serialization." + (e ? "upper" : "lower") + "' must be an array.");
			t.each(o, function () {
				if (!(this instanceof t.Link))
					throw Error("noUiSlider: 'serialization." + (e ? "upper" : "lower") + "' can only contain Link instances.");
				this.setIndex(e),
				this.setObject(i),
				this.setFormatting(n.format)
			})
		}),
		e.dir && 1 < e.handles && e.ser.reverse()
	}
	function v(n, o, r) {
		function s() {
			return g[["width", "height"][o.ort]]()
		}
		function l(t) {
			var e,
			n = [T.val()];
			for (e = 0; e < t.length; e++)
				T.trigger(t[e], n)
		}
		function d(n, i, a) {
			var r = n[0] !== b[0][0] ? 1 : 0,
			s = S[0] + o.margin,
			l = S[1] - o.margin;
			return a && 1 < b.length && (i = r ? Math.max(i, s) : Math.min(i, l)),
			100 > i && (i = function (t, e) {
				for (var n, i = 1; (t.dir ? 100 - e : e) >= t.xPct[i]; )
					i++;
				return t.snap ? e - (n = t.xPct[i - 1]) > ((i = t.xPct[i]) - n) / 2 ? i : n : t.xSteps[i - 1] ? t.xPct[i - 1] + Math.round((e - t.xPct[i - 1]) / t.xSteps[i - 1]) * t.xSteps[i - 1] : e
			}
				(o, i)),
			(i = e(parseFloat(i.toFixed(7)))) === S[r] ? 1 !== b.length && ((i === s || i === l) && 0) : (n.css(o.style, i + "%"), n.is(":first-child") && n.toggleClass(k[17], 50 < i), S[r] = i, o.dir && (i = 100 - i), t(w[r]).each(function () {
					this.write(function (t, e) {
						if (100 <= e)
							return t.xVal.slice(-1)[0];
						for (var n, i, o = 1; e >= t.xPct[o]; )
							o++;
						return n = [n = t.xVal[o - 1], t.xVal[o]],
						(e - (i = t.xPct[o - 1])) * (100 / (t.xPct[o] - i)) * (n[1] - n[0]) / 100 + n[0]
					}
						(o, i), n.children(), T)
				}), !0)
		}
		function c(t, e, n) {
			n || i(T, k[14], 300),
			d(t, e, !1),
			l(["slide", "set", "change"])
		}
		function u(t, e, n, i) {
			return t = t.replace(/\s/g, ".nui ") + ".nui",
			e.on(t, function (t) {
				var e = T.attr("disabled");
				if (T.hasClass(k[14]) || void 0 !== e && null !== e)
					return !1;
				t.preventDefault();
				e = 0 === t.type.indexOf("touch");
				var a,
				r,
				s = 0 === t.type.indexOf("mouse"),
				l = 0 === t.type.indexOf("pointer"),
				d = t;
				0 === t.type.indexOf("MSPointer") && (l = !0),
				t.originalEvent && (t = t.originalEvent),
				e && (a = t.changedTouches[0].pageX, r = t.changedTouches[0].pageY),
				(s || l) && (!l && void 0 === window.pageXOffset && (window.pageXOffset = document.documentElement.scrollLeft, window.pageYOffset = document.documentElement.scrollTop), a = t.clientX + window.pageXOffset, r = t.clientY + window.pageYOffset),
				d.points = [a, r],
				d.cursor = s,
				(t = d).calcPoint = t.points[o.ort],
				n(t, i)
			})
		}
		function h(t, n) {
			var i,
			o = n.handles || b,
			a = !1,
			r = (a = 100 * (t.calcPoint - n.start) / s(), o[0][0] !== b[0][0] ? 1 : 0),
			c = n.positions;
			i = a + c[0],
			a += c[1],
			1 < o.length ? (0 > i && (a += Math.abs(i)), 100 < a && (i -= a - 100), i = [e(i), e(a)]) : i = [i, a],
			a = d(o[0], i[r], 1 === o.length),
			1 < o.length && (a = d(o[1], i[r ? 0 : 1], !1) || a),
			a && l(["slide"])
		}
		function f(e) {
			t("." + k[15]).removeClass(k[15]),
			e.cursor && t("body").css("cursor", "").off(".nui"),
			y.off(".nui"),
			T.removeClass(k[12]),
			l(["set", "change"])
		}
		function p(e, n) {
			1 === n.handles.length && n.handles[0].children().addClass(k[15]),
			e.stopPropagation(),
			u($.move, y, h, {
				start: e.calcPoint,
				handles: n.handles,
				positions: [S[0], S[b.length - 1]]
			}),
			u($.end, y, f, null),
			e.cursor && (t("body").css("cursor", t(e.target).css("cursor")), 1 < b.length && T.addClass(k[12]), t("body").on("selectstart.nui", !1))
		}
		function m(e) {
			var n = e.calcPoint,
			i = 0;
			e.stopPropagation(),
			t.each(b, function () {
				i += this.offset()[o.style]
			}),
			i = n < i / 2 || 1 === b.length ? 0 : 1,
			n = 100 * (n -= g.offset()[o.style]) / s(),
			c(b[i], n, o.events.snap),
			o.events.snap && p(e, {
				handles: [b[i]]
			})
		}
		function v(t) {
			var e = (t = t.calcPoint < g.offset()[o.style]) ? 0 : 100;
			t = t ? 0 : b.length - 1,
			c(b[t], e, !1)
		}
		var g,
		w,
		b,
		x,
		C,
		T = t(n),
		S = [-1, -1];
		if (T.hasClass(k[0]))
			throw Error("Slider was already initialized.");
		x = o,
		(C = T).addClass([k[0], k[8 + x.dir], k[4 + x.ort]].join(" ")),
		g = t("<div/>").appendTo(C).addClass(k[1]),
		b = function (e, n) {
			var i,
			o,
			a,
			r,
			s,
			l = [];
			for (i = 0; i < e.handles; i++)
				l.push((o = e, a = i, r = void 0, s = void 0, r = t("<div><div/></div>").addClass(k[2]), s = ["-lower", "-upper"], o.dir && s.reverse(), r.children().addClass(k[3] + " " + k[3] + s[a]), r).appendTo(n));
			return l
		}
		(o, g),
		w = function (e, n) {
			var i,
			o,
			a,
			r = [];
			for (i = 0; i < e.handles; i++) {
				var s = r,
				l = i,
				d = e.ser[i],
				c = n[i].children(),
				u = e.formatting,
				h = void 0,
				f = [];
				for ((h = new t.Link({}, !0)).setFormatting(u), f.push(h), h = 0; h < d.length; h++)
					f.push((o = c, a = d[h], a.el && (a = new t.Link({
										target: t(a.el).clone().appendTo(o),
										method: a.method,
										format: a.formatting
									}, !0)), a));
				s[l] = f
			}
			return r
		}
		(o, b),
		function (t, e, n) {
			switch (t) {
			case 1:
				e.addClass(k[7]),
				n[0].addClass(k[6]);
				break;
			case 3:
				n[1].addClass(k[6]);
			case 2:
				n[0].addClass(k[7]);
			case 0:
				e.addClass(k[6])
			}
		}
		(o.connect, T, b),
		function (t) {
			var e;
			if (!t.fixed)
				for (e = 0; e < b.length; e++)
					u($.start, b[e].children(), p, {
						handles: [b[e]]
					});
			t.tap && u($.start, g, m, {
				handles: b
			}),
			t.extend && (T.addClass(k[16]), t.tap && u($.start, T, v, {
					handles: b
				})),
			t.drag && (e = g.find("." + k[7]).addClass(k[10]), t.fixed && (e = e.add(g.children().not(e).children())), u($.start, e, p, {
					handles: b
				}))
		}
		(o.events),
		n.vSet = function () {
			var e,
			n,
			r,
			s,
			c,
			u,
			h = Array.prototype.slice.call(arguments, 0),
			f = t.isArray(h[0]) ? h[0] : [h[0]];
			for ("object" == typeof h[1] ? (e = h[1].set, n = h[1].link, r = h[1].update, s = h[1].animate) : !0 === h[1] && (e = !0), o.dir && 1 < o.handles && f.reverse(), s && i(T, k[14], 300), h = 1 < b.length ? 3 : 1, 1 === f.length && (h = 1), c = 0; c < h; c++)
				s = n || w[c % 2][0], s = s.getValue(f[c % 2]), !1 !== s && (s = a(o, s), o.dir && (s = 100 - s), !0 !== d(b[c % 2], s, !0) && t(w[c % 2]).each(function (t) {
						if (!t)
							return u = this.actual, !0;
						this.write(u, b[c % 2].children(), T, r)
					}));
			return !0 === e && l(["set"]),
			this
		},
		n.vGet = function () {
			var t,
			e = [];
			for (t = 0; t < o.handles; t++)
				e[t] = w[t][0].saved;
			return 1 === e.length ? e[0] : o.dir ? e.reverse() : e
		},
		n.destroy = function () {
			return t.each(w, function () {
				t.each(this, function () {
					this.target && this.target.off(".nui")
				})
			}),
			t(this).off(".nui").removeClass(k.join(" ")).empty(),
			r
		},
		T.val(o.start)
	}
	function g(e) {
		if (!this.length)
			throw Error("noUiSlider: Can't initialize slider on empty selection.");
		var n,
		i,
		o,
		a,
		g = (n = e, i = this, a = {
				xPct: [],
				xVal: [],
				xSteps: [!1],
				margin: 0
			}, o = {
				step: {
					r: !1,
					t: r
				},
				start: {
					r: !0,
					t: l
				},
				connect: {
					r: !0,
					t: c
				},
				direction: {
					r: !0,
					t: f
				},
				range: {
					r: !0,
					t: s
				},
				snap: {
					r: !1,
					t: d
				},
				orientation: {
					r: !1,
					t: u
				},
				margin: {
					r: !1,
					t: h
				},
				behaviour: {
					r: !0,
					t: p
				},
				serialization: {
					r: !0,
					t: m
				}
			}, (n = t.extend({
						connect: !1,
						direction: "ltr",
						behaviour: "tap",
						orientation: "horizontal"
					}, n)).serialization = t.extend({
					lower: [],
					upper: [],
					format: {}
				}, n.serialization), t.each(o, function (t, e) {
				if (void 0 === n[t]) {
					if (e.r)
						throw Error("noUiSlider: '" + t + "' is required.");
					return !0
				}
				e.t(a, n[t], i)
			}), a.style = a.ort ? "top" : "left", a);
		return this.each(function () {
			v(this, g, e)
		})
	}
	function w() {
		return this[0][arguments.length ? "vSet" : "vGet"].apply(this[0], arguments)
	}
	var y = t(document),
	b = t.fn.val,
	$ = window.navigator.pointerEnabled ? {
		start: "pointerdown",
		move: "pointermove",
		end: "pointerup"
	}
	 : window.navigator.msPointerEnabled ? {
		start: "MSPointerDown",
		move: "MSPointerMove",
		end: "MSPointerUp"
	}
	 : {
		start: "mousedown touchstart",
		move: "mousemove touchmove",
		end: "mouseup touchend"
	},
	k = "noUi-target noUi-base noUi-origin noUi-handle noUi-horizontal noUi-vertical noUi-background noUi-connect noUi-ltr noUi-rtl noUi-dragable  noUi-state-drag  noUi-state-tap noUi-active noUi-extended noUi-stacking".split(" ");
	t.fn.val = function () {
		var e = arguments,
		n = t(this[0]);
		return arguments.length ? this.each(function () {
			(t(this).hasClass(k[0]) ? w : b).apply(t(this), e)
		}) : (n.hasClass(k[0]) ? w : b).call(n)
	},
	t.noUiSlider = {
		Link: t.Link
	},
	t.fn.noUiSlider = function (e, n) {
		return (n ? function (e) {
			return this.each(function () {
				var n = t(this).val(),
				i = this.destroy(),
				o = t.extend({}, i, e);
				t(this).noUiSlider(o),
				i.start === o.start && t(this).val(n)
			})
		}
			 : g).call(this, e)
	}
}
(window.jQuery || window.Zepto), function (t, e) {
	var n = /[<>&\r\n"']/gm,
	i = {
		"<": "lt;",
		">": "gt;",
		"&": "amp;",
		"\r": "#13;",
		"\n": "#10;",
		'"': "quot;",
		"'": "apos;"
	};
	t.extend({
		fileDownload: function (o, a) {
			function r(t) {
				return (t = t[0].contentWindow || t[0].contentDocument).document && (t = t.document),
				t
			}
			function s(t) {
				setTimeout(function () {
					v && (c && v.close(), d && (v.focus(), t && v.close()))
				}, 0)
			}
			function l(t) {
				return t.replace(n, function (t) {
					return "&" + i[t]
				})
			}
			var d,
			c,
			u,
			h = t.extend({
					preparingMessageHtml: null,
					failMessageHtml: null,
					androidPostUnsupportedMessageHtml: "Unfortunately your Android browser doesn't support this type of file download. Please try again with a different browser.",
					dialogOptions: {
						modal: !0
					},
					prepareCallback: function (t) {},
					successCallback: function (t) {},
					failCallback: function (t, e) {},
					httpMethod: "GET",
					data: null,
					checkInterval: 100,
					cookieName: "fileDownload",
					cookieValue: "true",
					cookiePath: "/",
					popupWindowTitle: "Initiating file download...",
					encodeHTMLEntities: !0
				}, a),
			f = new t.Deferred,
			p = (navigator.userAgent || navigator.vendor || e.opera).toLowerCase();
			if (/ip(ad|hone|od)/.test(p) ? d = !0 : -1 !== p.indexOf("android") ? c = !0 : u = /avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|playbook|silk|iemobile|iris|kindle|lge |maemo|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i.test(p) || /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|e\-|e\/|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(di|rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|xda(\-|2|g)|yas\-|your|zeto|zte\-/i.test(p.substr(0, 4)), p = h.httpMethod.toUpperCase(), c && "GET" !== p)
				return t().dialog ? t("<div>").html(h.androidPostUnsupportedMessageHtml).dialog(h.dialogOptions) : alert(h.androidPostUnsupportedMessageHtml), f.reject();
			var m,
			v,
			g,
			w = null,
			y = {
				onPrepare: function (e) {
					h.preparingMessageHtml ? w = t("<div>").html(h.preparingMessageHtml).dialog(h.dialogOptions) : h.prepareCallback && h.prepareCallback(e)
				},
				onSuccess: function (t) {
					w && w.dialog("close"),
					h.successCallback(t),
					f.resolve(t)
				},
				onFail: function (e, n) {
					w && w.dialog("close"),
					h.failMessageHtml && t("<div>").html(h.failMessageHtml).dialog(h.dialogOptions),
					h.failCallback(e, n),
					f.reject(e, n)
				}
			};
			if (y.onPrepare(o), null !== h.data && "string" != typeof h.data && (h.data = t.param(h.data)), "GET" === p)
				null !== h.data && (-1 !== o.indexOf("?") ? "&" !== o.substring(o.length - 1) && (o += "&") : o += "?", o += h.data), d || c ? (v = e.open(o), v.document.title = h.popupWindowTitle, e.focus()) : u ? e.location(o) : m = t("<iframe>").hide().prop("src", o).appendTo("body");
			else {
				var b = "";
				null !== h.data && t.each(h.data.replace(/\+/g, " ").split("&"), function () {
					var t = this.split("="),
					e = h.encodeHTMLEntities ? l(decodeURIComponent(t[0])) : decodeURIComponent(t[0]);
					e && (t = h.encodeHTMLEntities ? l(decodeURIComponent(t[1])) : decodeURIComponent(t[1]), b += '<input type="hidden" name="' + e + '" value="' + t + '" />')
				}),
				u ? (g = t("<form>").appendTo("body")).hide().prop("method", h.httpMethod).prop("action", o).html(b) : (d ? ((v = e.open("about:blank")).document.title = h.popupWindowTitle, u = v.document, e.focus()) : u = r(m = t("<iframe style='display: none' src='about:blank'></iframe>").appendTo("body")), u.write("<html><head></head><body><form method='" + h.httpMethod + "' action='" + o + "'>" + b + "</form>" + h.popupWindowTitle + "</body></html>"), g = t(u).find("form")),
				g.submit()
			}
			return setTimeout(function e() {
				if (-1 != document.cookie.indexOf(h.cookieName + "=" + h.cookieValue))
					y.onSuccess(o), document.cookie = h.cookieName + "=; expires=" + new Date(1e3).toUTCString() + "; path=" + h.cookiePath, s(!1);
				else {
					if (v || m)
						try {
							var n = v ? v.document : r(m);
							if (n && null != n.body && n.body.innerHTML.length) {
								var i = !0;
								if (g && g.length) {
									var a = t(n.body).contents().first();
									a.length && a[0] === g[0] && (i = !1)
								}
								if (i)
									return y.onFail(n.body.innerHTML, o), void s(!0)
							}
						} catch (t) {
							return y.onFail("", o),
							void s(!0)
						}
					setTimeout(e, h.checkInterval)
				}
			}, h.checkInterval),
			f.promise()
		}
	})
}
(jQuery, this), function (t) {
	t.extend({
		fileUpload: function (e, n) {
			var i = t.extend({
					params: {},
					completeCallback: function () {}
				}, n),
			o = "ajaxUploader-iframe-" + Math.round((new Date).getTime() / 1e3);
			t("body").after('<iframe width="0" height="0" style="display:none;" name="' + o + '" id="' + o + '"/>'),
			t("#" + o).on("load", function () {
				var t,
				n = this.contentWindow.document.body.innerHTML;
				try {
					t = JSON.parse(n)
				} catch (e) {
					t = n
				}
				n = e.children("input[type='hidden']");
				for (key in i.params)
					n.remove("input[name='" + key + "']");
				e.removeAttr("target"),
				i.completeCallback(e, t)
			}),
			e.attr("target", o),
			e.prepend(function () {
				var t,
				e = "";
				for (t in i.params) {
					var n = i.params[t];
					"function" == typeof n && (n = n()),
					e += '<input type="hidden" name="' + t + '" value="' + n + '" />'
				}
				return e
			}),
			e.on("submit", function (t) {
				t.stopPropagation()
			}).trigger("submit")
		}
	})
}
(jQuery);
var tch = tch || {};
function confirmationDialogue(t, e) {
	var n = '<div class="header"><div data-toggle="modal" class="header-title pull-left"><p>' + e + "</p></div></div>";
	$("body").append('<div class="popUpBG"></div>'),
	$("body").append('<div id="popUp"  class="popUp smallcard popUp-modal">' + n + '<div id="Poptxt" class="content"></div>');
	var i = t + '<br/><div class = "pull-center"><div id="ok" class= "btn btn-primary btn-large ' + e + '" align="center">' + okButton + '</div><div id="cancel" class="btn btn-primary btn-large" align="center">' + cancelButton + "</div></div>",
	o = $(document).height(),
	a = (n = $(window).height(), $(window).scrollTop());
	$("#Poptxt").html(i),
	$(".popUpBG").css("height", o),
	i = $(".header .settings").css("background-color"),
	$(".spinner3 div").css("background-color", i),
	10 < a && $("#popUp").css("top", .4 * n + a)
}
!function (t) {
	function e() {
		v && (window.clearTimeout(v), v = void 0),
		g && (window.clearTimeout(g), g = void 0)
	}
	function n(t, n, o) {
		$.isFunction(n) && (o = n, n = void 0),
		(null == n || 1 > n.length || "REFRESH" != n[0].value) && ($(window).scrollTop(0), p(waitMsg));
		var a = $(".modal-action-advanced:first").is(":visible");
		e(),
		$.ajaxSetup({
			beforeSend: function (t) {
				$.xhrPool.push(t)
			}
		}),
		$(".modal").load(t, n, function (t, e, n) {
			$.xhrPool = [],
			m(),
			403 === n.status || 0 < $("#sign-me-in").length ? (p(loginMsg), window.location = "/login.lp") : (("error" === e || "timeout" === e) && httpErrorMessage(n), i(), a && r(), $.isFunction(o) && o(t, e, n))
		})
	}
	function i() {
		if ("1" === $("meta[name=Advanced]").attr("content") && ($(".advanced.hide").removeClass("hide"), $(".advanced.show").remove(), $(".modal-action-advanced").parent().remove()), function () {
			var t = $(".modal-body .wizard").first();
			if (0 !== t.length) {
				var e = 0,
				n = 0,
				i = t.attr("card-previous");
				void 0 != i && (e = +i, n = +t.attr("card-action")),
				(0 === (i = t.find(".wizard-card")).eq(e).find(".error").length && 1 === n || -1 === n) && (e += n, 0 === i.eq(e).find(".error").length && $(".alert-error").detach()),
				t.attr("card-previous", e),
				i.hide(),
				e < i.length ? ($(".wizard-confirm").hide(), i.eq(e).show(), $("#wizard-complete").hide(), 0 === e && $("#wizard-previous").hide()) : $("#wizard-next").hide()
			}
		}
			(), $(".tooltip-on").tooltip(), $(".monitor-changes").each(function () {
				s(this, !0)
			}), $(".noUiSlider.slider-select").each(function () {
				var t = $(this),
				e = t.children("select"),
				n = e.find("option").length,
				i = e.prop("selectedIndex"),
				o = t.next(".noUiSlider-text");
				t.noUiSlider({
					start: i,
					range: {
						min: 0,
						max: n - 1
					},
					step: 1
				}),
				t.on("set", function () {
					var t = $(this),
					e = t.children("select"),
					n = t.next(".noUiSlider-text");
					e.prop("selectedIndex", t.val()),
					e.change(),
					n.text(e.children("option:selected").text())
				}),
				o.text(e.children("option:selected").text())
			}), $(".modal-body .typeahead").each(function (t, e) {
				var n = $(e),
				i = n.data("values"),
				o = [];
				$.each(i, function (t) {
					o.push(t)
				}),
				n.typeahead({
					source: o,
					updater: function (t) {
						return i.hasOwnProperty(t) ? i[t] : t
					}
				})
			}), 0 < $(".modal-header[data-autorefresh]").length) {
			var t = parseInt($(".modal-header").attr("data-autorefresh"), 10);
			!isNaN(t) && 0 < t && (v = window.setTimeout(function () {
						o()
					}, 1e3 * t))
		}
		0 < $(".modal-body [data-ajaxrefresh]").length && (g = window.setTimeout(function () {
					!function t() {
						var e = [{
								name: "action",
								value: "AJAX-GET"
							}, a()];
						e.push({
							name: "auto_update",
							value: "true"
						});
						var n = $(".modal form").attr("action"),
						i = $(".modal-body [data-ajaxrefresh]"),
						o = {},
						r = !1;
						w += 1;
						i.each(function () {
							var t = $(this),
							n = parseInt(t.attr("data-ajaxrefresh"), 10);
							0 == w % n && (n = t.attr("name") || t.attr("id")) && (o[n] = t, e.push({
									name: "requested_params",
									value: n
								}), r = !0)
						});
						r ? $.post(n + "?auto_update=true", e, function (e) {
							if ("string" == typeof e)
								try {
									e = JSON.parse(e)
								} catch (t) {
									return
								}
							for (var n in e)
								if (e.hasOwnProperty(n)) {
									var i = e[n],
									a = o[n];
									a && (a.attr("name") === n ? a.val(i) : a.html(i))
								}
							g = window.setTimeout(function () {
									t(),
									$(".monitor-changes").each(function () {
										s(this, !0)
									})
								}, 1e3)
						}).fail(function (t) {}) : g = window.setTimeout(function () {
								t()
							}, 1e3)
					}
					()
				}, 1e3))
	}
	function o() {
		var t = [{
				name: "operation",
				value: "REFRESH"
			}, a()],
		e = $(".modal form").attr("action"),
		i = $(".modal-body").scrollTop();
		n(e, t, function () {
			i && $(".modal-body").scrollTop(i)
		})
	}
	function a() {
		return {
			name: "CSRFtoken",
			value: $("meta[name=CSRFtoken]").attr("content")
		}
	}
	function r() {
		"1" !== $("meta[name=Advanced]").attr("content") && ($(".modal-action-advanced").toggle(), $(".modal-body .advanced").toggle())
	}
	function s(t, e) {
		var n = e ? 0 : 400,
		i = (r = $(t)).val(),
		o = r.attr("name"),
		a = r.attr("type"),
		r = r.prop("checked");
		("radio" !== a || !0 === r) && ("checkbox" !== a || "_TRUE_" === i || !0 === r) && ("checkbox" === a && "_TRUE_" === i && (i = !0 === r ? 1 : 0), a = $(".monitor-" + o + ":not(.monitor-" + i + ")"), i = $(".monitor-" + o + ".monitor-" + i), r = "monitor-hidden-" + o, o = "monitor-show-" + o, a.addClass(r), a.removeClass(o), a.filter(':not(.monitor-default-show[class*="monitor-show-"])').hide(n), i.removeClass(r), i.addClass(o), i.filter('.monitor-default-show,:not([class*="monitor-hidden-"])').show(n))
	}
	function l(t, e) {
		var i = $(".modal form").attr("action"),
		o = $(e).closest("table"),
		r = o.attr("id"),
		s = $(e).closest("tr").index(),
		l = o.find(".line-edit :input").serializeArray(),
		d = o.find(".additional-edit :input").serializeArray();
		("TABLE-MODIFY" == t || "TABLE-CANCEL" == t) && 0 < d.length && (s -= 2),
		(l = l.concat(d)).push({
			name: "tableid",
			value: r
		}),
		l.push({
			name: "stateid",
			value: o.attr("data-stateid")
		}),
		l.push({
			name: "action",
			value: t
		}),
		l.push({
			name: "index",
			value: s + 1
		}),
		l.push(a()),
		n(i, l, function () {
			c(r, s)
		})
	}
	function d(t, e) {
		var i = $(".modal form").attr("action"),
		o = $(e).closest("center").prev(),
		r = o.attr("id"),
		s = [];
		s.push({
			name: "tableid",
			value: r
		}),
		s.push({
			name: "stateid",
			value: o.attr("data-stateid")
		}),
		s.push({
			name: "action",
			value: t
		}),
		s.push({
			name: "index",
			value: -1
		}),
		s.push({
			name: "listid",
			value: $(e).attr("data-listid")
		}),
		s.push(a()),
		n(i, s, function () {
			c(r, -1)
		})
	}
	function c(t, e) {
		var n = $("#" + t),
		i = n.find("tr").eq(e);
		0 === i.length && (i = n.find("tr").last()),
		0 < i.length && $(".modal-body").scrollTop(i.position().top)
	}
	var lastCardClicked;
	function u(t, e) {
		if (!y) {
			y = !0,
			$(".modal").remove();
			try {
				p(openMsg)
			} catch (t) {
				return void(y = !1)
			}
			$.get(t, function (t) {
				var n = $(t);
				0 < n.find("#sign-me-in").length ? (p(loginMsg), window.location = "/login.lp") : ("1" === $("meta[name=Advanced]").attr("content") && (n.find(".advanced.hide").removeClass("hide"), n.find(".modal-action-advanced").parent().remove()), $('<div class="modal fade" id="' + e + '">' + t + "</div>").modal(), m(), y = !1, i())
			}).fail(function (t) {
				if (y = !1, 403 === t.status)
					p(loginMsg), window.location = "/login.lp";
				else if (500 === t.status) {
					httpErrorMessage(t)
					window.location = "/error.lp?err=" + t.getResponseHeader("error-msg") + "&status=" + t.status;
				} else {
					$(".header-title").filter('[data-id="' + e + '"]').children().html(),
					$(n).modal();
					var n = '<div class="modal fade" id="' + e + '"></div>';
					httpErrorMessage(t)
				}
			})
		}
	}
	function h(t) {
		var e = $(".wizard");
		if ("true" !== e.attr("button-clicked")) {
			e.attr("button-clicked", "true"),
			b && clearTimeout(b),
			b = setTimeout(function () {
					e.attr("button-clicked", "")
				}, 1e3);
			var i = e.attr("card-previous"),
			o = $(".modal form"),
			r = o.serializeArray();
			r.push({
				name: "wizardCardPrevious",
				value: i
			}, {
				name: "wizardCardAction",
				value: t
			}, {
				name: "action",
				value: "VALIDATE"
			}, a()),
			n(t = o.attr("action"), r, function () {
				$('.error input:not([type="hidden"])').first().focus()
			})
		}
	}
	function f() {
		var t = $(this).closest("table"),
		e = $(this).parents(".modal-body.no-save");
		0 === t.length && 0 === e.length && ($("#modal-no-change").fadeOut(300), $("#modal-changes").delay(350).fadeIn(300))
	}
	function p(t) {
		var e = '<div class="header"><div data-toggle="modal" class="header-title pull-left"><p>' + processMsg + "</p></div></div>";
		$("body").append('<div class="popUpBG"></div>'),
		$("body").append('<div id="popUp"  class="popUp smallcard span3">' + e + '<div id="Poptxt" class="content"></div>');
		var n = t + '<br/><div id="spinner" class="spinner" align="center"><div class="spinner3"><div class="rect1"></div><div class="rect2"></div><div class="rect3"></div><div class="rect4"></div><div class="rect5"></div></div></div>',
		i = $(document).height();
		t = $(window).height(),
		e = $(window).scrollTop(),
		$("#Poptxt").html(n),
		$(".popUpBG").css("height", i),
		n = $(".smallcard .header").css("background-color"),
		$(".spinner3 div").css("background-color", n),
		10 < e && $("#popUp").css("top", .4 * t + e)
	}
	function m() {
		$(".popUpBG").remove(),
		$("#popUp").remove()
	}
	var v,
	g;
	count = 0,
	$.xhrPool = [];
	var w = 0;
	$(document).on("change", '.header input[type="hidden"]', function () {
		p(waitMsg);
		var t = $(this).serializeArray();
		t.push({
			name: "action",
			value: "SAVE"
		}, a());
		var e = $(this).closest(".header").children(".header-title").attr("data-remote");
		$.post(e, t, function () {
			window.location.reload(!0)
		}).fail(function (t) {
			(403 === t.status || 0 < $("#sign-me-in").length) && (window.location = "/login.lp");
		})
	}),
	$(document).on("click", ".btn[data-name][data-value]:not(.disabled):not(.custom-handler)", function () {
		var t = [],
		e = $(this).attr("data-name"),
		i = $(this).attr("data-value");
		"action" !== e && t.push({
			name: "action",
			value: "SAVE"
		}),
		t.push({
			name: $(this).attr("data-name"),
			value: $(this).attr("data-value")
		}, a()),
		e = $('.modal-body [data-for~="' + i + '"]').serializeArray(),
		$.each(e, function (e, n) {
			t.push(n)
		}),
		n(e = $(".modal form").attr("action"), t, function () {
			0 < $(".error").closest(".advanced.hide").length && r(),
			$('.error input:not([type="hidden"])').first().focus()
		})
	}),
	$(document).on("click", ".switch:not(.disabled)", function () {
		(e = $(this).children(".switcher")).toggleClass("switcherOn");
		var t = e.attr("valOn") || "1",
		e = e.attr("valOff") || "0";
		$(this).toggleClass("switchOn");
		var n = $(this).children("input"),
		i = n.val();
		return n.val(i === t ? e : t),
		n.trigger("change"),
		!1
	}),
	$(document).on("click", ".modal-action-advanced", function () {
		r()
	}),
	$(document).on("click", ".modal-action-refresh", function () {
		var t = $(".modal form").attr("action"),
		e = $(".modal-body").scrollTop();
		n(t, function () {
			$(".modal-body").scrollTop(e)
		})
	}),
	$(document).on("click", "div[data-value='CONNECT']", function () {
		var t = $(".modal form").attr("action"),
		e = $(".modal-body").scrollTop();
		n(t, function () {
			$(".modal-body").scrollTop(e)
		})
	}),
	$(document).on("click", 'input[type="password"]', function () {
		"********" == $(this).val() && $(this).select()
	}),
	$(document).on("change", "select.monitor-changes", function () {
		s(this)
	}),
	$(document).on("change", 'input[type="hidden"].monitor-changes', function () {
		s(this)
	}),
	$(document).on("click", 'input[type="radio"].monitor-changes', function () {
		s(this)
	}),
	$(document).on("click", 'input[type="checkbox"].monitor-changes', function () {
		s(this)
	}),
	$(document).on("click", ".btn-table-new-list:not(.disabled)", function () {
		d("TABLE-NEW-LIST", this)
	}),
	$(document).on("click", ".btn-table-new:not(.disabled)", function () {
		d("TABLE-NEW", this)
	}),
	$(document).on("click", "table .btn-table-add:not(.disabled)", function () {
		l("TABLE-ADD", this)
	}),
	$(document).on("click", "table .btn-table-delete:not(.disabled)", function () {
		l("TABLE-DELETE", this)
	}),
	$(document).on("click", "table .btn-table-edit:not(.disabled)", function () {
		l("TABLE-EDIT", this)
	}),
	$(document).on("click", "table .btn-table-modify:not(.disabled)", function () {
		l("TABLE-MODIFY", this)
	}),
	$(document).on("click", "table .btn-table-cancel:not(.disabled)", function () {
		l("TABLE-CANCEL", this)
	}),
	$(document).on("change", 'table .switch input[type="hidden"]', function () {
		0 === $(this).closest("table").find(".btn-table-cancel").length && l("TABLE-MODIFY", this)
	}),
	$(document).on("change", "table .checkbox", function () {
		0 === $(this).closest("table").find(".btn-table-cancel").length && l("TABLE-MODIFY", this)
	}),
	$(document).on("click", "#signout", function (t) {
		t.preventDefault(),
		t = $("<form>", {
				action: "/",
				method: "post"
			}).append($("<input>", {
					name: "do_signout",
					value: "1",
					type: "hidden"
				})).append($("<input>", {
					name: "CSRFtoken",
					value: $("meta[name=CSRFtoken]").attr("content"),
					type: "hidden"
				})),
		$("body").append(t),
		t.submit()
	}),
	$(document).on("shown", ".modal", function (t) {
		$(t.target).hasClass("modal") && i()
	}),
	$(document).on("hide", ".modal", function (t) {
		$(t.target).hasClass("modal") && e()
	}),
	$(document).on("hidden", ".modal", function (t) {
		modalToCard = lastCardClicked ? lastCardClicked.find(".settings").data("remote") : null;
		if (count > 0 && $(t.target).hasClass("modal")) {
			if (modalToCard != null) {
				$.get("/ajax/get_card.lua?modal=" + modalToCard, function (data) {
					$(lastCardClicked).parent().replaceWith(data);
				});
			} else {
				window.location.reload(!0);
			}
		}
	});
	var y = !1;
	$(document).on("click touchend", '[data-toggle="modal"]', function (t) {
		t.preventDefault(),
		u(t = $(this).attr("data-remote"), $(this).attr("data-id"))
	}),
	$(document).on("click touchend", ".smallcard", function (t) {
		if (767 < window.innerWidth) {
			t.preventDefault();
			lastCardClicked = $(this);
			var e = $(t.currentTarget).find('[data-toggle="modal"]');
			t = e.attr("data-remote"),
			e = e.attr("data-id"),
			t && u(t, e)
		}
	}),
	$(document).on("click", "#save-config", function () {
		count += 1;
		var t = $(".modal form"),
		e = t.serializeArray();
		e.push({
			name: "action",
			value: "SAVE"
		}, {
			name: "fromModal",
			value: "YES"
		}, a()),
		n(t = t.attr("action"), e, function () {
			var t = $(".error");
			0 < t.length && ($("#modal-no-change").hide(), $("#modal-changes").show());
			var e = $(".modal-action-advanced:first").is(":visible");
			0 < t.closest(".advanced").length && !e && r(),
			$('.error input:not([type="hidden"])').first().trigger("focus")
		})
	});
	var b = null;
	$(document).on("click", "#wizard-next", function () {
		h(1)
	}),
	$(document).on("click", "#wizard-previous", function () {
		h(-1)
	}),
	$(document).on("click", "#wizard-complete", function () {
		$(".loading-wrapper").removeClass("hide"),
		$(".btn").hide();
		var t = $(".wizard").attr("card-previous"),
		e = $(".modal form"),
		i = e.serializeArray();
		i.push({
			name: "wizardCardPrevious",
			value: t
		}, {
			name: "action",
			value: "SAVE"
		}, a()),
		n(t = e.attr("action"), i, function () {
			0 === $(".error").length ? ($(".loading-wrapper").removeClass("hide"), $(".btn").hide(), window.location.reload(!0)) : $('.error input:not([type="hidden"])').first().focus()
		})
	}),
	$(document).on("click", ".nav a", function () {
		var t = $(this),
		e = t.attr("data-remote");
		$(".nav li").each(function () {
			$(this).removeClass("active")
		}),
		t.parent().addClass("active"),
		$.xhrPool.abortAll = function () {
			$(this).each(function (t, e) {
				e.abort()
			})
		},
		0 < $.xhrPool.length && $.xhrPool.abortAll(),
		n(e)
	}),
	$(document).on("keydown", ".modal input:not(.no-save):not(.disabled)", f),
	$(document).on("change", ".modal select:not(.no-save):not(.disabled)", f),
	$(document).on("click", ".modal .switch:not(.no-save):not(.disabled)", f),
	$(document).on("click", '.modal input[type="checkbox"]:not(.no-save):not(.disabled)', f),
	$(document).on("click", '.modal input[type="radio"]:not(.no-save):not(.disabled)', f),
	t.loadModal = n,
	t.modalLoaded = i,
	t.refreshModal = o,
	t.elementCSRFtoken = a,
	t.switchAdvanced = r,
	t.monitorHandler = s,
	t.modalgotchanges = f,
	t.setCookie = function (t, e, n) {
		var i = new Date;
		i.setDate(i.getDate() + n),
		e = encodeURIComponent(e) + (null === n ? "" : "; expires=" + i.toUTCString()),
		document.cookie = t + "=" + e
	},
	t.scrollRowIntoView = c,
	t.removeProgress = m,
	t.showProgress = p,
	t.stringToHex = function (t) {
		return t.replace(/./g, function (t) {
			return new Number(t.charCodeAt(0)).toString(16)
		})
	},
	t.nextWizardCard = h
}
(tch), $(document).ready(function () {
	var t = $(".someInfos");
	t.on("click", function () {
		t.tooltip("hide");
	});
	t.tooltip();
	var tsmall = $(".smallsomeInfos");
	tsmall.on("click", function () {
		tsmall.tooltip("hide");
	});
	tsmall.tooltip();
	$(".tooltip-on").tooltip();
	$('select[name="webui_language"]').on("change", function () {
		tch.setCookie("webui_language", $(this).val(), 30);
		location.reload(!0);
	});
	1 < window.location.hash.length && ($('div[data-id="' + window.location.hash.substring(1) + '"]').click(), window.location.hash = "");
});
var qrcode = function () {
	function t(e, n) {
		if (void 0 === e.length)
			throw Error(e.length + "/" + n);
		var i = function () {
			for (var t = 0; t < e.length && 0 == e[t]; )
				t += 1;
			for (var i = Array(e.length - t + n), o = 0; o < e.length - t; o += 1)
				i[o] = e[o + t];
			return i
		}
		(),
		o = {
			getAt: function (t) {
				return i[t]
			},
			getLength: function () {
				return i.length
			},
			multiply: function (e) {
				for (var n = Array(o.getLength() + e.getLength() - 1), i = 0; i < o.getLength(); i += 1)
					for (var a = 0; a < e.getLength(); a += 1)
						n[i + a] ^= d.gexp(d.glog(o.getAt(i)) + d.glog(e.getAt(a)));
				return t(n, 0)
			},
			mod: function (e) {
				if (0 > o.getLength() - e.getLength())
					return o;
				for (var n = d.glog(o.getAt(0)) - d.glog(e.getAt(0)), i = Array(o.getLength()), a = 0; a < o.getLength(); a += 1)
					i[a] = o.getAt(a);
				for (a = 0; a < e.getLength(); a += 1)
					i[a] ^= d.gexp(d.glog(e.getAt(a)) + n);
				return t(i, 0).mod(e)
			}
		};
		return o
	}
	var e = function (e, n) {
		var i = s[n],
		o = null,
		a = 0,
		r = null,
		d = [],
		f = {},
		p = function (n, s) {
			for (var h = a = 4 * e + 17, f = Array(h), p = 0; p < h; p += 1) {
				f[p] = Array(h);
				for (var v = 0; v < h; v += 1)
					f[p][v] = null
			}
			for (o = f, m(0, 0), m(a - 7, 0), m(0, a - 7), h = l.getPatternPosition(e), f = 0; f < h.length; f += 1)
				for (p = 0; p < h.length; p += 1) {
					v = h[f];
					var g = h[p];
					if (null == o[v][g])
						for (var w = -2; 2 >= w; w += 1)
							for (var y = -2; 2 >= y; y += 1)
								o[v + w][g + y] = -2 == w || 2 == w || -2 == y || 2 == y || 0 == w && 0 == y
				}
			for (h = 8; h < a - 8; h += 1)
				null == o[h][6] && (o[h][6] = 0 == h % 2);
			for (h = 8; h < a - 8; h += 1)
				null == o[6][h] && (o[6][h] = 0 == h % 2);
			for (h = l.getBCHTypeInfo(i << 3 | s), f = 0; 15 > f; f += 1)
				p = !n && 1 == (h >> f & 1), 6 > f ? o[f][8] = p : 8 > f ? o[f + 1][8] = p : o[a - 15 + f][8] = p;
			for (f = 0; 15 > f; f += 1)
				p = !n && 1 == (h >> f & 1), 8 > f ? o[8][a - f - 1] = p : 9 > f ? o[8][15 - f - 1 + 1] = p : o[8][15 - f - 1] = p;
			if (o[a - 8][8] = !n, 7 <= e) {
				for (h = l.getBCHTypeNumber(e), f = 0; 18 > f; f += 1)
					p = !n && 1 == (h >> f & 1), o[Math.floor(f / 3)][f % 3 + a - 8 - 3] = p;
				for (f = 0; 18 > f; f += 1)
					p = !n && 1 == (h >> f & 1), o[f % 3 + a - 8 - 3][Math.floor(f / 3)] = p
			}
			if (null == r) {
				for (h = c.getRSBlocks(e, i), f = u(), p = 0; p < d.length; p += 1)
					v = d[p], f.put(v.getMode(), 4), f.put(v.getLength(), l.getLengthInBits(v.getMode(), e)), v.write(f);
				for (p = v = 0; p < h.length; p += 1)
					v += h[p].dataCount;
				if (f.getLengthInBits() > 8 * v)
					throw Error("code length overflow. (" + f.getLengthInBits() + ">" + 8 * v + ")");
				for (f.getLengthInBits() + 4 <= 8 * v && f.put(0, 4); 0 != f.getLengthInBits() % 8; )
					f.putBit(!1);
				for (; !(f.getLengthInBits() >= 8 * v) && (f.put(236, 8), !(f.getLengthInBits() >= 8 * v)); )
					f.put(17, 8);
				var b = 0;
				for (v = p = 0, g = Array(h.length), w = Array(h.length), y = 0; y < h.length; y += 1) {
					var $ = h[y].dataCount,
					k = h[y].totalCount - $;
					p = Math.max(p, $),
					v = Math.max(v, k);
					g[y] = Array($);
					for (var x = 0; x < g[y].length; x += 1)
						g[y][x] = 255 & f.getBuffer()[x + b];
					for (b += $, x = l.getErrorCorrectPolynomial(k), $ = t(g[y], x.getLength() - 1).mod(x), w[y] = Array(x.getLength() - 1), x = 0; x < w[y].length; x += 1)
						k = x + $.getLength() - w[y].length, w[y][x] = 0 <= k ? $.getAt(k) : 0
				}
				for (x = f = 0; x < h.length; x += 1)
					f += h[x].totalCount;
				for (f = Array(f), x = b = 0; x < p; x += 1)
					for (y = 0; y < h.length; y += 1)
						x < g[y].length && (f[b] = g[y][x], b += 1);
				for (x = 0; x < v; x += 1)
					for (y = 0; y < h.length; y += 1)
						x < w[y].length && (f[b] = w[y][x], b += 1);
				r = f
			}
			for (h = r, f = -1, p = a - 1, v = 7, g = 0, w = l.getMaskFunction(s), y = a - 1; 0 < y; y -= 2)
				for (6 == y && (y -= 1); ; ) {
					for (x = 0; 2 > x; x += 1)
						null == o[p][y - x] && (b = !1, g < h.length && (b = 1 == (h[g] >>> v & 1)), w(p, y - x) && (b = !b), o[p][y - x] = b, v -= 1, -1 == v && (g += 1, v = 7));
					if (0 > (p += f) || a <= p) {
						p -= f,
						f = -f;
						break
					}
				}
		},
		m = function (t, e) {
			for (var n = -1; 7 >= n; n += 1)
				if (!(-1 >= t + n || a <= t + n))
					for (var i = -1; 7 >= i; i += 1)
						-1 >= e + i || a <= e + i || (o[t + n][e + i] = 0 <= n && 6 >= n && (0 == i || 6 == i) || 0 <= i && 6 >= i && (0 == n || 6 == n) || 2 <= n && 4 >= n && 2 <= i && 4 >= i)
		};
		return f.addData = function (t) {
			t = h(t),
			d.push(t),
			r = null
		},
		f.isDark = function (t, e) {
			if (0 > t || a <= t || 0 > e || a <= e)
				throw Error(t + "," + e);
			return o[t][e]
		},
		f.getModuleCount = function () {
			return a
		},
		f.make = function () {
			for (var t = 0, e = 0, n = 0; 8 > n; n += 1) {
				p(!0, n);
				var i = l.getLostPoint(f);
				(0 == n || t > i) && (t = i, e = n)
			}
			p(!1, e)
		},
		f.createTableTag = function (t, e) {
			var n;
			t = t || 2,
			n = '<table style=" border-width: 0px; border-style: none;',
			n += " border-collapse: collapse;",
			n += " padding: 0px; margin: " + (void 0 === e ? 4 * t : e) + "px;",
			n += '">',
			n += "<tbody>";
			for (var i = 0; i < f.getModuleCount(); i += 1) {
				n += "<tr>";
				for (var o = 0; o < f.getModuleCount(); o += 1)
					n += '<td style="', n += " border-width: 0px; border-style: none;", n += " border-collapse: collapse;", n += " padding: 0px; margin: 0px;", n += " width: " + t + "px;", n += " height: " + t + "px;", n += " background-color: ", n += f.isDark(i, o) ? "#000000" : "#ffffff", n += ";", n += '"/>';
				n += "</tr>"
			}
			return (n += "</tbody>") + "</table>"
		},
		f.createImgTag = function (t, e) {
			t = t || 2,
			e = void 0 === e ? 4 * t : e;
			var n = f.getModuleCount() * t + 2 * e,
			i = e,
			o = n - e;
			return v(n, n, function (e, n) {
				return i <= e && e < o && i <= n && n < o && f.isDark(Math.floor((n - i) / t), Math.floor((e - i) / t)) ? 0 : 1
			})
		},
		f
	};
	e.stringToBytes = function (t) {
		for (var e = [], n = 0; n < t.length; n += 1) {
			var i = t.charCodeAt(n);
			e.push(255 & i)
		}
		return e
	},
	e.createStringToBytes = function (t, e) {
		var n = function () {
			for (var n = p(t), i = function () {
				var t = n.read();
				if (-1 == t)
					throw Error();
					return t
				}, o = 0, a = {}; ; ) {
					if (-1 == (r = n.read()))
						break;
					var r,
					s = i(),
					l = i(),
					d = i();
					a[r = String.fromCharCode(r << 8 | s)] = l << 8 | d,
					o += 1
				}
			if (o != e)
				throw Error(o + " != " + e);
			return a
		}
		();
		return function (t) {
			for (var e = [], i = 0; i < t.length; i += 1) {
				var o = t.charCodeAt(i);
				128 > o ? e.push(o) : "number" == typeof(o = n[t.charAt(i)]) ? (255 & o) == o ? e.push(o) : (e.push(o >>> 8), e.push(255 & o)) : e.push(63)
			}
			return e
		}
	};
	var n,
	i,
	o,
	a,
	r,
	s = {
		L: 1,
		M: 0,
		Q: 3,
		H: 2
	},
	l = (o = [[], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34], [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50], [6, 30, 54], [6, 32, 58], [6, 34, 62], [6, 26, 46, 66], [6, 26, 48, 70], [6, 26, 50, 74], [6, 30, 54, 78], [6, 30, 56, 82], [6, 30, 58, 86], [6, 34, 62, 90], [6, 28, 50, 72, 94], [6, 26, 50, 74, 98], [6, 30, 54, 78, 102], [6, 28, 54, 80, 106], [6, 32, 58, 84, 110], [6, 30, 58, 86, 114], [6, 34, 62, 90, 118], [6, 26, 50, 74, 98, 122], [6, 30, 54, 78, 102, 126], [6, 26, 52, 78, 104, 130], [6, 30, 56, 82, 108, 134], [6, 34, 60, 86, 112, 138], [6, 30, 58, 86, 114, 142], [6, 34, 62, 90, 118, 146], [6, 30, 54, 78, 102, 126, 150], [6, 24, 50, 76, 102, 128, 154], [6, 28, 54, 80, 106, 132, 158], [6, 32, 58, 84, 110, 136, 162], [6, 26, 54, 82, 110, 138, 166], [6, 30, 58, 86, 114, 142, 170]], r = function (t) {
		for (var e = 0; 0 != t; )
			e += 1, t >>>= 1;
		return e
	}, (a = {}).getBCHTypeInfo = function (t) {
		for (var e = t << 10; 0 <= r(e) - r(1335); )
			e ^= 1335 << r(e) - r(1335);
		return 21522 ^ (t << 10 | e)
	}, a.getBCHTypeNumber = function (t) {
		for (var e = t << 12; 0 <= r(e) - r(7973); )
			e ^= 7973 << r(e) - r(7973);
		return t << 12 | e
	}, a.getPatternPosition = function (t) {
		return o[t - 1]
	}, a.getMaskFunction = function (t) {
		switch (t) {
		case 0:
			return function (t, e) {
				return 0 == (t + e) % 2
			};
		case 1:
			return function (t, e) {
				return 0 == t % 2
			};
		case 2:
			return function (t, e) {
				return 0 == e % 3
			};
		case 3:
			return function (t, e) {
				return 0 == (t + e) % 3
			};
		case 4:
			return function (t, e) {
				return 0 == (Math.floor(t / 2) + Math.floor(e / 3)) % 2
			};
		case 5:
			return function (t, e) {
				return 0 == t * e % 2 + t * e % 3
			};
		case 6:
			return function (t, e) {
				return 0 == (t * e % 2 + t * e % 3) % 2
			};
		case 7:
			return function (t, e) {
				return 0 == (t * e % 3 + (t + e) % 2) % 2
			};
		default:
			throw Error("bad maskPattern:" + t)
		}
	}, a.getErrorCorrectPolynomial = function (e) {
		for (var n = t([1], 0), i = 0; i < e; i += 1)
			n = n.multiply(t([1, d.gexp(i)], 0));
		return n
	}, a.getLengthInBits = function (t, e) {
		if (1 <= e && 10 > e)
			switch (t) {
			case 1:
				return 10;
			case 2:
				return 9;
			case 4:
			case 8:
				return 8;
			default:
				throw Error("mode:" + t)
			}
		else if (27 > e)
			switch (t) {
			case 1:
				return 12;
			case 2:
				return 11;
			case 4:
				return 16;
			case 8:
				return 10;
			default:
				throw Error("mode:" + t)
			}
		else {
			if (!(41 > e))
				throw Error("type:" + e);
			switch (t) {
			case 1:
				return 14;
			case 2:
				return 13;
			case 4:
				return 16;
			case 8:
				return 12;
			default:
				throw Error("mode:" + t)
			}
		}
	}, a.getLostPoint = function (t) {
		for (var e = t.getModuleCount(), n = 0, i = 0; i < e; i += 1)
			for (var o = 0; o < e; o += 1) {
				for (var a = 0, r = t.isDark(i, o), s = -1; 1 >= s; s += 1)
					if (!(0 > i + s || e <= i + s))
						for (var l = -1; 1 >= l; l += 1)
							0 > o + l || e <= o + l || 0 == s && 0 == l || r == t.isDark(i + s, o + l) && (a += 1);
				5 < a && (n += 3 + a - 5)
			}
		for (i = 0; i < e - 1; i += 1)
			for (o = 0; o < e - 1; o += 1)
				a = 0, t.isDark(i, o) && (a += 1), t.isDark(i + 1, o) && (a += 1), t.isDark(i, o + 1) && (a += 1), t.isDark(i + 1, o + 1) && (a += 1), (0 == a || 4 == a) && (n += 3);
		for (i = 0; i < e; i += 1)
			for (o = 0; o < e - 6; o += 1)
				t.isDark(i, o) && !t.isDark(i, o + 1) && t.isDark(i, o + 2) && t.isDark(i, o + 3) && t.isDark(i, o + 4) && !t.isDark(i, o + 5) && t.isDark(i, o + 6) && (n += 40);
		for (o = 0; o < e; o += 1)
			for (i = 0; i < e - 6; i += 1)
				t.isDark(i, o) && !t.isDark(i + 1, o) && t.isDark(i + 2, o) && t.isDark(i + 3, o) && t.isDark(i + 4, o) && !t.isDark(i + 5, o) && t.isDark(i + 6, o) && (n += 40);
		for (o = a = 0; o < e; o += 1)
			for (i = 0; i < e; i += 1)
				t.isDark(i, o) && (a += 1);
		return n + 10 * (t = Math.abs(100 * a / e / e - 50) / 5)
	}, a),
	d = function () {
		for (var t = Array(256), e = Array(256), n = 0; 8 > n; n += 1)
			t[n] = 1 << n;
		for (n = 8; 256 > n; n += 1)
			t[n] = t[n - 4] ^ t[n - 5] ^ t[n - 6] ^ t[n - 8];
		for (n = 0; 255 > n; n += 1)
			e[t[n]] = n;
		return {
			glog: function (t) {
				if (1 > t)
					throw Error("glog(" + t + ")");
				return e[t]
			},
			gexp: function (e) {
				for (; 0 > e; )
					e += 255;
				for (; 256 <= e; )
					e -= 255;
				return t[e]
			}
		}
	}
	(),
	c = (n = [[1, 26, 19], [1, 26, 16], [1, 26, 13], [1, 26, 9], [1, 44, 34], [1, 44, 28], [1, 44, 22], [1, 44, 16], [1, 70, 55], [1, 70, 44], [2, 35, 17], [2, 35, 13], [1, 100, 80], [2, 50, 32], [2, 50, 24], [4, 25, 9], [1, 134, 108], [2, 67, 43], [2, 33, 15, 2, 34, 16], [2, 33, 11, 2, 34, 12], [2, 86, 68], [4, 43, 27], [4, 43, 19], [4, 43, 15], [2, 98, 78], [4, 49, 31], [2, 32, 14, 4, 33, 15], [4, 39, 13, 1, 40, 14], [2, 121, 97], [2, 60, 38, 2, 61, 39], [4, 40, 18, 2, 41, 19], [4, 40, 14, 2, 41, 15], [2, 146, 116], [3, 58, 36, 2, 59, 37], [4, 36, 16, 4, 37, 17], [4, 36, 12, 4, 37, 13], [2, 86, 68, 2, 87, 69], [4, 69, 43, 1, 70, 44], [6, 43, 19, 2, 44, 20], [6, 43, 15, 2, 44, 16]], (i = {}).getRSBlocks = function (t, e) {
		var i,
		o,
		a,
		r = function (t, e) {
			switch (e) {
			case s.L:
				return n[4 * (t - 1) + 0];
			case s.M:
				return n[4 * (t - 1) + 1];
			case s.Q:
				return n[4 * (t - 1) + 2];
			case s.H:
				return n[4 * (t - 1) + 3]
			}
		}
		(t, e);
		if (void 0 === r)
			throw Error("bad rs block @ typeNumber:" + t + "/errorCorrectLevel:" + e);
		for (var l = r.length / 3, d = [], c = 0; c < l; c += 1)
			for (var u = r[3 * c + 0], h = r[3 * c + 1], f = r[3 * c + 2], p = 0; p < u; p += 1)
				d.push((i = h, o = f, a = void 0, a = {}, a.totalCount = i, a.dataCount = o, a));
		return d
	}, i),
	u = function () {
		var t = [],
		e = 0,
		n = {
			getBuffer: function () {
				return t
			},
			getAt: function (e) {
				return 1 == (t[Math.floor(e / 8)] >>> 7 - e % 8 & 1)
			},
			put: function (t, e) {
				for (var i = 0; i < e; i += 1)
					n.putBit(1 == (t >>> e - i - 1 & 1))
			},
			getLengthInBits: function () {
				return e
			},
			putBit: function (n) {
				var i = Math.floor(e / 8);
				t.length <= i && t.push(0),
				n && (t[i] |= 128 >>> e % 8),
				e += 1
			}
		};
		return n
	},
	h = function (t) {
		var n = e.stringToBytes(t);
		return {
			getMode: function () {
				return 4
			},
			getLength: function (t) {
				return n.length
			},
			write: function (t) {
				for (var e = 0; e < n.length; e += 1)
					t.put(n[e], 8)
			}
		}
	},
	f = function () {
		var t = [],
		e = {
			writeByte: function (e) {
				t.push(255 & e)
			},
			writeShort: function (t) {
				e.writeByte(t),
				e.writeByte(t >>> 8)
			},
			writeBytes: function (t, n, i) {
				n = n || 0,
				i = i || t.length;
				for (var o = 0; o < i; o += 1)
					e.writeByte(t[o + n])
			},
			writeString: function (t) {
				for (var n = 0; n < t.length; n += 1)
					e.writeByte(t.charCodeAt(n))
			},
			toByteArray: function () {
				return t
			},
			toString: function () {
				var e;
				e = "[";
				for (var n = 0; n < t.length; n += 1)
					0 < n && (e += ","), e += t[n];
				return e + "]"
			}
		};
		return e
	},
	p = function (t) {
		var e = 0,
		n = 0,
		i = 0,
		o = function (t) {
			if (65 <= t && 90 >= t)
				return t - 65;
			if (97 <= t && 122 >= t)
				return t - 97 + 26;
			if (48 <= t && 57 >= t)
				return t - 48 + 52;
			if (43 == t)
				return 62;
			if (47 == t)
				return 63;
			throw Error("c:" + t)
		};
		return {
			read: function () {
				for (; 8 > i; ) {
					if (e >= t.length) {
						if (0 == i)
							return -1;
						throw Error("unexpected end of file./" + i)
					}
					var a = t.charAt(e);
					if (e += 1, "=" == a)
						return i = 0, -1;
					a.match(/^\s$/) || (n = n << 6 | o(a.charCodeAt(0)), i += 6)
				}
				return a = n >>> i - 8 & 255,
				i -= 8,
				a
			}
		}
	},
	m = function (t, e) {
		var n = Array(t * e);
		return {
			setPixel: function (e, i, o) {
				n[i * t + e] = o
			},
			write: function (i) {
				var o;
				i.writeString("GIF87a"),
				i.writeShort(t),
				i.writeShort(e),
				i.writeByte(128),
				i.writeByte(0),
				i.writeByte(0),
				i.writeByte(0),
				i.writeByte(0),
				i.writeByte(0),
				i.writeByte(255),
				i.writeByte(255),
				i.writeByte(255),
				i.writeString(","),
				i.writeShort(0),
				i.writeShort(0),
				i.writeShort(t),
				i.writeShort(e),
				i.writeByte(0),
				o = 3;
				for (var a = function () {
					var t = {},
					e = 0,
					n = {
						add: function (i) {
							if (n.contains(i))
								throw Error("dup key:" + i);
								t[i] = e,
								e += 1
							},
							size: function () {
								return e
							},
							indexOf: function (e) {
								return t[e]
							},
							contains: function (e) {
								return void 0 !== t[e]
							}
						};
						return n
					}
						(), r = 0; 4 > r; r += 1)a.add(String.fromCharCode(r));
				a.add(String.fromCharCode(4)),
				a.add(String.fromCharCode(5));
				r = f();
				var s,
				l,
				d,
				c = (s = r, l = 0, d = 0, {
					write: function (t, e) {
						if (0 != t >>> e)
							throw Error("length over");
						for (; 8 <= l + e; )
							s.writeByte(255 & (t << l | d)), e -= 8 - l, t >>>= 8 - l, l = d = 0;
						d |= t << l,
						l += e
					},
					flush: function () {
						0 < l && s.writeByte(d)
					}
				});
				c.write(4, o);
				var u = 0,
				h = String.fromCharCode(n[u]);
				for (u = u + 1; u < n.length; ) {
					var p = String.fromCharCode(n[u]);
					u = u + 1;
					a.contains(h + p) ? h += p : (c.write(a.indexOf(h), o), 4095 > a.size() && (a.size() == 1 << o && (o += 1), a.add(h + p)), h = p)
				}
				for (c.write(a.indexOf(h), o), c.write(5, o), c.flush(), o = r.toByteArray(), i.writeByte(2), a = 0; 255 < o.length - a; )
					i.writeByte(255), i.writeBytes(o, a, 255), a += 255;
				i.writeByte(o.length - a),
				i.writeBytes(o, a, o.length - a),
				i.writeByte(0),
				i.writeString(";")
			}
		}
	},
	v = function (t, e, n, i) {
		for (var o = m(t, e), a = 0; a < e; a += 1)
			for (var r = 0; r < t; r += 1)
				o.setPixel(r, a, n(r, a));
		var s,
		l,
		d,
		c,
		u,
		h;
		for (n = f(), o.write(n), s = 0, l = 0, d = 0, c = "", h = function (t) {
			if (!(0 > t)) {
				if (26 > t)
					return 65 + t;
				if (52 > t)
					return t - 26 + 97;
				if (62 > t)
					return t - 52 + 48;
				if (62 == t)
					return 43;
				if (63 == t)
					return 47
			}
			throw Error("n:" + t)
		}, (u = {}).writeByte = function (t) {
			for (s = s << 8 | 255 & t, l += 8, d += 1; 6 <= l; )
				c += String.fromCharCode(h(s >>> l - 6 & 63)) , l -= 6
			}, u.flush = function () {
				if (0 < l && (c += String.fromCharCode(h(s << 6 - l & 63)), l = s = 0), 0 != d % 3)
					for (var t = 3 - d % 3, e = 0; e < t; e += 1)
						c += "="
			}, u.toString = function () {
				return c
			}, o = u, n = n.toByteArray(), a = 0; a < n.length; a += 1)o.writeByte(n[a]);
		return o.flush(),
		n = '<img src="',
		n += "data:image/gif;base64,",
		n += o,
		n += '"',
		n += ' width="',
		n += t,
		n += '"',
		n += ' height="',
		n += e,
		n += '"',
		i && (n += ' alt="', n += i, n += '"'),
		n + "/>"
	};
	return e
}
();
!function (t) {
	function e(e, n) {
		function r(t, e, n) {
			if (t.stopPropagation(), t.preventDefault(), !Y && !d(e) && !e.hasClass("dwa")) {
				Y = !0;
				var i = e.find(".dw-ul");
				m(i),
				clearInterval(ot),
				ot = setInterval(function () {
						n(i)
					}, ut.delay),
				n(i)
			}
		}
		function d(e) {
			return t.isArray(ut.readonly) ? (e = t(".dwwl", j).index(e), ut.readonly[e]) : ut.readonly
		}
		function h(e) {
			var n = '<div class="dw-bf">',
			i = 1,
			o = (e = (e = vt[e]).values ? e : a(e)).labels || [],
			r = e.values,
			s = e.keys || r;
			return t.each(r, function (t, e) {
				0 == i % 20 && (n += '</div><div class="dw-bf">'),
				n += '<div role="option" aria-selected="false" class="dw-li dw-v" data-val="' + s[t] + '"' + (o[t] ? ' aria-label="' + o[t] + '"' : "") + ' style="height:' + O + "px;line-height:" + O + 'px;"><div class="dw-i">' + e + "</div></div>",
				i++
			}),
			n += "</div>"
		}
		function m(e) {
			tt = t(".dw-li", e).index(t(".dw-v", e).eq(0)),
			et = t(".dw-li", e).index(t(".dw-v", e).eq(-1)),
			it = t(".dw-ul", j).index(e)
		}
		function C() {
			st.temp = gt && null !== st.val && st.val != ct.val() || null === st.values ? ut.parseValue(ct.val() || "", st) : st.values.slice(0),
			B()
		}
		function T(t, e) {
			clearTimeout(ft[e]),
			delete ft[e],
			t.closest(".dwwl").removeClass("dwa")
		}
		function S(t, e, n, i, o) {
			var a = (L - n) * O,
			r = t[0].style;
			a == mt[e] && ft[e] || (i && a != mt[e] && D("onAnimStart", [j, e, i]), mt[e] = a, r[w + "Transition"] = "all " + (i ? i.toFixed(3) : 0) + "s ease-out", v ? r[w + "Transform"] = "translate3d(0," + a + "px,0)" : r.top = a + "px", ft[e] && T(t, e), i && o && (t.closest(".dwwl").addClass("dwa"), ft[e] = setTimeout(function () {
							T(t, e)
						}, 1e3 * i)), pt[e] = n)
		}
		function A(e, n, i, o, a) {
			var r,
			s;
			!1 !== D("validate", [j, n, e]) && (t(".dw-ul", j).each(function (i) {
					var r = t(this),
					s = t('.dw-li[data-val="' + st.temp[i] + '"]', r),
					l = t(".dw-li", r),
					d = l.index(s),
					c = l.length,
					u = i == n || void 0 === n;
					if (!s.hasClass("dw-v")) {
						for (var h = s, f = 0, p = 0; 0 <= d - f && !h.hasClass("dw-v"); )
							f++, h = l.eq(d - f);
						for (; d + p < c && !s.hasClass("dw-v"); )
							p++, s = l.eq(d + p);
						(p < f && p && 2 !== o || !f || 0 > d - f || 1 == o) && s.hasClass("dw-v") ? d += p : (s = h, d -= f)
					}
					s.hasClass("dw-sel") && !u || (st.temp[i] = s.attr("data-val"), t(".dw-sel", r).removeClass("dw-sel"), ut.multiple || (t(".dw-sel", r).removeAttr("aria-selected"), s.attr("aria-selected", "true")), s.addClass("dw-sel"), S(r, i, d, u ? e : .1, !!u && a))
				}), U = ut.formatResult(st.temp), "inline" == ut.display ? B(i, 0, !0) : t(".dwv", j).html((r = U, (s = ut.headerText) ? "function" == typeof s ? s.call(dt, r) : s.replace(/\{value\}/i, r) : "")), i && D("onChange", [U]))
		}
		function D(e, i) {
			var o;
			return i.push(st),
			t.each([R.defaults, ht, n], function (t, n) {
				n[e] && (o = n[e].apply(dt, i))
			}),
			o
		}
		function M(e, n, i, o, a) {
			n = Math.max(tt, Math.min(n, et));
			var r = t(".dw-li", e).eq(n),
			s = void 0 === a ? n : a,
			l = it,
			d = o ? n == s ? .1 : Math.abs((n - s) * ut.timeUnit) : 0;
			st.temp[l] = r.attr("data-val"),
			S(e, l, n, d, a),
			setTimeout(function () {
				A(d, l, !0, i, void 0 !== a)
			}, 10)
		}
		function E(t) {
			var e = pt[it] + 1;
			M(t, e > et ? tt : e, 1, !0)
		}
		function P(t) {
			var e = pt[it] - 1;
			M(t, e < tt ? et : e, 2, !0)
		}
		function B(t, e, n, i) {
			wt && !n && A(e),
			U = ut.formatResult(st.temp),
			i || (st.values = st.temp.slice(0), st.val = U),
			t && gt && ct.val(U).trigger("change")
		}
		var L,
		O,
		U,
		j,
		F,
		I,
		V,
		z,
		H,
		N,
		W,
		q,
		R,
		_,
		Y,
		Q,
		G,
		J,
		X,
		Z,
		K,
		tt,
		et,
		nt,
		it,
		ot,
		at,
		rt,
		st = this,
		lt = t.mobiscroll,
		dt = e,
		ct = t(dt),
		ut = y({}, x),
		ht = {},
		ft = {},
		pt = {},
		mt = {},
		vt = [],
		gt = ct.is("input"),
		wt = !1,
		yt = function (e) {
			var n,
			a,
			r;
			i(e) && !s && !d(this) && !Y && (e.preventDefault(), s = !0, Q = "clickpick" != ut.mode, m(nt = t(".dw-ul", this)), K = (G = void 0 !== ft[it]) ? (n = nt, r = window.getComputedStyle ? getComputedStyle(n[0]) : n[0].style, v ? (t.each(["t", "webkitT", "MozT", "OT", "msT"], function (t, e) {
							if (void 0 !== r[e + "ransform"])
								return a = r[e + "ransform"], !1
						}), n = (a = a.split(")")[0].split(", "))[13] || a[5]) : n = r.top.replace("px", ""), Math.round(L - n / O)) : pt[it], J = o(e, "Y"), X = new Date, Z = J, S(nt, it, K, .001), Q && nt.closest(".dwwl").addClass("dwa"), t(document).on($, bt).on(k, $t))
		},
		bt = function (t) {
			Q && (t.preventDefault(), t.stopPropagation(), Z = o(t, "Y"), S(nt, it, Math.max(tt - 1, Math.min(K + (J - Z) / O, et + 1)))),
			G = !0
		},
		$t = function (e) {
			var n = new Date - X;
			e = Math.max(tt - 1, Math.min(K + (J - Z) / O, et + 1));
			var i,
			o = nt.offset().top;
			if (300 > n ? (i = (n = (Z - J) / n) * n / ut.speedUnit, 0 > Z - J && (i = -i)) : i = Z - J, n = Math.round(K - i / O), !i && !G) {
				o = Math.floor((Z - o) / O);
				var a = t(".dw-li", nt).eq(o);
				i = Q,
				!1 !== D("onValueTap", [a]) ? n = o : i = !0,
				i && (a.addClass("dw-hl"), setTimeout(function () {
						a.removeClass("dw-hl")
					}, 200))
			}
			Q && M(nt, n, 0, !0, Math.round(e)),
			s = !1,
			nt = null,
			t(document).off($, bt).off(k, $t)
		},
		kt = function (e) {
			var n = t(this);
			t(document).on(k, xt),
			n.hasClass("dwb-d") || n.addClass("dwb-a"),
			setTimeout(function () {
				n.trigger("blur")
			}, 10),
			n.hasClass("dwwb") && i(e) && r(e, n.closest(".dwwl"), n.hasClass("dwwbp") ? E : P)
		},
		xt = function (e) {
			Y && (clearInterval(ot), Y = !1),
			t(document).off(k, xt),
			t(".dwb-a", j).removeClass("dwb-a")
		},
		Ct = function (e) {
			38 == e.keyCode ? r(e, t(this), P) : 40 == e.keyCode && r(e, t(this), E)
		},
		Tt = function (t) {
			Y && (clearInterval(ot), Y = !1)
		},
		St = function (e) {
			if (!d(this)) {
				e.preventDefault(),
				e = (e = e.originalEvent || e).wheelDelta ? e.wheelDelta / 120 : e.detail ? -e.detail / 3 : 0;
				var n = t(".dw-ul", this);
				m(n),
				M(n, Math.round(pt[it] - e), 0 > e ? 1 : 2)
			}
		};
		st.position = function (e) {
			if (!("inline" == ut.display || F === t(window).width() && V === t(window).height() && e || !1 === D("onPosition", [j]))) {
				var n,
				i,
				o,
				a,
				r,
				s,
				l,
				d,
				c,
				u = 0,
				h = 0;
				e = t(window).scrollTop(),
				a = t(".dwwr", j);
				var f = t(".dw", j),
				p = {};
				r = void 0 === ut.anchor ? ct : ut.anchor,
				F = t(window).width(),
				V = t(window).height(),
				I = (I = window.innerHeight) || V,
				/modal|bubble/.test(ut.display) && (t(".dwc", j).each(function () {
						n = t(this).outerWidth(!0),
						u += n,
						h = n > h ? n : h
					}), n = u > F ? h : u, a.width(n).css("white-space", u > F ? "" : "nowrap")),
				z = f.outerWidth(),
				H = f.outerHeight(!0),
				N = H <= I && z <= F,
				"modal" == ut.display ? (i = (F - z) / 2, o = e + (I - H) / 2) : "bubble" == ut.display ? (c = !0, d = t(".dw-arrw-i", j), s = (i = r.offset()).top, l = i.left, a = r.outerWidth(), r = r.outerHeight(), i = 0 <= (i = (i = l - (f.outerWidth(!0) - a) / 2) > F - z ? F - (z + 20) : i) ? i : 20, (o = s - H) < e || s > e + I ? (f.removeClass("dw-bubble-top").addClass("dw-bubble-bottom"), o = s + r) : f.removeClass("dw-bubble-bottom").addClass("dw-bubble-top"), d = d.outerWidth(), a = l + a / 2 - (i + (z - d) / 2), t(".dw-arr", j).css({
						left: Math.max(0, Math.min(a, d))
					})) : (p.width = "100%", "top" == ut.display ? o = e : "bottom" == ut.display && (o = e + I - H)),
				p.top = 0 > o ? 0 : o,
				p.left = i,
				f.css(p),
				t(".dw-persp", j).height(0).height(o + H > t(document).height() ? o + H : t(document).height()),
				c && (o + H > e + I || s > e + I) && t(window).scrollTop(o + H - I)
			}
		},
		st.enable = function () {
			ut.disabled = !1,
			gt && ct.prop("disabled", !1)
		},
		st.disable = function () {
			ut.disabled = !0,
			gt && ct.prop("disabled", !0)
		},
		st.setValue = function (e, n, i, o) {
			st.temp = t.isArray(e) ? e.slice(0) : ut.parseValue.call(dt, e + "", st),
			B(n, i, !1, o)
		},
		st.getValue = function () {
			return st.values
		},
		st.getValues = function () {
			var t,
			e = [];
			for (t in st._selectedValues)
				e.push(st._selectedValues[t]);
			return e
		},
		st.changeWheel = function (e, n) {
			if (j) {
				var i = 0,
				o = e.length;
				t.each(ut.wheels, function (a, r) {
					if (t.each(r, function (a, r) {
							if (-1 < t.inArray(i, e) && (vt[i] = r, t(".dw-ul", j).eq(i).html(h(i)), !--o))
								return st.position() , A(n, void 0, !0), !1;
								i++
							}), !o)return !1
				})
			}
		},
		st.isVisible = function () {
			return wt
		},
		st.tap = function (t, e) {
			var n,
			i;
			ut.tap && t.on("touchstart.dw", function (t) {
				t.preventDefault(),
				n = o(t, "X"),
				i = o(t, "Y")
			}).on("touchend.dw", function (t) {
				20 > Math.abs(o(t, "X") - n) && 20 > Math.abs(o(t, "Y") - i) && e.call(this, t),
				l = !0,
				setTimeout(function () {
					l = !1
				}, 300)
			}),
			t.on("click.dw", function (t) {
				l || e.call(this, t)
			})
		},
		st.show = function (e) {
			if (ut.disabled || wt)
				return !1;
			"top" == ut.display && (W = "slidedown"),
			"bottom" == ut.display && (W = "slideup"),
			C(),
			D("onBeforeShow", []);
			var n,
			i = 0,
			o = "";
			W && !e && (o = "dw-" + W + " dw-in");
			var a = '<div role="dialog" class="' + ut.theme + " dw-" + ut.display + (g ? " dw" + g : "") + '">' + ("inline" == ut.display ? '<div class="dw dwbg dwi"><div class="dwwr">' : '<div class="dw-persp"><div class="dwo"></div><div class="dw dwbg ' + o + '"><div class="dw-arrw"><div class="dw-arrw-i"><div class="dw-arr"></div></div></div><div class="dwwr"><div aria-live="assertive" class="dwv' + (ut.headerText ? "" : " dw-hidden") + '"></div>') + '<div class="dwcc">';
			t.each(ut.wheels, function (e, o) {
				a += '<div class="dwc' + ("scroller" != ut.mode ? " dwpm" : " dwsc") + (ut.showLabel ? "" : " dwhl") + '"><div class="dwwc dwrc"><table cellpadding="0" cellspacing="0"><tr>',
				t.each(o, function (t, e) {
					vt[i] = e,
					n = void 0 !== e.label ? e.label : t,
					a += '<td><div class="dwwl dwrc dwwl' + i + '">' + ("scroller" != ut.mode ? '<div class="dwb-e dwwb dwwbp" style="height:' + O + "px;line-height:" + O + 'px;"><span>+</span></div><div class="dwb-e dwwb dwwbm" style="height:' + O + "px;line-height:" + O + 'px;"><span>&ndash;</span></div>' : "") + '<div class="dwl">' + n + '</div><div tabindex="0" aria-live="off" aria-label="' + n + '" role="listbox" class="dwww"><div class="dww" style="height:' + ut.rows * O + "px;min-width:" + ut.width + 'px;"><div class="dw-ul">',
					a += h(i),
					a += '</div><div class="dwwol"></div></div><div class="dwwo"></div></div><div class="dwwol"></div></div></td>',
					i++
				}),
				a += "</tr></table></div></div>"
			}),
			a += "</div>" + ("inline" != ut.display ? '<div class="dwbc' + (ut.button3 ? " dwbc-p" : "") + '"><span class="dwbw dwb-s"><span class="dwb dwb-e" role="button" tabindex="0">' + ut.setText + "</span></span>" + (ut.button3 ? '<span class="dwbw dwb-n"><span class="dwb dwb-e" role="button" tabindex="0">' + ut.button3Text + "</span></span>" : "") + '<span class="dwbw dwb-c"><span class="dwb dwb-e" role="button" tabindex="0">' + ut.cancelText + "</span></span></div></div>" : "") + "</div></div></div>",
			j = t(a),
			A(),
			D("onMarkupReady", [j]),
			"inline" != ut.display ? (j.appendTo("body"), W && !e && (j.addClass("dw-trans"), setTimeout(function () {
						j.removeClass("dw-trans").find(".dw").removeClass(o)
					}, 350))) : ct.is("div") ? ct.html(j) : j.insertAfter(ct),
			D("onMarkupInserted", [j]),
			wt = !0,
			R.init(j, st),
			"inline" != ut.display && (st.tap(t(".dwb-s span", j), function () {
					st.select()
				}), st.tap(t(".dwb-c span", j), function () {
					st.cancel()
				}), ut.button3 && st.tap(t(".dwb-n span", j), ut.button3), t(window).on("keydown.dw", function (t) {
					13 == t.keyCode ? st.select() : 27 == t.keyCode && st.cancel()
				}), ut.scrollLock && j.on("touchmove touchstart", function (t) {
					N && t.preventDefault()
				}), t("input,select,button").each(function () {
					this.disabled || (t(this).attr("autocomplete") && t(this).data("autocomplete", t(this).attr("autocomplete")), t(this).addClass("dwtd").prop("disabled", !0).attr("autocomplete", "off"))
				}), st.position(), t(window).on("orientationchange.dw resize.dw scroll.dw", function (t) {
					clearTimeout(q),
					q = setTimeout(function () {
							var e = "scroll" == t.type;
							(e && N || !e) && st.position(!e)
						}, 100)
				}), st.alert(ut.ariaDesc)),
			t(".dwwl", j).on("DOMMouseScroll mousewheel", St).on(b, yt).on("keydown", Ct).on("keyup", Tt),
			j.on(b, ".dwb-e", kt).on("keydown", ".dwb-e", function (e) {
				32 == e.keyCode && (e.preventDefault(), e.stopPropagation(), t(this).click())
			}),
			D("onShow", [j, U])
		},
		st.hide = function (e, n) {
			if (!wt || !1 === D("onClose", [U, n]))
				return !1;
			t(".dwtd").each(function () {
				t(this).prop("disabled", !1).removeClass("dwtd"),
				t(this).data("autocomplete") ? t(this).attr("autocomplete", t(this).data("autocomplete")) : t(this).removeAttr("autocomplete")
			}),
			j && ("inline" != ut.display && W && !e ? (j.addClass("dw-trans").find(".dw").addClass("dw-" + W + " dw-out"), setTimeout(function () {
						j.remove(),
						j = null
					}, 350)) : (j.remove(), j = null), t(window).off(".dw")),
			mt = {},
			wt = !1,
			rt = !0,
			ct.trigger("focus")
		},
		st.select = function () {
			!1 !== st.hide(!1, "set") && (B(!0, 0, !0), D("onSelect", [st.val]))
		},
		st.alert = function (t) {
			u.text(t),
			clearTimeout(c),
			c = setTimeout(function () {
					u.text("")
				}, 5e3)
		},
		st.cancel = function () {
			!1 !== st.hide(!1, "cancel") && D("onCancel", [st.val])
		},
		st.init = function (t) {
			R = y({
					defaults: {},
					init: p
				}, lt.themes[t.theme || ut.theme]),
			_ = lt.i18n[t.lang || ut.lang],
			y(n, t),
			y(ut, R.defaults, _, n),
			st.settings = ut,
			ct.off(".dw"),
			(t = lt.presets[ut.preset]) && (ht = t.call(dt, st), y(ut, ht, n)),
			L = Math.floor(ut.rows / 2),
			O = ut.height,
			W = ut.animate,
			wt && st.hide(),
			"inline" == ut.display ? st.show() : (C(), gt && (void 0 === at && (at = dt.readOnly), dt.readOnly = !0, ut.showOnFocus) && ct.on("focus.dw", function () {
					rt || st.show(),
					rt = !1
				}), ut.showOnTap && st.tap(ct, function () {
					st.show()
				}))
		},
		st.trigger = function (t, e) {
			return D(t, e)
		},
		st.option = function (t, e) {
			var n = {};
			"object" == typeof t ? n = t : n[t] = e,
			st.init(n)
		},
		st.destroy = function () {
			st.hide(),
			ct.off(".dw"),
			delete f[dt.id],
			gt && (dt.readOnly = at)
		},
		st.getInst = function () {
			return st
		},
		st.values = null,
		st.val = null,
		st.temp = null,
		st._selectedValues = {},
		st.init(n)
	}
	function n(t) {
		for (var e in t)
			if (void 0 !== m[t[e]])
				return !0;
		return !1
	}
	function i(t) {
		if ("touchstart" === t.type)
			d = !0;
		else if (d)
			return d = !1;
		return !0
	}
	function o(t, e) {
		var n = t.originalEvent,
		i = t.changedTouches;
		return i || n && n.changedTouches ? n ? n.changedTouches[0]["page" + e] : i[0]["page" + e] : t["page" + e]
	}
	function a(e) {
		var n = {
			values: [],
			keys: []
		};
		return t.each(e, function (t, e) {
			n.keys.push(t),
			n.values.push(e)
		}),
		n
	}
	function r(t, n, i) {
		var o = t;
		return "object" == typeof n ? t.each(function () {
			this.id || (h += 1, this.id = "mobiscroll" + h),
			f[this.id] = new e(this, n)
		}) : ("string" == typeof n && t.each(function () {
				var t;
				if ((t = f[this.id]) && t[n] && void 0 !== (t = t[n].apply(this, Array.prototype.slice.call(i, 1))))
					return o = t, !1
			}), o)
	}
	var s,
	l,
	d,
	c,
	u,
	h = (new Date).getTime(),
	f = {},
	p = function () {},
	m = document.createElement("modernizr").style,
	v = n(["perspectiveProperty", "WebkitPerspective", "MozPerspective", "OPerspective", "msPerspective"]),
	g = function () {
		var t,
		e = ["Webkit", "Moz", "O", "ms"];
		for (t in e)
			if (n([e[t] + "Transform"]))
				return "-" + e[t].toLowerCase();
		return ""
	}
	(),
	w = g.replace(/^\-/, "").replace("moz", "Moz"),
	y = t.extend,
	b = "touchstart mousedown",
	$ = "touchmove mousemove",
	k = "touchend mouseup",
	x = {
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
		speedUnit: .0012,
		timeUnit: .1,
		formatResult: function (t) {
			return t.join(" ")
		},
		parseValue: function (e, n) {
			var i,
			o = e.split(" "),
			r = [],
			s = 0;
			return t.each(n.settings.wheels, function (e, n) {
				t.each(n, function (e, n) {
					n = n.values ? n : a(n),
					i = n.keys || n.values,
					-1 !== t.inArray(o[s], i) ? r.push(o[s]) : r.push(i[0]),
					s++
				})
			}),
			r
		}
	};
	t(function () {
		u = t('<div class="dw-hidden" role="alert"></div>').appendTo("body")
	}),
	t(document).on("mouseover mouseup mousedown click", function (t) {
		if (l)
			return t.stopPropagation(), t.preventDefault(), !1
	}),
	t.fn.mobiscroll = function (e) {
		return y(this, t.mobiscroll.shorts),
		r(this, e, arguments)
	},
	t.mobiscroll = t.mobiscroll || {
		setDefaults: function (t) {
			y(x, t)
		},
		presetShort: function (t) {
			this.shorts[t] = function (e) {
				return r(this, y(e, {
						preset: t
					}), arguments)
			}
		},
		has3d: v,
		shorts: {},
		presets: {},
		themes: {},
		i18n: {}
	},
	t.scroller = t.scroller || t.mobiscroll,
	t.fn.scroller = t.fn.scroller || t.fn.mobiscroll
}
(jQuery), function (t) {
	var e = t.mobiscroll,
	n = new Date,
	i = {
		dateFormat: "mm/dd/yy",
		dateOrder: "mmddy",
		timeWheels: "hhiiA",
		timeFormat: "hh:ii A",
		startYear: n.getFullYear() - 100,
		endYear: n.getFullYear() + 1,
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
		ampmText: "&nbsp;",
		nowText: "Now",
		showNow: !1,
		stepHour: 1,
		stepMinute: 1,
		stepSecond: 1,
		separator: " "
	},
	o = function (n) {
		function o(t, e, n) {
			return void 0 !== b[e] ? +t[b[e]] : void 0 !== n ? n : M[$[e]] ? M[$[e]]() : $[e](M)
		}
		function a(t, e, n, i) {
			t.push({
				values: n,
				keys: e,
				label: i
			})
		}
		function r(t, e) {
			return Math.floor(t / e) * e
		}
		function s(t) {
			var e = o(t, "h", 0);
			return new Date(o(t, "y"), o(t, "m"), o(t, "d", 1), o(t, "a") ? e + 12 : e, o(t, "i", 0), o(t, "s", 0))
		}
		var l,
		d = {};
		if ((u = t(this)).is("input")) {
			switch (u.attr("type")) {
			case "date":
				l = "yy-mm-dd";
				break;
			case "datetime":
				l = "yy-mm-ddTHH:ii:ssZ";
				break;
			case "datetime-local":
				l = "yy-mm-ddTHH:ii:ss";
				break;
			case "month":
				l = "yy-mm",
				d.dateOrder = "mmyy";
				break;
			case "time":
				l = "HH:ii:ss"
			}
			var c = u.attr("min"),
			u = u.attr("max");
			c && (d.minDate = e.parseDate(l, c)),
			u && (d.maxDate = e.parseDate(l, u))
		}
		c = t.extend({}, n.settings);
		var h,
		f,
		p,
		m,
		v,
		g = t.extend(n.settings, i, d, c),
		w = 0,
		y = (u = [], []),
		b = {},
		$ = {
			y: "getFullYear",
			m: "getMonth",
			d: "getDate",
			h: function (t) {
				return t = t.getHours(),
				r(t = A && 12 <= t ? t - 12 : t, E)
			},
			i: function (t) {
				return r(t.getMinutes(), P)
			},
			s: function (t) {
				return r(t.getSeconds(), B)
			},
			a: function (t) {
				return S && 11 < t.getHours() ? 1 : 0
			}
		},
		k = g.preset,
		x = g.dateOrder,
		C = g.timeWheels,
		T = x.match(/D/),
		S = C.match(/a/i),
		A = C.match(/h/),
		D = "datetime" == k ? g.dateFormat + g.separator + g.timeFormat : "time" == k ? g.timeFormat : g.dateFormat,
		M = new Date,
		E = g.stepHour,
		P = g.stepMinute,
		B = g.stepSecond,
		L = g.minDate || new Date(g.startYear, 0, 1),
		O = g.maxDate || new Date(g.endYear, 11, 31, 23, 59, 59);
		if (l = l || D, k.match(/date/i)) {
			for (t.each(["y", "m", "d"], function (t, e) {
					-1 < (h = x.search(RegExp(e, "i"))) && y.push({
						o: h,
						v: e
					})
				}), y.sort(function (t, e) {
					return t.o > e.o ? 1 : -1
				}), t.each(y, function (t, e) {
					b[e.v] = t
				}), c = [], d = 0; 3 > d; d++)
				if (d == b.y) {
					for (w++, p = [], f = [], m = L.getFullYear(), v = O.getFullYear(), h = m; h <= v; h++)
						f.push(h), p.push(x.match(/yy/i) ? h : (h + "").substr(2, 2));
					a(c, f, p, g.yearText)
				} else if (d == b.m) {
					for (w++, p = [], f = [], h = 0; 12 > h; h++)
						m = x.replace(/[dy]/gi, "").replace(/mm/, 9 > h ? "0" + (h + 1) : h + 1).replace(/m/, h + 1), f.push(h), p.push(m.match(/MM/) ? m.replace(/MM/, '<span class="dw-mon">' + g.monthNames[h] + "</span>") : m.replace(/M/, '<span class="dw-mon">' + g.monthNamesShort[h] + "</span>"));
					a(c, f, p, g.monthText)
				} else if (d == b.d) {
					for (w++, p = [], f = [], h = 1; 32 > h; h++)
						f.push(h), p.push(x.match(/dd/i) && 10 > h ? "0" + h : h);
					a(c, f, p, g.dayText)
				}
			u.push(c)
		}
		if (k.match(/time/i)) {
			for (y = [], t.each(["h", "i", "s", "a"], function (t, e) {
					-1 < (t = C.search(RegExp(e, "i"))) && y.push({
						o: t,
						v: e
					})
				}), y.sort(function (t, e) {
					return t.o > e.o ? 1 : -1
				}), t.each(y, function (t, e) {
					b[e.v] = w + t
				}), c = [], d = w; d < w + 4; d++)
				if (d == b.h) {
					for (w++, p = [], f = [], h = 0; h < (A ? 12 : 24); h += E)
						f.push(h), p.push(A && 0 == h ? 12 : C.match(/hh/i) && 10 > h ? "0" + h : h);
					a(c, f, p, g.hourText)
				} else if (d == b.i) {
					for (w++, p = [], f = [], h = 0; 60 > h; h += P)
						f.push(h), p.push(C.match(/ii/) && 10 > h ? "0" + h : h);
					a(c, f, p, g.minuteText)
				} else if (d == b.s) {
					for (w++, p = [], f = [], h = 0; 60 > h; h += B)
						f.push(h), p.push(C.match(/ss/) && 10 > h ? "0" + h : h);
					a(c, f, p, g.secText)
				} else
					d == b.a && (w++, f = C.match(/A/), a(c, [0, 1], f ? ["AM", "PM"] : ["am", "pm"], g.ampmText));
			u.push(c)
		}
		return n.setDate = function (t, e, i, o) {
			for (var a in b)
				n.temp[b[a]] = t[$[a]] ? t[$[a]]() : $[a](t);
			n.setValue(n.temp, e, i, o)
		},
		n.getDate = function (t) {
			return s(t ? n.temp : n.values)
		}, {
			button3Text: g.showNow ? g.nowText : void 0,
			button3: g.showNow ? function () {
				n.setDate(new Date, !1, .3, !0)
			}
			 : void 0,
			wheels: u,
			headerText: function (t) {
				return e.formatDate(D, s(n.temp), g)
			},
			formatResult: function (t) {
				return e.formatDate(l, s(t), g)
			},
			parseValue: function (t) {
				var n,
				i = new Date,
				o = [];
				try {
					i = e.parseDate(l, t, g)
				} catch (t) {}
				for (n in b)
					o[b[n]] = i[$[n]] ? i[$[n]]() : $[n](i);
				return o
			},
			validate: function (e, i) {
				var a = n.temp,
				s = {
					y: L.getFullYear(),
					m: 0,
					d: 1,
					h: 0,
					i: 0,
					s: 0,
					a: 0
				},
				l = {
					y: O.getFullYear(),
					m: 11,
					d: 31,
					h: r(A ? 11 : 23, E),
					i: r(59, P),
					s: r(59, B),
					a: 1
				},
				d = !0,
				c = !0;
				t.each("ymdahis".split(""), function (n, i) {
					if (void 0 !== b[i]) {
						var r,
						u,
						h = s[i],
						f = l[i],
						p = 31,
						m = o(a, i),
						v = t(".dw-ul", e).eq(b[i]);
						if ("d" == i && (r = o(a, "y"), u = o(a, "m"), f = p = 32 - new Date(r, u, 32).getDate(), T && t(".dw-li", v).each(function () {
									var e = t(this),
									n = e.data("val"),
									i = new Date(r, u, n).getDay();
									n = x.replace(/[my]/gi, "").replace(/dd/, 10 > n ? "0" + n : n).replace(/d/, n);
									t(".dw-i", e).html(n.match(/DD/) ? n.replace(/DD/, '<span class="dw-day">' + g.dayNames[i] + "</span>") : n.replace(/D/, '<span class="dw-day">' + g.dayNamesShort[i] + "</span>"))
								})), d && L && (h = L[$[i]] ? L[$[i]]() : $[i](L)), c && O && (f = O[$[i]] ? O[$[i]]() : $[i](O)), "y" != i) {
							var w = t(".dw-li", v).index(t('.dw-li[data-val="' + h + '"]', v)),
							y = t(".dw-li", v).index(t('.dw-li[data-val="' + f + '"]', v));
							t(".dw-li", v).removeClass("dw-v").slice(w, y + 1).addClass("dw-v"),
							"d" == i && t(".dw-li", v).removeClass("dw-h").slice(p).addClass("dw-h")
						}
						if (m < h && (m = h), m > f && (m = f), d && (d = m == h), c && (c = m == f), g.invalid && "d" == i) {
							var k = [];
							if (g.invalid.dates && t.each(g.invalid.dates, function (t, e) {
									e.getFullYear() == r && e.getMonth() == u && k.push(e.getDate() - 1)
								}), g.invalid.daysOfWeek) {
								var C,
								S = new Date(r, u, 1).getDay();
								t.each(g.invalid.daysOfWeek, function (t, e) {
									for (C = e - S; C < p; C += 7)
										0 <= C && k.push(C)
								})
							}
							g.invalid.daysOfMonth && t.each(g.invalid.daysOfMonth, function (t, e) {
								(e = (e + "").split("/"))[1] ? e[0] - 1 == u && k.push(e[1] - 1) : k.push(e[0] - 1)
							}),
							t.each(k, function (e, n) {
								t(".dw-li", v).eq(n).removeClass("dw-v")
							})
						}
						a[b[i]] = m
					}
				})
			}
		}
	};
	t.each(["date", "time", "datetime"], function (t, n) {
		e.presets[n] = o,
		e.presetShort(n)
	}),
	e.formatDate = function (e, n, o) {
		if (!n)
			return null;
		o = t.extend({}, i, o);
		var a,
		r = function (t) {
			for (var n = 0; a + 1 < e.length && e.charAt(a + 1) == t; )
				n++, a++;
			return n
		},
		s = function (t, e, n) {
			if (e = "" + e, r(t))
				for (; e.length < n; )
					e = "0" + e;
			return e
		},
		l = function (t, e, n, i) {
			return r(t) ? i[e] : n[e]
		},
		d = "",
		c = !1;
		for (a = 0; a < e.length; a++)
			if (c)
				"'" != e.charAt(a) || r("'") ? d += e.charAt(a) : c = !1;
			else
				switch (e.charAt(a)) {
				case "d":
					d += s("d", n.getDate(), 2);
					break;
				case "D":
					d += l("D", n.getDay(), o.dayNamesShort, o.dayNames);
					break;
				case "o":
					d += s("o", (n.getTime() - new Date(n.getFullYear(), 0, 0).getTime()) / 864e5, 3);
					break;
				case "m":
					d += s("m", n.getMonth() + 1, 2);
					break;
				case "M":
					d += l("M", n.getMonth(), o.monthNamesShort, o.monthNames);
					break;
				case "y":
					d += r("y") ? n.getFullYear() : (10 > n.getYear() % 100 ? "0" : "") + n.getYear() % 100;
					break;
				case "h":
					var u = n.getHours();
					d = d + s("h", 12 < u ? u - 12 : 0 == u ? 12 : u, 2);
					break;
				case "H":
					d += s("H", n.getHours(), 2);
					break;
				case "i":
					d += s("i", n.getMinutes(), 2);
					break;
				case "s":
					d += s("s", n.getSeconds(), 2);
					break;
				case "a":
					d += 11 < n.getHours() ? "pm" : "am";
					break;
				case "A":
					d += 11 < n.getHours() ? "PM" : "AM";
					break;
				case "'":
					r("'") ? d += "'" : c = !0;
					break;
				default:
					d += e.charAt(a)
				}
		return d
	},
	e.parseDate = function (e, n, o) {
		var a = new Date;
		if (!e || !n)
			return a;
		n = "object" == typeof n ? n.toString() : n + "";
		var r = t.extend({}, i, o),
		s = r.shortYearCutoff;
		o = a.getFullYear();
		var l,
		d = a.getMonth() + 1,
		c = a.getDate(),
		u = -1,
		h = a.getHours(),
		f = (a = a.getMinutes(), 0),
		p = -1,
		m = !1,
		v = function (t) {
			return (t = l + 1 < e.length && e.charAt(l + 1) == t) && l++,
			t
		},
		g = function (t) {
			return v(t),
			t = RegExp("^\\d{1," + ("@" == t ? 14 : "!" == t ? 20 : "y" == t ? 4 : "o" == t ? 3 : 2) + "}"),
			(t = n.substr(y).match(t)) ? (y += t[0].length, parseInt(t[0], 10)) : 0
		},
		w = function (t, e, i) {
			for (t = v(t) ? i : e, e = 0; e < t.length; e++)
				if (n.substr(y, t[e].length).toLowerCase() == t[e].toLowerCase())
					return y += t[e].length, e + 1;
			return 0
		},
		y = 0;
		for (l = 0; l < e.length; l++)
			if (m)
				"'" != e.charAt(l) || v("'") ? y++ : m = !1;
			else
				switch (e.charAt(l)) {
				case "d":
					c = g("d");
					break;
				case "D":
					w("D", r.dayNamesShort, r.dayNames);
					break;
				case "o":
					u = g("o");
					break;
				case "m":
					d = g("m");
					break;
				case "M":
					d = w("M", r.monthNamesShort, r.monthNames);
					break;
				case "y":
					o = g("y");
					break;
				case "H":
					h = g("H");
					break;
				case "h":
					h = g("h");
					break;
				case "i":
					a = g("i");
					break;
				case "s":
					f = g("s");
					break;
				case "a":
					p = w("a", ["am", "pm"], ["am", "pm"]) - 1;
					break;
				case "A":
					p = w("A", ["am", "pm"], ["am", "pm"]) - 1;
					break;
				case "'":
					v("'") ? y++ : m = !0;
					break;
				default:
					y++
				}
		if (100 > o && (o += (new Date).getFullYear() - (new Date).getFullYear() % 100 + (o <= ("string" != typeof s ? s : (new Date).getFullYear() % 100 + parseInt(s, 10)) ? 0 : -100)), -1 < u)
			for (d = 1, c = u; ; ) {
				if (c <= (r = 32 - new Date(o, d - 1, 32).getDate()))
					break;
				d++,
				c -= r
			}
		if ((h = new Date(o, d - 1, c, -1 == p ? h : p && 12 > h ? h + 12 : p || 12 != h ? h : 0, a, f)).getFullYear() != o || h.getMonth() + 1 != d || h.getDate() != c)
			throw "Invalid date";
		return h
	}
}
(jQuery), function (t) {
	var e = t.mobiscroll,
	n = {
		invalid: [],
		showInput: !0,
		inputClass: ""
	},
	i = function (e) {
		function i(e, n, i, a) {
			for (var r = 0; r < n; ) {
				var s = t(".dwwl" + r, e),
				l = o(a, r, i);
				t.each(l, function (e, n) {
					t('.dw-li[data-val="' + n + '"]', s).removeClass("dw-v")
				}),
				r++
			}
		}
		function o(t, e, n) {
			for (var i, o = 0, a = []; o < e; ) {
				var r = t[o];
				for (i in n)
					if (n[i].key == r) {
						n = n[i].children;
						break
					}
				o++
			}
			for (o = 0; o < n.length; )
				n[o].invalid && a.push(n[o].key), o++;
			return a
		}
		function a(t, e, n) {
			var i,
			o,
			a = 0,
			s = [],
			l = g;
			if (e)
				for (i = 0; i < e; i++)
					s[i] = [{}
					];
			for (; a < t.length; ) {
				i = s,
				e = a;
				for (var d = l, c = {
						keys: [],
						values: [],
						label: w[a]
					}, u = 0; u < d.length; )
					c.values.push(d[u].value), c.keys.push(d[u].key), u++;
				for (i[e] = [c], i = 0, e = void 0; i < l.length && void 0 === e; )
					l[i].key == t[a] && (void 0 !== n && a <= n || void 0 === n) && (e = i), i++;
				if (void 0 !== e && l[e].children)
					a++, l = l[e].children;
				else {
					if (!(o = r(l)) || !o.children)
						break;
					a++,
					l = o.children
				}
			}
			return s
		}
		function r(t, e) {
			if (!t)
				return !1;
			for (var n, i = 0; i < t.length; )
				if (!(n = t[i++]).invalid)
					return e ? i - 1 : n;
			return !1
		}
		function s(e, n) {
			t(".dwc", e).css("display", "").slice(n).hide()
		}
		function l(t, e) {
			var n,
			i,
			o = [],
			a = g,
			s = 0,
			l = !1;
			if (void 0 !== t[s] && s <= e)
				for (l = 0, n = t[s], i = void 0; l < a.length && void 0 === i; )
					a[l].key == t[s] && !a[l].invalid && (i = l), l++;
			else
				i = r(a, !0), n = a[i].key;
			for (l = void 0 !== i && a[i].children, o[s] = n; l; ) {
				if (a = a[i].children, void 0 !== t[++s] && s <= e)
					for (l = 0, n = t[s], i = void 0; l < a.length && void 0 === i; )
						a[l].key == t[s] && !a[l].invalid && (i = l), l++;
				else
					i = r(a, !0), i = !1 === i ? void 0 : i, n = a[i].key;
				l = !(void 0 === i || !r(a[i].children)) && a[i].children,
				o[s] = n
			}
			return {
				lvl: s + 1,
				nVector: o
			}
		}
		var d,
		c,
		u = t.extend({}, e.settings),
		h = t.extend(e.settings, n, u),
		f = (u = t(this), this.id + "_dummy"),
		p = 0,
		m = 0,
		v = {},
		g = h.wheelArray || function e(n) {
			var i = [];
			return p = p > m++ ? p : m,
			n.children("li").each(function (n) {
				var o = t(this);
				(a = o.clone()).children("ul,ol").remove();
				var a = a.html().replace(/^\s\s*/, "").replace(/\s\s*$/, ""),
				r = !!o.data("invalid");
				n = {
					key: o.data("val") || n,
					value: a,
					invalid: r,
					children: null
				},
				(o = o.children("ul,ol")).length && (n.children = e(o)),
				i.push(n)
			}),
			m--,
			i
		}
		(u),
		w = function (t) {
			var e,
			n = [];
			for (e = 0; e < t; e++)
				n[e] = h.labels && h.labels[e] ? h.labels[e] : e;
			return n
		}
		(p),
		y = [],
		b = a(b = function (t) {
				for (var e, n = [], i = !0, o = 0; i; )
					e = r(t), n[o++] = e.key, (i = e.children) && (t = e.children);
				return n
			}
				(g), p);
		return t("#" + f).remove(),
		h.showInput && (d = t('<input type="text" id="' + f + '" value="" class="' + h.inputClass + '" readonly />').insertBefore(u), e.settings.anchor = d, h.showOnFocus && d.focus(function () {
				e.show()
			}), h.showOnTap && e.tap(d, function () {
				e.show()
			})),
		h.wheelArray || u.hide().closest(".ui-field-contain").trigger("create"), {
			width: 50,
			wheels: b,
			headerText: !1,
			onBeforeShow: function (t) {
				t = e.temp,
				y = t.slice(0),
				e.settings.wheels = a(t, p, p),
				c = !0
			},
			onSelect: function (t, e) {
				d && d.val(t)
			},
			onChange: function (t, e) {
				d && "inline" == h.display && d.val(t)
			},
			onClose: function () {
				d && d.blur()
			},
			onShow: function (e) {
				t(".dwwl", e).on("mousedown touchstart", function () {
					clearTimeout(v[t(".dwwl", e).index(this)])
				})
			},
			validate: function (t, n, o) {
				var r = e.temp;
				if (void 0 !== n && y[n] != r[n] || void 0 === n && !c) {
					e.settings.wheels = a(r, null, n);
					var d = [],
					u = (n || 0) + 1,
					h = l(r, n);
					for (void 0 !== n && (e.temp = h.nVector.slice(0)); u < h.lvl; )
						d.push(u++);
					if (s(t, h.lvl), y = e.temp.slice(0), d.length)
						return c = !0, e.settings.readonly = function (t, e) {
							for (var n = []; t; )
								n[--t] = !0;
							return n[e] = !1,
							n
						}
					(p, n),
					clearTimeout(v[n]),
					v[n] = setTimeout(function () {
							e.changeWheel(d),
							e.settings.readonly = !1
						}, 1e3 * o),
					!1;
					i(t, h.lvl, g, e.temp)
				} else
					h = l(r, r.length), i(t, h.lvl, g, r), s(t, h.lvl);
				c = !1
			}
		}
	};
	t.each(["list", "image", "treelist"], function (t, n) {
		e.presets[n] = i,
		e.presetShort(n)
	})
}
(jQuery), function (t) {
	var e = {
		inputClass: "",
		invalid: [],
		rtl: !1,
		group: !1,
		groupLabel: "Groups"
	};
	t.mobiscroll.presetShort("select"),
	t.mobiscroll.presets.select = function (n) {
		function i() {
			var e,
			n = 0,
			i = [],
			o = [],
			a = [[]];
			return l.group ? (l.rtl && (n = 1), t("optgroup", d).each(function (e) {
					i.push(t(this).attr("label")),
					o.push(e)
				}), a[n] = [{
						values: i,
						keys: o,
						label: l.groupLabel
					}
				], e = h, n += l.rtl ? -1 : 1) : e = d,
			i = [],
			o = [],
			t("option", e).each(function () {
				var e = t(this).attr("value");
				i.push(t(this).text()),
				o.push(e),
				t(this).prop("disabled") && $.push(e)
			}),
			a[n] = [{
					values: i,
					keys: o,
					label: b
				}
			],
			a
		}
		function o(t, e) {
			var i = [];
			if (c) {
				var o = [],
				a = 0;
				for (a in n._selectedValues)
					o.push(x[a]), i.push(a);
				w.val(o.join(", "))
			} else
				w.val(t), i = e ? n.values[v] : null;
			e && (r = !0, d.val(i).trigger("change"))
		}
		function a(t) {
			if (c && t.hasClass("dw-v") && t.closest(".dw").find(".dw-ul").index(t.closest(".dw-ul")) == v) {
				var e = t.attr("data-val");
				return t.hasClass("dw-msel") ? (t.removeClass("dw-msel").removeAttr("aria-selected"), delete n._selectedValues[e]) : (t.addClass("dw-msel").attr("aria-selected", "true"), n._selectedValues[e] = e),
				"inline" == l.display && o(e, !0),
				!1
			}
		}
		var r,
		s = t.extend({}, n.settings),
		l = t.extend(n.settings, e, s),
		d = t(this),
		c = d.prop("multiple"),
		u = (s = this.id + "_dummy", c ? d.val() ? d.val()[0] : t("option", d).attr("value") : d.val()),
		h = d.find('option[value="' + u + '"]').parent(),
		f = h.index() + "",
		p = f;
		t('label[for="' + this.id + '"]').attr("for", s);
		var m,
		v,
		g,
		w,
		y = t('label[for="' + s + '"]'),
		b = void 0 !== l.label ? l.label : y.length ? y.text() : d.attr("name"),
		$ = [],
		k = [],
		x = {},
		C = l.readonly;
		for (l.group && !t("optgroup", d).length && (l.group = !1), l.invalid.length || (l.invalid = $), l.group ? l.rtl ? (m = 1, v = 0) : (m = 0, v = 1) : (m = -1, v = 0), t("#" + s).remove(), w = t('<input type="text" id="' + s + '" class="' + l.inputClass + '" readonly />').insertBefore(d), t("option", d).each(function () {
				x[t(this).attr("value")] = t(this).text()
			}), l.showOnFocus && w.focus(function () {
				n.show()
			}), l.showOnTap && n.tap(w, function () {
				n.show()
			}), s = d.val() || [], y = 0; y < s.length; y++)
			n._selectedValues[s[y]] = s[y];
		return o(x[u]),
		d.off(".dwsel").on("change.dwsel", function () {
			r || n.setValue(c ? d.val() || [] : [d.val()], !0),
			r = !1
		}).hide().closest(".ui-field-contain").trigger("create"),
		n._setValue || (n._setValue = n.setValue),
		n.setValue = function (e, a, r, s, m) {
			var g = t.isArray(e) ? e[0] : e;
			if (u = void 0 !== g ? g : t("option", d).attr("value"), c)
				for (n._selectedValues = {}, g = 0; g < e.length; g++)
					n._selectedValues[e[g]] = e[g];
			l.group ? (h = d.find('option[value="' + u + '"]').parent(), p = h.index(), e = l.rtl ? [u, h.index()] : [h.index(), u], p !== f && (l.wheels = i(), n.changeWheel([v]), f = p + "")) : e = [u],
			n._setValue(e, a, r, s, m),
			a && (a = !!c || u !== d.val(), o(x[u], a))
		},
		n.getValue = function (t) {
			return (t ? n.temp : n.values)[v]
		}, {
			width: 50,
			wheels: void 0,
			headerText: !1,
			multiple: c,
			anchor: w,
			formatResult: function (t) {
				return x[t[v]]
			},
			parseValue: function () {
				var e = d.val() || [],
				i = 0;
				if (c)
					for (n._selectedValues = {}; i < e.length; i++)
						n._selectedValues[e[i]] = e[i];
				return u = c ? d.val() ? d.val()[0] : t("option", d).attr("value") : d.val(),
				h = d.find('option[value="' + u + '"]').parent(),
				p = h.index(),
				f = p + "",
				l.group && l.rtl ? [u, p] : l.group ? [p, u] : [u]
			},
			validate: function (e, o, a) {
				if (void 0 === o && c) {
					var r = n._selectedValues,
					s = 0;
					t(".dwwl" + v + " .dw-li", e).removeClass("dw-msel").removeAttr("aria-selected");
					for (s in r)
						t(".dwwl" + v + ' .dw-li[data-val="' + r[s] + '"]', e).addClass("dw-msel").attr("aria-selected", "true")
				}
				if (o === m)
					if (p = n.temp[m], p !== f) {
						if (h = d.find("optgroup").eq(p), p = h.index(), u = (u = h.find("option").eq(0).val()) || d.val(), l.wheels = i(), l.group)
							return n.temp = l.rtl ? [u, p] : [p, u], l.readonly = [l.rtl, !l.rtl], clearTimeout(g), g = setTimeout(function () {
									n.changeWheel([v]),
									l.readonly = C,
									f = p + ""
								}, 1e3 * a), !1
					} else
						l.readonly = C;
				else
					u = n.temp[v];
				var w = t(".dw-ul", e).eq(v);
				t.each(l.invalid, function (e, n) {
					t('.dw-li[data-val="' + n + '"]', w).removeClass("dw-v")
				})
			},
			onBeforeShow: function (t) {
				l.wheels = i(),
				l.group && (n.temp = l.rtl ? [u, h.index()] : [h.index(), u])
			},
			onMarkupReady: function (e) {
				if (t(".dwwl" + m, e).on("mousedown touchstart", function () {
						clearTimeout(g)
					}), c) {
					e.addClass("dwms"),
					t(".dwwl", e).eq(v).addClass("dwwms").attr("aria-multiselectable", "true"),
					t(".dwwl", e).on("keydown", function (e) {
						32 == e.keyCode && (e.preventDefault(), e.stopPropagation(), a(t(".dw-sel", this)))
					}),
					k = {};
					for (var i in n._selectedValues)
						k[i] = n._selectedValues[i]
				}
			},
			onValueTap: a,
			onSelect: function (t) {
				o(t, !0),
				l.group && (n.values = null)
			},
			onCancel: function () {
				if (l.group && (n.values = null), c) {
					n._selectedValues = {};
					for (var t in k)
						n._selectedValues[t] = k[t]
				}
			},
			onChange: function (t) {
				"inline" == l.display && !c && (w.val(t), r = !0, d.val(n.temp[v]).trigger("change"))
			},
			onClose: function () {
				w.blur()
			}
		}
	}
}
(jQuery), function (t) {
	var e = {
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
	t.mobiscroll.themes["android-ics"] = e,
	t.mobiscroll.themes["android-ics light"] = e
}
(jQuery);
