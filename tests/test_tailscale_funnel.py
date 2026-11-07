"""Exercise Funnel lifecycle without exposing a service or launching Tailscale."""
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / 'decompressed/gui_file/usr/share/modgui-tailscale/tailscale.connect'


class TailscaleFunnel(unittest.TestCase):
    def run_worker(self, *, enabled='1', port='443', target='8080', owned='', mode='success', action='', ssh=False, key=True, target_ip='', ssh_target='', owned_mode='', password='0'):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'socket').touch()
            if key:
                (root / 'authorized_keys').write_text('test-public-key\n')
            marker = '.modgui-funnel-ssh-port' if ssh else '.modgui-funnel-port'
            status_name = 'worker-funnel-ssh-status' if ssh else 'worker-funnel-status'
            if owned:
                (root / marker).write_text(owned)
            if owned_mode:
                (root / (marker + '.mode')).write_text(owned_mode)
            source = WORKER.read_text().replace('/tmp/modgui-tailscale-', str(root / 'worker-'))
            source = source.replace('/var/run/tailscale/tailscaled.sock', str(root / 'socket'))
            source = source.replace('/etc/dropbear/authorized_keys', str(root / 'authorized_keys')).replace('/root/.ssh/authorized_keys', str(root / 'authorized_keys'))
            source = source.replace('-S ', '-f ').replace('/usr/sbin/tailscale', 'mock_tailscale')
            prelude = '''
uci() {
 case "$3" in
  tailscale.service.state_dir) echo "$TEST_ROOT" ;;
  tailscale.service.funnel_enabled|tailscale.service.funnel_ssh_enabled) echo "$TEST_ENABLED" ;;
  tailscale.service.funnel_port|tailscale.service.funnel_ssh_port) echo "$TEST_PORT" ;;
  tailscale.service.funnel_target_port) echo "$TEST_TARGET" ;;
  tailscale.service.funnel_target_ip|tailscale.service.funnel_ssh_target_ip) echo "$TEST_IP" ;;
  tailscale.service.funnel_ssh_target_port) echo "$TEST_SSH_TARGET" ;;
  tailscale.service.funnel_ssh_password_auth) echo "$TEST_PASSWORD" ;;
  tailscale.service.enabled|tailscale.service.connect) echo 1 ;;
 esac
}
lua() { python3 -c 'import os,ipaddress; ipaddress.ip_address(os.environ["MODGUI_FUNNEL_IP"])' 2>/dev/null; }
ip() { echo '    inet 100.64.0.1/32 scope global tailscale0'; }
timeout() { shift; "$@"; }
jsonfilter() { [ "$TEST_MODE" = empty ] || echo '{"HTTPS":true}'; }
sleep() { cat "$TEST_ROOT/$TEST_STATUS" >> "$TEST_ROOT/history"; }
mock_tailscale() {
 if [ "$*" = 'funnel status --json' ]; then echo '{}'; return 0; fi
 echo "$*" >> "$TEST_ROOT/commands"
 case "$*" in *' off') return 0 ;; esac
 if [ "$TEST_MODE" = approval ] && [ ! -f "$TEST_ROOT/approved" ]; then
  touch "$TEST_ROOT/approved"
  echo 'Enable at https://login.tailscale.com/f/abc047'
  return 124
 fi
 if [ "$TEST_MODE" = failure ]; then echo 'Funnel not permitted'; return 1; fi
 echo 'Available on the internet: https://router.example.ts.net'
}
'''
            import os
            env = dict(os.environ, TEST_ROOT=str(root), TEST_ENABLED=enabled, TEST_PORT=port,
                       TEST_TARGET=target, TEST_MODE=mode, TEST_STATUS=status_name, TEST_IP=target_ip, TEST_SSH_TARGET=ssh_target, TEST_PASSWORD=password)
            result = subprocess.run(['sh', '-c', prelude + source, 'worker', ('funnel-ssh-stop' if ssh else 'funnel-stop') if action == 'stop' else ('funnel-ssh' if ssh else 'funnel')], env=env,
                                    capture_output=True, text=True, timeout=5)
            read = lambda name: (root / name).read_text() if (root / name).exists() else ''
            status = dict(line.split('=', 1) for line in read(status_name).splitlines())
            return result.returncode, status, read('commands'), read(marker), read('history')

    def test_ssh_uses_tls_and_dedicated_loopback_target(self):
        code, status, commands, owned, _ = self.run_worker(ssh=True, port='8443')
        self.assertEqual(code, 0)
        self.assertEqual(status['state'], 'active')
        self.assertEqual(status['url'], 'router.example.ts.net:8443')
        self.assertEqual(commands, 'funnel --bg --yes --tls-terminated-tcp=8443 tcp://127.0.0.1:22\n')
        self.assertEqual(owned.strip(), '8443')

    def test_ssh_requires_public_key_and_cleans_only_its_port(self):
        code, status, commands, _, _ = self.run_worker(ssh=True, key=False)
        self.assertEqual(code, 1)
        self.assertIn('SSH public key', status['message'])
        self.assertEqual(commands, '')
        code, status, commands, owned, _ = self.run_worker(ssh=True, enabled='0', owned='8443')
        self.assertEqual(code, 0)
        self.assertEqual(commands, 'funnel --yes --tls-terminated-tcp=8443 off\n')
        self.assertEqual(owned, '')

    def test_password_auth_does_not_require_an_ssh_key(self):
        code, status, commands, _, _ = self.run_worker(ssh=True, port='10000', key=False, password='1')
        self.assertEqual(code, 0)
        self.assertEqual(status['state'], 'active')
        self.assertEqual(commands, 'funnel --bg --yes --tls-terminated-tcp=10000 tcp://127.0.0.1:22\n')
        for value in ('0', '', 'invalid'):
            code, status, commands, _, _ = self.run_worker(ssh=True, key=False, password=value)
            self.assertEqual(code, 1)
            self.assertIn('SSH public key', status['message'])
            self.assertEqual(commands, '')

    def test_ssh_remote_destination_does_not_require_modem_keys(self):
        code, status, commands, _, _ = self.run_worker(ssh=True, port='10000', target_ip='192.168.133.10', ssh_target='22', key=False)
        self.assertEqual(code, 0)
        self.assertEqual(status['state'], 'active')
        self.assertEqual(commands, 'funnel --bg --yes --tls-terminated-tcp=10000 tcp://192.168.133.10:22\n')

    def test_ipv6_destination_is_bracketed(self):
        code, _, commands, _, _ = self.run_worker(ssh=True, port='10000', target_ip='fd00::123', ssh_target='2223', key=False)
        self.assertEqual(code, 0)
        self.assertEqual(commands, 'funnel --bg --yes --tls-terminated-tcp=10000 tcp://[fd00::123]:2223\n')

    def test_http_remote_destination_changes_mode_and_cleans_old_handler(self):
        code, status, commands, _, _ = self.run_worker(target_ip='192.168.133.10', target='8081', owned='443', owned_mode='https')
        self.assertEqual(code, 0)
        self.assertEqual(status['url'], 'https://router.example.ts.net/')
        self.assertEqual(commands, 'funnel --yes --https=443 off\nfunnel --bg --yes --tls-terminated-tcp=443 tcp://192.168.133.10:8081\n')

    def test_invalid_destination_is_rejected_before_cli(self):
        for ip in ('999.1.1.1', '127.0.0.1;id', 'example.com', '::bad::bad'):
            code, status, commands, _, _ = self.run_worker(target_ip=ip)
            self.assertEqual(code, 1)
            self.assertEqual(status['state'], 'error')
            self.assertEqual(commands, '')

    def test_enable_and_background_target(self):
        code, status, commands, owned, _ = self.run_worker()
        self.assertEqual(code, 0)
        self.assertEqual(status['state'], 'active')
        self.assertEqual(status['url'], 'https://router.example.ts.net')
        self.assertEqual(commands, 'funnel --bg --yes --https=443 http://127.0.0.1:8080\n')
        self.assertEqual(owned.strip(), '443')

    def test_disabled_does_not_reset_manual_configuration(self):
        code, status, commands, _, _ = self.run_worker(enabled='0')
        self.assertEqual(code, 0)
        self.assertEqual(status['state'], 'disabled')
        self.assertEqual(commands, '')

    def test_disable_and_stop_remove_only_owned_listener(self):
        for options in ({'enabled': '0'}, {'action': 'stop'}):
            code, status, commands, owned, _ = self.run_worker(owned='8443', **options)
            self.assertEqual(code, 0)
            self.assertEqual(status['state'], 'disabled')
            self.assertEqual(commands, 'funnel --yes --https=8443 off\n')
            self.assertEqual(owned, '')

    def test_port_change_cleans_previous_listener(self):
        _, status, commands, owned, _ = self.run_worker(owned='8443')
        self.assertEqual(status['state'], 'active')
        self.assertTrue(commands.startswith('funnel --yes --https=8443 off\n'))
        self.assertEqual(owned.strip(), '443')

    def test_approval_link_is_reported_and_retried(self):
        code, status, _, _, history = self.run_worker(mode='approval')
        self.assertEqual(code, 0)
        self.assertIn('state=authorization_required', history)
        self.assertIn('approval_url=https://login.tailscale.com/f/abc047', history)
        self.assertEqual(status['state'], 'active')
        self.assertEqual(status['approval_url'], '')

    def test_disable_unapproved_attempt_does_not_request_authorization(self):
        code, status, commands, owned, _ = self.run_worker(enabled='0', owned='443', mode='empty')
        self.assertEqual(code, 0)
        self.assertEqual(status['state'], 'disabled')
        self.assertEqual(commands, '')
        self.assertEqual(owned, '')

    def test_failure_and_invalid_ports(self):
        code, status, _, _, _ = self.run_worker(mode='failure')
        self.assertEqual(code, 1)
        self.assertEqual(status['state'], 'error')
        self.assertIn('Funnel not permitted', status['message'])
        for options in ({'port': '80'}, {'target': '0'}, {'target': '65536'}, {'target': '80;id'}):
            code, status, commands, _, _ = self.run_worker(**options)
            self.assertEqual(code, 1)
            self.assertEqual(status['state'], 'error')
            self.assertEqual(commands, '')


class FunnelModal(unittest.TestCase):
    def test_connect_sets_dns_explicitly_and_defaults_to_off(self):
        import os
        for preference, expected in (('', '0'), ('0', '0'), ('1', '1'), ('invalid', '0')):
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'socket').touch()
                cli = root / 'tailscale'
                cli.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$ARG_LOG"\n')
                cli.chmod(0o755)
                source = WORKER.read_text().replace('/usr/sbin/tailscale', str(cli))
                source = source.replace('/var/run/tailscale/tailscaled.sock', str(root / 'socket')).replace('-S ', '-f ')
                source = source.replace('/tmp/modgui-tailscale-', str(root / 'worker-'))
                prelude = '''
uci() {
 case "$3" in
  tailscale.service.enabled|tailscale.service.connect) echo 1 ;;
  tailscale.service.hostname) echo modem ;;
  tailscale.service.accept_dns) echo "$TEST_DNS" ;;
 esac
}
'''
                result = subprocess.run(['sh', '-c', prelude + source],
                                        env=dict(os.environ, TEST_DNS=preference, ARG_LOG=str(root / 'args')),
                                        text=True, capture_output=True, check=True)
                self.assertIn('--accept-dns=' + expected, (root / 'args').read_text().splitlines())
                self.assertIn('state=connected', (root / 'worker-connect-status').read_text())

    def test_ssh_listener_is_loopback_only_and_requires_keys(self):
        source = (ROOT / 'decompressed/gui_file/usr/share/modgui-tailscale/tailscale.init').read_text()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            key = root / 'authorized_keys'
            source = source.replace('/etc/dropbear/authorized_keys', str(key)).replace('/root/.ssh/authorized_keys', str(key))
            for enabled, has_key, target_ip, target_port, password in ((True, True, '', '', False), (True, False, '', '', False), (False, True, '', '', False), (True, True, '192.168.133.10', '22', False), (True, True, '::1', '2222', False), (True, False, '', '', True), (False, False, '', '', True), (True, False, '192.168.133.10', '22', True)):
                if has_key:
                    key.write_text('public-key\n')
                elif key.exists():
                    key.unlink()
                prelude = '''
uci() {
 case "$3" in
  tailscale.service.funnel_ssh_enabled) echo "$SSH_ENABLED" ;;
  tailscale.service.funnel_ssh_target_ip) echo "$SSH_TARGET_IP" ;;
  tailscale.service.funnel_ssh_target_port) echo "$SSH_TARGET_PORT" ;;
  tailscale.service.funnel_ssh_password_auth) echo "$SSH_PASSWORD" ;;
  tailscale.service.enabled|tailscale.service.connect) echo 1 ;;
 esac
}
procd_open_instance() { instance="$1"; }
procd_set_param() { [ "$1" != command ] || { shift; echo "$instance:$*"; }; }
procd_close_instance() { :; }
'''
                result = subprocess.run(['sh', '-c', f'SSH_ENABLED={int(enabled)}; SSH_TARGET_IP="{target_ip}"; SSH_TARGET_PORT="{target_port}"; SSH_PASSWORD={int(password)};\n' + prelude + source + '\nstart_service\n'],
                                        text=True, capture_output=True, check=True)
                expected = 'funnel_sshd:/usr/sbin/dropbear -F' + ('' if password else ' -s') + ' -p 127.0.0.1:22 -P /var/run/modgui-funnel-sshd.pid'
                self.assertEqual(expected in result.stdout, enabled and (has_key or password) and not target_ip)
                self.assertIn('funnel_ssh:/usr/share/modgui-tailscale/tailscale.connect funnel-ssh', result.stdout)

    def test_bootstrap_sets_certificate_storage_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runtime = root / 'runtime'
            runtime.mkdir()
            for name in ('tailscale', 'tailscaled'):
                binary = runtime / name
                binary.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
                binary.chmod(0o755)
            dev = root / 'dev'
            dev.mkdir()
            (dev / 'tun').touch()
            bootstrap = (ROOT / 'decompressed/gui_file/usr/share/modgui-tailscale/tailscale.bootstrap').read_text()
            bootstrap = bootstrap.replace('/dev/net', str(dev)).replace('[ -c ', '[ -f ')
            bootstrap = bootstrap.replace('/var/run/tailscale', str(root / 'run'))
            bootstrap = bootstrap.replace('/tmp/modgui-tailscale-', str(root / 'worker-'))
            prelude = '''
uci() {
 case "$3" in
  tailscale.service.runtime_dir) echo "$TEST_ROOT/runtime" ;;
  tailscale.service.state_dir) echo "$TEST_ROOT/state" ;;
 esac
}
'''
            import os
            result = subprocess.run(['sh', '-c', prelude + bootstrap],
                                    env=dict(os.environ, TEST_ROOT=str(root)), capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout.splitlines(), ['--port', '41641', '--statedir', str(root / 'state'),
                                                         '--state', str(root / 'state/tailscaled.state')])

    @unittest.skipUnless(shutil.which('lua'), 'Lua required')
    def test_form_validation_and_safe_output(self):
        modal = ROOT / 'decompressed/gui_file/www/docroot/modals/tailscale-modal.lp'
        result = subprocess.run(['lua', '-', str(modal)], input=r'''
T = function(value) return value end
gettext = {textdomain = function() end}
string.untaint = function(value) return value end
local output = {}
ngx = {print = function(...) for _, value in ipairs({...}) do output[#output + 1] = tostring(value) end end}
package.preload['web.uimessage_helper'] = function() return {popMessages = function() return {} end} end
package.preload['web.ui_helper'] = function() return setmetatable({}, {__index = function() return function() return '' end end}) end
package.preload['web.post_helper'] = function()
 local helper = {
  validateIPAndSubnet = function() return function() return true end end,
  validateBoolean = function(value) return value == '0' or value == '1' end,
  validateStringIsIP = function(value) return value == '192.168.133.10' or value == 'fd00::123' end,
  validateStringIsPort = function(value) return tonumber(value) and tonumber(value) >= 1 and tonumber(value) <= 65535 end,
 }
 helper.handleQuery = function(map, validation)
  assert(map.funnel_enabled == 'uci.tailscale.service.funnel_enabled')
  assert(map.funnel_ssh_enabled == 'uci.tailscale.service.funnel_ssh_enabled')
  assert(map.accept_dns == 'uci.tailscale.service.accept_dns')
  assert(map.funnel_ssh_password_auth == 'uci.tailscale.service.funnel_ssh_password_auth')
  assert(validation.funnel_ssh_password_auth('1') and validation.funnel_ssh_password_auth('0'))
  assert(not validation.funnel_ssh_password_auth('invalid'))
  assert(validation.accept_dns('0') and validation.accept_dns('1'))
  assert(not validation.accept_dns('bad'))
  assert(validation.funnel_ssh_target_ip('192.168.133.10'))
  assert(validation.funnel_target_ip('fd00::123'))
  assert(not validation.funnel_target_ip('999.1.1.1'))
  assert(validation.funnel_ssh_target_port('22', {funnel_ssh_enabled='1'}, 'funnel_ssh_target_port'))
  assert(not validation.funnel_ssh_target_port('0', {funnel_ssh_enabled='1'}, 'funnel_ssh_target_port'))
  assert(not validation.funnel_ssh_port('443', {funnel_enabled='1', funnel_port='443', funnel_ssh_enabled='1'}, 'funnel_ssh_port'))
  assert(validation.funnel_ssh_port('8443', {funnel_enabled='1', funnel_port='443', funnel_ssh_enabled='1'}, 'funnel_ssh_port'))
  for _, value in ipairs({'443', '8443', '10000'}) do assert(validation.funnel_port(value, {funnel_enabled='1'})) end
  assert(not validation.funnel_port('80', {funnel_enabled='1'}))
  assert(not validation.funnel_port('', {funnel_enabled='1'}))
  assert(validation.funnel_port('', {funnel_enabled='0'}))
  assert(not validation.funnel_target_port('65536', {funnel_enabled='1'}))
  assert(not validation.funnel_target_port('', {funnel_enabled='1'}))
  assert(validation.funnel_target_port('8080', {funnel_enabled='1'}))
  return {funnel_enabled='0', funnel_port='', funnel_target_port=''}, {}
 end
 return helper
end
io.popen = function()
 local lines = {'funnel_state=error', 'funnel_message=<script>unsafe</script>', 'funnel_approval_url=javascript:unsafe'}
 local i = 0
 return {lines = function() return function() i=i+1; return lines[i] end end, close=function() end}
end
assert(loadfile(arg[1]))()
local html = table.concat(output)
assert(html:find('&lt;script&gt;unsafe&lt;/script&gt;', 1, true))
assert(not html:find('href="javascript:', 1, true))
''', capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
