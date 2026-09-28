import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/stage-repository.py'
PREFIX = b'\x00\x93\x04\x10duckdb_signature\x80\x04'


def fixture(platform, version):
    fields = ['', '', '', 'CPP', 'test', version, platform, '4']
    body = b'\x00asm\x01\x00\x00\x00' if platform.startswith('wasm_') else b'\xcf\xfa\xed\xfe'
    return body + PREFIX + b''.join(s.encode().ljust(32, b'\0') for s in fields) + bytes(256)


class StageRepositoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.inputs = []
        for target, version, platform in [('native', 'v1.5.4', 'osx_arm64'), ('wasm', 'v1.4.3', 'wasm_eh'), ('wasm', 'v1.4.3', 'wasm_mvp')]:
            path = self.base / platform
            path.write_bytes(fixture(platform, version))
            self.inputs.append([target, version, platform, str(path)])

    def run_stage(self, output='repository'):
        args = [sys.executable, str(SCRIPT), '--output', str(self.base / output)]
        for item in self.inputs:
            args += ['--artifact', *item]
        return subprocess.run(args, capture_output=True, text=True)

    def test_rejects_invalid_inputs_before_creating_output(self):
        cases = ['missing', 'truncated', 'version', 'platform', 'header', 'abi', 'signed', 'prefix', 'magic', 'padding', 'target', 'traversal', 'duplicate']
        for case in cases:
            with self.subTest(case=case):
                path = Path(self.inputs[-1][-1])
                original = fixture('wasm_mvp', 'v1.4.3')
                path.write_bytes(original)
                inputs = [item[:] for item in self.inputs]
                if case == 'missing':
                    path.unlink()
                elif case == 'truncated':
                    path.write_bytes(b'bad')
                elif case in ['version', 'platform', 'target']:
                    self.inputs[-1][{'target': 0, 'version': 1, 'platform': 2}[case]] = {'target': 'native', 'version': 'v1.5.4', 'platform': 'wasm_eh'}[case]
                elif case == 'traversal':
                    self.inputs[-1][1] = '../escape'
                elif case == 'duplicate':
                    self.inputs.append(self.inputs[-1][:])
                else:
                    data = bytearray(original)
                    index = {'header': -288, 'abi': -416, 'signed': -1, 'prefix': -513, 'magic': 0, 'padding': -289}[case]
                    data[index] = 65
                    path.write_bytes(data)
                result = self.run_stage(case)
                self.inputs = inputs
                self.assertNotEqual(result.returncode, 0, case)
                self.assertFalse((self.base / case).exists(), result.stderr)

    def test_existing_output_is_not_overwritten(self):
        result = self.run_stage()
        self.assertEqual(result.returncode, 0, result.stderr)
        output = self.base / 'repository'
        before = {str(p.relative_to(output)): p.read_bytes() for p in output.rglob('*') if p.is_file()}
        result = self.run_stage()
        self.assertNotEqual(result.returncode, 0)
        after = {str(p.relative_to(output)): p.read_bytes() for p in output.rglob('*') if p.is_file()}
        self.assertEqual(before, after)

    def test_stages_deterministic_repository_and_manifest(self):
        for output in ['one', 'two']:
            result = self.run_stage(output)
            self.assertEqual(result.returncode, 0, result.stderr)
        one, two = self.base / 'one', self.base / 'two'
        manifest = json.loads((one / 'manifest.json').read_text())
        self.assertEqual(manifest['status'], 'UNSIGNED DEVELOPMENT-ONLY')
        self.assertEqual(len(manifest['artifacts']), 3)
        self.assertEqual((one / 'manifest.json').read_bytes(), (two / 'manifest.json').read_bytes())
        for item, (target, version, platform, source) in zip(manifest['artifacts'], self.inputs):
            suffix = '.gz' if target == 'native' else '.wasm'
            self.assertEqual(item['path'], f'{version}/{platform}/gtfs_duck_tools.duckdb_extension{suffix}')
            data = (one / item['path']).read_bytes()
            self.assertEqual(data, (two / item['path']).read_bytes())
            self.assertEqual(item['sha256'], hashlib.sha256(data).hexdigest())
            self.assertEqual(item['size'], len(data))
            original = Path(source).read_bytes()
            self.assertEqual(item['source_sha256'], hashlib.sha256(original).hexdigest())
            self.assertEqual(item['extension_version'], 'test')
            self.assertEqual(item['abi'], 'CPP')
            self.assertEqual(item['target'], target)
            self.assertEqual(item['version'], version)
            self.assertEqual(item['platform'], platform)
            self.assertEqual(item['status'], 'UNSIGNED DEVELOPMENT-ONLY')
            self.assertEqual(gzip.decompress(data) if target == 'native' else data, original)
            if target == 'native':
                self.assertEqual(data[3:8], bytes(5))


if __name__ == '__main__':
    unittest.main()
