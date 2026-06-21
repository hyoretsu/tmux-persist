#!/usr/bin/env bash
# Deleting a saved session removes its snapshots + "last" pointer, leaves other
# sessions untouched, and never deletes a differently-named session that merely
# shares a name prefix. (tmux-resurrect#552, #466, #385)

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

delete() { tmuxp run-shell "$PLUGIN_DIR/scripts/delete.sh $* quiet"; sleep 0.5; }
count() { find "$TEST_PERSIST_DIR" -maxdepth 1 -name "$1" 2>/dev/null | wc -l | tr -d ' '; }

# Two sessions where one name is a prefix of the other.
make_session app   APP_MARK
make_session app2  APP2_MARK
save app
save app2
assert_file "$TEST_PERSIST_DIR/app_last"  "app snapshot created"
assert_file "$TEST_PERSIST_DIR/app2_last" "app2 snapshot created"

# Delete only "app".
delete app
assert_no_file "$TEST_PERSIST_DIR/app_last" "app last pointer removed"
assert_eq "$(count 'app_*')" "0" "app snapshot files removed"
# The prefix-sharing session must be untouched.
assert_file "$TEST_PERSIST_DIR/app2_last" "app2 snapshot untouched (prefix not matched)"

# app2 still restores fine.
tmuxp kill-session -t app2
tmuxp new-session -d -s app2
restore app2
assert_contains "$(pane_text app2)" "APP2_MARK" "app2 still restorable after deleting app"

# Deleting also removes the separate-format pane-contents companion.
tmuxp set -g @persist-snapshot-format separate
make_session sep SEP_MARK
save sep
assert_file "$(echo "$TEST_PERSIST_DIR/sep_"*_pane_contents.tgz)" "companion exists before delete"
delete sep
assert_no_file "$TEST_PERSIST_DIR/sep_last" "sep last removed"
assert_eq "$(count 'sep_*')" "0" "sep snapshot + companion removed"

teardown
finish
