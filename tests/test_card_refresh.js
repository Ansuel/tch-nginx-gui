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
let handler, complete, replaced = [], requests = 0, modalToCard;
const originalParent = {replaceWith: data => replaced.push(['original', data])};
let lastCardClicked = {find: () => ({data: () => '/modals/wanservices-modal.lp'}), parent: () => originalParent};
$ = selector => selector === document ? {on: (event, target, callback) => {handler = callback;}} : {hasClass: () => true};
$.get = (url, callback) => {requests++; complete = callback;};
const document = {}, window = {location: {reload: () => {throw Error('unexpected reload');}}};
const start = source.indexOf('\t$(document).on("hidden", ".modal"');
eval(source.slice(start, source.indexOf('\n\tvar y = !1;', start)));
count = 1;
handler({target: {}});
assert.strictEqual(count, 0);
lastCardClicked = {parent: () => ({replaceWith: () => {throw Error('wrong card');}})};
complete('updated');
assert.deepStrictEqual(replaced, [['original', 'updated']]);
lastCardClicked = null;
handler({target: {}});
assert.strictEqual(requests, 1);
console.log('Card refresh: 20 table cases and asynchronous target/reset checks passed');
