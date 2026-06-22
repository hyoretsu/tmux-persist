#!/usr/bin/env bash
# A pane whose working directory contains a space (e.g. a home on a volume named
# "El Gato") must save and restore to the exact same path. The old space-escaping
# in dump_panes corrupted such paths. (tmux-resurrect#548)

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

space_dir="$TEST_PERSIST_DIR/El Gato/work"
mkdir -p "$space_dir"

# A session whose pane starts in the spaced directory.
tmuxp new-session -d -s spaced -c "$space_dir"
tmuxp send-keys -t spaced "echo SPACE_MARK" Enter
sleep 0.3
save spaced

# The stored layout must hold the path verbatim - no injected backslash.
layout="$TEST_PERSIST_DIR/restore/layout"
rm -rf "$TEST_PERSIST_DIR/restore"; mkdir -p "$TEST_PERSIST_DIR/restore"
tar xzf "$TEST_PERSIST_DIR/spaced_last" -C "$TEST_PERSIST_DIR/restore" 2>/dev/null
assert_contains     "$(cat "$layout")" "El Gato" "path stored with its space"
assert_not_contains "$(cat "$layout")" 'El\ Gato' "path not backslash-escaped"
rm -rf "$TEST_PERSIST_DIR/restore"

# Round-trip: restore lands the pane back in the spaced directory.
tmuxp kill-session -t spaced
tmuxp new-session -d -s spaced
restore spaced
assert_eq "$(tmuxp display-message -p -t spaced '#{pane_current_path}')" "$space_dir" \
	"restored pane cwd is the spaced path"
assert_contains "$(pane_text spaced)" "SPACE_MARK" "restored pane content"

teardown
finish
