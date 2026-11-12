"""Exercise status reporting with a finished connect worker and a live daemon."""

from pathlib import Path
import socket
import subprocess
import tempfile
import unittest


STATUS = (Path(__file__).resolve().parents[1] / "decompressed/gui_file"
          / "usr/share/transformer/scripts/tailscaleStatus.sh")


class TailscaleStatus(unittest.TestCase):
    def test_status_uses_read_only_process_checks(self):
        for running, enabled, bootstrap, expected in ((True, True, False, "connected"),
                                                      (False, True, False, "stopped"),
                                                      (True, False, False, "stopped"),
                                                      (False, True, True, "starting")):
            with self.subTest(running=running, enabled=enabled, bootstrap=bootstrap), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                with socket.socket(socket.AF_UNIX) as daemon_socket:
                    daemon_socket.bind(str(root / "daemon.sock"))
                    source = STATUS.read_text().replace(
                        "/etc/init.d/tailscale", "mock_service").replace(
                        "/var/run/tailscale/tailscaled.sock", str(root / "daemon.sock")).replace(
                        "/tmp/modgui-tailscale-", str(root / "worker-"))
                    script = '''
uci() {
    case "$*" in
        *service.enabled) echo "$ENABLED" ;;
        *service.version) echo 1.104.5 ;;
        *service.download_url) : ;;
    esac
}
ip() { echo '    inet 100.64.0.1/32 scope global tailscale0'; }
mock_service() {
    echo 'PRIVILEGED_SERVICE_CHECK' >&2; return 1
}
pidof() { [ "$*" = tailscaled ] && [ "$RUNNING" = 1 ]; }
pgrep() { [ "$BOOTSTRAP" = 1 ]; }
''' + source
                    result = subprocess.run(
                        ["sh", "-c", f"ENABLED={int(enabled)}; RUNNING={int(running)}; BOOTSTRAP={int(bootstrap)};\n" + script],
                        capture_output=True, text=True, check=True)
                    status = dict(line.split("=", 1) for line in result.stdout.splitlines())
                    self.assertEqual(status["version"], "1.104.5")
                    self.assertEqual(status["phase"], expected)
                    self.assertEqual(status["online"], "true" if expected == "connected" else "false")
                    self.assertNotIn('PRIVILEGED_SERVICE_CHECK', result.stderr)


    def test_version_falls_back_to_download_url(self):
        script = """
uci() {
 case "$*" in
 *service.download_url) echo https://pkgs.tailscale.com/stable/tailscale_1.104.5_arm.tgz ;;
 esac
}
ip() { :; }
pidof() { return 1; }
pgrep() { return 1; }
""" + STATUS.read_text()
        result = subprocess.run(["sh", "-c", script], capture_output=True, text=True, check=True)
        status = dict(line.split("=", 1) for line in result.stdout.splitlines())
        self.assertEqual(status["version"], "1.104.5")

if __name__ == "__main__":
    unittest.main()
