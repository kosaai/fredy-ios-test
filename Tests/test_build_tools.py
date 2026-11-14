"""Offline timing/policy tests. Synthetic job metadata is not a real CI run."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load_tool(name):
    path = ROOT / 'tools' / (name + '.py')
    if not path.exists():
        raise AssertionError('Build tool is not implemented: ' + name)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class WorkflowPolicyTests(unittest.TestCase):
    def test_manual_macos26_unsigned_device_build_and_verified_upload(self):
        path = ROOT / '.github/workflows/unsigned-ipa.yml'
        self.assertTrue(path.exists(), 'Unsigned macOS workflow is missing')
        import json
        workflow = json.loads(path.read_text())
        self.assertEqual(set(workflow['on']), {'workflow_dispatch'})
        self.assertEqual(workflow['permissions'], {'contents': 'read'})
        self.assertEqual(len(workflow['jobs']), 1)
        job = workflow['jobs']['build-unsigned']
        self.assertEqual(job['runs-on'], 'macos-26')
        commands = '\n'.join(s.get('run', '') for s in job['steps'])
        for required in ['xcodebuild', '-sdk iphoneos', '-arch arm64', 'generic/platform=iOS',
                         'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'ditto',
                         'Payload/FredyTest.app', 'verify_unsigned_ipa.py', 'FredyTest-Unsigned.ipa']:
            self.assertIn(required, commands)
        self.assertNotIn('-exportArchive', commands)
        upload = [s for s in job['steps'] if s.get('with', {}).get('name', '').startswith('FredyTest-Unsigned-')]
        self.assertEqual(len(upload), 1)
        self.assertIn('FredyTest-Unsigned.ipa', upload[0]['with']['path'])
        self.assertEqual(upload[0]['with']['if-no-files-found'], 'error')


class FakeClock:
    def __init__(self):
        self.now = 0.0
        self.cancels = []

    def time(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds

    def cancel(self):
        self.cancels.append(self.now)


def job(started=False, label='macos-26'):
    return {'id': 1, 'name': 'Build unsigned iPhone IPA', 'labels': [label],
            'status': 'in_progress' if started else 'queued',
            'runner_id': 1 if started else 0,
            'started_at': '2000-01-01T00:00:00Z',
            'steps': [{'status': 'in_progress', 'started_at': '2000-01-01T00:00:00Z'}] if started else []}


class QueuePolicyTests(unittest.TestCase):
    def wait(self, fetch):
        self.clock = FakeClock()
        tool = load_tool('actions_queue')
        return tool.wait_for_runner(lambda remaining: fetch(self.clock), self.clock.cancel,
                                    start=0, timeout=300, clock=self.clock.time, sleep=self.clock.sleep)

    def test_cancels_at_300_not_workflow_timeout(self):
        result = self.wait(lambda _: [job()])
        self.assertEqual(result['state'], 'macOS runner unavailable')
        self.assertEqual(self.clock.cancels, [300])

    def test_accepts_execution_before_deadline(self):
        result = self.wait(lambda c: [job(started=c.now >= 298)])
        self.assertEqual(result['state'], 'runner_started')
        self.assertEqual(self.clock.cancels, [])

    def test_does_not_accept_late_start_or_queued_timestamp(self):
        result = self.wait(lambda c: [job(started=c.now >= 302)])
        self.assertEqual(result['state'], 'macOS runner unavailable')
        self.assertEqual(self.clock.cancels, [300])

    def test_api_failure_does_not_abandon_queued_run(self):
        def fail(_):
            raise RuntimeError('synthetic API outage')
        result = self.wait(fail)
        self.assertEqual(result['state'], 'macOS runner unavailable')
        self.assertEqual(self.clock.cancels, [300])

    def test_wrong_runner_is_cancelled_without_fallback(self):
        result = self.wait(lambda _: [job(started=True, label='macos-latest')])
        self.assertEqual(result['state'], 'runner_label_mismatch')
        self.assertEqual(self.clock.cancels, [0])

    def test_assignment_without_started_step_is_not_execution(self):
        def assigned(_):
            value = job(started=True)
            value['steps'] = []
            return [value]
        result = self.wait(assigned)
        self.assertEqual(result['state'], 'macOS runner unavailable')
        self.assertEqual(self.clock.cancels, [300])


import os
import plistlib
import struct
import tempfile
import zipfile


class UnsignedIPATests(unittest.TestCase):
    def fixture(self, *, cpu=0x0100000C, platform=2, signed=False):
        directory = tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR', str(Path.home() / '.hermes/cache/scratch')))
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / 'test-only.ipa'
        commands = struct.pack('<6I', 0x32, 24, platform, 0x110000, 0x1A0000, 0)
        if signed:
            commands += struct.pack('<4I', 0x1D, 16, 0, 0)
        binary = struct.pack('<8I', 0xFEEDFACF, cpu, 0, 2, 2 if signed else 1, len(commands), 0, 0) + commands
        info = {'CFBundleExecutable': 'FredyTest', 'CFBundlePackageType': 'APPL',
                'CFBundleIdentifier': 'online.salatiq.FredyTest', 'CFBundleSupportedPlatforms': ['iPhoneOS'],
                'UIDeviceFamily': [1]}
        with zipfile.ZipFile(path, 'w') as archive:
            archive.writestr('Payload/FredyTest.app/Info.plist', plistlib.dumps(info))
            archive.writestr('Payload/FredyTest.app/FredyTest', binary)
        return path

    def test_accepts_unsigned_device_arm64_structure_not_runtime(self):
        tool = load_tool('verify_unsigned_ipa')
        result = tool.verify(self.fixture())
        self.assertEqual(result['architecture'], 'arm64')
        self.assertEqual(result['platform'], 'iPhoneOS')

    def test_rejects_simulator_platform(self):
        tool = load_tool('verify_unsigned_ipa')
        with self.assertRaises(ValueError): tool.verify(self.fixture(platform=7))

    def test_rejects_non_arm64(self):
        tool = load_tool('verify_unsigned_ipa')
        with self.assertRaises(ValueError): tool.verify(self.fixture(cpu=0x01000007))

    def test_rejects_code_signature(self):
        tool = load_tool('verify_unsigned_ipa')
        with self.assertRaises(ValueError): tool.verify(self.fixture(signed=True))


if __name__ == '__main__':
    unittest.main(verbosity=2)
