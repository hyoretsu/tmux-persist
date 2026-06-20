#!/usr/bin/env bash
# Automatic behavior wired by persist.tmux: hooks installed, auto-restore when a
# session is created, and unsaved sessions left untouched.

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

load_plugin

# --- hooks are installed ---
hooks="$(tmuxp show-hooks -g 2>/dev/null)"
assert_contains "$hooks" "client-detached"  "client-detached hook set"
assert_contains "$hooks" "session-closed"   "session-closed hook set"
assert_contains "$hooks" "session-created"  "session-created (auto-restore) hook set"

# --- auto-restore when a saved session is (re)created ---
make_session proj PROJ_AUTO_MARK
save proj
tmuxp kill-session -t proj
sleep 0.3
tmuxp new-session -d -s proj            # fires session-created -> auto-restore
sleep 1.5
assert_contains "$(pane_text proj)" "PROJ_AUTO_MARK" "auto-restore on session creation"

# --- creating an unsaved session is a silent no-op ---
tmuxp new-session -d -s scratch
sleep 0.6
assert_eq "$(tmuxp list-windows -t scratch | wc -l | tr -d ' ')" "1" "unsaved session left untouched"

# --- disabling auto-restore skips it ---
tmuxp set -g @persist-auto-restore off
load_plugin                              # re-applies hooks per option
make_session keep KEEP_MARK
save keep
tmuxp kill-session -t keep
sleep 0.3
tmuxp new-session -d -s keep
sleep 1.0
assert_not_contains "$(pane_text keep)" "KEEP_MARK" "auto-restore off: no restore on create"

teardown
finish
