#!/usr/bin/env bash
# `restore all`: bulk restore of every saved session in one pass, added
# alongside the existing single-session modes ("restore.sh", "restore.sh
# <session>", "restore.sh quiet"). Those existing modes are already covered
# extensively by test_save_restore.sh; this file only tests the new "all"
# mode plus a light smoke check that both modes coexist without leaking into
# each other.
#
# `restore()` (see test_helpers.sh) already appends "quiet" to every
# invocation, so every case below also implicitly exercises restore-all's
# quiet output - no separate assertion for that is needed.
#
# Restore-all deliberately does not restore "the" active pane/window (there's
# no single coherent choice across many bulk-restored sessions, and there's
# typically no attached client at the points this mode is meant to run from).
# None of the assertions below require an active pane/window to end up set.

source "$(dirname "$0")/helpers/test_helpers.sh"
setup
tmuxp set -g automatic-rename off

# --- all: no-op when nothing has been saved yet ---
make_session lonely LONELY_MARK
restore all
assert_contains "$(pane_text lonely)" "LONELY_MARK" "no snapshots: live session keeps its own content"
assert_eq "$(tmuxp list-windows -t lonely | wc -l | tr -d ' ')" "1" "no snapshots: live session gains no windows"
assert_no_file "$TEST_PERSIST_DIR/restore" "no snapshots: no restore staging left behind"

# --- all: recreates every saved session, no cross-contamination, unsaved sessions left untouched ---
make_session alpha ALPHA_MARK
save alpha
make_session beta BETA_MARK
save beta
make_session untouched UNTOUCHED_MARK      # live, but never saved

tmuxp kill-session -t alpha
tmuxp kill-session -t beta
restore all

alpha_txt="$(pane_text alpha)"
beta_txt="$(pane_text beta)"
assert_contains     "$alpha_txt" "ALPHA_MARK" "restore all: alpha restored its own content"
assert_not_contains "$alpha_txt" "BETA_MARK"  "restore all: alpha did not get beta's content"
assert_contains     "$beta_txt"  "BETA_MARK"  "restore all: beta restored its own content"
assert_not_contains "$beta_txt"  "ALPHA_MARK" "restore all: beta did not get alpha's content"

untouched_txt="$(pane_text untouched)"
assert_contains     "$untouched_txt" "UNTOUCHED_MARK" "restore all: live session with no snapshot keeps its own content"
assert_not_contains "$untouched_txt" "ALPHA_MARK"      "restore all: live session with no snapshot did not gain alpha's content"
assert_not_contains "$untouched_txt" "BETA_MARK"       "restore all: live session with no snapshot did not gain beta's content"
assert_eq "$(tmuxp list-windows -t untouched | wc -l | tr -d ' ')" "1" "restore all: live session with no snapshot gains no windows"

# --- all: full per-session restoration (windows, window names, layout), not just one pane ---
make_session multi MULTI_WIN0_MARK
tmuxp new-window -t multi -n secondwin
tmuxp send-keys -t multi:secondwin "echo MULTI_WIN1_MARK" Enter
sleep 0.3
save multi
tmuxp kill-session -t multi
restore all

assert_eq "$(tmuxp list-windows -t multi | wc -l | tr -d ' ')" "2" "restore all: window count restored"
assert_contains "$(tmuxp list-windows -t multi -F '#{window_name}')" "secondwin" "restore all: window name restored"
assert_contains "$(pane_text multi:0)"         "MULTI_WIN0_MARK" "restore all: first window content restored"
assert_contains "$(pane_text multi:secondwin)" "MULTI_WIN1_MARK" "restore all: second window content restored"

# --- smoke test: single-session restore is unaffected by the existence of "all" ---
make_session solo1 SOLO1_MARK
save solo1
make_session solo2 SOLO2_MARK
save solo2
tmuxp kill-session -t solo1

restore solo1                              # no "all" - existing single-session mode
assert_contains "$(pane_text solo1)" "SOLO1_MARK" "single-session restore still works alongside 'all'"
assert_eq "$(tmuxp list-windows -t solo2 | wc -l | tr -d ' ')" "1" "single-session restore did not touch other saved sessions"

teardown
finish
