#!/usr/bin/env bash
# The persist dir must not be group/world-readable: saved sessions can contain
# sensitive scrollback. mkdir -p alone honours the umask, so the dir is chmod'd
# to 0700 explicitly. (tmux-resurrect#561)

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

mode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }

# Make the dir permissive first, so a passing result can only come from the
# explicit chmod (not from an already-strict umask).
chmod 0777 "$TEST_PERSIST_DIR"

make_session sec SEC_MARK
save sec

assert_file "$TEST_PERSIST_DIR/sec_last" "snapshot created"
assert_eq "$(mode "$TEST_PERSIST_DIR")" "700" "persist dir is 0700 after save"

# A restore round-trip still works with the strict perms in place.
tmuxp kill-session -t sec
tmuxp new-session -d -s sec
restore sec
assert_contains "$(pane_text sec)" "SEC_MARK" "restore works with 0700 perms"

teardown
finish
