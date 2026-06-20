#!/usr/bin/env bash
#
# Runs the tmux-persist test suite. Each tests/test_*.sh is self-contained
# (its own tmux server + temp persist dir) and exits non-zero on failure.
#
# Requires: tmux, bash, tar, find. No submodules, no expect.

cd "$(dirname "$0")/.." || exit 2

if ! command -v tmux >/dev/null 2>&1; then
	echo "tmux not found - cannot run tests" >&2
	exit 2
fi

failed=0
for test_file in tests/test_*.sh; do
	echo "== ${test_file} =="
	if ! bash "$test_file"; then
		failed=1
	fi
done

if [ "$failed" -eq 0 ]; then
	echo "ALL TESTS PASSED"
else
	echo "SOME TESTS FAILED"
fi
exit "$failed"
