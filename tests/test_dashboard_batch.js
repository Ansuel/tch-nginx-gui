const fs = require('fs'), vm = require('vm'), assert = require('assert');
function setup(select = () => {}) {
  const timers = new Map(), requests = [];
  let nextTimer = 0;
  function Deferred() {
    let state = 'pending', args, context, done = [], fail = [], always = [];
    function settle(nextState, ctx, values, callbacks) {
      if (state !== 'pending') return;
      state = nextState; args = values; context = ctx;
      [...callbacks, ...always].forEach(fn => fn.apply(context, args));
    }
    const api = {
      done(fn) {done.push(fn); if (state === 'resolved') fn.apply(context, args); return this;},
      fail(fn) {fail.push(fn); if (state === 'rejected') fn.apply(context, args); return this;},
      always(fn) {always.push(fn); if (state !== 'pending') fn.apply(context, args); return this;},
      resolveWith(ctx, values) {settle('resolved', ctx, values, done);},
      rejectWith(ctx, values) {settle('rejected', ctx, values, fail);},
      resolve(...values) {api.resolveWith(api, values);},
      reject(...values) {api.rejectWith(api, values);},
      promise(target) {for (const name of ['done', 'fail', 'always']) target[name] = api[name]; return target;},
    };
    return api;
  }
  const $ = Object.assign(select, {Deferred, trim: text => text.trim(), ajax(options) {
    const deferred = Deferred();
    if (options.success) deferred.done(options.success);
    const xhr = deferred.promise({options, resolve: deferred.resolve, reject: deferred.reject,
      abort() {this.aborted = true; deferred.reject({status: 0, statusText: 'abort'}, 'abort');}});
    requests.push(xhr); return xhr;
  }});
  const window = {
    setTimeout(fn) {timers.set(++nextTimer, fn); return nextTimer;},
    clearTimeout(id) {timers.delete(id);},
  };
  vm.runInNewContext(fs.readFileSync('decompressed/gui_file/www/docroot/js/dashboard-polling.js', 'utf8'), {window, jQuery: $});
  return {requests, send: window.modguiDashboardRequest, read: window.modguiDashboardRead,
    loadCards: window.modguiLoadDashboardCards, abortCards: window.modguiAbortDashboardCards,
    flush() {
      while (timers.size) {
        const [id, fn] = timers.entries().next().value;
        timers.delete(id); fn();
      }
    }};
}
const options = (path, success, token = 'test') => ({url: '/ajax/' + path + (path.includes('?') ? '&' : '?') + 'auto_update=true', type: 'POST', dataType: 'json',
  timeout: 8000, data: [{name: 'CSRFtoken', value: token}], success});
{
  const s = setup(), results = [];
  const a = s.send(options('cpuload.lua', data => results.push(data.value)));
  const b = s.send(options('internet.lua', data => results.push(data.value)));
  a.done(() => results.push('done')); b.always(() => results.push('always'));
  assert.strictEqual(s.requests.length, 0); s.flush();
  assert.strictEqual(s.requests.length, 1);
  assert.strictEqual(s.requests[0].options.data[1].value, 'gateway,wan');
  assert.strictEqual(s.requests[0].options.timeout, 8000);
  s.requests[0].resolve({modules: {gateway: {status: 200, data: {value: 'cpu'}}, wan: {status: 200, data: {value: 'wan'}}}});
  assert.deepStrictEqual(results, ['cpu', 'done', 'wan', 'always']);
}
{
  const s = setup(), results = [];
  const a = s.send(options('cpuload.lua', () => results.push('stale'))).fail(xhr => results.push(xhr.statusText));
  s.send(options('internet.lua', () => results.push('wan')));
  s.flush(); a.abort();
  s.requests[0].resolve({modules: {gateway: {status: 200, data: {}}, wan: {status: 200, data: {}}}});
  assert.deepStrictEqual(results, ['abort', 'wan']);
}
{
  const s = setup(); let success = 0;
  s.send(options('cpuload.lua', () => success++)); s.send(options('internet.lua', () => success++));
  s.flush(); s.requests[0].reject({status: 404}); s.flush();
  assert.strictEqual(s.requests.length, 3);
  s.requests[1].resolve({}); s.requests[2].resolve({}); assert.strictEqual(success, 2);
  s.send(options('port_status.lua', () => success++)); s.flush(); assert.strictEqual(s.requests.length, 4);
}
{
  const s = setup(); let failure;
  s.send(options('internet.lua')).fail(xhr => failure = xhr);
  s.flush(); s.requests[0].resolve({modules: {wan: {status: 500, error: 'backend'}}});
  assert.strictEqual(failure.status, 500); assert.strictEqual(failure.getResponseHeader('error-msg'), 'backend');
  s.send(options('cpuload.lua')).fail(xhr => failure = xhr);
  s.flush(); s.requests[1].resolve({modules: {}}); assert.strictEqual(failure.status, 502);
  s.send(options('cpuload.lua')).fail(xhr => failure = xhr);
  s.flush(); s.requests[2].reject({status: 0, statusText: 'timeout'}); assert.strictEqual(failure.statusText, 'timeout');
}
{
  const s = setup(); let completed = 0;
  const a = s.send(options('internet.lua', () => completed++)); a.abort(); s.flush();
  assert.strictEqual(s.requests.length, 0);
  s.send(options('internet.lua', () => completed++, 'old'));
  s.send(options('internet.lua', () => completed++, 'new')); s.flush();
  assert.strictEqual(s.requests.length, 2); // Different tokens cannot share a request.
  s.send(options('traffic_graph.lua')); s.send(options('internet.lua?extra=1')); s.flush();
  assert.strictEqual(s.requests.length, 2, 'all physical requests share the limit');
  s.requests[0].resolve({}); s.flush(); assert.strictEqual(s.requests.length, 3);
  s.requests[1].resolve({}); s.flush(); assert.strictEqual(s.requests.length, 4);
}
{
  const s = setup();
  const running = s.read(options('ports.lua'));
  s.read(options('traffic_graph.lua'));
  s.flush();
  const canceled = s.read(options('canceled.lua'));
  s.read(options('queued-poll.lua'));
  s.read(options('get_card.lua'), true);
  canceled.abort();
  s.flush();
  assert.strictEqual(s.requests.length, 2);
  running.abort(); s.flush();
  assert(s.requests[0].aborted);
  assert(s.requests[2].options.url.includes('get_card.lua'), 'initial loads take priority over polling');
  let status;
  const next = s.read(options('next.lua')).fail((_, text) => status = text);
  s.requests[2].resolve({});
  s.flush();
  assert(s.requests[3].options.url.includes('queued-poll.lua'));
  next.abort();
  assert.strictEqual(status, 'abort', 'queued abort preserves the jQuery status argument');
  s.requests[1].resolve({}); s.flush();
  assert.strictEqual(s.requests.length, 4, 'removed reads never reach the router');
}
{
  const s = setup();
  const first = s.send(options('cpuload.lua')), second = s.send(options('internet.lua'));
  s.flush();
  first.abort();
  assert(!s.requests[0].aborted, 'the remaining subscriber still needs the batch');
  second.abort();
  assert(s.requests[0].aborted, 'cancel a batch with no remaining subscribers');
}
{
  const row = {parentNode: {}, getAttribute: key => key};
  const cards = ['slow', 'hidden', 'queued'].map(name => ({name, parentNode: row, messages: {}}));
  const s = setup(element => {
    if (element === row) return {children: () => ({each: callback => cards.forEach(card => callback.call(card))})};
    return {
      0: element, attr: () => '/modals/' + element.name + '.lp',
      remove() {element.parentNode = null;},
      find(selector) {
        const node = {attr: () => node, text: message => {element.messages[selector] = message;}};
        return node;
      },
    };
  });
  s.loadCards(row); s.flush();
  assert.strictEqual(s.requests.length, 2);
  s.requests[0].reject({status: 0}, 'timeout');
  s.requests[1].resolve(' ');
  s.flush();
  assert.strictEqual(cards[1].parentNode, null, 'empty successful responses hide unavailable cards');
  assert.deepStrictEqual(s.requests.slice(2).map(xhr => xhr.options.data.modal),
    ['/modals/queued.lp', '/modals/slow.lp'], 'retry follows the cards still waiting for their first load');
  s.requests[3].reject({status: 504}, 'error');
  s.flush();
  assert.strictEqual(s.requests.length, 4, 'a timed-out card is retried once');
  assert.strictEqual(cards[0].messages['.divtable'], 'data-card-timeout');
  s.abortCards();
  assert(s.requests[2].aborted, 'switching views cancels active placeholder loads');
}
console.log('dashboard batching lifecycle OK');
{
  const s = setup(); let wan, stats;
  s.send(options('internet.lua', data => wan = data));
  s.send(options('internet.lua?datatype=wanstats', data => stats = data));
  s.flush();
  assert.strictEqual(s.requests[0].options.data[1].value, 'wan,wanstats');
  s.requests[0].resolve({modules: {
    wan: {status: 200, data: {status: 'dhcp'}},
    wanstats: {status: 200, data: {connection: 'DHCP'}},
  }});
  assert.deepStrictEqual(wan, {status: 'dhcp'});
  assert.deepStrictEqual(stats, {connection: 'DHCP'});
}
{
  const s = setup(); let updated = false;
  s.send(options('internet.lua?datatype=xdsl'));
  s.send(options('cpuload.lua', () => updated = true)); s.flush();
  assert.strictEqual(s.requests.length, 2);
  assert(s.requests[0].options.url.includes('datatype=xdsl'));
  assert.strictEqual(s.requests[1].options.data[1].value, 'gateway');
  s.requests[1].resolve({modules: {gateway: {status: 200, data: {}}}});
  assert(updated); // An unresolved DSL request must not delay other cards.
}
