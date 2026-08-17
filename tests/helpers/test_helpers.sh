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

# `tmux kill-server` returns before the server process actually finishes
# reaping its children - measured directly (see the fix this test file is
# for): ~0ms for a 1-pane tree, ~3.4s for a 100-pane one. A test case with a
# large session tree (e.g. case4b's 50+ phantom sessions) followed
# immediately by the next case's setup() starting a fresh server on the
# SAME socket path can hit that exact race between test cases, producing
# "server exited unexpectedly"/"no server running" failures that have
# nothing to do with whatever that next case is actually testing. Waits for
# the OLD server's process to actually exit (not just for its socket to
# stop answering, which can happen before the process is fully gone) before
# returning, so setup()/teardown() themselves are never a source of test
# flakiness.
_kill_test_server_and_wait() {
	local pid socket_path
	# Ask the live server for its own canonical socket path rather than
	# constructing one - two dead ends confirmed directly: (1) tmux resolves
	# its socket directory from $TMUX_TMPDIR or /tmp, never $TMPDIR, so
	# environments where $TMPDIR happens to also be set (common on macOS)
	# make guessing the wrong base directory an easy mistake; (2) even with
	# the right base directory, macOS's /tmp is a symlink to /private/tmp
	# and `lsof -t` does not dereference it when matching a socket path
	# argument - it needs the literal canonical path. #{socket_path}
	# already gives us that path pre-resolved, sidestepping both problems.
	socket_path="$(tmux -L "$TEST_SOCKET" display-message -p '#{socket_path}' 2>/dev/null)"
	[ -n "$socket_path" ] && pid="$(lsof -t "$socket_path" 2>/dev/null | head -1)"
	tmux -L "$TEST_SOCKET" kill-server 2>/dev/null
	[ -n "$pid" ] || return 0
	local waited=0
	while kill -0 "$pid" 2>/dev/null; do
		sleep 0.05
		waited=$((waited + 1))
		[ "$waited" -ge 200 ] && break   # 10s cap, comfortably past the measured worst case
	done
}

setup() {
	TEST_PERSIST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/persist-test.XXXXXX")"
	_kill_test_server_and_wait
	# Fresh server that does NOT load the user's tmux config.
	tmuxp -f /dev/null new-session -d -s _bootstrap
	tmuxp set -g @persist-dir "$TEST_PERSIST_DIR"
}

teardown() {
	_kill_test_server_and_wait
	[ -n "$TEST_PERSIST_DIR" ] && rm -rf "$TEST_PERSIST_DIR"
	TEST_PERSIST_DIR=""
	[ -n "${SABOTAGE_SCRIPT:-}" ] && rm -f "$SABOTAGE_SCRIPT"
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

# Live pane count for one session, across all its windows. Not
# `list-panes -t X -a`: despite the -t, tmux's -a flag lists every pane on the
# whole server and ignores -t entirely - session-scoping needs -s instead.
live_pane_count() {
	tmuxp list-panes -s -t "$1" 2>/dev/null | wc -l | tr -d ' '
}

# Like restore(), but redirects the restore script's own stderr into $1
# (truncated first) instead of letting it go wherever `tmux run-shell` sends a
# job's stderr (nowhere useful - only a job's stdout is forwarded to the
# invoking client). This is the only way to see the plain `echo ... >&2`
# failure lines the all-sessions retry logic is expected to write.
# `tmux run-shell` blocks until the shell-command finishes, so by the time
# this returns the whole (possibly-retried) restore is already done - the
# trailing sleep is only to let tmux's own state settle, same as restore().
restore_capture_stderr() { # errfile [args...]
	local errfile="$1"; shift
	: > "$errfile"
	tmuxp run-shell "$PLUGIN_DIR/scripts/restore.sh $* quiet 2>>'$errfile'"
	sleep 1.5
}

# Same as restore_capture_stderr, but backgrounded so the caller can poll
# (see poll_until) for the failure line to appear and time it, rather than
# only finding out after the whole (possibly long, budget-scaled) run
# finishes. Bounding the wait this way also means a runaway/never-gives-up
# implementation fails the test instead of hanging the suite.
restore_capture_stderr_bg() { # errfile [args...]
	local errfile="$1"; shift
	: > "$errfile"
	tmuxp run-shell "$PLUGIN_DIR/scripts/restore.sh $* quiet 2>>'$errfile'" &
}

# Like restore(), but does not force "quiet" - use when the assertion is
# about the summary display_message() call itself (see last_displayed_message).
restore_show() { # [args...]
	tmuxp run-shell "$PLUGIN_DIR/scripts/restore.sh $*"
	sleep 1.5
}

# Text of the most recent display_message(...) call on the test server. With
# no client attached it never reaches an actual screen, but tmux still
# records every command it runs in its own message log (`show-messages`,
# newest first), one line per command. Greps for the display-message command
# specifically (rather than just the first line) because display_message()
# itself runs two more tmux commands (saving/restoring the display-time
# option) right before/after the one that actually carries the text.
last_displayed_message() {
	tmuxp show-messages | grep 'command: display-message' | head -1 |
		sed 's/.*command: display-message "//; s/"$//'
}

# Arms $1 (a hook name, e.g. "pre-restore-all") to append one line to $2 each
# time it fires - a cheap way to assert a hook fired exactly N times.
set_counter_hook() { # hook_name counter_file
	tmuxp set -g "@persist-hook-$1" "echo 1 >> '$2'"
}

# Number of times a counter hook armed via set_counter_hook has fired so far.
hook_fire_count() { # counter_file
	if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi
}

# Arms tmux's own native after-new-window/after-split-window hooks (NOT
# tmux-persist's @persist-hook-* system, and deliberately NOT
# after-new-session - see below) to kill the most-recently-created live pane
# belonging to session $1 the instant restore_all_panes() creates one,
# manufacturing a reproducible pane-count mismatch without depending on real
# kill-server teardown timing. These fire synchronously as part of the same
# tmux command that creates the pane/window - confirmed directly, no race.
# Deliberately NOT using @persist-hook-pre-restore-pane-processes: that fires
# once per session (not once per pane, and not during retries - see
# restore_structure_properties() in restore.sh), so it can't manufacture a
# mismatch *during* the retry-safe creation step the fix actually retries.
#
# Deliberately NOT after-new-session either: that fires on a session's
# FIRST/only pane, and killing a session's only pane kills the whole
# session with it - confirmed directly, this cascades into restore.sh's own
# SUBSEQUENT commands (e.g. select-pane on a pane index that never got
# created, split-window against a session that no longer exists) failing
# with real, unrelated tmux errors ("can't find session", "can't find
# pane") that leak onto stderr and are easily mistaken for this fix's own
# failure-reporting output. Restricting to after-new-window/after-split-window
# guarantees the target session's first pane is never touched, so a kill
# only ever removes one of several panes - a clean, non-destructive
# mismatch, not a session-destroying one.
#
# The kill logic lives in a standalone script file, not an inline quoted
# string: a hook's VALUE goes through tmux's own command parser AND its
# format-expansion, and the kill logic needs its own nested quotes/braces
# (`[ -n "$p" ]`, `#{pane_id}`) - inlined, those collide with the hook
# string's own quoting and get prematurely format-expanded (confirmed
# directly: both broke silently, one as a parse error, one as a literal
# pane id spliced into the command text before the nested list-panes call
# ever saw it). A script file sidesteps both: its contents are never parsed
# or format-expanded by tmux at all, only executed by bash.
#   mode "once"   - kills a pane only the first time $1 actually has 2+ live
#                   panes, then never again (tracked via flag file $3) - used
#                   to make exactly one attempt fail before a clean retry.
#   mode "always" - kills a pane every time $1 has 2+ live panes - used to
#                   make every attempt fail (persistent-failure cases). For a
#                   session with only ever 1 saved pane, this mode never
#                   fires (nothing non-first to kill) - use a multi-pane
#                   session for persistent-failure test cases.
#   $3 unused in "always" mode.
# Other sessions restored in the same run are unaffected: these are global
# hooks (fire for every session's creation events), but the kill command
# itself targets session $1 by name, so it's a no-op for any other session.
SABOTAGE_SCRIPT="${TMPDIR:-/tmp}/persist-test-sabotage-$$.sh"
_write_sabotage_script() {
	cat > "$SABOTAGE_SCRIPT" <<'EOF'
#!/usr/bin/env bash
session="$1"; mode="$2"; flag="$3"
[ "$mode" = "once" ] && [ -f "$flag" ] && exit 0
count="$(tmux list-panes -t "$session" 2>/dev/null | wc -l | tr -d ' ')"
[ "${count:-0}" -ge 2 ] || exit 0
p="$(tmux list-panes -t "$session" -F '#{pane_id}' 2>/dev/null | tail -1)"
[ -n "$p" ] || exit 0
tmux kill-pane -t "$p" 2>/dev/null
if [ "$mode" = "once" ]; then touch "$flag"; fi
exit 0
EOF
	chmod +x "$SABOTAGE_SCRIPT"
}
set_sabotage_hook() { # session mode [flag_file]
	local session="$1" mode="$2" flag="$3"
	_write_sabotage_script
	local hook_cmd="run-shell \"'$SABOTAGE_SCRIPT' '$session' '$mode' '$flag'\""
	local h
	for h in after-new-window after-split-window; do
		tmuxp set-hook -g "$h" "$hook_cmd"
	done
}

# Clears all three native hooks set-hook installs, so a later test case in
# the same file doesn't inherit a still-armed sabotage from an earlier one.
clear_sabotage_hook() {
	local h
	for h in after-new-session after-new-window after-split-window; do
		tmuxp set-hook -gu "$h" 2>/dev/null
	done
}

# Polls condition command $2.. every 0.2s until it exits 0 or $1 seconds pass.
# Returns the condition's last exit status. Used instead of a fixed sleep when
# the wait time itself varies by design (e.g. a retry give-up whose length
# scales with fleet size).
poll_until() { # timeout_seconds condition...
	local timeout="$1"; shift
	local max_iters=$(( timeout * 5 ))
	local i=0
	while [ "$i" -lt "$max_iters" ]; do
		"$@" && return 0
		sleep 0.2
		i=$((i + 1))
	done
	"$@"
}

# assertions
_ok() { TESTS_PASSED=$((TESTS_PASSED + 1)); printf '  ok   - %s\n' "$1"; }
_ko() { TESTS_FAILED=$((TESTS_FAILED + 1)); printf '  FAIL - %s\n' "$1"; }

assert_contains()     { case "$1" in *"$2"*) _ok "$3";; *) _ko "$3 (missing: $2)";; esac; }
assert_not_contains() { case "$1" in *"$2"*) _ko "$3 (unexpected: $2)";; *) _ok "$3";; esac; }
assert_file()         { [ -e "$1" ] && _ok "$2" || _ko "$2 (no file: $1)"; }
assert_no_file()      { [ ! -e "$1" ] && _ok "$2" || _ko "$2 (exists: $1)"; }
assert_eq()           { [ "$1" = "$2" ] && _ok "$3" || _ko "$3 (got '$1', want '$2')"; }
assert_ne()            { [ "$1" != "$2" ] && _ok "$3" || _ko "$3 (both '$1' == '$2')"; }

finish() {
	echo "  -> ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
	[ "$TESTS_FAILED" -eq 0 ]
}
