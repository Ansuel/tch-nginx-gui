"""Exercise ULA prefix repair with an isolated UCI store and firmware helper."""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "decompressed/gui_file/etc/modgui_scripts/06_network.sh"
PREFIX = "network.globals.ula_prefix"
GENERATED = "fd12:3456:789a::/48"


class ULAPrefixTest(unittest.TestCase):
    def repair(self, prefix=None, backup=None, globals_section="globals", helper="ok"):
        source = SOURCE.read_text()
        function = source[source.index("fix_missing_ula_prefix() ("):
                          source.index("puryfy_wan_interface() {")]
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            state = base / "state"
            state.mkdir()
            values = {"network.globals": globals_section, PREFIX: prefix,
                      "network.globals.ula_prefix_backup": backup}
            for key, value in values.items():
                if value is not None:
                    (state / key).write_text(value)
            uci = base / "uci"
            uci.write_text('''#!/bin/sh
[ "$1" = "-q" ] && shift
case "$1" in
  get) [ -f "$STATE/$2" ] && cat "$STATE/$2" ;;
  set)
    printf '%s\\n' "$*" >> "$STATE/operations"
    key=${2%%=*}
    printf '%s' "${2#*=}" > "$STATE/$key"
    ;;
  delete)
    printf '%s\\n' "$*" >> "$STATE/operations"
    rm -f "$STATE/$2"
    ;;
  commit) printf '%s\\n' "$*" >> "$STATE/operations" ;;
  *) exit 2 ;;
esac
''')
            uci.chmod(0o755)
            generator = base / "12_network-generate-ula"
            if helper != "missing":
                body = 'echo called >> "$STATE/generator_calls"\n'
                if helper in ("ok", "fail_after_write"):
                    body += f"uci set {PREFIX}={GENERATED}\nuci commit network\n"
                body += "exit " + ("1" if helper.startswith("fail") else "0") + "\n"
                generator.write_text(body)
            function = function.replace(
                '"/rom/etc/uci-defaults/12_network-generate-ula"',
                shlex.quote(str(generator)),
            )
            script = function + '\nlogecho() { :; }\nfix_missing_ula_prefix\nfix_missing_ula_prefix\n'
            result = subprocess.run(
                ["sh", "-c", script], capture_output=True, text=True,
                env={**os.environ, "STATE": str(state), "PATH": str(base) + os.pathsep + os.environ["PATH"]},
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            actual = (state / PREFIX).read_text() if (state / PREFIX).exists() else None
            operations = (state / "operations").read_text() if (state / "operations").exists() else ""
            calls = (state / "generator_calls").read_text().splitlines() if (state / "generator_calls").exists() else []
            return actual, operations, calls

    def test_missing_empty_and_auto_are_repaired_once(self):
        for prefix in (None, "", "auto"):
            with self.subTest(prefix=prefix):
                actual, operations, calls = self.repair(prefix=prefix)
                self.assertEqual(actual, GENERATED)
                self.assertIn("commit network", operations)
                self.assertEqual(calls, ["called"])

    def test_existing_prefix_and_explicit_disable_are_untouched(self):
        for prefix in (GENERATED, "fdab:cdef:1234::/48", "none", "0"):
            with self.subTest(prefix=prefix):
                self.assertEqual(self.repair(prefix=prefix), (prefix, "", []))

    def test_saved_prefix_is_preserved(self):
        for prefix in (None, "auto", "none"):
            with self.subTest(prefix=prefix):
                self.assertEqual(self.repair(prefix=prefix, backup=GENERATED), (prefix, "", []))

    def test_unsupported_firmware_is_untouched(self):
        for options in ({"helper": "missing"}, {"globals_section": None},
                        {"globals_section": "other"}):
            with self.subTest(options=options):
                self.assertEqual(self.repair(**options), (None, "", []))

    def test_failure_or_no_generated_prefix_restores_previous_setting(self):
        for helper in ("fail", "fail_after_write", "empty"):
            for prefix in (None, "auto"):
                with self.subTest(helper=helper, prefix=prefix):
                    actual, operations, calls = self.repair(prefix=prefix, helper=helper)
                    self.assertEqual(actual, prefix)
                    self.assertIn("commit network", operations)
                    self.assertEqual(len(calls), 2)


if __name__ == "__main__":
    unittest.main()
