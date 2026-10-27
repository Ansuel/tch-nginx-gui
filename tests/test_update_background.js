const fs = require('fs'), vm = require('vm'), assert = require('assert');
const source = fs.readFileSync('decompressed/gui_file/www/docroot/js/shared-script.js', 'utf8');
const handlers = {}, requests = [], errors = [], timers = new Map();
let spinning = false, modal = 0, counter = 0, now = 0, label = '';
function $(selector) {
  return {attr(key, value) {if (value !== undefined) return this; return selector === 'meta[name=CSRFtoken]' ? 'csrf' : undefined;},
    off() {return this;}, on(name, fn) {handlers[selector] = fn; return this;},
    addClass(name) {if (name === 'fa-spin') spinning = true; return this;},
    removeClass(name) {if (name === 'fa-spin') spinning = false; return this;},
    remove() {return this;}, parent() {return this;}, appendTo() {errors.push(this.value); return this;},
    text(value) {this.value = value; if(selector === '.gui_version_status_text') label = value; return this;},
    each() {return this;}, toggleClass() {return this;}};
}
$.ajax = options => {
  const callbacks = {};
  const request = {options,
    done(fn) {callbacks.done = fn; return this;}, fail(fn) {callbacks.fail = fn; return this;}, always(fn) {callbacks.always = fn; return this;},
    resolve(data) {callbacks.done(data); if(callbacks.always) callbacks.always();},
    reject(data) {callbacks.fail(data); if(callbacks.always) callbacks.always();}};
  requests.push(request); return request;
};
const context = {$, KoRequest: {}, gui_var: {gui_updated:'updated',gui_outdated:'outdated'},
  Date: {now:()=>now}, postAction() {modal++;}, tch:{elementCSRFtoken:()=>({})},
  setInterval(fn) {timers.set(++counter,fn); return counter;}, clearInterval(id) {timers.delete(id);}};
vm.createContext(context);
vm.runInContext(source.slice(source.indexOf('\tfunction linkCheckUpdate()'),source.indexOf('\n\tfunction freshStyle')),context);
context.linkCheckUpdate();
const event = {preventDefault(){},stopPropagation(){}};
function click() {handlers['.check_update'](event);}
click(); click(); assert.equal(requests.length,1); assert(spinning); assert.equal(timers.size,0);
requests[0].resolve({success:'true'}); assert.equal(requests.length,2);
assert.equal(requests[1].options.url, '/modals/modgui-modal.lp?auto_update=true');
assert.equal(requests[1].options.data.action, 'get_update_status'); assert.equal(timers.size,1);
requests[1].resolve({state:'Checking',new_version_text:'Unknown'}); assert.equal(label,'');
timers.values().next().value(); requests[2].resolve({state:'Error',log:'HTTP 404'});
assert(!spinning); assert.equal(timers.size,0); assert.equal(errors.pop(),'HTTP 404'); assert.equal(modal,0);
click(); requests[3].reject({responseJSON:{error:'busy'}}); assert.equal(errors.pop(),'busy'); assert(!spinning);
click(); requests[4].resolve({success:true}); requests[5].resolve({state:'Complete',new_version_text:'9.9.0'});
assert.equal(label,'outdated'); assert(!spinning); assert.equal(timers.size,0);
click(); requests[6].resolve({success:true}); requests[7].resolve({state:'Complete',new_version_text:'Unknown'});
assert.equal(label,'updated'); assert(!spinning);
click(); requests[8].resolve({success:true}); requests[9].reject({status:0}); assert(!spinning); assert.equal(timers.size,0);
click(); requests[10].resolve({success:true}); now=100000; timers.values().next().value(); assert(!spinning); assert.equal(timers.size,0);
assert.equal(modal,0);
console.log('Background update: acceptance, duplicates, error, success, network failure and deadline passed');
