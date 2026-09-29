import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import re


STATUS = 'UNSIGNED DEVELOPMENT-ONLY'
PREFIX = b'\x00\x93\x04\x10duckdb_signature\x80\x04'
NATIVE = {'linux_amd64', 'linux_arm64', 'osx_amd64', 'osx_arm64', 'windows_amd64', 'windows_amd64_mingw'}
WASM = {'wasm_eh', 'wasm_mvp'}
MAGIC = {'wasm': b'\x00asm\x01\x00\x00\x00', 'osx': b'\xcf\xfa\xed\xfe', 'linux': b'\x7fELF', 'windows': b'MZ'}


def validate(target, version, platform, source):
    if not re.fullmatch(r'v[0-9]+\.[0-9]+\.[0-9]+', version):
        raise ValueError(f'Invalid engine version: {version}')
    if platform not in {'native': NATIVE, 'wasm': WASM}.get(target, set()):
        raise ValueError(f'Unsupported target/platform: {target}/{platform}')
    data = Path(source).read_bytes()
    if len(data) < 512 + len(PREFIX) or data[-512-len(PREFIX):-512] != PREFIX:
        raise ValueError(f'{source}: missing DuckDB metadata prefix')
    fields = []
    for offset in range(len(data) - 512, len(data) - 256, 32):
        field = data[offset:offset+32]
        text = field.rstrip(b'\0')
        if b'\0' in text:
            raise ValueError(f'{source}: invalid metadata padding')
        fields.append(text.decode('ascii'))
    if fields[:3] != ['', '', ''] or fields[3] != 'CPP' or not fields[4] or fields[7] != '4':
        raise ValueError(f'{source}: unsupported metadata/ABI/header')
    if fields[5:7] != [version, platform]:
        raise ValueError(f'{source}: metadata mismatch: expected {version}/{platform}, found {fields[5]}/{fields[6]}')
    if data[-256:] != bytes(256):
        raise ValueError(f'{source}: nonzero signature; this tool only stages unsigned development artifacts')
    magic = MAGIC[platform.split('_')[0]]
    if not data.startswith(magic):
        raise ValueError(f'{source}: binary format does not match target')
    return data, fields[4]


def stage(output, artifacts):
    entries = []
    validated = []
    seen = set()
    for target, version, platform, source in artifacts:
        original, extension_version = validate(target, version, platform, source)
        key = (version, platform)
        if key in seen:
            raise ValueError(f'Duplicate destination: {version}/{platform}')
        seen.add(key)
        validated.append((target, version, platform, original, extension_version))
    output.mkdir(parents=True)
    for target, version, platform, original, extension_version in validated:
        data = original
        if target == 'native':
            buffer = io.BytesIO()
            with gzip.GzipFile(filename='', mode='wb', fileobj=buffer, mtime=0, compresslevel=9) as stream:
                stream.write(original)
            data = buffer.getvalue()
        suffix = '.gz' if target == 'native' else '.wasm'
        path = f'{version}/{platform}/gtfs.duckdb_extension{suffix}'
        destination = output / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        entries.append(dict(target=target, version=version, platform=platform, extension_version=extension_version, abi='CPP', path=path, size=len(data), sha256=hashlib.sha256(data).hexdigest(), source_sha256=hashlib.sha256(original).hexdigest(), status=STATUS))
    (output / 'manifest.json').write_text(json.dumps(dict(status=STATUS, artifacts=entries), indent=2, sort_keys=True) + '\n')


def main():
    parser = argparse.ArgumentParser(description='Stage unsigned local-development DuckDB artifacts; never signs or uploads.')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--artifact', nargs=4, action='append', required=True, metavar=('TARGET', 'VERSION', 'PLATFORM', 'FILE'))
    args = parser.parse_args()
    try:
        stage(args.output, args.artifact)
    except (OSError, ValueError) as error:
        parser.exit(1, f'{error}\n')
    print(args.output / 'manifest.json')


if __name__ == '__main__':
    main()
