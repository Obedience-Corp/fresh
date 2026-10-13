#!/usr/bin/env bash
# Record real Camp in Docker, using local VHS for capture. Never runs host Camp.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${CAMP_BIN_DIR:?Set CAMP_BIN_DIR to a directory containing Linux camp and fest binaries}"
for tool in docker vhs python3 ffmpeg; do command -v "$tool" >/dev/null; done
for binary in camp fest; do test -x "$CAMP_BIN_DIR/$binary"; done
CAMP_BIN_DIR="$(cd "$CAMP_BIN_DIR" && pwd -P)"
recording_dir="$(mktemp -d)"
FRESH_DEMO_CONTAINER="fresh-vhs-$$"
export FRESH_DEMO_CONTAINER
cleanup() {
  docker rm -f "$FRESH_DEMO_CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$recording_dir"
}
trap cleanup EXIT
mkdir -p "$recording_dir/bin"
cat > "$recording_dir/bin/demo-shell" <<'SH'
#!/usr/bin/env bash
exec docker exec -it -w /demo/site -e TERM=xterm-256color -e COLORTERM=truecolor \
  -e 'PS1=site $ ' -e PATH=/binaries:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  "$FRESH_DEMO_CONTAINER" bash --noprofile --norc
SH
chmod +x "$recording_dir/bin/demo-shell"
export PATH="$recording_dir/bin:$PATH"
docker run -d --name "$FRESH_DEMO_CONTAINER" --platform "${CAMP_DEMO_PLATFORM:-linux/amd64}" \
  --mount "type=bind,src=$CAMP_BIN_DIR,dst=/binaries,readonly" \
  --mount "type=bind,src=$PWD,dst=/fresh,readonly" alpine:3.21 sleep 1800 >/dev/null
docker exec "$FRESH_DEMO_CONTAINER" sh -c 'apk add --no-cache bash git nodejs npm >/dev/null && PATH=/binaries:$PATH bash /fresh/docs/demos/setup-fixture.sh'
vhs docs/demos/configure.tape
docker exec -w /demo/site "$FRESH_DEMO_CONTAINER" /binaries/camp fresh show-workflow site --json > "$recording_dir/workflow.json"
python3 - "$recording_dir/workflow.json" <<'PY'
import json,sys
workflow=json.load(open(sys.argv[1]))
steps=[s['follow'] for s in workflow['steps'] if s['kind']=='follow_up']
assert [(s['name'],s['run']) for s in steps]==[('install','npm ci'),('build','npm run build')],steps
assert workflow['project']=='site' and not workflow['inherits_follow_ups']
print('Verified: the TUI saved install and build in project scope.')
PY
vhs docs/demos/cleanup.tape
docker exec -w /demo/site "$FRESH_DEMO_CONTAINER" sh -c '
  test -s dist/index.html &&
  test "$(git branch --show-current)" = main &&
  test "$(git rev-parse main)" = "$(git rev-parse origin/main)" &&
  test -z "$(git status --porcelain)" &&
  if git show-ref --verify --quiet refs/heads/feat/homepage; then exit 1; fi
'
for pair in configure:configured cleanup:cleaned; do
  ffmpeg -y -loglevel error -sseof -0.3 -i "docs/demos/${pair%%:*}.mp4" -frames:v 1 "docs/demos/${pair##*:}.png"
done
echo 'Verified: cleanup removed the merged branch, synced main, and built the site.'
