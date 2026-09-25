#!/usr/bin/env python3
"""Exercise runner process ownership without requesting audio capture (Python 3)."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest

RUNNER = Path(__file__).resolve().parents[1] / "run-process-tap-audio-only-probe.sh"
PROBE = '''#!/usr/bin/env python3
import json, os, signal, subprocess, sys, time
from pathlib import Path
os.setpgid(0, 0)
args = dict(zip(sys.argv[1::2], sys.argv[2::2]))
output = Path(args['--output'])
child = subprocess.Popen(['/usr/bin/afplay', args['--tone']], executable=os.environ['FIXTURE_PLAYER'])
(output.parent / 'child.pid').write_text(str(child.pid))
mode = os.environ['FIXTURE_MODE']
if mode == 'crash':
    os._exit(1)
if mode == 'wait':
    child.wait()
    sys.exit(1)
child.terminate()
child.wait()
cycle = dict(teardownVerified=True, capturedFrames=100, rms=0.1, targetAmplitude=0.1)
output.write_text(json.dumps(dict(schemaVersion=2, microphoneRequested=False,
    screenPixelsRequested=False, status='PASS', permissionOutcome='process_tap_created',
    requestedCycles=1, completedCycles=1, capturedFrames=100,
    minimumCycleRMS=0.1, minimumCycleTargetAmplitude=0.1, cycles=[cycle])))
'''


class RunnerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.player_temp = tempfile.TemporaryDirectory(prefix='process-tap-player-test-')
        cls.player = Path(cls.player_temp.name) / 'afplay'
        # A silent stand-in with the same process name and argv as afplay. This
        # reproduces filename-based cleanup without touching audio hardware.
        subprocess.run(['cc', '-x', 'c', '-', '-o', str(cls.player)],
                       input='#include <unistd.h>\nint main(void) { sleep(60); return 0; }\n',
                       text=True, check=True)

    @classmethod
    def tearDownClass(cls):
        cls.player_temp.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='process-tap-runner-test-')
        self.root = Path(self.temp.name)
        self.output = self.root / 'evidence'
        bindir = self.root / 'bin'
        bindir.mkdir()
        fixture = self.root / 'probe'
        fixture.write_text(PROBE)
        fixture.chmod(0o755)
        # Substitute only build/sign steps; execute the actual shell runner and
        # real process discovery, signals, waits, and result validation.
        for name, body in {
            'swiftc': '#!/bin/bash\nwhile [[ "$1" != -o ]]; do shift; done\ncp "$FIXTURE_PROBE" "$2"\n',
            'codesign': '#!/bin/bash\nexit 0\n',
            'swift': '#!/bin/bash\necho fixture\n',
        }.items():
            path = bindir / name
            path.write_text(body)
            path.chmod(0o755)
        self.env = dict(os.environ, PATH=str(bindir) + ':' + os.environ['PATH'],
                        FIXTURE_PROBE=str(fixture), FIXTURE_PLAYER=str(self.player), FIXTURE_MODE='pass')
        self.unrelated = subprocess.Popen(
            ['/usr/bin/afplay', str(self.output / 'generated-997hz.wav')], executable=str(self.player))
        self.runner = None

    def tearDown(self):
        if self.runner and self.runner.poll() is None:
            self.runner.terminate()
            self.runner.wait(timeout=15)
        self.unrelated.terminate()
        self.unrelated.wait()
        self.temp.cleanup()

    def launch(self, mode='pass', deadline='20'):
        self.env.update(FIXTURE_MODE=mode, MACPARAKEET_PROCESS_TAP_PROBE_DEADLINE_SECONDS=deadline)
        self.runner = subprocess.Popen(['bash', str(RUNNER), str(self.output)], env=self.env,
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def await_child(self):
        path = self.output / 'child.pid'
        for _ in range(100):
            if path.exists() and path.read_text():
                return int(path.read_text())
            time.sleep(0.05)
        self.fail('fixture never launched child')

    def assert_cleanup(self, child):
        self.assertIsNone(self.unrelated.poll(), 'cleanup killed unrelated process')
        for _ in range(100):
            state = subprocess.run(['/bin/ps', '-p', str(child), '-o', 'stat='],
                                   capture_output=True, text=True).stdout.strip()
            if not state or state.startswith('Z'):
                return
            time.sleep(0.05)
        self.fail('probe child survived cleanup')

    def test_success(self):
        self.launch()
        child = self.await_child()
        self.assertEqual(self.runner.wait(timeout=15), 0)
        self.assertEqual(json.loads((self.output / 'result.json').read_text())['status'], 'PASS')
        self.assert_cleanup(child)

    def test_timeout(self):
        self.launch('wait', '1')
        child = self.await_child()
        self.assertEqual(self.runner.wait(timeout=15), 124)
        self.assertEqual(json.loads((self.output / 'result.json').read_text())['status'], 'FAIL')
        self.assert_cleanup(child)

    def test_signal(self):
        self.launch('wait')
        child = self.await_child()
        self.runner.send_signal(signal.SIGTERM)
        self.assertEqual(self.runner.wait(timeout=15), 143)
        self.assertEqual(json.loads((self.output / 'result.json').read_text())['status'], 'FAIL')
        self.assert_cleanup(child)

    def test_crashed_probe_orphan(self):
        self.launch('crash')
        child = self.await_child()
        self.assertNotEqual(self.runner.wait(timeout=15), 0)
        self.assert_cleanup(child)


if __name__ == '__main__':
    unittest.main()
