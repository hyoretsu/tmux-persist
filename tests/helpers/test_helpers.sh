#!/usr/bin/env bash
#
# Minimal self-contained test helpers for tmux-persist.
# No external test framework, no tmux-test submodule, no expect.
#
# Each test file sources this, calls `setup`, makes assertions, then
# `teardown` and `finish` (whose exit status reflects pass/fail).

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TESTS_PASSED=0
TESTS_FAILED=0

TEST_SOCKET="persist-test-$$"
TEST_PERSIST_DIR=""

tmuxp() { tmux -L "$TEST_SOCKET" "$@"; }

# Sets a file's mtime to N days in the past, portably across BSD (macOS) and
# GNU touch/date. GNU's `touch -d "N days ago"` relies on GNU date's flexible
# parser; BSD touch also has a -d flag, but it only accepts a strict ISO 8601
# timestamp, not relative English phrases, so that form silently errors on
# macOS. -t [[CC]YY]MMDDhhmm[.SS] is accepted identically by both, so compute
# the target with whichever `date` dialect is present and feed touch that.
touch_days_ago() { # days file
	local days="$1" file="$2" ts
	if date -v-1d >/dev/null 2>&1; then
		ts="$(date -v-"${days}"d +%Y%m%d%H%M.%S)"
	else
		ts="$(date -d "$days days ago" +%Y%m%d%H%M.%S)"
	fi
	# Fail loudly, not silently: a bad $ts here would otherwise make touch
	# either error quietly (caller ignores the exit code) or - worse - no-op
	# and leave the file's mtime unchanged, which is exactly the failure mode
	# this helper exists to fix (a file meant to look "old" silently doesn't).
	if [ -z "$ts" ]; then
		echo "touch_days_ago: failed to compute a timestamp for '$days days ago'" >&2
		return 1
	fi
	touch -t "$ts" "$file"
}

setup() {
	TEST_PERSIST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/persist-test.XXXXXX")"
	tmux -L "$TEST_SOCKET" kill-server 2>/dev/null
	# Fresh server that does NOT load the user's tmux config.
	tmuxp -f /dev/null new-session -d -s _bootstrap
	tmuxp set -g @persist-dir "$TEST_PERSIST_DIR"
}

teardown() {
	tmux -L "$TEST_SOCKET" kill-server 2>/dev/null
	[ -n "$TEST_PERSIST_DIR" ] && rm -rf "$TEST_PERSIST_DIR"
	TEST_PERSIST_DIR=""
}

# Run plugin scripts through tmux run-shell (so $TMUX is set) and wait a beat.
save()        { tmuxp run-shell "$PLUGIN_DIR/scripts/save.sh quiet $*"; sleep 0.6; }
restore()     { tmuxp run-shell "$PLUGIN_DIR/scripts/restore.sh $* quiet"; sleep 1.5; }
load_plugin() { tmuxp run-shell "$PLUGIN_DIR/persist.tmux"; sleep 0.6; }
prune() {
	tmuxp run-shell "bash -c 'CURRENT_DIR=\"$PLUGIN_DIR/scripts\"; \
		source \"$PLUGIN_DIR/scripts/variables.sh\"; \
		source \"$PLUGIN_DIR/scripts/helpers.sh\"; prune_all_old_backups'"
	sleep 0.4
}

# Create a session with a unique marker line in its pane.
make_session() { # name marker
	tmuxp new-session -d -s "$1"
	tmuxp send-keys -t "$1" "echo $2" Enter
	sleep 0.3
}

pane_text() { tmuxp capture-pane -pt "$1" -S -200 2>/dev/null; }

# assertions
_ok() { TESTS_PASSED=$((TESTS_PASSED + 1)); printf '  ok   - %s\n' "$1"; }
_ko() { TESTS_FAILED=$((TESTS_FAILED + 1)); printf '  FAIL - %s\n' "$1"; }

assert_contains()     { case "$1" in *"$2"*) _ok "$3";; *) _ko "$3 (missing: $2)";; esac; }
assert_not_contains() { case "$1" in *"$2"*) _ko "$3 (unexpected: $2)";; *) _ok "$3";; esac; }
assert_file()         { [ -e "$1" ] && _ok "$2" || _ko "$2 (no file: $1)"; }
assert_no_file()      { [ ! -e "$1" ] && _ok "$2" || _ko "$2 (exists: $1)"; }
assert_eq()           { [ "$1" = "$2" ] && _ok "$3" || _ko "$3 (got '$1', want '$2')"; }

finish() {
	echo "  -> ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
	[ "$TESTS_FAILED" -eq 0 ]
}
