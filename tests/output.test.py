"""Exercise the process boundary: no real Camp, Git, home writes, or network."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'skills/fresh/scripts/fresh-output.py'


class CaptureTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='fresh-test-')
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)
        self.camp = self.root / 'camp with spaces'
        self.camp.write_text('''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
with Path('calls').open('a') as f: f.write(json.dumps(sys.argv[1:]) + '\\n')
if os.environ.get('WAIT'):
    print('running', flush=True)
    time.sleep(30)
print(os.environ.get('OUT', '✓ Synced main\\n  kept feat/wip'), flush=True)
print('warning on stderr', file=sys.stderr, flush=True)
sys.exit(int(os.environ.get('CODE', '0')))
''')
        self.camp.chmod(0o755)

    def command(self, *flags):
        return [sys.executable, str(SCRIPT), '--camp', str(self.camp),
                '--output-dir', str(self.root), '--', *flags]

    def run_capture(self, *flags, **env):
        result = subprocess.run(self.command(*flags), cwd=self.root,
                                env={**os.environ, **env}, capture_output=True, timeout=10)
        return result, json.loads(result.stdout)

    def test_preview_keeps_arguments_and_output_and_runs_once(self):
        result, report = self.run_capture('--dry-run', '-b', 'feat/next', '--campaign', 'my camp')
        self.assertEqual(result.returncode, 0)
        self.assertTrue(report['preview'])
        self.assertEqual((self.root / 'calls').read_text().splitlines(),
                         [json.dumps(['fresh', '--dry-run', '-b', 'feat/next', '--campaign', 'my camp'])])
        self.assertIn('kept feat/wip', report['output'])
        self.assertIn('warning on stderr', report['output'])
        self.assertEqual(Path(report['transcriptPath']).read_bytes(), result.stderr)
        self.assertEqual(json.loads(Path(report['htmlPath']).with_name('report.json').read_text()), report)
        self.assertEqual(Path(report['htmlPath']).parent.stat().st_mode & 0o777, 0o700)

    def test_failure_preserves_exit_and_never_reruns(self):
        result, report = self.run_capture(CODE='7', OUT='Error: build failed')
        self.assertEqual(result.returncode, 7)
        self.assertEqual(report['exitCode'], 7)
        self.assertIn('Run failed', Path(report['htmlPath']).read_text())
        self.assertEqual(len((self.root / 'calls').read_text().splitlines()), 1)

    def test_escape_html_strip_ansi_keep_raw(self):
        source = '\x1b[32m✓ <script>alert("bad")</script> & branch\x1b[0m'
        _, report = self.run_capture(OUT=source)
        rendered = Path(report['htmlPath']).read_text()
        self.assertNotIn('<script>', rendered)
        self.assertIn('&lt;script&gt;', rendered)
        self.assertNotIn('\x1b', report['output'])
        self.assertIn(source, Path(report['transcriptPath']).read_text())

    def test_large_transcript_is_complete_and_display_marks_shortening(self):
        source = 'start\n' + 'x' * 70000 + '\nend'
        _, report = self.run_capture(OUT=source)
        self.assertTrue(report['truncated'])
        self.assertIn('Display shortened', report['output'])
        self.assertTrue(report['output'].startswith('start'))
        self.assertIn('end', report['output'])
        self.assertIn(source, Path(report['transcriptPath']).read_text())

    def test_failed_allocation_does_not_launch_camp(self):
        cmd = self.command()
        cmd[cmd.index('--output-dir') + 1] = str(self.root / 'missing')
        result = subprocess.run(cmd, cwd=self.root, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.root / 'calls').exists())

    def test_missing_binary_is_failed_report(self):
        self.camp.unlink()
        result, report = self.run_capture()
        self.assertEqual(result.returncode, 127)
        self.assertEqual(report['exitCode'], 127)
        self.assertIn('capture error', report['output'])

    def test_explicit_false_overrides_preview_flag(self):
        _, report = self.run_capture('--dry-run', '--dry-run=false')
        self.assertFalse(report['preview'])

    def test_interrupt_reaches_child_and_report_is_not_success(self):
        child = subprocess.Popen(self.command(), cwd=self.root,
                                 env={**os.environ, 'WAIT': '1'},
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.addCleanup(lambda: child.kill() if child.poll() is None else None)
        deadline = time.monotonic() + 5
        while not (self.root / 'calls').exists() and time.monotonic() < deadline:
            time.sleep(.01)
        self.assertTrue((self.root / 'calls').exists())
        child.send_signal(signal.SIGTERM)
        stdout, _ = child.communicate(timeout=5)
        self.assertEqual(child.returncode, 143)
        self.assertEqual(json.loads(stdout)['exitCode'], 143)
        self.assertEqual(len((self.root / 'calls').read_text().splitlines()), 1)


if __name__ == '__main__':
    unittest.main()
