"""Execute the RPC shell wrapper with both timeout command-line dialects."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LUA = shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua required')
class SmartphoneTimeoutTest(unittest.TestCase):
    def test_deadline_keeps_usb_identity_and_reports_telemetry_failure(self):
        for status, code in [('124', 'telemetry_timeout'), ('137', 'telemetry_timeout'), ('1', 'helper_error')]:
            with self.subTest(status=status):
                result = subprocess.run([LUA, '-', str(ROOT), status, code], input=r'''
local calls = 0
io.popen = function(command)
    calls = calls + 1
    if calls == 1 then
        return {read = function() return "\nEXIT_STATUS|" .. arg[2] .. "\n" end, close = function() end}
    end
    assert(command:find('get_usb_info', 1, true), command)
    return {read = function() return "USB_DEV|Example phone\nUSB_ADB|1\nHOST_IF|usb0\n" end, close = function() end}
end
local mapping
register = function(value) mapping = value end
assert(loadfile(arg[1] .. '/decompressed/smartphone/usr/share/transformer/mappings/rpc/smartphone.map'))()
local stats = mapping.get.stats()
assert(stats:find('ERROR_CODE|' .. arg[3], 1, true), stats)
assert(stats:find('USB_DEV|Example phone', 1, true), stats)
assert(stats:find('HOST_IF|usb0', 1, true), stats)
assert(calls == 2)
''', text=True, capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rpc_preserves_usb_diagnostics_with_old_and_new_timeout(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            timeout = folder / 'timeout'
            timeout.write_text('''#!/bin/sh
if [ "$1" = --help ]; then
    if [ "$LEGACY" = 1 ]; then echo 'Usage: timeout [-t SECS] PROG ARGS';
    else echo 'Usage: timeout SECS PROG ARGS'; fi
    exit 0
fi
if [ "$LEGACY" = 1 ]; then [ "$1" = -t ] || exit 90; shift; fi
[ "$1" = 18 ] || exit 91
shift
exec "$@"
''')
            helper = folder / 'phone_stats.sh'
            helper.write_text('''#!/bin/sh
printf 'ERROR|Enable USB debugging\nERROR_CODE|usb_only\nUSB_DEV|moto g32\nUSB_ADB|0\n'
exit 1
''')
            timeout.chmod(0o755)
            helper.chmod(0o755)
            for legacy in ('0', '1'):
                with self.subTest(legacy=legacy):
                    result = subprocess.run([LUA, '-', str(ROOT)], input=r'''
local original = io.popen
io.popen = function(command)
    return original((command:gsub('/usr/bin/phone_stats.sh', os.getenv('HELPER'))))
end
local mapping
register = function(value) mapping = value end
assert(loadfile(arg[1] .. '/decompressed/smartphone/usr/share/transformer/mappings/rpc/smartphone.map'))()
local stats = mapping.get.stats()
assert(stats:find('ERROR_CODE|usb_only', 1, true), stats)
assert(stats:find('USB_DEV|moto g32', 1, true), stats)
assert(stats:find('USB_ADB|0', 1, true), stats)
''', text=True, capture_output=True, timeout=5,
                        env={**os.environ, 'PATH': directory + ':/usr/bin:/bin',
                             'LEGACY': legacy, 'HELPER': str(helper)})
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
