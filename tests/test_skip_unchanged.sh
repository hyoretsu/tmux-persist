#!/usr/bin/env bash
# @persist-skip-unchanged: a re-save with identical content writes no new
# snapshot (only refreshes the existing one's mtime); a content change or the
# option being off writes a fresh snapshot.

source "$(dirname "$0")/helpers/test_helpers.sh"
setup
tmuxp set -g @persist-capture-pane-contents on

count_snaps() { ls "$TEST_PERSIST_DIR"/foo_????????T??????.tgz 2>/dev/null | wc -l | tr -d ' '; }
snap_path()   { ls "$TEST_PERSIST_DIR"/foo_????????T??????.tgz 2>/dev/null | head -1; }

# --- first save: one snapshot + hash sidecar ---
make_session foo HELLO_FOO
# Freeze the window name so tmux's automatic-rename (tmux -> zsh shortly after
# creation) doesn't mutate the layout between the two "unchanged" saves.
tmuxp set -g automatic-rename off
tmuxp rename-window -t foo:0 winfoo
sleep 0.3
save all
assert_eq "$(count_snaps)" "1"                      "first save writes one snapshot"
assert_file "$TEST_PERSIST_DIR/foo_last.hash"       "first save writes hash sidecar"
hash1="$(cat "$TEST_PERSIST_DIR/foo_last.hash")"

# --- unchanged re-save: skipped, no new snapshot, hash unchanged ---
sleep 1.2
save all
assert_eq "$(count_snaps)" "1"                      "unchanged re-save writes no new snapshot"
assert_eq "$(cat "$TEST_PERSIST_DIR/foo_last.hash")" "$hash1" "unchanged re-save keeps hash"

# --- skip refreshes the existing snapshot's mtime (keeps pruning from expiring it) ---
snap="$(snap_path)"
touch -d "10 days ago" "$snap"
sleep 1.2
save all
assert_eq "$(find "$snap" -mtime +1 2>/dev/null | wc -l | tr -d ' ')" "0" "skip refreshes snapshot mtime"

# --- content change: a fresh snapshot is written ---
tmuxp send-keys -t foo "echo CHANGED_FOO" Enter
sleep 0.4
sleep 1.2
save all
assert_eq "$(count_snaps)" "2"                      "content change writes a new snapshot"

# --- option off: always writes a new snapshot, even when unchanged ---
tmuxp set -g @persist-skip-unchanged off
sleep 1.2
save all
assert_eq "$(count_snaps)" "3"                      "skip off always writes a new snapshot"

teardown
finish
