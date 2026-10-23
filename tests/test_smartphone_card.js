const assert = require('assert');
const fs = require('fs');
const vm = require('vm');
const card = fs.readFileSync('decompressed/smartphone/www/cards/017_smartphone.lp', 'utf8');
const client = card.match(/<script>\n([\s\S]*?)\n<\/script>/)[1];
const shared = fs.readFileSync('decompressed/gui_file/www/docroot/js/shared-script.js', 'utf8');
const factory = shared.slice(shared.indexOf('\tfunction createAjaxUpdateCard('), shared.indexOf('\n\tfunction linkCheckUpdate()'));
let element = {}, requests = [], timers = new Map(), nextTimer = 0;
const classes = {}, attributes = {}, labels = {
  'data-connected': 'Connected', 'data-tether-off': 'USB tethering disabled',
  'data-data-off': 'Mobile data disabled', 'data-unavailable': 'Phone unavailable', 'data-checking': 'Checking connection'
};
function selection(name) {
  return {
    attr(key, value) {
      if (value === undefined) return name === '.content' ? labels[key] : attributes[name + ':' + key];
      attributes[name + ':' + key] = value; return this;
    },
    toggleClass(key, value) { classes[name + ':' + key] = !!value; return this; },
    each(callback) {
      if (name === '[data-bind]') {
        for (const field of ['phoneBattery', 'phoneStatus', 'phoneNetwork', 'phoneSignal']) callback.call({bind: 'text: ' + field});
      } else { for (let i = 0; i < 5; i++) callback.call('bar' + i, i); }
      return this;
    }
  };
}
function $(value) {
  if (typeof value === 'function') { value(); return; }
  if (value && value.bind) return {data: () => value.bind};
  if (value === element || value === '#smartphone-card') return {find: selection};
  return selection(String(value));
}
$.ajax = options => {
  const handle = {
    options, done(callback) { this.success = callback; return this; },
    fail(callback) { this.failure = callback; return this; },
    always(callback) { this.finish = callback; return this; },
    abort() { this.aborted = true; this.failure({statusText: 'abort'}, 'abort'); this.finish(); },
    deliver(data) { this.success(data); this.finish(); },
    reject() { this.failure({}, 'error'); this.finish(); }
  };
  requests.push(handle); return handle;
};
const context = {
  $, jQuery: $, window: {}, document: {hidden: false, getElementById: () => element}, KoRequest: {},
  setInterval(callback, delay, binding) {
    assert.strictEqual(delay, 30000);
    timers.set(++nextTimer, () => callback(binding)); return nextTimer;
  },
  clearInterval(id) { timers.delete(id); },
  ko: {
    observable() { let value; return function(next) { if (arguments.length) value = next; return value; }; },
    dataFor: node => node.bindings,
    applyBindings: (bindings, node) => { node.bindings = bindings; }
  },
  tch: {elementCSRFtoken: () => ({name: 'CSRFtoken', value: 'fixture'})}
};
vm.createContext(context);
vm.runInContext(factory, context);
context.modgui = {createAjaxUpdateCard: context.createAjaxUpdateCard};
vm.runInContext(client, context);
assert.strictEqual(requests.length, 1);
assert.strictEqual(requests[0].options.url, '/modals/smartphone-modal.lp');
assert.strictEqual(requests[0].options.data[1].value, 'get_stats');
assert.strictEqual(requests[0].options.data[0].name, 'CSRFtoken');
const binding = element.bindings;
assert.strictEqual(binding.phoneStatus(), 'Checking connection');
const sample = {DEV: 'Example phone', BATT: '72%', BATT_STAT: 'In Carica', OPER: 'VERY',
  NET: '5G (NSA)', SIGNAL_RAW: '-90', TETHER: 'Attivo (rndis0)', DATA_ST: '1'};
const tick = () => timers.get(context.KoRequest.SmartphoneCardInterval.interval)();
tick(); assert.strictEqual(requests.length, 1, 'Shared polling must prevent overlap');
requests[0].deliver(sample);
assert.strictEqual(binding.phoneStatus(), 'Connected (VERY)');
assert.strictEqual(binding.phoneBattery(), '(⚡ 72%)');
assert.strictEqual(binding.phoneNetwork(), '5G (NSA)');
assert.strictEqual(binding.phoneSignal(), '75% (-90 dBm)');
assert(classes['.light:green']);
assert.strictEqual([0,1,2,3,4].filter(i => classes['bar' + i + ':bar-small-active']).length, 4);
tick(); requests[1].deliver({...sample, TETHER: 'Inattivo', SIGNAL_RAW: '2147483647', BATT: '999%'});
assert.strictEqual(binding.phoneStatus(), 'USB tethering disabled (VERY)');
assert(!classes['.light:green'] && classes['.light:orange']);
assert.strictEqual(binding.phoneSignal(), '—');
assert.strictEqual(binding.phoneBattery(), '(—)');
assert(![0,1,2,3,4].some(i => classes['bar' + i + ':bar-small-active']));
tick(); requests[2].deliver({...sample, DATA_ST: '0', OPER: '<img src=x onerror=evil()>'});
assert.strictEqual(binding.phoneStatus(), 'Mobile data disabled (<img src=x onerror=evil()>)');
tick(); requests[3].deliver({ERROR: 'USB authorization required'});
assert.strictEqual(binding.phoneStatus(), 'Phone unavailable');
assert.strictEqual(binding.phoneNetwork(), '—');
assert.strictEqual(attributes['.smartphone-status:title'], 'USB authorization required');
context.document.hidden = true;
tick(); assert.strictEqual(requests.length, 4);
context.document.hidden = false;
tick(); assert.strictEqual(requests.length, 5);
requests[4].reject();
tick();
const pending = requests[5];
element = {};
vm.runInContext(client, context);
assert(pending.aborted, 'Replacing the card must abort the previous request');
assert.strictEqual(timers.size, 1);
pending.success(sample);
assert.strictEqual(binding.phoneStatus(), 'Phone unavailable', 'Stale responses must not update old bindings');
const active = requests[6];
element = null;
tick();
assert(active.aborted, 'Removing the card must abort its request');
assert.strictEqual(timers.size, 0);
assert.strictEqual(context.KoRequest.SmartphoneCardInterval, undefined);
console.log('Smartphone card: shared lifecycle, Knockout, mobile indicators and telemetry states passed');
