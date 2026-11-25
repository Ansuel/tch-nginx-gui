// Exercise real table callbacks and modal-close handler with a small DOM stub.
const fs = require('fs');
const assert = require('assert');
const source = fs.readFileSync('decompressed/gui_file/www/docroot/js/main-min-nojquery.js', 'utf8');
const tableAction = source.slice(source.indexOf('\tfunction l(t, e) {'), source.indexOf('\tfunction d(t, e) {', source.indexOf('\tfunction l(t, e) {')));
let count = 0, status = 'success', errors = 0, posted;
const chain = {attr: () => 'rules', closest: () => chain, find: () => chain,
 index: () => 0, serializeArray: () => [], length: 0};
function $(selector) { return typeof selector === 'string' && selector.includes('.alert-error') ? {length: errors} : chain; }
function a() { return {name: 'CSRFtoken', value: 'test'}; }
function c() {}
function n(url, data, callback) { posted = data; callback('', status); }
const l = eval("(" + tableAction.trim() + ")");
for (const action of ['TABLE-ADD', 'TABLE-DELETE', 'TABLE-MODIFY', 'TABLE-EDIT', 'TABLE-CANCEL']) {
 for (const response of ['success', 'error']) {
  for (const invalid of [0, 1]) {
   count = 0; status = response; errors = invalid;
   l(action, {});
   assert.strictEqual(count, response === 'success' && !invalid && ['TABLE-ADD','TABLE-DELETE','TABLE-MODIFY'].includes(action) ? 1 : 0);
   assert(posted.some(x => x.name === 'action' && x.value === action));
  }
 }
}
// An asynchronous refresh must retain its original target, even if another card opens.
let handler, complete, failure, replaced = [], requests = 0, reloads = 0, inDom = true, forceReload = false;
const originalParent = {replaceWith: data => replaced.push(['original', data])};
const cardElement = {};
let lastCardClicked = {0: cardElement, find: () => ({data: () => '/modals/wanservices-modal.lp'}), parent: () => originalParent};
$ = selector => selector === document ? {on: (event, target, callback) => {handler = callback;}} : {hasClass: () => true};
$.get = (url, callback) => {requests++; complete = callback; return {fail: callback => {failure = callback;}};};
$.contains = (root, element) => inDom && element === cardElement;
const document = {body: {}}, window = {location: {reload: () => {reloads++;}}};
const start = source.indexOf('\t$(document).on("hidden", ".modal"');
eval(source.slice(start, source.indexOf('\n\tvar modalOpening', start)));
count = 1;
handler({target: {}});
assert.strictEqual(count, 0);
assert.strictEqual(requests, 1);
assert.strictEqual(reloads, 0);
lastCardClicked = {parent: () => ({replaceWith: () => {throw Error('wrong card');}})};
complete('updated');
assert.deepStrictEqual(replaced, [['original', 'updated']]);
// Without a pending change nothing happens.
lastCardClicked = null;
handler({target: {}});
assert.strictEqual(requests, 1);
assert.strictEqual(reloads, 0);
// A failed card request falls back to a full reload.
lastCardClicked = {0: cardElement, find: () => ({data: () => '/modals/wanservices-modal.lp'}), parent: () => originalParent};
count = 1;
handler({target: {}});
assert.strictEqual(requests, 2);
failure();
assert.strictEqual(reloads, 1);
// A card that is no longer in the page cannot be refreshed, so reload instead.
inDom = false;
count = 1;
handler({target: {}});
assert.strictEqual(requests, 2);
assert.strictEqual(reloads, 2);
// A forced reload skips the single-card refresh and does not leak into the next close.
inDom = true;
count = 1;
forceReload = true;
handler({target: {}});
assert.strictEqual(requests, 2);
assert.strictEqual(reloads, 3);
assert.strictEqual(forceReload, false);
count = 1;
handler({target: {}});
assert.strictEqual(requests, 3);
assert.strictEqual(reloads, 3);
console.log('Card refresh: 20 table cases and asynchronous target/reset/fallback checks passed');
