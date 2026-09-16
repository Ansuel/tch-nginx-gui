#!/usr/bin/env python3
"""Validate packaged files against processed sources, without extracting archives."""
import argparse
import hashlib
import os
from pathlib import Path, PurePosixPath
import stat
import tarfile


def file_entry(path):
    mode = stat.S_IMODE(path.lstat().st_mode)
    if path.is_symlink():
        return ('link', mode, os.readlink(path))
    if path.is_dir():
        return ('dir', mode, None)
    return ('file', mode, hashlib.sha256(path.read_bytes()).hexdigest())


def tree_entries(root):
    entries = {}
    for base, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            path = Path(base) / name
            entries[path.relative_to(root).as_posix()] = file_entry(path)
    return entries


def verify_archive(path, expected):
    with tarfile.open(path, 'r:bz2') as archive:
        seen = set()
        for member in archive:
            name = member.name.rstrip('/')
            if PurePosixPath(name).is_absolute() or '..' in PurePosixPath(name).parts:
                raise ValueError(f'{path.name}: unsafe path {name}')
            if name in seen or name not in expected:
                raise ValueError(f'{path.name}: duplicate or unexpected entry {name}')
            seen.add(name)
            kind, mode, content = expected[name]
            if member.uid != 0 or member.gid != 0:
                raise ValueError(f'{path.name}: non-root ownership for {name}')
            actual_kind = 'dir' if member.isdir() else 'link' if member.issym() else 'file' if member.isfile() else 'unsupported'
            if actual_kind != kind:
                raise ValueError(f'{path.name}: wrong entry type for {name}')
            # Directory modes can differ when modules are merged; files may not.
            if kind == 'file' and member.mode != mode:
                raise ValueError(f'{path.name}: wrong permissions for {name}')
            if kind == 'link' and member.linkname != content:
                raise ValueError(f'{path.name}: wrong symlink target for {name}')
            if kind == 'file':
                stream = archive.extractfile(member)
                digest = hashlib.sha256()
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(chunk)
                if digest.hexdigest() != content:
                    raise ValueError(f'{path.name}: wrong content for {name}')
            if name == 'tmp' and member.mode != mode:
                raise ValueError(f'{path.name}: wrong tmp permissions')
        missing = set(expected) - seen
        if missing:
            raise ValueError(f'{path.name}: missing entries: {", ".join(sorted(missing)[:10])}')


def verify_build(root):
    sources = root / 'decompressed'
    output = root / 'compressed'
    build_type = (root / 'data/type').read_text().strip()
    suffix = {'STABLE': '', 'DEV': '_dev', 'PREVIEW': '_preview'}[build_type]
    version = (root / 'data/version').read_text().strip()
    rootdevice = sources / 'base/etc/init.d/rootdevice'
    if f'version_gui={version}-' not in rootdevice.read_text():
        raise ValueError('rootdevice does not contain the build version')
    required = [rootdevice, sources/'gui_file/usr/share/transformer/scripts/checkver',
                sources/'gui_file/usr/share/transformer/scripts/upgradegui']
    for path in required:
        if not path.is_file():
            raise ValueError(f'Missing required file: {path}')
        if not path.stat().st_mode & 0o111:
            raise ValueError(f'Required script is not executable: {path}')
    expected_archives = set()
    for module in sorted(sources.iterdir()):
        if module.is_dir():
            filename = module.name + '.tar.bz2'
            verify_archive(output / filename, tree_entries(module))
            expected_archives.add(filename)
    merged = {}
    for module in ('base', 'gui_file', 'traffic_mon'):
        merged.update(tree_entries(sources / module))
    merged['tmp'] = ('dir', 0o777, None)
    for filename in expected_archives:
        if filename not in ('base.tar.bz2', 'gui_file.tar.bz2', 'traffic_mon.tar.bz2') and not filename.startswith('upgrade-pack-'):
            merged['tmp/' + filename] = file_entry(output / filename)
    gui = 'GUI' + suffix + '.tar.bz2'
    verify_archive(output / gui, merged)
    expected_archives.add(gui)
    actual = {path.name for path in output.glob('*.tar.bz2')}
    if actual != expected_archives:
        raise ValueError(f'Unexpected archive set: {actual ^ expected_archives}')
    print(f'Verified {len(expected_archives)} archives: content, permissions, symlinks, ownership and required files.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    args = parser.parse_args()
    try:
        verify_build(args.root)
    except (ValueError, KeyError, OSError, tarfile.TarError) as exc:
        parser.exit(1, f'Archive verification failed: {exc}\n')
