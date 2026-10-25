// The shared terminal must never poll the previous job before POST acceptance.
const fs = require('fs'), vm = require('vm'), assert = require('assert');
const source = fs.readFileSync('decompressed/gui_file/www/docroot/js/shared-script.js', 'utf8');
const script = source.slice(source.indexOf('\tvar commandRequestInProgress'), source.indexOf('\n\tfunction createAjaxUpdateCard('));
const requests = [], opened = [], errors = [], events = [];
let clears = 0, closes = 0, state = 'Complete', log = 'GUI upgrade finished';
const window = {location: {reload() {closes++;}}};
function $(selector) {
  const element = {
    attr(value) {return typeof value === 'string' ? (value === 'action' ? '/modals/applications-modal.lp' : 'csrf') : this;},
    remove() {return this;}, addClass() {return this;},
    text(value) {errors.push(value); return this;}, prependTo() {return this;},
    one(name, fn) {events.push(fn); return this;}, unbind() {return this;},
    on(name, fn) {this.handler = fn; return this;},
  };
  return element;
}
$.post = (target, data, callback, type) => {
  assert.strictEqual(type, 'json');
  const handlers = {};
  const request = {
    target, data,
    done(fn) {handlers.done = fn; return this;},
    fail(fn) {handlers.fail = fn; return this;},
    always(fn) {handlers.always = fn; return this;},
    resolve(data) {handlers.done(data); handlers.always();},
    reject(data) {handlers.fail(data); handlers.always();},
  };
  requests.push(request); return request;
};
const context = {window, $, waitMsg: 'wait', clearKoInterval() {clears++;},
  tch: {showProgress() {}, openModal(url) {opened.push({url, state, log});}}};
vm.createContext(context);
vm.runInContext(script, context);
assert.strictEqual(context.postAction('install_luci', 1), false);
assert.strictEqual(requests.length, 1);
assert.strictEqual(opened.length, 0, 'do not open a terminal with the previous Complete state');
assert.strictEqual(clears, 0, 'keep the current modal intact until acceptance');
context.postAction('install_luci', 1);
assert.strictEqual(requests.length, 1, 'ignore duplicate clicks while awaiting acceptance');
// Simulate the server preparing the new job, then acknowledging the POST.
state = 'Requested'; log = '';
requests[0].resolve({success: 'true'});
assert.strictEqual(opened.length, 1);
assert.strictEqual(opened[0].state, 'Requested');
assert.strictEqual(opened[0].log, '');
assert.strictEqual(clears, 1);
assert.strictEqual(events.length, 1);
events[0]();
// A rejected start must not show another job's log as its result.
state = 'Complete'; log = 'Older job';
context.postAction('install_luci', 1);
requests[1].reject({status: 409, responseJSON: {error: 'Another command is already running'}});
assert.strictEqual(opened.length, 1);
assert.strictEqual(errors.pop(), 'Another command is already running');
context.postAction('install_luci', 1);
requests[2].resolve({success: false, error: 'Start failed'});
assert.strictEqual(opened.length, 1);
assert.strictEqual(errors.pop(), 'Start failed');
context.postAction('install_luci', 1);
requests[3].reject({status: 0});
assert.strictEqual(errors.pop(), 'Unable to start command.');
assert.strictEqual(opened.length, 1);
// Boolean acknowledgements and commands without a terminal remain supported.
context.postAction('install_luci', 1);
requests[4].resolve({success: true});
assert.strictEqual(opened.length, 2);
context.postAction('checkver', null, null, '/modals/modgui-modal.lp?auto_update=true');
assert.strictEqual(requests[5].target, '/modals/modgui-modal.lp?auto_update=true');
requests[5].resolve({success: 'true'});
assert.strictEqual(opened.length, 2);
console.log('Command start: delayed acceptance, previous log, duplicates, rejection and retry passed');
