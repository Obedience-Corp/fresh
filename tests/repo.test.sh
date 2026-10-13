#!/usr/bin/env bash
# Structure checks for the fresh plugin repository: manifests agree, the hook
# does one thing, the discovery symlinks resolve, and the skill stays small.
#
# Usage: bash tests/repo.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT" || exit 2

PASS=0
FAIL=0

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
        if [ -n "${VERBOSE:-}" ]; then echo "  ok    $desc"; fi
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL  $desc"
    fi
}

MANIFESTS=".claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json plugin.json"

echo "manifests and hook"
if ! command -v python3 >/dev/null 2>&1; then
    echo "  FAIL  python3 is required for the JSON checks"
    FAIL=$((FAIL + 1))
else
    for f in $MANIFESTS hooks/hooks.json; do
        check "$f is valid JSON" python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f"
    done
    check "every manifest names fresh at the skill's version" python3 - <<'EOF'
import json, re, sys
want_name = "fresh"
skill = open("skills/fresh/SKILL.md", encoding="utf-8").read()
m = re.search(r'^  version:\s*"?([^"\n]+)"?\s*$', skill, re.M)
assert m, "SKILL.md has no version"
want_version = m.group(1)
for path in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json", "plugin.json"):
    d = json.load(open(path))
    assert d["name"] == want_name, path
    assert d["version"] == want_version, path
    assert d["license"] == "Apache-2.0", path
    assert d["repository"] == "https://github.com/Obedience-Corp/fresh", path
market = json.load(open(".claude-plugin/marketplace.json"))
assert market["name"] == want_name
assert len(market["plugins"]) == 1
entry = market["plugins"][0]
assert entry["name"] == want_name and entry["version"] == want_version
assert entry["source"] == "./"
EOF
    check "hooks.json has only one SessionStart command, the ensure script in hook mode" python3 - <<'EOF'
import json
hooks = json.load(open("hooks/hooks.json"))["hooks"]
assert list(hooks) == ["SessionStart"], list(hooks)
groups = hooks["SessionStart"]
assert len(groups) == 1 and len(groups[0]["hooks"]) == 1
hook = groups[0]["hooks"][0]
assert hook["type"] == "command"
assert hook["command"] == 'bash "${CLAUDE_PLUGIN_ROOT}/skills/fresh/scripts/ensure-festival.sh" --hook'
assert 0 < hook["timeout"] <= 120
EOF
    check "Codex starter prompts fit its limits (3 entries, 128 characters)" python3 - <<'EOF'
import json
prompts = json.load(open(".codex-plugin/plugin.json"))["interface"]["defaultPrompt"]
assert isinstance(prompts, list) and 1 <= len(prompts) <= 3
assert all(isinstance(p, str) and 0 < len(p) <= 128 for p in prompts)
EOF
fi

echo "discovery symlinks"
for link in .claude/skills/fresh .agents/skills/fresh .opencode/skills/fresh; do
    check "$link is a symlink" test -L "$link"
    check "$link resolves to skills/fresh" test "$(cd "$link" 2>/dev/null && pwd -P)" = "$ROOT/skills/fresh"
    check "$link exposes SKILL.md" test -f "$link/SKILL.md"
done
check "no broken symlinks" test -z "$(find . -path ./.git -prune -o -type l ! -exec test -e {} \; -print)"

echo "skill"
SKILL="skills/fresh/SKILL.md"
body_lines="$(awk 'f >= 2 {n++} /^---$/ {f++} END {print n + 0}' "$SKILL")"
check "SKILL.md body is one screen (40 lines or fewer, has $body_lines)" test "$body_lines" -le 40
check "has the outcome" grep -q "Your PR merged. Start clean." "$SKILL"
check "has the definition of done" grep -q "^Done means:" "$SKILL"
for step in "1. \*\*Get \`camp\`" "2. \*\*Preview" "3. \*\*Run" "4. \*\*Report"; do
    check "has step: $step" grep -q "^$step" "$SKILL"
done
check "has the laws" grep -q "^## Laws" "$SKILL"
check "previews first" grep -q "Preview first. Every time." "$SKILL"
check "ensure script is executable" test -x skills/fresh/scripts/ensure-festival.sh
check "there is one copy of the ensure script" test "$(find . -path ./.git -prune -o -type f -name ensure-festival.sh -print | wc -l | tr -d ' ')" = "1"
if command -v shellcheck >/dev/null 2>&1; then
    check "ensure script passes shellcheck" shellcheck skills/fresh/scripts/ensure-festival.sh
    check "tests pass shellcheck" shellcheck -x tests/run.sh tests/repo.test.sh tests/ensure-festival.test.sh
else
    echo "  skip  shellcheck is not installed"
fi

echo "copy"
check "no em dash anywhere" test -z "$(grep -rn "$(printf '\342\200\224')" . --exclude-dir=.git)"
check "README states the install lines" grep -q "/plugin install fresh@fresh" README.md
check "README states the skills install line" grep -q "npx skills add https://github.com/Obedience-Corp/fresh --skill fresh" README.md
check "README states the status plainly" grep -q "works only in" README.md
check "README names the undo" grep -q "camp project unlink" README.md
check "LICENSE is Apache-2.0" grep -q "Apache License" LICENSE
check "NOTICE credits Festival" grep -q "Obedience-Corp/festival" NOTICE

echo
echo "repository tests: passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ]
