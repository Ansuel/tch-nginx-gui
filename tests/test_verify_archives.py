import importlib.util
import io
from pathlib import Path
import tarfile
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('verify_archives', Path(__file__).resolve().parents[1]/'scripts/verify_archives.py')
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class ArchiveVerification(unittest.TestCase):
    def test_optional_luci_archive_is_released_but_not_embedded_in_gui(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            files = {
                'data/type': 'STABLE', 'data/version': '1.2.3',
                'decompressed/base/etc/init.d/rootdevice': 'version_gui=1.2.3-DEV',
                'decompressed/gui_file/usr/share/transformer/scripts/checkver': '# check',
                'decompressed/gui_file/usr/share/transformer/scripts/upgradegui': '# upgrade',
                'decompressed/traffic_mon/usr/bin/traffic': '# traffic',
                'decompressed/luci_wireless/usr/lib/lua/luci/model/tch_wireless.lua': '-- optional',
                'decompressed/another_module/extra': 'embedded legacy module',
            }
            for name, value in files.items():
                path = root/name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(value)
                if path.name in ('rootdevice', 'checkver', 'upgradegui'):
                    path.chmod(0o755)
            output = root/'compressed'
            output.mkdir()

            def pack(path, entries):
                with tarfile.open(path, 'w:bz2') as archive:
                    for name, source in sorted(entries.items()):
                        if source is None:
                            item = tarfile.TarInfo(name)
                            item.type = tarfile.DIRTYPE
                            item.mode = 0o777
                        else:
                            item = archive.gettarinfo(str(source), name)
                        item.uid = item.gid = 0
                        if source is not None and item.isfile():
                            with source.open('rb') as stream:
                                archive.addfile(item, stream)
                        else:
                            archive.addfile(item)

            merged = {'tmp': None}
            for module in (root/'decompressed').iterdir():
                entries = {name: module/name for name in verify.tree_entries(module)}
                pack(output/(module.name+'.tar.bz2'), entries)
                if module.name in ('base', 'gui_file', 'traffic_mon'):
                    merged.update(entries)
                elif module.name != 'luci_wireless':
                    merged['tmp/'+module.name+'.tar.bz2'] = output/(module.name+'.tar.bz2')
            pack(output/'GUI.tar.bz2', merged)
            verify.verify_build(root)
            with tarfile.open(output/'GUI.tar.bz2') as archive:
                self.assertFalse(any('luci_wireless' in n or '/lua/luci/' in n for n in archive.getnames()))
            self.assertTrue((output/'luci_wireless.tar.bz2').is_file())

    def test_rejects_corrupt_structure_permissions_contents_and_links(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root/'source'
            source.mkdir()
            script = source/'run'
            script.write_bytes(b'good')
            script.chmod(0o755)
            (source/'link').symlink_to('run')
            expected = verify.tree_entries(source)
            for defect in (None, 'missing', 'content', 'mode', 'link', 'owner', 'extra'):
                with self.subTest(defect=defect):
                    path = root/'test.tar.bz2'
                    with tarfile.open(path, 'w:bz2') as archive:
                        info = tarfile.TarInfo('run')
                        info.mode = 0o644 if defect == 'mode' else 0o755
                        info.uid = 1000 if defect == 'owner' else 0
                        info.size = 4
                        if defect != 'missing':
                            archive.addfile(info, io.BytesIO(b'evil' if defect == 'content' else b'good'))
                        link = tarfile.TarInfo('link')
                        link.type = tarfile.SYMTYPE
                        link.linkname = '/wrong' if defect == 'link' else 'run'
                        archive.addfile(link)
                        if defect == 'extra':
                            archive.addfile(tarfile.TarInfo('extra'))
                    if defect is None:
                        verify.verify_archive(path, expected)
                    else:
                        with self.assertRaises(ValueError):
                            verify.verify_archive(path, expected)
