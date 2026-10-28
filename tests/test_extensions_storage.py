"""Render storage availability and architecture-specific USB requirements."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

MODAL = Path(__file__).resolve().parents[1] / 'decompressed/gui_file/www/docroot/modals/applications-modal.lp'


class InstallerStorage(unittest.TestCase):
    def test_unlimited_tmpfs_uses_ram_without_overriding_full_filesystems(self):
        source = (MODAL.parents[3] / "usr/share/transformer/scripts/appInstallRemoveUtility.sh").read_text()
        function = source[source.index("require_free_space() {"):source.index("\nadblock_cleanup_dns()")]
        cases = (
            ("tmpfs", 0, 0, "MemAvailable: 70000 kB\n", True),
            ("tmpfs", 0, 0, "MemAvailable: 30000 kB\n", False),
            ("tmpfs", 65536, 0, "MemAvailable: 70000 kB\n", False),
            ("ext4", 0, 0, "MemAvailable: 70000 kB\n", False),
            ("tmpfs", 0, 0, "MemFree: 10000 kB\nBuffers: 10000 kB\nCached: 30000 kB\n", True),
        )
        for filesystem, total, free, memory, expected in cases:
            with self.subTest(filesystem=filesystem, total=total, memory=memory), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "mounts").write_text(f"tmpfs /tmp {filesystem} rw 0 0\n")
                (root / "meminfo").write_text(memory)
                private = function.replace("/proc/mounts", str(root / "mounts")).replace("/proc/meminfo", str(root / "meminfo"))
                script = private + '\ndf() { echo "Filesystem 1024-blocks Used Available Capacity Mounted"; echo "tmpfs DFTOTAL 0 DFFREE 0% /tmp"; }\nrequire_free_space 40960 /tmp/staging\n'
                script = script.replace("DFTOTAL", str(total)).replace("DFFREE", str(free))
                result = subprocess.run(["sh", "-c", script], capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, expected, result.stdout + result.stderr)


@unittest.skipUnless(shutil.which('lua'), 'Lua interpreter required')
class ExtensionsStorage(unittest.TestCase):
    def render(self, cpu, mode):
        harness = r'''
T = function(text) return text end
gettext = {textdomain = function() end}
ngx = {var = {host = 'gateway.test'}, req = {get_method = function() return 'GET' end},
    print = function(value) io.write(type(value) == 'table' and table.concat(value) or value) end}
package.preload.datamodel = function() return {get = function(path)
    return {{value = path:find('CPUtype') and arg[2] or '19.4'}}
end} end
package.preload['web.content_helper'] = function() return {getExactContent = function(params)
    for key in pairs(params) do params[key] = '0' end
end} end
package.preload['web.ui_helper'] = function() return setmetatable({}, {__index = function()
    return function() return '' end
end}) end
package.preload['tch.posix'] = function()
    if arg[3] == 'missing' then error('module unavailable') end
    return {statvfs = function(path)
        if arg[3] == 'failed' then error('device removed') end
        -- A much larger inactive bank must never be used as app capacity.
        assert(path ~= '/overlay', 'must measure active application filesystem')
        local blocks = ({['/usr'] = 1800, ['/tmp'] = 8192,
            ['/tmp/run/mountd/sda'] = 2097152, ['/tmp/run/mountd/sdb1'] = 256})[path]
        assert(blocks, path)
        return {f_bavail = arg[3] == 'zero' and 0 or blocks, f_bfree = 9999999,
            f_bsize = 4096, f_frsize = 4096}
    end}
end
io.popen = function() return {read = function() return '0' end, close = function() end} end
io.open = function(path)
    if path ~= '/proc/mounts' or arg[3] == 'missing' then return nil end
    local mounts = '/dev/root / squashfs ro 0 0\n/dev/sda /tmp/run/mountd/sda vfat rw,noatime 0 0\n' ..
        '/dev/sdb1 /tmp/run/mountd/sdb1 ext4 ro 0 0\n'
    return {lines = function() return mounts:gmatch('[^\n]+') end, close = function() end}
end
dofile(arg[1])
'''
        result = subprocess.run(['lua', '-', str(MODAL), cpu, mode], input=harness,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_active_internal_and_raw_or_partitioned_usb_space(self):
        html = self.render('mips', 'normal')
        self.assertIn('Internal storage: 7.03 MiB', html)
        self.assertIn('USB sda: 8.00 GiB</span>', html)
        self.assertIn('USB sdb1: 1.00 MiB (Read-only)', html)
        self.assertNotIn('USB: no mounted drive', html)
        self.assertEqual(html.count('>USB required</span>'), 3)
        for title in ('aMule', 'Aria2 GUI', 'Transmission GUI'):
            card = html.split('<legend>' + title + '</legend>', 1)[1].split('</fieldset>', 1)[0]
            self.assertIn('>USB required</span>', card)

    def test_arm_downloaders_and_amule_report_usb_requirement(self):
        html = self.render('armv7l', 'normal')
        self.assertEqual(html.count('>USB required</span>'), 3)
        self.assertIn('<legend>aMule</legend>', html)

    def test_missing_mounts_or_failed_stats_render_unavailable(self):
        for mode in ('missing', 'failed'):
            with self.subTest(mode=mode):
                html = self.render('mips', mode)
                self.assertIn('Internal storage: Unavailable', html)
                if mode == 'missing':
                    self.assertIn('USB: no mounted drive', html)
                else:
                    self.assertIn('USB sda: Unavailable', html)

    def test_full_filesystem_shows_zero_instead_of_unknown(self):
        self.assertIn('Internal storage: 0.00 MiB', self.render('mips', 'zero'))


if __name__ == '__main__':
    unittest.main()
