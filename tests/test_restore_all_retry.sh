#!/usr/bin/env bash
# `restore all` retry-on-mismatch behavior: a `tmux kill-server` used to
# recreate a bulk-restore source session returns before the server finishes
# reaping child panes (measured ~0ms for 1 pane, ~3.4s for 100 panes,
# ~33ms/pane), so restore_all_sessions() can start restoring a session while
# its old panes are still mid-teardown on the same socket and silently lose
# it. This file is written against the fix as specified (see the task/spec
# this branch was started from), BEFORE restore_all_sessions() has been
# changed to implement it - restore.sh is untouched on this branch. Every
# assertion below therefore describes intended behavior, not current
# behavior; substantive failures here are expected until the retry logic is
# implemented.
#
# Rather than depending on real kill-server teardown timing (slow and racy to
# reproduce on demand), these tests manufacture a deterministic pane-count
# mismatch: @persist-hook-pre-restore-pane-processes (fires once per
# restore_structure() attempt - see execute_hook in helpers.sh, confirmed
# against docs/hooks.md) is armed to kill one live pane in a specific target
# session, gated by a flag file so the exact attempt(s) it fires on are
# controlled. See set_sabotage_hook, restore_capture_stderr(_bg),
# set_counter_hook and poll_until in test_helpers.sh.
#
# Note: the spec's own shorthand for reading a session's live pane count -
# `tmux list-panes -t "$session" -a` - is what the implementation is expected
# to use internally, but it is not session-scoped for OUR assertions: tmux's
# -a flag lists every pane on the whole server and ignores -t entirely. This
# file's own checks use live_pane_count() (`list-panes -s -t`) instead, which
# actually scopes to one session.

source "$(dirname "$0")/helpers/test_helpers.sh"

# --- case 1: clean first-attempt success, no sabotage ---
setup
tmuxp set -g automatic-rename off

make_session clean1 CLEAN1_W0
tmuxp split-window -t clean1
sleep 0.2
tmuxp new-window -t clean1 -n win2
tmuxp send-keys -t clean1:win2 "echo CLEAN1_W1" Enter
sleep 0.3
save clean1
tmuxp kill-session -t clean1

case1_pre="$TEST_PERSIST_DIR/case1_pre"
case1_post="$TEST_PERSIST_DIR/case1_post"
set_counter_hook "pre-restore-all" "$case1_pre"
set_counter_hook "post-restore-all" "$case1_post"
case1_err="$TEST_PERSIST_DIR/case1_err"
restore_capture_stderr "$case1_err" all

assert_eq "$(live_pane_count clean1)" "3" "case1: pane count correct (3 panes across 2 windows)"
assert_eq "$(tmuxp list-windows -t clean1 | wc -l | tr -d ' ')" "2" "case1: window count correct"
assert_contains "$(pane_text clean1:0.0)"  "CLEAN1_W0" "case1: first window content restored"
assert_contains "$(pane_text clean1:win2)" "CLEAN1_W1" "case1: second window content restored"
assert_eq "$(hook_fire_count "$case1_pre")"  "1" "case1: pre-restore-all hook fired exactly once"
assert_eq "$(hook_fire_count "$case1_post")" "1" "case1: post-restore-all hook fired exactly once"
assert_eq "$(cat "$case1_err" 2>/dev/null)" "" "case1: no failure text on stderr"

teardown

# --- case 2: retry-then-succeed (sabotage fires on attempt #1 only) ---
setup
tmuxp set -g automatic-rename off

make_session retry2 RETRY2_W0
tmuxp split-window -t retry2
sleep 0.2
tmuxp new-window -t retry2 -n win2
tmuxp send-keys -t retry2:win2 "echo RETRY2_W1" Enter
sleep 0.3
save retry2
tmuxp kill-session -t retry2

case2_flag="$TEST_PERSIST_DIR/case2_killed_once"
set_sabotage_hook retry2 once "$case2_flag"
case2_pre="$TEST_PERSIST_DIR/case2_pre"
case2_post="$TEST_PERSIST_DIR/case2_post"
set_counter_hook "pre-restore-all" "$case2_pre"
set_counter_hook "post-restore-all" "$case2_post"
case2_err="$TEST_PERSIST_DIR/case2_err"
restore_capture_stderr "$case2_err" all

assert_file "$case2_flag" "case2: sabotage actually fired (killed a pane on attempt 1)"
assert_eq "$(live_pane_count retry2)" "3" "case2: final pane count correct after retry"
assert_eq "$(tmuxp list-windows -t retry2 | wc -l | tr -d ' ')" "2" "case2: final window count correct"
assert_eq "$(hook_fire_count "$case2_pre")"  "1" "case2: pre-restore-all fired exactly once (outside the retry loop, not once per attempt)"
assert_eq "$(hook_fire_count "$case2_post")" "1" "case2: post-restore-all fired exactly once (outside the retry loop, not once per attempt)"
assert_not_contains "$(cat "$case2_err" 2>/dev/null)" "retry2" "case2: no failure line for a session that eventually succeeded"

teardown

# --- case 3: persistent failure, alongside a healthy session in the same run ---
setup
tmuxp set -g automatic-rename off

# small (2-pane) session so a killed pane never fully destroys the session
# itself (tmux auto-kills a session when its last pane closes) - keeps every
# retry attempt "recreate one missing pane", not "recreate from scratch".
make_session bad3 BAD3_MARK
tmuxp split-window -t bad3
sleep 0.2
save bad3
tmuxp kill-session -t bad3

make_session good3 GOOD3_MARK
save good3
tmuxp kill-session -t good3

set_sabotage_hook bad3 always ""
case3_err="$TEST_PERSIST_DIR/case3_err"
restore_capture_stderr "$case3_err" all      # restore_capture_stderr already runs quiet

assert_contains "$(cat "$case3_err" 2>/dev/null)" "bad3" "case3: sabotaged session's name reported on stderr even under quiet"
assert_eq "$(live_pane_count good3)" "1" "case3: healthy session still fully restored despite the other session's persistent failure (per-session independence)"
assert_eq "$(tmuxp list-windows -t good3 | wc -l | tr -d ' ')" "1" "case3: healthy session window count correct"
assert_contains "$(pane_text good3)" "GOOD3_MARK" "case3: healthy session content restored"

teardown

# --- case 4: retry give-up budget scales with fleet size ---
# 4a: a lone, tiny, persistently-sabotaged session - nothing else saved.
setup
tmuxp set -g automatic-rename off

make_session budget_a BUDGET_A_MARK
tmuxp split-window -t budget_a
sleep 0.2
save budget_a
tmuxp kill-session -t budget_a
set_sabotage_hook budget_a always ""

case4a_err="$TEST_PERSIST_DIR/case4a_err"
: > "$case4a_err"
restore_capture_stderr_bg "$case4a_err" all
start_a=$(date +%s)
poll_until 30 grep -q "budget_a" "$case4a_err"
found_a=$?
end_a=$(date +%s)
elapsed_a=$((end_a - start_a))
assert_eq "$found_a" "0" "case4a: tiny-fleet sabotaged session eventually reports failure"

teardown

# 4b: the same shape of sabotaged session, but as one of many saved sessions
# in a much larger fleet - inflates TOTAL_EXPECTED_PANES (summed across every
# saved session, not just the sabotaged one) and so should inflate the
# give-up budget too.
setup
tmuxp set -g automatic-rename off

make_session budget_b BUDGET_B_MARK
tmuxp split-window -t budget_b
sleep 0.2
save budget_b
tmuxp kill-session -t budget_b

i=1
while [ "$i" -le 50 ]; do
	tmuxp new-session -d -s "phantom$i"
	i=$((i + 1))
done
save all   # snapshots budget_b (already dead) is skipped; phantoms + _bootstrap saved live

set_sabotage_hook budget_b always ""
case4b_err="$TEST_PERSIST_DIR/case4b_err"
: > "$case4b_err"
restore_capture_stderr_bg "$case4b_err" all
start_b=$(date +%s)
poll_until 60 grep -q "budget_b" "$case4b_err"
found_b=$?
end_b=$(date +%s)
elapsed_b=$((end_b - start_b))
assert_eq "$found_b" "0" "case4b: large-fleet sabotaged session eventually reports failure"

teardown

# Only a meaningful comparison if both sides actually detected the failure
# line rather than exhausting poll_until's timeout - a timeout makes elapsed_*
# just measure our own poll_until timeout constants (30/60s), not real
# give-up behavior, and must not be read as a passing "scales with fleet
# size" result.
if [ "$found_a" -ne 0 ] || [ "$found_b" -ne 0 ]; then
	_ko "case4: give-up time scales with fleet size (skipped - failure line never appeared within the poll timeout, see case4a/case4b above)"
elif [ "$elapsed_b" -ge "$((elapsed_a + 1))" ]; then
	_ok "case4: give-up time scales with fleet size (large-fleet ${elapsed_b}s > tiny-fleet ${elapsed_a}s)"
else
	_ko "case4: give-up time scales with fleet size (expected large-fleet clearly greater; got large=${elapsed_b}s, tiny=${elapsed_a}s)"
fi

# --- case 5: summary message correctness across three states ---
setup
tmuxp set -g automatic-rename off

# 5a: no snapshots at all - pre-existing case (already covered behaviorally
# by test_restore_all.sh), must not regress.
restore_show all
assert_eq "$(last_displayed_message)" "No saved tmux-persist sessions found!" "case5a: no-snapshots summary text unchanged"

# 5b: every saved session restores cleanly.
make_session ok5 OK5_MARK
save ok5
tmuxp kill-session -t ok5
restore_show all
summary_all_ok="$(last_displayed_message)"
assert_eq "$summary_all_ok" "Tmux restore complete (all sessions)!" "case5b: all-succeed summary text"

# 5c: mixed - a persistently-sabotaged session alongside ok5 (already live
# and correct from 5b, so its restore is an instant match with nothing to
# retry - the "succeeding" half of this mixed run).
make_session bad5 BAD5_MARK
tmuxp split-window -t bad5
sleep 0.2
save bad5
tmuxp kill-session -t bad5
set_sabotage_hook bad5 always ""
restore_show all
summary_mixed="$(last_displayed_message)"

assert_ne "$summary_mixed" "$summary_all_ok" "case5c: mixed-result summary text differs from the all-succeed text (must not claim unconditional full success)"
assert_ne "$summary_mixed" "No saved tmux-persist sessions found!" "case5c: mixed-result summary is not the no-snapshots text either"

teardown

finish
