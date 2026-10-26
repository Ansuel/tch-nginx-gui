"""Regression tests for the TG-1/VANT-5 nginx compatibility pass."""

import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "decompressed/gui_file/usr/share/transformer/scripts/compat_nginx.sh"

LEGACY_CONFIG = textwrap.dedent(
    """\
    error_log syslog:server=unix:/dev/log,facility=daemon,nohostname error;
    events { worker_connections 256; }
    http {
      init_by_lua '
        os.execute("true")
      ';
      init_worker_by_lua '
        local sessioncontrol = require("web.sessioncontrol")
        sessioncontrol.setManagerForPort("default", "80")
      ';
      server {
        listen 80;
        listen 443 ssl;
        listen 8443 ssl;
        ssl_certificate /etc/nginx/server.crt;
        ssl_certificate_key /etc/nginx/server.key;
      }
    }
    """
)


class LegacyNginxCompatibility(unittest.TestCase):
    def run_compat(self, config, validator):
        base = Path(self.tempdir.name)
        config_path = base / "nginx.conf"
        nginx_path = base / "nginx"
        config_path.write_text(config)
        nginx_path.write_text("#!/bin/sh\n" + validator)
        nginx_path.chmod(0o755)
        env = {
            **os.environ,
            "FORCE_LEGACY_NGINX": "1",
            "NGINX_CONFIG": str(config_path),
            "NGINX_BIN": str(nginx_path),
        }
        result = subprocess.run(["sh", str(SCRIPT)], env=env, text=True, capture_output=True)
        return result, config_path.read_text()

    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tempdir.cleanup()

    def test_valid_modern_config_is_untouched(self):
        result, actual = self.run_compat(LEGACY_CONFIG, "exit 0\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actual, LEGACY_CONFIG)

    def test_legacy_directives_are_adapted_in_sequence(self):
        validator = textwrap.dedent(
            """\
            config="$3"
            if grep -q init_worker_by_lua "$config"; then
              echo 'unknown directive "init_worker_by_lua"' >&2
              exit 1
            fi
            if grep -q ' ssl;' "$config"; then
              echo 'the "ssl" parameter requires ngx_http_ssl_module' >&2
              exit 1
            fi
            if grep -q '^error_log syslog:' "$config"; then
              echo 'invalid parameter "facility=daemon" in error_log' >&2
              exit 1
            fi
            exit 0
            """
        )
        result, actual = self.run_compat(LEGACY_CONFIG, validator)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("init_worker_by_lua", actual)
        self.assertIn('sessioncontrol.setManagerForPort("default", "80")', actual)
        self.assertNotIn(" ssl;", actual)
        self.assertNotIn("ssl_certificate", actual)
        self.assertIn("listen 80;", actual)
        self.assertIn("error_log /dev/null;", actual)

    def test_unrecognised_failure_restores_original_config(self):
        result, actual = self.run_compat(LEGACY_CONFIG, "echo 'unknown directive foo' >&2\nexit 1\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(actual, LEGACY_CONFIG)
        self.assertIn("Legacy nginx compatibility failed", result.stderr)


if __name__ == "__main__":
    unittest.main()
