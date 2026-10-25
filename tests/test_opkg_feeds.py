"""Exercise feed registration against isolated opkg configuration files."""
from pathlib import Path
import shlex
import shutil
import sys
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'decompressed/gui_file/etc/modgui_scripts/02_specific.sh'


class OpkgFeeds(unittest.TestCase):
    def test_global_download_timeout_is_bounded_and_idempotent(self):
        source = SOURCE.read_text()
        helper = source[source.index('configure_opkg_timeout()'):source.index('apply_right_opkg_repo()')]
        if sys.platform == 'darwin':
            if not shutil.which('gsed'):
                self.skipTest('GNU sed required to emulate BusyBox sed -i')
            helper = helper.replace('sed -i', shlex.quote(shutil.which('gsed')) + ' -i')
        cases = [
            ('', '', 30),
            ('option http_timeout 0\n', '', 30),
            ('option http_timeout invalid\n', '', 30),
            ('option http_timeout 120\n', '', 120),
            ('', 'option http_timeout 45\n', 45),
            ('', 'option http_timeout "60"\n', 60),
            ('', 'option http_timeout 0\n', 30),
            ('option http_timeout 0\n', 'option http_timeout 90\n', 30),
        ]
        for main, extra, expected in cases:
            with self.subTest(main=main, extra=extra), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp)
                conf = base / 'opkg.conf'
                feeds = 'arch all 100\nsrc/gz base https://example.test/base\n'
                conf.write_text(feeds + main)
                directory = base / 'opkg'
                directory.mkdir()
                custom = directory / 'custom.conf'
                custom.write_text(extra)
                script = (helper + '\nopkg_file=' + shlex.quote(str(conf)) +
                          '\nopkg_config_dir=' + shlex.quote(str(directory)) + '\nconfigure_opkg_timeout\n')
                subprocess.run(['sh', '-c', script], check=True)
                updated = conf.read_text()
                subprocess.run(['sh', '-c', script], check=True)
                self.assertEqual(conf.read_text(), updated)
                self.assertEqual(custom.read_text(), extra)
                self.assertTrue(updated.startswith(feeds))
                values = [line.split()[2].strip('"') for line in (updated + extra).splitlines()
                          if line.startswith('option http_timeout ')]
                self.assertEqual(int(values[0]), expected)

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
