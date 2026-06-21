#!/usr/bin/env bash
# A 0-byte / corrupt snapshot (interrupted save, crash, lost socket) must not
# break things: save must not repoint "last" at an empty file, and restore must
# skip an empty/dangling snapshot instead of feeding tmux an empty file (which
# can make an auto-restored session exit immediately). (tmux-resurrect#115, #403)

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

# Run a helpers.sh snippet inside the test server (bare tmux calls hit the test
# socket). Keep snippets free of single quotes.
hp() { # snippet
	local out="$TEST_PERSIST_DIR/hp.out"
	rm -f "$out"
	tmuxp run-shell "bash -c 'CURRENT_DIR=\"$PLUGIN_DIR/scripts\"; \
		source \"$PLUGIN_DIR/scripts/variables.sh\"; \
		source \"$PLUGIN_DIR/scripts/helpers.sh\"; \
		{ $1 ; } > \"$out\" 2>&1'"
	sleep 0.4
	cat "$out"
}

# --- snapshot_valid ---------------------------------------------------------
assert_eq "$(hp 'snapshot_valid ghost && echo YES || echo NO')" "NO" \
	"snapshot_valid is false when there is no snapshot"

make_session keep KEEP_MARK
save keep
assert_eq "$(hp 'snapshot_valid keep && echo YES || echo NO')" "YES" \
	"snapshot_valid is true for a real snapshot"

# Corrupt the snapshot to 0 bytes; the pointer is now invalid.
: > "$TEST_PERSIST_DIR/$(readlink "$TEST_PERSIST_DIR/keep_last")"
assert_eq "$(hp 'snapshot_valid keep && echo YES || echo NO')" "NO" \
	"snapshot_valid is false for a 0-byte snapshot"

# --- save does not clobber a good "last" with an empty snapshot -------------
tmuxp set -g @persist-snapshot-format separate
make_session gd GD_MARK
save gd
good_target="$(readlink "$TEST_PERSIST_DIR/gd_last")"
# Simulate a failed save: empty staging layout, then create a snapshot.
hp 'ensure() { mkdir -p "$(persist_dir)/save"; }; ensure; : > "$(persist_dir)/save/layout"; snapshot_create gd; echo done' >/dev/null
assert_eq "$(readlink "$TEST_PERSIST_DIR/gd_last")" "$good_target" \
	"last still points at the good snapshot after an empty save"

# --- restore skips a corrupt snapshot without harming the session ----------
restore keep
assert_contains "$(pane_text keep)" "KEEP_MARK" "session untouched when its snapshot is corrupt"

teardown
finish
