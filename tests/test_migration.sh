#!/usr/bin/env bash
# Auto-migration of a tmux-resurrect global snapshot into per-session snapshots.

source "$(dirname "$0")/helpers/test_helpers.sh"
setup
DIR="$TEST_PERSIST_DIR"

migrate() {
	tmuxp run-shell "bash -c 'CURRENT_DIR=\"$PLUGIN_DIR/scripts\"; \
		source \"$PLUGIN_DIR/scripts/variables.sh\"; \
		source \"$PLUGIN_DIR/scripts/helpers.sh\"; migrate_legacy_snapshots'"
	sleep 0.4
}

# --- craft an old tmux-resurrect global snapshot (two sessions) ---
old="$DIR/tmux_resurrect_20260101T000000.txt"
{
	printf 'pane\ts1\t0\t1\t:*\t0\tbash\t:/tmp\t1\tbash\t:\n'
	printf 'pane\ts2\t0\t1\t:*\t0\tbash\t:/tmp\t1\tbash\t:\n'
	printf 'window\ts1\t0\t:bash\t1\t:*\tlayout\t:\n'
	printf 'window\ts2\t0\t:bash\t1\t:*\tlayout\t:\n'
} > "$old"
ln -sf "tmux_resurrect_20260101T000000.txt" "$DIR/last"

mkdir -p "$DIR/w/pane_contents"
printf 'S1_OLD_CONTENT\n' > "$DIR/w/pane_contents/pane-s1:0.0"
printf 'S2_OLD_CONTENT\n' > "$DIR/w/pane_contents/pane-s2:0.0"
tar czf "$DIR/pane_contents.tar.gz" -C "$DIR/w" ./pane_contents
rm -rf "$DIR/w"

migrate

# --- per-session snapshots + marker created ---
assert_file "$DIR/s1_last" "migrated: s1 snapshot created"
assert_file "$DIR/s2_last" "migrated: s2 snapshot created"
assert_file "$DIR/.migrated_from_resurrect" "migration marker written"

# --- migrated snapshot is self-contained and per-session isolated ---
ex="$DIR/extract"; rm -rf "$ex"; mkdir -p "$ex"
tar xzf "$(echo "$DIR"/s1_*.tgz)" -C "$ex"
assert_contains     "$(cat "$ex/pane_contents/pane-s1:0.0" 2>/dev/null)" "S1_OLD_CONTENT" "s1 pane contents carried over"
assert_no_file      "$ex/pane_contents/pane-s2:0.0" "s1 snapshot has no s2 contents"
assert_contains     "$(cat "$ex/layout")" "s1" "s1 layout present"
assert_not_contains "$(cat "$ex/layout")" "	s2	" "s1 layout has no s2 lines"

# --- idempotent: rerun does not error or duplicate ---
before="$(ls "$DIR"/s1_*.tgz | wc -l | tr -d ' ')"
migrate
after="$(ls "$DIR"/s1_*.tgz | wc -l | tr -d ' ')"
assert_eq "$after" "$before" "re-running migration is a no-op"

teardown
finish
