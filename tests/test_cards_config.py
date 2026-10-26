"""Card indexes must remain fresh across requests and preserve access policy."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('luajit') or shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua required')
class CardsConfig(unittest.TestCase):
    def run_cards(self, scenario):
        script = r'''
local cursors, scans, unloads = 0, 0, 0
local rules = {{['.name'] = 'alpha', target = '/alpha.lp'},
               {['.name'] = 'beta', target = '/beta.lp'},
               {['.name'] = 'gamma', target = '/gamma.lp'}}
local entries = {{modal = 'alpha', card = '001_alpha.lp'},
                 {modal = 'beta', card = '002_beta.lp', hide = '0'},
                 {modal = 'gamma', card = '003_gamma.lp', hide = '1'}}
local files = {['/cards'] = {'003_gamma.lp', '002_beta.lp', '001_alpha.lp', 'note.txt'},
               ['/info'] = {'010_stats.lp'}}
package.preload.uci = function() return {cursor = function()
  cursors = cursors + 1
  return {foreach = function(_, config, section, callback)
    assert(config == 'web')
    scans = scans + 1
    for _, value in ipairs(section == 'rule' and rules or entries) do callback(value) end
  end, unload = function(_, config) assert(config == 'web'); unloads = unloads + 1 end}
end} end
package.preload.lfs = function() return {
  attributes = function(path, mode)
    assert(mode == 'mode'); if files[path] then return 'directory' end
    if path:match('^/www/cards/%d+_[%w_]+%.lp$') then return 'file' end
  end,
  dir = function(path)
    local i = 0
    return function() i = i + 1; return files[path][i] end
  end,
} end
local limited = {}
package.preload.cards_limiter = function() return {
  get_limit_info = function() return limited end,
  card_limited = function(info, name, path)
    assert(info == limited and files[path]); return info[name] == true
  end,
} end
local function context(allowed)
  return {session = {hasAccess = function(_, target) return allowed[target] == true end}}
end
ngx = {ctx = context({})}
'''
        script += f'local cards = assert(loadfile({str(ROOT / "www/lua/cards.lua")!r}))()\n'
        result = subprocess.run([LUA, '-'], input=script + scenario,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_index_once_per_request_without_mutating_uci_records(self):
        self.run_cards(r'''
assert(cursors == 0)
ngx.ctx = context({['/alpha.lp'] = true, ['/gamma.lp'] = true})
cards.setpath('/cards')
assert(table.concat(cards.cards(), ',') == '001_alpha.lp,002_beta.lp,003_gamma.lp')
for i = 1, 20 do
  assert(cards.get_card_from_modal('/alpha.lp') == '001_alpha.lp')
  assert(cards.get_modal_from_card('001_alpha.lp') == '/alpha.lp')
  assert(cards.get_modal_from_card('alpha.lp') == '/alpha.lp')
end
assert(cursors == 1 and scans == 2 and unloads == 1)
assert(entries[1].card == '001_alpha.lp' and entries[1].modal == 'alpha')
''')

    def test_existing_hide_semantics_and_limiter_are_preserved(self):
        self.run_cards(r'''
cards.setpath('/cards')
assert(table.concat(cards.cards(), ',') == '002_beta.lp')
assert(not cards.get_card_from_modal('/alpha.lp'))
assert(cards.get_card_from_modal('/beta.lp') == '002_beta.lp')
assert(not cards.get_card_from_modal('/gamma.lp'))
ngx.ctx.session = context({['/alpha.lp'] = true, ['/gamma.lp'] = true}).session
assert(cards.get_card_from_modal('/gamma.lp') == '003_gamma.lp')
limited['gamma.lp'] = true
assert(table.concat(cards.cards(), ',') == '001_alpha.lp,002_beta.lp')
''')

    def test_interleaved_requests_keep_paths_config_and_permissions_separate(self):
        self.run_cards(r'''
local first = context({['/alpha.lp'] = true})
ngx.ctx = first
cards.setpath('/cards')
assert(cards.get_card_from_modal('/alpha.lp') == '001_alpha.lp')
rules[1].target = '/new-alpha.lp'
ngx.ctx = context({})
cards.setpath('/info')
assert(cards.get_modal_from_card('alpha.lp') == '/new-alpha.lp')
assert(not cards.get_card_from_modal('/new-alpha.lp'))
assert(table.concat(cards.cards(), ',') == '010_stats.lp')
ngx.ctx = first
assert(cards.get_modal_from_card('alpha.lp') == '/alpha.lp')
assert(table.concat(cards.cards(), ',') == '001_alpha.lp,002_beta.lp')
assert(cursors == 2 and scans == 4 and unloads == 2)
''')

    def test_explicit_reload_and_next_request_observe_configuration_changes(self):
        self.run_cards(r'''
assert(cards.get_modal_from_card('alpha.lp') == '/alpha.lp')
rules[1].target = '/changed.lp'
cards.reload_config()
assert(cards.get_modal_from_card('alpha.lp') == '/changed.lp')
assert(not cards.get_card_from_modal('/alpha.lp'))
entries[1].hide = '0'
ngx.ctx = context({})
assert(cards.get_card_from_modal('/changed.lp') == '001_alpha.lp')
assert(cursors == 3 and scans == 6)
''')

    def test_malformed_config_and_query_values_do_not_raise_or_resolve(self):
        self.run_cards(r'''
for _, value in ipairs({false, 123, {}, '/not-configured.lp', '../../alpha.lp'}) do
  assert(not cards.get_card_from_modal(value))
  assert(not cards.get_modal_from_card(value))
end
assert(not cards.get_card_from_modal(nil) and not cards.get_modal_from_card(nil))
entries[#entries+1] = {modal = 'alpha'}
entries[#entries+1] = {modal = 'alpha', card = {}, hide = '0'}
entries[#entries+1] = {modal = 'alpha', card = '999_anonymous.lp', ['.anonymous'] = true}
entries[#entries+1] = {modal = 'missing', card = '999_missing.lp'}
cards.reload_config()
assert(not cards.get_modal_from_card('999_anonymous.lp'))
assert(not cards.get_modal_from_card('999_missing.lp'))
assert(cards.get_modal_from_card('002_beta.lp') == '/beta.lp')
assert(#cards.cards() == 0)
''')

    def test_tainted_strings_are_normalized_before_indexing(self):
        self.run_cards(r'''
if not string.taint then
  local values = {}
  string.taint = function(value) local proxy = newproxy(); values[proxy] = value; return proxy end
  string.untaint = function(value) return values[value] or value end
end
cards.setpath(string.taint('/cards'))
assert(cards.get_modal_from_card(string.taint('002_beta.lp')) == '/beta.lp')
assert(cards.get_card_from_modal(string.taint('/beta.lp')) == '002_beta.lp')
assert(table.concat(cards.cards(), ',') == '002_beta.lp')
''')

    def test_visibility_is_separate_from_access_and_does_not_hide_stats(self):
        self.run_cards(r'''
entries[1].visible = '0'
ngx.ctx = context({['/alpha.lp'] = true})
cards.setpath('/cards')
assert(table.concat(cards.cards(), ',') == '002_beta.lp')
assert(not cards.get_card_from_modal('/alpha.lp'))
files['/www/info-cards'] = {'001_alpha.lp'}
cards.setpath('/www/info-cards')
assert(table.concat(cards.cards(), ',') == '001_alpha.lp')
entries[1].visible = '1'
ngx.ctx = context({})
cards.setpath('/cards')
assert(table.concat(cards.cards(), ',') == '002_beta.lp')
''')

    def test_settings_include_hidden_authorized_cards_and_keep_settings_reachable(self):
        self.run_cards(r'''
entries[1]['.name'] = 'alpha_card'
entries[1].visible = '0'
entries[2]['.name'] = 'beta_card'
entries[3]['.name'] = 'gamma_card'
files['/www/cards'] = files['/cards']
entries[#entries+1] = {['.name'] = 'modgui_card', modal = 'beta', card = '001_modgui.lp', hide = '0', visible = '0'}
files['/cards'][#files['/cards']+1] = '001_modgui.lp'
ngx.ctx = context({['/alpha.lp'] = true})
cards.setpath('/cards')
local settings = cards.get_visibility_settings()
assert(#settings == 1 and settings[1].section == 'alpha_card')
assert(table.concat(cards.cards(), ',') == '001_modgui.lp,002_beta.lp')
limited['alpha.lp'] = true
assert(#cards.get_visibility_settings() == 0)
''')


if __name__ == '__main__':
    unittest.main()
