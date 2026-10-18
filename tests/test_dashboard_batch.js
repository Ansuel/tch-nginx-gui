const fs = require('fs'), vm = require('vm'), assert = require('assert');
function setup() {
  let timers = [], requests = [];
  function Deferred() {
    let state = 'pending', value, done = [], fail = [], always = [];
    const api = {
      done(fn) {done.push(fn); if (state === 'resolved') fn(value); return this;},
      fail(fn) {fail.push(fn); if (state === 'rejected') fn(value); return this;},
      always(fn) {always.push(fn); if (state !== 'pending') fn(value); return this;},
      resolve(data) {if (state !== 'pending') return; state = 'resolved'; value = data; done.forEach(fn => fn(data)); always.forEach(fn => fn(data));},
      reject(data) {if (state !== 'pending') return; state = 'rejected'; value = data; fail.forEach(fn => fn(data)); always.forEach(fn => fn(data));},
      promise(target) {for (const name of ['done', 'fail', 'always']) target[name] = api[name]; return target;},
    };
    return api;
  }
  const $ = {Deferred, ajax(options) {
    const deferred = Deferred();
    if (options.success) deferred.done(options.success);
    const xhr = deferred.promise({options, resolve: data => deferred.resolve(data), reject: data => deferred.reject(data),
      abort() {deferred.reject({status: 0, statusText: 'abort'});}});
    requests.push(xhr); return xhr;
  }};
  const window = {setTimeout(fn) {timers.push(fn); return timers.length;}};
  vm.runInNewContext(fs.readFileSync('decompressed/gui_file/www/docroot/js/dashboard-polling.js', 'utf8'), {window, jQuery: $});
  return {requests, send: window.modguiDashboardRequest, flush() {const batch = timers; timers = []; batch.forEach(fn => fn());}};
}
const options = (path, success, token = 'test') => ({url: '/ajax/' + path + '?auto_update=true', type: 'POST', dataType: 'json',
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
  s.flush(); s.requests[0].reject({status: 404});
  assert.strictEqual(s.requests.length, 3);
  s.requests[1].resolve({}); s.requests[2].resolve({}); assert.strictEqual(success, 2);
  s.send(options('port_status.lua', () => success++)); assert.strictEqual(s.requests.length, 4);
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
  s.send(options('traffic_graph.lua')); assert.strictEqual(s.requests.length, 3);
  s.send(options('internet.lua?extra=1')); assert.strictEqual(s.requests.length, 4);
}
console.log('dashboard batching lifecycle OK');
