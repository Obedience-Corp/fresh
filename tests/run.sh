#!/usr/bin/env bash
# Run every test for the fresh plugin. Exits non-zero if any suite fails.
#
# Nothing here touches the real home directory or the network: the script tests
# run in throwaway directories against stub binaries.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
status=0

for suite in "$DIR/repo.test.sh" "$DIR/ensure-festival.test.sh"; do
    echo "== $(basename "$suite")"
    if ! bash "$suite"; then
        status=1
    fi
    echo
done

if [ "$status" -eq 0 ]; then
    echo "all suites passed"
else
    echo "one or more suites failed" >&2
fi
exit "$status"
