const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const source = fs.readFileSync('decompressed/gui_file/www/info-cards/004_graph.lp', 'utf8');
const script = source.slice(source.indexOf('var trafficSample ='), source.indexOf('$(document).ready'))
    .replace(/\\\r?\n/g, '\n');
let label = {textContent: ''};
let request, chartUpdates = 0, hour = 23, unavailable;
const context = {
    document: {getElementById: () => label},
    tch: {elementCSRFtoken: () => ({name: 'CSRFtoken', value: 'test'})},
    $: Object.assign(() => ({toggleClass: (_, hidden) => { unavailable = !hidden; }}), {
        ajax: options => {
            request = options;
            assert.strictEqual(options.type, 'POST');
            assert.strictEqual(options.timeout, 8000);
            return options;
        },
    }),
    Date: class {getHours() {return hour;} getMinutes() {return 0;} getSeconds() {return 0;}},
    wanRxdatasets: [], wanTxdatasets: [], timelabel: [],
    InfoWANChart: {update: () => { chartUpdates++; }},
    encodeURIComponent, isFinite,
};
vm.createContext(context);
vm.runInContext(script, context);
const refresh = () => {
    assert.strictEqual(context.InfoGraphCardRefresh(), request);
    return new URL(request.url, 'http://router').searchParams;
};
const sample = (device, time, rate) => ({
    valid: true, interface: device, rx_traffic: '2000', tx_traffic: '5000', sample_time: time,
    rx_bytes_per_second: rate, tx_bytes_per_second: rate,
});

let query = refresh();
assert.strictEqual(query.get('source'), 'wan');
assert.strictEqual(query.get('interface'), '');
request.success(sample('eth4', 10));
query = refresh();
assert.strictEqual(query.get('interface'), 'eth4');
assert.strictEqual(query.get('oldtime'), '10');
request.success(sample('eth4', 20, 100));
assert.deepStrictEqual(context.wanRxdatasets, ['800']);
hour = 0; // Crossing midnight does not change the rate supplied by the router.
refresh();
request.success(sample('eth4', 30, 100));
assert.deepStrictEqual(context.wanRxdatasets, ['800', '800']);
const updates = chartUpdates;
refresh();
request.success(sample('eth4', 40));
assert.strictEqual(chartUpdates, updates, 'counter resets must rebase without inserting a spike');

refresh();
request.success(sample('usb0', 50));
assert.strictEqual(label.textContent, 'usb0');
assert.strictEqual(context.wanRxdatasets.length, 0);
assert.strictEqual(refresh().get('interface'), 'usb0');
request.success({valid: false});
assert.strictEqual(label.textContent, '');
assert.strictEqual(unavailable, true);
assert.strictEqual(refresh().get('oldtime'), '');
request.success(sample('eth4', 60));
assert.strictEqual(unavailable, false);
for (let i = 0; i < 65; i++) {
    refresh();
    request.success(sample('eth4', 70 + i, 10));
}
assert.strictEqual(context.wanRxdatasets.length, 60);
assert.strictEqual(context.wanTxdatasets.length, 60);
assert.strictEqual(context.timelabel.length, 60);

refresh();
const oldRequest = request;
label = {textContent: ''};
vm.runInContext(script, context);
oldRequest.success(sample('usb0', 200));
assert.strictEqual(label.textContent, '');
assert.strictEqual(refresh().get('interface'), '');
label = null;
assert.strictEqual(context.InfoGraphCardRefresh(), undefined);
console.log('Traffic graph: interface changes, unavailable links, counter resets and bounded data passed');
