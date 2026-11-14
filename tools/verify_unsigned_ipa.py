#!/usr/bin/env python3
"""Verify an unsigned arm64 iPhone IPA's ZIP/plist/Mach-O structure, not runtime behavior."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import struct
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(path):
    path = Path(path)
    with zipfile.ZipFile(path) as archive:
        infos = archive.infolist()
        names = [i.filename for i in infos]
        require(len(names) == len(set(names)), 'Duplicate archive entries')
        require(len(names) < 10000 and sum(i.file_size for i in infos) < 512 * 1024 * 1024,
                'Unexpectedly large application archive')
        for name in names:
            parts = PurePosixPath(name).parts
            require(not name.startswith('/') and '..' not in parts and '\\' not in name, 'Unsafe ZIP path')
            require(name == 'Payload/' or name.startswith('Payload/FredyTest.app/'), 'Unexpected IPA content')
            require('_CodeSignature' not in parts and not name.endswith('.mobileprovision'), 'Signing material found')
        require(archive.testzip() is None, 'Corrupt IPA archive')
        base = 'Payload/FredyTest.app/'
        info = plistlib.loads(archive.read(base + 'Info.plist'))
        require(info.get('CFBundlePackageType') == 'APPL', 'Not an application bundle')
        require(info.get('CFBundleSupportedPlatforms') == ['iPhoneOS'], 'Not an iphoneos device build')
        require(1 in info.get('UIDeviceFamily', []), 'iPhone not supported')
        executable = info.get('CFBundleExecutable')
        require(executable == 'FredyTest', 'Unexpected executable')
        binary = archive.read(base + executable)
        require(len(binary) >= 32, 'Missing Mach-O header')
        magic, cpu, _, filetype, count, size, _, _ = struct.unpack_from('<8I', binary)
        require(magic == 0xFEEDFACF and cpu == 0x0100000C and filetype == 2, 'Expected thin arm64 executable')
        end = 32 + size
        require(count <= 4096 and end <= len(binary), 'Invalid Mach-O load commands')
        offset = 32
        platform = None
        for _ in range(count):
            require(offset + 8 <= end, 'Truncated Mach-O command')
            command, length = struct.unpack_from('<2I', binary, offset)
            require(length >= 8 and offset + length <= end, 'Invalid Mach-O command size')
            require(command != 0x1D, 'Executable contains a code signature')
            if command == 0x32:
                require(length >= 24, 'Invalid build-version command')
                platform = struct.unpack_from('<I', binary, offset + 8)[0]
            offset += length
        require(offset == end and platform == 2, 'Expected iOS device platform, not simulator')
    return {'filename': path.name, 'bytes': path.stat().st_size,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'bundle_id': info.get('CFBundleIdentifier'), 'architecture': 'arm64',
            'platform': 'iPhoneOS', 'unsigned': True, 'zip_entries': len(names)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.ipa), indent=2))
