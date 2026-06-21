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
assert_not_contains "$(tmuxp list-windows -t good -F '#{window_index}' | tr '\n' ' ')" "9" \
	"bogus window 9 not added to good"

teardown
finish
