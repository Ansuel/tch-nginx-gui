"""Exercise session expiry and timer recovery with a simulated monotonic clock."""
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file/usr/lib/lua'
LUA = shutil.which('luajit') or shutil.which('lua')

HARNESS = r'''
local now, serial, cookie = 0, 0, nil
local logs, pending, timerCalls = {}, {}, 0
local failTimer = false
string.untaint = function(value) return value end
local config = {timeout='30', cookiepath='/', authpath='/auth',
                passpath='/password', loginpath='/login'}
package.preload.datamodel = function()
  return {get=function(path)
    assert(path == 'uci.web.')
    local rows = {}
    for key, value in pairs(config) do
      rows[#rows+1] = {path='uci.web.sessionmgr.@default.', param=key, value=value}
    end
    return rows
  end}
end
package.preload.srp = function() return {} end
package.preload['web.check_host'] = function() return {} end
package.preload['web.web'] = function()
  return {get_cookies=function() return {sessionID=cookie} end}
end
package.preload['tch.posix'] = function()
  return {CLOCK_MONOTONIC=1, clock_gettime=function() return now end}
end
package.preload['web.session'] = function()
  return {new=function(address, mgr)
    serial = serial + 1
    local session = {sessionid=string.format('%064x', serial), mgr=mgr,
      remoteIP=address.remote, timestamp=now,
      getrole=function() return 'guest' end,
      isUserAllowedByIP=function() return true end}
    session.proxy = session
    return session
  end}
end
ngx = {ERR=3, WARN=2, HTTP_SERVICE_UNAVAILABLE=503, header={}, ctx={},
  var={remote_addr='192.168.0.10', server_addr='192.168.0.1',
       server_port='80', uri='/login'},
  get_phase=function() return 'access' end,
  redirect=function() error('unexpected redirect') end,
  log=function(_, ...)
    local parts = {...}
    for i, value in ipairs(parts) do parts[i] = tostring(value) end
    logs[#logs+1] = table.concat(parts)
  end,
  exit=function(code) error('HTTP '..code, 0) end,
  timer={at=function(delay, callback, mgr)
    timerCalls = timerCalls + 1
    if failTimer then return nil, 'too many pending timers' end
    pending[#pending+1] = {delay=delay, callback=callback, mgr=mgr}
    return true
  end}}
local SessionMgr = require('web.sessionmgr')
local function manager()
  return SessionMgr.new('default', config, {})
end
local function request(mgr, id, ip, noActivity)
  cookie = id
  ngx.var.remote_addr = ip or '192.168.0.10'
  ngx.header, ngx.ctx = {}, {}
  local ok, err = pcall(function() mgr:checkrequest(noActivity) end)
  if not ok then return nil, err end
  return ngx.ctx.session
end
local function assertCounts(mgr, expected)
  local count, ips = 0, {}
  for _, session in pairs(mgr.sessions) do
    count = count + 1
    ips[session.remoteIP] = (ips[session.remoteIP] or 0) + 1
  end
  assert(count == expected and mgr._session_tracker.count == expected)
  for ip, value in pairs(mgr._session_tracker.ipcount) do
    assert(value == (ips[ip] or 0))
  end
  for ip, value in pairs(ips) do
    assert(mgr._session_tracker.ipcount[ip] == value)
  end
end
local function controller()
  local control = require('web.sessioncontrol')
  control.setManagerForPort('default', '80')
  return control
end
local function fireTimer(premature)
  local timer = table.remove(pending, 1)
  assert(timer, 'expected pending cleanup timer')
  timer.callback(premature or false, timer.mgr)
end
'''


@unittest.skipUnless(LUA, 'Lua interpreter required')
class Sessions(unittest.TestCase):
    def run_lua(self, script):
        result = subprocess.run(
            [LUA, '-'],
            input=f'package.path = {str(ROOT / "?.lua")!r} .. ";" .. package.path\n'
                  + HARNESS + script,
            text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_expired_sessions_free_capacity_in_same_request(self):
        self.run_lua(r'''
for _, perIP in ipairs({false, true}) do
  now = 0
  local mgr = manager()
  if perIP then mgr.maxsessions_per_ip=2 else mgr.maxsessions=2 end
  local first = assert(request(mgr))
  local otherIP
  if not perIP then otherIP = '192.168.0.11' end
  local second = assert(request(mgr, nil, otherIP))
  now = 1800
  local third = assert(request(mgr))
  assert(third ~= first and third ~= second)
  assertCounts(mgr, 1)
  assert(ngx.header['Set-Cookie']:find(third.sessionid, 1, true))
end
''')

    def test_active_sessions_remain_protected_by_both_limits(self):
        self.run_lua(r'''
for _, perIP in ipairs({false, true}) do
  now = 0
  local mgr = manager()
  if perIP then mgr.maxsessions_per_ip=1 else mgr.maxsessions=1 end
  local first = assert(request(mgr))
  now = 1799
  local refused, err = request(mgr)
  assert(not refused and err == 'HTTP 503')
  local diagnostic = logs[#logs-1]
  assert(diagnostic:find('total=1/', 1, true))
  assert(diagnostic:find('per_ip=1/', 1, true))
  assert(not diagnostic:find(first.sessionid, 1, true))
  assertCounts(mgr, 1)
  assert(mgr.sessions[first.sessionid] == first)
  assert(request(mgr, first.sessionid) == first)
  assert(first.timestamp == now)
end
''')

    def test_browser_session_survives_days_without_allocating_more_slots(self):
        self.run_lua(r'''
local mgr = manager()
local first = assert(request(mgr))
for minute=1, 3*24*60 do
  now = minute*60
  assert(request(mgr, first.sessionid) == first)
  assertCounts(mgr, 1)
end
assert(serial == 1)
''')

    def test_cookie_loss_and_different_ips_do_not_accumulate_expired_slots(self):
        self.run_lua(r'''
local mgr = manager()
mgr.maxsessions=3
for i=1, 100 do
  now = i*1800
  assert(request(mgr, nil, 'client-'..i))
  assert(mgr._session_tracker.count <= 3)
end
now = now+1800
assert(mgr:cleanup() == 0)
assertCounts(mgr, 0)
assert(next(mgr._session_tracker.ipcount) == nil)
''')

    def test_background_polling_does_not_extend_idle_session(self):
        self.run_lua(r'''
local mgr = manager()
mgr.maxsessions_per_ip=1
local first = assert(request(mgr))
now = 1799
assert(request(mgr, first.sessionid, nil, true) == first)
assert(first.timestamp == 0)
now = 1800
local second = assert(request(mgr, first.sessionid, nil, true))
assert(second ~= first and mgr.sessions[first.sessionid] == nil)
assertCounts(mgr, 1)
''')

    def test_identity_rotation_and_ip_binding_preserve_counts(self):
        self.run_lua(r'''
local mgr = manager()
mgr.maxsessions=1
local first = assert(request(mgr))
local oldID = first.sessionid
first.sessionid = 'rotated-identity'
assert(request(mgr, oldID) == first)
assert(mgr.sessions[oldID] == nil)
assert(mgr.sessions[first.sessionid] == first)
assertCounts(mgr, 1)
local refused, err = request(mgr, first.sessionid, '192.168.0.99')
assert(not refused and err == 'HTTP 503')
assert(first.remoteIP == '192.168.0.10')
assert(request(mgr, {'unknown', first.sessionid}) == first)
assertCounts(mgr, 1)
''')

    def test_failed_initial_timer_does_not_break_requests_and_can_retry(self):
        self.run_lua(r'''
local control = controller()
failTimer = true
local mgr = assert(control.getmgr())
assert(not mgr.timerset and timerCalls == 1)
assert(request(mgr))
now = 1800
assert(control.getmgr() == mgr)
assertCounts(mgr, 0)
assert(request(mgr))
failTimer = false
assert(control.getmgr() == mgr)
assert(mgr.timerset and #pending == 1 and timerCalls == 3)
assert(control.getmgr() == mgr and timerCalls == 3)
''')

    def test_failed_timer_reschedule_recovers_on_next_request(self):
        self.run_lua(r'''
local control = controller()
local mgr = assert(control.getmgr())
local session = assert(request(mgr))
now = 1799
assert(request(mgr, session.sessionid))
now = 1800
failTimer = true
fireTimer()
assert(not mgr.timerset and #pending == 0)
assertCounts(mgr, 1)
failTimer = false
assert(control.getmgr() == mgr and mgr.timerset and #pending == 1)
now = 3600
fireTimer()
assertCounts(mgr, 0)
assert(not mgr.timerset and #pending == 0)
''')

    def test_timer_tracks_refreshed_session_until_it_expires(self):
        self.run_lua(r'''
local control = controller()
local mgr = assert(control.getmgr())
local session = assert(request(mgr))
assert(pending[1].delay == 1800)
now = 1799
assert(request(mgr, session.sessionid))
now = 1800
fireTimer()
assert(mgr.timerset and #pending == 1 and pending[1].delay == 1799)
now = 3599
fireTimer()
assert(not mgr.timerset and #pending == 0)
assertCounts(mgr, 0)
''')

    def test_cleanup_error_does_not_leave_a_phantom_timer(self):
        self.run_lua(r'''
local control = controller()
local mgr = assert(control.getmgr())
local cleanup = mgr.cleanup
mgr.cleanup = function() error('cleanup interrupted') end
assert(not pcall(fireTimer))
assert(not mgr.timerset and #pending == 0)
mgr.cleanup = cleanup
assert(control.getmgr() == mgr and mgr.timerset and #pending == 1)
''')


if __name__ == '__main__':
    unittest.main()
