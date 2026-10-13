#!/usr/bin/env python3
"""Check real Codex plugin discovery without a login, model turn, or cleanup."""
import json
import os
from pathlib import Path
import select
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent


def discovered_skills(env, cwd):
    with tempfile.TemporaryFile() as errors:
        server = subprocess.Popen(
            ['codex', 'app-server', '--stdio'], env=env, cwd=cwd,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors,
            bufsize=0,
        )
        buffered = b''

        def send(message):
            server.stdin.write((json.dumps(message) + '\n').encode())

        def request(identifier, method, params):
            nonlocal buffered
            send({'id': identifier, 'method': method, 'params': params})
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                while b'\n' in buffered:
                    line, buffered = buffered.split(b'\n', 1)
                    result = json.loads(line)
                    if result.get('id') == identifier:
                        assert 'error' not in result, result
                        return result['result']
                if select.select([server.stdout], [], [],
                                 max(0, deadline - time.monotonic()))[0]:
                    chunk = os.read(server.stdout.fileno(), 65536)
                    assert chunk, 'Codex app-server closed before responding.'
                    buffered += chunk
            raise TimeoutError(f'Codex did not answer {method}')

        try:
            request(1, 'initialize', {'clientInfo': {
                'name': 'fresh-integration', 'version': '1.0',
            }})
            send({'method': 'initialized'})
            entries = request(2, 'skills/list', {
                'cwds': [str(cwd)], 'forceReload': True,
            })['data']
            assert len(entries) == 1 and not entries[0]['errors'], entries
            return [s for s in entries[0]['skills'] if s.get('pluginId') == 'fresh@fresh']
        finally:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
            server.stdin.close()
            server.stdout.close()


with tempfile.TemporaryDirectory(prefix='fresh-codex-test-') as directory:
    root = Path(directory)
    profile = root / 'codex'
    profile.mkdir()
    project = root / 'project'
    project.mkdir()
    env = dict(os.environ, CODEX_HOME=str(profile))

    def codex(*args):
        return subprocess.check_output(['codex', *args], cwd=project, env=env,
                                       text=True, timeout=120)

    # Local source tests the working tree. Override to check the documented Git route.
    source = os.environ.get('FRESH_MARKETPLACE_SOURCE', str(ROOT))
    assert not discovered_skills(env, project), 'Fresh must be absent before install.'
    market = json.loads(codex('plugin', 'marketplace', 'add', source, '--json'))
    assert market['marketplaceName'] == 'fresh'
    installed = json.loads(codex('plugin', 'add', 'fresh@fresh', '--json'))
    cached = Path(installed['installedPath'])
    skills = discovered_skills(env, project)
    assert {s['name'] for s in skills} == {'fresh:fresh', 'fresh:fresh-configure'}
    assert all(s['enabled'] and Path(s['path']).is_relative_to(cached) for s in skills)
    for skill in skills:
        folder = skill['name'].split(':')[-1]
        assert Path(skill['path']).read_bytes() == (ROOT / 'skills' / folder / 'SKILL.md').read_bytes()
    for resource in ('scripts/ensure-festival.sh', 'scripts/fresh-output.py', 'references/output.md'):
        relative = Path('skills/fresh') / resource
        assert (cached / relative).read_bytes() == (ROOT / relative).read_bytes()
    codex('plugin', 'remove', 'fresh@fresh')
    assert not discovered_skills(env, project), 'Removed skills must disappear.'
    print(f"{codex('--version').strip()}: install, both skills, bundled resources, and removal passed.")
