#!/usr/bin/env bash
# Record a real Codex skill run in a disposable container, never on host projects.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${CAMP_BIN_DIR:?Set CAMP_BIN_DIR to a directory containing Linux camp and fest binaries}"
: "${CODEX_AUTH_FILE:?Set CODEX_AUTH_FILE to an existing Codex auth.json file}"
for tool in docker vhs python3 ffmpeg; do command -v "$tool" >/dev/null; done
for binary in camp fest; do test -x "$CAMP_BIN_DIR/$binary"; done
test -f "$CODEX_AUTH_FILE"
CAMP_BIN_DIR="$(cd "$CAMP_BIN_DIR" && pwd -P)"
CODEX_AUTH_FILE="$(cd "$(dirname "$CODEX_AUTH_FILE")" && pwd -P)/$(basename "$CODEX_AUTH_FILE")"
recording_dir="$(mktemp -d)"
FRESH_DEMO_CONTAINER="fresh-skill-vhs-$$"
export FRESH_DEMO_CONTAINER
cleanup() {
  docker rm -f "$FRESH_DEMO_CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$recording_dir"
}
trap cleanup EXIT
cat > "$recording_dir/agent-demo" <<'LAUNCH'
#!/usr/bin/env bash
exec docker exec -it -w /demo/site -e TERM=xterm-256color -e COLORTERM=truecolor \
  "$FRESH_DEMO_CONTAINER" codex -a never -s danger-full-access
LAUNCH
chmod +x "$recording_dir/agent-demo"
export PATH="$recording_dir:$PATH"
# Codex runs natively; choose the architecture of the Docker daemon.
docker run -d --name "$FRESH_DEMO_CONTAINER" \
  --platform "${CAMP_DEMO_PLATFORM:-linux/arm64}" \
  --mount "type=bind,src=$CAMP_BIN_DIR,dst=/binaries,readonly" \
  --mount "type=bind,src=$PWD,dst=/fresh,readonly" \
  --mount "type=bind,src=$CODEX_AUTH_FILE,dst=/root/.codex/auth.json,readonly" \
  node:24-bookworm sleep 1800 >/dev/null
docker exec "$FRESH_DEMO_CONTAINER" bash -c '
  set -euo pipefail
  apt-get update -qq
  apt-get install -y -qq python3 ripgrep bubblewrap >/dev/null
  npm install -g @openai/codex@0.162.1 >/dev/null
  ln -s /binaries/camp /usr/local/bin/camp
  ln -s /binaries/fest /usr/local/bin/fest
  bash /fresh/docs/demos/setup-fixture.sh
  mkdir -p /root/.agents/skills
  cp -R /fresh/skills/fresh /fresh/skills/fresh-configure /root/.agents/skills/
  printf "cli_auth_credentials_store = \"file\"\n[projects.\"/demo/site\"]\ntrust_level = \"trusted\"\n[notice]\nhide_full_access_warning = true\n" > /root/.codex/config.toml
  cd /demo/site
  camp fresh configure add install --run "npm ci" --project site
  camp fresh configure add build --run "npm run build" --project site
  codex login status
'
vhs docs/demos/skill.tape
docker exec -w /demo/site "$FRESH_DEMO_CONTAINER" python3 /fresh/docs/demos/verify-skill.py > "$recording_dir/skill-run.json"
cp "$recording_dir/skill-run.json" docs/demos/skill-run.json
# Match the still to the useful GIF preview, before the transcript scroll.
ffmpeg -y -loglevel error -i docs/demos/skill.gif -frames:v 1 docs/demos/skill.png
echo 'Verified: Codex invoked Fresh, previewed, cleaned up, and completed the build.'
