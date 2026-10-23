// Run each inline extension client with the real shared polling lifecycle.
const fs = require('fs'), vm = require('vm'), assert = require('assert');
const shared = fs.readFileSync('decompressed/gui_file/www/docroot/js/shared-script.js', 'utf8');
const factory = shared.slice(shared.indexOf('\tfunction createAjaxUpdateCard('), shared.indexOf('\n\tfunction linkCheckUpdate()'));
for (const [name, file, modal] of [
  ['tailscale', '016_tailscale.lp', 'tailscale'],
  ['wireguard', '016_wireguard.lp', 'wireguard'],
  ['openvpn', '015_openvpn-server.lp', 'openvpn-server'],
]) {
  const source = fs.readFileSync('decompressed/gui_file/www/cards/' + file, 'utf8');
  const client = source.split('<script>')[1].split('</script>')[0];
  let element = {}, replacements = [], timers = new Map(), next = 0, requests = [];
  const document = {hidden: false, getElementById: id => id === name + '-card' ? element : null};
  function $(target) {
    if (typeof target === 'function') return target();
    if (target === '<div>') return {append: parsed => ({find: selector => {
      assert.strictEqual(selector, '#' + name + '-card > .smallcard > .content');
      return {length: parsed === 'valid' ? 1 : 0, value: parsed};
    }})};
    return {find: () => ({each: () => {}, replaceWith: content => replacements.push(content.value)})};
  }
  $.parseHTML = (html, doc, keepScripts) => {
    assert.strictEqual(doc, document);
    assert.strictEqual(keepScripts, false, 'response scripts must never execute');
    return html;
  };
  $.ajax = options => {
    assert.strictEqual(options.url, '/ajax/get_card.lua?modal=/modals/' + modal + '-modal.lp');
    assert.strictEqual(options.type, 'GET');
    assert.strictEqual(options.timeout, 8000);
    assert.strictEqual(options.dataType, 'html');
    assert.strictEqual(options.cache, false);
    let done, always;
    const req = {aborted: false, done(fn) {done = fn; return this;}, always(fn) {always = fn; return this;},
      resolve(html) {done(html); always();}, reject() {always();}, abort() {this.aborted = true; always();}};
    requests.push(req); return req;
  };
  const context = {document, $, KoRequest: {}, modgui: {}, ko: {dataFor: () => true},
    setInterval: (fn, delay, arg) => {assert.strictEqual(delay, 30000); timers.set(++next, () => fn(arg)); return next;},
    clearInterval: id => timers.delete(id)};
  vm.createContext(context);
  vm.runInContext(factory + '\nmodgui.createAjaxUpdateCard = createAjaxUpdateCard;', context);
  const init = () => vm.runInContext(client, context);
  const tick = () => [...timers.values()].forEach(fn => fn());
  init(); init(); tick();
  assert.strictEqual(requests.length, 1, 'duplicate initialization and pending reads must not overlap');
  requests[0].resolve('valid'); assert.deepStrictEqual(replacements, ['valid']);
  document.hidden = true; tick(); assert.strictEqual(requests.length, 1);
  document.hidden = false; tick(); requests[1].resolve('login page');
  assert.deepStrictEqual(replacements, ['valid'], 'invalid or login responses must not replace the card');
  tick(); requests[2].reject(); tick(); assert.strictEqual(requests.length, 4, 'retry after failure');
  const old = requests[3]; element = {}; init(); assert(old.aborted);
  old.resolve('valid'); assert.deepStrictEqual(replacements, ['valid'], 'ignore stale results');
  const current = requests[4]; element = null; tick(); assert(current.aborted);
  assert.strictEqual(timers.size, 0);
}
console.log('Extension cards: shared polling, hidden pages, overlap, retry, script stripping and stale/removal checks passed');
