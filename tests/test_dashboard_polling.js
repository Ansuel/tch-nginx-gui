const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const source = fs.readFileSync('decompressed/gui_file/www/docroot/js/shared-script.js', 'utf8');
const script = source.slice(source.indexOf('\tfunction createAjaxUpdateCard('), source.indexOf('\n\tfunction linkCheckUpdate()'));
let elements = {}, timers = new Map(), requests = [], nextTimer = 0, popup = false;
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
    done(fn) {callbacks.done = fn; return this;},
    fail(fn) {callbacks.fail = fn; return this;},
    always(fn) {callbacks.always = fn; return this;},
    resolve(data) {options.success(data); callbacks.done(data); callbacks.always();},
    reject(data) {callbacks.fail(data); callbacks.always();},
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
  $, document: {hidden: false, getElementById: id => elements[id]}, KoRequest: {}, connectionissue: 0,
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
const tick = timer => timers.get(context.KoRequest[timer || 'CardInterval'].interval)();
elements.card = {};
initialize();
assert.strictEqual(requests.length, 1);
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
assert.strictEqual(context.connectionissue, 1);
tick(); requests[2].resolve({value: 'recovered'});
assert.strictEqual(context.connectionissue, 0);
assert(progress.includes('hide'));
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
assert.strictEqual(currentCard.bindings.value(), undefined);
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
tick('AuthInterval');
requests[7].reject({status: 500, getResponseHeader: () => 'example'});
assert(context.window.location.href.includes('/error.lp?status=500'));
tick('AuthInterval'); requests[8].resolve(null);
assert.strictEqual(elements.auth.bindings.value(), undefined);
console.log('Dashboard polling: visibility, timeout/retry, duplicates, replacement, custom callbacks and auth/errors passed');
