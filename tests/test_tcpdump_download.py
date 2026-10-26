"""Execute the download and button-rendering paths with failed/valid captures."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'decompressed/gui_file/www/docroot/modals/diagnostics-tcpdump-modal.lp'


def regression_script():
    source = SOURCE.read_text()
    functions = source[source.index('local capture_unavailable'):source.index('local function restartTest')]
    render = source[source.index('  html = {}'):source.index('  html[#html + 1] = ui_helper.createInputCheckbox')]
    return r'''
local T = function(s) return s end
local untaint = string.untaint or function(s) return s end
local taint = string.taint or function(s) return s end
local path_tcpdump = 'rpc.system.tcpdump.'
local config, output, closed, opened, reads, exitCode
local ngx = {HTTP_OK=200, HTTP_NOT_FOUND=404, HTTP_CONFLICT=409,
 HTTP_SERVICE_UNAVAILABLE=503, ERROR=-1}
ngx.print = function(s)
 if config.printError then return nil, 'closed' end
 output[#output+1] = untaint(s)
 return true
end
ngx.flush = function() return not config.flushError end
ngx.exit = function(code) exitCode = code; return code end
local content_helper = {getExactContent=function(t)
 t.state = taint(config.state or 'Complete')
 t.file = config.path and taint(config.path)
 return not config.backendError
end}
local lfs = {attributes=function(path)
 assert(path == config.path)
 if config.missing then return nil end
 return {mode=config.mode or 'file', size=config.size or #config.body}
end}
local open = function(path, mode)
 opened = opened + 1
 assert(path == config.path and mode == 'rb')
 if config.openError then return nil end
 local offset = 1
 return {
 read=function(_, size)
  assert(size == 1024)
  reads = reads + 1
  if config.readError == reads then return nil, 'I/O error' end
  if offset > #config.body then return nil end
  local chunk = config.body:sub(offset, offset+size-1)
  offset = offset + #chunk
  return chunk
 end,
 close=function() closed=closed+1 end
 }
end
''' + functions + r'''
local function run(options)
 config = {path='/tmp/tcpdumpGUI.pcap', body=('a'..string.char(0,255)):rep(1000)}
 for k,v in pairs(options) do config[k]=v end
 output, closed, opened, reads, exitCode = {}, 0, 0, 0, nil
 ngx.header, ngx.status = {}, 200
 tcpdump_download()
end
local failures = {
 {backendError=true, status=503},
 {state='Requested', status=409},
 {state='None', status=409},
 {state='Error', status=409},
 {path=false, status=404},
 {path='', status=404},
 {path='/tmp/', status=404},
 {path='/tmp/bad"name.pcap', status=404},
 {path='/tmp/bad\r\nname.pcap', status=404},
 {missing=true, status=404},
 {mode='directory', status=404},
 {size=0, status=404},
 {openError=true, status=404},
 {readError=1, status=404},
 {body='', size=100, status=404}
}
for _, failure in ipairs(failures) do
 run(failure)
 assert(ngx.status == failure.status, 'incorrect failure status')
 assert(exitCode == ngx.HTTP_OK)
 assert(ngx.header.set_cookie == nil and ngx.header.content_disposition == nil)
 assert(ngx.header.content_type == 'text/html; charset=utf-8')
 assert(table.concat(output):find('Run a new capture', 1, true))
 assert(closed == (opened > 0 and not config.openError and 1 or 0))
end
for _, path in ipairs({'/tmp/tcpdumpGUI.pcap', '/tmp/tcpdumpGUI.log', '/mnt/USB disk/tcpdumpGUI.pcap'}) do
 run({path=path})
 assert(exitCode == 200 and ngx.status == 200 and closed == 1)
 assert(table.concat(output) == config.body and reads > 2)
 assert(ngx.header.content_length == #config.body)
 assert(ngx.header.set_cookie == 'fileDownload=true; Path=/')
 assert(ngx.header.content_disposition:find(path:match('/([^/]+)$'), 1, true))
end
for _, failure in ipairs({{readError=2}, {printError=true}, {flushError=true}}) do
 run(failure)
 assert(exitCode == ngx.ERROR and closed == 1)
end
-- Exercise the actual rendering block: nil sizes used to expose Download.
local ui_helper = {
 createButton=function() return 'download' end,
 createAlertBlock=function(text) return untaint(text) end
}
local tcpdump_data, html
local function render()
''' + render + r'''
 return table.concat(html, '\n')
end
for _, scenario in ipairs({{}, {missing=true}, {size=0}, {mode='directory'}, {path=''}}) do
 run(scenario)
 tcpdump_data = {state='Complete', saveonusb='0', file=taint(config.path)}
 local result = render()
 local available = not (config.missing or config.size == 0 or config.mode == 'directory' or config.path == '')
 assert((result:find('download', 1, true) ~= nil) == available)
 if not available then assert(result:find('Run a new capture', 1, true)) end
end
for _, state in ipairs({'None', 'Requested', 'Error'}) do
 tcpdump_data.state = state
 assert(render() == '')
end
tcpdump_data.state, tcpdump_data.saveonusb = 'Complete', '1'
assert(render() == '')
print('TCPDump: failure, binary streaming, cleanup and button rendering cases passed')
'''


@unittest.skipUnless(shutil.which('lua'), 'Lua interpreter required')
class TCPDumpDownload(unittest.TestCase):
    def test_download_and_rendering(self):
        result = subprocess.run(['lua', '-'], input=regression_script(), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
