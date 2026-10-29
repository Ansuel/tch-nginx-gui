"""Exercise feed registration against isolated opkg configuration files."""
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'decompressed/gui_file/etc/modgui_scripts/02_specific.sh'


class OpkgFeeds(unittest.TestCase):
    def test_legacy_kernel_feed_and_its_cached_indexes_are_removed(self):
        source = SOURCE.read_text()
        helper = source[source.index('remove_legacy_kernel_feed()'):source.index('apply_right_opkg_repo()')]
        for ending in ('', '/', ' # obsolete', '/ # obsolete'):
            with self.subTest(ending=ending), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                directory = root / 'opkg'
                directory.mkdir()
                cache = root / 'cache'
                cache.mkdir()
                legacy = 'https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/target/packages' + ending
                conf = root / 'opkg.conf'
                conf.write_text(f'lists_dir ext {cache}\nsrc/gz chaos_calmer_core {legacy}\nsrc/gz keep https://example.invalid/packages\n')
                extra = directory / 'customfeeds.conf'
                extra.write_text(f'src/gz old_custom {legacy}\nsrc/gz userspace https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/base\n')
                for name in ('chaos_calmer_core', 'old_custom', 'keep'):
                    (cache / name).write_text('cached index')
                # Keep every path private, including the default index directories.
                private = helper.replace('/var/opkg-lists', str(cache)).replace('/tmp/opkg-lists', str(cache)).replace('/usr/lib/opkg/lists', str(cache))
                if shutil.which('gsed'):
                    private = private.replace('sed -i', shutil.which('gsed') + ' -i')
                script = private + f'\nopkg_file={shlex.quote(str(conf))}\nopkg_config_dir={shlex.quote(str(directory))}\nremove_legacy_kernel_feed\nremove_legacy_kernel_feed\n'
                subprocess.run(['sh', '-c', script], check=True)
                self.assertNotIn('target/packages', conf.read_text())
                self.assertNotIn('target/packages', extra.read_text())
                self.assertIn('src/gz keep ', conf.read_text())
                self.assertIn('kernel-4.1/base', extra.read_text())
                self.assertFalse((cache / 'chaos_calmer_core').exists())
                self.assertFalse((cache / 'old_custom').exists())
                self.assertTrue((cache / 'keep').exists())

    def test_no_install_branch_adds_the_legacy_kernel_feed(self):
        source = SOURCE.read_text()
        apply = source[source.index('apply_right_opkg_repo()'):source.index('ledfw_extract()')]
        self.assertIn('remove_legacy_kernel_feed', apply)
        self.assertNotIn('kernel-4.1/target/packages', apply)

    def test_arm_feed_setup_does_not_reintroduce_legacy_kernel_source(self):
        source = SOURCE.read_text()
        functions = source[source.index('append_missing_opkg_feeds()'):source.index('ledfw_extract()')]
        for version in ('18.3', '19.4'):
            with self.subTest(version=version), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                (root / 'opkg').mkdir()
                conf = root / 'opkg.conf'
                conf.write_text('src/gz chaos_calmer_core https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/target/packages\n')
                private = functions.replace('/etc/opkg', str(root / 'opkg'))
                for directory in ('/var/opkg-lists', '/tmp/opkg-lists', '/usr/lib/opkg/lists'):
                    private = private.replace(directory, str(root / 'cache'))
                if shutil.which('gsed'):
                    private = private.replace('sed -i', shutil.which('gsed') + ' -i')
                script = private + f'''
logecho() {{ :; }}
cpu_type=armv7l
marketing_version={version}
uname() {{ echo 4.1.38; }}
uci() {{ echo VBNT-O; }}
curl() {{ return 0; }}
opkg() {{ echo 'arch brcm963xx 100'; }}
apply_right_opkg_repo
apply_right_opkg_repo
'''
                subprocess.run(['sh', '-c', script], check=False, capture_output=True, text=True)
                result = conf.read_text()
                self.assertNotIn('kernel-4.1/target/packages', result)
                self.assertIn('kernel/4.1.38-vbnto', result)
                self.assertIn('kernel-4.1/base', result)

    def test_vpn_feeds_follow_running_kernel_and_skip_missing_indexes(self):
        source = SOURCE.read_text()
        helper = source[source.index('append_missing_opkg_feeds()'):source.index('apply_right_opkg_repo()')]
        for available in (False, True):
            with self.subTest(available=available), tempfile.TemporaryDirectory() as tmp:
                conf = Path(tmp) / 'opkg.conf'
                conf.touch()
                script = helper + f'''
opkg_file={shlex.quote(str(conf))}
opkg_config_dir={shlex.quote(tmp)}
uname() {{ echo 6.6.99-custom; }}
curl() {{ return {0 if available else 1}; }}
opkg() {{ awk '$1 == "arch" {{print "arch", $2, $3}}' "$opkg_file"; }}
append_gui_vpn_feeds
append_gui_vpn_feeds
'''
                subprocess.run(['sh', '-c', script], check=True)
                lines = conf.read_text().splitlines()
                self.assertEqual(lines.count('src/gz modgui_base https://francyesco.github.io/GUI_ipk/base'), 1)
                kernel_feed = 'src/gz modgui_kernel_6.6.99-custom https://francyesco.github.io/GUI_ipk/kernel/6.6.99-custom'
                self.assertEqual(lines.count(kernel_feed), int(available))
                self.assertEqual(lines.count('arch brcm963xx 100'), int(available))

    def test_platform_feed_is_normalized_and_probed_independently(self):
        source = SOURCE.read_text()
        helper = source[source.index('append_missing_opkg_feeds()'):source.index('apply_right_opkg_repo()')]
        for product, platform in (("VBNT-O_fastweb", "vbnto"), ("VBNT-S", "vbnts")):
            for generic_available in (False, True):
                with self.subTest(product=product, generic_available=generic_available), tempfile.TemporaryDirectory() as tmp:
                    conf = Path(tmp) / 'opkg.conf'
                    conf.touch()
                    script = helper + f'''
opkg_file={shlex.quote(str(conf))}
opkg_config_dir={shlex.quote(tmp)}
uname() {{ echo 4.1.38; }}
uci() {{ echo {shlex.quote(product)}; }}
curl() {{
  case "$2" in
    */4.1.38-{platform}/Packages.gz) return 0 ;;
    *) return {0 if generic_available else 1} ;;
  esac
}}
opkg() {{ echo 'arch brcm963xx 100'; }}
append_gui_vpn_feeds
append_gui_vpn_feeds
'''
                    subprocess.run(['sh', '-c', script], check=True)
                    lines = conf.read_text().splitlines()
                    self.assertEqual(lines.count(f'src/gz modgui_kernel_4.1.38_{platform} https://francyesco.github.io/GUI_ipk/kernel/4.1.38-{platform}'), 1)
                    self.assertEqual(lines.count('src/gz modgui_kernel_4.1.38 https://francyesco.github.io/GUI_ipk/kernel/4.1.38'), int(generic_available))

    def test_custom_partial_commented_and_repeated_feeds(self):
        source = SOURCE.read_text()
        helper = source[source.index('append_missing_opkg_feeds()'):source.index('apply_right_opkg_repo()')]
        for custom in (False, True):
            with self.subTest(custom=custom), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp)
                conf = base / 'opkg.conf'
                conf.write_text('# src/gz feed_a https://old.invalid/a\n')
                directory = base / 'opkg'
                if custom:
                    directory.mkdir()
                    (directory / 'customfeeds.conf').write_text('src/gz feed_a https://custom.invalid/a\n')
                    (directory / 'extra.conf').write_text('src feed_b https://custom.invalid/b\n')
                script = helper + '\nopkg_file=' + shlex.quote(str(conf)) + '\nopkg_config_dir=' + shlex.quote(str(directory)) + '\n'
                script += 'append_missing_opkg_feeds <<EOF\nsrc/gz feed_a https://new.invalid/a\nsrc/gz feed_b https://new.invalid/b\nsrc/gz feed_c https://new.invalid/c\nEOF\n'
                for _ in range(2):
                    subprocess.run(['sh', '-c', script], check=True)
                lines = conf.read_text().splitlines()
                actual = [line.split()[1] for line in lines if line.startswith('src')]
                self.assertEqual(actual, ['feed_c'] if custom else ['feed_a', 'feed_b', 'feed_c'])
                if custom:
                    self.assertEqual((directory / 'customfeeds.conf').read_text(), 'src/gz feed_a https://custom.invalid/a\n')


if __name__ == '__main__':
    unittest.main()
