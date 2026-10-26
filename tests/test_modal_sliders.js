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
let status, httpStatus, initCalls = 0, errors = 0, callbacks = 0;
function load$(selector) {
  if (selector === '.modal') return {load(url, data, fn) {fn('', status, {status: httpStatus});}};
  if (selector === '.modal-action-advanced:first') return {is() {return false;}};
  if (selector === '#sign-me-in') return {length: 0};
  if (selector === windowStub) return {scrollTop() {}};
  throw Error('Unexpected selector: ' + selector);
}
load$.ajaxSetup = () => {};
const windowStub = {};
const loadContext = {$: load$, window: windowStub, waitMsg: '', loginMsg: '',
  p() {}, e() {}, m() {}, r() {}, httpErrorMessage() {errors++;}, i() {initCalls++;}};
vm.createContext(loadContext);
vm.runInContext(source.slice(loadStart, initStart), loadContext);
for (const failure of ['error', 'timeout']) {
  status = failure; httpStatus = 0;
  loadContext.n('/modals/wireless-modal.lp?radio=radio_5G', () => callbacks++);
}
assert.strictEqual(errors, 2);
assert.strictEqual(initCalls, 0); // The old sliders remain initialized after a failed load.
assert.strictEqual(callbacks, 0);
status = 'success'; httpStatus = 200;
loadContext.n('/modals/wireless-modal.lp?radio=radio_5G', () => callbacks++);
assert.strictEqual(initCalls, 1);
assert.strictEqual(callbacks, 1);
console.log('modal slider and failed-load lifecycle OK');
