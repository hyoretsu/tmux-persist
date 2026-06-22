#!/usr/bin/env bash
# A snapshot carrying a line with no session name (a crafted file, or one saved
# by a pre-3.x tmux that allowed `rename-session ''`) must not derail restore:
# the nameless line is skipped and the valid session restores normally. Modern
# tmux rejects `new-session -s ""`, so an un-skipped line only spews errors.
# (tmux-resurrect#415)

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

t=$'\t'

# --- unit: restore_pane skips a nameless line silently ---------------------
# Without the guard, restore_pane would reach `new-session -s ""`, which tmux
# rejects with an error on stderr. With the guard it returns silently. Run it
# inside the test server so the bare tmux calls hit the test socket.
nameless_line="$(printf 'pane%s%s9%s1%s:*%s0%s%s:/tmp%s1%s:%s:vim' "$t" "$t" "$t" "$t" "$t" "$t" "$t" "$t" "$t" "$t")"
err_file="$TEST_PERSIST_DIR/restore_pane.err"
tmuxp run-shell "bash -c 'cd \"$PLUGIN_DIR/scripts\"; \
	source ./restore.sh good quiet >/dev/null 2>&1; \
	restore_pane \"$nameless_line\" >/dev/null 2> \"$err_file\"'"
sleep 0.5
assert_eq "$(cat "$err_file" 2>/dev/null)" "" "restore_pane skips a nameless line without erroring"

# --- integration: a doctored snapshot still restores its valid session -----
tmuxp set -g @persist-snapshot-format separate
make_session good GOOD_MARK
save good

layout_txt="$TEST_PERSIST_DIR/$(readlink "$TEST_PERSIST_DIR/good_last")"
assert_file "$layout_txt" "plain-text layout exists"

# Prepend a nameless window + pane line (field 2 = session name is empty).
{
	printf 'window%s%s9%s:bad%s1%s:*%sdead0,80x24,0,0,0%s:\n' "$t" "$t" "$t" "$t" "$t" "$t" "$t"
	printf '%s\n' "$nameless_line"
	cat "$layout_txt"
} > "$layout_txt.new" && mv "$layout_txt.new" "$layout_txt"

tmuxp kill-session -t good
tmuxp new-session -d -s good
restore good

assert_contains "$(pane_text good)" "GOOD_MARK" "valid session restored despite nameless line"
sessions="$(tmuxp list-sessions -F '[#{session_name}]' 2>/dev/null | tr '\n' ' ')"
assert_not_contains "$sessions" "[]"     "no nameless session was created"
assert_contains     "$sessions" "[good]" "good session present"
assert_not_contains "$(tmuxp list-windows -t good -F '#{window_index}' | tr '\n' ' ')" "9" \
	"bogus window not added to good"

teardown
finish
