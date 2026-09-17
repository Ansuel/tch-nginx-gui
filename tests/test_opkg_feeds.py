"""Exercise feed registration against isolated opkg configuration files."""
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'decompressed/gui_file/etc/modgui_scripts/02_specific.sh'


class OpkgFeeds(unittest.TestCase):
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
