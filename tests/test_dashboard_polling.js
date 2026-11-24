const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const source = fs.readFileSync('decompressed/gui_file/www/docroot/js/shared-script.js', 'utf8');
const script = source.slice(source.indexOf('\tfunction createAjaxUpdateCard('), source.indexOf('\n\tfunction linkCheckUpdate()'));
let elements = {}, timers = new Map(), requests = [], nextTimer = 0, popup = false, clock = 0;
const progress = [];
function $(selector) {
  if (typeof selector === 'object') return {data: () => selector.bind};
  if (selector === '#popUp') return {is: () => popup};
  return {find: () => ({each: callback => callback.call({bind: 'text: value'})})};
}
$.ajax = options => {
  const callbacks = {};
  const request = {
    options, aborted: false,
    done(fn) {(callbacks.done ||= []).push(fn); return this;},
    fail(fn) {(callbacks.fail ||= []).push(fn); return this;},
    always(fn) {callbacks.always = fn; return this;},
    resolve(data) {options.success(data); (callbacks.done || []).forEach(fn => fn(data)); callbacks.always();},
    reject(data) {(callbacks.fail || []).forEach(fn => fn(data)); callbacks.always();},
    abort() {this.aborted = true; this.reject({statusText: 'abort'});},
  };
  requests.push(request);
  assert.strictEqual(options.type, 'POST');
  assert.strictEqual(options.dataType, 'json');
  assert.strictEqual(options.timeout, 8000);
  assert(options.data.some(item => item.name === 'CSRFtoken'));
  return request;
};
const context = {
  $, Date: {now: () => clock}, document: {hidden: false, getElementById: id => elements[id]}, KoRequest: {},
  ko: {
    observable: () => {let value; return function(next) {if (arguments.length) value = next; return value;};},
    dataFor: element => element.bindings,
    applyBindings: (bindings, element) => {element.bindings = bindings;},
  },
  tch: {
    elementCSRFtoken: () => ({name: 'CSRFtoken', value: 'test'}),
    removeProgress: () => {popup = false; progress.push('hide');},
    showProgress: message => {popup = true; progress.push(message);},
  },
  setInterval: (fn, delay, arg) => {const id = ++nextTimer; timers.set(id, () => fn(arg)); return id;},
  clearInterval: id => timers.delete(id),
  window: {location: {href: '/current'}}, loginMsg: 'login', connectionLost: 'lost',
};
vm.createContext(context);
vm.runInContext(script, context);
const initialize = (id = 'card', timer = 'CardInterval', custom) =>
  context.createAjaxUpdateCard(id, '/ajax/test.lua?number=1', timer, 3000, custom);
const tick = timer => {clock += 3000; timers.get(context.KoRequest[timer || 'CardInterval'].interval)();};
elements.card = {};
initialize();
assert.strictEqual(requests.length, 1);
assert.strictEqual(elements.card.bindings, undefined, 'leave the server-rendered card intact while loading');
assert(requests[0].options.url.endsWith('?number=1&auto_update=true'));
tick(); tick(); assert.strictEqual(requests.length, 1, 'requests must not overlap');
requests[0].resolve({value: 0});
assert.strictEqual(elements.card.bindings.value(), 0);
initialize();
assert.strictEqual(timers.size, 1, 'duplicate initialization must not register a second timer');
assert.strictEqual(requests.length, 1);
context.document.hidden = true;
tick(); assert.strictEqual(requests.length, 1);
context.document.hidden = false;
tick(); assert.strictEqual(requests.length, 2);
requests[1].reject({status: 0, statusText: 'timeout'});
tick(); assert.strictEqual(requests.length, 2, 'back off after a timeout');
popup = true;
tick(); requests[2].resolve({value: 'recovered'});
assert(popup, 'polling must leave an unrelated progress overlay alone');
assert.deepStrictEqual(progress, []);
assert.strictEqual(elements.card.bindings.value(), 'recovered');
tick();
const oldRequest = requests[3], oldCard = elements.card;
elements.card = {};
initialize();
const currentCard = elements.card;
assert(oldRequest.aborted, 'replacement must abort the old request');
assert.strictEqual(timers.size, 1);
oldRequest.options.success({value: 'stale'});
assert.strictEqual(oldCard.bindings.value(), 'recovered');
assert.strictEqual(currentCard.bindings, undefined);
requests[4].resolve({value: 'current'});
assert.strictEqual(currentCard.bindings.value(), 'current');
tick();
const removedRequest = requests[5], timerId = context.KoRequest.CardInterval.interval;
delete elements.card;
timers.get(timerId)();
assert(removedRequest.aborted);
assert.strictEqual(context.KoRequest.CardInterval, undefined);
assert.strictEqual(timers.size, 0);
removedRequest.options.success({value: 'late'});
assert.strictEqual(currentCard.bindings.value(), 'current');
let customCalls = 0;
elements.custom = {};
initialize('custom', 'CustomInterval', binding => {customCalls++; binding.value('custom');});
assert.strictEqual(customCalls, 1);
context.document.hidden = true; tick('CustomInterval');
assert.strictEqual(customCalls, 1);
context.document.hidden = false; tick('CustomInterval');
assert.strictEqual(customCalls, 2);
assert.strictEqual(elements.custom.bindings.value(), 'custom');
elements.auth = {};
initialize('auth', 'AuthInterval');
requests[6].reject({status: 200, responseText: '<div id="sign-me-in">login</div>'});
assert.strictEqual(context.window.location.href, '/');

tick('AuthInterval'); tick('AuthInterval');
requests[7].reject({status: 500, getResponseHeader: () => 'example'});
assert.strictEqual(context.window.location.href, '/', 'background errors must not navigate');
tick('AuthInterval'); tick('AuthInterval'); tick('AuthInterval'); tick('AuthInterval'); requests[8].resolve(null);
assert.strictEqual(elements.auth.bindings, undefined);
// Returned custom jqXHRs share pending/abort ownership with standard cards.
const customRequest = binding => $.ajax({url: '/custom', type: 'POST', dataType: 'json', timeout: 8000,
  data: [{name: 'CSRFtoken', value: 'test'}], success() {}
}).done(data => binding.value(data.value)).fail(() => {});
elements.customXHR = {};
initialize('customXHR', 'CustomXHRInterval', customRequest);
const requestCount = requests.length;
tick('CustomXHRInterval'); tick('CustomXHRInterval');
assert.strictEqual(requests.length, requestCount, 'custom requests must not overlap');
requests[requestCount - 1].resolve({value: 'custom response'});
assert.strictEqual(elements.customXHR.bindings.value(), 'custom response');
tick('CustomXHRInterval');
const replacedCustomRequest = requests[requests.length - 1];
elements.customXHR = {};
initialize('customXHR', 'CustomXHRInterval', customRequest);
assert(replacedCustomRequest.aborted, 'replacement must abort custom requests');
const removedCustomRequest = requests[requests.length - 1];
delete elements.customXHR;
tick('CustomXHRInterval');
assert(removedCustomRequest.aborted, 'removal must abort custom requests');

console.log('Dashboard polling: visibility, timeout/retry, duplicates, replacement, custom callbacks and auth/errors passed');
