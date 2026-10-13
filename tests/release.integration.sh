#!/usr/bin/env bash
set -euo pipefail
# Download the real release and exercise first use only in a disposable container.
if [ ! -f /.dockerenv ] || [ -e /first-use ] || [ -e /fixture ]; then
  echo "Run only in a fresh disposable Docker container." >&2
  exit 2
fi
for binary in camp fest festival; do
  if command -v "$binary"; then
    echo "Expected a container without Festival binaries." >&2
    exit 2
  fi
done
camp_bin=$(bash /fresh/skills/fresh/scripts/ensure-festival.sh)
"$camp_bin" version
"$(dirname "$camp_bin")/fest" version
PATH="$(dirname "$camp_bin"):$PATH"
export PATH
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
mkdir -p /first-use/reports
git init -q --bare --initial-branch=main /first-use/origin.git
git clone -q /first-use/origin.git /first-use/site
cd /first-use/site
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
python3 /fresh/skills/fresh/scripts/fresh-output.py --camp "$camp_bin" --output-dir /first-use/reports -- --dry-run > /first-use/preview.json
test ! -e .camp
test ! -d /root/campaigns/festival
git show-ref --verify --quiet refs/heads/feat/landed
python3 /fresh/skills/fresh/scripts/fresh-output.py --camp "$camp_bin" --output-dir /first-use/reports -- > /first-use/run.json
test -e .camp
test -d /root/campaigns/festival
test "$(git branch --show-current)" = main
test "$(git rev-parse main)" = "$(git rev-parse origin/main)"
test -z "$(git status --porcelain)"
if git show-ref --verify --quiet refs/heads/feat/landed; then
  echo "Merged branch was not removed." >&2
  exit 1
fi
python3 - <<'PY'
import json
from pathlib import Path
preview=json.loads(Path('/first-use/preview.json').read_text())
run=json.loads(Path('/first-use/run.json').read_text())
assert preview['exitCode']==0 and preview['preview']
assert run['exitCode']==0 and not run['preview']
assert 'camp project unlink' in run['output']
print(run['output'])
PY
bash /fresh/skills/fresh/scripts/ensure-festival.sh
bash /fresh/tests/camp.integration.sh
printf '\nPASS: release install, preview without linking, automatic link, cleanup, repeat installer, follow-up integration\n'
