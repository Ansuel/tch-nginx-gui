const fs = require('fs'), vm = require('vm'), assert = require('assert');
const source = fs.readFileSync('decompressed/gui_file/www/docroot/js/main-min-nojquery.js', 'utf8');
const initStart = source.indexOf('\tfunction i() {', source.indexOf('\tfunction n(t, n, o) {'));
const initEnd = source.indexOf('\n\tfunction o()', initStart);
assert(initStart > 0 && initEnd > initStart);
let sliders = [], initialized = 0, handlers = 0;
const empty = {length: 0, first() { return this; }, each() { return this; }, tooltip() { return this; }};
function slider(selectedIndex) {
  const select = {find() {return {length: 13};}, prop(key, value) {
    if (arguments.length > 1) {selectedIndex = value; return this;}
    return selectedIndex;
  }, children() {return {text() {return '0 dBm';}};}};
  return {ready: false, hasClass() {return this.ready;}, children() {return select;},
    next() {return {text() {}};}, noUiSlider(options) {
      if (this.ready) throw new Error('Slider was already initialized.');
      this.ready = true; this.value = options.start; initialized++;
    }, on() {handlers++;}, val() {return this.value;}};
}
function $(selector) {
  if (typeof selector === 'object') return selector;
  if (selector === 'meta[name=Advanced]') return {attr() {return '0';}};
  if (selector === '.noUiSlider.slider-select') return {each(fn) {sliders.forEach(s => fn.call(s));}};
  return empty;
}
const context = {$, window: {}};
vm.createContext(context);
vm.runInContext(source.slice(initStart, initEnd), context);
sliders = [slider(6), slider(8)];
context.i();
// openModal and Bootstrap's shown event initialize the same DOM twice.
context.i();
assert.strictEqual(initialized, 2);
assert.strictEqual(handlers, 2);
assert.strictEqual(sliders[0].value, 6);
assert.strictEqual(sliders[1].value, 8);
// A successful tab switch replaces the DOM and must initialize new controls.
sliders = [slider(3)];
context.i();
assert.strictEqual(initialized, 3);
assert.strictEqual(handlers, 3);
assert.strictEqual(sliders[0].value, 3);

const loadStart = source.indexOf('\tfunction n(t, n, o) {');
const openStart = source.indexOf('\tfunction u(url, id)', initEnd);
const openEnd = source.indexOf('\n\tfunction h(', openStart);
const url = '/modals/smartphone-modal.lp';
let busy = false, request, throwOnRequest = false, activeModal = true;
let rendered, errorDialog, initCalls = 0, callbacks = 0;
const errors = [];
const body = {
  length: 1,
  first() { return this; },
  find() { return {first: () => ({is: () => false})}; },
  triggerHandler() { return this; },
  data(key, value) { return arguments.length === 1 ? url : this; },
  empty() { return this; },
  append(content) { rendered = content.html; },
  remove() {},
};
const windowStub = {location: '/cards.lp'};
function load$(selector) {
  if (selector === '.modal') return body;
  if (selector === '.modal.in') return {first: () => activeModal ? body : {length: 0}};
  if (selector === '.modal form') return {attr() {}};
  if (selector === windowStub) return {scrollTop() {}};
  if (typeof selector === 'object') return selector;
  if (selector.includes('modal fade')) {
    errorDialog = {find: () => ({attr() {}}), modal(mode) { this.mode = mode; }};
    return errorDialog;
  }
  throw Error('Unexpected selector: ' + selector);
}
load$.parseHTML = html => ({
  html,
  find(selector) { return {addBack: () => ({length: Number(html.includes(selector.slice(1)))})}; },
});
load$.ajax = options => {
  if (throwOnRequest) throw Error('request setup failed');
  assert.strictEqual(options.timeout, 60000);
  let done, fail, always;
  request = {
    options,
    done(fn) { done = fn; return this; },
    fail(fn) { fail = fn; return this; },
    always(fn) { always = fn; return this; },
    resolve(html) { done(html, 'success', {status: 200}); if (always) always(); },
    reject(status, code) { fail({status: code}, status); if (always) always(); },
    abort() { this.reject('abort', 0); },
  };
  return request;
};
const loadContext = {$: load$, window: windowStub, document: {}, waitMsg: 'Wait', openMsg: 'Loading',
  cancelButton: 'Cancel', modalOpening: false, console: {error() {}},
  p() { assert(!busy); busy = true; }, m() { busy = false; }, e() {}, r() {},
  httpErrorMessage(xhr, target, status) { errors.push([xhr?.status, target, status]); },
  i() { initCalls++; },
};
vm.createContext(loadContext);
vm.runInContext(source.slice(loadStart, initStart), loadContext);
vm.runInContext(source.slice(openStart, openEnd), loadContext);

assert.strictEqual(loadContext.modalRefreshUrl(), url);
loadContext.n(undefined);
assert.strictEqual(request, undefined);
assert.deepStrictEqual(errors.pop(), [undefined, body, 'invalid']);
assert(!busy);

for (const [status, code] of [['error', 500], ['error', 404], ['error', 0], ['timeout', 0]]) {
  loadContext.n(url, () => callbacks++);
  assert(busy);
  request.reject(status, code);
  assert(!busy);
  assert.deepStrictEqual(errors.pop(), [code, body, status]);
}
loadContext.n(url);
request.resolve('<html>Unexpected response</html>');
assert(!busy);
assert.deepStrictEqual(errors.pop(), [undefined, body, 'invalid']);
assert.strictEqual(rendered, undefined);
assert.strictEqual(initCalls, 0);
assert.strictEqual(callbacks, 0);

throwOnRequest = true;
loadContext.n(url);
assert(!busy);
assert.deepStrictEqual(errors.pop(), [undefined, body, 'error']);
throwOnRequest = false;

loadContext.n(url);
const superseded = request;
loadContext.n(url, () => callbacks++);
assert.notStrictEqual(request, superseded);
assert(busy);
assert.strictEqual(errors.length, 0);
assert.strictEqual(request.options.type, 'GET');
request.resolve('<div class="modal-body">Ready</div>');
assert(!busy);
assert.strictEqual(rendered, '<div class="modal-body">Ready</div>');
assert.strictEqual(initCalls, 1);
assert.strictEqual(callbacks, 1);

loadContext.n(url, [{name: 'action', value: 'SAVE'}]);
assert.strictEqual(request.options.type, 'POST');
request.reject('error', 403);
assert(!busy);
assert.strictEqual(windowStub.location, '/login.lp');

activeModal = false;
loadContext.u(url, 'smartphone');
assert(busy);
request.reject('error', 500);
assert(!busy);
assert(!loadContext.modalOpening);
assert.strictEqual(errorDialog.mode, 'show');
assert.deepStrictEqual(errors.pop(), [500, errorDialog, 'error']);
console.log('modal slider and failed-load lifecycle OK');
