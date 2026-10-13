#!/usr/bin/env bash
# Container-only integration check. Requires git, bash, python3, camp and fest.
# Mount this repository read-only at /fresh and current Camp/Fest binaries in PATH.
# Invoke once in a new disposable container; reports are left in /fixture/reports.
set -euo pipefail
if [ ! -f /.dockerenv ] || [ -e /fixture ]; then
  echo "Run only in a fresh disposable Docker container." >&2
  exit 2
fi
CAMP_BIN="$(command -v camp)"
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

mkdir -p /fixture/reports
camp init /fixture/camp --name fresh-visual-test --description "Disposable visual test" --mission "Verify output and configuration" --no-skills --no-git >/dev/null
# All Git and Camp mutations below are confined to this disposable container.
git init -q --bare --initial-branch=main /fixture/origin.git
git clone -q /fixture/origin.git /fixture/my-project
cd /fixture/my-project
printf 'initial\n' > tracked.txt
git add tracked.txt
git commit -qm initial
git push -qu origin main
git switch -qc feat/landed
printf 'landed\n' >> tracked.txt
git commit -qam landed
git switch -q main
git merge -q --no-ff feat/landed -m merged
git push -q origin main
camp project link /fixture/my-project --campaign fresh-visual-test --yes --no-commit >/dev/null
camp project list --format json > /fixture/reports/projects.json
camp fresh configure add global --run 'printf global >> /fixture/order'
camp fresh configure add install --run 'printf install >> /fixture/order' --project my-project
camp fresh configure add build --run 'printf wrong >> /fixture/order' --project my-project
camp fresh configure edit build --run 'printf build >> /fixture/order' --project my-project
camp fresh configure move build --up --project my-project
camp fresh configure move build --down --project my-project
camp fresh configure add remove-me --run 'false' --project my-project
camp fresh configure remove remove-me --project my-project
camp fresh show-workflow my-project --json > /fixture/reports/workflow.json
python3 /fresh/skills/fresh/scripts/fresh-output.py --camp "$CAMP_BIN" --output-dir /fixture/reports -- --dry-run -b feat/next > /fixture/reports/preview.json
test ! -e /fixture/order
git show-ref --verify --quiet refs/heads/feat/landed
python3 /fresh/skills/fresh/scripts/fresh-output.py --camp "$CAMP_BIN" --output-dir /fixture/reports -- -b feat/next > /fixture/reports/run.json
test "$(cat /fixture/order)" = installbuild
if git show-ref --verify --quiet refs/heads/feat/landed; then exit 1; fi
test "$(git branch --show-current)" = feat/next
python3 /fresh/skills/fresh/scripts/fresh-output.py --camp "$CAMP_BIN" --output-dir /fixture/reports -- --no-follow-up > /fixture/reports/skipped.json
test "$(cat /fixture/order)" = installbuild
camp fresh configure edit build --run 'exit 9' --project my-project
camp fresh configure add later --run 'touch /fixture/later' --project my-project
set +e
python3 /fresh/skills/fresh/scripts/fresh-output.py --camp "$CAMP_BIN" --output-dir /fixture/reports -- > /fixture/reports/failed.json
failure=$?
set -e
test "$failure" -ne 0
test ! -e /fixture/later
camp fresh configure edit build --run 'exit 9' --continue-on-error --project my-project
python3 /fresh/skills/fresh/scripts/fresh-output.py --camp "$CAMP_BIN" --output-dir /fixture/reports -- > /fixture/reports/continued.json
test -e /fixture/later
camp fresh configure remove install --project my-project
camp fresh configure remove build --project my-project
camp fresh configure remove later --project my-project
camp fresh show-workflow my-project --json > /fixture/reports/restored-global.json
camp fresh configure set branch --action branch --value feat/configured --project my-project
camp fresh configure set push_upstream --action off --project my-project
camp fresh show-workflow my-project --json > /fixture/reports/settings.json
camp fresh configure set branch --action no-branch --project my-project
camp fresh configure set branch --action inherit --project my-project
camp fresh configure set push_upstream --action inherit --project my-project
camp fresh show-workflow my-project --json > /fixture/reports/inherited-settings.json
python3 - <<'PY'
import json
from pathlib import Path
p = Path('/fixture/reports')
preview, run, failed, continued = [json.loads((p/(name+'.json')).read_text()) for name in ('preview','run','failed','continued')]
assert preview['preview'] and preview['exitCode'] == 0
assert 'would run' in preview['output']
assert run['exitCode'] == 0 and not run['preview']
assert 'feat/landed' in run['output']
assert failed['exitCode'] != 0 and 'failed' in failed['output']
assert continued['exitCode'] == 0 and 'failed (continuing)' in continued['output']
workflow = (p/'workflow.json').read_text()
assert 'printf install' in workflow and 'printf build' in workflow and 'printf global' not in workflow
restored = (p/'restored-global.json').read_text()
assert 'printf global' in restored and 'printf install' not in restored
settings = json.loads((p/'settings.json').read_text())
by_key = {s.get('setting'): s for s in settings['steps']}
assert by_key['branch']['stored'] == 'branch'
assert 'feat/configured' in by_key['branch']['detail']
assert by_key['push_upstream']['stored'] == 'off'
settings = json.loads((p/'inherited-settings.json').read_text())
assert all(s['stored'] == 'inherit' for s in settings['steps'] if s.get('setting') in ('branch','push_upstream'))
print('Real Camp: configuration readback, preview, cleanup, order, skip, failure, continue, inheritance all passed.')
PY
