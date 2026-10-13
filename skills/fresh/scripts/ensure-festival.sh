#!/usr/bin/env bash
# ensure-festival.sh: make sure a `camp` that can freshen an unlinked git
# repository is available, installing or updating Festival only when needed.
#
# Usage:
#   ensure-festival.sh           find camp; install or update Festival if needed
#   ensure-festival.sh --check   report what would happen; change nothing
#   ensure-festival.sh --hook    session-start mode: always exits 0, prints no path
#
# stdout  The absolute path to `camp` on one line, whenever one was found.
#         Nothing else. In --hook mode stdout is empty unless Festival was
#         installed or updated, in which case it carries that one notice,
#         because a session-start hook's stdout is what the session sees.
# stderr  Everything a person should read.
#
# Exit codes
#   0  ready: this camp can freshen a repository that is not linked to a camp
#   2  usage error
#   3  Festival could not be installed or updated
#   4  camp is too old and is not this script's to replace
#   5  the latest Festival release cannot freshen an unlinked repository yet
#   6  --check only: an install or update is needed and was not attempted
#
# On 4 and 5 the path is still printed. That camp works in a repository that is
# already linked to a camp.
#
# What this script will never do: run a package manager, pass --force or
# --allow-unverified to the festival manager, install anything whose checksum
# does not verify, or replace a binary it did not install.
#
# The release download, checksum verification, and install steps are adapted
# from Festival's plugin hook, claude-plugin/hooks/scripts/ensure-festival.sh
# in https://github.com/Obedience-Corp/festival (Apache-2.0). See NOTICE.

set -euo pipefail

REPO="Obedience-Corp/festival"
RELEASES_PAGE="https://github.com/${REPO}/releases/latest"
CAPABILITY_FLAG="--no-link"

HOME_DIR="${HOME:-}"
INSTALL_DIR="${INSTALL_DIR:-$HOME_DIR/.local/bin}"
MANAGED_BIN_DIR="$HOME_DIR/.obey/installer/bin"
STATE_DIR="${XDG_STATE_HOME:-$HOME_DIR/.local/state}/fresh"
RECEIPT_FILE="$STATE_DIR/receipt"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME_DIR/.cache}/fresh"
ATTEMPT_FILE="$CACHE_DIR/last-update-attempt"
DOWNLOAD_TIMEOUT_SECONDS="${FRESH_DOWNLOAD_TIMEOUT_SECONDS:-120}"
HOOK_DOWNLOAD_TIMEOUT_SECONDS=45
HOOK_RETRY_SECONDS=86400

EXIT_READY=0
EXIT_USAGE=2
EXIT_FAILED=3
EXIT_NOT_OURS=4
EXIT_NOT_YET=5
EXIT_CHECK_PENDING=6

MODE="run"
TMP_DIR=""
OS=""
ARCH=""
INSTALLED_TAG=""

say() {
    echo "fresh: $*" >&2
}

# changed reports something that was installed or updated. In --hook mode it
# also goes to stdout, the one channel a session-start hook can be heard on.
changed() {
    say "$*"
    if [ "$MODE" = "hook" ]; then
        echo "fresh: $*"
    fi
}

cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

# A session must never fail because of this script, however it ends.
on_exit() {
    local status=$?
    cleanup
    if [ "$MODE" = "hook" ]; then
        exit 0
    fi
    exit "$status"
}

# finish CODE [CAMP_PATH]: print the path (never in --hook mode) and exit.
finish() {
    local code="$1"
    local camp_path="${2-}"
    if [ "$MODE" != "hook" ] && [ -n "$camp_path" ]; then
        printf '%s\n' "$camp_path"
    fi
    exit "$code"
}

usage() {
    sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
}

is_executable_file() {
    [ -n "${1-}" ] && [ -f "$1" ] && [ -x "$1" ]
}

# find_manager prints the path to the festival manager, if there is one.
find_manager() {
    local candidate
    if candidate="$(type -P festival 2>/dev/null)" && is_executable_file "$candidate"; then
        printf '%s\n' "$candidate"
        return 0
    fi
    for candidate in "$INSTALL_DIR/festival" "$MANAGED_BIN_DIR/festival"; do
        if is_executable_file "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

# find_camp prints the path to camp: PATH first, then the places Festival's own
# installers use, then wherever the festival manager says it runs camp from.
find_camp() {
    local candidate manager
    if candidate="$(type -P camp 2>/dev/null)" && is_executable_file "$candidate"; then
        printf '%s\n' "$candidate"
        return 0
    fi
    for candidate in "$INSTALL_DIR/camp" "$MANAGED_BIN_DIR/camp"; do
        if is_executable_file "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    if manager="$(find_manager)"; then
        candidate="$("$manager" resolve camp 2>/dev/null </dev/null || true)"
        candidate="$(printf '%s\n' "$candidate" | awk 'NR==1 {print; exit}')"
        if is_executable_file "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi
    return 1
}

# camp_capable CAMP: 0 when `camp fresh --help` lists the capability flag.
camp_capable() {
    local help
    help="$("$1" fresh --help 2>&1 </dev/null || true)"
    case "$help" in
        *"$CAPABILITY_FLAG"*) return 0 ;;
    esac
    return 1
}

camp_version() {
    local out
    out="$("$1" version 2>/dev/null </dev/null || true)"
    printf '%s\n' "$out" | awk 'NR==1 {print; exit}'
}

detect_platform() {
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$os" in
        darwin) OS="macOS" ;;
        linux) OS="linux" ;;
        *)
            say "unsupported platform: $os. Festival runs on macOS and Linux; on Windows, use WSL2."
            return 1
            ;;
    esac
    arch="$(uname -m)"
    case "$arch" in
        x86_64 | amd64) ARCH="x86_64" ;;
        arm64 | aarch64) ARCH="arm64" ;;
        *)
            say "unsupported architecture: $arch."
            return 1
            ;;
    esac
}

require_tools() {
    local name missing=""
    for name in curl tar grep sed awk find install; do
        if ! command -v "$name" >/dev/null 2>&1; then
            missing="$missing $name"
        fi
    done
    if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
        missing="$missing shasum-or-sha256sum"
    fi
    if [ -n "$missing" ]; then
        say "cannot install Festival, required commands not found:$missing"
        return 1
    fi
}

download_timeout() {
    if [ "$MODE" = "hook" ] && [ "$DOWNLOAD_TIMEOUT_SECONDS" -gt "$HOOK_DOWNLOAD_TIMEOUT_SECONDS" ]; then
        echo "$HOOK_DOWNLOAD_TIMEOUT_SECONDS"
        return 0
    fi
    echo "$DOWNLOAD_TIMEOUT_SECONDS"
}

fetch_release() {
    curl -fsSL --connect-timeout 10 --max-time "$(download_timeout)" \
        "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null
}

# find_archive_url RELEASE_JSON: exact OS and arch first, then an OS-wide
# archive such as macOS-all.
find_archive_url() {
    local release_json="$1"
    local url
    url="$(printf '%s\n' "$release_json" | grep '"browser_download_url"' | grep -i "${OS}" | grep -i "${ARCH}" | grep '\.tar\.gz"' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
    if [ -z "$url" ]; then
        url="$(printf '%s\n' "$release_json" | grep '"browser_download_url"' | grep -i "${OS}" | grep -i "all" | grep '\.tar\.gz"' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
    fi
    printf '%s\n' "$url"
}

extract_tag() {
    printf '%s\n' "$1" | grep '"tag_name"' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true
}

download_file() {
    local url="$1"
    local dest="$2"
    local tmp="${dest}.tmp"
    rm -f "$tmp"
    if ! curl -fsSL --connect-timeout 10 --max-time "$(download_timeout)" "$url" -o "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$dest"
}

sha256_file() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
        return 0
    fi
    sha256sum "$1" | awk '{print $1}'
}

expected_checksum() {
    awk -v name="$2" '$2 == name {print $1; found=1} END {exit found ? 0 : 1}' "$1"
}

verify_checksum() {
    local archive_path="$1"
    local checksums_path="$2"
    local archive_name="$3"
    local expected actual
    if ! expected="$(expected_checksum "$checksums_path" "$archive_name")"; then
        say "checksum for ${archive_name} not found in checksums.txt"
        return 1
    fi
    actual="$(sha256_file "$archive_path")"
    if [ "$actual" != "$expected" ]; then
        say "checksum mismatch for ${archive_name}: expected ${expected}, got ${actual}"
        return 1
    fi
}

write_receipt() {
    local dir="$1"
    local tag="$2"
    mkdir -p "$STATE_DIR"
    {
        echo "tag=${tag}"
        echo "dir=${dir}"
        echo "camp_sha256=$(sha256_file "${dir}/camp")"
        echo "fest_sha256=$(sha256_file "${dir}/fest")"
    } >"${RECEIPT_FILE}.tmp"
    mv "${RECEIPT_FILE}.tmp" "$RECEIPT_FILE"
}

receipt_value() {
    [ -f "$RECEIPT_FILE" ] || return 1
    sed -n "s/^${1}=//p" "$RECEIPT_FILE" | head -n 1
}

# is_ours CAMP: 0 only when this script installed exactly this file. A binary
# someone later replaced at the same path has a different checksum and is not
# ours any more.
is_ours() {
    local camp_path="$1"
    local binary_name="${2:-camp}"
    local dir recorded
    dir="$(receipt_value dir || true)"
    recorded="$(receipt_value "${binary_name}_sha256" || true)"
    [ -n "$dir" ] && [ -n "$recorded" ] || return 1
    [ -d "$dir" ] || return 1
    [ -f "$camp_path" ] && [ ! -L "$camp_path" ] || return 1
    [ "$(dirname "$camp_path")" -ef "$dir" ] || return 1
    [ "$(sha256_file "$camp_path")" = "$recorded" ]
}

# Check both destinations before downloading or writing either binary. Owning
# camp does not imply owning a fest that the user installed or replaced.
check_install_targets() {
    local dir="$1" name path
    for name in camp fest; do
        path="$dir/$name"
        if { [ -e "$path" ] || [ -L "$path" ]; } && ! is_ours "$path" "$name"; then
            say "will not replace ${path}: it was not installed by fresh, or has been replaced since."
            return 1
        fi
    done
}

# install_release DIR: download the latest Festival release, verify it, and
# install camp and fest into DIR. Nothing is installed unless the checksum
# verifies and both binaries are present. Returns 1 on any failure.
install_release() {
    local dir="$1"
    local release_json archive_url archive_name archive_path checksums_path extract_dir
    local camp_src fest_src installed_tag

    check_install_targets "$dir" || return 1
    detect_platform || return 1
    require_tools || return 1

    if ! release_json="$(fetch_release)" || [ -z "$release_json" ]; then
        say "could not reach GitHub for the latest Festival release. See ${RELEASES_PAGE}"
        return 1
    fi
    archive_url="$(find_archive_url "$release_json")"
    if [ -z "$archive_url" ]; then
        say "no Festival release archive for ${OS}/${ARCH}. See ${RELEASES_PAGE}"
        return 1
    fi
    INSTALLED_TAG="$(extract_tag "$release_json")"
    installed_tag="$(receipt_value tag || true)"
    if is_ours "$dir/camp" && [ -n "$installed_tag" ] && version_lt "$INSTALLED_TAG" "$installed_tag"; then
        say "will not downgrade Festival from ${installed_tag} to ${INSTALLED_TAG}. Nothing was installed."
        return 1
    fi

    archive_name="$(basename "$archive_url")"
    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fresh-festival.XXXXXX")"
    archive_path="${TMP_DIR}/${archive_name}"
    checksums_path="${TMP_DIR}/checksums.txt"
    extract_dir="${TMP_DIR}/extract"

    if ! download_file "$archive_url" "$archive_path"; then
        say "download failed: ${archive_url}"
        return 1
    fi
    if ! download_file "${archive_url%/*}/checksums.txt" "$checksums_path"; then
        say "checksum download failed. Nothing was installed."
        return 1
    fi
    if ! verify_checksum "$archive_path" "$checksums_path" "$archive_name"; then
        say "checksum verification failed. Nothing was installed."
        return 1
    fi

    mkdir -p "$extract_dir"
    if ! tar -xzf "$archive_path" -C "$extract_dir"; then
        say "could not unpack ${archive_name}. Nothing was installed."
        return 1
    fi
    camp_src="$(find "$extract_dir" -type f -name camp | head -n 1)"
    fest_src="$(find "$extract_dir" -type f -name fest | head -n 1)"
    if [ -z "$camp_src" ] || [ -z "$fest_src" ]; then
        say "${archive_name} does not contain camp and fest. Nothing was installed."
        return 1
    fi

    if ! mkdir -p "$dir"; then
        say "could not create ${dir}."
        return 1
    fi
    check_install_targets "$dir" || return 1
    if ! install -m 0755 "$fest_src" "${dir}/fest" || ! install -m 0755 "$camp_src" "${dir}/camp"; then
        say "could not write to ${dir}."
        return 1
    fi
    if ! write_receipt "$dir" "$INSTALLED_TAG"; then
        say "could not record what was installed; a later update will leave these binaries alone."
    fi
    return 0
}

path_hint() {
    case ":${PATH}:" in
        *":$1:"*) ;;
        *) say "$1 is not on your PATH. Add it with: export PATH=\"$1:\$PATH\"" ;;
    esac
}

# json_string JSON KEY: the last string value for KEY in pretty-printed JSON,
# one key per line, which is how the festival manager prints it.
json_string() {
    printf '%s\n' "$1" |
        sed -n 's/^[[:space:]]*"'"$2"'"[[:space:]]*:[[:space:]]*"\(.*\)",\{0,1\}[[:space:]]*$/\1/p' |
        tail -n 1 |
        sed -e 's/\\u0026/\&/g' -e 's/\\u003c/</g' -e 's/\\u003e/>/g' -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}

# version_lt A B: 0 when release A is older than release B (X.Y.Z, optional v).
version_lt() {
    awk -v a="${1#v}" -v b="${2#v}" 'BEGIN {
        split(a, x, /[.-]/); split(b, y, /[.-]/)
        for (i = 1; i <= 3; i++) {
            if ((x[i] + 0) < (y[i] + 0)) exit 0
            if ((x[i] + 0) > (y[i] + 0)) exit 1
        }
        exit 1
    }'
}

hook_attempted_recently() {
    local last now
    [ "$MODE" = "hook" ] || return 1
    [ -f "$ATTEMPT_FILE" ] || return 1
    last="$(cat "$ATTEMPT_FILE" 2>/dev/null || echo 0)"
    case "$last" in
        '' | *[!0-9]*) return 1 ;;
    esac
    now="$(date +%s)"
    [ $((now - last)) -lt "$HOOK_RETRY_SECONDS" ]
}

record_hook_attempt() {
    [ "$MODE" = "hook" ] || return 0
    mkdir -p "$CACHE_DIR" 2>/dev/null || return 0
    date +%s >"$ATTEMPT_FILE" 2>/dev/null || true
}

say_not_yet() {
    say "the latest Festival release cannot freshen a repository that is not linked to a camp yet."
    say "fresh still works in repositories already linked to a camp."
}

# after_change CAMP: Festival was just installed or updated; is it ready?
after_change() {
    local camp_path="$1"
    if camp_capable "$camp_path"; then
        finish "$EXIT_READY" "$camp_path"
    fi
    say_not_yet
    finish "$EXIT_NOT_YET" "$camp_path"
}

install_missing() {
    if [ "$MODE" = "check" ]; then
        say "camp was not found."
        say "would install the latest Festival release (camp, fest) into ${INSTALL_DIR}, checksum verified."
        say "--check changed nothing."
        finish "$EXIT_CHECK_PENDING"
    fi
    if ! install_release "$INSTALL_DIR"; then
        say "Festival was not installed. Install it yourself: brew install --cask Obedience-Corp/tap/festival, or npm install -g @obedience-corp/festival."
        finish "$EXIT_FAILED"
    fi
    changed "installed Festival ${INSTALLED_TAG} (camp, fest) into ${INSTALL_DIR}."
    path_hint "$INSTALL_DIR"
    after_change "${INSTALL_DIR}/camp"
}

# update_with_manager MANAGER CAMP: let the festival manager update the suite.
# Returns 0 when the manager says the suite is not its to update, so the caller
# can fall through to its own receipt. Every other outcome exits.
update_with_manager() {
    local manager="$1"
    local camp_path="$2"
    local out action upgrade version latest refreshed message

    if [ "$MODE" = "check" ]; then
        say "would run: ${manager} update"
        say "--check changed nothing."
        finish "$EXIT_CHECK_PENDING" "$camp_path"
    fi

    if ! out="$("$manager" update --json </dev/null)"; then
        message="$(json_string "$out" message)"
        say "festival update failed${message:+: $message}"
        finish "$EXIT_FAILED" "$camp_path"
    fi
    action="$(json_string "$out" action)"
    version="$(json_string "$out" version)"
    latest="$(json_string "$out" latest)"
    upgrade="$(json_string "$out" upgrade)"

    case "$action" in
        upgraded)
            changed "updated Festival to ${version} through the festival manager."
            refreshed="$(find_camp || true)"
            after_change "${refreshed:-$camp_path}"
            ;;
        current)
            say "Festival ${version} is already the latest release."
            say_not_yet
            finish "$EXIT_NOT_YET" "$camp_path"
            ;;
        package)
            if [ -n "$latest" ] && [ -n "$version" ] && version_lt "$version" "$latest"; then
                say "Festival ${version} was installed with a package manager, and ${latest} is available."
                if [ -n "$upgrade" ]; then
                    say "update it with: ${upgrade}"
                else
                    say "update it with the package manager you installed it with."
                fi
                finish "$EXIT_NOT_OURS" "$camp_path"
            fi
            say_not_yet
            finish "$EXIT_NOT_YET" "$camp_path"
            ;;
        unmanaged | absent)
            return 0
            ;;
        *)
            say "festival update returned something unexpected; nothing was changed."
            finish "$EXIT_FAILED" "$camp_path"
            ;;
    esac
}

update_existing() {
    local camp_path="$1"
    local manager dir

    # At session start, try at most once a day. A camp that is present but too
    # old stays that way until a release ships or its owner updates it.
    if hook_attempted_recently; then
        finish "$EXIT_NOT_YET" "$camp_path"
    fi
    record_hook_attempt

    if manager="$(find_manager)"; then
        update_with_manager "$manager" "$camp_path"
    fi

    if is_ours "$camp_path"; then
        dir="$(dirname "$camp_path")"
        if [ "$MODE" = "check" ]; then
            say "would reinstall the latest Festival release into ${dir}, checksum verified."
            say "--check changed nothing."
            finish "$EXIT_CHECK_PENDING" "$camp_path"
        fi
        if ! install_release "$dir"; then
            say "Festival was not updated."
            finish "$EXIT_FAILED" "$camp_path"
        fi
        changed "updated Festival to ${INSTALLED_TAG} in ${dir}."
        after_change "$camp_path"
    fi

    say "${camp_path} is too old to freshen a repository that is not linked to a camp."
    say "fresh did not install it, so it was left alone. Update it the way you installed it:"
    say "brew upgrade --cask festival, npm install -g @obedience-corp/festival@latest, or rebuild it."
    say "fresh still works in repositories already linked to a camp."
    if [ "$MODE" = "check" ]; then
        say "--check changed nothing."
    fi
    finish "$EXIT_NOT_OURS" "$camp_path"
}

main() {
    local arg camp_path version

    for arg in "$@"; do
        case "$arg" in
            --check)
                [ "$MODE" = "run" ] || { usage; exit "$EXIT_USAGE"; }
                MODE="check"
                ;;
            --hook)
                [ "$MODE" = "run" ] || { usage; exit "$EXIT_USAGE"; }
                MODE="hook"
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                usage
                exit "$EXIT_USAGE"
                ;;
        esac
    done

    if [ -z "$HOME_DIR" ]; then
        say "HOME is not set."
        finish "$EXIT_FAILED"
    fi

    if ! camp_path="$(find_camp)"; then
        install_missing
    fi

    if camp_capable "$camp_path"; then
        if [ "$MODE" = "check" ]; then
            say "camp found at ${camp_path} ($(camp_version "$camp_path")). It is ready; nothing to do."
        fi
        finish "$EXIT_READY" "$camp_path"
    fi

    if [ "$MODE" = "check" ]; then
        version="$(camp_version "$camp_path")"
        say "camp found at ${camp_path} (${version:-version unknown})."
        say "it cannot freshen a repository that is not linked to a camp: camp fresh has no ${CAPABILITY_FLAG}."
    fi
    update_existing "$camp_path"
}

# Run main only when executed, not when sourced by the tests.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
    trap on_exit EXIT
    main "$@"
fi
