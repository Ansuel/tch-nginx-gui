const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const shared = fs.readFileSync('decompressed/gui_file/www/docroot/js/shared-script.js', 'utf8');
const script = shared.slice(shared.indexOf('    var resourceSamples'), shared.indexOf('\tmodule.postAction = postAction,'));
let request, refresh, observed;
let activeId = 'graphtab';
let activeCard = createCard();
const charts = {};
function createCard() {
    const elements = {};
    return {querySelector: selector => {
        const id = selector.match(/="([^"]+)"/)[1];
        return elements[id] || (elements[id] = {
            id, textContent: id, hidden: false, style: {},
            setAttribute(name, value) { this[name] = value; },
        });
    }};
}
const element = id => activeCard.querySelector('[data-resource="' + id + '"]');
const context = {
    document: {getElementById: id => id === activeId ? activeCard : null, body: {}},
    window: {MutationObserver: true, getComputedStyle: () => ({color: '#fff'})},
    MutationObserver: class {
        constructor(callback) { observed = callback; }
        observe() {}
        disconnect() {}
    },
    modgui: {createAjaxUpdateCard: (id, _, name, interval, next) => {
        assert.strictEqual(id, activeId);
        assert.strictEqual(name, id + 'ChartsInterval');
        assert.strictEqual(interval, 10000);
        refresh = next;
    }},
    Chart: function (canvas, config) {
        Object.assign(this, {
            data: config.data, options: config.options, resize() {}, update() {}, destroy() { this.destroyed = true; },
        });
        charts[canvas.id] = this;
    },
    tch: {elementCSRFtoken: () => ({name: 'CSRFtoken', value: 'test'})},
    get_bitrate: bytes => bytes * 8 + ' bit/s',
    $: Object.assign(value => {
        if (typeof value === 'function') return value();
        return {toggleClass: (_, hidden) => { value.hidden = hidden; }};
    }, {
        ajax: options => {
            request = options;
            assert.strictEqual(options.type, 'POST');
            assert.strictEqual(options.timeout, 8000);
            return request;
        },
    }),
};
context.module = context.modgui;
context.Chart.defaults = {global: {events: ['mousemove']}};
vm.runInNewContext(script, context);
context.modgui.initResourceCharts(activeId, false);
const points = (name, index = 0) => Array.from(charts[name].data.datasets[index].data, point => [point.x, point.y]);
const usage = 'resource-chart', wan = 'wan-chart';
const poll = () => {
    assert.strictEqual(refresh(), request);
    return new URL(request.url, 'http://router').searchParams;
};
const sample = (device, time, rate, cpu = 30) => ({
    time, interface: device, rx: rate, tx: rate, cpu, ram: 50,
    lan: true, lan_rx: rate && rate * 2, lan_tx: rate && rate * 3,
});

let query = poll();
assert.strictEqual(query.get('source'), 'wan');
assert.strictEqual(query.get('resources'), 'history');
assert.strictEqual(query.get('after'), null);
request.success({replace: true, samples: [
    {interface: 'eth4', time: 10, ram: 49},
    sample('eth4', 20, 100)
]});
assert.deepStrictEqual(points(usage), [[10, null], [20, 30]]);
assert.deepStrictEqual(points(usage, 1), [[10, 49], [20, 50]]);
assert.deepStrictEqual(points(wan), [[10, null], [20, 100]]);
assert.strictEqual(element('traffic-download').textContent, '800 bit/s');
assert.strictEqual(charts[usage].options.scales.xAxes[0].display, true);
assert.strictEqual(charts[usage].options.scales.xAxes[0].ticks.min, 10);
assert.strictEqual(charts[wan].options.scales.xAxes[0].ticks.min, 20);
assert.strictEqual(charts[wan].options.scales.xAxes[0].ticks.max, 20);
const singleAxis = charts[wan].options.scales.xAxes[0];
assert.deepStrictEqual(Array.from(singleAxis.afterBuildTicks({options: singleAxis, maxWidth: 380})), [20]);
const axis = charts[usage].options.scales.xAxes[0];
assert.deepStrictEqual(Array.from(axis.afterBuildTicks({options: axis, maxWidth: 220})), [10, 20]);
assert.deepStrictEqual(Array.from(axis.afterBuildTicks({options: axis, maxWidth: 380})), [10, 13, 17, 20]);
assert.strictEqual(element('rx-key').style.backgroundColor, '#379962');
assert.strictEqual(charts[wan].options.legend.display, false);
assert.strictEqual(poll().get('after'), '20');
request.success({replace: false, samples: []});
assert.deepStrictEqual(points(wan), [[10, null], [20, 100]]);

poll();
request.success({replace: false, samples: [sample('eth4', 30, undefined)]});
assert.deepStrictEqual(points(wan), [[10, null], [20, 100], [30, null]]);
poll();
request.success({replace: false, samples: [sample('eth4', 65, 99)]});
assert.deepStrictEqual(points(wan).slice(-2), [[30, null], [65, 99]]);

poll();
request.success({replace: false, samples: [sample('usb0', 75, undefined)]});
assert.strictEqual(element('traffic-interface').textContent, 'usb0');
assert.deepStrictEqual(points(wan), [[75, null]]);
poll();
request.success({replace: false, samples: [{time: 85, cpu: 31, ram: 80}]});
assert.strictEqual(element('traffic-interface').textContent, '');
assert.strictEqual(element('traffic-unavailable').hidden, false);
assert.strictEqual(element('wan-chart-frame').hidden, true);
assert.strictEqual(element('resource-cpu').textContent, '31%');

poll();
request.success({replace: true, samples: [sample('eth4', 100, 42)]});
assert.deepStrictEqual(points(usage), [[100, 30]], 'a cleared router cache replaces local points');
for (let i = 1; i <= 65; i++) {
    poll();
    request.success({replace: false, samples: [sample('eth4', 100 + i * 10, 10)]});
}
assert.strictEqual(points(wan).length, 60);
assert.strictEqual(points(usage).length, 60);

poll();
const stale = request;
const oldCard = activeCard;
activeCard = null;
stale.success({replace: true, samples: [sample('usb0', 800, 20)]});
assert.strictEqual(oldCard.querySelector('[data-resource="traffic-interface"]').textContent, 'eth4');
observed();
assert.ok(charts[wan].destroyed && charts[usage].destroyed);

activeId = 'system-resources-card';
activeCard = createCard();
context.modgui.initResourceCharts(activeId, true);
assert.strictEqual(charts[wan].options.scales.yAxes[0].display, false);
assert.strictEqual(charts[wan].options.scales.xAxes[0].display, false);
assert.ok(charts[usage].data.datasets.every(dataset => dataset.fill === 'origin'));
assert.ok(charts[wan].data.datasets.every(dataset => dataset.fill === 'origin'));
assert.strictEqual(points(wan).length, 60, 'the other view renders existing points before requesting data');
assert.match(element('wan-chart')['aria-label'], /160 bit\/s.*240 bit\/s/);
assert.strictEqual(element('wan-chart').title, undefined);
assert.strictEqual(poll().get('after'), '750');
request.success({replace: false, samples: [{time: 760, ram: 50}]});
assert.strictEqual(element('wan-chart-frame').hidden, true);
assert.strictEqual(element('wan-chart')['aria-label'], 'br-lan RX – · TX –');

poll();
request.success({replace: true, samples: [
    {...sample('eth4', 1000, 10, 25), historical: true},
    {time: 1300, interface: 'eth4', lan: true, ram: 51},
    sample('eth4', 1310, 20, 32),
]});
assert.deepStrictEqual(points(usage), [[1000, 25], [1310, 32]]);
assert.deepStrictEqual(points(wan), [[1000, 20], [1310, 40]]);
const dataset = charts[usage].data.datasets[0];
assert.strictEqual(dataset.pointRadius, 0);
assert.strictEqual(charts[usage].options.events.length, 0);
assert.strictEqual(charts[wan].options.events.length, 0);

poll();
request.success({replace: true, samples: [
    {...sample('eth4', 1000, 10, 25), historical: true},
    sample('eth4', 1700, 20, 32),
]});
assert.deepStrictEqual(points(wan), [[1000, 20], [1001, null], [1700, 40]]);

activeId = 'graphtab';
activeCard = createCard();
context.modgui.initResourceCharts(activeId, false);
assert.ok(charts[usage].data.datasets.every(dataset => dataset.fill === 'origin'));
assert.ok(charts[wan].data.datasets.every(dataset => dataset.fill === 'origin'));
poll();
request.success({replace: true, samples: [
    {...sample('eth4', 1000, 10, 25), historical: true},
    {time: 1700, interface: 'eth4', ram: 51},
    {time: 1710, interface: 'eth4', ram: 51},
    sample('eth4', 1720, 20, 32),
    sample('eth4', 1750, 25, 35),
]});
assert.deepStrictEqual(points(usage), [[1000, 25], [1720, 32], [1721, null], [1750, 35]]);
assert.deepStrictEqual(points(wan), [[1000, 10], [1720, 20], [1721, null], [1750, 25]]);
console.log('Resource charts share history, render gaps, retain a bounded window and reset WAN on interface changes');
