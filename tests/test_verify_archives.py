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
