"""Do not allow a forced redirect to an unavailable HTTPS listener."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('lua')


def regression_script():
    source = (ROOT / 'www/docroot/modals/modgui-modal.lp').read_text()
    block = source[source.index('local https_support = {}'):source.index('local https_available, https_reason')]
    return r'''
local rules, sockets, closes, policy_error = {}, {}, 0, nil
package.preload.uci = function() return {cursor = function() return {
 foreach = function(_, config, section, fn)
  assert(config == 'firewall' and section == 'rule')
  if policy_error == 'throw' then error('unavailable') end
  if policy_error == 'missing' then return nil end
  for _, rule in ipairs(rules) do fn(rule) end
  return true
 end,
 unload = function() end,
} end} end
io.open = function(path)
 local entries = sockets[path]
 if not entries then return nil end
 return {lines = function() local i = 0; return function() i=i+1; return entries[i] end end,
  close = function() closes = closes + 1 end}
end
''' + block + r'''
local helper = https_support
assert(not helper.available())
assert(helper.validate('0') and not helper.validate('1') and not helper.validate('yes'))
sockets['/proc/net/tcp'] = {' 0: 00000000:01BB 00000000:0000 0A 0:0'}
assert(helper.available() and helper.validate('1'))
local drop = {src='lan', proto='tcp', dest_port='443-444', target='DROP', family='ipv4'}
rules = {drop}
assert(not helper.available() and not helper.validate('1') and helper.validate('0'))
for key, value in pairs({enabled='0', dest='wan', src='wan', proto='udp', dest_port='8443',
 target='ACCEPT', src_ip='192.0.2.1', dest_ip='192.0.2.2', src_mac='00:11:22:33:44:55',
 src_port='1000', extra='--something', ipset='test', start_time='12:00', weekdays='Mon'}) do
 local saved = drop[key]; drop[key] = value
 assert(helper.available(), key); drop[key] = saved
end
for _, port in ipairs({'443', '80 443', '440:450', {'80', '443'}}) do
 drop.dest_port = port; assert(not helper.available())
end
drop.dest_port = '443'; drop.proto = {'udp', 'tcp'}
assert(not helper.available())
rules = {}
sockets['/proc/net/tcp'] = {'0: 0100007F:01BB 00000000:0000 0A 0:0'}
assert(not helper.available())
sockets['/proc/net/tcp6'] = {'0: 00000000000000000000000000000000:01BB 00000000000000000000000000000000:0000 0A 0:0'}
assert(helper.available())
assert(closes > 20)
for _, failure in ipairs({'throw', 'missing'}) do
 policy_error = failure
 assert(not helper.available() and not helper.validate('1') and helper.validate('0'))
end
'''


@unittest.skipUnless(LUA, 'Lua required')
class HttpsSupport(unittest.TestCase):
    def test_listener_and_lan_policy(self):
        result = subprocess.run([LUA, '-'], input=regression_script(), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejected_form_cannot_modify_live_redirect(self):
        source = (ROOT / 'www/docroot/modals/modgui-modal.lp').read_text()
        self.assertNotIn('mngr.force_https = post_args.gui_forcehttps', source)
        block = source[source.index('-- Update the live manager only'):source.index('local visibility_changed')]
        script = '''
local method, action, persisted, readable, live
ngx = {req = {get_method = function() return method end,
 get_post_args = function() return {action = action, gui_forcehttps = '1'} end}}
local content_helper = {getExactContent = function(data) data.force_https = persisted; return readable end}
package.preload['web.sessioncontrol'] = function() return {loadmgr = function() return live end} end
for _, request in ipairs({'GET', 'POST'}) do
 for _, command in ipairs({'SAVE', 'OTHER'}) do
  for _, saved in ipairs({'0', '1'}) do
   for _, available in ipairs({true, false}) do
    method, action, persisted, readable, live = request, command, saved, available, {force_https = '0'}
''' + block + '''
    assert(live.force_https == (request == 'POST' and command == 'SAVE' and available and saved or '0'))
   end
  end
 end
end
'''
        result = subprocess.run([LUA, '-'], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
