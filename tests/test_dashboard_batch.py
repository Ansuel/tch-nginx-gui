from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
LUA = shutil.which('luajit') or shutil.which('lua')


class DashboardBatch(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node required')
    def test_client_batch_lifecycle(self):
        result = subprocess.run(['node', 'tests/test_dashboard_batch.js'], cwd=ROOT,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(LUA, 'Lua required')
    def test_backend_whitelist_authorization_csrf_and_failure_isolation(self):
        script = r'''
local body, method, session, selected, captures, output, exited
local allowed, replies = {}, {}
package.preload.dkjson = function() return {
  encode = function(value) output = value; return '{}' end,
  decode = function(value)
    if value == 'valid' then return {value = 1}, 6 end
    if value == 'trailing' then return {value = 1}, 3 end
    return nil, 1, 'invalid JSON'
  end,
} end
session = {hasAccess = function(_, uri) return allowed[uri] == true end}
ngx = {ctx = {}, header = {}, HTTP_OK = 200, HTTP_POST = 8,
  req = {get_method = function() return method end,
    get_post_args = function() if not body then error('invalid CSRF') end; return {modules = selected} end,
    get_body_data = function() return 'CSRFtoken=test&modules=' .. selected end},
  say = function() end, exit = function(code) exited = code end,
  location = {capture_multi = function(requests)
    captures = requests
    for _, request in ipairs(requests) do
      assert(allowed[request[1]] and request[2].ctx.session == session)
      assert(request[2].method == 8 and request[2].body:find('CSRFtoken=test', 1, true))
    end
    return unpack(replies)
  end},
}
'''
        script += f'local endpoint = assert(loadfile({str(ROOT / "decompressed/gui_file/www/docroot/ajax/dashboard_sync.lua")!r}))\n'
        script += r'''
local function run(value)
  ngx.ctx.session = session; ngx.status = nil; output = nil; captures = nil
  selected = value; method = 'POST'; body = true
  endpoint()
end
allowed['/ajax/cpuload.lua'] = true
replies = {{status = 200, body = 'valid'}}
run('gateway,ports')
assert(#captures == 1 and output.modules.gateway.data.value == 1)
assert(output.modules.ports.status == 403)
assert(ngx.header['Cache-Control'] == 'no-store')
allowed['/ajax/internet.lua'] = true
replies = {{status = 500, body = 'broken', header = {['error-msg'] = 'backend'}},
           {status = 200, body = 'valid'}}
run('gateway,xdsl')
assert(output.modules.gateway.status == 500 and output.modules.gateway.error == 'backend')
assert(output.modules.xdsl.status == 200 and captures[2][2].args.datatype == 'xdsl')
replies = {{status = 200, body = 'trailing'}}
run('gateway'); assert(output.modules.gateway.data == nil)
for _, value in ipairs({'gateway,gateway', 'unknown', 'gateway,,ports', ',gateway', 'gateway,', '', '../../secret', {}}) do
  run(value); assert(ngx.status == 400 and not captures)
end
method = 'GET'; ngx.ctx.session = nil; endpoint(); assert(ngx.status == 403)
ngx.ctx.session = session; method = 'POST'; body = false
assert(not pcall(endpoint), 'CSRF validation errors must not be bypassed')
'''
        result = subprocess.run([LUA, '-'], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
