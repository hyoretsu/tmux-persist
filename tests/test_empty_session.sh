#!/usr/bin/env bash
# A snapshot carrying a line with no session name (a crafted file, or one saved
# by a pre-3.x tmux that allowed `rename-session ''`) must not derail restore:
# the nameless lines are skipped and the valid session restores normally. Modern
# tmux rejects `new-session -s ""`, so an un-skipped line only spews errors and
# noise. (tmux-resurrect#415)

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

t=$'\t'

# 'separate' format keeps the layout as a plain .txt we can doctor.
tmuxp set -g @persist-snapshot-format separate
make_session good GOOD_MARK
save good

layout_txt="$TEST_PERSIST_DIR/$(readlink "$TEST_PERSIST_DIR/good_last")"
assert_file "$layout_txt" "plain-text layout exists"

# Prepend a nameless window + pane line (field 2 = session name is empty). The
# pane references window 9 so we can prove nothing bogus leaks into 'good'.
nameless_pane="$(printf 'pane%s%s9%s1%s:*%s0%s%s:/tmp%s1%s:%s:vim' "$t" "$t" "$t" "$t" "$t" "$t" "$t" "$t" "$t" "$t")"
{
	printf 'window%s%s9%s:bad%s1%s:*%sdead0,80x24,0,0,0%s:\n' "$t" "$t" "$t" "$t" "$t" "$t" "$t"
	printf '%s\n' "$nameless_pane"
	cat "$layout_txt"
} > "$layout_txt.new" && mv "$layout_txt.new" "$layout_txt"

tmuxp kill-session -t good
tmuxp new-session -d -s good
restore good

assert_contains "$(pane_text good)" "GOOD_MARK" "valid session restored despite nameless lines"
sessions="$(tmuxp list-sessions -F '[#{session_name}]' 2>/dev/null | tr '\n' ' ')"
assert_not_contains "$sessions" "[]"     "no nameless session was created"
assert_contains     "$sessions" "[good]" "good session present"
# Exact match, not just "contains [good]": a naive read-based emptiness check
# (bash's `read` collapses a lone tab and shifts every later field left, so
# $session_name silently becomes the next real field's value instead of
# staying empty) would let this line through as a session literally named
# "9" instead of catching it as nameless.
assert_eq "$sessions" "[_bootstrap] [good] " "only _bootstrap and good exist - no session named '9' from the shifted fields"
assert_not_contains "$(tmuxp list-windows -t good -F '#{window_index}' | tr '\n' ' ')" "9" \
	"bogus window 9 not added to good"

teardown

# =====================================================================
# Case 2: a nameless pane line must not make restore_all_sessions() think
# the session under-restored. Before the fix, the retry-budget's expected-pane
# count included nameless lines (which restore_pane() itself skips), so a
# session that restored every real pane correctly still got reported as
# failed on stderr after burning its full retry budget.
# =====================================================================
setup
tmuxp set -g @persist-snapshot-format separate
make_session onlybad ONLYBAD_MARK
save onlybad

onlybad_txt="$TEST_PERSIST_DIR/$(readlink "$TEST_PERSIST_DIR/onlybad_last")"
{
	printf '%s\n' "$nameless_pane"
	cat "$onlybad_txt"
} > "$onlybad_txt.new" && mv "$onlybad_txt.new" "$onlybad_txt"

tmuxp kill-session -t onlybad

case2_err="$TEST_PERSIST_DIR/case2.err"
restore_capture_stderr "$case2_err" all
assert_eq "$(cat "$case2_err" 2>/dev/null)" "" \
	"restore all: no false failure reported for a session with only a nameless extra pane line"
assert_contains "$(pane_text onlybad)" "ONLYBAD_MARK" "restore all: the real pane still restored correctly"

teardown

# =====================================================================
# Case 3: a nameless grouped_session line must not hijack an attached
# client's focus. restore_active_and_alternate_windows_for_grouped_sessions()
# turns an empty $grouped_session into `switch-client -t ":$window_index"`,
# a valid tmux target meaning "current session, window $window_index" - so
# an unguarded empty line would silently move whichever client happens to be
# attached, not just error out like the other guarded call sites.
# =====================================================================
setup
tmuxp set -g @persist-snapshot-format separate

# bystander: the session an attached client sits in. Its active window must
# stay put - it is never referenced by name anywhere in victim's snapshot.
make_session bystander BYSTANDER_W0
tmuxp new-window -t bystander -n w1
tmuxp send-keys -t bystander:w1 "echo BYSTANDER_W1" Enter
tmuxp select-window -t bystander:0
sleep 0.3
assert_eq "$(active_window_index bystander)" "0" "sanity: bystander starts on window 0"

attach_control_client bystander
ctrl_pid="$CONTROL_CLIENT_PID"

# victim: an ordinary, non-grouped session - restoring it must not touch
# bystander's focus even though a bogus grouped_session line rides along.
make_session victim VICTIM_MARK
save victim
victim_txt="$TEST_PERSIST_DIR/$(readlink "$TEST_PERSIST_DIR/victim_last")"
nameless_grouped="$(printf 'grouped_session%s%svictim%s:1%s:1' "$t" "$t" "$t" "$t")"
{
	printf '%s\n' "$nameless_grouped"
	cat "$victim_txt"
} > "$victim_txt.new" && mv "$victim_txt.new" "$victim_txt"

tmuxp kill-session -t victim
tmuxp new-session -d -s victim
restore victim

assert_contains "$(pane_text victim)" "VICTIM_MARK" "victim still restored correctly despite the bogus line"
assert_eq "$(active_window_index bystander)" "0" \
	"bystander's focus untouched by victim's bogus grouped_session line"

detach_all_control_clients
teardown

finish
