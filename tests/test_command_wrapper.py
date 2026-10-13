"""Exercise log collection and terminal state without a router."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest


WRAPPER = Path(__file__).resolve().parents[1] / "decompressed/gui_file/usr/share/transformer/scripts/wrapper.sh"


class CommandWrapper(unittest.TestCase):
    def run_command(self, status):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "command_log"
            states = root / "states"
            wrapper = root / "wrapper.sh"
            wrapper.write_text(WRAPPER.read_text().replace("LOG_LOCATION=/tmp/command_log", f"LOG_LOCATION={log}"))
            lua = root / "lua"
            lua.write_text('#!/bin/sh\nprintf "%s\\n" "$2" >> "$TEST_STATES"\n')
            lua.chmod(0o755)
            command = root / "command.sh"
            command.write_text(f'#!/bin/sh\necho first\necho error >&2\necho last\nexit {status}\n')
            command.chmod(0o755)
            result = subprocess.run(
                ["sh", str(wrapper), str(command)],
                env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}", "TEST_STATES": str(states)},
                capture_output=True, text=True, timeout=5,
            )
            return result, log.read_text(), states.read_text()

    def test_stdout_and_stderr_are_preserved_in_order(self):
        result, log, states = self.run_command(0)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(log, "first\nerror\nlast\n")
        self.assertIn("Requested", states)
        self.assertIn("Complete", states)
        self.assertNotIn("Idle", states)

    def test_failure_keeps_output_and_completes_polling(self):
        result, log, states = self.run_command(7)
        self.assertEqual(result.returncode, 7)
        self.assertIn("first\nerror\nlast\n", log)
        self.assertIn("exit status 7", log)
        self.assertIn("Complete", states)


if __name__ == "__main__":
    unittest.main()
