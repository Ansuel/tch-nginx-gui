"""Render the optional card and exercise its polling client without a phone."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
CARD = ROOT / 'decompressed/smartphone/www/cards/017_smartphone.lp'


class SmartphoneCard(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node.js required')
    def test_live_card_states_and_polling_lifecycle(self):
        result = subprocess.run(['node', 'tests/test_smartphone_card.js'], cwd=ROOT,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(shutil.which('lua'), 'Lua required')
    def test_card_renders_without_blocking_on_adb_and_respects_access(self):
        for access in ('yes', 'no'):
            result = subprocess.run(['lua', '-', str(CARD), access], input=r'''
local output = {}
T = function(value) return value end
gettext = {textdomain = function() end}
ngx = {ctx = {session = {hasAccess = function() return arg[2] == "yes" end}},
    print = function(...) for _, value in ipairs({...}) do output[#output + 1] = value end end}
package.preload["web.ui_helper"] = function() return {
    createCardHeader = function() return "Smartphone USB" end,
    createSimpleLight = function(_, text) return '<span class="simple-desc"><div class="light off"></div>' .. text .. '</span>' end
} end
package.preload["web.web"] = function() return {html_escape = function(value) return value end} end
package.preload.datamodel = function() error("Initial card rendering must not issue an ADB request") end
assert(loadfile(arg[1]))()
local html = table.concat(output)
assert(html:find('id="smartphone-card"', 1, true))
assert(html:find('class="bar-small bar-small5"', 1, true))
assert(html:find('data-bind="text: phoneBattery"', 1, true))
assert(html:find('href="/css/mobiled.css"', 1, true))
assert(not html:find('<style>', 1, true))
assert(not html:find('src="/js/smartphone-card.js"', 1, true))
assert((html:find('new modgui.createAjaxUpdateCard(', 1, true) ~= nil) == (arg[2] == "yes"))
''', text=True, capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
