const fs = require('fs'), vm = require('vm'), assert = require('assert');
const script = fs.readFileSync('decompressed/gui_file/www/docroot/js/easy-mesh-configuration.js', 'utf8');
const shared = fs.readFileSync('decompressed/gui_file/www/docroot/js/main-min-nojquery.js', 'utf8');
const start = shared.indexOf('function () {', shared.indexOf('$(document).on("click", ".switch:not(.disabled)"'));
const widget = shared.slice(start, shared.indexOf('\n\t}),', start) + 3);

function load({agent='1', controller='1', confirm='false', agentOnly=false}={}) {
  let handlers = [], popups = 0;
  const document = {}, elements = {};
  function element(value='') {
    return {value, events: {}, classes: {}, length:1,
      val(v) { if (arguments.length) {this.value=v; return this;} return this.value; },
      closest() {return this===elements.easyMeshEnable ? toggle : this;},
      children(selector) {return selector==='.switcher' ? knob : elements.easyMeshEnable;},
      css() {return this;}, toggle() {return this;}, attr() {return undefined;},
      toggleClass(name,value) {this.classes[name]=arguments.length===2 ? value : !this.classes[name]; return this;},
      on(type,fn) {(this.events[type] ||= []).push(fn); return this;},
      trigger(type) {for (const fn of this.events[type] || []) fn.call(this); return this;}
    };
  }
  const toggle=element(), knob=element();
  const initial = agentOnly ? agent==='1' : agent==='1' || controller==='1';
  elements.easyMeshEnable=element(initial?'1':'0');
  for(const [id,value] of Object.entries({agentEnable:agent,controllerEnable:controller,
    wificonductorEnable:initial?'1':'0',wifibandsteerEnable:'0',wifiGuestbandsteerEnable:'0'})) elements[id]=element(value);
  const generic=element();
  const doc={off(type) {handlers=handlers.filter(h=>h.type!==type);return this;},
    one(type,selector,fn) {handlers.push({type,selector,fn});return this;}};
  function $(selector) {
    if(selector===document) return doc;
    if(typeof selector==='object') return selector;
    const ids=selector.split(',').map(x=>x.trim().match(/^#([\w]+)$/)?.[1]);
    if(ids.every(x=>x && elements[x])) {
      if(ids.length===1) return elements[ids[0]];
      return {val(v) {for(const id of ids) elements[id].val(v);return this;}};
    }
    return generic;
  }
  const context={$,document,multiapAgent:agent,multiapContr:controller,extenderInfo:'Extender Info',
    agentList:'Agent List',devicesList:'WiFi Devices',confirmPopup:confirm,easyMeshAgentOnly:agentOnly,
    bandsteerDisabled:false,isGuest:false,guestAP:[],content:{},ap0_state:'1',ap1_state:'1',
    easyMeshEnableMessage:'enabled',easyMeshDisableMessage:'disabled',enableTitle:'Enable',disableTitle:'Disable',
    confirmationDialogue() {popups++;},tch:{removeProgress() {}}};
  vm.createContext(context); vm.runInContext(script,context);
  const clickShared=vm.runInContext('('+widget+')',context);
  return {elements,knob,toggle,get popups(){return popups;},
    click() {
      // Direct parent handlers run first; the shared document handler then
      // toggles the input and emits change, exactly as in the real GUI.
      for(const fn of toggle.events.click || []) fn.call(toggle);
      clickShared.call(toggle);
    },
    confirm(id) {for(const h of [...handlers]) if(h.selector===id && handlers.includes(h)) {
      handlers=handlers.filter(x=>x!==h);h.fn();
    }},
    hidden() {return [elements.agentEnable.value,elements.controllerEnable.value];},
    get pending(){return handlers.length;}
  };
}
for(const [agent,controller] of [['1','1'],['1','0'],['0','1']]) {
 const s=load({agent,controller});s.click();
 assert.strictEqual(s.elements.easyMeshEnable.value,'0');assert.deepStrictEqual(s.hidden(),['0','0']);
 assert.strictEqual(s.popups,0);
 s.click();assert.deepStrictEqual(s.hidden(),['1','1']);
 assert.strictEqual(s.elements.wifibandsteerEnable.value,'0');
}
const confirmed=load({confirm:'true'});confirmed.click();
assert.deepStrictEqual(confirmed.hidden(),['1','1']);assert.strictEqual(confirmed.popups,1);
confirmed.confirm('#cancel');assert.strictEqual(confirmed.elements.easyMeshEnable.value,'1');
assert.strictEqual(confirmed.pending,0);assert.deepStrictEqual(confirmed.hidden(),['1','1']);
confirmed.click();confirmed.confirm('#ok');assert.deepStrictEqual(confirmed.hidden(),['0','0']);
assert.strictEqual(confirmed.pending,0);
confirmed.click();confirmed.confirm('#ok');assert.deepStrictEqual(confirmed.hidden(),['1','1']);
const agentOnly=load({agent:'1',controller:'0',agentOnly:true});
agentOnly.click();assert.deepStrictEqual(agentOnly.hidden(),['0','0']);
agentOnly.click();assert.deepStrictEqual(agentOnly.hidden(),['1','0']);
console.log('EasyMesh shared-widget ordering, mixed roles, confirmation/cancel and agent-only mode OK');
