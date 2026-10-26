const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const source = fs.readFileSync('decompressed/gui_file/www/info-cards/004_graph.lp', 'utf8');
const script = source.slice(source.indexOf('var graphRequestPending ='), source.indexOf('$(document).ready'))
  .replace(/\\\r?\n/g, '\n')
  .replace("'); ngx.print(graph_interface); ngx.print('", 'ptm0');
const nodes = {
  rx_traffic_complete: {textContent: '1000'}, tx_traffic_complete: {textContent: '3000'},
  traffic_sample_time: {textContent: '10'},
};
let request, complete, requestCount = 0, chartUpdates = 0, hour = 23;
const bindings = {};
for (const key of Object.keys(nodes)) bindings[key] = value => { nodes[key].textContent = String(value); };
const context = {
  document: {hidden: false, getElementById: id => nodes[id]},
  tch: {elementCSRFtoken: () => ({name: 'CSRFtoken', value: 'test'})},
  $: {ajax: options => {
    requestCount++; request = options;
    assert.strictEqual(options.type, 'POST');
    assert.strictEqual(options.timeout, 8000);
    return {always: callback => { complete = callback; }};
  }},
  Date: class {getHours() {return hour;} getMinutes() {return 0;} getSeconds() {return 0;}},
  wanRxdatasets: [], wanTxdatasets: [], timelabel: [],
  InfoWANChart: {update: () => { chartUpdates++; }},
  encodeURIComponent, isFinite,
};
vm.createContext(context);
vm.runInContext(script, context);
const refresh = () => context.InfoGraphCardRefresh(bindings);
const respond = data => { request.success(data); complete(); };
refresh(); refresh();
assert.strictEqual(requestCount, 1, 'overlapping requests must be suppressed');
assert(request.url.includes('&oldtime=10'));
respond({valid: true, rx_traffic: '2000', tx_traffic: '5000', sample_time: 20,
  rx_bytes_per_second: 100, tx_bytes_per_second: 200});
assert.deepStrictEqual(context.wanRxdatasets, ['800']);
assert.strictEqual(nodes.traffic_sample_time.textContent, '20');
hour = 0; // Crossing midnight must not change the rate supplied by the router.
refresh();
respond({valid: true, rx_traffic: '3000', tx_traffic: '7000', sample_time: 30,
  rx_bytes_per_second: 100, tx_bytes_per_second: 200});
assert.strictEqual(context.wanRxdatasets[1], '800');
refresh();
respond({valid: true, rx_traffic: '1', tx_traffic: '2', sample_time: 40, reason: 'counter_reset'});
assert.strictEqual(chartUpdates, 2, 'a reset rebases without inserting a spike');
assert.strictEqual(nodes.rx_traffic_complete.textContent, '1');
refresh(); respond({valid: false, reason: 'interface_unavailable'});
assert.strictEqual(nodes.rx_traffic_complete.textContent, '1');
context.document.hidden = true;
const before = requestCount;
refresh(); assert.strictEqual(requestCount, before);
context.document.hidden = false;
refresh(); complete(); // An error/timeout must release the request guard.
refresh(); complete();
for (let i = 0; i < 65; i++) {
  refresh();
  respond({valid: true, rx_traffic: String(i), tx_traffic: String(i), sample_time: 50 + i,
    rx_bytes_per_second: 10, tx_bytes_per_second: 20});
}
assert.strictEqual(context.wanRxdatasets.length, 60);
assert.strictEqual(context.wanTxdatasets.length, 60);
assert.strictEqual(context.timelabel.length, 60);
// A response from a removed card must not modify a new card or release its guard.
refresh();
const oldRequest = request, oldComplete = complete;
nodes.traffic_sample_time = {textContent: '100'};
vm.runInContext(script, context);
refresh();
const updatesBefore = chartUpdates;
oldRequest.success({valid: true, rx_traffic: '999', tx_traffic: '999', sample_time: 999,
  rx_bytes_per_second: 999, tx_bytes_per_second: 999});
oldComplete();
assert.strictEqual(nodes.traffic_sample_time.textContent, '100');
assert.strictEqual(context.graphRequestPending, true);
assert.strictEqual(chartUpdates, updatesBefore);
complete();
delete nodes.traffic_sample_time;
const finalCount = requestCount;
refresh(); assert.strictEqual(requestCount, finalCount);
console.log('Traffic graph: router time, resets, hidden pages, bounded data and request lifecycle passed');
