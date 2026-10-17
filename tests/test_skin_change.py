"""Run the skin change callback without the nonstandard browser window.event."""
from pathlib import Path
import json
import shutil
import subprocess
import unittest


@unittest.skipUnless(shutil.which('node'), 'Node.js required')
class SkinChangeTest(unittest.TestCase):
    def test_repeated_changes_without_global_event(self):
        root = Path(__file__).resolve().parents[1]
        source = (root / 'decompressed/gui_file/www/docroot/modals/modgui-modal.lp').read_text()
        start = source.index('  $("#gui_skin").on("change"')
        end = source.index('  $("#btn-gen-backup")', start)
        callback = source[start:end].replace('\\\n', '\n').replace("\\'", "'")
        script = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
let handler, firstpage = 'cards', disabled = false;
const previews = [];
const option = {
    is: () => firstpage === 'cards',
    attr: () => { disabled = true; },
    removeAttr: () => { disabled = false; }
};
const context = {
    schedulReload: false,
    modgui: {freshStyle: path => previews.push(path)},
    $: selector => {
        if (typeof selector === 'object') return {val: () => selector.theme};
        if (selector === '#gui_skin') return {on: (event, cb) => {handler = cb;}};
        if (selector === '#gui_skin_firstpage') return {val: value => {firstpage = value;}};
        return option;
    }
};
vm.createContext(context);
'''
        script += 'vm.runInContext(' + json.dumps(callback) + ', context);\n'
        script += r'''
// No global event is provided: Firefox and other browsers need none here.
for (const theme of ['blue', 'violet', 'green', 'TIM', 'dark-blue-unified',
                     'Fritz', 'dark-white_Fritz', 'dark-midnight_Fritz', 'dark-red', 'green']) {
    context.schedulReload = false;
    firstpage = 'cards';
    const count = previews.length;
    handler.call({theme}, {type: 'change'});
    assert.equal(context.schedulReload, true, theme);
    const restricted = theme.includes('Fritz') || theme.includes('unified');
    assert.equal(disabled, restricted, theme);
    assert.equal(firstpage, restricted ? 'stats' : 'cards', theme);
    assert.equal(previews.length, count + (theme.includes('Fritz') ? 0 : 1), theme);
    if (!theme.includes('Fritz')) assert.equal(previews.at(-1), theme + '/style.css');
}
'''
        result = subprocess.run(['node', '-e', script], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
