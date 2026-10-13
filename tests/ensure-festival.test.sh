#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub scripts are written with literal $ on purpose
# Tests for skills/fresh/scripts/ensure-festival.sh.
#
# Every scenario runs the script in a throwaway home directory with a PATH that
# holds only stub binaries and system tools. `curl`, `camp`, `fest`, and the
# `festival` manager are stubs, so nothing is downloaded, the real home
# directory is never touched, and no real camp can be replaced.
#
# Usage: bash tests/ensure-festival.test.sh
#        VERBOSE=1 bash tests/ensure-festival.test.sh    # list passing checks too
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ENSURE_SCRIPT:-$ROOT/skills/fresh/scripts/ensure-festival.sh}"
SYS_PATH="/usr/bin:/bin:/usr/sbin:/sbin"

# The "camp is missing" scenarios are only honest if the system PATH has none.
for tool in camp fest festival; do
    if PATH="$SYS_PATH" type -P "$tool" >/dev/null 2>&1; then
        echo "refusing to run: a real $tool is installed in $SYS_PATH" >&2
        exit 2
    fi
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/fresh-tests.XXXXXX")"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
N=0
SB=""
RC=0
OUT=""
ERR=""

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
        if [ -n "${VERBOSE:-}" ]; then echo "  ok    $desc"; fi
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL  $desc"
        echo "        rc=$RC"
        echo "        stdout: $OUT"
        echo "        stderr: $(printf '%s' "$ERR" | tr '\n' '|')"
    fi
}

sha() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        sha256sum "$1" | awk '{print $1}'
    fi
}

# ------------------------------------------------------------------ sandbox

scenario() {
    N=$((N + 1))
    SB="$WORK/s$N"
    mkdir -p "$SB/home" "$SB/stubs" "$SB/fixtures" "$SB/tmp"
    echo "$1"
    stub_curl
}

# run_ensure ARGS...: run the script with a clean environment in the sandbox.
run_ensure() {
    env -i HOME="$SB/home" PATH="$SB/stubs:$SYS_PATH" TMPDIR="$SB/tmp" SANDBOX="$SB" \
        bash "$SCRIPT" "$@" >"$SB/out" 2>"$SB/err"
    RC=$?
    OUT="$(cat "$SB/out")"
    ERR="$(cat "$SB/err")"
}

# make_camp PATH yes|no LABEL: a stub camp. "yes" lists --no-link in its help.
make_camp() {
    mkdir -p "$(dirname "$1")"
    {
        echo '#!/bin/bash'
        echo '[ -n "${SANDBOX-}" ] && echo "camp $*" >>"$SANDBOX/camp.calls"'
        echo 'if [ "${1-}" = "fresh" ] && [ "${2-}" = "--help" ]; then'
        echo '  echo "Usage: camp fresh [flags]"'
        echo '  echo "  -n, --dry-run   Preview without making changes"'
        if [ "$2" = "yes" ]; then
            echo '  echo "      --no-link   Never link an unlinked repository"'
        fi
        echo '  exit 0'
        echo 'fi'
        echo "if [ \"\${1-}\" = \"version\" ]; then echo \"camp $3\"; exit 0; fi"
        echo 'echo "stub camp: unexpected arguments: $*" >&2'
        echo 'exit 97'
    } >"$1"
    chmod +x "$1"
}

make_fest() {
    mkdir -p "$(dirname "$1")"
    printf '#!/bin/bash\necho "fest stub"\n' >"$1"
    chmod +x "$1"
}

# stub_curl: serves fixtures from the sandbox and logs every call.
stub_curl() {
    cat >"$SB/stubs/curl" <<'EOF'
#!/bin/bash
echo "$*" >>"$SANDBOX/curl.calls"
[ -f "$SANDBOX/curl.fail" ] && exit 22
dest=""
url=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o) dest="$2"; shift 2 ;;
        --connect-timeout | --max-time) shift 2 ;;
        http*) url="$1"; shift ;;
        *) shift ;;
    esac
done
case "$url" in
    */releases/latest) src="$SANDBOX/fixtures/release.json" ;;
    */checksums.txt) src="$SANDBOX/fixtures/checksums.txt" ;;
    *.tar.gz) src="$SANDBOX/fixtures/archive.tar.gz" ;;
    *) exit 22 ;;
esac
[ -f "$src" ] || exit 22
if [ -n "$dest" ]; then cp "$src" "$dest"; else cat "$src"; fi
EOF
    chmod +x "$SB/stubs/curl"
}

# make_release yes|no TAG [corrupt]: a fixture release whose camp is or is not
# capable. "corrupt" publishes a checksum that does not match the archive.
make_release() {
    local capable="$1" tag="$2" corrupt="${3-}" ver="${2#v}" sum name
    rm -rf "$SB/fixtures/pkg"
    make_camp "$SB/fixtures/pkg/festival-$ver/camp" "$capable" "$tag"
    make_fest "$SB/fixtures/pkg/festival-$ver/fest"
    tar -czf "$SB/fixtures/archive.tar.gz" -C "$SB/fixtures/pkg" "festival-$ver"
    sum="$(sha "$SB/fixtures/archive.tar.gz")"
    if [ "$corrupt" = "corrupt" ]; then
        sum="0000000000000000000000000000000000000000000000000000000000000000"
    fi
    : >"$SB/fixtures/checksums.txt"
    {
        echo "{"
        echo "  \"tag_name\": \"$tag\","
        echo "  \"assets\": ["
    } >"$SB/fixtures/release.json"
    for name in "festival-$ver-macOS-all.tar.gz" "festival-$ver-linux-x86_64.tar.gz" "festival-$ver-linux-arm64.tar.gz"; do
        echo "$sum  $name" >>"$SB/fixtures/checksums.txt"
        echo "    {\"browser_download_url\": \"https://github.com/Obedience-Corp/festival/releases/download/$tag/$name\"}," >>"$SB/fixtures/release.json"
    done
    {
        echo "    {\"browser_download_url\": \"https://github.com/Obedience-Corp/festival/releases/download/$tag/checksums.txt\"}"
        echo "  ]"
        echo "}"
    } >>"$SB/fixtures/release.json"
}

# stub_manager ACTION [VERSION] [LATEST] [UPGRADE]: a festival manager whose
# `update --json` reports ACTION. Optional $SB/festival.update.sh runs first.
stub_manager() {
    cat >"$SB/stubs/festival" <<'EOF'
#!/bin/bash
echo "$*" >>"$SANDBOX/festival.calls"
case "${1-}" in
    resolve)
        [ -f "$SANDBOX/festival.resolve" ] || exit 1
        cat "$SANDBOX/festival.resolve"
        exit 0
        ;;
    update)
        [ -f "$SANDBOX/festival.update.sh" ] && . "$SANDBOX/festival.update.sh"
        cat "$SANDBOX/festival.update.json" 2>/dev/null
        exit "$(cat "$SANDBOX/festival.update.rc" 2>/dev/null || echo 0)"
        ;;
esac
exit 97
EOF
    chmod +x "$SB/stubs/festival"
    if [ "${1-}" = "error" ]; then
        cat >"$SB/festival.update.json" <<'EOF'
{
  "ok": false,
  "action": "update",
  "schema_version": "festival/v1alpha1",
  "warnings": [],
  "error": {
    "code": "E_SOURCE_FETCH",
    "message": "could not reach the release source"
  }
}
EOF
        echo 1 >"$SB/festival.update.rc"
        return 0
    fi
    {
        echo '{'
        echo '  "ok": true,'
        echo '  "action": "update",'
        echo '  "schema_version": "festival/v1alpha1",'
        echo '  "warnings": [],'
        echo '  "data": {'
        echo '    "package": "obedience-corp/festival",'
        echo "    \"action\": \"$1\","
        [ -n "${2-}" ] && echo "    \"version\": \"$2\","
        [ -n "${3-}" ] && echo "    \"latest\": \"$3\","
        [ -n "${4-}" ] && echo "    \"upgrade\": \"$4\","
        echo '    "self_replaced": false'
        echo '  }'
        echo '}'
    } >"$SB/festival.update.json"
}

# ---------------------------------------------------------------- predicates

rc_is() { [ "$RC" -eq "$1" ]; }
out_is() { [ "$OUT" = "$1" ]; }
out_empty() { [ -z "$OUT" ]; }
out_has() { printf '%s' "$OUT" | grep -qE -- "$1"; }
out_lines() { [ "$(printf '%s\n' "$OUT" | grep -c .)" -eq "$1" ]; }
err_empty() { [ -z "$ERR" ]; }
err_has() { printf '%s' "$ERR" | grep -qE -- "$1"; }
err_lacks() { ! err_has "$1"; }
no_curl() { [ ! -s "$SB/curl.calls" ]; }
curl_count() {
    local n
    n="$(grep -c . "$SB/curl.calls" 2>/dev/null)"
    [ "${n:-0}" -eq "$1" ]
}
manager_ran() { grep -qxF -- "$1" "$SB/festival.calls" 2>/dev/null; }
manager_never() { ! grep -qE -- "$1" "$SB/festival.calls" 2>/dev/null; }
exists() { [ -e "$1" ]; }
absent() { [ ! -e "$1" ]; }
sha_is() { [ "$(sha "$1")" = "$2" ]; }
receipt_has() { grep -qxF -- "$1" "$SB/home/.local/state/fresh/receipt" 2>/dev/null; }
# snapshot DIR: every file under DIR with its checksum, for "nothing changed".
snapshot() {
    (cd "$1" && find . -type f -print | LC_ALL=C sort | while IFS= read -r f; do
        printf '%s %s\n' "$(sha "$f")" "$f"
    done)
}
same() { [ "$1" = "$2" ]; }

LOCAL_CAMP=""
set_local() { LOCAL_CAMP="$SB/home/.local/bin/camp"; }

# ================================================================ scenarios

scenario "1  capable camp on PATH: ready, silent, no network"
make_camp "$SB/stubs/camp" yes v2.0.0
run_ensure
check "exits 0" rc_is 0
check "stdout is exactly the camp path" out_is "$SB/stubs/camp"
check "stderr is empty" err_empty
check "curl was never called" no_curl
check "nothing was written under the home directory" same "$(snapshot "$SB/home")" ""

scenario "2  camp missing and install blocked"
: >"$SB/curl.fail"
set_local
run_ensure
check "exits 3" rc_is 3
check "stdout is empty" out_empty
check "nothing was installed" absent "$LOCAL_CAMP"
check "says Festival was not installed" err_has "Festival was not installed"
check "does not suggest piping curl to a shell" err_lacks "curl .*\| *(ba)?sh"

scenario "3  camp missing, install succeeds, release is capable"
make_release yes v9.9.9
set_local
run_ensure
check "exits 0" rc_is 0
check "stdout is exactly the installed camp path" out_is "$LOCAL_CAMP"
check "camp was installed" exists "$LOCAL_CAMP"
check "fest was installed" exists "$SB/home/.local/bin/fest"
check "reports one install line" err_has "installed Festival v9.9.9 \(camp, fest\)"
check "says the install directory is not on PATH" err_has "is not on your PATH"
check "receipt records the tag" receipt_has "tag=v9.9.9"
check "receipt records the camp checksum" receipt_has "camp_sha256=$(sha "$LOCAL_CAMP")"
calls_after_install="$(grep -c . "$SB/curl.calls")"
run_ensure
check "second run exits 0" rc_is 0
check "second run prints the same path" out_is "$LOCAL_CAMP"
check "second run is silent" err_empty
check "second run uses no network" curl_count "$calls_after_install"

scenario "4  camp missing, install succeeds, release is not capable yet"
make_release no v9.9.9
set_local
run_ensure
check "exits 5" rc_is 5
check "stdout is still the camp path" out_is "$LOCAL_CAMP"
check "says the release cannot do it yet" err_has "not linked to a camp yet"
check "says it still works in linked repositories" err_has "already linked to a camp"

scenario "5  checksum mismatch installs nothing"
make_release yes v9.9.9 corrupt
set_local
run_ensure
check "exits 3" rc_is 3
check "stdout is empty" out_empty
check "nothing was installed" absent "$LOCAL_CAMP"
check "no receipt was written" absent "$SB/home/.local/state/fresh/receipt"
check "says the checksum did not match" err_has "checksum mismatch"

scenario "6  old camp, festival manager upgrades it"
make_camp "$SB/stubs/camp" no v1.0.0
stub_manager upgraded 9.9.9
{
    echo "cat >\"\$SANDBOX/stubs/camp\" <<'CAMP'"
    echo '#!/bin/bash'
    echo 'if [ "${1-}" = "fresh" ]; then echo "      --no-link   Never link"; exit 0; fi'
    echo 'echo "camp v9.9.9"'
    echo 'CAMP'
} >"$SB/festival.update.sh"
run_ensure
check "exits 0" rc_is 0
check "stdout is exactly the camp path" out_is "$SB/stubs/camp"
check "ran festival update --json" manager_ran "update --json"
check "never passed --force" manager_never "--force"
check "never passed --allow-unverified" manager_never "--allow-unverified"
check "reports the update" err_has "updated Festival to 9.9.9 through the festival manager"
check "did not download anything itself" no_curl

scenario "7  old camp, festival manager says the suite is current"
make_camp "$SB/stubs/camp" no v1.0.0
before="$(sha "$SB/stubs/camp")"
stub_manager current 0.3.19
run_ensure
check "exits 5" rc_is 5
check "stdout is the camp path" out_is "$SB/stubs/camp"
check "camp was not touched" sha_is "$SB/stubs/camp" "$before"
check "did not download anything itself" no_curl

scenario "8  old camp from a package manager with an update available"
make_camp "$SB/stubs/camp" no v1.0.0
before="$(sha "$SB/stubs/camp")"
stub_manager package 0.3.19 0.4.0 "brew upgrade --cask festival"
printf '#!/bin/bash\necho ran >>"$SANDBOX/brew.calls"\n' >"$SB/stubs/brew"
chmod +x "$SB/stubs/brew"
run_ensure
check "exits 4" rc_is 4
check "stdout is the camp path" out_is "$SB/stubs/camp"
check "surfaces the package manager command" err_has "update it with: brew upgrade --cask festival"
check "did not run the package manager" absent "$SB/brew.calls"
check "camp was not touched" sha_is "$SB/stubs/camp" "$before"
check "did not download anything itself" no_curl

scenario "9  old camp from a package manager, already at the latest release"
make_camp "$SB/stubs/camp" no v1.0.0
stub_manager package 0.3.19 0.3.19 "brew upgrade --cask festival"
run_ensure
check "exits 5" rc_is 5
check "does not tell the user to upgrade" err_lacks "update it with"

scenario "10 old camp, festival manager fails"
make_camp "$SB/stubs/camp" no v1.0.0
before="$(sha "$SB/stubs/camp")"
stub_manager error
run_ensure
check "exits 3" rc_is 3
check "stdout is the camp path" out_is "$SB/stubs/camp"
check "passes on the manager's message" err_has "festival update failed: could not reach the release source"
check "camp was not touched" sha_is "$SB/stubs/camp" "$before"

scenario "11 old camp that is not ours to replace"
make_camp "$SB/stubs/camp" no v1.0.0
before="$(sha "$SB/stubs/camp")"
make_release yes v9.9.9
run_ensure
check "exits 4" rc_is 4
check "stdout is the camp path" out_is "$SB/stubs/camp"
check "says it was left alone" err_has "left alone"
check "camp was not touched" sha_is "$SB/stubs/camp" "$before"
check "curl was never called" no_curl

scenario "12 old camp that this script installed is reinstalled"
make_release no v9.9.9
set_local
run_ensure
check "first install exits 5" rc_is 5
make_release yes v9.9.10
run_ensure
check "exits 0 after the newer release" rc_is 0
check "stdout is the camp path" out_is "$LOCAL_CAMP"
check "reports the update" err_has "updated Festival to v9.9.10"
check "receipt records the new tag" receipt_has "tag=v9.9.10"

scenario "13 a binary replaced at our path is no longer ours"
make_release no v9.9.9
set_local
run_ensure
make_camp "$LOCAL_CAMP" no dev-build
before="$(sha "$LOCAL_CAMP")"
calls_before="$(grep -c . "$SB/curl.calls")"
make_release yes v9.9.10
run_ensure
check "exits 4" rc_is 4
check "the replaced binary was not touched" sha_is "$LOCAL_CAMP" "$before"
check "nothing was downloaded" curl_count "$calls_before"

scenario "14 manager says unmanaged, our own install is updated"
make_release no v9.9.9
set_local
run_ensure
stub_manager unmanaged
make_release yes v9.9.10
run_ensure
check "exits 0" rc_is 0
check "asked the manager first" manager_ran "update --json"
check "then reinstalled its own copy" err_has "updated Festival to v9.9.10"

scenario "15 camp found only through festival resolve"
make_camp "$SB/elsewhere/camp" yes v2.0.0
stub_manager current 2.0.0
echo "$SB/elsewhere/camp" >"$SB/festival.resolve"
run_ensure
check "exits 0" rc_is 0
check "stdout is the resolved path" out_is "$SB/elsewhere/camp"
check "did not run an update" manager_never "^update"

scenario "16 unsupported platform"
printf '#!/bin/bash\nif [ "${1-}" = "-s" ]; then echo MINGW64_NT-10.0; else echo x86_64; fi\n' >"$SB/stubs/uname"
chmod +x "$SB/stubs/uname"
run_ensure
check "exits 3" rc_is 3
check "points to WSL2" err_has "WSL2"
check "curl was never called" no_curl

scenario "17 usage errors"
run_ensure --bogus
check "unknown flag exits 2" rc_is 2
run_ensure --check --hook
check "--check with --hook exits 2" rc_is 2

# ------------------------------------------------------------------ --check

scenario "18 --check, capable camp"
make_camp "$SB/stubs/camp" yes v2.0.0
run_ensure --check
check "exits 0" rc_is 0
check "stdout is the camp path" out_is "$SB/stubs/camp"
check "says it is ready" err_has "ready; nothing to do"

scenario "19 --check, camp missing"
make_release yes v9.9.9
before="$(snapshot "$SB/home")"
run_ensure --check
check "exits 6" rc_is 6
check "stdout is empty" out_empty
check "says what it would install" err_has "would install the latest Festival release"
check "says it changed nothing" err_has "--check changed nothing"
check "curl was never called" no_curl
check "home directory is unchanged" same "$(snapshot "$SB/home")" "$before"

scenario "20 --check, old camp with a festival manager"
make_camp "$SB/stubs/camp" no v1.0.0
before="$(sha "$SB/stubs/camp")"
stub_manager upgraded 9.9.9
run_ensure --check
check "exits 6" rc_is 6
check "stdout is the camp path" out_is "$SB/stubs/camp"
check "reports the camp is not capable" err_has "camp fresh has no --no-link"
check "says it would run the manager" err_has "would run: .*festival update"
check "did not run festival update" manager_never "^update"
check "camp was not touched" sha_is "$SB/stubs/camp" "$before"
check "curl was never called" no_curl

scenario "21 --check, old camp that is not ours"
make_camp "$SB/stubs/camp" no v1.0.0
run_ensure --check
check "exits 4" rc_is 4
check "says it was left alone" err_has "left alone"
check "says it changed nothing" err_has "--check changed nothing"
check "curl was never called" no_curl

scenario "22 --check, old camp that this script installed"
make_release no v9.9.9
set_local
run_ensure
before="$(snapshot "$SB/home")"
calls_before="$(grep -c . "$SB/curl.calls")"
make_release yes v9.9.10
run_ensure --check
check "exits 6" rc_is 6
check "says it would reinstall" err_has "would reinstall the latest Festival release"
check "nothing was downloaded" curl_count "$calls_before"
check "home directory is unchanged" same "$(snapshot "$SB/home")" "$before"

# ------------------------------------------------------------------- --hook

scenario "23 --hook, capable camp: silent"
make_camp "$SB/stubs/camp" yes v2.0.0
run_ensure --hook
check "exits 0" rc_is 0
check "stdout is empty" out_empty
check "stderr is empty" err_empty

scenario "24 --hook, camp missing and install blocked: never fails the session"
: >"$SB/curl.fail"
run_ensure --hook
check "exits 0" rc_is 0
check "stdout is empty" out_empty
check "leaves a short stderr line" err_has "Festival was not installed"

scenario "25 --hook, camp missing and install succeeds: says so on stdout"
make_release yes v9.9.9
run_ensure --hook
check "exits 0" rc_is 0
check "stdout is one line" out_lines 1
check "stdout is the install notice, not a path" out_has "^fresh: installed Festival v9.9.9"
check "camp was installed" exists "$SB/home/.local/bin/camp"

scenario "26 --hook, old camp that is not ours: quiet, and at most once a day"
make_camp "$SB/stubs/camp" no v1.0.0
run_ensure --hook
check "exits 0" rc_is 0
check "stdout is empty" out_empty
check "first run leaves a stderr line" err_has "left alone"
run_ensure --hook
check "second run exits 0" rc_is 0
check "second run is silent" err_empty
check "curl was never called" no_curl

scenario "27 --hook, package-manager install with an update available"
make_camp "$SB/stubs/camp" no v1.0.0
stub_manager package 0.3.19 0.4.0 "npm install -g @obedience-corp/festival@latest"
run_ensure --hook
check "exits 0" rc_is 0
check "stdout is empty" out_empty
check "surfaces the command on stderr" err_has "npm install -g @obedience-corp/festival@latest"

scenario "28 --hook, unsupported platform"
printf '#!/bin/bash\nif [ "${1-}" = "-s" ]; then echo MINGW64_NT-10.0; else echo x86_64; fi\n' >"$SB/stubs/uname"
chmod +x "$SB/stubs/uname"
run_ensure --hook
check "exits 0" rc_is 0
check "stdout is empty" out_empty

# --------------------------------------------------------------- pure logic

scenario "29 version comparison and JSON reading"
unit() { env -i HOME="$SB/home" PATH="$SYS_PATH" bash -c ". \"$SCRIPT\"; $1"; }
check "0.3.19 is older than 0.4.0" unit 'version_lt 0.3.19 0.4.0'
check "v0.3.9 is older than v0.3.10" unit 'version_lt v0.3.9 v0.3.10'
check "0.4.0 is not older than 0.3.19" unit '! version_lt 0.4.0 0.3.19'
check "equal versions are not older" unit '! version_lt 0.3.19 0.3.19'
json='{
  "ok": true,
  "action": "update",
  "data": {
    "starter": {
      "action": "created"
    },
    "package": "obedience-corp/festival",
    "action": "package",
    "upgrade": "brew update && brew upgrade --cask festival",
    "self_replaced": false
  }
}'
check "reads the inner action, not the envelope's" unit "[ \"\$(json_string '$json' action)\" = package ]"
check "unescapes the upgrade command" unit "[ \"\$(json_string '$json' upgrade)\" = 'brew update && brew upgrade --cask festival' ]"
check "a missing key reads as empty" unit "[ -z \"\$(json_string '$json' latest)\" ]"

echo
scenario "30 missing camp never overwrites an existing fest"
make_fest "$SB/home/.local/bin/fest"
printf '#!/bin/bash\necho developer-fest\n' >"$SB/home/.local/bin/fest"
before="$(sha "$SB/home/.local/bin/fest")"
make_release yes v9.9.9
run_ensure
check "exits 3" rc_is 3
check "existing fest is preserved" sha_is "$SB/home/.local/bin/fest" "$before"
check "camp is not partially installed" absent "$SB/home/.local/bin/camp"
check "explains the conflicting binary" err_has "will not replace.*fest"
check "no download was attempted" no_curl

scenario "31 replacing our fest revokes permission to update the suite"
make_release no v9.9.9
set_local
run_ensure
before="$(sha "$LOCAL_CAMP")"
printf '#!/bin/bash\necho developer-fest\n' >"$SB/home/.local/bin/fest"
fest_before="$(sha "$SB/home/.local/bin/fest")"
calls_before="$(grep -c . "$SB/curl.calls")"
make_release yes v9.9.10
run_ensure
check "exits 3" rc_is 3
check "camp is preserved" sha_is "$LOCAL_CAMP" "$before"
check "developer fest is preserved" sha_is "$SB/home/.local/bin/fest" "$fest_before"
check "no new download was attempted" curl_count "$calls_before"

scenario "32 an older release never downgrades our install"
make_release no v9.9.9
set_local
run_ensure
before="$(sha "$LOCAL_CAMP")"
fest_before="$(sha "$SB/home/.local/bin/fest")"
make_release yes v9.9.8
run_ensure
check "exits 3" rc_is 3
check "camp is not downgraded" sha_is "$LOCAL_CAMP" "$before"
check "fest is not downgraded" sha_is "$SB/home/.local/bin/fest" "$fest_before"
check "receipt keeps the installed release" receipt_has "tag=v9.9.9"
check "explains the downgrade refusal" err_has "will not downgrade"

echo "ensure-festival tests: passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ]
