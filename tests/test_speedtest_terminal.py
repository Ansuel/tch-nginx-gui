"""Exercise Ookla streaming through the command wrapper without a router."""

from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import time
import unittest


SCRIPTS = Path(__file__).resolve().parents[1] / "decompressed/gui_file/usr/share/transformer/scripts"


class SpeedtestTerminal(unittest.TestCase):
    @unittest.skipUnless(shutil.which("lua"), "Lua required")
    def test_terminal_progress_rendering(self):
        result = subprocess.run(
            ["lua", "-"], cwd=SCRIPTS.parents[5],
            input=r'''
local cases = {
    {"plain\nlog\n", "plain\nlog\n"},
    {"header\n\rDownload: 5%\rDownload: 50%\rDownload: 100%\n\rUpload: 2%", "header\nDownload: 100%\nUpload: 2%"},
    {"<unsafe>\n", "<unsafe>\n"},
    {"windows\r\nlog\r\n", "windows\nlog\n"},
}
local expected, input
package.preload["datamodel"] = function()
    return {get = function() return {{value = "Requested"}} end}
end
package.preload["dkjson"] = function()
    return {encode = function(data)
        assert(data.log == expected, string.format("Unexpected log: %q", data.log))
        assert(data.state == "Requested")
        return true
    end}
end
string.untaint = function(value) return value end
ngx = {say = function() end, exit = function() end, HTTP_OK = 200}
io.open = function(path)
    assert(path == "/tmp/command_log")
    return {read = function() return input end, close = function() end}
end
for _, case in ipairs(cases) do
    input, expected = case[1], case[2]
    assert(loadfile("decompressed/gui_file/www/docroot/ajax/commandlogread.lua"))()
end
''',
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_live_output_completion_and_failure(self):
        source = (SCRIPTS / "appInstallRemoveUtility.sh").read_text()
        start = source.index("app_speedtest() {")
        function = source[start:source.index("\napp_adguardhome()", start)]
        for status in (0, 7):
            with self.subTest(status=status), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "ookla").mkdir()
                binary = root / "ookla/speedtest"
                binary.write_text('''#!/bin/sh
echo "$*" > "$TEST_ROOT/args"
echo 'Download: testing'
while [ ! -f "$TEST_ROOT/release" ]; do sleep 0.05; done
echo 'Upload: testing' >&2
echo 'Result URL: https://example.test/result'
exit "$TEST_STATUS"
''')
                binary.chmod(0o755)
                command = root / "command.sh"
                command.write_text("#!/bin/sh\n" + function.replace("/opt/ookla", str(root / "ookla")).replace("/tmp/speedtest", str(root / "speedtest")) + "\napp_speedtest start\n")
                command.chmod(0o755)
                wrapper = root / "wrapper.sh"
                log = root / "command_log"
                wrapper.write_text((SCRIPTS / "wrapper.sh").read_text().replace("LOG_LOCATION=/tmp/command_log", f"LOG_LOCATION={log}"))
                lua = root / "lua"
                lua.write_text('#!/bin/sh\nprintf "%s\\n" "$2" >> "$TEST_ROOT/states"\n')
                lua.chmod(0o755)
                process = subprocess.Popen(
                    ["sh", str(wrapper), str(command)], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}", "TEST_ROOT": str(root), "TEST_STATUS": str(status)},
                )
                try:
                    deadline = time.monotonic() + 5
                    while not (log.exists() and "Download: testing" in log.read_text()):
                        if time.monotonic() > deadline or process.poll() is not None:
                            self.fail("Speedtest output did not reach the terminal while running")
                        time.sleep(0.02)
                    self.assertIsNone(process.poll())
                    self.assertNotIn("Complete", (root / "states").read_text())
                    self.assertTrue((root / "speedtest.pid").exists())
                    self.assertIn("--progress=yes", (root / "args").read_text())
                finally:
                    (root / "release").touch()
                    process.communicate(timeout=5)
                self.assertEqual(process.returncode, status)
                saved = (root / "speedtest-result.txt").read_text()
                self.assertEqual(saved, "Download: testing\nUpload: testing\nResult URL: https://example.test/result\n")
                self.assertTrue(log.read_text().startswith(saved))
                self.assertIn("Complete", (root / "states").read_text())
                if status:
                    self.assertIn("exit status 7", log.read_text())
                self.assertFalse((root / "speedtest.pid").exists())
                self.assertEqual(list(root.glob("speedtest-run.*")), [])


if __name__ == "__main__":
    unittest.main()
