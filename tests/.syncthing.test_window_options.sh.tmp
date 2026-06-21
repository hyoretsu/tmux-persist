#!/usr/bin/env bash
# Per-window options set on a window (e.g. monitor-activity) must survive a
# save/restore cycle. They are stored as "wopt" lines and re-applied on restore.
# (tmux-resurrect#132)

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

wopt() { tmuxp show-options -wv -t "$1" "$2"; }

tmuxp new-session -d -s wo
tmuxp set-option -w -t wo:0 monitor-activity on
tmuxp set-option -w -t wo:0 monitor-bell on
tmuxp set-option -w -t wo:0 main-pane-height 42
save wo

# The layout records the options as wopt lines.
rm -rf "$TEST_PERSIST_DIR/restore"; mkdir -p "$TEST_PERSIST_DIR/restore"
tar xzf "$TEST_PERSIST_DIR/wo_last" -C "$TEST_PERSIST_DIR/restore" 2>/dev/null
assert_contains "$(cat "$TEST_PERSIST_DIR/restore/layout")" "wopt" "window options recorded in layout"
rm -rf "$TEST_PERSIST_DIR/restore"

# Recreate the session fresh (options back to defaults) and restore.
tmuxp kill-session -t wo
tmuxp new-session -d -s wo
assert_eq "$(wopt wo:0 monitor-activity)" "" "fresh window has no monitor-activity override"
restore wo

assert_eq "$(wopt wo:0 monitor-activity)" "on" "monitor-activity restored"
assert_eq "$(wopt wo:0 monitor-bell)"     "on" "monitor-bell restored"
assert_eq "$(wopt wo:0 main-pane-height)" "42" "numeric window option restored"

teardown
finish
