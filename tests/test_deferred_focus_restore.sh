#!/usr/bin/env bash
# Deferred focus restore for `restore all` (bulk restore). This file is
# written against the spec BEFORE restore_all_sessions() implements it -
# restore.sh is untouched on this branch. Every assertion below therefore
# describes intended behavior, not current behavior; substantive failures
# are expected until the feature is implemented.
#
# Background: restore_one_session() (single-session restore) always has a
# real attached client (it's normally triggered interactively), so it can
# call the three switch-client-based focus-restoration functions
# (restore_active_pane_for_each_window,
# restore_active_and_alternate_windows_for_all_grouped_sessions,
# restore_active_and_alternate_windows) right after restoring structure.
# restore_all_sessions() (bulk restore, e.g. after a crash, or
# tmux-continuum's boot-time trigger) currently skips all three - there's
# usually no attached client yet at that trigger point.
#
# Spec: after restore_all_sessions()'s existing per-session structure/process
# loop completes,
#   - if a client IS already attached: run the three focus functions
#     immediately, for every saved session.
#   - if NO client is attached: arm a ONE-SHOT `client-attached` hook that,
#     the first time any client actually attaches, removes itself first
#     (so it never fires twice), then re-extracts each saved session's
#     permanent snapshot (not the already-cleaned-up staging area from the
#     earlier bulk pass) and runs the three focus functions for it, then
#     cleanup_restored_pane_contents.
#
# Confirmed empirically (see attach_control_client in test_helpers.sh) that
# `tmux -C attach-session`, with its stdin held open, is a real attached
# client for tmux's purposes: it fires the native client-attached hook and
# shows up in `list-clients`, and `switch-client` run via `run-shell` (not
# from that client's own command context) successfully retargets it as long
# as at least one client is attached - exactly what restore.sh's existing
# switch-client-based functions rely on.
#
# Window/pane indices below assume base-index 0, same assumption every other
# test file in this suite already makes (tests run with `-f /dev/null`, no
# user config).

source "$(dirname "$0")/helpers/test_helpers.sh"

# Small polling predicates (poll_until needs a command it can re-run each
# iteration, not an already-expanded value).
_active_window_is() { [ "$(active_window_index "$1")" = "$2" ]; }
_active_pane_is()   { [ "$(active_pane_index "$1")" = "$2" ]; }
_hook_armed()        { tmuxp show-hooks -g 2>/dev/null | \grep -q 'client-attached\['; }
_hook_not_armed()    { ! _hook_armed; }

# =====================================================================
# Case 1 + 2: no client at bulk-restore time; client attaches later; and
# the one-shot behavior of the hook once it has fired.
# =====================================================================
setup
tmuxp set -g automatic-rename off

# --- build focusA: 3 windows, window 2 active, pane 1 active within it ---
make_session focusA FOCUSA_W0
tmuxp new-window -t focusA -n w1
tmuxp send-keys -t focusA:w1 "echo FOCUSA_W1" Enter
tmuxp new-window -t focusA -n w2
tmuxp send-keys -t focusA:w2 "echo FOCUSA_W2P0" Enter
tmuxp split-window -t focusA:w2
tmuxp send-keys -t focusA:w2 "echo FOCUSA_W2P1" Enter
tmuxp select-pane -t focusA:w2.1
tmuxp select-window -t focusA:w2
sleep 0.3
save focusA

# --- build focusB: 2 windows, window 1 active, pane 0 active within it ---
make_session focusB FOCUSB_W0
tmuxp new-window -t focusB -n w1
tmuxp send-keys -t focusB:w1 "echo FOCUSB_W1" Enter
tmuxp select-window -t focusB:w1
sleep 0.3
save focusB

tmuxp kill-session -t focusA
tmuxp kill-session -t focusB

# Headless bulk restore: setup() never attached a real client (_bootstrap is
# a detached session and run-shell invocations are not clients), so this
# matches "no client attached at restore-all time".
assert_eq "$(tmuxp list-clients 2>/dev/null | wc -l | tr -d ' ')" "0" "sanity: no client attached before restore all"
restore all

# --- structure sanity (not the point of this file, but worth a cheap check
# that both sessions actually came back before asserting on their focus) ---
assert_eq "$(live_pane_count focusA)" "4" "focusA: pane count restored (4 panes across 3 windows)"
assert_eq "$(live_pane_count focusB)" "2" "focusB: pane count restored (2 panes across 2 windows)"

# --- pre-attach: focus NOT yet restored, still the default landing spot ---
assert_eq "$(active_window_index focusA)" "0" "focusA: pre-attach active window is still the default (0), not yet restored"
assert_eq "$(active_window_index focusB)" "0" "focusB: pre-attach active window is still the default (0), not yet restored"

# --- pre-attach: a one-shot client-attached hook must now be armed ---
assert_contains "$(tmuxp show-hooks -g 2>/dev/null)" "client-attached[" "client-attached hook is armed after a no-client bulk restore"

# --- attach a real client: the deferred focus restore should now run ---
attach_control_client focusA
ctrl1_pid="$CONTROL_CLIENT_PID"
poll_until 5 _active_window_is focusA 2
poll_until 5 _active_window_is focusB 1

assert_eq "$(active_window_index focusA)" "2" "focusA: active window correctly restored to 2 after client attaches"
assert_eq "$(active_pane_index focusA:2)" "1" "focusA: active pane correctly restored to 1 within window 2"
assert_eq "$(active_window_index focusB)" "1" "focusB: active window correctly restored to 1 after client attaches (every saved session, not just one)"
assert_eq "$(active_pane_index focusB:1)" "0" "focusB: active pane correctly restored to 0 within window 1"

# --- the hook must have removed itself after firing ---
poll_until 5 _hook_not_armed
assert_not_contains "$(tmuxp show-hooks -g 2>/dev/null)" "client-attached[" "client-attached hook removed itself after firing once"

# =====================================================================
# Case 2: one-shot behavior - a later reattach must NOT re-apply the saved
# focus over a manual change.
# =====================================================================

# Simulate the user doing real work: manually move off the restored focus.
tmuxp select-window -t focusA:1
tmuxp select-pane -t focusA:1.0
sleep 0.3
assert_eq "$(active_window_index focusA)" "1" "sanity: manual focus change took effect before the second attach"

# Attach a second control client - since the hook already fired once and
# removed itself, this must be a no-op for focus.
attach_control_client focusB
ctrl2_pid="$CONTROL_CLIENT_PID"
sleep 1

assert_eq "$(active_window_index focusA)" "1" "focusA: manual focus change survives a later client attach (one-shot, not reverted)"
assert_not_contains "$(tmuxp show-hooks -g 2>/dev/null)" "client-attached[" "client-attached hook is still gone after a second attach"

detach_all_control_clients
teardown

# =====================================================================
# Case 3: a client IS already attached at bulk-restore time - focus is
# restored immediately, no deferred hook needed or left armed.
# =====================================================================
setup
tmuxp set -g automatic-rename off

attach_control_client _bootstrap
ctrl3_pid="$CONTROL_CLIENT_PID"
assert_eq "$(tmuxp list-clients 2>/dev/null | wc -l | tr -d ' ')" "1" "sanity: a client is attached before restore all runs"

make_session focusC FOCUSC_W0
tmuxp new-window -t focusC -n w1
tmuxp send-keys -t focusC:w1 "echo FOCUSC_W1" Enter
tmuxp select-window -t focusC:w1
sleep 0.3
save focusC
tmuxp kill-session -t focusC

restore all   # restore() already sleeps 1.5s afterward - no extra wait added

assert_eq "$(live_pane_count focusC)" "2" "focusC: pane count restored"
assert_eq "$(active_window_index focusC)" "1" "focusC: active window restored immediately (client already attached, no need to wait for a later attach)"
assert_eq "$(active_pane_index focusC:1)" "0" "focusC: active pane restored immediately"
assert_not_contains "$(tmuxp show-hooks -g 2>/dev/null)" "client-attached[" "client-attached hook was never armed (went through the immediate path, not the deferred one)"

detach_all_control_clients
teardown

# =====================================================================
# Case 4: grouped sessions - a grouped session's own active/alternate
# window must also be restored via the deferred path.
# =====================================================================
setup
tmuxp set -g automatic-rename off

# grpmain: the original session in the group, 3 windows, its own active
# window left at 0 (the default/first window).
make_session grpmain GRPMAIN_W0
tmuxp new-window -t grpmain -n w1
tmuxp send-keys -t grpmain:w1 "echo GRPMAIN_W1" Enter
tmuxp new-window -t grpmain -n w2
tmuxp send-keys -t grpmain:w2 "echo GRPMAIN_W2" Enter
tmuxp select-window -t grpmain:0
sleep 0.3

# grpsecond: a grouped (secondary) session sharing grpmain's windows, with
# its OWN active/alternate window set differently from grpmain's.
tmuxp new-session -d -t grpmain -s grpsecond
tmuxp select-window -t grpsecond:w1
tmuxp select-window -t grpsecond:w2
sleep 0.3

# Each session is saved separately, same as every other case in this file -
# dump_grouped_sessions() detects the grouping globally regardless of which
# single session is being saved (confirmed empirically).
save grpmain
save grpsecond

tmuxp kill-session -t grpsecond
tmuxp kill-session -t grpmain

restore all

# --- structure sanity: both sessions back, sharing 3 windows ---
assert_eq "$(tmuxp list-windows -t grpmain | wc -l | tr -d ' ')" "3" "grpmain: window count restored"
assert_eq "$(tmuxp list-windows -t grpsecond | wc -l | tr -d ' ')" "3" "grpsecond: shares grpmain's restored windows"

# --- pre-attach: grpsecond's own active window not yet restored to 2 ---
assert_eq "$(active_window_index grpsecond)" "0" "grpsecond: pre-attach active window is still the default (0), not yet restored"

attach_control_client grpmain
ctrl4_pid="$CONTROL_CLIENT_PID"
poll_until 5 _active_window_is grpsecond 2

assert_eq "$(active_window_index grpsecond)" "2" "grpsecond: active window correctly restored to 2 via the deferred path"
assert_eq "$(alternate_window_index grpsecond)" "1" "grpsecond: alternate window correctly restored to 1 via the deferred path"
assert_eq "$(active_window_index grpmain)" "0" "grpmain: its own (non-grouped) active window is also correctly restored, unaffected by grpsecond's"

detach_all_control_clients
teardown

finish
