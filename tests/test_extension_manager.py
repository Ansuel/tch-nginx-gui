"""Regression tests for the native Extensions manager integrations."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / "decompressed/gui_file"
INSTALLER = GUI / "usr/share/transformer/scripts/appInstallRemoveUtility.sh"
RPC_MAP = GUI / "usr/share/transformer/mappings/rpc/system.modgui.map"
UCI_MAP = GUI / "usr/share/transformer/mappings/uci/modgui.map"
MODAL = GUI / "www/docroot/modals/applications-modal.lp"
CARD = GUI / "www/cards/009_extensions.lp"
CONFIG = GUI / "etc/modgui_scripts/04_config.sh"

EXTENSIONS = {
    "adblock": "adblock_app",
    "rsyncd": "rsyncd_app",
    "speedtest": "speedtest_app",
    "adguardhome": "adguardhome_app",
    "openspeedtest": "openspeedtest_app",
    "wireguard": "wireguard_app",
    "l2tpipsec": "l2tpipsec_app",
    "openvpn": "openvpn_app",
    "tailscale": "tailscale_app",
    "dumaos": "dumaos_app",
}


class ExtensionManager(unittest.TestCase):
    def test_transmission_package_failure_stops_before_state_write(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_transmission() {")
        function = installer[start:installer.index("\napp_telstra()", start)]
        for failing_command in ("update", "install"):
            with self.subTest(failing_command=failing_command):
                script = function + '''
marketing_version=19.4
cpu_type=armv7l
opkg() { [ "$1" != "$FAIL_COMMAND" ]; }
uci() { echo "UNEXPECTED_STATE_WRITE:$*"; }
FAIL_COMMAND=''' + failing_command + "\napp_transmission install"
                result = subprocess.run(["sh", "-c", script], text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")

    def test_l2tp_preserves_preinstalled_xl2tpd_version(self):
        installer = INSTALLER.read_text()
        start = installer.index("    # Preserve the firmware's existing xl2tpd")
        end = installer.index('    curl -kfL "https://raw.githubusercontent.com/FrancYescO/sharing_tg789/', start)
        setup = installer[start:end]
        for installed in (False, True):
            with self.subTest(installed=installed):
                script = '''
opkg() {
    if [ "$1" = status ]; then
        [ "$PREINSTALLED" = 1 ] && echo 'Status: install user installed'
    else
        echo "$*"
    fi
}
l2tpipsec_rollback_install() { echo UNEXPECTED_ROLLBACK; }
PREINSTALLED=''' + str(int(installed)) + "\n" + setup
                result = subprocess.run(["sh", "-c", script], text=True,
                                        capture_output=True, check=True)
                expected = ["install strongswan-default"]
                if not installed:
                    expected.insert(0, "install xl2tpd")
                self.assertEqual(result.stdout.splitlines(), expected)

    def test_aria2_package_failure_stops_before_download_and_state_write(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_aria2() {")
        function = installer[start:installer.index("\napp_voipblock_for_mmpbx()", start)]
        for failing_command in ("update", "install"):
            with self.subTest(failing_command=failing_command):
                script = function + '''
marketing_version=19.4
cpu_type=armv7l
opkg() { [ "$1" != "$FAIL_COMMAND" ]; }
curl() { echo UNEXPECTED_DOWNLOAD; return 1; }
uci() { echo "UNEXPECTED_STATE_WRITE:$*"; }
FAIL_COMMAND=''' + failing_command + "\napp_aria2 install"
                result = subprocess.run(["sh", "-c", script], text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")

    def test_adblock_removal_only_cleans_its_dns_reference(self):
        installer = INSTALLER.read_text()
        start = installer.index("adblock_cleanup_dns() {")
        function = installer[start:installer.index("\napp_adblock()", start)]
        function = function.replace("/etc/init.d/dnsmasq reload", "echo DNS_RELOAD")
        script = function + '''
uci() {
    case "$*" in
        '-q show dhcp') printf '%s\\n' 'dhcp.lan=dnsmasq' 'dhcp.guest=dnsmasq' 'dhcp.pool=dhcp' ;;
        '-q get dhcp.lan.serversfile') echo /tmp/adb_list.overall ;;
        '-q get dhcp.guest.serversfile') echo /etc/custom-dns-servers ;;
        *) echo "$*" ;;
    esac
}
adblock_cleanup_dns
'''
        result = subprocess.run(["sh", "-c", script], text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.splitlines(),
                         ["-q delete dhcp.lan.serversfile", "commit dhcp", "DNS_RELOAD"])

    def test_xupnp_package_errors_do_not_change_install_state(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_xupnp() {")
        function = installer[start:installer.index("\nset_extension_state()", start)]
        for action, failing_command in (("install", "update"), ("install", "install"), ("remove", "remove")):
            with self.subTest(action=action, failing_command=failing_command):
                script = function + '''
opkg() { [ "$1" != "$FAIL_COMMAND" ]; }
uci() { echo "Unexpected state write: $*"; }
FAIL_COMMAND=''' + failing_command + "\napp_xupnp " + action
                result = subprocess.run(["sh", "-c", script], text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")

    def test_wireguard_detection_reconciles_stale_install_state(self):
        config = CONFIG.read_text()
        start = config.index("  # Reconcile stale flags")
        end = config.index('  if [ ! "$(uci get -q modgui.app.l2tpipsec_app)" ]; then', start)
        detection = config[start:end]
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / name for name in ("wireguard-go", "wg-go", "wireguard.sh")]
            detection = detection.replace("/etc/.modgui-wireguard-native-installed", str(Path(directory) / "native-installed"))
            for original, replacement in zip(
                ("/usr/bin/wireguard-go", "/usr/bin/wg-go", "/lib/netifd/proto/wireguard.sh"), paths,
            ):
                detection = detection.replace(original, str(replacement))
            for binary_count in range(4):
                with self.subTest(binary_count=binary_count):
                    if binary_count:
                        paths[binary_count - 1].touch(mode=0o755)
                    script = '''
uci() {
    case "$1" in
        get) echo 1 ;;
        set) echo "$2" ;;
    esac
}
''' + detection
                    result = subprocess.run(["sh", "-c", script], text=True,
                                            capture_output=True, check=True)
                    self.assertEqual(result.stdout.strip(),
                                     f"modgui.app.wireguard_app={int(binary_count == 3)}")

    @unittest.skipUnless(shutil.which("lua"), "lua is not installed")
    def test_installed_web_interfaces_are_links_in_extensions_card(self):
        harness = r'''
local installed = arg[2]
T = function(text) return text end
gettext = { textdomain = function() end }
ngx = {
    var = { host = arg[4] },
    req = { get_method = function() return "GET" end },
    ctx = { session = { hasAccess = function() return true end } },
    print = function(value)
        if type(value) == "table" then value = table.concat(value) end
        io.write(value)
    end,
}
package.preload["datamodel"] = function()
    return { get = function(path)
        return {{value = path:find("Supported$") and (arg[5] or "1") or (path:find("CPUtype") and arg[3] or "19.4")}}
    end }
end
package.preload["web.content_helper"] = function()
    return { getExactContent = function(params)
        for key, path in pairs(params) do
            assert(not path:find("uci.network", 1, true), "Must not read interface addresses")
            params[key] = installed
        end
    end }
end
package.preload["web.ui_helper"] = function()
    return setmetatable({
        createCardHeader = function() return "" end,
        createSimpleLight = function(state, title)
            return '<span data-state="' .. state .. '">' .. title .. '</span>'
        end,
        createSimpleButton = function(title) return title end,
    }, { __index = function() return function() return "" end end })
end
io.popen = function(command)
    assert(not command:find("check tun", 1, true), "Web worker must not run opkg probes")
    assert(not command:find("check wireguard", 1, true), "Web worker must not run opkg probes")
    return {read = function() return "0" end, close = function() end}
end
io.open = function(path)
    if path == "/etc/modgui-amule-web.password" then
        return { read = function() return [[test<&"'password]] end, close = function() end }
    end
    if path ~= "/opt/AdGuardHome/AdGuardHome.yaml" then return nil end
    local lines = {"http:", "  address: 0.0.0.0:8081", "dns:", "  port: 53"}
    local index = 0
    return { lines = function() return function()
        index = index + 1
        return lines[index]
    end end, close = function() end }
end
dofile(arg[1])
'''
        cases = (("0", "armv7", "192.0.2.10"),
                 ("1", "armv7", "192.0.2.10"),
                 ("1", "mips", "192.0.2.10"),
                 ("1", "armv7", "modem.example.test"),
                 ("1", "armv7", "2001:db8::69"),
                 ("1", "armv7", "[2001:db8::69]"))
        for installed, architecture, host in cases:
            address = f"[{host}]" if ":" in host and not host.startswith("[") else host
            with self.subTest(installed=installed, architecture=architecture, host=host):
                result = subprocess.run(
                    ["lua", "-", str(CARD), installed, architecture, host], input=harness,
                    text=True, capture_output=True, check=True,
                )
                if installed == "0":
                    self.assertNotIn('<a ', result.stdout)
                    self.assertIn('>DumaOS</span>', result.stdout)
                    modal = subprocess.run(
                        ["lua", "-", str(MODAL), installed, architecture, host], input=harness,
                        text=True, capture_output=True, check=True,
                    )
                    self.assertNotIn('id="amule-web-password"', modal.stdout)
                    self.assertNotIn("test&lt;", modal.stdout)
                    continue
                for url, title in (
                    (f"http://{address}:9080/", "LuCI"),
                    ("/aria", "Aria2"),
                    (f"http://{address}:9091/transmission", "Transmission"),
                    (f"http://{address}:4044/ui/", "XUPnP"),
                    ("/telstra-gui.lp", "Telstra GUI"),
                    (f"http://{address}:8081/", "AdGuard Home"),
                    (f"http://{address}:5678/", "OpenSpeedTest"),
                ):
                    if architecture == "mips" and title == "AdGuard Home":
                        continue
                    self.assertIn(f'href="{url}">{title}</a>', result.stdout)
                self.assertIn(f'href="http://{address}:4711/">aMule</a>', result.stdout)
                architecture_url, architecture_title = (
                    ("/desktop/", "DumaOS") if architecture == "armv7"
                    else (f"http://{address}:4711/", "aMule")
                )
                self.assertIn(f'href="{architecture_url}">{architecture_title}</a>', result.stdout)
                self.assertEqual(result.stdout.count('class="card-direct-link"'), 9 if architecture == "armv7" else 7)
                self.assertNotIn('>WireGuard</a>', result.stdout)
                modal = subprocess.run(
                    ["lua", "-", str(MODAL), installed, architecture, host], input=harness,
                    text=True, capture_output=True, check=True,
                )
                self.assertIn('id="amule-web-password" class="input-block-level" type="password" readonly', modal.stdout)
                self.assertIn('value="test&lt;&amp;&quot;&#39;password"', modal.stdout)
                self.assertIn('id="amule-show-password" type="checkbox"', modal.stdout)
                for port in ("9080", "9091", "4044", "5678"):
                    self.assertIn(f'http://{address}:{port}', modal.stdout)
                if architecture == "armv7":
                    self.assertIn(f'http://{address}:8081', modal.stdout)
                else:
                    self.assertIn(f'http://{address}:4711', modal.stdout)

        for supported in ("0", "1"):
            result = subprocess.run(
                ["lua", "-", str(MODAL), "0", "armv7", "gateway.test", supported],
                input=harness, text=True, capture_output=True, check=True,
            )
            for title in ("WireGuard", "OpenVPN", "Tailscale"):
                self.assertEqual("Install " + title in result.stdout, supported == "1")

    def test_extensions_are_whitelisted_dispatched_and_mapped(self):
        installer = INSTALLER.read_text()
        rpc_map = RPC_MAP.read_text()
        uci_map = UCI_MAP.read_text()
        config = CONFIG.read_text()

        for app, option in EXTENSIONS.items():
            with self.subTest(app=app):
                self.assertIn(f'"{app}",', rpc_map)
                self.assertIn(f"  {app})", installer)
                self.assertIn(f"app_{app}()", installer)
                self.assertIn(f'"{option}"', uci_map)
                self.assertIn(f"modgui.app.{option}", config)

    def test_downloaded_binaries_use_official_https_sources(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_speedtest()")
        end = installer.index("install_specific_files()", start)
        downloaded_extensions = installer[start:end]
        self.assertIn("https://install.speedtest.net/app/cli/", downloaded_extensions)
        self.assertIn("https://static.adguard.com/adguardhome/release/", downloaded_extensions)
        self.assertNotIn("curl | sh", downloaded_extensions)
        self.assertNotIn("curl | ash", downloaded_extensions)

    def test_adguard_install_does_not_reconfigure_dns(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_adguardhome()")
        end = installer.index("install_specific_files()", start)
        adguard = installer[start:end]

        self.assertNotIn("dnsmasq", adguard)
        self.assertNotIn("port 53", adguard)
        self.assertIn('"$adguard_bin" -s install', adguard)
        self.assertIn("require_free_space 49152 /opt", adguard)
        self.assertIn('adguard_work="/tmp/AdGuardHomeWork"', adguard)
        self.assertIn("$3 == \"jffs2\"", adguard)

    def test_rsync_removal_only_removes_an_owned_dependency(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_rsyncd()")
        end = installer.index("app_speedtest()", start)
        rsyncd = installer[start:end]
        self.assertIn("opkg remove rsyncd", rsyncd)
        self.assertIn('if [ -f "$rsync_owned" ]', rsyncd)
        self.assertIn("opkg remove rsync", rsyncd)

    def test_armv7_adguard_uses_soft_float_binary(self):
        installer = INSTALLER.read_text()
        self.assertIn('armv7*) adguard_arch="armv5"', installer)

    def test_openspeedtest_is_pinned_verified_and_keeps_nginx_global_config(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_openspeedtest()")
        end = installer.index("install_specific_files()", start)
        openspeedtest = installer[start:end]
        self.assertIn(
            'openspeedtest_commit="f4263546f50694a154fdd27a03000390949068df"',
            openspeedtest,
        )
        self.assertIn(
            'openspeedtest_sha256="f8d239bc4183c214c0747ec1a1c418fd33773683f82e7ee8327cf734ea6a4987"',
            openspeedtest,
        )
        self.assertIn("sha256sum", openspeedtest)
        self.assertIn("server_openspeedtest.conf", openspeedtest)
        self.assertNotIn("/etc/nginx/nginx.conf", openspeedtest)

    def test_wireguard_uses_feeds_and_installs_disabled(self):
        installer = INSTALLER.read_text()
        defaults = (GUI / "usr/share/modgui-wireguard/wireguard.default").read_text()
        start = installer.index("app_wireguard()")
        end = installer.index("app_l2tpipsec()", start)
        wireguard = installer[start:end]
        shared_tun = installer[:start]
        modal = MODAL.read_text()

        self.assertIn("CONFIG_TUN=y", shared_tun)
        self.assertNotIn("19.4.0866-3401052", shared_tun)
        self.assertIn("tun-vbntj-damson-4.1.52.ko", shared_tun)
        self.assertIn("modgui_install_tun wireguard", wireguard)
        self.assertIn("opkg update", wireguard)
        self.assertIn("opkg install wireguard-go", wireguard)
        self.assertIn("modgui_kernel_package", wireguard)
        self.assertNotIn("curl ", wireguard)
        self.assertNotIn("wireguard_version=", wireguard)
        self.assertNotIn("uci set network.", wireguard)
        self.assertNotIn("uci set firewall.", wireguard)
        self.assertIn("wireguard.wg.enabled='0'", wireguard)
        self.assertIn("wireguard.wg.allow_lan='0'", wireguard)
        self.assertIn("wireguard.wg.allow_wan='0'", wireguard)
        self.assertIn("option allow_lan '0'", defaults)
        self.assertIn("option allow_wan '0'", defaults)
        self.assertNotIn("firewall.modgui_wireguard_udp=rule", wireguard)
        self.assertIn("rpc.system.modgui.TunSupported", modal)
        self.assertIn("rpc.system.modgui.WireGuardSupported", modal)
        self.assertIn("no reviewed TUN module", modal)

    def test_reviewed_tun_module_requires_matching_platform_and_kernel(self):
        installer = INSTALLER.read_text()
        start = installer.index("modgui_reviewed_tun_build() {")
        end = installer.index("\n}", start) + len("\n}")
        script = '''
cpu_type="$1"
test_kernel="$2"
marketing_version="$3"
uname() { [ "$1" = "-r" ] && printf '%s\\n' "$test_kernel"; }
        uci() { echo unexpected-model-lookup >&2; return 99; }
''' + installer[start:end] + "\nmodgui_reviewed_tun_build\n"
        for cpu, kernel, version, supported in (
            ("armv7l", "4.1.52", "19.4", True),
            ("armv7l", "4.1.51", "19.4", False),
            ("aarch64", "4.1.52", "19.4", False),
            ("mips", "4.1.52", "17.2", False),
            ("mips", "3.4.11-rt19", "17.2 Mint", True),
            ("mips", "3.4.11-rt19", "17.2.1", True),
            ("mips", "3.4.11-rt19", "17.2", True),
            ("mips", "3.4.11-rt19", "16.3", False),
            ("mips", "3.4.11", "17.2", False),
            ("mips", "3.4.11-rt19", "17.20", False),
            ("mipsel", "3.4.11-rt19", "17.2", False),
        ):
            with self.subTest(cpu=cpu, kernel=kernel):
                result = subprocess.run(
                    ["sh", "-c", script, "tun-test", cpu, kernel, version],
                    text=True, capture_output=True,
                )
                self.assertEqual(result.returncode == 0, supported, result.stderr)

    def test_wireguard_removal_is_ownership_aware(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_wireguard()")
        end = installer.index("app_l2tpipsec()", start)
        wireguard = installer[start:end]
        self.assertIn('wireguard_owned="/etc/.modgui-wireguard-go-installed"', wireguard)
        self.assertIn('[ -f "$wireguard_owned" ]', wireguard)
        self.assertIn("opkg remove wireguard-go", wireguard)
        self.assertIn("Remove manually configured WireGuard network interfaces", wireguard)
        self.assertIn("wireguard_cleanup_network", wireguard)
        self.assertIn("web.wireguard_card", wireguard)
        self.assertIn("modgui-wireguard-gui.tar.gz", wireguard)

    def test_wireguard_card_and_apply_configuration_on_enable(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_wireguard()")
        end = installer.index("app_l2tpipsec()", start)
        wireguard = installer[start:end]
        card = (GUI / "www/cards/016_wireguard.lp").read_text()
        modal = (GUI / "www/docroot/modals/wireguard-modal.lp").read_text()
        apply_script = (GUI / "usr/share/transformer/scripts/wireguardApply.sh").read_text()
        config = CONFIG.read_text()

        for path in (
            GUI / "usr/share/modgui-wireguard/wireguard.default",
            GUI / "usr/share/transformer/mappings/uci/wireguard.map",
            GUI / "usr/share/transformer/mappings/uci/wireguard.peer.map",
            GUI / "usr/share/transformer/commitapply/uci_wireguard.ca",
            GUI / "usr/share/transformer/scripts/wireguardApply.sh",
            GUI / "usr/share/transformer/scripts/wireguardStatus.sh",
            GUI / "usr/share/transformer/scripts/wireguardKeygen.sh",
            GUI / "www/cards/016_wireguard.lp",
            GUI / "www/docroot/modals/wireguard-modal.lp",
            GUI / "www/lang/it-it/webui-wireguard.po",
        ):
            with self.subTest(path=path):
                self.assertTrue(path.is_file())

        self.assertIn("wireguard_prepare_config", wireguard)
        self.assertIn("wireguard_backup_gui", wireguard)
        self.assertIn("wireguard_repair_gui", wireguard)
        self.assertIn("wireguardApply.sh", wireguard)
        self.assertIn("/opt/modgui-wireguard-gui.tar.gz", config)
        self.assertIn("appInstallRemoveUtility.sh refresh wireguard", config)

        self.assertIn("network.modgui_wg0.proto='wireguard'", apply_script)
        self.assertIn("wireguard_modgui_wg0", apply_script)
        self.assertIn("firewall.modgui_wireguard_zone", apply_script)
        self.assertIn("firewall.modgui_wireguard_to_lan", apply_script)
        self.assertIn("firewall.modgui_wireguard_to_wan", apply_script)
        self.assertIn("wireguard.wg.listen_port", apply_script)
        self.assertIn('grep -q \'"proto": "none"\'', apply_script)
        self.assertIn("/etc/init.d/network restart", apply_script)
        self.assertNotIn("firewall.modgui_wan_to_wireguard", apply_script)
        self.assertIn("firewall.modgui_wireguard_zone.input='REJECT'", apply_script)
        self.assertNotIn("firewall.modgui_lan_to_wireguard=forwarding", apply_script)
        self.assertIn("valid_cidr", apply_script)
        self.assertIn('[ "$endpoint_port" -le 65535 ]', apply_script)
        self.assertIn('[ "$keepalive" -le 320 ]', apply_script)
        self.assertIn('valid_key "$preshared_key"', apply_script)
        self.assertIn("umask 077", (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn("printf '%s\\n'", (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn('if [ "$2" = "export" ]',
                      (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn('server_public="${3:-$(uci -q get wireguard.wg.public_key)}"',
                      (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn("chmod 640 /tmp/modgui-wireguard-client.conf",
                      (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn("chown root:nogroup /tmp/modgui-wireguard-client.conf",
                      (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn('client | client-profile)',
                      (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn("A pre-existing WireGuard runtime is installed; refusing to remove it", wireguard)
        self.assertIn("modgui_release_tun wireguard", wireguard)
        self.assertIn(".modgui-tun-user-", installer)
        self.assertIn("30-modgui-tun", installer)

        self.assertIn("uci.wireguard.wg.enabled", card)
        self.assertIn("wireguardStatus.sh", card)
        self.assertIn("wireguardStatus.sh", modal)
        self.assertIn("wireguardKeygen.sh", modal)
        self.assertIn('proxy.add("uci.wireguard.peer.")', modal)
        self.assertIn("client-profile", modal)
        self.assertIn('proxy.getPN("uci.wireguard.peer.", true)', modal)
        self.assertIn('qrcode(typeNumber,errorCorrectLevel)', modal)
        self.assertIn('var typeNumber=10', modal)
        self.assertIn('var errorCorrectLevel="L"', modal)
        self.assertIn("wireguard-client-qr", modal)
        self.assertIn("Download client profile", modal)
        self.assertIn("/ajax/wireguard_profile.lua", modal)
        self.assertIn("web.wireguardprofile", installer)
        self.assertNotIn("?keygen=", modal)
        self.assertIn('data-value="WG_KEYGEN_INTERFACE"', modal)
        self.assertIn("plain(ngx.var.http_host)", modal)
        self.assertIn(
            'plain(host:gsub(":%d+$", ""):gsub("[^A-Za-z0-9.%-]", ""))',
            modal,
        )
        self.assertIn('run_keygen("interface export")', modal)
        self.assertIn('["uci.wireguard.wg.private_key"] = private', modal)
        self.assertIn('server_public = getvalue("uci.wireguard.wg.public_key")', modal)
        self.assertIn('local submitted_private = plain(post_args.private_key)', modal)
        self.assertIn('if submitted_private == "********" then submitted_private = "" end', modal)
        self.assertIn('if submitted_private ~= "" then', modal)
        self.assertIn('validators.private_key = valid_private_key', modal)
        self.assertIn('post_helper.handleQuery(map_params, validators)', modal)
        self.assertIn('content.private_key = getvalue("uci.wireguard.wg.private_key")', modal)
        self.assertIn('type = "password"', modal)
        self.assertIn('if value == "********" then return true end', modal)
        self.assertIn("uci.wireguard.peer.@.", modal)
        self.assertIn('name = "uci.wireguard.peer.@."',
                       (GUI / "usr/share/transformer/mappings/uci/wireguard.peer.map").read_text())
        peer_map = (GUI / "usr/share/transformer/mappings/uci/wireguard.peer.map").read_text()
        self.assertIn('param == "preshared_key" and value ~= ""', peer_map)
        self.assertIn('tostring(value or "") == "********"', peer_map)
        keygen = (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text()
        self.assertIn('uci add wireguard peer', keygen)
        self.assertIn('allowed_ips=$client_address/32', keygen)
        self.assertIn('/tmp/modgui-wireguard-client.name', keygen)


    def test_l2tpipsec_is_pinned_fixed_and_starts_disabled(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_l2tpipsec()")
        end = installer.index("install_specific_files()", start)
        vpn = installer[start:end]
        shared_tun = installer[:start]

        self.assertIn(
            'l2tpipsec_commit="5c9015930961848259aa883cbe1a20c02a227de4"',
            vpn,
        )
        self.assertIn(
            'l2tpipsec_sha256="5604db2e143c339eb1db0cb980e30492c2e5f57c4e35f06b52d224fb4822de18"',
            vpn,
        )
        self.assertIn("sha256sum", vpn)
        self.assertIn("modgui-vpn_1.1-0_all.ipk", vpn)
        self.assertIn("grep -q '^xl2tpd version:'", vpn)
        self.assertIn("/etc/init.d/modgui-ipsec restart", vpn)
        self.assertNotIn("l2tpipsec_fix_runtime", vpn)
        self.assertIn("modgui-l2tp-ipsec-gui.tar.gz", vpn)
        self.assertIn("l2tpipsec_set_enabled 0", vpn)
        self.assertNotIn("--force-overwrite", vpn)
        self.assertNotIn("spuctl", vpn)
        self.assertNotIn("/etc/init.d/ipsec restart", vpn)
        self.assertGreaterEqual(vpn.count("l2tpipsec_rollback_install"), 5)

    def test_l2tpipsec_removal_tracks_owned_packages(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_l2tpipsec()")
        end = installer.index("install_specific_files()", start)
        vpn = installer[start:end]
        self.assertIn(".modgui-l2tp-ipsec-packages", vpn)
        self.assertIn("grep -Fxq", vpn)
        self.assertIn("opkg remove \"$package\"", vpn)
        self.assertLess(
            vpn.index("l2tpipsec_remove_owned_package strongswan-default"),
            vpn.index("grep '^strongswan-mod-'"),
        )
        self.assertLess(
            vpn.index("l2tpipsec_remove_owned_package strongswan-ipsec"),
            vpn.index("l2tpipsec_remove_owned_package strongswan\n"),
        )
        self.assertIn("delete web.l2tpipsecserver_card", vpn)

    def test_l2tpipsec_is_only_shown_on_supported_cpus(self):
        modal = MODAL.read_text()
        card = CARD.read_text()
        architecture_gate = (
            'if cputype:match("^armv7") or cputype:match("^mips") then\n'
            '\tmapParams.l2tpipsec_application = "uci.modgui.app.l2tpipsec_app"\n'
            "end"
        )
        self.assertIn(architecture_gate, modal)
        self.assertIn(architecture_gate, card)

    def test_openvpn_is_safe_gated_and_starts_disabled(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_openvpn()")
        end = installer.index("install_specific_files()", start)
        vpn = installer[start:end]
        shared_tun = installer[:start]
        modal = MODAL.read_text()
        card = CARD.read_text()

        self.assertIn("openvpn-openssl openvpn-easy-rsa", vpn)
        self.assertNotIn("openvpn-easy-rsa liblzo libopenssl", vpn)
        self.assertIn("openvpn-easy-rsa openssl-util liblzo", vpn)
        self.assertIn("openvpn_has_tun", vpn)
        self.assertIn("CONFIG_TUN=y", shared_tun)
        self.assertIn("modgui_install_tun openvpn", vpn)
        self.assertIn("A pre-existing OpenVPN installation was found", vpn)
        self.assertIn(".modgui-openvpn-packages", vpn)
        self.assertIn("openvpn.server.enabled=0", vpn)
        self.assertIn("openvpnGenerateKeys.sh", vpn)
        self.assertIn("openvpnApply.sh", vpn)
        self.assertIn('openvpn_gui_backup="/opt/modgui-openvpn-gui.tar.gz"', vpn)
        self.assertIn('openvpn_backup_gui || return 1', vpn)
        self.assertIn('tar -xzf "$openvpn_gui_backup" -C /', vpn)
        self.assertIn('openvpn_repair_gui', vpn)
        self.assertIn('if [ -d "$openvpn_openssl_lib/usr/lib" ]', vpn)
        self.assertIn('openvpn_register_client', vpn)
        self.assertIn('openvpnClientRoute.sh', vpn)
        self.assertIn('openvpn.client.map', vpn)
        self.assertIn('openvpn.client.ssid.map', vpn)
        self.assertIn("firewall.modgui_openvpn", vpn)
        self.assertNotIn("--force-overwrite", vpn)
        self.assertIn('mapParams.openvpn_application = "uci.modgui.app.openvpn_app"', modal)
        self.assertIn('mapParams.openvpn_application = "uci.modgui.app.openvpn_app"', card)
        config = CONFIG.read_text()
        self.assertIn('/opt/modgui-openvpn-gui.tar.gz', config)
        self.assertIn('appInstallRemoveUtility.sh refresh openvpn', config)

    def test_openvpn_assets_are_present(self):
        expected = (
            GUI / "usr/share/modgui-openvpn/openvpn.default",
            GUI / "usr/share/modgui-openvpn/checkpwd.sh",
            GUI / "usr/share/transformer/mappings/uci/openvpn.map",
            GUI / "usr/share/transformer/mappings/rpc/openvpn.map",
            GUI / "usr/share/transformer/mappings/rpc/openvpn.server.map",
            GUI / "usr/share/transformer/mappings/rpc/openvpn.client.map",
            GUI / "usr/share/transformer/mappings/rpc/openvpn.client.ssid.map",
            GUI / "usr/share/transformer/commitapply/uci_openvpn.ca",
            GUI / "usr/share/transformer/scripts/openvpnApply.sh",
            GUI / "usr/share/transformer/scripts/openvpnGenerateKeys.sh",
            GUI / "usr/share/transformer/scripts/openvpnClientRoute.sh",
            GUI / "etc/hotplug.d/iface/95-modgui-openvpn-client",
            GUI / "www/cards/015_openvpn-server.lp",
            GUI / "www/docroot/modals/openvpn-server-modal.lp",
        )
        for path in expected:
            with self.subTest(path=path):
                self.assertTrue(path.is_file())

    def test_openvpn_client_keeps_main_route_and_discovers_ssids(self):
        apply_script = (GUI / "usr/share/transformer/scripts/openvpnApply.sh").read_text()
        route_script = (GUI / "usr/share/transformer/scripts/openvpnClientRoute.sh").read_text()
        ssid_map = (GUI / "usr/share/transformer/mappings/rpc/openvpn.client.ssid.map").read_text()
        modal = (GUI / "www/docroot/modals/openvpn-server-modal.lp").read_text()
        self.assertIn("route-nopull", apply_script)
        self.assertIn("dev tun1", apply_script)
        self.assertIn("unreachable default", route_script)
        self.assertIn('network ~= "lan"', ssid_map)
        self.assertIn('rpc.openvpn.client.ssid.', modal)
        self.assertIn('local raw = string.untaint(value or "")', modal)
        self.assertIn('local path = item.path and string.untaint(item.path)', modal)
        self.assertNotIn("route_guest_24", route_script)
        self.assertNotIn("route_guest_5", route_script)

    def test_tailscale_is_pinned_gated_and_starts_disabled(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_tailscale()")
        end = installer.index("install_specific_files()", start)
        tailscale = installer[start:end]
        shared_tun = installer[:start]
        modal = MODAL.read_text()
        card = CARD.read_text()
        config = CONFIG.read_text()

        self.assertIn('tailscale_version="1.102.4"', tailscale)
        self.assertIn(
            'tailscale_sha256="b981a59cb85fb923ee6e1860ee6934772c83a840a6627f0dbfd7711ed690b869"',
            tailscale,
        )
        self.assertIn(
            'tailscale_sha256="9dd1e6a592a014bbaea0103167ffe299adeda4ba14e078ce9c2895364f6c4c3f"',
            tailscale,
        )
        self.assertIn("https://pkgs.tailscale.com/stable/", tailscale)
        self.assertIn("sha256sum", tailscale)
        self.assertIn("tailscale_has_tun", tailscale)
        self.assertIn("CONFIG_TUN=y", shared_tun)
        self.assertIn("modgui_install_tun tailscale", tailscale)
        self.assertIn("modgui_release_tun tailscale", tailscale)
        self.assertIn("A pre-existing Tailscale installation was found", tailscale)
        self.assertIn("tailscale.service.enabled=0", tailscale)
        self.assertIn("tailscale.service.connect=0", tailscale)
        self.assertIn(".modgui-tailscale-packages", tailscale)
        self.assertIn("modgui-tailscale-gui.tar.gz", tailscale)
        self.assertIn("tailscale_has_space 131072 /tmp", tailscale)
        self.assertIn("/tmp/modgui-tailscale-runtime", tailscale)
        self.assertIn("tailscale.service.download_url", tailscale)
        self.assertNotIn("opkg install ca-bundle", tailscale)
        self.assertIn('curl -kfL "https://pkgs.tailscale.com/stable/', tailscale)
        self.assertNotIn("curl | sh", tailscale)
        self.assertIn('mapParams.tailscale_application = "uci.modgui.app.tailscale_app"', modal)
        self.assertIn('mapParams.tailscale_application = "uci.modgui.app.tailscale_app"', card)
        self.assertIn("appInstallRemoveUtility.sh refresh tailscale", config)

    def test_tailscale_assets_and_safe_routing_are_present(self):
        expected = (
            GUI / "usr/share/modgui-tailscale/tailscale.default",
            GUI / "usr/share/modgui-tailscale/tailscale.init",
            GUI / "usr/share/modgui-tailscale/tailscale.bootstrap",
            GUI / "usr/share/modgui-tailscale/tailscale.connect",
            GUI / "usr/share/transformer/mappings/uci/tailscale.map",
            GUI / "usr/share/transformer/commitapply/uci_tailscale.ca",
            GUI / "usr/share/transformer/scripts/tailscaleApply.sh",
            GUI / "usr/share/transformer/scripts/tailscaleStatus.sh",
            GUI / "www/cards/016_tailscale.lp",
            GUI / "www/docroot/modals/tailscale-modal.lp",
            GUI / "www/lang/it-it/webui-tailscale.po",
        )
        for path in expected:
            with self.subTest(path=path):
                self.assertTrue(path.is_file())

        apply_script = (GUI / "usr/share/transformer/scripts/tailscaleApply.sh").read_text()
        connect_script = (GUI / "usr/share/modgui-tailscale/tailscale.connect").read_text()
        modal = (GUI / "www/docroot/modals/tailscale-modal.lp").read_text()
        self.assertIn("--netfilter-mode=off", connect_script)
        self.assertIn("firewall.modgui_tailscale_to_lan", apply_script)
        self.assertIn("firewall.modgui_tailscale_to_wan", apply_script)
        self.assertIn("firewall.modgui_tailscale_zone.device='tailscale0'", apply_script)
        self.assertNotIn("firewall.modgui_wan_to_tailscale", apply_script)
        init_script = (GUI / "usr/share/modgui-tailscale/tailscale.init").read_text()
        self.assertIn("chown root:nogroup", connect_script)
        self.assertIn("chmod 640", connect_script)
        self.assertIn("tailscale.bootstrap", init_script)
        self.assertIn("tailscale.connect", init_script)
        self.assertNotIn("sleep 1", apply_script)
        self.assertIn("https://login%.tailscale%.com/", modal)
        self.assertNotIn("authkey", modal.lower())

    def test_dumaos_is_pinned_verified_detected_and_armv7_only(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_dumaos()")
        end = installer.index("install_specific_files()", start)
        dumaos = installer[start:end]
        modal = MODAL.read_text()
        card = CARD.read_text()
        config = CONFIG.read_text()
        dumaos_modal = (GUI / "www/docroot/modals/dumaos-modal.lp").read_text()

        self.assertIn('dumaos_version="2.0-46"', dumaos)
        self.assertIn('dumaos_tag="dumaos-repack-v$dumaos_version"', dumaos)
        self.assertIn('dumaos-repack_${dumaos_version}_arm_cortex-a9.ipk', dumaos)
        self.assertIn(
            'dumaos_sha256="4fe83ddc7a34e1ada525302863f7683f54d1b37f21233c7db0750f253e50e4ef"',
            dumaos,
        )
        self.assertIn("releases/download/$dumaos_tag/$dumaos_package", dumaos)
        self.assertIn('dumaos_installed_version', dumaos)
        self.assertIn("sha256sum", dumaos)
        self.assertIn('opkg install "$dumaos_tmp"', dumaos)
        self.assertNotIn("--force-overwrite", dumaos)
        self.assertIn("opkg remove dumaos-repack", dumaos)
        self.assertIn("dumaos_install_qos_module", dumaos)
        self.assertIn("act-connmark-damson-4.1.52.ko", dumaos)
        self.assertIn("/www/cards/015_dumaos.lp", dumaos)
        self.assertNotIn("uci set web.dumaos_card", dumaos)
        self.assertNotIn('[ -f /www/cards/015_dumaos.lp ]', dumaos)
        self.assertIn("rm -f /www/cards/015_dumaos.lp", dumaos)
        self.assertIn("rm -f /www/cards/015_dumaos.lp", config)
        self.assertIn("uci -q delete web.dumaos_card", config)
        self.assertIn("uci set web.dumaosmodal=rule", dumaos)
        self.assertIn("web.ruleset_main.rules=dumaosmodal", dumaos)
        self.assertIn("uci -q delete web.dumaos_card", dumaos)
        self.assertIn("uci -q delete web.dumaosmodal", dumaos)
        self.assertIn('class="card-direct-link"', card)
        self.assertIn('url = "/desktop/"', card)
        self.assertIn('closest(".card-direct-link")', (GUI / "www/docroot/js/main-min-nojquery.js").read_text())
        self.assertNotIn(":81", card)
        self.assertIn('enabled = "rpc.dumaos.enabled"', dumaos_modal)
        self.assertIn('status = "rpc.dumaos.status"', dumaos_modal)
        self.assertIn('createSwitch(T"DumaOS service", "enabled"', dumaos_modal)
        self.assertIn('href="/desktop/"', dumaos_modal)
        self.assertIn("/usr/share/transformer/mappings/rpc/dumaos.map", dumaos)
        self.assertIn('mapParams.dumaos_application = "uci.modgui.app.dumaos_app"', modal)
        self.assertIn('mapParams.dumaos_application = "uci.modgui.app.dumaos_app"', card)
        self.assertIn('local dumaos_link = "/desktop/"', modal)
        self.assertIn("activated transactionally", modal)
        self.assertIn("opkg status dumaos-repack", config)
        self.assertIn("/www/data/shorthash", config)
        self.assertIn("/www/docroot/modals/dumaos-modal.lp", config)
        self.assertIn("dumaos_recover_if_enabled", dumaos)
        self.assertIn("cp /dumaossystem/version /www/data/shorthash", dumaos)
        self.assertIn("/usr/lib/dumaos/platform/control.sh start", dumaos)
        self.assertIn("/usr/lib/dumaos/platform/control.sh stop", dumaos)
        self.assertNotIn('if [ ! "$(uci get -q modgui.app.dumaos_app)" ]; then', config)
        self.assertIn("dumaos_remove_firewall", dumaos)
        self.assertIn('"DumaOS UI" | dumaos_ui', dumaos)
        self.assertNotIn("firewall.dumaos_ui=rule", dumaos)
        self.assertNotIn("curl | sh", dumaos)
        self.assertNotIn("curl | ash", dumaos)

    def test_arm_only_extensions_are_hidden_on_mips(self):
        modal = MODAL.read_text()
        card = CARD.read_text()
        condition = (
            'if cputype:match("^armv7") or cputype == "aarch64" '
            'or cputype == "arm64" then'
        )
        for source in (modal, card):
            self.assertIn(condition, source)
            block = source[source.index(condition):]
            block = block.split('if marketing_version >= 17.3 then', 1)[0]
            self.assertIn("speedtest_app", block)
            self.assertIn("adguardhome_app", block)
            self.assertIn("wireguard_app", block)
            self.assertIn("tailscale_app", block)

    def test_shell_sources_parse(self):
        sources = (
            INSTALLER,
            CONFIG,
            GUI / "usr/share/transformer/scripts/tailscaleApply.sh",
            GUI / "usr/share/transformer/scripts/tailscaleStatus.sh",
            GUI / "usr/share/transformer/scripts/wireguardApply.sh",
            GUI / "usr/share/transformer/scripts/wireguardStatus.sh",
            GUI / "usr/share/transformer/scripts/wireguardKeygen.sh",
            GUI / "usr/share/modgui-tailscale/tailscale.init",
            GUI / "usr/share/modgui-tailscale/tailscale.bootstrap",
            GUI / "usr/share/modgui-tailscale/tailscale.connect",
        )
        for source in sources:
            with self.subTest(source=source.name):
                subprocess.run(["sh", "-n", source], check=True)

    @unittest.skipUnless(shutil.which("luac"), "luac is not installed")
    def test_lua_sources_parse(self):
        sources = (
            RPC_MAP,
            UCI_MAP,
            MODAL,
            CARD,
            GUI / "usr/share/transformer/mappings/uci/tailscale.map",
            GUI / "usr/share/transformer/mappings/uci/wireguard.map",
            GUI / "usr/share/transformer/mappings/uci/wireguard.peer.map",
            GUI / "www/cards/016_tailscale.lp",
            GUI / "www/docroot/modals/tailscale-modal.lp",
            GUI / "www/cards/016_wireguard.lp",
            GUI / "www/docroot/modals/wireguard-modal.lp",
        )
        for source in sources:
            with self.subTest(source=source.name):
                subprocess.run(["luac", "-p", source], check=True)



INSTALLER_SOURCE = INSTALLER.read_text()
VPN_KERNEL_HELPER = INSTALLER_SOURCE[INSTALLER_SOURCE.index("modgui_kernel_abi_matches() ("):INSTALLER_SOURCE.index("app_wireguard() {")]


class KernelVPN(unittest.TestCase):
    def test_list_finishes_before_another_opkg_read_takes_the_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            script = VPN_KERNEL_HELPER + '''
uname() { echo 6.6.99; }
awk() { while read -r name rest; do printf '%s\n' "$name"; done; }
opkg() {
 case "$1" in
 list) touch "$testroot/lock"; echo 'kmod-wireguard - 6.6.99-1'; sleep 0.2; rm "$testroot/lock" ;;
 info) [ ! -f "$testroot/lock" ] || return 1; echo 'Version: 6.6.99-1' ;;
 status) return 0 ;;
 esac
}
testroot="$1"
modgui_kernel_package '^kmod-wireguard(-|$)'
'''
            result = subprocess.run(["sh", "-c", script, "lock-test", directory], capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout.strip(), "kmod-wireguard")

    def test_same_release_with_different_feed_kernel_abi_is_rejected(self):
        for feed_abi in ("live-abi", "other-abi"):
            with self.subTest(feed_abi=feed_abi), tempfile.TemporaryDirectory() as directory:
                Path(directory, "kernel-feed").write_text(
                    "Package: kernel\nVersion: 6.6.99-1-" + feed_abi + "\n\n"
                    "Package: kmod-wireguard\nVersion: 6.6.99-1\n\n"
                    "Package: kmod-tun\nVersion: 6.6.99-1\n\n"
                    "Package: kmod-bcmspu\nVersion: 6.6.99-1\n"
                )
                helper = VPN_KERNEL_HELPER.replace("/var/opkg-lists", directory)
                script = helper + '''
uname() { echo 6.6.99; }
opkg() {
 case "$1" in
 status) echo 'Version: 6.6.99-1-live-abi' ;;
 list) printf '%s\n' 'kmod-wireguard - 6.6.99-1' 'kmod-tun - 6.6.99-1' 'kmod-bcmspu - 6.6.99-1' ;;
 info) echo 'Version: 6.6.99-1' ;;
 esac
}
modgui_kernel_package '^kmod-'
'''
                result = subprocess.run(["sh", "-c", script], capture_output=True, text=True, check=True)
                self.assertEqual(bool(result.stdout.strip()), feed_abi == "live-abi")
                self.assertEqual("ABI mismatch" in result.stderr, feed_abi != "live-abi")

    def test_module_selection_uses_current_kernel_without_firmware_lookup(self):
        for kernel in ("4.1.38", "4.1.52", "6.6.99"):
            with self.subTest(kernel=kernel):
                script = VPN_KERNEL_HELPER + f'''
uname() {{ echo {kernel}; }}
uci() {{ echo UNEXPECTED_FIRMWARE_CHECK >&2; return 1; }}
opkg() {{
  case "$*" in
    list) printf '%s\\n' 'kmod-wireguard - 4.1.38+1.0.20220627-1' 'kmod-wireguard-current - {kernel}-2' ;;
    'info kmod-wireguard') echo 'Version: 4.1.38+1.0.20220627-1' ;;
    'info kmod-wireguard-current') echo 'Version: {kernel}-2' ;;
  esac
}}
modgui_kernel_package '^kmod-wireguard(-|$)'
'''
                result = subprocess.run(["sh", "-c", script], capture_output=True, text=True, check=True)
                expected = "kmod-wireguard" if kernel == "4.1.38" else "kmod-wireguard-current"
                self.assertEqual(result.stdout.strip(), expected)
                self.assertEqual(result.stderr, "")

    def test_dependency_requires_exact_kernel_release(self):
        for dependency, expected in (("4.1.52-1", ""), ("4.1.5-1", "kmod-wireguard")):
            script = VPN_KERNEL_HELPER + f'''
uname() {{ echo 4.1.5; }}
opkg() {{
 case "$1" in
 list) echo 'kmod-wireguard - 1.0.1' ;;
 info) printf '%s\\n' 'Version: 1.0.1' 'Depends: kernel (= {dependency}), libc' ;;
 esac
}}
modgui_kernel_package '^kmod-wireguard(-|$)'
'''
            result = subprocess.run(["sh", "-c", script], capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout.strip(), expected)

    def test_missing_udp_dependency_stops_before_inserting_wireguard(self):
        result = subprocess.run(["sh", "-c", VPN_KERNEL_HELPER + '''
modprobe() { return 1; }
insmod() { echo UNEXPECTED_INSERT; }
modgui_load_wireguard
'''], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("UNEXPECTED_INSERT", result.stdout)

    def test_spu_only_sets_supported_module_options(self):
        for supports_option in (False, True):
            with self.subTest(supports_option=supports_option), tempfile.TemporaryDirectory() as directory:
                Path(directory, "bcmspu.ko").touch()
                helper = VPN_KERNEL_HELPER.replace('/lib/modules/$(uname -r)', directory).replace('/etc/modules.d', directory)
                script = helper + f'''
grep() {{ case "$*" in */proc/modules*) return 1 ;; *) command grep "$@" ;; esac; }}
strings() {{ return 1; }}
modinfo() {{ echo {'blog_offload:ESP flow offload' if supports_option else 'other:Other option'}; }}
modprobe() {{ echo "$*"; }}
modgui_load_spu
'''
                result = subprocess.run(["sh", "-c", script], capture_output=True, text=True, check=True)
                self.assertEqual(result.stdout.strip(), "bcmspu blog_offload=N" if supports_option else "bcmspu")

    def test_native_apply_needs_no_tun_and_stops_on_load_failure(self):
        script = (GUI / "usr/share/transformer/scripts/wireguardApply.sh").read_text()
        script = script[script.index('if [ "$native" = 0 ]; then'):]
        script = script.replace("modprobe udp_tunnel && modprobe ip6_udp_tunnel", "load_native")
        for status in (0, 1):
            result = subprocess.run(["sh", "-c", f'''
native=1
load_native() {{ return {status}; }}
grep() {{ return 0; }}
configure_network() {{ echo CONFIGURED; }}
''' + script], capture_output=True, text=True)
            self.assertEqual(result.returncode, status)
            self.assertEqual("CONFIGURED" in result.stdout, status == 0)

    def test_go_backup_is_not_needed_for_fresh_install_or_failed_module_load(self):
        for go_installed, load_status in ((False, 0), (True, 1)):
            with self.subTest(go_installed=go_installed), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "etc").mkdir()
                if go_installed:
                    (root / "etc/.modgui-wireguard-go-installed").touch()
                    (root / "go-installed").touch()
                (root / "wg").write_text("#!/bin/sh\nexit 0\n")
                (root / "wg").chmod(0o755)
                (root / "wireguard.sh").touch(mode=0o755)
                helper = VPN_KERNEL_HELPER.replace("/etc/", directory + "/etc/")
                helper = helper.replace("/usr/bin/wg", str(root / "wg"))
                helper = helper.replace("/lib/netifd/proto/wireguard.sh", str(root / "wireguard.sh"))
                script = helper + f'''
modgui_backup_wireguard_go() {{ echo UNEXPECTED_BACKUP; return 1; }}
modgui_load_wireguard() {{ return {load_status}; }}
uci() {{ return 0; }}
opkg() {{
  case "$*" in
    list-installed) [ ! -f '{directory}/go-installed' ] || echo 'wireguard-go - installed-version' ;;
    remove*) echo "REMOVED:$2" ;;
  esac
  return 0
}}
modgui_install_native_wireguard kmod-wireguard
'''
                result = subprocess.run(["sh", "-c", script], capture_output=True, text=True)
                self.assertEqual(result.returncode, load_status, result.stderr)
                self.assertNotIn("UNEXPECTED_BACKUP", result.stdout)
                self.assertNotIn("REMOVED:wireguard-go", result.stdout)
                self.assertEqual((root / "etc/.modgui-wireguard-native-installed").exists(), not go_installed)

    def test_failed_tools_install_restores_installed_go_payload(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "etc").mkdir()
            (root / "etc/.modgui-wireguard-go-installed").touch()
            (root / "go-installed").touch()
            helper = VPN_KERNEL_HELPER.replace("/etc/", directory + "/etc/")
            script = helper + f'''
modgui_backup_wireguard_go() {{ touch "$1/go.ipk"; }}
modgui_load_wireguard() {{ return 0; }}
uci() {{ return 0; }}
opkg() {{
  case "$*" in
    list-installed) [ ! -f '{directory}/go-installed' ] || echo 'wireguard-go - installed-version' ;;
    'remove wireguard-go') rm '{directory}/go-installed' ;;
    'remove wireguard-tools'|'remove kmod-wireguard') return 0 ;;
    'install wireguard-tools') return 1 ;;
    'install kmod-wireguard') return 0 ;;
    install*) touch '{directory}/go-installed'; echo GO_RESTORED ;;
  esac
}}
modgui_install_native_wireguard kmod-wireguard
'''
            result = subprocess.run(["sh", "-c", script], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("GO_RESTORED", result.stdout)
            self.assertTrue((root / "go-installed").exists())
            self.assertFalse((root / "etc/.modgui-wireguard-native-installed").exists())


if __name__ == "__main__":
    unittest.main()
