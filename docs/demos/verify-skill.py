#!/usr/bin/env python3
"""Verify only the disposable agent recording and export non-sensitive evidence."""
import json
from pathlib import Path
import subprocess

assert Path('/.dockerenv').exists(), 'Run inside the recording container.'
assert Path.cwd() == Path('/demo/site'), 'Run from the disposable demo project.'

def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()

assert git('branch', '--show-current') == 'main'
assert git('rev-parse', 'main') == git('rev-parse', 'origin/main')
assert not git('status', '--porcelain')
assert subprocess.run(['git', 'show-ref', '--verify', '--quiet',
                       'refs/heads/feat/homepage']).returncode == 1
assert Path('dist/index.html').read_bytes() == Path('index.html').read_bytes()
reports = sorted((json.loads(p.read_text()) for p in Path('/tmp').glob('fresh-output-*/report.json')),
                 key=lambda r: r['startedAt'])
assert len(reports) == 2, 'Expected exactly one preview and one cleanup capture.'
assert [r['preview'] for r in reports] == [True, False]
assert all(r['exitCode'] == 0 for r in reports)
assert 'would delete 1 branch' in reports[0]['output']
assert 'deleted 1 branch' in reports[1]['output']
assert 'Built dist/index.html' in reports[1]['output']
rows = []
for path in Path('/root/.codex/sessions').rglob('*.jsonl'):
    rows.extend(json.loads(line) for line in path.read_text().splitlines())
items = [r['payload'] for r in rows if r.get('type') == 'response_item']
calls = [p.get('input', '') for p in items if p.get('type') == 'custom_tool_call']
assert any('SKILL.md' in s for s in calls), 'Agent must read the installed skill.'
assert any('ensure-festival.sh' in s for s in calls), 'Agent must run the installer check.'
captures = [s for s in calls if 'fresh-output.py' in s and 'python3' in s]
assert len(captures) == 2
assert '--dry-run' in captures[0] and '--dry-run' not in captures[1]
assert any(r.get('payload', {}).get('type') == 'task_complete' for r in rows)
# Export only fixture output and the requested prompt. Never export raw session,
# authentication, usage, account, or machine configuration data.
print(json.dumps({
    'prompt': 'Use $fresh. My PR merged.',
    'codexVersion': subprocess.check_output(['codex', '--version'], text=True).strip(),
    'checks': ['installed skill read', 'installer invoked', 'preview before cleanup',
               'merged branch removed', 'main synced', 'clean Git status', 'build output verified'],
    'preview': reports[0]['output'],
    'completed': reports[1]['output'],
}, indent=2, ensure_ascii=True))
